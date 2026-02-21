import Foundation
import CoreBluetooth

// MARK: - Camera Status (Real-time updates)
class CameraStatusData: ObservableObject {
    // Statuses (keep optional) - these need real-time UI updates
    @Published var batteryLevel: Int? = nil // Battery level (0 to 4)
    @Published var batteryPercentage: Int? = nil // Battery percentage (0 to 100)
    @Published var isUSBConnected: Bool? = nil // Whether USB is connected
    @Published var hasSDCardWriteSpeedError: Bool? = nil // Whether there's an SD card write speed error
    @Published var isCold: Bool? = nil // Whether the GoPro is in a cold environment
    @Published var isReady: Bool? = nil // Whether the GoPro is ready
    @Published var hasGPSLock: Bool? = nil // Whether GPS is locked
    @Published var sdCardRemaining: Int64? = nil // Remaining SD card space in kilobytes

    @Published var isOverheating: Bool? = nil // Whether the GoPro is overheating
    @Published var isBusy: Bool? = nil // Whether the GoPro is busy
    @Published var isEncoding: Bool? = nil // Whether the GoPro is encoding
    @Published var videoEncodingDuration: Int32? = nil
    @Published var isBatteryPresent: Bool? = nil
    @Published var isExternalBatteryPresent: Bool? = nil
    @Published var connectedDevices: Int8? = nil
    @Published var usbControlled: Bool? = nil
    @Published var cameraControlId: Int? = nil

    // Additional properties needed for the parser (keep optional)
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

    // WiFi credentials (keep optional)
    @Published var wifiSSID: String? = nil
    @Published var apSSID: String? = nil
    @Published var apState: Int? = nil
    @Published var wifiPassword: String? = nil
    @Published var apPassword: String? = nil

    // New status from firmware analysis (keep optional)
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

    // Time synchronization tracking
    @Published var lastTimeSyncDate: Date? = nil // When the camera's time was last synchronized
}

// MARK: - GoPro Settings (Value-based, no @Published)
struct GoProSettings {
    // Static default values from GoProSettingsData
    static let defaultValues: GoProSettingsData = GoProSettingsData.defaultSettings()

    // Settings (make non-optional with default values) - these are configuration values
    var videoResolution: Int
    var framesPerSecond: Int
    var autoPowerDown: Int
    var gps: Bool
    var videoLens: Int
    var antiFlicker: Int
    var hypersmooth: Int
    var maxLens: Bool
    var videoPerformanceMode: Int
    var colorProfile: Int
    var lcdBrightness: Int
    var isoMax: Int
    var language: Int
    var voiceControl: Bool
    var beeps: Int
    var isoMin: Int
    var protuneEnabled: Bool
    var whiteBalance: Int
    var ev: Int
    var bitrate: Int
    var rawAudio: Int
    var mode: Int
    var shutter: Int
    var led: Int
    var wind: Int
    var hindsight: Int
    var quickCapture: Bool
    var voiceLanguageControl: Int

    // New settings from firmware analysis (make non-optional with default values)
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

    // Default initializer
    init() {
        let defaults = Self.defaultValues
        self.videoResolution = defaults.videoResolution
        self.framesPerSecond = defaults.framesPerSecond
        self.autoPowerDown = defaults.autoPowerDown
        self.gps = defaults.gps
        self.videoLens = defaults.videoLens
        self.antiFlicker = defaults.antiFlicker
        self.hypersmooth = defaults.hypersmooth
        self.maxLens = defaults.maxLens
        self.videoPerformanceMode = defaults.videoPerformanceMode
        self.colorProfile = defaults.colorProfile
        self.lcdBrightness = defaults.lcdBrightness
        self.isoMax = defaults.isoMax
        self.language = defaults.language
        self.voiceControl = defaults.voiceControl
        self.beeps = defaults.beeps
        self.isoMin = defaults.isoMin
        self.protuneEnabled = defaults.protuneEnabled
        self.whiteBalance = defaults.whiteBalance
        self.ev = defaults.ev
        self.bitrate = defaults.bitrate
        self.rawAudio = defaults.rawAudio
        self.mode = defaults.mode
        self.shutter = defaults.shutter
        self.led = defaults.led
        self.wind = defaults.wind
        self.hindsight = defaults.hindsight
        self.quickCapture = defaults.quickCapture
        self.voiceLanguageControl = defaults.voiceLanguageControl
        self.privacy = defaults.privacy
        self.autoLock = defaults.autoLock
        self.wakeOnVoice = defaults.wakeOnVoice
        self.timer = defaults.timer
        self.videoCompression = defaults.videoCompression
        self.landscapeLock = defaults.landscapeLock
        self.screenSaverFront = defaults.screenSaverFront
        self.screenSaverRear = defaults.screenSaverRear
        self.defaultPreset = defaults.defaultPreset
        self.frontLcdMode = defaults.frontLcdMode
        self.gopSize = defaults.gopSize
        self.idrInterval = defaults.idrInterval
        self.bitRateMode = defaults.bitRateMode
        self.audioProtune = defaults.audioProtune
        self.noAudioTrack = defaults.noAudioTrack
    }

