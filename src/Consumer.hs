module Consumer where

import Messages

import Control.Concurrent (threadDelay)
import Control.Distributed.Process

-- | Helper function for declaring that a consumer
-- is logging.
consumerSay :: String -> Process ()
consumerSay str = say $ "consumer : " ++ str

-- | A function that sends cnt 'Inc' messages to counter
-- knowing its PID and then sends 'Done' to master.
consumer :: Int -> ProcessId -> ProcessId -> Process ()
consumer 0            _ masterPid = do
    send masterPid Done
    terminate
consumer cnt counterPid masterPid = do
    self <- getSelfPid
    consumerSay $ "counter=" ++ show cnt
    send counterPid $ Inc self
    consumerSay $ "sent inc message to " ++ show counterPid
    Report n <- expect
    consumerSay $ "received report " ++ show n
    liftIO $ threadDelay 2000000
    consumer (cnt-1) counterPid masterPid