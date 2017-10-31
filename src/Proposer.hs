module Proposer where

import Messages

import Control.Concurrent (threadDelay)
import Control.Distributed.Process (
    match, send, liftIO, getSelfPid, spawnLocal,
    receiveTimeout, kill, Process, ProcessId
    )
import Control.Monad (forM_, replicateM)
import Data.List (partition)
import Data.Maybe (catMaybes)
import System.Random (randomRIO)


isPromiseOk :: Promise -> Bool
isPromiseOk PromiseOk{} =  True
isPromiseOk           _ = False

-- | Rejects messages that do not refer to the right
-- 'TicketId'
isRelevant :: TicketId -> Promise -> Bool
isRelevant tCurrent (PromiseOk    _ _ _ t) = tCurrent == t
isRelevant tCurrent (PromiseNotOk _ t)     = tCurrent == t

-- | Splits a 'Maybe' 'Promise' list to two lists, from
-- which the first contains 'PromiseOk' messages and the
-- second 'PromiseNotOk' messages.
splitOkNotOk :: TicketId -> [Maybe Promise] -> ([Promise], [Promise])
splitOkNotOk tCurrent list =
    let list' = filter (isRelevant tCurrent) (catMaybes list) in
        partition isPromiseOk list'
        -- (filter isPromiseOk list', filter (not.isPromiseOk) list')

isProposalSuccess :: TicketId -> Proposal -> Bool
isProposalSuccess tCurrent (ProposalSuccess t) = t == tCurrent
isProposalSuccess        _                  _  = False

-- | The 'catProposalSuccess' function takes a list of 'Maybe'
-- 'Proposal's and returns a list of all the 'Just'
-- 'ProposalSuccess' values for the specified 'TicketId'.
catProposalSuccess :: [Maybe Proposal] -> TicketId -> [Proposal]
catProposalSuccess list t =
    let list' = catMaybes list in
        filter (isProposalSuccess t) list'

-- | Sends 'Prepare' to every acceptor.
sendPrepare :: TicketId -> ProcessId -> [ProcessId] -> Process ()
sendPrepare t proposerPid list =
    forM_ list $ flip send (Prepare t proposerPid)

receivePromise :: Promise -> Process Promise
receivePromise = return

receiveProposal :: Proposal -> Process Proposal
receiveProposal = return

-- | Proposer's main.
propose :: [ProcessId] -> Command -> TicketId -> Process ()
propose serverPids cmd t = do

    self <- getSelfPid
    -- Phase 1
    -- "wait some time before consecutive attempts 100ms - 2s"
    delay <- liftIO $ randomRIO (100000, 2*second) --110000 to see more negative answers
    liftIO $ threadDelay delay
    let t' = t+1
    -- send Prepare
    senderPid <- spawnLocal $ sendPrepare t' self serverPids

    let a = length serverPids
    answers <- replicateM a (receiveTimeout second [ match receivePromise ])
    let (listOk, listNotOk) = splitOkNotOk t' answers

    kill senderPid "Receiving is over"

    if length listOk < a `div` 2 + 1 then
        case listNotOk of
            [] -> propose serverPids cmd t'
            _  -> let PromiseNotOk t'' _ = maximum listNotOk in
                do
                    proposerSay $ "Received 'PromiseNotOk'. Changing t: " ++
                        show t' ++ " -> " ++ show (t''+1)
                    propose serverPids cmd t''
    else do
        -- Phase 2
        let (PromiseOk tStore c _ _) = maximum listOk
        let cmd' = if tStore > 0 then c else cmd
        let pidsListOk = map (\(PromiseOk _ _ pid _) -> pid) listOk
        forM_ pidsListOk $ flip send $ Propose t' cmd' self

        ans <- replicateM a (receiveTimeout second [ match receiveProposal ])
        if length (catProposalSuccess ans t') < a `div` 2 + 1 then
            propose serverPids cmd t'
        else
            forM_ serverPids $ flip send $ Execute cmd'