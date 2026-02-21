# GoPro Configurator - API Reference

## Table of Contents
1. [Core Classes](#core-classes)
2. [BLE Communication](#ble-communication)
3. [Data Models](#data-models)
4. [UI Components](#ui-components)
5. [Utilities](#utilities)
6. [Testing](#testing)

---

## Core Classes

### BLEManager

**File**: `BLEManager.swift`
**Purpose**: Central BLE communication hub for GoPro camera management

#### Properties

```swift
class BLEManager: NSObject, ObservableObject {
    // Published properties for SwiftUI binding
    @Published var isScanning: Bool = false
    @Published var connectedGopros: [GoPro] = []
    @Published var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    // Private properties
    private var centralManager: CBCentralManager!
    private var parser: GoProBLEParser
    private var connectionRetryCount: [UUID: Int] = [:]
    private var pendingCommands: [UUID: GoProCommand] = [:]
    private var pendingSleepCommands: Set<UUID> = []
    private var pendingPowerDownCommands: Set<UUID> = []
}
```

#### Methods

##### Connection Management

```swift
// Start scanning for GoPro devices
func startScanning()

// Stop scanning
func stopScanning()

// Connect to a specific GoPro
func connectToGoPro(_ peripheral: CBPeripheral)

// Disconnect from a GoPro
func disconnectFromGoPro(_ gopro: GoPro)

// Connect to all discovered GoPro devices
func connectAllGopros()
```

##### Command Sending

```swift
// Send a command to a GoPro
func sendCommand(_ command: GoProCommand, to gopro: GoPro)

// Get current settings from a GoPro
func getSettings(from gopro: GoPro)

// Set settings on a GoPro
func setSettings(_ settings: GoProSettings, on gopro: GoPro)

// Send sleep command
func sendSleepCommand(to gopro: GoPro)

// Send power down command
func sendPowerDownCommand(to gopro: GoPro)
```

##### Status Management

```swift
// Get status from a GoPro
func getStatus(from gopro: GoPro)

// Update GoPro settings based on response
func updateGoProSettings(_ gopro: GoPro, with response: ResponseType)

// Check if settings match between cameras
func hasSettingsMismatch(gopro: GoPro, targetSettings: GoProSettings) -> Bool
```

#### CBCentralManagerDelegate Methods

```swift
// Called when central manager state changes
func centralManagerDidUpdateState(_ central: CBCentralManager)

// Called when a peripheral is discovered
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)

// Called when connection is established
func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)

// Called when connection fails
func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)

// Called when peripheral disconnects
func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
```

#### CBPeripheralDelegate Methods

```swift
// Called when services are discovered
func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)

// Called when characteristics are discovered
func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)

// Called when characteristic value is updated
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)

// Called when characteristic write is complete
func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
```

---

### GoProBLEParser

**File**: `GoProBLEParser.swift`
**Purpose**: Parse raw BLE packets into structured responses

#### Properties

```swift
class GoProBLEParser {
    // Packet reconstruction buffers
    private var continuationBuffer: [String: Data] = [:]
    private var expectedMessageLength: [String: Int] = [:]
    private var lastPacketTime: [String: Date] = [:]
}
```

#### Methods

```swift
// Process a BLE packet and return parsed responses
func processPacket(_ data: Data, peripheralId: String) -> [ResponseType]

// Clear buffer for a specific peripheral
func clearBuffer(for peripheralId: String)

// Handle continuation packets
private func handleContinuationPacket(data: Data, peripheralId: String) -> [ResponseType]

// Parse TLV data into response types
private func parseTLVData(_ data: Data, queryID: UInt8) -> [ResponseType]

// Parse individual TLV entry
private func parseTLVEntry(type: UInt8, value: Data) -> ResponseType?
```

---

### ConfigManager

**File**: `CameraConfig.swift`
**Purpose**: Manage camera configurations and presets

#### Properties

```swift
class ConfigManager: ObservableObject {
    @Published var configs: [CameraConfig] = []
    private let userDefaults = UserDefaults.standard
}
```

#### Methods

```swift
// Add a new configuration
func addConfig(_ config: CameraConfig)

// Delete a configuration
func deleteConfig(_ id: UUID)

// Get configuration by ID
func getConfig(_ id: UUID) -> CameraConfig?

// Save configurations to persistent storage
func saveConfigs()

// Load configurations from persistent storage
func loadConfigs()

// Create default configuration
func createDefaultConfig() -> CameraConfig

// Check if settings match between cameras
func hasSettingsMismatch(gopro: GoPro, targetSettings: GoProSettings) -> Bool
```

---

### CameraGroupManager

**File**: `CameraGroup.swift`
**Purpose**: Manage groups of cameras (camera groups)

#### Properties

```swift
class CameraGroupManager: ObservableObject {
    @Published var cameraSets: [CameraGroup] = []
    private let configManager: ConfigManager
    private let userDefaults = UserDefaults.standard
}
```

#### Methods

```swift
// Add a new camera group
func addCameraGroup(name: String, cameraIds: Set<UUID> = [], configId: UUID? = nil)

// Remove a camera group
func removeCameraGroup(_ cameraSet: CameraGroup)

// Get camera group by ID
func getCameraGroup(_ id: UUID) -> CameraGroup?

// Add camera to set
func addCamera(_ cameraId: UUID, to cameraSet: CameraGroup)

// Remove camera from set
func removeCamera(_ cameraId: UUID, from cameraSet: CameraGroup)

// Set active camera group
func setActiveCameraGroup(_ cameraSet: CameraGroup)

// Get active camera group
func getActiveCameraGroup() -> CameraGroup?

// Save camera groups to persistent storage
func saveCameraGroups()

// Load camera groups from persistent storage
func loadCameraGroups()

// Get cameras in a group
func getCamerasInSet(_ cameraSet: CameraGroup, from gopros: [GoPro]) -> [GoPro]

// Get group status
func getSetStatus(_ cameraSet: CameraGroup, gopros: [GoPro]) -> SetStatus
```

---

## Data Models

### GoProSettings

**File**: `GoPro.swift`
**Purpose**: Live camera settings with reactive updates

#### Properties

```swift
class GoProSettings: ObservableObject {
    // Status properties (optional - updated from camera)
    @Published var batteryLevel: Int? = nil
    @Published var batteryPercentage: Int? = nil
    @Published var isUSBConnected: Bool? = nil
    @Published var hasSDCardWriteSpeedError: Bool? = nil
    @Published var isCold: Bool? = nil
    @Published var isReady: Bool? = nil
    @Published var hasGPSLock: Bool? = nil
    @Published var sdCardRemaining: Int64? = nil
    @Published var isOverheating: Bool? = nil
    @Published var isBusy: Bool? = nil
    @Published var isEncoding: Bool? = nil
    @Published var videoEncodingDuration: Int32? = nil
    @Published var isBatteryPresent: Bool? = nil
    @Published var isExternalBatteryPresent: Bool? = nil
    @Published var connectedDevices: Int8? = nil
    @Published var usbControlled: Bool? = nil
    @Published var cameraControlId: Int? = nil

    // Settings properties (required - with defaults)
    @Published var videoResolution: Int = defaultValues.videoResolution
    @Published var framesPerSecond: Int = defaultValues.framesPerSecond
    @Published var autoPowerDown: Int = defaultValues.autoPowerDown
    @Published var gps: Bool = defaultValues.gps
    @Published var videoLens: Int = defaultValues.videoLens
    @Published var antiFlicker: Int = defaultValues.antiFlicker
    @Published var hypersmooth: Int = defaultValues.hypersmooth
    @Published var maxLens: Bool = defaultValues.maxLens
    @Published var videoPerformanceMode: Int = defaultValues.videoPerformanceMode
    @Published var colorProfile: Int = defaultValues.colorProfile
    @Published var lcdBrightness: Int = defaultValues.lcdBrightness
    @Published var isoMax: Int = defaultValues.isoMax
    @Published var language: Int = defaultValues.language
    @Published var voiceControl: Bool = defaultValues.voiceControl
    @Published var beeps: Int = defaultValues.beeps
    @Published var isoMin: Int = defaultValues.isoMin
    @Published var protuneEnabled: Bool = defaultValues.protuneEnabled
    @Published var whiteBalance: Int = defaultValues.whiteBalance
    @Published var ev: Int = defaultValues.ev
    @Published var bitrate: Int = defaultValues.bitrate
    @Published var rawAudio: Int = defaultValues.rawAudio
    @Published var mode: Int = defaultValues.mode
    @Published var shutter: Int = defaultValues.shutter
    @Published var led: Int = defaultValues.led
    @Published var wind: Int = defaultValues.wind
    @Published var hindsight: Int = defaultValues.hindsight
    @Published var quickCapture: Bool = defaultValues.quickCapture
    @Published var voiceLanguageControl: Int = defaultValues.voiceLanguageControl

    // Additional properties
    @Published var wifiBars: Int? = nil
    @Published var cameraMode: Int? = nil
    @Published var videoMode: Int? = nil
    @Published var photoMode: Int? = nil
    @Published var multiShotMode: Int? = nil
    @Published var flatMode: Int? = nil
    @Published var videoProtune: Bool? = nil
    @Published var videoStabilization: Int? = nil
    @Published var videoFieldOfView: Int? = nil
    @Published var turboMode: Bool? = nil

    // New settings from firmware analysis
    @Published var privacy: Int = defaultValues.privacy
    @Published var autoLock: Int = defaultValues.autoLock
    @Published var wakeOnVoice: Bool = defaultValues.wakeOnVoice
    @Published var timer: Int = defaultValues.timer
    @Published var videoCompression: Int = defaultValues.videoCompression
    @Published var landscapeLock: Int = defaultValues.landscapeLock
    @Published var screenSaverFront: Int = defaultValues.screenSaverFront
    @Published var screenSaverRear: Int = defaultValues.screenSaverRear
    @Published var defaultPreset: Int = defaultValues.defaultPreset
    @Published var frontLcdMode: Int = defaultValues.frontLcdMode
    @Published var gopSize: Int = defaultValues.gopSize
    @Published var idrInterval: Int = defaultValues.idrInterval
    @Published var bitRateMode: Int = defaultValues.bitRateMode
    @Published var audioProtune: Bool = defaultValues.audioProtune
    @Published var noAudioTrack: Bool = defaultValues.noAudioTrack

    // New status from firmware analysis
    @Published var cameraControlStatus: Bool? = nil
    @Published var allowControlOverUsb: Bool? = nil
    @Published var turboTransfer: Bool? = nil
    @Published var sdRatingCheckError: Bool? = nil
    @Published var videoLowTempAlert: Bool? = nil
    @Published var battOkayForOta: Bool? = nil
    @Published var firstTimeUse: Bool? = nil
    @Published var mobileFriendlyVideo: Bool? = nil
    @Published var analyticsReady: Bool? = nil
    @Published var analyticsSize: Int? = nil
    @Published var nextPollMsec: Int? = nil
    @Published var inContextualMenu: Bool? = nil
    @Published var creatingPreset: Bool? = nil
    @Published var linuxCoreActive: Bool? = nil
}
```

### GoProSettingsData

**File**: `CameraConfig.swift`
**Purpose**: Codable version of GoPro settings for persistence

#### Properties

```swift
struct GoProSettingsData: Codable {
    // Video Settings
    var videoResolution: Int
    var framesPerSecond: Int
    var videoLens: Int
    var antiFlicker: Int
    var hypersmooth: Int
    var maxLens: Bool
    var videoPerformanceMode: Int
    var colorProfile: Int
    var bitrate: Int
    var mode: Int
    var shutter: Int
    var ev: Int

    // Audio Settings
    var rawAudio: Int

    // Camera Behavior
    var autoPowerDown: Int
    var gps: Bool
    var quickCapture: Bool
    var voiceControl: Bool
    var hindsight: Int
    var wind: Int

    // Image Quality
    var isoMax: Int
    var isoMin: Int
    var whiteBalance: Int
    var protuneEnabled: Bool

    // Interface
    var lcdBrightness: Int
    var language: Int
    var beeps: Int
    var led: Int
    var voiceLanguageControl: Int

    // Additional Settings
    var privacy: Int
    var autoLock: Int
    var wakeOnVoice: Bool
    var timer: Int
    var videoCompression: Int
    var landscapeLock: Int
    var screenSaverFront: Int
    var screenSaverRear: Int
    var defaultPreset: Int
    var frontLcdMode: Int
    var gopSize: Int
    var idrInterval: Int
    var bitRateMode: Int
    var audioProtune: Bool
    var noAudioTrack: Bool
}
```

#### Methods

```swift
// Create default settings
static func defaultSettings() -> GoProSettingsData

// Create settings from GoProSettings
init(from settings: GoProSettings)

// Convert to GoProSettings
func toGoProSettings() -> GoProSettings
```

### CameraConfig

**File**: `CameraConfig.swift`
**Purpose**: Camera configuration/preset model

#### Properties

```swift
struct CameraConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var isDefault: Bool
    var settings: GoProSettingsData
}
```

#### Methods

```swift
// Create config from GoProSettings
init(name: String, description: String, isDefault: Bool, from settings: GoProSettings)

// Create default config
static func createDefault() -> CameraConfig
```

### CameraGroup

**File**: `CameraGroup.swift`
**Purpose**: Camera group/set model

#### Properties

```swift
struct CameraGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var cameraIds: Set<UUID>
    var isActive: Bool
    var configId: UUID? // Reference to a CameraConfig
}
```

### GoPro

**File**: `GoPro.swift`
**Purpose**: Represents a connected GoPro camera

#### Properties

```swift
class GoPro: ObservableObject, Identifiable {
    var id: UUID {
        peripheral.identifier
    }

    var name: String? {
        peripheral.name
    }

    @Published var peripheral: CBPeripheral
    @Published var hasControl: Bool = false
    @Published var settings: GoProSettings
    @Published var hasReceivedInitialStatus: Bool = false
}
```

---

## UI Components

### ContentView

**File**: `ContentView.swift`
**Purpose**: Main app interface and navigation hub

#### Properties

```swift
struct ContentView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var configManager: ConfigManager

    @State private var showingCameraGroupManagement = false
    @State private var showingConfigManagement = false
    @State private var showingVoiceNotificationSettings = false
    @State private var showingBugReportForm = false
}
```

#### Methods

```swift
// Main view body
var body: some View

// Connect all cameras
private func connectAllCameras()

// Disconnect all cameras
private func disconnectAllCameras()

// Get active camera group
private func getActiveCameraGroup() -> CameraGroup?

// Get cameras in active set
private func getCamerasInActiveSet() -> [GoPro]
```

### ActiveSetSummaryView

**File**: `ActiveSetSummaryView.swift`
**Purpose**: Real-time camera group status display

#### Properties

```swift
struct ActiveSetSummaryView: View {
    @ObservedObject var cameraSet: CameraGroup
    @ObservedObject var configManager: ConfigManager
    let cameras: [GoPro]

    @State private var showingSettingsMismatch = false
    @State private var showingBatteryWarning = false
}
```

#### Methods

```swift
// Main view body
var body: some View

// Get set status
private func getSetStatus() -> SetStatus

// Check for settings mismatches
private func checkSettingsMismatches() -> [GoPro]

// Get battery status
private func getBatteryStatus() -> BatteryStatus

// Apply configuration to all cameras
private func applyConfigurationToAll()

// Sync settings across cameras
private func syncSettings()
```

### CameraGroupViews

**File**: `CameraGroupViews.swift`
**Purpose**: Camera group creation and management

#### Properties

```swift
struct CameraGroupViews: View {
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var configManager: ConfigManager
    let cameras: [GoPro]

    @State private var showingCreateSet = false
    @State private var newSetName = ""
    @State private var selectedConfigId: UUID?
}
```

#### Methods

```swift
// Main view body
var body: some View

// Create new camera group
private func createCameraGroup()

// Delete camera group
private func deleteCameraGroup(_ cameraSet: CameraGroup)

// Add camera to set
private func addCameraToSet(_ camera: GoPro, set: CameraGroup)

// Remove camera from set
private func removeCameraFromSet(_ camera: GoPro, set: CameraGroup)
```

### ConfigManagementView

**File**: `ConfigManagementView.swift`
**Purpose**: Camera configuration management

#### Properties

```swift
struct ConfigManagementView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    let cameras: [GoPro]

    @State private var showingCreateConfig = false
    @State private var newConfigName = ""
    @State private var newConfigDescription = ""
    @State private var selectedCamera: GoPro?
}
```

#### Methods

```swift
// Main view body
var body: some View

// Create new configuration
private func createConfiguration()

// Delete configuration
private func deleteConfiguration(_ config: CameraConfig)

// Apply configuration to cameras
private func applyConfiguration(_ config: CameraConfig, to cameras: [GoPro])

// Create config from camera settings
private func createConfigFromCamera(_ camera: GoPro)
```

---

## Utilities

### SettingsValidator

**File**: `SettingsValidator.swift`
**Purpose**: Validate camera settings against hardware capabilities

#### Properties

```swift
class SettingsValidator {
    static let shared = SettingsValidator()

    struct ValidRanges {
        static let videoResolution = 0...4
        static let framesPerSecond = 0...13
        static let videoLens = 0...2
        static let antiFlicker = 0...1
        static let hypersmooth = 0...2
        static let videoPerformanceMode = 0...1
        static let colorProfile = 0...2
        static let lcdBrightness = 0...100
        static let isoMax = 100...6400
        static let language = 0...10
        static let beeps = 0...2
        static let isoMin = 100...800
        static let whiteBalance = 0...4
        static let ev = -2...2
        static let bitrate = 0...3
        static let rawAudio = 0...1
        static let mode = 0...2
        static let shutter = 0...10
        static let led = 0...2
        static let wind = 0...1
        static let hindsight = 0...30
        static let voiceLanguageControl = 0...10
        static let privacy = 0...1
        static let autoLock = 0...3
        static let timer = 0...30
        static let videoCompression = 0...1
        static let landscapeLock = 0...1
        static let screenSaverFront = 0...2
        static let screenSaverRear = 0...2
        static let defaultPreset = 0...4
        static let frontLcdMode = 0...2
        static let gopSize = 1...60
        static let idrInterval = 1...60
        static let bitRateMode = 0...1
    }
}
```

#### Methods

```swift
// Validate GoProSettings
func validateSettings(_ settings: GoProSettings) throws

// Validate GoProSettingsData
func validateSettings(_ settings: GoProSettingsData) throws

// Validate individual setting
private func validateSetting<T: Comparable>(_ value: T, range: ClosedRange<T>, name: String) throws

// Validate boolean setting
private func validateBooleanSetting(_ value: Bool, name: String) throws
```

### CrashReporter

**File**: `CrashReporter.swift`
**Purpose**: Comprehensive crash and error reporting

#### Properties

```swift
class CrashReporter: NSObject {
    static let shared = CrashReporter()

    private let logger = Logger(subsystem: "com.kmatzen.facett", category: "CrashReporter")
    private var crashLogs: [CrashLog] = []
    private var bugReports: [BugReport] = []
    private var errorLogs: [ErrorLog] = []
    private var warningLogs: [WarningLog] = []
}
```

#### Methods

```swift
// Log an error
func logError(_ message: String, error: Error?, context: [String: String])

// Log a warning
func logWarning(_ message: String, context: [String: String])

// Submit a bug report
func submitBugReport(_ report: BugReport)

// Get all reports
func getAllReports() -> (crashes: [CrashLog], bugs: [BugReport], errors: [ErrorLog], warnings: [WarningLog])

// Clear old reports
func clearOldReports(olderThan days: Int)

// Export reports
func exportReports() -> Data?

// Check if running in TestFlight
func isTestFlightBuild() -> Bool
```

### HapticManager

**File**: `HapticManager.swift`
**Purpose**: Provide haptic feedback

#### Methods

```swift
// Success haptic feedback
func success()

// Error haptic feedback
func error()

// Warning haptic feedback
func warning()

// Light haptic feedback
func light()

// Medium haptic feedback
func medium()

// Heavy haptic feedback
func heavy()
```

### SpeechManager

**File**: `SpeechManager.swift`
**Purpose**: Text-to-speech functionality

#### Properties

```swift
class SpeechManager: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var isEnabled = true
}
```

#### Methods

```swift
// Speak text
func speak(_ text: String)

// Stop speaking
func stop()

// Check if speech is available
func isSpeechAvailable() -> Bool
```

### VoiceNotificationManager

**File**: `VoiceNotificationManager.swift`
**Purpose**: Manage voice notifications

#### Properties

```swift
class VoiceNotificationManager: ObservableObject {
    @Published var isEnabled = true
    @Published var connectionNotifications = true
    @Published var settingsNotifications = true
    @Published var errorNotifications = true
    @Published var batteryNotifications = true
}
```

#### Methods

```swift
// Notify camera connected
func notifyCameraConnected(_ camera: GoPro)

// Notify camera disconnected
func notifyCameraDisconnected(_ camera: GoPro)

// Notify settings applied
func notifySettingsApplied(_ camera: GoPro)

// Notify error
func notifyError(_ error: String, camera: GoPro?)

// Notify low battery
func notifyLowBattery(_ camera: GoPro)
```

---

## Testing

### ParserTests

**File**: `FacettTests/ParserTests.swift`
**Purpose**: Test BLE packet parsing logic

#### Test Methods

```swift
// Test parser initialization
func testParserInitialization()

// Test empty data handling
func testEmptyData()

// Test invalid packet handling
func testInvalidPacket()

// Test short packet handling
func testShortPacket()

// Test multiple peripherals
func testMultiplePeripherals()

// Test buffer cleanup
func testBufferCleanup()
```

### SettingsTests

**File**: `FacettTests/SettingsTests.swift`
**Purpose**: Test configuration and settings management

#### Test Methods

```swift
// Test ConfigManager initialization
func testConfigManagerInitialization()

// Test CameraGroupManager initialization
func testCameraGroupManagerInitialization()

// Test SettingsValidator initialization
func testSettingsValidatorInitialization()

// Test configuration creation
func testCreateConfiguration()

// Test configuration deletion
func testDeleteConfiguration()

// Test camera group creation
func testCreateCameraGroup()

// Test camera group deletion
func testDeleteCameraGroup()

// Test settings validation
func testSettingsValidatorWithDefaultSettings()
```

### UIWorkflowTests

**File**: `FacettUITests/UIWorkflowTests.swift`
**Purpose**: Test complete user workflows

#### Test Methods

```swift
// Test app launch
func testAppLaunch()

// Test camera connection workflow
func testCameraConnectionWorkflow()

// Test settings management workflow
func testSettingsManagementWorkflow()

// Test camera group management workflow
func testCameraGroupManagementWorkflow()

// Test error handling UI
func testErrorHandlingUI()
```

### ManualTest

**File**: `FacettTests/ManualTest.swift`
**Purpose**: Manual testing with real devices

#### Test Methods

```swift
// Test real GoPro connection
func testRealGoProConnection()

// Test settings synchronization
func testSettingsSynchronization()

// Test multi-camera setup
func testMultiCameraGroupup()

// Test error recovery
func testErrorRecovery()
```

---

## Enums and Constants

### ResponseType

**File**: `BLEManager.swift`
**Purpose**: Define all possible BLE response types

```swift
enum ResponseType {
    // Status responses
    case batteryLevel(Int)
    case batteryPercentage(Int)
    case overheating(Bool)
    case isBusy(Bool)
    case encoding(Bool)
    case videoEncodingDuration(Int32)
    case sdCardRemaining(Int64)
    case gpsLock(Bool)
    case isReady(Bool)
    case isCold(Bool)
    case sdCardWriteSpeedError(Bool)
    case usbConnected(Bool)
    case batteryPresent(Bool)
    case externalBatteryPresent(Bool)
    case connectedDevices(Int8)
    case usbControlled(Bool)
    case cameraControlId(Int)

    // Settings responses
    case videoResolution(Int)
    case framesPerSecond(Int)
    case autoPowerDown(Int)
    case gps(Bool)
    case videoLens(Int)
    case antiFlicker(Int)
    case hypersmooth(Int)
    case maxLens(Bool)
    case videoPerformanceMode(Int)
    case colorProfile(Int)
    case lcdBrightness(Int)
    case isoMax(Int)
    case language(Int)
    case voiceControl(Bool)
    case beeps(Int)
    case isoMin(Int)
    case protuneEnabled(Bool)
    case whiteBalance(Int)
    case ev(Int)
    case bitrate(Int)
    case rawAudio(Int)
    case mode(Int)
    case shutter(Int)
    case led(Int)
    case wind(Int)
    case hindsight(Int)
    case quickCapture(Bool)
    case voiceLanguageControl(Int)

    // Additional responses
    case privacy(Int)
    case autoLock(Int)
    case wakeOnVoice(Bool)
    case timer(Int)
    case videoCompression(Int)
    case landscapeLock(Int)
    case screenSaverFront(Int)
    case screenSaverRear(Int)
    case defaultPreset(Int)
    case frontLcdMode(Int)
    case gopSize(Int)
    case idrInterval(Int)
    case bitRateMode(Int)
    case audioProtune(Bool)
    case noAudioTrack(Bool)

    // Control responses
    case cameraControlStatus(Bool)
    case allowControlOverUsb(Bool)
    case turboTransfer(Bool)
    case sdRatingCheckError(Bool)
    case videoLowTempAlert(Bool)
    case battOkayForOta(Bool)
    case firstTimeUse(Bool)
    case mobileFriendlyVideo(Bool)
    case analyticsReady(Bool)
    case analyticsSize(Int)
    case nextPollMsec(Int)
    case inContextualMenu(Bool)
    case creatingPreset(Bool)
    case linuxCoreActive(Bool)
}
```

### CameraStatus

**File**: `CameraGroup.swift`
**Purpose**: Define camera status states

```swift
enum CameraStatus: String, CaseIterable {
    case ready = "Ready"
    case error = "Error"
    case settingsMismatch = "Settings Mismatch"
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case initializing = "Initializing"
    case recording = "Recording"
    case lowBattery = "Low Battery"
    case noSDCard = "No SD Card"
    case overheating = "Overheating"
}
```

### BugSeverity

**File**: `BugReportView.swift`
**Purpose**: Define bug report severity levels

```swift
enum BugSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}
```

### BugCategory

**File**: `BugReportView.swift`
**Purpose**: Define bug report categories

```swift
enum BugCategory: String, CaseIterable {
    case general = "General"
    case connection = "Connection"
    case settings = "Settings"
    case ui = "User Interface"
    case performance = "Performance"
    case crash = "Crash"
    case other = "Other"
}
```

---

## Constants

### BLE Constants

```swift
// GoPro BLE Service UUIDs
let GoProServiceUUID = CBUUID(string: "B5F90001-AA8D-11E3-9046-0002A5D5C51B")
let GoProControlUUID = CBUUID(string: "B5F90002-AA8D-11E3-9046-0002A5D5C51B")
let GoProResponseUUID = CBUUID(string: "B5F90003-AA8D-11E3-9046-0002A5D5C51B")

// Timeouts
let connectionTimeout: TimeInterval = 10.0
let commandTimeout: TimeInterval = 5.0
let baseRetryDelay: TimeInterval = 1.0
let maxRetryAttempts = 3

// Buffer limits
let maxBatchSize = 20
let maxParameterLength = 255
```

### UI Constants

```swift
// Animation durations
let animationDuration: Double = 0.3
let hapticDelay: Double = 0.1

// UI dimensions
let cornerRadius: CGFloat = 12.0
let buttonHeight: CGFloat = 44.0
let spacing: CGFloat = 16.0
```

---

## Error Types

### ValidationError

```swift
enum ValidationError: Error, LocalizedError {
    case invalidVideoResolution(Int)
    case invalidFramesPerSecond(Int)
    case invalidVideoLens(Int)
    case invalidAntiFlicker(Int)
    case invalidHypersmooth(Int)
    case invalidVideoPerformanceMode(Int)
    case invalidColorProfile(Int)
    case invalidLcdBrightness(Int)
    case invalidIsoMax(Int)
    case invalidLanguage(Int)
    case invalidBeeps(Int)
    case invalidIsoMin(Int)
    case invalidWhiteBalance(Int)
    case invalidEv(Int)
    case invalidBitrate(Int)
    case invalidRawAudio(Int)
    case invalidMode(Int)
    case invalidShutter(Int)
    case invalidLed(Int)
    case invalidWind(Int)
    case invalidHindsight(Int)
    case invalidVoiceLanguageControl(Int)
    case invalidPrivacy(Int)
    case invalidAutoLock(Int)
    case invalidTimer(Int)
    case invalidVideoCompression(Int)
    case invalidLandscapeLock(Int)
    case invalidScreenSaverFront(Int)
    case invalidScreenSaverRear(Int)
    case invalidDefaultPreset(Int)
    case invalidFrontLcdMode(Int)
    case invalidGopSize(Int)
    case invalidIdrInterval(Int)
    case invalidBitRateMode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidVideoResolution(let value):
            return "Invalid video resolution: \(value)"
        case .invalidFramesPerSecond(let value):
            return "Invalid frames per second: \(value)"
        // ... other cases
        }
    }
}
```

### BLEError

```swift
enum BLEError: Error, LocalizedError {
    case centralManagerNotPoweredOn
    case peripheralNotFound
    case connectionFailed
    case commandTimeout
    case invalidResponse
    case deviceNotSupported

    var errorDescription: String? {
        switch self {
        case .centralManagerNotPoweredOn:
            return "Bluetooth is not powered on"
        case .peripheralNotFound:
            return "GoPro device not found"
        case .connectionFailed:
            return "Failed to connect to GoPro"
        case .commandTimeout:
            return "Command timed out"
        case .invalidResponse:
            return "Invalid response from GoPro"
        case .deviceNotSupported:
            return "Device not supported"
        }
    }
}
```

---

This API reference provides a comprehensive overview of all the major classes, methods, and interfaces in the GoPro Configurator app. Each section includes detailed information about properties, methods, parameters, and return values, making it easy for developers to understand and use the codebase effectively.
