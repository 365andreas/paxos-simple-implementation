module Acceptor where

import Messages

import Control.Distributed.Process (say, match, send, liftIO, receiveWait, Process, ProcessId)
import Control.Monad (forever, void, when)
import Data.IORef


logMsg :: String -> Process ()
logMsg msg = counterSay $ "Message came: " ++ msg

-- | Acceptor serving a phase-1 client
servePrepareMsg :: IORef TicketId -> IORef Command -> IORef TicketId -> Prepare -> Process ()
servePrepareMsg tMaxRef cmdRef tStoreRef (Prepare t proposerPid) = do

    tMax   <- liftIO $ readIORef   tMaxRef
    cmd    <- liftIO $ readIORef    cmdRef
    tStore <- liftIO $ readIORef tStoreRef

    when (t > tMax) $ do
        -- T_max = t (line 4)
        liftIO $ writeIORef tMaxRef t
        -- answer with ok(T_store, C) (line 5)
        send proposerPid $ PromiseOk tStore cmd

-- | Acceptor serving a phase-2 client
serveProposeMsg :: IORef TicketId -> IORef Command -> IORef TicketId -> Propose -> Process ()
serveProposeMsg tMaxRef cmdRef tStoreRef (Propose t cmd' proposerPid) = do

    tMax   <- liftIO $ readIORef   tMaxRef

    when (t == tMax) $ do
        -- C=c & T_store=t (lines 15, 16)
        liftIO $ writeIORef    cmdRef cmd'
        liftIO $ writeIORef tStoreRef   t
        -- answer with success (line 17)
        send proposerPid ProposalSuccess

-- | Acceptor serving an 'Execute' message
serveExecuteMsg :: ProcessId -> IORef TicketId -> IORef Command -> IORef TicketId ->Execute -> Process ()
serveExecuteMsg masterPid tMaxRef cmdRef tStoreRef (Execute cmdExec) = do
    acceptorSay $ "Received 'Execute " ++ show cmdExec ++ "' message"
    send masterPid $ Executed cmdExec

    liftIO $ writeIORef tMaxRef     0
    liftIO $ writeIORef tStoreRef   0
    liftIO $ writeIORef cmdRef    (-1)

serve :: ProcessId -> Process ()
serve masterPid = do

    tMaxRef   <- liftIO $ newIORef   0  :: Process (IORef TicketId)
    tStoreRef <- liftIO $ newIORef   0  :: Process (IORef TicketId)
    cmdRef    <- liftIO $ newIORef (-1) :: Process (IORef  Command)

    void $ forever $receiveWait [
            match $ servePrepareMsg tMaxRef cmdRef tStoreRef
          , match $ serveProposeMsg tMaxRef cmdRef tStoreRef
          , match $ serveExecuteMsg masterPid tMaxRef cmdRef tStoreRef
          , match logMsg
          ]