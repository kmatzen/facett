import Foundation
import SwiftUI

// MARK: - Camera Configuration Model
struct CameraConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var isDefault: Bool
    var settings: GoProSettingsData

    init(name: String, description: String = "", isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.isDefault = isDefault
        self.settings = GoProSettingsData.defaultSettings()
    }

    // Create a config from current GoProSettings
    init(name: String, description: String, isDefault: Bool, from settings: GoProSettings) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.isDefault = isDefault
        self.settings = GoProSettingsData(from: settings)
    }
}

// MARK: - GoPro Settings Data (Codable version)
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

    // Custom initializer
    init(
        videoResolution: Int,
        framesPerSecond: Int,
        videoLens: Int,
        antiFlicker: Int,
        hypersmooth: Int,
        maxLens: Bool,
        videoPerformanceMode: Int,
        colorProfile: Int,
        bitrate: Int,
        mode: Int,
        shutter: Int,
        ev: Int,
        rawAudio: Int,
        autoPowerDown: Int,
        gps: Bool,
        quickCapture: Bool,
        voiceControl: Bool,
        hindsight: Int,
        wind: Int,
        isoMax: Int,
        isoMin: Int,
        whiteBalance: Int,
        protuneEnabled: Bool,
        lcdBrightness: Int,
        language: Int,
        beeps: Int,
        led: Int,
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
        self.videoLens = videoLens
        self.antiFlicker = antiFlicker
        self.hypersmooth = hypersmooth
        self.maxLens = maxLens
        self.videoPerformanceMode = videoPerformanceMode
        self.colorProfile = colorProfile
        self.bitrate = bitrate
        self.mode = mode
        self.shutter = shutter
        self.ev = ev
        self.rawAudio = rawAudio
        self.autoPowerDown = autoPowerDown
        self.gps = gps
        self.quickCapture = quickCapture
        self.voiceControl = voiceControl
        self.hindsight = hindsight
        self.wind = wind
        self.isoMax = isoMax
        self.isoMin = isoMin
        self.whiteBalance = whiteBalance
        self.protuneEnabled = protuneEnabled
        self.lcdBrightness = lcdBrightness
        self.language = language
        self.beeps = beeps
        self.led = led
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

    // Initialize with default values - must match BLEManager.defaultGoProSettings
    static func defaultSettings() -> GoProSettingsData {
        let settings = GoProSettingsData(
            videoResolution: 1, // 4K
            framesPerSecond: 5, // 60 FPS
            videoLens: 0, // Wide
            antiFlicker: 2, // 60 Hz
            hypersmooth: 0, // Off
            maxLens: false,
            videoPerformanceMode: 0, // Maximum Performance
            colorProfile: 1, // Flat
            bitrate: 1, // High
            mode: 12, // Video
            shutter: 0, // Auto
            ev: 4, // Neutral
            rawAudio: 2, // High
            autoPowerDown: 7, // 30 minutes
            gps: true,
            quickCapture: false,
            voiceControl: false,
            hindsight: 4, // Off
            wind: 0, // Off
            isoMax: 1,
            isoMin: 8,
            whiteBalance: 4, // Native
            protuneEnabled: true,
            lcdBrightness: 100, // 100%
            language: 0, // English
            beeps: 0, // Off
            led: 5, // Off
            voiceLanguageControl: 0, // English
            privacy: 0,
            autoLock: 0,
            wakeOnVoice: false,
            timer: 0,
            videoCompression: 0,
            landscapeLock: 0,
            screenSaverFront: 0,
            screenSaverRear: 0,
            defaultPreset: 0,
            frontLcdMode: 0,
            gopSize: 0,
            idrInterval: 0,
            bitRateMode: 0,
            audioProtune: false,
            noAudioTrack: false
        )
        return settings
    }

    // Initialize from GoProSettings
    init(from settings: GoProSettings) {
        self.videoResolution = settings.videoResolution
        self.framesPerSecond = settings.framesPerSecond
        self.videoLens = settings.videoLens
        self.antiFlicker = settings.antiFlicker
        self.hypersmooth = settings.hypersmooth
        self.maxLens = settings.maxLens
        self.videoPerformanceMode = settings.videoPerformanceMode
        self.colorProfile = settings.colorProfile
        self.bitrate = settings.bitrate
        self.mode = settings.mode
        self.shutter = settings.shutter
        self.ev = settings.ev
        self.rawAudio = settings.rawAudio
        self.autoPowerDown = settings.autoPowerDown
        self.gps = settings.gps
        self.quickCapture = settings.quickCapture
        self.voiceControl = settings.voiceControl
        self.hindsight = settings.hindsight
        self.wind = settings.wind
        self.isoMax = settings.isoMax
        self.isoMin = settings.isoMin
        self.whiteBalance = settings.whiteBalance
        self.protuneEnabled = settings.protuneEnabled
        self.lcdBrightness = settings.lcdBrightness
        self.language = settings.language
        self.beeps = settings.beeps
        self.led = settings.led
        self.voiceLanguageControl = settings.voiceLanguageControl
        self.privacy = settings.privacy
        self.autoLock = settings.autoLock
        self.wakeOnVoice = settings.wakeOnVoice
        self.timer = settings.timer
        self.videoCompression = settings.videoCompression
        self.landscapeLock = settings.landscapeLock
        self.screenSaverFront = settings.screenSaverFront
        self.screenSaverRear = settings.screenSaverRear
        self.defaultPreset = settings.defaultPreset
        self.frontLcdMode = settings.frontLcdMode
        self.gopSize = settings.gopSize
        self.idrInterval = settings.idrInterval
        self.bitRateMode = settings.bitRateMode
        self.audioProtune = settings.audioProtune
        self.noAudioTrack = settings.noAudioTrack
    }

    // Convert to GoProSettings
    func toGoProSettings() -> GoProSettings {
        return GoProSettings(
            videoResolution: videoResolution,
            framesPerSecond: framesPerSecond,
            autoPowerDown: autoPowerDown,
            gps: gps,
            videoLens: videoLens,
            antiFlicker: antiFlicker,
            hypersmooth: hypersmooth,
            maxLens: maxLens,
            videoPerformanceMode: videoPerformanceMode,
            colorProfile: colorProfile,
            lcdBrightness: lcdBrightness,
            isoMax: isoMax,
            language: language,
            voiceControl: voiceControl,
            beeps: beeps,
            isoMin: isoMin,
            protuneEnabled: protuneEnabled,
            whiteBalance: whiteBalance,
            ev: ev,
            bitrate: bitrate,
            rawAudio: rawAudio,
            mode: mode,
            shutter: shutter,
            led: led,
            wind: wind,
            hindsight: hindsight,
            quickCapture: quickCapture,
            voiceLanguageControl: voiceLanguageControl,
            privacy: privacy,
            autoLock: autoLock,
            wakeOnVoice: wakeOnVoice,
            timer: timer,
            videoCompression: videoCompression,
            landscapeLock: landscapeLock,
            screenSaverFront: screenSaverFront,
            screenSaverRear: screenSaverRear,
            defaultPreset: defaultPreset,
            frontLcdMode: frontLcdMode,
            gopSize: gopSize,
            idrInterval: idrInterval,
            bitRateMode: bitRateMode,
            audioProtune: audioProtune,
            noAudioTrack: noAudioTrack
        )
    }
}
