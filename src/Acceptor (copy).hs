module Acceptor where

import Messages

import Control.Distributed.Process (say, match, send, liftIO, receiveWait, Process, ProcessId)

-- | Helper function for declaring that the counter
-- is logging.
counterSay :: String -> Process ()
counterSay str = say $ "counter : " ++ str

logMsg :: String -> Process ()
logMsg msg = counterSay $ "Message came: " ++ msg

-- | Acceptor serving a phase-1 client
servePrepareMsg :: ProcessId -> TicketId -> Command -> TicketId -> Prepare -> Process ()
servePrepareMsg masterPid tMax cmd tStore (Prepare t proposerPid)
    | t > tMax  = do
        -- answer with ok(T_store, C) (line 5)
        send proposerPid $ PromiseOk tStore cmd
        -- T_max = t (line 4)
        serve masterPid t cmd tStore
    | otherwise =
        serve masterPid tMax cmd tStore

-- | Acceptor serving a phase-2 client
serveProposeMsg :: ProcessId -> TicketId -> Command -> TicketId -> Propose -> Process ()
serveProposeMsg masterPid tMax cmd tStore (Propose t cmd' proposerPid)
    | t == tMax  = do
        -- answer with success (line 17)
        send proposerPid ProposalSuccess
        -- C=c & T_store=t (lines 15, 16)
        serve masterPid tMax cmd' t
    | otherwise =
        serve masterPid tMax cmd tStore

serveExecuteMsg :: ProcessId -> Execute -> Process ()
serveExecuteMsg masterPid (Execute cmdExec) = do
    acceptorSay $ "Received 'Execute " ++ show cmdExec ++ "' message"
    send masterPid $ Executed cmdExec
    serve masterPid 0 (-1) 0

serve :: ProcessId -> TicketId -> Command -> TicketId -> Process ()
serve masterPid tMax cmd tStore =
    receiveWait [
        match $ servePrepareMsg masterPid tMax cmd tStore
      , match $ serveProposeMsg masterPid tMax cmd tStore
      , match $ serveExecuteMsg masterPid
      , match logMsg
      ]