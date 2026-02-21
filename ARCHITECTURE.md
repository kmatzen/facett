# GoPro Configurator - Software Architecture Documentation

## Table of Contents
1. [Software Architecture Overview](#software-architecture-overview)
2. [State Machines](#state-machines)
3. [BLE Protocol Implementation](#ble-protocol-implementation)
4. [Testing Strategy](#testing-strategy)
5. [Data Models](#data-models)
6. [UI Architecture](#ui-architecture)
7. [Error Handling & Crash Reporting](#error-handling--crash-reporting)
8. [Performance Considerations](#performance-considerations)
9. [Security & Privacy](#security--privacy)
10. [Deployment & Distribution](#deployment--distribution)

---

## Software Architecture Overview

### High-Level Architecture

The GoPro Configurator (Facett) is built using **SwiftUI** with **MVVM (Model-View-ViewModel)** architecture pattern. The app follows a modular design with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI Views Layer                      │
├─────────────────────────────────────────────────────────────┤
│                   ViewModels & Managers                     │
├─────────────────────────────────────────────────────────────┤
│                    Business Logic Layer                     │
├─────────────────────────────────────────────────────────────┤
│                    Data Models Layer                        │
├─────────────────────────────────────────────────────────────┤
│                   Core Bluetooth Layer                      │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. **App Entry Point** (`FacettApp.swift`)
- **Purpose**: Application lifecycle management and dependency injection
- **Key Responsibilities**:
  - Initialize core managers (BLE, Config, CameraGroup)
  - Handle app state transitions (active/inactive/background)
  - Manage idle timer for continuous BLE operations
  - Initialize crash reporting system

#### 2. **BLE Manager** (`BLEManager.swift`)
- **Purpose**: Central BLE communication hub
- **Key Responsibilities**:
  - Device discovery and connection management
  - Command sending and response handling
  - Connection retry logic and error recovery
  - State synchronization across multiple cameras

#### 3. **Configuration Management** (`CameraConfig.swift`, `ConfigManager`)
- **Purpose**: Camera settings and preset management
- **Key Responsibilities**:
  - Store and retrieve camera configurations
  - Validate settings against hardware capabilities
  - Manage default and custom presets
  - Settings synchronization across camera groups

#### 4. **Camera Group Management** (`CameraGroup.swift`, `CameraGroupManager`)
- **Purpose**: Group management for multiple cameras
- **Key Responsibilities**:
  - Create and manage camera groups
  - Coordinate settings across camera groups
  - Track set status and health
  - Handle set-wide operations

### Dependency Injection Pattern

The app uses SwiftUI's `@StateObject` and `@ObservedObject` for dependency injection:

```swift
@main
struct FacettApp: App {
    @StateObject var bleManager = BLEManager()
    @StateObject var configManager = ConfigManager()
    @StateObject var cameraGroupManager: CameraGroupManager

    init() {
        let configManager = ConfigManager()
        self._configManager = StateObject(wrappedValue: configManager)
        self._cameraGroupManager = StateObject(wrappedValue: CameraGroupManager(configManager: configManager))
    }
}
```

---

## State Machines

The app implements several critical state machines that govern device connectivity, camera status, and settings synchronization. These state machines are **implicit** in the code structure rather than explicit enum-based state machines, making them crucial to understand for proper debugging and maintenance.

### 1. **BLE Device Lifecycle State Machine**

The BLE manager tracks devices across multiple collections that represent different lifecycle states:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Discovered     │───▶│   Connecting    │───▶│   Connected     │
│ (discoveredGoPros)│   │(connectingGoPros)│   │(connectedGoPros) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │   Failed        │    │   Disconnected  │
         │              │ (retry logic)   │    │ (back to discovered)│
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
```

**State Collections & Transitions**:

#### **Discovered State** (`discoveredGoPros: [UUID: GoPro]`)
- **Entry**: Device discovered via BLE scan
- **Exit**: Device moves to connecting or connected
- **Actions**: Device available for connection

#### **Connecting State** (`connectingGoPros: [UUID: GoPro]`)
- **Entry**: `connectToGoPro()` called
- **Exit**: Connection succeeds → Connected, or fails → Discovered
- **Retry Logic**: Up to 3 attempts with 2-second delays
- **Actions**: Attempting BLE connection, discovering services/characteristics

#### **Connected State** (`connectedGoPros: [UUID: GoPro]`)
- **Entry**: `didConnect` delegate called
- **Exit**: `didDisconnect` delegate called → back to Discovered
- **Actions**:
  - Claim control (`hasControl = true`)
  - Start periodic status queries (every 5 seconds)
  - Start periodic settings queries (every 20 seconds)
  - Enable notifications on response characteristics

#### **Connection Failure Handling**:
- **Retry Count**: Tracked in `connectionRetryCount: [UUID: Int]`
- **Max Retries**: 3 attempts
- **Retry Delay**: 2 seconds between attempts
- **Timeout**: Connection attempts timeout after 10 seconds
- **Final State**: After max retries → back to Discovered

### 2. **Camera Operational Status State Machine**

Each connected camera has an implicit operational status based on its `GoProSettings` properties:

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
```

**Status Properties & Conditions**:

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

### 3. **Camera Group Status State Machine**

Camera groups have computed status based on their member cameras:

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

**Group Status Logic** (from `GroupStatus.overallStatus`):
1. **Error**: Any camera has error status (overheating, no SD card, low battery, or other errors)
2. **Recording**: Any camera is recording
3. **Connecting**: Any camera is connecting
4. **Initializing**: Any camera is initializing
5. **Ready**: All cameras are ready
6. **Disconnected**: All cameras disconnected
7. **Settings Mismatch**: Some cameras disconnected or settings don't match

### 4. **Settings Synchronization State Machine**

Settings synchronization follows this implicit state flow:

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

**Sync Process States**:

#### **Synced State**
- **Condition**: All cameras have matching settings
- **Actions**: No sync operations needed

#### **Syncing State**
- **Entry**: `sendSettingsToCamerasInSet()` called
- **Actions**:
  - Send individual setting commands to each camera
  - Track pending settings responses
  - Wait for acknowledgment from each camera

#### **Validating State**
- **Entry**: Settings commands sent
- **Actions**:
  - Query all settings from cameras
  - Compare received settings with target settings
  - Check for mismatches

#### **Mismatch State**
- **Condition**: `hasSettingsMismatch()` returns true
- **Actions**:
  - Highlight mismatched cameras in UI
  - Offer manual sync options
  - Continue monitoring for changes

#### **Error State**
- **Condition**: Settings commands fail or timeout
- **Actions**:
  - Log error for crash reporting
  - Retry sync after delay
  - Notify user of failure

### 5. **Control State Machine**

Camera control follows this state progression:

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

**Control States**:

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

### 6. **Straggler Connection Management State Machine**

For managing cameras that fail to connect during bulk operations:

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

**Straggler Management**:
- **Retry Interval**: 15 seconds between attempts
- **Max Retries**: 5 attempts per straggler
- **Timeout**: Straggler timer runs until all targets connected or abandoned
- **Actions**: Automatic reconnection attempts for failed cameras

### 7. **Command Response State Machine**

Commands follow this response tracking pattern:

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

**Command States**:
- **Command Sent**: Command written to BLE characteristic
- **Response Wait**: Waiting for response in `pendingCommands`
- **Response Received**: Response processed, command removed from pending
- **Timeout**: Command removed from pending after timeout (3-5 seconds)

### 8. **Sleep/Power Down State Machine**

Special state machine for graceful disconnection:

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

**Sleep/Power Down Process**:
1. **Release Control**: Send `releaseControl()` command
2. **Wait**: 0.5 second delay
3. **Send Sleep/Power Command**: Add to `pendingSleepCommands` or `pendingPowerDownCommands`
4. **Wait for Response**: Up to 3 seconds
5. **Disconnect**: Either on response or timeout

### State Machine Interactions

These state machines interact in complex ways:

1. **Connection State** affects **Operational State**: Camera must be connected to be ready
2. **Control State** affects **Sync State**: Must have control to send settings
3. **Recording State** affects **Sync State**: Cannot sync while recording
4. **Straggler State** affects **Set State**: Stragglers prevent set from being ready
5. **Command State** affects **All States**: Commands can change any camera state

### Debugging State Machines

To debug state machine issues:

1. **Check Collections**: Verify device is in correct collection (`discoveredGoPros`, `connectingGoPros`, `connectedGoPros`)
2. **Check Properties**: Verify `hasControl`, `hasReceivedInitialStatus`, `isReady`, etc.
3. **Check Timers**: Verify query timers are running for connected devices
4. **Check Pending Commands**: Verify commands are being processed and removed from pending
5. **Check Retry Counts**: Verify retry logic is working correctly
6. **Check Straggler State**: Verify straggler management for bulk operations

---

## BLE Protocol Implementation

### Protocol Overview

The app implements GoPro's proprietary BLE protocol for camera control and status monitoring. The protocol uses a **packet-based communication system** with **TLV (Type-Length-Value)** encoding.

### Packet Structure

```
┌─────────┬─────────┬─────────┬─────────┬─────────────┐
│ Header  │ Length  │ QueryID │ Status  │ TLV Data    │
│ (1 byte)│ (1 byte)│ (1 byte)│ (1 byte)│ (variable)  │
└─────────┴─────────┴─────────┴─────────┴─────────────┘
```

**Header Format**:
- **Bits 7-6**: Packet type (0=General, 1=Extended, 2=Continuation)
- **Bit 5**: Continuation bit (1=more packets coming)
- **Bits 4-0**: Reserved

### Key Protocol Components

#### 1. **GoProBLEParser** (`GoProBLEParser.swift`)
- **Purpose**: Parse raw BLE packets into structured responses
- **Key Features**:
  - Packet reconstruction for multi-packet messages
  - TLV parsing and validation
  - Response type mapping
  - Buffer management for incomplete packets

**Packet Reconstruction Logic**:
```swift
func processPacket(_ data: Data, peripheralId: String) -> [ResponseType] {
    let packetHeader = data[0]
    let packetType = (packetHeader >> 6) & 0x03
    let isContinuationBit = (packetHeader & 0x20) != 0

    if packetType == 2 || (isContinuationBit && !looksLikeInitialPacket) {
        return handleContinuationPacket(data: data, peripheralId: peripheralId)
    }

    // Process complete or initial packets
    return parseTLVData(tlvData, queryID: UInt8(queryID))
}
```

#### 2. **Command Structure**
Commands follow a specific format:
```swift
struct GoProCommand {
    let commandID: UInt8
    let parameters: [UInt8]
    let expectedResponse: ResponseType
}
```

**Common Commands**:
- **Get Settings**: Query current camera settings
- **Set Settings**: Apply new settings to camera
- **Get Status**: Request camera status (battery, recording, etc.)
- **Control Commands**: Start/stop recording, power management

#### 3. **Response Handling**
Responses are parsed into strongly-typed `ResponseType` enum:
```swift
enum ResponseType {
    // Status responses
    case batteryLevel(Int)
    case batteryPercentage(Int)
    case isReady(Bool)
    case isRecording(Bool)

    // Settings responses
    case videoResolution(Int)
    case framesPerSecond(Int)
    case videoLens(Int)
    // ... many more
}
```

### Connection Management

#### 1. **Discovery Process**
```swift
func startScanning() {
    // Scan for GoPro devices with specific service UUIDs
    centralManager.scanForPeripherals(
        withServices: [GoProServiceUUID],
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    )
}
```

#### 2. **Connection Retry Logic**
```swift
private func attemptReconnection(for peripheral: CBPeripheral) {
    let retryCount = connectionRetryCount[peripheral.identifier] ?? 0
    if retryCount < maxRetryAttempts {
        connectionRetryCount[peripheral.identifier] = retryCount + 1
        centralManager.connect(peripheral, options: nil)
    }
}
```

#### 3. **Command Queue Management**
```swift
private func sendCommand(_ command: GoProCommand, to gopro: GoPro) {
    // Add to pending commands queue
    pendingCommands[gopro.id] = command

    // Send with timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + commandTimeout) {
        self.handleCommandTimeout(for: gopro.id)
    }
}
```

---

## Testing Strategy

### Testing Architecture

The app implements a comprehensive testing strategy with multiple layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Tests (XCUITest)                      │
├─────────────────────────────────────────────────────────────┤
│                 Integration Tests                           │
├─────────────────────────────────────────────────────────────┤
│                    Unit Tests (XCTest)                      │
├─────────────────────────────────────────────────────────────┤
│                   Manual Testing                            │
└─────────────────────────────────────────────────────────────┘
```

### 1. **Unit Tests** (`FacettTests/`)

#### **Parser Tests** (`ParserTests.swift`)
- **Purpose**: Test BLE packet parsing logic
- **Coverage**:
  - Packet reconstruction
  - TLV parsing
  - Error handling
  - Multi-packet message handling

```swift
func testParserInitialization() {
    XCTAssertNotNil(parser, "Parser should be initialized")
}

func testInvalidPacket() {
    let invalidData = Data([0xFF, 0xFF, 0xFF])
    let responses = parser.processPacket(invalidData, peripheralId: "test")
    XCTAssertTrue(responses.isEmpty, "Invalid packet should return no responses")
}
```

#### **Settings Tests** (`SettingsTests.swift`)
- **Purpose**: Test configuration and settings management
- **Coverage**:
  - ConfigManager CRUD operations
  - CameraGroupManager operations
  - SettingsValidator logic
  - Data persistence

```swift
func testCreateConfiguration() {
    let settings = GoProSettingsData.defaultSettings()
    var config = CameraConfig(name: "Test Config", description: "Test")
    config.settings = settings
    configManager.addConfig(config)

    let createdConfig = configManager.configs.first { $0.name == "Test Config" }
    XCTAssertNotNil(createdConfig, "Configuration should be created")
}
```

### 2. **UI Tests** (`FacettUITests/`)

#### **Workflow Tests** (`UIWorkflowTests.swift`)
- **Purpose**: Test complete user workflows
- **Coverage**:
  - App launch and navigation
  - Camera connection flows
  - Settings management
  - Error handling UI

```swift
func testAppLaunch() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.buttons["Connect All"].exists)
    XCTAssertTrue(app.buttons["Camera Groups"].exists)
}
```

### 3. **Manual Testing** (`ManualTest.swift`)
- **Purpose**: Test real device interactions
- **Coverage**:
  - Physical GoPro camera connections
  - Real BLE communication
  - Hardware-specific features

### 4. **Test Automation** (`run_tests.sh`)

The test runner script provides automated testing across different environments:

```bash
#!/bin/bash
# Test runner with multiple configurations
./run_tests.sh unit      # Run unit tests only
./run_tests.sh ui        # Run UI tests only
./run_tests.sh all       # Run all tests
./run_tests.sh device    # Run on physical device
```

---

## Data Models

### 1. **GoPro Settings Model**

#### **GoProSettings** (Observable)
- **Purpose**: Live camera settings with reactive updates
- **Key Features**:
  - `@Published` properties for SwiftUI binding
  - Real-time status updates
  - Optional vs required properties

```swift
class GoProSettings: ObservableObject {
    // Status properties (optional - updated from camera)
    @Published var batteryLevel: Int? = nil
    @Published var isUSBConnected: Bool? = nil
    @Published var isReady: Bool? = nil

    // Settings properties (required - with defaults)
    @Published var videoResolution: Int = defaultValues.videoResolution
    @Published var framesPerSecond: Int = defaultValues.framesPerSecond
    // ... many more settings
}
```

#### **GoProSettingsData** (Codable)
- **Purpose**: Persistent settings storage
- **Key Features**:
  - `Codable` for JSON serialization
  - Default values for all settings
  - Validation support

### 2. **Camera Configuration Model**

```swift
struct CameraConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var isDefault: Bool
    var settings: GoProSettingsData

    // Factory methods
    static func createDefault() -> CameraConfig
    static func createFromSettings(_ settings: GoProSettings) -> CameraConfig
}
```

### 3. **Camera Group Model**

```swift
struct CameraGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var cameraIds: Set<UUID>
    var isActive: Bool
    var configId: UUID? // Reference to CameraConfig
}
```

### 4. **Status Models**

```swift
enum CameraStatus: String, CaseIterable {
    case ready = "Ready"
    case error = "Error"
    case settingsMismatch = "Settings Mismatch"
    case disconnected = "Disconnected"
    // ... more statuses
}

struct SetStatus {
    let totalCameras: Int
    let readyCameras: Int
    let errorCameras: Int
    // ... computed properties for overall status
}
```

---

## UI Architecture

### SwiftUI View Hierarchy

```
ContentView
├── ActiveSetSummaryView
│   ├── CameraStatusRow
│   ├── BatteryIndicator
│   └── SettingsMismatchIndicator
├── CameraGroupViews
│   ├── CameraListView
│   ├── CameraGroupRow
│   └── CameraDetailView
├── ConfigManagementView
│   ├── ConfigList
│   ├── ConfigEditor
│   └── SettingsValidator
└── ManagementButtons
    ├── ConnectAllButton
    ├── CameraGroupsButton
    ├── ConfigurationsButton
    └── BugReportButton
```

### Key UI Components

#### 1. **ContentView** (`ContentView.swift`)
- **Purpose**: Main app interface and navigation hub
- **Key Features**:
  - Camera group management
  - Configuration management
  - Connection controls
  - Status monitoring

#### 2. **ActiveSetSummaryView** (`ActiveSetSummaryView.swift`)
- **Purpose**: Real-time camera group status display
- **Key Features**:
  - Battery level indicators
  - USB connection status
  - Settings mismatch detection
  - Quick actions

#### 3. **CameraGroupViews** (`CameraGroupViews.swift`)
- **Purpose**: Camera group creation and management
- **Key Features**:
  - Drag-and-drop camera assignment
  - Set configuration assignment
  - Status monitoring

### Reactive UI Updates

The UI uses SwiftUI's reactive system for automatic updates:

```swift
struct CameraStatusRow: View {
    @ObservedObject var camera: GoPro

    var body: some View {
        HStack {
            Text(camera.name ?? "Unknown Camera")
            Spacer()
            BatteryIndicator(level: camera.settings.batteryLevel)
            if camera.settings.isUSBConnected == true {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
            }
        }
        .onChange(of: camera.settings.batteryLevel) { newLevel in
            // Handle battery level changes
        }
    }
}
```

---

## Error Handling & Crash Reporting

### 1. **Crash Reporter** (`CrashReporter.swift`)

#### **Automatic Crash Detection**
```swift
class CrashReporter: NSObject {
    static let shared = CrashReporter()

    private func setupCrashHandlers() {
        // Signal-based crash handling
        signal(SIGABRT) { signal in
            CrashReporter.shared.handleCrash(signal: signal, name: "SIGABRT")
        }

        // Exception handling
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
    }
}
```

#### **Error Logging**
```swift
func logError(_ message: String, error: Error?, context: [String: String]) {
    let errorLog = ErrorLog(
        timestamp: Date(),
        message: message,
        error: error?.localizedDescription,
        context: context,
        threadStack: Thread.callStackSymbols,
        deviceInfo: getDeviceInfo(),
        appInfo: getAppInfo()
    )

    saveErrorLog(errorLog)
}
```

### 2. **Bug Reporting** (`BugReportView.swift`)

#### **User-Initiated Bug Reports**
- Comprehensive bug report form
- Device and app context collection
- Categorized bug types
- Severity levels

### 3. **BLE Error Handling**

#### **Connection Error Recovery**
```swift
func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    // Log error for crash reporting
    CrashReporter.shared.logError(
        "BLE Connection Failed",
        error: error,
        context: [
            "peripheral_name": peripheral.name ?? "Unknown",
            "retry_count": "\(connectionRetryCount[peripheral.identifier] ?? 0)"
        ]
    )

    // Implement retry logic
    attemptReconnection(for: peripheral)
}
```

---

## Performance Considerations

### 1. **BLE Communication Optimization**

#### **Command Batching**
- Group related commands to reduce BLE overhead
- Implement command queues to prevent flooding
- Use timeouts to prevent hanging connections

#### **Connection Management**
- Limit concurrent connections to prevent resource exhaustion
- Implement connection pooling for multiple cameras
- Use background task handling for long operations

### 2. **UI Performance**

#### **SwiftUI Optimization**
- Use `@StateObject` vs `@ObservedObject` appropriately
- Implement lazy loading for large lists
- Minimize view updates with proper state management

#### **Memory Management**
- Proper cleanup of BLE connections
- Release resources when views disappear
- Monitor memory usage in crash reports

### 3. **Data Persistence**

#### **Efficient Storage**
- Use `UserDefaults` for small settings
- Implement file-based storage for large configurations
- Compress data when appropriate

---

## Security & Privacy

### 1. **BLE Security**

#### **Connection Security**
- Validate device identities
- Implement connection encryption where supported
- Secure command transmission

#### **Data Protection**
- Encrypt sensitive configuration data
- Secure storage of camera credentials
- Privacy protection for user data

### 2. **App Security**

#### **Code Signing**
- Proper code signing for TestFlight distribution
- Secure API key management
- Input validation and sanitization

---

## Deployment & Distribution

### 1. **TestFlight Integration**

#### **Crash Reporting**
- Automatic crash report collection
- Symbolication for stack traces
- User feedback integration

#### **Beta Testing**
- Internal testing group
- External beta testing
- Feedback collection and analysis

### 2. **Build Configuration**

#### **Release vs Debug**
- Separate configurations for testing and production
- Conditional compilation for debug features
- Performance profiling in debug builds

### 3. **App Store Preparation**

#### **Metadata Management**
- App store descriptions and screenshots
- Privacy policy and terms of service
- App review guidelines compliance

---

## Future Enhancements

### 1. **Architecture Improvements**
- Implement dependency injection container
- Add comprehensive logging system
- Enhance error recovery mechanisms

### 2. **Feature Additions**
- Multi-camera synchronization
- Advanced settings validation
- Cloud configuration backup

### 3. **Testing Enhancements**
- Automated UI testing with real devices
- Performance benchmarking
- Security testing automation

---

## Conclusion

The GoPro Configurator app demonstrates a well-architected SwiftUI application with robust BLE communication, comprehensive testing, and excellent error handling. The modular design allows for easy maintenance and future enhancements while providing a solid foundation for reliable camera management.

The combination of reactive UI updates, sophisticated state management, and comprehensive error handling creates a professional-grade application suitable for production use and TestFlight distribution.
