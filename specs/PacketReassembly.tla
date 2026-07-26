--------------------------- MODULE PacketReassembly ---------------------------
(***************************************************************************)
(* A TLA+ model of Facett's BLE multi-packet reassembler                   *)
(* (Facett/BLEPacketReconstructor.swift), together with the delivery step  *)
(* in BLEManager.startDeviceQueryTimer that consumes timed-out buffers.    *)
(*                                                                         *)
(* Modelled as written, so TLC produces counterexamples for the real       *)
(* defects.  Fragments are tagged with the (peripheral, query) they were   *)
(* actually sent for, which is what makes misrouting observable -- the     *)
(* Swift code has no such tag, which is precisely the problem.             *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Peripherals,   \* connected cameras
    Queries,       \* query IDs in flight (e.g. 0x12 settings, 0x13 status)
    MaxFrags,      \* max fragments per message
    MaxClock       \* bound on the logical clock, to keep TLC finite

Key  == [p: Peripherals, q: Queries]
Frag == [p: Peripherals, q: Queries, idx: 0..MaxFrags]

NoDelivery == [none |-> TRUE]

VARIABLES
    buffer,       \* BLEPacketReconstructor.continuationBuffer
    expected,     \* BLEPacketReconstructor.expectedMessageLength
    active,       \* which buffer keys currently exist
    lastTime,     \* BLEPacketReconstructor.lastPacketTime
    clock,        \* logical clock feeding lastTime
    txOpen,       \* camera side: is a message being transmitted for this key
    txSent,       \* how many fragments of it have been emitted
    txTotal,      \* how many fragments it will have
    lastDelivery  \* the most recent message handed to the app

vars == <<buffer, expected, active, lastTime, clock,
          txOpen, txSent, txTotal, lastDelivery>>

Delivery == [key: Key, frags: Seq(Frag), appliedTo: SUBSET Peripherals,
             complete: BOOLEAN]

TypeOK ==
    /\ active \subseteq Key
    /\ buffer   \in [Key -> Seq(Frag)]
    /\ expected \in [Key -> 0..MaxFrags]
    /\ lastTime \in [Key -> 0..MaxClock]
    /\ clock \in 0..MaxClock
    /\ txOpen \in [Key -> BOOLEAN]
    /\ txSent \in [Key -> 0..MaxFrags]
    /\ txTotal \in [Key -> 0..MaxFrags]
    /\ lastDelivery \in {NoDelivery} \cup Delivery

Init ==
    /\ active = {}
    /\ buffer   = [k \in Key |-> <<>>]
    /\ expected = [k \in Key |-> 0]
    /\ lastTime = [k \in Key |-> 0]
    /\ clock = 0
    /\ txOpen = [k \in Key |-> FALSE]
    /\ txSent = [k \in Key |-> 0]
    /\ txTotal = [k \in Key |-> 0]
    /\ lastDelivery = NoDelivery

-----------------------------------------------------------------------------
\* Active buffer keys belonging to peripheral p. The Swift code selects these
\* with `$0.hasPrefix(peripheralId)` (BLEPacketReconstructor.swift:171).
ActiveFor(p) == {k \in active: k.p = p}

(***************************************************************************)
(* handleStartPacket -- BLEPacketReconstructor.swift:126.                  *)
(*                                                                         *)
(* Note the unconditional overwrite at :146-148.  If a buffer already      *)
(* exists for this key, the in-flight partial message is silently          *)
(* discarded with no warning.                                              *)
(***************************************************************************)
StartPacket(p, q) ==
    LET k == [p |-> p, q |-> q] IN
    /\ ~txOpen[k]
    /\ clock < MaxClock
    /\ \E total \in 1..MaxFrags:
         /\ txTotal' = [txTotal EXCEPT ![k] = total]
         /\ expected' = [expected EXCEPT ![k] = total]
         /\ LET frags == <<[p |-> p, q |-> q, idx |-> 0]>> IN
            /\ buffer' = [buffer EXCEPT ![k] = frags]
            /\ IF 1 >= total
               THEN \* single-packet message completes immediately
                    /\ active' = active \ {k}
                    /\ txOpen' = [txOpen EXCEPT ![k] = FALSE]
                    /\ txSent' = [txSent EXCEPT ![k] = 0]
                    /\ lastDelivery' = [key |-> k, frags |-> frags,
                                        appliedTo |-> {p}, complete |-> TRUE]
               ELSE /\ active' = active \cup {k}
                    /\ txOpen' = [txOpen EXCEPT ![k] = TRUE]
                    /\ txSent' = [txSent EXCEPT ![k] = 1]
                    /\ UNCHANGED lastDelivery
    /\ clock' = clock + 1
    /\ lastTime' = [lastTime EXCEPT ![k] = clock + 1]

(***************************************************************************)
(* handleContinuationPacket -- BLEPacketReconstructor.swift:163.           *)
(*                                                                         *)
(* THE DEFECT: the continuation is routed to whichever buffer for this     *)
(* peripheral was touched most recently (:181), because the packet carries *)
(* no correlator the code reads.  The 4-bit sequence counter documented at *)
(* BLE_PROTOCOL.md:29 is never parsed, so neither misrouting nor a dropped *)
(* fragment is detectable.                                                 *)
(***************************************************************************)
MostRecent(p) ==
    CHOOSE k \in ActiveFor(p): \A j \in ActiveFor(p): lastTime[k] >= lastTime[j]

SendContinuation(p, q) ==
    LET src == [p |-> p, q |-> q] IN
    /\ txOpen[src]
    /\ txSent[src] < txTotal[src]
    /\ ActiveFor(p) # {}
    /\ clock < MaxClock
    /\ LET dst  == MostRecent(p)                        \* routed by recency, not by q
           frag == [p |-> p, q |-> q, idx |-> txSent[src]]
           buf  == Append(buffer[dst], frag)
       IN /\ buffer' = [buffer EXCEPT ![dst] = buf]
          /\ txSent' = [txSent EXCEPT ![src] = @ + 1]
          /\ IF Len(buf) >= expected[dst]
             THEN /\ active' = active \ {dst}
                  /\ txOpen' = [txOpen EXCEPT ![dst] = FALSE]
                  /\ lastDelivery' = [key |-> dst, frags |-> buf,
                                      appliedTo |-> {dst.p}, complete |-> TRUE]
             ELSE /\ UNCHANGED <<active, txOpen>>
                  /\ UNCHANGED lastDelivery
          /\ lastTime' = [lastTime EXCEPT ![dst] = clock + 1]
    /\ clock' = clock + 1
    /\ UNCHANGED <<expected, txTotal>>

