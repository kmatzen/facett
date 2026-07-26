------------------------ MODULE PacketReassemblyFixed ------------------------
(***************************************************************************)
(* The repaired reassembler.  Three changes:                               *)
(*                                                                         *)
(*  FIX 1: buffers are keyed by (peripheral, CHARACTERISTIC) rather than   *)
(*         (peripheral, queryID).  Per the GoPro spec, accumulation is a   *)
(*         per-characteristic context and each characteristic carries one  *)
(*         message at a time -- so routing becomes deterministic and the   *)
(*         "most recently touched buffer" heuristic disappears entirely.   *)
(*         This is what actually closes FragmentIntegrity: keying by       *)
(*         queryID invented concurrency that the protocol does not have,   *)
(*         while ignoring the concurrency it DOES have (0x0077 query       *)
(*         responses and 0x0075 settings responses arrive independently    *)
(*         and both fed one buffer set).                                   *)
(*                                                                         *)
(*  FIX 2: the 4-bit continuation sequence counter is parsed and checked.  *)
(*         A gap discards the message in progress.                         *)
(*                                                                         *)
(*  FIX 3: timed-out buffers are discarded, never delivered.               *)
(*                                                                         *)
(* Sequence validation alone would NOT have closed FragmentIntegrity: two  *)
(* messages interleaved at the same fragment position carry the SAME       *)
(* counter value, so the check cannot tell them apart.  FIX 1 is doing     *)
(* the real work; FIX 2 catches drops and duplicates.                      *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Peripherals,   \* connected cameras
    Channels,      \* notify characteristics (0x0077 query, 0x0075 settings)
    Queries,       \* query IDs, used only to tag message identity
    MaxFrags,
    MaxClock

Key  == [p: Peripherals, ch: Channels]
Frag == [p: Peripherals, ch: Channels, q: Queries, idx: 0..MaxFrags]

NoDelivery == [none |-> TRUE]

VARIABLES
    buffer, expected, active, bufQ, seqNext,
    txOpen, txQ, txSent, txTotal,
    clock, lastDelivery

vars == <<buffer, expected, active, bufQ, seqNext,
          txOpen, txQ, txSent, txTotal, clock, lastDelivery>>

Delivery == [key: Key, q: Queries, frags: Seq(Frag),
             appliedTo: SUBSET Peripherals, complete: BOOLEAN]

TypeOK ==
    /\ active \subseteq Key
    /\ buffer   \in [Key -> Seq(Frag)]
    /\ expected \in [Key -> 0..MaxFrags]
    /\ bufQ     \in [Key -> Queries]
    /\ seqNext  \in [Key -> 0..MaxFrags]
    /\ txOpen \in [Key -> BOOLEAN]
    /\ txQ    \in [Key -> Queries]
    /\ txSent \in [Key -> 0..MaxFrags]
    /\ txTotal \in [Key -> 0..MaxFrags]
    /\ clock \in 0..MaxClock
    /\ lastDelivery \in {NoDelivery} \cup Delivery

Init ==
    /\ active = {}
    /\ buffer   = [k \in Key |-> <<>>]
    /\ expected = [k \in Key |-> 0]
    /\ bufQ     = [k \in Key |-> CHOOSE q \in Queries: TRUE]
    /\ seqNext  = [k \in Key |-> 0]
    /\ txOpen = [k \in Key |-> FALSE]
    /\ txQ    = [k \in Key |-> CHOOSE q \in Queries: TRUE]
    /\ txSent = [k \in Key |-> 0]
    /\ txTotal = [k \in Key |-> 0]
    /\ clock = 0
    /\ lastDelivery = NoDelivery

-----------------------------------------------------------------------------
\* A start packet replaces any buffer in progress on this characteristic.
\* (Now an explicit, logged discard rather than a silent overwrite.)
StartPacket(p, ch, q) ==
    LET k == [p |-> p, ch |-> ch] IN
    /\ ~txOpen[k]
    /\ clock < MaxClock
    /\ \E total \in 1..MaxFrags:
         /\ txTotal' = [txTotal EXCEPT ![k] = total]
         /\ expected' = [expected EXCEPT ![k] = total]
         /\ bufQ' = [bufQ EXCEPT ![k] = q]
         /\ txQ'  = [txQ EXCEPT ![k] = q]
         /\ LET frags == <<[p |-> p, ch |-> ch, q |-> q, idx |-> 0]>> IN
            /\ buffer' = [buffer EXCEPT ![k] = frags]
            /\ IF 1 >= total
               THEN /\ active' = active \ {k}
                    /\ txOpen' = [txOpen EXCEPT ![k] = FALSE]
                    /\ txSent' = [txSent EXCEPT ![k] = 0]
                    /\ seqNext' = [seqNext EXCEPT ![k] = 0]
                    /\ lastDelivery' = [key |-> k, q |-> q, frags |-> frags,
                                        appliedTo |-> {p}, complete |-> TRUE]
               ELSE /\ active' = active \cup {k}
                    /\ txOpen' = [txOpen EXCEPT ![k] = TRUE]
                    /\ txSent' = [txSent EXCEPT ![k] = 1]
                    /\ seqNext' = [seqNext EXCEPT ![k] = 1]
                    /\ UNCHANGED lastDelivery
    /\ clock' = clock + 1

