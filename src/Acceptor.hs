{-# LANGUAGE RecordWildCards #-}

module Acceptor where

import Messages

import Control.Distributed.Process (say, match, send, liftIO, receiveWait, Process, ProcessId)
import Control.Monad (forever, void, when)
import Data.IORef

data ServerInfo =
    ServerInfo
        { masterPid :: ProcessId
        , tMaxRef   :: IORef TicketId
        , cmdRef    :: IORef Command
        , tStoreRef :: IORef TicketId
        }


logMsg :: String -> Process ()
logMsg msg = say $ "Message came: " ++ msg

-- | Acceptor serving a phase-1 client
servePrepare :: ServerInfo -> Prepare -> Process ()
servePrepare ServerInfo{..} (Prepare t proposerPid) = do

    tMax   <- liftIO $ readIORef   tMaxRef
    cmd    <- liftIO $ readIORef    cmdRef
    tStore <- liftIO $ readIORef tStoreRef

    when (t > tMax) $ do
        -- T_max = t (line 4)
        liftIO $ writeIORef tMaxRef t
        -- answer with ok(T_store, C) (line 5)
        send proposerPid $ PromiseOk tStore cmd

-- | Acceptor serving a phase-2 client
servePropose :: ServerInfo -> Propose -> Process ()
servePropose ServerInfo{..} (Propose t cmd' proposerPid) = do

    tMax   <- liftIO $ readIORef   tMaxRef

    when (t == tMax) $ do
        -- C=c & T_store=t (lines 15, 16)
        liftIO $ writeIORef    cmdRef cmd'
        liftIO $ writeIORef tStoreRef   t
        -- answer with success (line 17)
        send proposerPid ProposalSuccess

-- | Acceptor serving an 'Execute' message
serveExecute :: ServerInfo -> Execute -> Process ()
serveExecute ServerInfo{..} (Execute cmdExec) = do
    acceptorSay $ "Received 'Execute " ++ show cmdExec ++ "' message"
    send masterPid $ Executed cmdExec

    liftIO $ writeIORef tMaxRef     0
    liftIO $ writeIORef tStoreRef   0
    liftIO $ writeIORef cmdRef    (-1)

-- | Acceptor waits for 'Prepare', 'Propose' or
-- 'Execute' messages and serves them.
serve :: ProcessId -> Process ()
serve masterPid = do

    tMaxRef   <- liftIO $ newIORef   0  :: Process (IORef TicketId)
    tStoreRef <- liftIO $ newIORef   0  :: Process (IORef TicketId)
    cmdRef    <- liftIO $ newIORef (-1) :: Process (IORef  Command)

    void $ forever $receiveWait [
            match $ servePrepare ServerInfo{..}
          , match $ servePropose ServerInfo{..}
          , match $ serveExecute ServerInfo{..}
          , match logMsg
          ]