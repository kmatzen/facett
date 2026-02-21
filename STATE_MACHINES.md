# State Machines Documentation

This document provides a comprehensive and accurate description of all state machines in the GoPro Configurator app, based on the actual code implementation.

## Overview

The GoPro Configurator app uses several implicit state machines to manage complex workflows:

1. **BLE Device Lifecycle State Machine** - Manages device discovery, connection, and disconnection
2. **Camera Operational Status State Machine** - Tracks individual camera operational states
3. **Camera Group Status State Machine** - Manages group-level status based on member cameras
4. **Control State Machine** - Manages camera control acquisition and loss
5. **Settings Synchronization State Machine** - Handles settings sync across cameras
6. **Command Response State Machine** - Tracks BLE command responses and timeouts
7. **Straggler Connection Management State Machine** - Handles failed connections during bulk operations
8. **Sleep/Power Down State Machine** - Manages graceful disconnection

## 1. BLE Device Lifecycle State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Discovered    │───▶│   Connecting    │───▶│   Connected     │
│(discoveredGoPros)│   │(connectingGoPros)│   │(connectedGoPros)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │   Failed        │    │  Disconnected   │
         │              │(max retries)    │    │(connection lost)│
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

### State Transitions

#### **Discovered State**
- **Collection**: `discoveredGoPros`
- **Entry**: Device discovered via BLE scan
- **Exit**: Connection attempt initiated
- **Actions**: Device available for connection

#### **Connecting State**
- **Collection**: `connectingGoPros`
- **Entry**: `connectToGoPro()` called
- **Exit**: Connection succeeds or fails
- **Actions**:
  - Connection retry logic active
  - UI shows connecting animation
  - Retry count tracking

#### **Connected State**
- **Collection**: `connectedGoPros`
- **Entry**: BLE connection established
- **Exit**: Device disconnects
- **Actions**:
  - Status queries active
  - Command sending enabled
  - Settings synchronization possible

#### **Failed State**
- **Entry**: Max retry attempts reached
- **Exit**: Manual retry or device rediscovery
- **Actions**: Device moved back to discovered state

#### **Disconnected State**
- **Entry**: Connection lost or device powered off
- **Exit**: Device rediscovery
- **Actions**: Device moved back to discovered state

### Implementation Details

```swift
// Connection retry logic
private var connectionRetryCount: [UUID: Int] = [:]
private var connectionRetryTimers: [UUID: Timer] = [:]
private let maxRetryAttempts = 3
private let retryDelay: TimeInterval = 2.0

// State collections
@Published var discoveredGoPros: [UUID: GoPro] = [:]
@Published var connectingGoPros: [UUID: GoPro] = [:]
@Published var connectedGoPros: [UUID: GoPro] = [:]
```

