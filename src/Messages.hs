{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}

module Messages where

import Control.Distributed.Process (Process, ProcessId, say)
import Data.Binary
import Data.Typeable
import GHC.Generics

type TicketId = Int
type Command  = Int

newtype Inc = Inc ProcessId deriving (Generic, Typeable, Binary)
newtype Report = Report Int deriving (Generic, Typeable, Binary)
data Done = Done deriving (Generic, Typeable, Binary, Show)

-- | The prepare message is the one the proposer sends to
-- the acceptors in line 2.
data Prepare = Prepare TicketId ProcessId
    deriving (Generic, Typeable, Binary, Show)

-- | The promise-ok message is the one called ok in the
-- book, and sent as a response to prepare in line 5.
-- The promise-not-ok message is mentioned in the second
-- remark as a negative message the acceptor can send to the
-- proposer in the case it cannot make a promise.
data Promise = PromiseOk TicketId Command ProcessId TicketId | PromiseNotOk TicketId TicketId
    deriving (Generic, Typeable, Binary, Show)

instance Eq Promise where
    (==) (PromiseOk a b c d) (PromiseOk a' b' c' d') = a==a' && b==b' && c==c' && d==d'
    (==)  PromiseOk{}        (PromiseNotOk _ _)      = False
    (==) (PromiseNotOk _ _)   PromiseOk{}            = False
    (==) (PromiseNotOk a b)    (PromiseNotOk a' b')  = a==a' && b==b'

instance Ord Promise where
    compare (PromiseOk    a _ _ _) (PromiseOk    a' _ _ _) = compare a a'
    compare (PromiseNotOk a _)     (PromiseNotOk a' _)     = compare a a'
    compare                   _                     _      = error
        "You must not compare PromiseOk with PromiseNotOk"

-- | The propose message is the one sent by the proposer
-- to the acceptors in line 12.
data Propose = Propose TicketId Command ProcessId
    deriving (Generic, Typeable, Binary, Show)

-- | The proposal-success message is the one sent by the
-- acceptor to the proposer in line 17.
-- Once again, the proposal-failure is mentioned in the
-- second remark as a negative message the acceptor can send
-- to the proposer in the case it cannot accept a proposal.
data Proposal = ProposalSuccess TicketId | ProposalFailure TicketId
    deriving (Generic, Typeable, Binary, Show)

-- | The execute message is the one sent by the proposer to
-- all acceptors in line 20.
newtype Execute = Execute Command
    deriving (Generic, Typeable, Binary, Show)

-- | The executed message is an additional message we just
-- use for this exercise. It's sent by the acceptors to the
-- master at the end of the protocol.
newtype Executed = Executed Command
    deriving (Generic, Typeable, Binary, Show)

-- | 1s = 1,000,000us
second :: Int
second = 1000000

-- | Helper function for declaring that the master is
-- logging.
masterSay :: String -> Process ()
masterSay msg = say $ "master   : " ++ msg

-- | Helper function for declaring that an acceptor
-- is logging.
acceptorSay :: String -> Process ()
acceptorSay msg = say $ "acceptor : " ++ msg

-- | Helper function for declaring that a proposer
-- is logging.
proposerSay :: String -> Process ()
proposerSay msg = say $ "proposer : " ++ msg