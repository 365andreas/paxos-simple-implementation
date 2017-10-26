-- {-# LANGUAGE RecordWildCards #-}

module Proposer where

import Messages

import Control.Concurrent (threadDelay)
import Control.Distributed.Process (
    match, send, liftIO, getSelfPid, spawnLocal,
    receiveTimeout, kill, Process, ProcessId
    )
import Control.Monad (forM_, replicateM)
import Data.Maybe (isJust, catMaybes)
import System.Random (randomRIO)


isPromiseOk :: Promise -> Bool
isPromiseOk PromiseOk{} =  True
isPromiseOk           _ = False

splitOkNotOk :: [Maybe Promise] -> ([Promise], [Promise])
splitOkNotOk list =
    let list' = catMaybes list in
        (filter isPromiseOk list', filter (not.isPromiseOk) list')

isProposalSuccess :: Proposal -> Bool
isProposalSuccess ProposalSuccess =  True
isProposalSuccess               _ = False

catProposalSuccess :: [Maybe Proposal] -> [Proposal]
catProposalSuccess list =
    let list' = catMaybes list in
        filter isProposalSuccess list'

-- | Sends 'Prepare' to every acceptor.
sendPrepare :: TicketId -> ProcessId -> [ProcessId] -> Process ()
sendPrepare t proposerPid list =
    forM_ list $ flip send (Prepare t proposerPid)

receivePromise :: Promise -> Process Promise
receivePromise = return

receiveProposal :: Proposal -> Process Proposal
receiveProposal = return

-- | Proposer ...
propose :: [ProcessId] -> Command -> TicketId -> Process ()
propose serverPids cmd t = do

    self <- getSelfPid
    -- Phase 1
    -- "wait some time before consecutive attempts"
    delay <- liftIO $ randomRIO (100000, 2*second) --110000 to see more negative answers
    liftIO $ threadDelay delay
    let t' = t+1
    -- send Prepare
    senderPid <- spawnLocal $ sendPrepare t' self serverPids

    let a = length serverPids

    -- receivePhase1
    answers <- replicateM a (receiveTimeout second [ match receivePromise ])
    let (listOk, listNotOk) = splitOkNotOk answers

    kill senderPid "Receiving is over"

    if length listOk < a `div` 2 + 1 then
        case listNotOk of
            [] -> propose serverPids cmd t'
            _  -> let PromiseNotOk t'' = maximum listNotOk in
                do
                    proposerSay $ "Received 'PromiseNotOk'. Changing t: " ++
                        show t' ++ " -> " ++ show (t''+1)
                    propose serverPids cmd t''
    else do
        -- Phase 2
        let (PromiseOk tStore c _) = maximum listOk
        let cmd' = if tStore > 0 then c else cmd
        let pidsListOk = map (\(PromiseOk _ _ pid) -> pid) listOk
        forM_ pidsListOk $ flip send $ Propose t' cmd' self

        ans <- replicateM a (receiveTimeout second [ match receiveProposal ])
        if length (catProposalSuccess ans) < a `div` 2 + 1 then
            propose serverPids cmd t'
        else
            forM_ serverPids $ flip send $ Execute cmd'