## 2. Camera Operational Status State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Initializing   │───▶│     Ready       │───▶│    Recording    │
│(hasReceivedInitialStatus=false)│(hasReceivedInitialStatus=true)│(isEncoding=true)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Error       │    │      Busy       │    │   Overheating   │
│(isReady=false)  │    │(isBusy=true)    │    │(isOverheating=true)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Low Battery    │    │   No SD Card    │    │ Settings Mismatch│
│(batteryLevel≤1) │    │(sdCardRemaining=0)│(settings don't match)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### State Priority Order (Highest to Lowest)

1. **Overheating** - `isOverheating == true`
2. **No SD Card** - `sdCardRemaining == nil || sdCardRemaining == 0`
3. **Low Battery** - `batteryLevel <= 1`
4. **Recording** - `isEncoding == true`
5. **Settings Mismatch** - Settings don't match target configuration
6. **Ready** - `isReady == true`
7. **Error** - `isReady == false` (catch-all)
8. **Initializing** - `hasReceivedInitialStatus == false`

### Implementation Details

```swift
func getCameraStatus(_ camera: GoPro, bleManager: BLEManager) -> CameraStatus {
    // Priority 1: Initializing
    if !camera.hasReceivedInitialStatus {
        return .initializing
    }

    // Priority 2: Overheating
    if camera.settings.isOverheating == true {
        return .overheating
    }

    // Priority 3: No SD Card
    if camera.settings.sdCardRemaining == nil || camera.settings.sdCardRemaining == 0 {
        return .noSDCard
    }

    // Priority 4: Low Battery
    if let batteryLevel = camera.settings.batteryLevel, batteryLevel <= 1 {
        return .lowBattery
    }

    // Priority 5: Recording
    if camera.settings.isEncoding == true {
        return .recording
    }

    // Priority 6: Settings Mismatch
    if hasSettingsMismatch(camera, bleManager: bleManager) {
        return .settingsMismatch
    }

    // Priority 7: Ready
    if camera.settings.isReady == true {
        return .ready
    }

    // Priority 8: Error (catch-all)
    return .error
}
```

### State Properties

#### **Initializing State**
- **Condition**: `hasReceivedInitialStatus = false`
- **Entry**: Device first connects
- **Exit**: First status response received
- **Actions**: Waiting for initial status query response

#### **Ready State**
- **Condition**: `hasReceivedInitialStatus = true` AND `isReady = true`
- **Actions**:
  - Can receive commands
  - Can have settings applied
  - Can start/stop recording
  - Periodic status monitoring active

#### **Recording State**
- **Condition**: `isEncoding = true`
- **Actions**:
  - Cannot have settings changed
  - Recording indicator active
  - Status queries continue
  - Settings queries suspended

#### **Busy State**
- **Condition**: `isBusy = true`
- **Actions**:
  - Commands queued, not sent
  - Status queries continue
  - Temporary state during command processing

#### **Error States**
- **Overheating**: `isOverheating = true`
- **Cold**: `isCold = true`
- **SD Card Error**: `hasSDCardWriteSpeedError = true`
- **Low Battery**: `batteryLevel < 2`

## 3. Camera Group Status State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Disconnected  │───▶│   Connecting    │───▶│    Ready        │
│(all cameras disconnected)│(any camera connecting)│(all cameras ready)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │   Initializing  │    │   Recording     │
         │              │(any camera initializing)│(any camera recording)│
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

### Group Status Priority Order (Highest to Lowest)

1. **Error** - Any camera has error status
2. **Recording** - Any camera is recording
3. **Connecting** - Any camera is connecting
4. **Initializing** - Any camera is initializing
5. **Ready** - All cameras are ready
6. **Settings Mismatch** - Some cameras disconnected or settings don't match
7. **Disconnected** - All cameras disconnected

### Implementation Details

```swift
var overallStatus: CameraStatus {
    if errorCameras > 0 {
        return .error
    } else if disconnectedCameras == totalCameras {
        return .disconnected
    } else if recordingCameras > 0 {
        return .recording
    } else if connectingCameras > 0 {
        return .connecting
    } else if initializingCameras > 0 {
        return .initializing
    } else if readyCameras == totalCameras {
        return .ready
    } else if disconnectedCameras > 0 {
        return .settingsMismatch
    } else {
        return .settingsMismatch
    }
}
```

### Group Status Properties

```swift
struct GroupStatus {
    let totalCameras: Int
    let readyCameras: Int
    let errorCameras: Int
    let disconnectedCameras: Int
    let recordingCameras: Int
    let connectingCameras: Int
    let initializingCameras: Int
}
```

## 4. Control State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  No Control     │───▶│ Claiming Control│───▶│  Has Control    │
│(hasControl=false)│   │(claimControl sent)│   │(hasControl=true)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │   Lost Control  │    │ Releasing Control│
         │              │(cameraControlId!=2)│   │(releaseControl sent)│
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

### Control States

#### **No Control State**
- **Condition**: `hasControl = false`
- **Actions**: Cannot send recording or settings commands

#### **Claiming Control State**
- **Entry**: `claimControl()` called
- **Actions**: Send control claim command, wait for response

#### **Has Control State**
- **Condition**: `hasControl = true` AND `cameraControlId = 2`
- **Actions**: Can send all commands (recording, settings, etc.)

#### **Lost Control State**
- **Entry**: `cameraControlId` response indicates loss of control
- **Actions**: Automatically attempt to reclaim control

### Implementation Details

```swift
// Control assertion
assert(gopro.hasControl, "Attempted to send a command requiring control without having it.")

// Control acquisition
gopro.hasControl = true

// Control loss
gopro.hasControl = false
```

## 5. Settings Synchronization State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Synced        │───▶│   Syncing       │───▶│   Validating    │
│(all cameras match)│   │(settings being sent)│(checking results)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │   Mismatch      │    │     Error       │
         │              │(settings differ)│    │(sync failed)    │
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

### Settings Mismatch Detection

```swift
private func hasSettingsMismatch(_ camera: GoPro, bleManager: BLEManager) -> Bool {
    // Skip settings mismatch checks for recording cameras
    if camera.settings.isEncoding == true {
        return false
    }

    let targetSettings = configManager.getTargetSettings(for: activeGroup)

    // Check critical settings only
    if camera.settings.videoResolution != targetSettings.videoResolution {
        return true
    }
    if camera.settings.framesPerSecond != targetSettings.framesPerSecond {
        return true
    }
    if camera.settings.autoPowerDown != targetSettings.autoPowerDown {
        return true
    }
    if camera.settings.gps != targetSettings.gps {
        return true
    }
    if camera.settings.hypersmooth != targetSettings.hypersmooth {
        return true
    }
    if camera.settings.quickCapture != targetSettings.quickCapture {
        return true
    }

    return false
}
```

## 6. Command Response State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Command Sent   │───▶│  Response Wait  │───▶│  Response Received│
│(command queued) │   │(pendingCommands)│   │(response processed)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │   Timeout       │              │
         │              │(command timeout)│              │
         │              └─────────────────┘              │
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

### Command States

- **Command Sent**: Command written to BLE characteristic
- **Response Wait**: Waiting for response in `pendingCommands`
- **Response Received**: Response processed, command removed from pending
- **Timeout**: Command removed from pending after timeout (3-5 seconds)

### Implementation Details

```swift
// Command tracking
private var pendingCommands: [UUID: [Command]] = [:]

// Timeout handling
private var timeoutCheckTimer: Timer?

// Command response processing
func processCommandResponse(_ response: Data, from peripheral: CBPeripheral) {
    // Process response and remove from pending
}
```

## 7. Straggler Connection Management State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Target Set     │───▶│  Straggler      │───▶│   Retrying      │
│(targetConnectedCameras)│(not connected/connecting)│(stragglerRetryCount)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Connected     │    │   Max Retries   │    │   Abandoned     │
│(successfully connected)│(stragglerRetryCount>=5)│(removed from targets)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Straggler Management

- **Retry Interval**: 15 seconds between attempts
- **Max Retries**: 5 attempts per straggler
- **Timeout**: Straggler timer runs until all targets connected or abandoned
- **Actions**: Automatic reconnection attempts for failed cameras

### Implementation Details

```swift
// Straggler tracking
private var stragglerRetryTimer: Timer?
private var stragglerRetryCount: [UUID: Int] = [:]
private let maxStragglerRetries = 5
private let stragglerRetryInterval: TimeInterval = 15.0
private var targetConnectedCameras: Set<UUID> = []
```

## 8. Sleep/Power Down State Machine

### State Definitions

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Normal         │───▶│  Sleep Command  │───▶│  Disconnecting  │
│(connected)      │   │(pendingSleepCommands)│(waiting for response)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │   Timeout       │    │   Disconnected  │
         │              │(3 second timeout)│   │(connection closed)│
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

### Sleep/Power Down Process

1. **Release Control**: Send `releaseControl()` command
2. **Wait**: 0.5 second delay
3. **Send Sleep/Power Command**: Add to `pendingSleepCommands` or `pendingPowerDownCommands`
4. **Wait for Response**: Up to 3 seconds
5. **Disconnect**: Either on response or timeout

### Implementation Details

```swift
// Sleep/power down tracking
private var pendingSleepCommands: Set<UUID> = []
private var pendingPowerDownCommands: Set<UUID> = []

// Sleep command process
func sendSleepCommand(to cameraId: UUID) {
    // Release control first
    releaseControl(for: cameraId)

    // Wait 0.5 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        // Send sleep command
        self.pendingSleepCommands.insert(cameraId)
        // Start 3-second timeout
    }
}
```

## State Machine Interactions

These state machines interact in complex ways:

1. **Connection State** affects **Operational State**: Camera must be connected to be ready
2. **Control State** affects **Sync State**: Must have control to send settings
3. **Recording State** affects **Sync State**: Cannot sync while recording
4. **Straggler State** affects **Group State**: Stragglers prevent group from being ready
5. **Command State** affects **All States**: Commands can change any camera state

## Debugging State Machines

To debug state machine issues:

1. **Check Collections**: Verify device is in correct collection (`discoveredGoPros`, `connectingGoPros`, `connectedGoPros`)
2. **Check Properties**: Verify `hasControl`, `hasReceivedInitialStatus`, `isReady`, etc.
3. **Check Timers**: Verify query timers are running for connected devices
4. **Check Pending Commands**: Verify commands are being processed and removed from pending
5. **Check Retry Counts**: Verify retry logic is working correctly
6. **Check Straggler State**: Verify straggler management for bulk operations

## Testing State Machines

The state machines are tested comprehensively with:

1. **Unit Tests**: Individual state transitions and conditions
2. **Integration Tests**: State machine interactions
3. **Edge Case Tests**: Nil values, empty groups, multiple conditions
4. **Simulated Data**: Mock cameras with various states
5. **Priority Tests**: Verify correct state priority ordering

See `StateMachineTests.swift` for comprehensive test coverage.