    // Custom initializer for all parameters
    init(
        videoResolution: Int,
        framesPerSecond: Int,
        autoPowerDown: Int,
        gps: Bool,
        videoLens: Int,
        antiFlicker: Int,
        hypersmooth: Int,
        maxLens: Bool,
        videoPerformanceMode: Int,
        colorProfile: Int,
        lcdBrightness: Int,
        isoMax: Int,
        language: Int,
        voiceControl: Bool,
        beeps: Int,
        isoMin: Int,
        protuneEnabled: Bool,
        whiteBalance: Int,
        ev: Int,
        bitrate: Int,
        rawAudio: Int,
        mode: Int,
        shutter: Int,
        led: Int,
        wind: Int,
        hindsight: Int,
        quickCapture: Bool,
        voiceLanguageControl: Int,
        privacy: Int,
        autoLock: Int,
        wakeOnVoice: Bool,
        timer: Int,
        videoCompression: Int,
        landscapeLock: Int,
        screenSaverFront: Int,
        screenSaverRear: Int,
        defaultPreset: Int,
        frontLcdMode: Int,
        gopSize: Int,
        idrInterval: Int,
        bitRateMode: Int,
        audioProtune: Bool,
        noAudioTrack: Bool
    ) {
        self.videoResolution = videoResolution
        self.framesPerSecond = framesPerSecond
        self.autoPowerDown = autoPowerDown
        self.gps = gps
        self.videoLens = videoLens
        self.antiFlicker = antiFlicker
        self.hypersmooth = hypersmooth
        self.maxLens = maxLens
        self.videoPerformanceMode = videoPerformanceMode
        self.colorProfile = colorProfile
        self.lcdBrightness = lcdBrightness
        self.isoMax = isoMax
        self.language = language
        self.voiceControl = voiceControl
        self.beeps = beeps
        self.isoMin = isoMin
        self.protuneEnabled = protuneEnabled
        self.whiteBalance = whiteBalance
        self.ev = ev
        self.bitrate = bitrate
        self.rawAudio = rawAudio
        self.mode = mode
        self.shutter = shutter
        self.led = led
        self.wind = wind
        self.hindsight = hindsight
        self.quickCapture = quickCapture
        self.voiceLanguageControl = voiceLanguageControl
        self.privacy = privacy
        self.autoLock = autoLock
        self.wakeOnVoice = wakeOnVoice
        self.timer = timer
        self.videoCompression = videoCompression
        self.landscapeLock = landscapeLock
        self.screenSaverFront = screenSaverFront
        self.screenSaverRear = screenSaverRear
        self.defaultPreset = defaultPreset
        self.frontLcdMode = frontLcdMode
        self.gopSize = gopSize
        self.idrInterval = idrInterval
        self.bitRateMode = bitRateMode
        self.audioProtune = audioProtune
        self.noAudioTrack = noAudioTrack
    }
}

class GoPro: ObservableObject, Identifiable {
    var id: UUID {
        peripheral.identifier
    }

    var name: String? {
        peripheral.name
    }

    @Published var peripheral: CBPeripheral // Core Bluetooth peripheral
    @Published var hasControl: Bool = false
    @Published var settings: GoProSettings // Value-based settings (triggers UI update when replaced)
    @Published var status: CameraStatusData // Real-time status updates
    @Published var hasReceivedInitialStatus: Bool = false // Track if camera has received first status update

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.settings = GoProSettings()
        self.status = CameraStatusData()
    }

    // Method to update settings and trigger UI update
    func updateSettings(_ newSettings: GoProSettings) {
        settings = newSettings
    }

    // Method to update individual setting (for backward compatibility)
    func updateSetting<T>(_ keyPath: WritableKeyPath<GoProSettings, T>, value: T) {
        var newSettings = settings
        newSettings[keyPath: keyPath] = value
        settings = newSettings
    }
}