(***************************************************************************)
(* checkTimeouts (BLEPacketReconstructor.swift:58) feeding the delivery    *)
(* loop at BLEManager.swift:2061-2063.                                     *)
(*                                                                         *)
(* THE DEFECT: the return type is (data, queryID) -- the peripheral half   *)
(* of the buffer key is discarded at :68-70.  The caller therefore applies *)
(* the partial buffer to EVERY connected camera:                           *)
(*                                                                         *)
(*     for uuid in self.connectedGoPros.keys {                             *)
(*         self.responseHandler.updateGoProStatus(uuid: uuid, with: ...)   *)
(*     }                                                                   *)
(***************************************************************************)
Timeout(k) ==
    /\ k \in active
    /\ active' = active \ {k}
    /\ txOpen' = [txOpen EXCEPT ![k] = FALSE]
    /\ lastDelivery' = [key |-> k,
                        frags |-> buffer[k],
                        appliedTo |-> Peripherals,          \* broadcast to all
                        complete |-> Len(buffer[k]) >= expected[k]]
    /\ UNCHANGED <<buffer, expected, lastTime, clock, txSent, txTotal>>

-----------------------------------------------------------------------------
Next ==
    \/ \E p \in Peripherals, q \in Queries:
         StartPacket(p, q) \/ SendContinuation(p, q)
    \/ \E k \in Key: Timeout(k)

Spec == Init /\ [][Next]_vars

StateConstraint == clock <= MaxClock

-----------------------------------------------------------------------------
\*                              PROPERTIES

\* Every fragment in a delivered message must belong to that message.
FragmentIntegrity ==
    lastDelivery = NoDelivery \/
    \A i \in DOMAIN lastDelivery.frags:
        /\ lastDelivery.frags[i].p = lastDelivery.key.p
        /\ lastDelivery.frags[i].q = lastDelivery.key.q

\* A message must be applied only to the camera that sent it.
CorrectAttribution ==
    lastDelivery = NoDelivery \/ lastDelivery.appliedTo = {lastDelivery.key.p}

\* A truncated buffer must never be handed to the app as if it were a message.
NoPartialDelivery ==
    lastDelivery = NoDelivery \/ lastDelivery.complete

=============================================================================
