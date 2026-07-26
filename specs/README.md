# Formal specs

TLA+ models of Facett's BLE layer.

**Connection state machine**

- `BLEConnection.tla` — models the code **as currently written** (`BLEManager.swift`,
  `BLEConnectionHandler.swift`). All four properties below fail; each failure is a real defect.
- `BLEConnectionFixed.tla` — the same machine with four fixes applied. All properties pass.
  These fixes are now applied to `BLEManager.swift`.

**Sleep tracking**

- `SleepState.tla` — models the sleep flag against the physical camera, under four
  designs selected by the `Variant` constant. **Every one of them fails a property.**
- `SleepVisibility.tla` — the design that works, and what `BLEDeviceStateManager` now does.

Run:

```bash
for v in original naive graced confirmed; do
  java -cp tla2tools.jar tlc2.TLC -config MC_Sleep_$v.cfg -deadlock SleepState.tla
done
java -cp tla2tools.jar tlc2.TLC -config MC_SleepVisibility.cfg -deadlock SleepVisibility.tla
```

| Design | `NoFightingOwnSleep` | `NeverPermanentlyInvisibleWhileAwake` |
|---|---|---|
| `original` — flag never actually set | ✗ | ✓ |
| `naive` — always ignore adverts while flagged | ✓ | ✗ |
| `graced` — ignore only inside a timed window | ✗ | ✓ |
| `confirmed` — clear only after observed silence | ✓ | ✗ |
| `SleepVisibility` — suppress auto-connect only | ✓ | ✓ |

The impossibility is the point: **a camera still shutting down and a camera that just
woke up emit identical advertisements.** No rule over advertisements plus elapsed time
can separate them, so every such design must choose which way to be wrong — undo the
user's sleep command, or hide the camera forever with no way to reach it (since
`connectToGoPro` requires membership in `discoveredGoPros`).

`graced` was shipped before this was modelled. TLC found its counterexample in seven
steps: the camera is still advertising when the window closes, so the app re-discovers
it mid-shutdown. The 10-second constant was a guess about hardware timing, and the
design was wrong in principle rather than merely mistuned.

The way out is to stop inferring. The old guard conflated two concerns — *don't
auto-reconnect a camera the user slept* and *don't show it* — and only the first is
required. Suppressing automatic reconnection alone satisfies both properties with no
assumption about how long shutdown takes.

One property was deliberately **not** asserted: never auto-reconnecting during
shutdown. TLC shows it conflicts with honouring manual override — the user may connect
mid-shutdown, which clears the flag, and a later auto-reconnect is then correct. Manual
override wins; see the note in `SleepVisibility.tla`.

**Packet reassembly**

- `PacketReassembly.tla` — models `BLEPacketReconstructor.swift` plus the delivery loop in
  `BLEManager.startDeviceQueryTimer`. All three properties fail.
- `PacketReassemblyFixed.tla` — the repaired design. All four properties pass.
  These fixes are now applied to `BLEPacketReconstructor.swift`.

## Running

```bash
curl -sSL -o tla2tools.jar \
  https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar

# as-written — each of these produces a counterexample trace
java -cp tla2tools.jar tlc2.TLC -config MC_MutualExclusion.cfg    BLEConnection.tla
java -cp tla2tools.jar tlc2.TLC -config MC_BoundedRetries.cfg     BLEConnection.tla
java -cp tla2tools.jar tlc2.TLC -config MC_NoOrphanedRetryState.cfg BLEConnection.tla
java -cp tla2tools.jar tlc2.TLC -config MC_Liveness.cfg           BLEConnection.tla

# fixed — both clean
java -cp tla2tools.jar tlc2.TLC -config MC_Fixed.cfg         BLEConnectionFixed.tla
java -cp tla2tools.jar tlc2.TLC -config MC_FixedLiveness.cfg BLEConnectionFixed.tla
```

Runtime is a few seconds to ~2 minutes with 2 cameras. Liveness configs use 1 camera to keep
the state graph small; the bugs they expose are per-camera, so this loses no coverage.

