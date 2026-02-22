# Facett - Software Architecture Documentation

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

Facett is built using **SwiftUI** with **MVVM (Model-View-ViewModel)** architecture pattern. The app follows a modular design with clear separation of concerns:

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

The app uses several implicit state machines to manage device connectivity, camera status, settings synchronization, control ownership, straggler recovery, command lifecycle, and sleep/power-down.

See [STATE_MACHINES.md](STATE_MACHINES.md) for diagrams, state definitions, transitions, and debugging tips.

---

## BLE Protocol Implementation

Facett communicates with GoPro cameras over BLE using a packet-based protocol with TLV (Type-Length-Value) encoding. The parsing pipeline is:

1. **BLEPacketReconstructor** — reassembles multi-packet messages using header bit-fields
2. **BLETLVParser** — decodes TLV entries from the reassembled payload
3. **BLEResponseMapper** — maps TLV entries to strongly-typed `ResponseType` values

See [BLE_PROTOCOL.md](BLE_PROTOCOL.md) for packet formats, header encoding, and command/response details.

---

## Testing Strategy

Tests are organized in layers: unit tests (`FacettTests/`), UI tests (`FacettUITests/`), and manual hardware tests (`ManualTest.swift`). The `run_tests.sh` script automates test execution across environments.

See [TESTING.md](TESTING.md) for test categories, coverage details, and usage instructions.

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
    var cameraSerials: Set<String>
    var isActive: Bool
    var configId: UUID?
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

struct GroupStatus {
    let totalCameras: Int
    let readyCameras: Int
    let errorCameras: Int
    let disconnectedCameras: Int
    let recordingCameras: Int
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

Facett has a layered error handling system:

- **CrashReporter** — signal and exception handlers for automatic crash logging
- **ErrorHandler** — centralized logging with severity levels (`error`, `warning`, `info`, `debug`)
- **BugReportView** — user-initiated bug reports with device context
- **BLE error recovery** — automatic reconnection with retry logic

See [CRASH_REPORTING.md](CRASH_REPORTING.md) for implementation details.

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
- Proper code signing for distribution
- Secure API key management
- Input validation and sanitization

---

## Deployment & Distribution

### 1. **Build Configuration**

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

Facett demonstrates a well-architected SwiftUI application with robust BLE communication, comprehensive testing, and excellent error handling. The modular design allows for easy maintenance and future enhancements while providing a solid foundation for reliable camera management.

The combination of reactive UI updates, sophisticated state management, and comprehensive error handling creates a professional-grade application suitable for production use.
