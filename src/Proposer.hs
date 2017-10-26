-- {-# LANGUAGE RecordWildCards #-}

module Proposer where

import Messages

import Control.Concurrent (threadDelay)
import Control.Distributed.Process (
    say, match, send, liftIO, receiveWait, getSelfPid,
    spawnLocal, receiveTimeout, expectTimeout, kill,
    Process, ProcessId
    )
import Control.Monad (forM_, replicateM)
import Data.Maybe (isJust, catMaybes)
import System.Random

-- data ServerInfo =
--     ServerInfo
--         { masterPid :: ProcessId
--         , tMaxRef   :: IORef TicketId
--         , cmdRef    :: IORef Command
--         , tStoreRef :: IORef TicketId
--         }

isPromiseOk :: Promise -> Bool
isPromiseOk PromiseOk{} =  True
isPromiseOk           _ = False

splitOkNotOk :: [Maybe Promise] -> ([Promise], [Promise])
splitOkNotOk list =
    let list' = catMaybes list in
        (filter isPromiseOk list', filter (not.isPromiseOk) list')

-- | Sends 'Prepare' to every acceptor.
sendPrepare :: TicketId -> ProcessId -> [ProcessId] -> Process ()
sendPrepare t proposerPid list =
    forM_ list $ flip send (Prepare t proposerPid)

-- receivePromiseOk :: PromiseOk -> Process (Maybe PromiseOk)
-- receivePromiseOK _ =
-- --     liftIO $ putStrLn "---i am in"
-- --     replicateM (3-1) (expectTimeout 1000 :: Process (Maybe PromiseOk))

-- receivePromiseNotOk :: PromiseNotOk -> Process TicketId
-- receivePromiseNotOk (PromiseNotOk t) = undefined

receivePromise :: Promise -> Process Promise
receivePromise = return

-- receivePhase1 :: Int -> [Promise] -> [Promise]
-- receivePhase1 0 = Right
-- receivePhase1 n list = do
--     receiveWait [ match receivePromise ]

-- | Proposer ...
propose :: [ProcessId] -> Command -> TicketId -> Process ()
propose serverPids cmd t = do

    self <- getSelfPid
    -- Phase 1
    -- "wait some time before consecutive attempts"
    delay <- liftIO $ randomRIO (100000, 2*second) --11000 to see more negative answers
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
                    -- liftIO $ print listNotOk
                    proposerSay $ "Received NotOk. Changing t :" ++ show t' ++ " -> " ++ show (t''+1)
                    propose serverPids cmd t''
    else do
        -- Phase 2
        let (PromiseOk tStore c _) = maximum listOk
        let cmd' = if tStore > 0 then c else cmd
        let pidsListOk = map (\(PromiseOk _ _ pid) -> pid) listOk
        forM_ pidsListOk $ flip send $ Propose t' cmd' self

        ans <- replicateM a (expectTimeout second :: Process (Maybe ProposalSuccess))
        if length (filter isJust ans) < a `div` 2 + 1 then
            propose serverPids cmd t'
        else
            forM_ serverPids $ flip send $ Execute cmd'