--------------------------- MODULE StateQueueOrdering ---------------------------
(***************************************************************************)
(* Does `onStateQueue` preserve the order in which operations were issued?  *)
(*                                                                         *)
(* ConnectionConcurrency.tla establishes that the whole read-decide-write   *)
(* must run as one block on one queue. It says nothing about the ORDER in   *)
(* which those blocks run relative to each other, and the helper introduced *)
(* to implement that discipline makes a choice about exactly that:          *)
(*                                                                         *)
(*     func onStateQueue(_ work: @escaping () -> Void) {                    *)
(*         if Thread.isMainThread { work() }          // inline            *)
(*         else { DispatchQueue.main.async(execute: work) }                 *)
(*     }                                                                    *)
(*                                                                         *)
(* Running inline when already on main was chosen to keep main-thread       *)
(* callers synchronous. That reasoning optimises for synchronicity at the   *)
(* possible cost of global ordering, which is worth checking rather than    *)
(* assuming: work issued earlier from the CoreBluetooth queue is still      *)
(* queued while a later main-thread caller executes immediately.            *)
(*                                                                         *)
(*   "inline"      - the shipped helper.                                    *)
(*   "alwaysAsync" - always dispatch, so every block goes through one FIFO. *)
(***************************************************************************)
EXTENDS Naturals, Sequences

CONSTANTS
    Mode,     \* "inline" | "alwaysAsync"
    MaxOps    \* bound on operations issued, to keep TLC finite

VARIABLES
    issued,   \* operations in the order they were issued (real-time order)
    pending,  \* operations dispatched to main and not yet run
    applied,  \* operations in the order their effects actually landed
    nextId

vars == <<issued, pending, applied, nextId>>

Ops == 1..MaxOps

TypeOK ==
    /\ issued \in Seq(Ops)
    /\ pending \in Seq(Ops)
    /\ applied \in Seq(Ops)
    /\ nextId \in 1..(MaxOps + 1)

Init ==
    /\ issued = <<>>
    /\ pending = <<>>
    /\ applied = <<>>
    /\ nextId = 1

-----------------------------------------------------------------------------
(***************************************************************************)
(* A caller issues a state operation from one of the two queues. Under      *)
(* "inline" a main-thread caller's work lands immediately, overtaking       *)
(* anything the CoreBluetooth queue dispatched earlier.                     *)
(***************************************************************************)
Issue(q) ==
    /\ nextId <= MaxOps
    /\ issued' = Append(issued, nextId)
    /\ nextId' = nextId + 1
    /\ IF Mode = "inline" /\ q = "main"
       THEN /\ applied' = Append(applied, nextId)
            /\ UNCHANGED pending
       ELSE /\ pending' = Append(pending, nextId)
            /\ UNCHANGED applied

\* The main queue runs the next dispatched block.
Drain ==
    /\ pending # <<>>
    /\ applied' = Append(applied, Head(pending))
    /\ pending' = Tail(pending)
    /\ UNCHANGED <<issued, nextId>>

Next ==
    \/ \E q \in {"ble", "main"}: Issue(q)
    \/ Drain

Spec == Init /\ [][Next]_vars /\ WF_vars(Drain)

-----------------------------------------------------------------------------
IsPrefix(s, t) ==
    /\ Len(s) <= Len(t)
    /\ \A i \in 1..Len(s): s[i] = t[i]

(***************************************************************************)
(* Effects must land in the order the operations were issued. If they do    *)
(* not, two callers racing over the same camera can observe each other's    *)
(* state in the wrong order even though every individual block is atomic -- *)
(* atomicity of each block does not imply a consistent order between them.  *)
(***************************************************************************)
AppliedInIssueOrder == IsPrefix(applied, issued)

\* Everything issued eventually lands. Stated as "applied catches up with
\* issued infinitely often" rather than "all MaxOps are applied": Issue is not
\* a fair action, so a behaviour that simply never issues anything would
\* otherwise fail this for reasons that say nothing about the queue.
PendingAlwaysDrains == []<>(Len(applied) = Len(issued))

=============================================================================
