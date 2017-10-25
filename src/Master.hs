{-# LANGUAGE TemplateHaskell #-}

module Master where

import Acceptor (serve)
import Messages
import Proposer (propose)

-- import Control.Concurrent (threadDelay)
import Control.Monad (replicateM_, replicateM, forM_)
import Control.Distributed.Process
import Control.Distributed.Process.Closure (mkClosure, remotable)
import Control.Distributed.Process.Node
import Network.Transport.TCP (createTransport, defaultTCPParameters)


serveExecuted :: Executed -> Process ()
serveExecuted (Executed _) = return () -- masterSay $ "Received 'Executed " ++ show cmd ++ "'"

proposeClosure :: ([ProcessId], Command, TicketId) -> Process ()
proposeClosure (list, cmd, t) = propose list cmd t

remotable ['serve, 'proposeClosure]

masterRemoteTable :: RemoteTable
masterRemoteTable = Master.__remoteTable initRemoteTable

master :: Int -> Int -> IO ()
master a p = do
    Right t     <- createTransport "127.0.0.1" "10501" defaultTCPParameters
    Right tAcc  <- createTransport "127.0.0.1" "10502" defaultTCPParameters
    Right tProp <- createTransport "127.0.0.1" "10503" defaultTCPParameters

    masterNode    <- newLocalNode     t   initRemoteTable
    acceptorsNode <- newLocalNode  tAcc masterRemoteTable
    proposersNode <- newLocalNode tProp masterRemoteTable

    let acceptorsNodeId = localNodeId acceptorsNode
    let proposersNodeId = localNodeId proposersNode

    runProcess masterNode $ do
        masterPid <- getSelfPid
        -- Spawn acceptors on their node
        acceptorsPids <- replicateM a $ spawn acceptorsNodeId $ $(mkClosure 'serve) masterPid
        -- liftIO $ print acceptorsPids

        let zeroT = 0 :: TicketId
        -- Spawn proposers on their node
        forM_ (zip3 (repeat acceptorsPids) [1..p] (repeat zeroT)) $
             spawn proposersNodeId . $( mkClosure 'proposeClosure )

        replicateM_ a $ receiveWait [ match serveExecuted ]