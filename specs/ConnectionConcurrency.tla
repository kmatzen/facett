------------------------- MODULE ConnectionConcurrency -------------------------
(***************************************************************************)
(* Which concurrency discipline actually makes BLEManager's shared state    *)
(* safe?                                                                    *)
(*                                                                          *)
(* BLEManager keeps connection state in three @Published dictionaries.      *)
(* CoreBluetooth delegate callbacks run on a background queue                *)
(* (BLEManager.swift:652 creates the central with a utility queue), while    *)
(* @Published mutations are bounced to main. Roughly 70 accesses across      *)
(* nine delegate methods are involved, so the refactor is expensive and      *)
(* worth getting right on paper first.                                      *)
(*                                                                          *)
(* Rather than model all 70 sites, this models the SHAPE they share: a       *)
(* read-decide-write over shared state, performed concurrently by a          *)
(* CoreBluetooth-queue path and a main-queue path. The retry counter bug     *)
(* already fixed in didFailToConnect is exactly this shape, which is why it  *)
(* is a fair representative.                                                *)
(*                                                                          *)
(* Two distinct hazards are checked, because they need different fixes:      *)
(*                                                                          *)
(*   NoDataRace   - no two threads touching the dictionary at once, one of   *)
(*                  them writing. Swift Dictionary is not thread-safe, so    *)
(*                  this is memory-unsafety, not just a logic error.         *)
(*                                                                          *)
(*   NoLostUpdate - no write based on a value read before someone else's     *)
(*                  write landed.                                           *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Agents,      \* concurrent operations in flight
    Discipline   \* "current" | "writesOnMain" | "mainAtomic" | "serialQueue"

VARIABLES
    counter,   \* the shared state (stands in for connectionRetryCount et al.)
    phase,     \* per agent: "idle" | "reading" | "held" | "writing" | "done"
    snapshot,  \* per agent: the value it read
    completed  \* how many operations have finished

vars == <<counter, phase, snapshot, completed>>

MaxOps == Cardinality(Agents)

-----------------------------------------------------------------------------
(***************************************************************************)
(* Which queue each half of the operation runs on.                         *)
(*                                                                         *)
(* "current"      - reads happen on the CoreBluetooth queue and writes are  *)
(*                  dispatched to main. This is what the code does today.   *)
(* "writesOnMain" - the tempting minimal fix: make sure every WRITE is on   *)
(*                  main, but leave reads where they are.                   *)
(* "mainAtomic"   - the whole read-decide-write runs in one main-queue      *)
(*                  block.                                                  *)
(* "serialQueue"  - the whole operation runs on one dedicated serial queue  *)
(*                  (equivalently, inside one actor).                       *)
(***************************************************************************)
ReadQueue ==
    CASE Discipline = "current"      -> "ble"
      [] Discipline = "writesOnMain" -> "ble"
      [] Discipline = "mainAtomic"   -> "main"
      [] Discipline = "serialQueue"  -> "state"

WriteQueue ==
    CASE Discipline = "current"      -> "main"
      [] Discipline = "writesOnMain" -> "main"
      [] Discipline = "mainAtomic"   -> "main"
      [] Discipline = "serialQueue"  -> "state"

\* Whether read and write are one indivisible block.
Atomic == Discipline \in {"mainAtomic", "serialQueue"}

QueueOf(p) ==
    CASE p = "reading" -> ReadQueue
      [] p = "held"    -> ReadQueue     \* holding a snapshot between the halves
      [] p = "writing" -> WriteQueue
      [] OTHER         -> "none"

\* An agent is touching the dictionary while reading or writing. Holding a
\* snapshot between the two halves is NOT contact -- that is the window in
\* which someone else's write can be lost.
Touching(a) == phase[a] \in {"reading", "writing"}

-----------------------------------------------------------------------------
TypeOK ==
    /\ counter \in 0..MaxOps
    /\ phase \in [Agents -> {"idle", "reading", "held", "writing", "done"}]
    /\ snapshot \in [Agents -> 0..MaxOps]
    /\ completed \in 0..MaxOps

Init ==
    /\ counter = 0
    /\ phase = [a \in Agents |-> "idle"]
    /\ snapshot = [a \in Agents |-> 0]
    /\ completed = 0

-----------------------------------------------------------------------------
\* A serial queue admits one agent at a time; different queues run in parallel.
QueueFree(q, a) ==
    \A other \in Agents \ {a}: ~(Touching(other) /\ QueueOf(phase[other]) = q)

(***************************************************************************)
(* Non-atomic disciplines: read, release, then write later. The gap between *)
(* BeginRead and Write is where the retry counter was lost --               *)
(* BLEManager.swift:959 read on the CoreBluetooth queue and :966 applied    *)
(* snapshot+1 inside a later main-queue block.                             *)
(***************************************************************************)
BeginRead(a) ==
    /\ ~Atomic
    /\ phase[a] = "idle"
    /\ QueueFree(ReadQueue, a)
    /\ phase' = [phase EXCEPT ![a] = "reading"]
    /\ UNCHANGED <<counter, snapshot, completed>>

EndRead(a) ==
    /\ ~Atomic
    /\ phase[a] = "reading"
    /\ snapshot' = [snapshot EXCEPT ![a] = counter]
    /\ phase' = [phase EXCEPT ![a] = "held"]
    /\ UNCHANGED <<counter, completed>>

BeginWrite(a) ==
    /\ ~Atomic
    /\ phase[a] = "held"
    /\ QueueFree(WriteQueue, a)
    /\ phase' = [phase EXCEPT ![a] = "writing"]
    /\ UNCHANGED <<counter, snapshot, completed>>

EndWrite(a) ==
    /\ ~Atomic
    /\ phase[a] = "writing"
    /\ counter' = snapshot[a] + 1        \* the decision uses the earlier read
    /\ phase' = [phase EXCEPT ![a] = "done"]
    /\ completed' = completed + 1
    /\ UNCHANGED snapshot

(***************************************************************************)
(* Atomic disciplines: the whole read-decide-write is one critical section, *)
(* so no other agent can interleave within it.                             *)
(***************************************************************************)
AtomicBegin(a) ==
    /\ Atomic
    /\ phase[a] = "idle"
    /\ QueueFree(ReadQueue, a)
    /\ phase' = [phase EXCEPT ![a] = "writing"]
    /\ snapshot' = [snapshot EXCEPT ![a] = counter]
    /\ UNCHANGED <<counter, completed>>

AtomicEnd(a) ==
    /\ Atomic
    /\ phase[a] = "writing"
    /\ counter' = snapshot[a] + 1
    /\ phase' = [phase EXCEPT ![a] = "done"]
    /\ completed' = completed + 1
    /\ UNCHANGED snapshot

-----------------------------------------------------------------------------
Next ==
    \E a \in Agents:
        \/ BeginRead(a) \/ EndRead(a) \/ BeginWrite(a) \/ EndWrite(a)
        \/ AtomicBegin(a) \/ AtomicEnd(a)

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
\*                              PROPERTIES

(***************************************************************************)
(* Swift's Dictionary is not thread-safe: two threads touching it at once,  *)
(* with at least one writing, is undefined behaviour rather than merely a   *)
(* stale read. Agents on the same serial queue cannot overlap; agents on    *)
(* different queues can.                                                    *)
(***************************************************************************)
NoDataRace ==
    \A a, b \in Agents:
        (a # b /\ Touching(a) /\ Touching(b))
            => (QueueOf(phase[a]) = QueueOf(phase[b]))

(***************************************************************************)
(* Every completed operation must be reflected in the result. This is the   *)
(* retry-counter bug generalised: two failures both read n and both write   *)
(* n+1, so the counter never advances and the camera retries forever.       *)
(***************************************************************************)
NoLostUpdate ==
    counter >= completed

\* All operations eventually finish and every one of them counts.
AllOperationsCount ==
    <>[](completed = MaxOps /\ counter = MaxOps)

=============================================================================
