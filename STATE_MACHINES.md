# State Machines

Facett uses several implicit state machines to manage complex workflows. This document describes the states, transitions, and interactions — see the source code for implementation details.

## 1. BLE Device Lifecycle

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

## 2. Camera Operational Status

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Initializing   │───▶│     Ready       │───▶│    Recording    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │      Busy       │    │   Overheating   │
                       └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Low Battery   │    │ Settings Mismatch│
                       └─────────────────┘    └─────────────────┘
```

### Priority Order (highest → lowest)

1. **Overheating** — `isOverheating == true`
2. **No SD Card** — `sdCardRemaining` is nil or 0
3. **Low Battery** — `batteryLevel <= 1`
4. **Recording** — `isEncoding == true`
5. **Settings Mismatch** — camera settings differ from target config
6. **Ready** — `isReady == true`
7. **Error** — `isReady == false` (catch-all)
8. **Initializing** — `hasReceivedInitialStatus == false`

See `CameraGroup.getCameraStatus(_:bleManager:)` for the implementation.

## 3. Camera Group Status

Aggregate status across all cameras in a group.

### Priority Order (highest → lowest)

1. **Error** — any camera has an error
2. **Recording** — any camera is recording
3. **Connecting** — any camera is connecting
4. **Initializing** — any camera is initializing
5. **Ready** — all cameras are ready
6. **Settings Mismatch** — some cameras disconnected or settings differ
7. **Disconnected** — all cameras disconnected

See `GroupStatus.overallStatus` for the implementation.

## 4. Control

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  No Control     │───▶│ Claiming Control│───▶│  Has Control    │
│(hasControl=false)│   │                 │   │(hasControl=true) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │  Lost Control   │    │Releasing Control│
         │              │(controlId != 2) │    │                 │
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

- Must have control (`hasControl = true`, `cameraControlId = 2`) to send recording or settings commands
- Control is automatically reclaimed when lost

## 5. Settings Synchronization

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Synced      │───▶│    Syncing      │───▶│   Validating    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │    Mismatch     │    │      Error      │
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

- Cannot sync while recording
- Must have control to send settings
- Mismatch detection compares critical settings (resolution, FPS, auto power down, GPS, hypersmooth, quick capture)

## 6. Command Response

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Command Sent   │───▶│  Response Wait  │───▶│Response Received│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │    Timeout      │
                       └─────────────────┘
```

- Commands tracked in `pendingCommands` until response or timeout (3–5 seconds)

## 7. Straggler Connection Management

Handles cameras that fail to connect during bulk "Connect All" operations.

- **Retry interval**: 15 seconds
- **Max retries**: 5 per straggler
- Stragglers are abandoned after max retries and removed from target set

## 8. Sleep / Power Down

1. Release control → 0.5 s delay → send sleep/power-down command
2. Wait up to 3 seconds for response
3. Disconnect (on response or timeout)

Tracked via `pendingSleepCommands` / `pendingPowerDownCommands` sets.

## State Machine Interactions

1. **Connection** affects **Operational Status** — must be connected to be ready
2. **Control** affects **Sync** — must have control to send settings
3. **Recording** affects **Sync** — cannot sync while recording
4. **Stragglers** affect **Group Status** — stragglers prevent group from being fully ready
5. **Commands** affect **All** — commands can change any camera state

## Debugging Tips

1. Verify the device is in the correct collection (`discoveredGoPros`, `connectingGoPros`, `connectedGoPros`)
2. Check `hasControl`, `hasReceivedInitialStatus`, `isReady`, `isEncoding`
3. Verify query timers are running for connected devices
4. Check `pendingCommands` for stuck commands
5. Check retry counts and straggler state for bulk operations

See `StateMachineTests.swift` for comprehensive test coverage.
