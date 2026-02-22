# State Machines & Status Logic

This document describes how Facett tracks device state, camera status, and command lifecycle. Some of these are true state machines with tracked transitions; others are stateless priority evaluations computed on the fly.

## 1. BLE Device Lifecycle (state machine)

Devices move between three tracked collections as their BLE connection state changes:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Discovered    │───▶│   Connecting    │───▶│   Connected     │
│(discoveredGoPros)│   │(connectingGoPros)│   │(connectedGoPros)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │     Failed      │    │  Disconnected   │
         │              │ (max retries)   │    │(connection lost) │
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

- **Discovered** — device found via BLE scan, available for connection
- **Connecting** — connection attempt in progress; retries up to 3 times with exponential backoff
- **Connected** — BLE link established; status queries and commands enabled
- **Failed** — max retries reached; device returns to Discovered on rediscovery
- **Disconnected** — connection lost; device returns to Discovered on rediscovery

## 2. Camera Operational Status (priority evaluation)

Not a state machine — computed on the fly by `CameraGroup.getCameraStatus(_:bleManager:)`. The code checks conditions top-to-bottom and returns the first match:

```
hasReceivedInitialStatus == false?  ──▶  Initializing
isOverheating == true?              ──▶  Overheating
sdCardRemaining is nil or 0?        ──▶  No SD Card
batteryLevel <= 1?                  ──▶  Low Battery
isEncoding == true?                 ──▶  Recording
settings differ from target?        ──▶  Settings Mismatch
isReady == true?                    ──▶  Ready
(none of the above)                 ──▶  Error
```

A camera can match multiple conditions simultaneously — the one listed highest wins.

## 3. Camera Group Status (priority evaluation)

Also computed on the fly by `GroupStatus.overallStatus`. Aggregates individual camera statuses:

```
any camera has error?               ──▶  Error
all cameras disconnected?           ──▶  Disconnected
any camera recording?               ──▶  Recording
any camera connecting?              ──▶  Connecting
any camera initializing?            ──▶  Initializing
all cameras ready?                  ──▶  Ready
(otherwise)                         ──▶  Settings Mismatch
```

## 4. Camera Control (boolean flag)

Each `GoPro` object has a `hasControl` boolean. It is set to `true` when a claim-control command response succeeds, and `false` when a control-loss notification arrives.

- `claimControl(for:)` sends a Protobuf command; the response handler sets `hasControl = true`
- `releaseControl(for:)` sends the release command; the response handler sets `hasControl = false`
- Control-loss notifications from the camera also set `hasControl = false`
- Commands that require control (recording, settings) check `hasControl` before sending

There is no intermediate "claiming" or "releasing" state tracked in code — the flag flips when the response arrives.

## 5. Settings Sync (fire-and-forget)

There is no settings sync state machine. The actual flow is:

1. User taps "Apply Settings" → `sendSettingsToCamerasInGroup()` writes BLE commands to each camera
2. Each camera processes the commands independently and responds
3. Camera settings are updated from responses as they arrive
4. Separately, `ConfigValidation.hasSettingsMismatch()` compares current settings to target — this is called at display time, not tracked as state

Preconditions: must have control, camera must not be recording. Compared settings: resolution, FPS, auto power down, GPS, hypersmooth, quick capture.

## 6. Command Lifecycle (state machine)

Commands are tracked in `pendingCommands: [UUID: [PendingCommand]]`:

```
Command Sent  ───▶  Waiting (in pendingCommands)  ───▶  Response Received (removed)
                              │
                              ├──▶  Timeout (retried up to 2 times, then removed)
                              │
                              └──▶  BLE error (retried or removed)
```

- Default timeout: 5 seconds
- Retry attempts: 2

## 7. Straggler Connection Management

Handles cameras that fail to connect during bulk "Connect All" operations. Tracked via `stragglerRetryCount` and a repeating timer.

- **Retry interval**: 15 seconds
- **Max retries**: 5 per straggler
- Stragglers are abandoned after max retries and removed from target set

## 8. Sleep / Power Down

A short sequential flow tracked via `pendingSleepCommands` / `pendingPowerDownCommands` sets:

1. Release control → 0.5 s delay → send sleep/power-down command
2. Wait up to 3 seconds for response
3. Disconnect (on response or timeout)

## Interactions

1. **Connection** → **Status**: must be connected to have any operational status
2. **Control** → **Settings**: must have control to send settings
3. **Recording** → **Settings**: cannot sync while recording
4. **Stragglers** → **Group Status**: stragglers prevent group from being fully ready

## Debugging Tips

1. Verify the device is in the correct collection (`discoveredGoPros`, `connectingGoPros`, `connectedGoPros`)
2. Check `hasControl`, `hasReceivedInitialStatus`, `isReady`, `isEncoding`
3. Verify query timers are running for connected devices
4. Check `pendingCommands` for stuck commands
5. Check retry counts and straggler state for bulk operations

See `StateMachineTests.swift` for test coverage of the priority evaluations.
