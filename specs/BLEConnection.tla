---------------------------- MODULE BLEConnection ----------------------------
(***************************************************************************)
(* A TLA+ model of Facett's BLE connection state machine, as implemented   *)
(* in Facett/BLEManager.swift and Facett/BLEConnectionHandler.swift.       *)
(*                                                                         *)
(* This spec deliberately models the code AS WRITTEN, not as intended, so  *)
(* that TLC produces counterexample traces for the real defects.  Each     *)
(* modelling choice that mirrors a specific line of Swift is annotated.    *)
(*                                                                         *)
(* Connection state in the app is not an enum -- it is encoded as which of *)
(* three dictionaries a camera currently lives in (BLEManager.swift:160).  *)
(* The spec therefore uses three independent sets rather than one          *)
(* location variable, so that "camera is in two states at once" is even    *)
(* expressible.                                                            *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Cameras,      \* set of camera identities (UUIDs)
    MaxRetries,   \* BLEManager.maxRetryAttempts (= 3)
    QueueBound    \* bound on in-flight main-queue blocks, to keep TLC finite

VARIABLES
    discovered,        \* BLEManager.discoveredGoPros  (keys)
    connecting,        \* BLEManager.connectingGoPros  (keys)
    connected,         \* BLEManager.connectedGoPros   (keys)
    retryCount,        \* BLEManager.connectionRetryCount
    retryTimer,        \* BLEManager.connectionRetryTimers   (armed?)
    attemptTimer,      \* BLEManager.connectionAttemptTimers (armed?)
    failQueue,         \* DispatchQueue.main blocks enqueued by didFailToConnect
    failuresProcessed  \* ghost: how many retries we have actually scheduled

vars == <<discovered, connecting, connected, retryCount, retryTimer,
          attemptTimer, failQueue, failuresProcessed>>

(***************************************************************************)
(* A queued main-queue block carries a SNAPSHOT of retryCount that was     *)
(* read earlier, on the CoreBluetooth background queue.  This is the       *)
(* crux of the lost-update bug: BLEManager.swift:959 reads the count off   *)
(* the BLE queue, and BLEManager.swift:966 applies snapshot+1 later on     *)
(* main.  Modelling the snapshot explicitly is what lets TLC find it.      *)
(***************************************************************************)
Block == [cam: Cameras, snapshot: 0..MaxRetries]

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
\* Environment action: centralManager didDiscover (BLEManager.swift:912)
Discover(c) ==
    /\ c \notin discovered /\ c \notin connecting /\ c \notin connected
    /\ discovered' = discovered \cup {c}
    /\ UNCHANGED <<connecting, connected, retryCount, retryTimer,
                   attemptTimer, failQueue, failuresProcessed>>

(***************************************************************************)
(* connectToGoPro -- BLEManager.swift:1846.                                *)
(*                                                                         *)
(* Two faithful details that matter:                                       *)
(*   1. It adds to connectingGoPros (:1871) but does NOT remove from       *)
(*      discoveredGoPros.  That removal happens only on didConnect         *)
(*      (BLEConnectionHandler.swift:43).                                   *)
(*   2. It does NOT arm a connection-attempt timer.  Only retryConnection  *)
(*      does (BLEManager.swift:1935).                                      *)
(***************************************************************************)
ConnectToGoPro(c) ==
    /\ c \in discovered
    /\ c \notin connecting
    /\ c \notin connected
    /\ connecting' = connecting \cup {c}
    /\ UNCHANGED <<discovered, connected, retryCount, retryTimer,
                   attemptTimer, failQueue, failuresProcessed>>

\* Environment action: didConnect (BLEConnectionHandler.swift:41-43)
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

(***************************************************************************)
(* Environment action: didFailToConnect (BLEManager.swift:958-966).        *)
(* Reads retryCount on the BLE queue, then defers the decision to main.    *)
(***************************************************************************)
DidFail(c) ==
    /\ c \in connecting
    /\ Len(failQueue) < QueueBound
    /\ failQueue' = Append(failQueue, [cam |-> c, snapshot |-> retryCount[c]])
    /\ attemptTimer' = attemptTimer \ {c}
    /\ UNCHANGED <<discovered, connecting, connected, retryCount,
                   retryTimer, failuresProcessed>>

(***************************************************************************)
(* handleConnectionTimeout -- BLEManager.swift:1880.                       *)
(* Removes from connectingGoPros (:1904) and THEN re-enters                *)
(* didFailToConnect (:1909) -- so by the time the queued block runs, the   *)
(* camera is no longer in connectingGoPros.                                *)
(***************************************************************************)
HandleConnectionTimeout(c) ==
    /\ c \in attemptTimer
    /\ c \in connecting
    /\ Len(failQueue) < QueueBound
    /\ connecting'   = connecting \ {c}
    /\ attemptTimer' = attemptTimer \ {c}
    /\ failQueue'    = Append(failQueue, [cam |-> c, snapshot |-> retryCount[c]])
    /\ UNCHANGED <<discovered, connected, retryCount, retryTimer, failuresProcessed>>

(***************************************************************************)
(* The deferred main-queue block from didFailToConnect                     *)
(* (BLEManager.swift:961-1008).  Note the guard at :962 --                 *)
(* `if let gopro = self.connectingGoPros[uuid]` -- and that the ELSE       *)
(* branch is empty: if the camera has left connectingGoPros in the         *)
(* meantime, the failure is silently dropped and no state is cleaned up.   *)
(***************************************************************************)
ProcessFail ==
    /\ failQueue # <<>>
    /\ LET blk == Head(failQueue)
           c   == blk.cam
       IN /\ failQueue' = Tail(failQueue)
          /\ IF c \in connecting
             THEN IF blk.snapshot < MaxRetries
                  THEN \* retry path, BLEManager.swift:966-978
                       /\ retryCount' = [retryCount EXCEPT ![c] = blk.snapshot + 1]
                       /\ failuresProcessed' = [failuresProcessed EXCEPT ![c] = @ + 1]
                       /\ retryTimer' = retryTimer \cup {c}
                       /\ UNCHANGED <<discovered, connecting, connected, attemptTimer>>
                  ELSE \* abandon path, BLEManager.swift:982-987
                       /\ connecting'   = connecting \ {c}
                       /\ discovered'   = discovered \cup {c}
                       /\ retryCount'   = [retryCount EXCEPT ![c] = 0]
                       /\ retryTimer'   = retryTimer \ {c}
                       /\ attemptTimer' = attemptTimer \ {c}
                       /\ failuresProcessed' = [failuresProcessed EXCEPT ![c] = 0]
                       /\ UNCHANGED connected
             ELSE \* guard failed: block does nothing at all
                  UNCHANGED <<discovered, connecting, connected, retryCount,
                              retryTimer, attemptTimer, failuresProcessed>>

(***************************************************************************)
(* retryConnection -- BLEManager.swift:1913.  Guards on discoveredGoPros,  *)
(* which still contains the camera (see ConnectToGoPro note 1), then arms  *)
(* the attempt timer at :1935.                                             *)
(***************************************************************************)
RetryFire(c) ==
    /\ c \in retryTimer
    /\ retryTimer' = retryTimer \ {c}
    /\ IF c \in discovered /\ c \notin connected
       THEN /\ connecting'   = connecting \cup {c}
            /\ attemptTimer' = attemptTimer \cup {c}
       ELSE UNCHANGED <<connecting, attemptTimer>>
    /\ UNCHANGED <<discovered, connected, retryCount, failQueue, failuresProcessed>>

\* didDisconnectPeripheral, non-sleeping path (BLEConnectionHandler.swift:74-80)
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

(***************************************************************************)
(* Fairness is asserted ONLY for actions the app itself controls.          *)
(* DidConnect and DidFail are CoreBluetooth callbacks -- the radio is      *)
(* under no obligation to ever call back, which is precisely why a         *)
(* connection attempt needs its own timeout.  Leaving them unfair is what  *)
(* exposes the missing-timeout liveness bug.                               *)
(***************************************************************************)
Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(ProcessFail)
    /\ \A c \in Cameras:
         /\ WF_vars(RetryFire(c))
         /\ WF_vars(HandleConnectionTimeout(c))

\* Keeps the ghost counter finite so TLC terminates.
StateConstraint == \A c \in Cameras: failuresProcessed[c] <= MaxRetries + 2

-----------------------------------------------------------------------------
\*                              PROPERTIES

\* A camera should occupy exactly one of the three dictionaries.
MutualExclusion ==
    \A c \in Cameras:
        /\ ~(c \in discovered /\ c \in connecting)
        /\ ~(c \in connecting /\ c \in connected)
        /\ ~(c \in discovered /\ c \in connected)

\* A camera must be abandoned after at most MaxRetries scheduled retries.
BoundedRetries ==
    \A c \in Cameras: failuresProcessed[c] <= MaxRetries

\* Scanning restarts only when connectingGoPros is empty (BLEManager.swift:2090),
\* so a camera stuck in `connecting` disables discovery for the whole app.
ScanningLive == []<>(connecting = {})

\* No camera stays in `connecting` forever.
NoStuckConnecting == \A c \in Cameras: (c \in connecting) ~> (c \notin connecting)

\* Retry bookkeeping must not outlive the connection attempt it belongs to.
NoOrphanedRetryState ==
    \A c \in Cameras:
        (c \notin connecting /\ c \notin connected) => retryCount[c] = 0

=============================================================================
