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
import Data.Maybe (isJust)
import System.Random

-- data ServerInfo =
--     ServerInfo
--         { masterPid :: ProcessId
--         , tMaxRef   :: IORef TicketId
--         , cmdRef    :: IORef Command
--         , tStoreRef :: IORef TicketId
--         }

logMsg :: String -> Process ()
logMsg msg = say $ "Message came: " ++ msg

-- | Sends 'Prepare' to every acceptor.
sendPrepare :: TicketId -> ProcessId -> [ProcessId] -> Process ()
sendPrepare t proposerPid list =
    forM_ list $ flip send (Prepare t proposerPid)

-- receivePromise :: PromiseOk -> Process [Maybe PromiseOk]
-- receivePromise _ = do
--     liftIO $ putStrLn "---i am in"
--     replicateM (3-1) (expectTimeout 1000 :: Process (Maybe PromiseOk))

-- | Proposer ...
propose :: [ProcessId] -> Command -> TicketId -> Process ()
propose serverPids cmd t = do

    self <- getSelfPid
    -- Phase 1
    -- "wait some time before consecutive attempts"
    delay <- liftIO $ randomRIO (100000, 2*second)
    liftIO $ threadDelay delay
    let t' = t+1
    -- send Prepare
    senderPid <- spawnLocal $ sendPrepare t' self serverPids

    let a = length serverPids
    answers <- replicateM a (expectTimeout second :: Process (Maybe PromiseOk))
    kill senderPid "Receiving is over"

    let listOk = filter isJust answers
    if length listOk < a `div` 2 +1 then
        propose serverPids cmd t'
    else do
        -- Phase 2
        let Just (PromiseOk tStore c _) = maximum listOk
        let cmd' = if tStore > 0 then c else cmd
        let pidsListOk = map (\(Just (PromiseOk _ _ pid)) -> pid) listOk
        forM_ pidsListOk $ flip send $ Propose t' cmd' self

        ans <- replicateM a (expectTimeout second :: Process (Maybe ProposalSuccess))
        if length (filter isJust ans) < a `div` 2 + 1 then
            propose serverPids cmd t'
        else
            forM_ serverPids $ flip send $ Execute cmd'