(***************************************************************************)
(* Continuation routing is now deterministic: the buffer for the           *)
(* characteristic the packet arrived on.  The sequence counter is checked; *)
(* a mismatch discards the message in progress.                            *)
(***************************************************************************)
SendContinuation(p, ch) ==
    LET k == [p |-> p, ch |-> ch] IN
    /\ txOpen[k]
    /\ txSent[k] < txTotal[k]
    /\ clock < MaxClock
    /\ clock' = clock + 1
    /\ txSent' = [txSent EXCEPT ![k] = @ + 1]
    /\ IF k \notin active
       THEN \* no buffer in progress -- continuation is dropped
            /\ UNCHANGED <<buffer, expected, active, bufQ, seqNext,
                           txOpen, txQ, txTotal, lastDelivery>>
       ELSE LET seq  == txSent[k]
                frag == [p |-> p, ch |-> ch, q |-> txQ[k], idx |-> seq]
                buf  == Append(buffer[k], frag)
            IN IF seq # seqNext[k]
               THEN \* FIX 2: sequence gap -- discard the message in progress
                    /\ active' = active \ {k}
                    /\ txOpen' = [txOpen EXCEPT ![k] = FALSE]
                    /\ UNCHANGED <<buffer, expected, bufQ, seqNext, txQ,
                                   txTotal, lastDelivery>>
               ELSE /\ buffer' = [buffer EXCEPT ![k] = buf]
                    /\ seqNext' = [seqNext EXCEPT ![k] = @ + 1]
                    /\ IF Len(buf) >= expected[k]
                       THEN /\ active' = active \ {k}
                            /\ txOpen' = [txOpen EXCEPT ![k] = FALSE]
                            /\ lastDelivery' = [key |-> k, q |-> bufQ[k],
                                                frags |-> buf,
                                                appliedTo |-> {p},
                                                complete |-> TRUE]
                       ELSE /\ UNCHANGED <<active, txOpen>>
                            /\ UNCHANGED lastDelivery
                    /\ UNCHANGED <<expected, bufQ, txQ, txTotal>>

\* The radio drops a fragment: the camera advances but nothing arrives.
\* This is what FIX 2 exists to catch.
LoseFragment(p, ch) ==
    LET k == [p |-> p, ch |-> ch] IN
    /\ txOpen[k]
    /\ txSent[k] < txTotal[k]
    /\ txSent' = [txSent EXCEPT ![k] = @ + 1]
    /\ UNCHANGED <<buffer, expected, active, bufQ, seqNext,
                   txOpen, txQ, txTotal, clock, lastDelivery>>

\* FIX 3: a timed-out buffer is discarded, not delivered.
Timeout(k) ==
    /\ k \in active
    /\ active' = active \ {k}
    /\ txOpen' = [txOpen EXCEPT ![k] = FALSE]
    /\ UNCHANGED <<buffer, expected, bufQ, seqNext, txQ, txSent,
                   txTotal, clock, lastDelivery>>

-----------------------------------------------------------------------------
Next ==
    \/ \E p \in Peripherals, ch \in Channels:
         \/ \E q \in Queries: StartPacket(p, ch, q)
         \/ SendContinuation(p, ch)
         \/ LoseFragment(p, ch)
    \/ \E k \in Key: Timeout(k)

Spec == Init /\ [][Next]_vars

StateConstraint == clock <= MaxClock

-----------------------------------------------------------------------------
FragmentIntegrity ==
    lastDelivery = NoDelivery \/
    \A i \in DOMAIN lastDelivery.frags:
        /\ lastDelivery.frags[i].p  = lastDelivery.key.p
        /\ lastDelivery.frags[i].ch = lastDelivery.key.ch
        /\ lastDelivery.frags[i].q  = lastDelivery.q

CorrectAttribution ==
    lastDelivery = NoDelivery \/ lastDelivery.appliedTo = {lastDelivery.key.p}

NoPartialDelivery ==
    lastDelivery = NoDelivery \/ lastDelivery.complete

\* Fragments of a delivered message are contiguous and in order.
NoSequenceGap ==
    lastDelivery = NoDelivery \/
    \A i \in DOMAIN lastDelivery.frags: lastDelivery.frags[i].idx = i - 1

=============================================================================