## Connection state concurrency

`ConnectionConcurrency.tla` answers a design question before the refactor is written:
which discipline actually makes `BLEManager`'s shared dictionaries safe? Roughly 70
accesses across nine CoreBluetooth delegate methods are involved, so this is expensive
to get wrong.

```bash
for d in current writesOnMain mainAtomic serialQueue; do
  java -cp tla2tools.jar tlc2.TLC -config MC_Conc_$d.cfg -deadlock ConnectionConcurrency.tla
done
```

| Discipline | `NoDataRace` | `NoLostUpdate` |
|---|---|---|
| `current` — read on BLE queue, write dispatched to main | ✗ | ✗ |
| `writesOnMain` — ensure every *write* is on main | ✗ | ✗ |
| `mainAtomic` — whole read-decide-write in one main block | ✓ | ✓ |
| `serialQueue` — whole operation on one serial queue / actor | ✓ | ✓ |

**The result that matters: `writesOnMain` is no better than the status quo.** Moving
writes to the main queue while leaving reads on the CoreBluetooth queue fixes neither
hazard — the read still races a concurrent write (Swift `Dictionary` is not
thread-safe, so that is undefined behaviour, not a stale read), and the decision is
still made from a value that another write can invalidate before it lands.

What determines safety is whether the whole read-decide-write is **one indivisible
block on a single queue**, not which queue the write happens on. That distinction is
easy to miss when reviewing diffs: a change that adds `DispatchQueue.main.async` around
a mutation looks like a fix and is not one.

### Ordering between blocks

`ConnectionConcurrency.tla` establishes that each read-decide-write must be one atomic
block. It says nothing about the order those blocks run in, and the helper written to
implement it made a choice about exactly that:

```bash
for m in inline alwaysAsync; do
  java -cp tla2tools.jar tlc2.TLC -config MC_Order_$m.cfg -deadlock StateQueueOrdering.tla
done
```

| `onStateQueue` implementation | `AppliedInIssueOrder` |
|---|---|
| `inline` — run directly when already on main | ✗ violated in 3 steps |
| `alwaysAsync` — always dispatch | ✓ |

The first version ran `work()` inline when the caller was already on main, to keep
main-thread callers synchronous. TLC inverts two operations immediately: work dispatched
earlier from the CoreBluetooth queue is still waiting while a later main-thread caller
executes right away.

**Atomicity of each block does not imply a consistent order between blocks.** Routing
every block through the same FIFO is what gives that, so `onStateQueue` now always
dispatches. The cost is that main-thread callers are deferred by a runloop turn; no
caller depends on the effect landing synchronously.

### Status

Both disciplines are now applied, each where it fits:

- **`mainAtomic`** for `BLEManager`'s connection dictionaries. Every CoreBluetooth-queue
  path that touched them (`didDiscover`, `didFailToConnect`, `handleConnectionSuccess`,
  the WiFi response callbacks, `setDateTime`, the device-query timer) now runs its whole
  read-decide-write in one `onStateQueue` block. `assertOnStateQueue()` traps in debug
  builds so a new off-queue reader fails immediately rather than corrupting memory
  occasionally in the field.
- **`serialQueue`** for `BLEPacketReconstructor`. Its state was touched from the
  CoreBluetooth queue (`processPacket`) and the timer queue (`checkTimeouts`) — two
  different queues. It does not drive SwiftUI, so a dedicated serial queue is cheaper
  than main and keeps packet handling off the main thread.

The reassembler change is confirmed empirically: a 4,000-iteration concurrent stress
harness runs **0 ThreadSanitizer races**, and the same harness against a build with the
serial queue removed reports `Swift access race in handleStartPacket`. That is the
model's prediction reproduced against real code.

`BLEManager` has no equivalent empirical check — exercising it needs real BLE traffic,
so its discipline rests on the model plus the debug assertions.

