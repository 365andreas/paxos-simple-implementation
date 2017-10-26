# The Science of the Blockchain

## "Paxos" Assignment

The goal of this assignment is to implement the Paxos Algorithm
as specified as Algorithm 2.13 on page 13 of the Book.

There are the following types of messages:

- `prepare`             [OK]
- `promise-ok`          [OK]
- `promise-not-ok`      [  ]
- `propose`             [OK]
- `proposal-success`    [OK]
- `proposal-failure`    [  ]
- `execute`             [OK]
- `executed`            [OK]

There are the following types of agents:
- proposer  [OK]
- acceptor  [OK]
- master    [OK]

### Setup

The main program should be parameterized by numbers `a`
and `p`, indicating the number of acceptors and proposers
to use, respectively. The main program runs the master.     [OK]

The master should then start `a` acceptors.                 [OK]

The master should then start `p` proposers, which receive the process ids of
all the acceptors as an input. Each proposer should also be parameterized by
the value it would like to propose (if it is its own choice).  The main program
will just use different integers for each of the proposers. [OK]

Each acceptor should log when it receives an execute
message, and the value the execute message indicates.
It should then send an `executed` message to the master.    [OK]

The master should then wait for `p` occurrences of the
`executed` message to be sent. If that happens, it can
quit. If that does not happen (e.g., because no consensus
is being reached or even a single one of the acceptors
crashed), it will wait forever.                             [OK]

You should define a version of the algorithm that works
with timeouts but without negative responses, and one       [OK]
that in addition works with timeouts and negative responses.[  ]
In the latter, due to the reliability of a local network,
you'll probably never hit the timeouts though.              [  ]