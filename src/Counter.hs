module Counter where

import Messages

import Control.Monad (forever)
import Control.Distributed.Process
import Data.IORef

-- | Helper function for declaring that the counter
-- is logging.
counterSay :: String -> Process ()
counterSay str = say $ "counter : " ++ str

logMsg :: String -> Process ()
logMsg msg = counterSay $ "Message came: " ++ msg

logDone :: Done -> Process ()
logDone _ = counterSay "Done came"

-- | After receiving 'Inc' message counter increases its
-- state and send the 'Report' message to the specified PID.
increaseAndReport :: IORef Int -> Inc -> Process ()
increaseAndReport ref (Inc pid) = do
    liftIO $ modifyIORef ref (+1)
    n <- liftIO $ readIORef ref :: Process Int
    counterSay $  "received inc message, has state: " ++ show n
               ++ "\n\t and will send report message to " ++ show pid
    send pid $ Report n
    return ()

counter :: Process ()
counter = do
    stateRef <- liftIO $ newIORef 0 :: Process (IORef Int)
    _ <- forever $ receiveWait [match $ increaseAndReport stateRef, match logMsg, match logDone]
    return ()