Two disciplines work. `mainAtomic` is the better fit for connection state: the dictionaries are
`@Published` and drive SwiftUI, so they must be touched on main regardless, and
`serialQueue` would need a second hop to main for every UI update. The model checks
clean at three concurrent agents as well as two, and the codebase contains no
`DispatchQueue.main.sync`, so the usual deadlock risk of a main-only discipline does
not apply.

## Modelling notes

Connection state is not an enum in the app — it is encoded as *which of three dictionaries* a
camera lives in (`BLEManager.swift:160`). The spec uses three independent sets rather than one
location variable, so that "camera is in two states at once" is expressible at all.

CoreBluetooth callbacks (`DidConnect`, `DidFail`) are deliberately left **unfair**: the radio is
under no obligation to ever call back. That is what makes the missing first-attempt timeout show
up as a liveness violation rather than being masked by an unrealistic fairness assumption.

`failuresProcessed` is a ghost variable — it has no counterpart in the Swift code and exists only
to state `BoundedRetries`. It is reset wherever `retryCount` is reset, so it counts retries within
a single connection episode, not over the app's lifetime.

## Properties

| Property | Meaning | As-written result |
|---|---|---|
| `MutualExclusion` | A camera is in exactly one of the three dictionaries | ✗ violated in 3 steps |
| `BoundedRetries` | At most `MaxRetries` retries per connection episode | ✗ violated (lost update) |
| `NoOrphanedRetryState` | Retry bookkeeping does not outlive its attempt | ✗ violated |
| `ScanningLive` | `connectingGoPros` empties infinitely often, so scanning resumes | ✗ violated (stutter) |
| `NoStuckConnecting` | No camera stays in `connecting` forever | ✗ violated |

## Packet reassembly

```bash
java -cp tla2tools.jar tlc2.TLC -config MC_FragmentIntegrity.cfg  PacketReassembly.tla
java -cp tla2tools.jar tlc2.TLC -config MC_CorrectAttribution.cfg PacketReassembly.tla
java -cp tla2tools.jar tlc2.TLC -config MC_NoPartialDelivery.cfg  PacketReassembly.tla
```

| Property | Meaning | Result |
|---|---|---|
| `FragmentIntegrity` | Every fragment in a message belongs to that message | ✗ violated in 5 steps |
| `CorrectAttribution` | A message is applied only to the camera that sent it | ✗ violated |
| `NoPartialDelivery` | A truncated buffer is never delivered as a message | ✗ violated |

Fragments in the model are tagged with the `(peripheral, query)` they were sent for. The Swift
code has no such tag — that absence *is* the bug, and the tag exists only so the model checker
can observe the misrouting.

The defects, and what closed them:

1. `FragmentIntegrity` — continuations were routed to whichever buffer for that peripheral was
   touched most recently, because nothing in the packet correlated it to a message.
   **Fix: key buffers by (peripheral, characteristic).** Accumulation is a per-characteristic
   context and each characteristic carries one message at a time, so routing becomes
   deterministic. Keying by query ID invented concurrency the protocol does not have, while
   ignoring the concurrency it *does* have — query responses (0x0077) and settings responses
   (0x0075) stream independently and both fed one buffer set.
2. `NoSequenceGap` — the 4-bit counter documented at `BLE_PROTOCOL.md:29` was never parsed, so a
   dropped or duplicated continuation produced a byte-shifted payload that still satisfied the
   length check and decoded as plausible-but-wrong TLV.
   **Fix: parse and validate the counter; a gap discards the message in progress.**
3. `CorrectAttribution` / `NoPartialDelivery` — `checkTimeouts` dropped the peripheral half of the
   buffer key, so `BLEManager` applied one camera's truncated buffer to every connected camera.
   **Fix: discard timed-out buffers outright** rather than force-completing them. With nothing
   delivered on timeout, the broadcast loop is gone entirely.

**Sequence validation alone would not have closed `FragmentIntegrity`.** Two messages interleaved
at the same fragment position carry the *same* counter value, so the check cannot tell them apart
— the model checker confirms the property still fails with only fix 2. Re-keying is doing the real
work; counter validation catches drops and duplicates.
