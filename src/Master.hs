{-# LANGUAGE TemplateHaskell #-}

module Master where

import Acceptor (serve)
import Counter
import Consumer
import Messages

import Control.Concurrent (threadDelay)
import Control.Monad (replicateM_, replicateM)
import Control.Distributed.Process
import Control.Distributed.Process.Closure (mkClosure, remotable, mkStaticClosure)
import Control.Distributed.Process.Node
import Data.Maybe (isJust)
import Network.Transport.TCP (createTransport, defaultTCPParameters)


-- | Helper function in order to be able to apply 'mkClosure'
consumerClosure :: (Int, ProcessId, ProcessId) -> Process ()
consumerClosure (cnt, counterPid, masterPid) =
    consumer cnt counterPid masterPid

remotable ['counter, 'consumerClosure, 'serve]

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
        self <- getSelfPid
        -- Spawn acceptors on their node
        acceptorsPids <- replicateM a $ spawn acceptorsNodeId $ $(mkClosure 'serve) self

        counterPid  <- spawn acceptorsNodeId $ $(mkStaticClosure 'counter)
        liftIO $ print acceptorsPids
        -- Spawn proposers on their node
        replicateM_ a $ spawn proposersNodeId $ $(mkClosure 'consumerClosure) (p, counterPid, self)

        list <- replicateM a (expectTimeout $ 180*second :: Process (Maybe Done))
        if length (filter isJust list) == a
            then say $ "master : All Done messages (" ++ show a ++ ") received."
            else say $ "master : Messages received: " ++ show list

        kill counterPid "kill sent from master"
        liftIO $ threadDelay 500000
        terminate