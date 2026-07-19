------------------------- MODULE BLEConnectionFixed -------------------------
(***************************************************************************)
(* The repaired connection state machine.  Same actions as BLEConnection,  *)
(* with four changes -- each one corresponding to a concrete code fix:     *)
(*                                                                         *)
(*  FIX 1 (MutualExclusion): connectToGoPro moves the camera out of        *)
(*        discoveredGoPros instead of leaving it in both dictionaries.     *)
(*                                                                         *)
(*  FIX 2 (ScanningLive): connectToGoPro arms the connection-attempt       *)
(*        timer, so the FIRST attempt is bounded, not just retries.        *)
(*                                                                         *)
(*  FIX 3 (BoundedRetries): the deferred main-queue block reads            *)
(*        retryCount LIVE on main rather than using a snapshot taken       *)
(*        earlier on the CoreBluetooth queue.                              *)
(*                                                                         *)
(*  FIX 4 (NoOrphanedRetryState): handleConnectionTimeout no longer        *)
(*        removes the camera from connectingGoPros before re-entering the  *)
(*        failure path; ownership of that transition belongs to the        *)
(*        failure handler alone.                                           *)
(*                                                                         *)
(*  Note the coupling: FIX 1 invalidates retryConnection's existing guard  *)
(*  `guard let gopro = discoveredGoPros[uuid]`, because a retrying camera  *)
(*  is no longer in discoveredGoPros.  The guard must become a check on    *)
(*  connectingGoPros.  Applying FIX 1 without this would silently disable  *)
(*  all retries.                                                           *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Cameras, MaxRetries, QueueBound

VARIABLES discovered, connecting, connected, retryCount, retryTimer,
          attemptTimer, failQueue, failuresProcessed

vars == <<discovered, connecting, connected, retryCount, retryTimer,
          attemptTimer, failQueue, failuresProcessed>>

\* The block no longer carries a snapshot -- only the camera identity.
Block == [cam: Cameras]

TypeOK ==
    /\ discovered \subseteq Cameras
    /\ connecting \subseteq Cameras
    /\ connected  \subseteq Cameras
    /\ retryTimer \subseteq Cameras
    /\ attemptTimer \subseteq Cameras
    /\ retryCount \in [Cameras -> 0..MaxRetries]
    /\ failuresProcessed \in [Cameras -> Nat]
    /\ failQueue \in Seq(Block)

Init ==
    /\ discovered = {}
    /\ connecting = {}
    /\ connected  = {}
    /\ retryCount = [c \in Cameras |-> 0]
    /\ failuresProcessed = [c \in Cameras |-> 0]
    /\ retryTimer = {}
    /\ attemptTimer = {}
    /\ failQueue = <<>>

-----------------------------------------------------------------------------
Discover(c) ==
    /\ c \notin discovered /\ c \notin connecting /\ c \notin connected
    /\ discovered' = discovered \cup {c}
    /\ UNCHANGED <<connecting, connected, retryCount, retryTimer,
                   attemptTimer, failQueue, failuresProcessed>>

\* FIX 1 + FIX 2
ConnectToGoPro(c) ==
    /\ c \in discovered
    /\ c \notin connecting
    /\ c \notin connected
    /\ discovered'   = discovered \ {c}
    /\ connecting'   = connecting \cup {c}
    /\ attemptTimer' = attemptTimer \cup {c}
    /\ UNCHANGED <<connected, retryCount, retryTimer, failQueue, failuresProcessed>>

DidConnect(c) ==
    /\ c \in connecting
    /\ connected'  = connected \cup {c}
    /\ connecting' = connecting \ {c}
    /\ discovered' = discovered \ {c}
    /\ retryCount' = [retryCount EXCEPT ![c] = 0]
    /\ retryTimer' = retryTimer \ {c}
    /\ attemptTimer' = attemptTimer \ {c}
    /\ failuresProcessed' = [failuresProcessed EXCEPT ![c] = 0]
    /\ UNCHANGED failQueue

DidFail(c) ==
    /\ c \in connecting
    /\ Len(failQueue) < QueueBound
    /\ failQueue' = Append(failQueue, [cam |-> c])
    /\ attemptTimer' = attemptTimer \ {c}
    /\ UNCHANGED <<discovered, connecting, connected, retryCount,
                   retryTimer, failuresProcessed>>

\* FIX 4: stays in `connecting`; the failure handler owns the transition.
HandleConnectionTimeout(c) ==
    /\ c \in attemptTimer
    /\ c \in connecting
    /\ Len(failQueue) < QueueBound
    /\ attemptTimer' = attemptTimer \ {c}
    /\ failQueue'    = Append(failQueue, [cam |-> c])
    /\ UNCHANGED <<discovered, connecting, connected, retryCount,
                   retryTimer, failuresProcessed>>

\* FIX 3: reads retryCount live instead of a stale snapshot.
ProcessFail ==
    /\ failQueue # <<>>
    /\ LET c == Head(failQueue).cam
       IN /\ failQueue' = Tail(failQueue)
          /\ IF c \in connecting
             THEN IF retryCount[c] < MaxRetries
                  THEN /\ retryCount' = [retryCount EXCEPT ![c] = @ + 1]
                       /\ failuresProcessed' = [failuresProcessed EXCEPT ![c] = @ + 1]
                       /\ retryTimer' = retryTimer \cup {c}
                       /\ UNCHANGED <<discovered, connecting, connected, attemptTimer>>
                  ELSE /\ connecting'   = connecting \ {c}
                       /\ discovered'   = discovered \cup {c}
                       /\ retryCount'   = [retryCount EXCEPT ![c] = 0]
                       /\ retryTimer'   = retryTimer \ {c}
                       /\ attemptTimer' = attemptTimer \ {c}
                       /\ failuresProcessed' = [failuresProcessed EXCEPT ![c] = 0]
                       /\ UNCHANGED connected
             ELSE UNCHANGED <<discovered, connecting, connected, retryCount,
                              retryTimer, attemptTimer, failuresProcessed>>

\* Guard now checks connectingGoPros, per the FIX 1 coupling note above.
RetryFire(c) ==
    /\ c \in retryTimer
    /\ retryTimer' = retryTimer \ {c}
    /\ IF c \in connecting /\ c \notin connected
       THEN attemptTimer' = attemptTimer \cup {c}
       ELSE UNCHANGED attemptTimer
    /\ UNCHANGED <<discovered, connecting, connected, retryCount,
                   failQueue, failuresProcessed>>

Disconnect(c) ==
    /\ c \in connected
    /\ connected'  = connected \ {c}
    /\ discovered' = discovered \cup {c}
    /\ UNCHANGED <<connecting, retryCount, retryTimer, attemptTimer,
                   failQueue, failuresProcessed>>

-----------------------------------------------------------------------------
Next ==
    \/ ProcessFail
    \/ \E c \in Cameras:
         \/ Discover(c) \/ ConnectToGoPro(c) \/ DidConnect(c)
         \/ DidFail(c)  \/ HandleConnectionTimeout(c)
         \/ RetryFire(c) \/ Disconnect(c)

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(ProcessFail)
    /\ \A c \in Cameras:
         /\ WF_vars(RetryFire(c))
         /\ WF_vars(HandleConnectionTimeout(c))

StateConstraint == \A c \in Cameras: failuresProcessed[c] <= MaxRetries + 2

-----------------------------------------------------------------------------
MutualExclusion ==
    \A c \in Cameras:
        /\ ~(c \in discovered /\ c \in connecting)
        /\ ~(c \in connecting /\ c \in connected)
        /\ ~(c \in discovered /\ c \in connected)

BoundedRetries == \A c \in Cameras: failuresProcessed[c] <= MaxRetries

ScanningLive == []<>(connecting = {})

NoStuckConnecting == \A c \in Cameras: (c \in connecting) ~> (c \notin connecting)

NoOrphanedRetryState ==
    \A c \in Cameras:
        (c \notin connecting /\ c \notin connected) => retryCount[c] = 0

=============================================================================
