import Foundation

// MARK: - Settings Protocol
protocol SettingsProtocol {
    var videoResolution: Int { get }
    var framesPerSecond: Int { get }
    var autoPowerDown: Int { get }
    var gps: Bool { get }
    var videoLens: Int { get }
    var antiFlicker: Int { get }
    var hypersmooth: Int { get }
    var maxLens: Bool { get }
    var videoPerformanceMode: Int { get }
    var colorProfile: Int { get }
    var lcdBrightness: Int { get }
    var isoMax: Int { get }
    var isoMin: Int { get }
    var language: Int { get }
    var beeps: Int { get }
    var whiteBalance: Int { get }
    var ev: Int { get }
    var bitrate: Int { get }
    var rawAudio: Int { get }
    var mode: Int { get }
    var shutter: Int { get }
    var led: Int { get }
    var wind: Int { get }
    var hindsight: Int { get }
    var voiceLanguageControl: Int { get }
    var privacy: Int { get }
    var autoLock: Int { get }
    var timer: Int { get }
    var videoCompression: Int { get }
    var landscapeLock: Int { get }
    var screenSaverFront: Int { get }
    var screenSaverRear: Int { get }
    var defaultPreset: Int { get }
    var frontLcdMode: Int { get }
    var gopSize: Int { get }
    var idrInterval: Int { get }
    var bitRateMode: Int { get }
    var protuneEnabled: Bool { get }
    var quickCapture: Bool { get }
    var voiceControl: Bool { get }
    var wakeOnVoice: Bool { get }
    var audioProtune: Bool { get }
    var noAudioTrack: Bool { get }
}

// MARK: - Protocol Conformance
extension GoProSettings: SettingsProtocol {}
extension GoProSettingsData: SettingsProtocol {}

// MARK: - Validation Errors
enum SettingsValidationError: Error, LocalizedError {
    case invalidVideoResolution(Int)
    case invalidFramesPerSecond(Int)
    case invalidVideoLens(Int)
    case invalidAntiFlicker(Int)
    case invalidHypersmooth(Int)
    case invalidVideoPerformanceMode(Int)
    case invalidColorProfile(Int)
    case invalidLcdBrightness(Int)
    case invalidIsoMax(Int)
    case invalidIsoMin(Int)
    case invalidLanguage(Int)
    case invalidBeeps(Int)
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
    case incompatibleSettings(String)

    var errorDescription: String? {
        switch self {
        case .invalidVideoResolution(let value):
            return "Invalid video resolution: \(value)"
        case .invalidFramesPerSecond(let value):
            return "Invalid frames per second: \(value)"
        case .invalidVideoLens(let value):
            return "Invalid video lens: \(value)"
        case .invalidAntiFlicker(let value):
            return "Invalid anti-flicker: \(value)"
        case .invalidHypersmooth(let value):
            return "Invalid hypersmooth: \(value)"
        case .invalidVideoPerformanceMode(let value):
            return "Invalid video performance mode: \(value)"
        case .invalidColorProfile(let value):
            return "Invalid color profile: \(value)"
        case .invalidLcdBrightness(let value):
            return "Invalid LCD brightness: \(value)"
        case .invalidIsoMax(let value):
            return "Invalid ISO max: \(value)"
        case .invalidIsoMin(let value):
            return "Invalid ISO min: \(value)"
        case .invalidLanguage(let value):
            return "Invalid language: \(value)"
        case .invalidBeeps(let value):
            return "Invalid beeps: \(value)"
        case .invalidWhiteBalance(let value):
            return "Invalid white balance: \(value)"
        case .invalidEv(let value):
            return "Invalid EV: \(value)"
        case .invalidBitrate(let value):
            return "Invalid bitrate: \(value)"
        case .invalidRawAudio(let value):
            return "Invalid raw audio: \(value)"
        case .invalidMode(let value):
            return "Invalid mode: \(value)"
        case .invalidShutter(let value):
            return "Invalid shutter: \(value)"
        case .invalidLed(let value):
            return "Invalid LED: \(value)"
        case .invalidWind(let value):
            return "Invalid wind: \(value)"
        case .invalidHindsight(let value):
            return "Invalid hindsight: \(value)"
        case .invalidVoiceLanguageControl(let value):
            return "Invalid voice language control: \(value)"
        case .invalidPrivacy(let value):
            return "Invalid privacy: \(value)"
        case .invalidAutoLock(let value):
            return "Invalid auto lock: \(value)"
        case .invalidTimer(let value):
            return "Invalid timer: \(value)"
        case .invalidVideoCompression(let value):
            return "Invalid video compression: \(value)"
        case .invalidLandscapeLock(let value):
            return "Invalid landscape lock: \(value)"
        case .invalidScreenSaverFront(let value):
            return "Invalid screen saver front: \(value)"
        case .invalidScreenSaverRear(let value):
            return "Invalid screen saver rear: \(value)"
        case .invalidDefaultPreset(let value):
            return "Invalid default preset: \(value)"
        case .invalidFrontLcdMode(let value):
            return "Invalid front LCD mode: \(value)"
        case .invalidGopSize(let value):
            return "Invalid GOP size: \(value)"
        case .invalidIdrInterval(let value):
            return "Invalid IDR interval: \(value)"
        case .invalidBitRateMode(let value):
            return "Invalid bit rate mode: \(value)"
        case .incompatibleSettings(let message):
            return "Incompatible settings: \(message)"
        }
    }
}

// MARK: - Settings Validator
class SettingsValidator {
    static let shared = SettingsValidator()

    private init() {}

    // MARK: - Valid Ranges (based on GoPro firmware analysis)
    private struct ValidRanges {
        static let videoResolution = 0...4
        static let framesPerSecond = 0...13
        static let videoLens = 0...2
        static let antiFlicker = 0...1
        static let hypersmooth = 0...2
        static let videoPerformanceMode = 0...1
        static let colorProfile = 0...1
        static let lcdBrightness = 0...2
        static let isoMax = 0...2
        static let isoMin = 0...8
        static let language = 0...1
        static let beeps = 0...2
        static let whiteBalance = 0...1
        static let ev = 0...5
        static let bitrate = 0...1
        static let rawAudio = 0...1
        static let mode = 0...1
        static let shutter = 0...1
        static let led = 0...2
        static let wind = 0...1
        static let hindsight = 0...1
        static let voiceLanguageControl = 0...1
        static let privacy = 0...1
        static let autoLock = 0...1
        static let timer = 0...1
        static let videoCompression = 0...1
        static let landscapeLock = 0...1
        static let screenSaverFront = 0...1
        static let screenSaverRear = 0...1
        static let defaultPreset = 0...1
        static let frontLcdMode = 0...1
        static let gopSize = 0...1
        static let idrInterval = 0...1
        static let bitRateMode = 0...1
    }

    // MARK: - Validation Methods
    func validateSettings(_ settings: GoProSettings) throws {
        try validateSettingsData(settings)
    }

    func validateSettings(_ settings: GoProSettingsData) throws {
        try validateSettingsData(settings)
    }

    private func validateSettingsData(_ settings: any SettingsProtocol) throws {
        var errors: [SettingsValidationError] = []

        // Validate individual settings
        if !ValidRanges.videoResolution.contains(settings.videoResolution) {
            errors.append(.invalidVideoResolution(settings.videoResolution))
        }

        if !ValidRanges.framesPerSecond.contains(settings.framesPerSecond) {
            errors.append(.invalidFramesPerSecond(settings.framesPerSecond))
        }

        if !ValidRanges.videoLens.contains(settings.videoLens) {
            errors.append(.invalidVideoLens(settings.videoLens))
        }

        if !ValidRanges.antiFlicker.contains(settings.antiFlicker) {
            errors.append(.invalidAntiFlicker(settings.antiFlicker))
        }

        if !ValidRanges.hypersmooth.contains(settings.hypersmooth) {
            errors.append(.invalidHypersmooth(settings.hypersmooth))
        }

        if !ValidRanges.videoPerformanceMode.contains(settings.videoPerformanceMode) {
            errors.append(.invalidVideoPerformanceMode(settings.videoPerformanceMode))
        }

        if !ValidRanges.colorProfile.contains(settings.colorProfile) {
            errors.append(.invalidColorProfile(settings.colorProfile))
        }

        if !ValidRanges.lcdBrightness.contains(settings.lcdBrightness) {
            errors.append(.invalidLcdBrightness(settings.lcdBrightness))
        }

        if !ValidRanges.isoMax.contains(settings.isoMax) {
            errors.append(.invalidIsoMax(settings.isoMax))
        }

        if !ValidRanges.isoMin.contains(settings.isoMin) {
            errors.append(.invalidIsoMin(settings.isoMin))
        }

        if !ValidRanges.language.contains(settings.language) {
            errors.append(.invalidLanguage(settings.language))
        }

        if !ValidRanges.beeps.contains(settings.beeps) {
            errors.append(.invalidBeeps(settings.beeps))
        }

        if !ValidRanges.whiteBalance.contains(settings.whiteBalance) {
            errors.append(.invalidWhiteBalance(settings.whiteBalance))
        }

        if !ValidRanges.ev.contains(settings.ev) {
            errors.append(.invalidEv(settings.ev))
        }

        if !ValidRanges.bitrate.contains(settings.bitrate) {
            errors.append(.invalidBitrate(settings.bitrate))
        }

        if !ValidRanges.rawAudio.contains(settings.rawAudio) {
            errors.append(.invalidRawAudio(settings.rawAudio))
        }

        if !ValidRanges.mode.contains(settings.mode) {
            errors.append(.invalidMode(settings.mode))
        }

        if !ValidRanges.shutter.contains(settings.shutter) {
            errors.append(.invalidShutter(settings.shutter))
        }

        if !ValidRanges.led.contains(settings.led) {
            errors.append(.invalidLed(settings.led))
        }

        if !ValidRanges.wind.contains(settings.wind) {
            errors.append(.invalidWind(settings.wind))
        }

        if !ValidRanges.hindsight.contains(settings.hindsight) {
            errors.append(.invalidHindsight(settings.hindsight))
        }

        if !ValidRanges.voiceLanguageControl.contains(settings.voiceLanguageControl) {
            errors.append(.invalidVoiceLanguageControl(settings.voiceLanguageControl))
        }

        if !ValidRanges.privacy.contains(settings.privacy) {
            errors.append(.invalidPrivacy(settings.privacy))
        }

        if !ValidRanges.autoLock.contains(settings.autoLock) {
            errors.append(.invalidAutoLock(settings.autoLock))
        }

        if !ValidRanges.timer.contains(settings.timer) {
            errors.append(.invalidTimer(settings.timer))
        }

        if !ValidRanges.videoCompression.contains(settings.videoCompression) {
            errors.append(.invalidVideoCompression(settings.videoCompression))
        }

        if !ValidRanges.landscapeLock.contains(settings.landscapeLock) {
            errors.append(.invalidLandscapeLock(settings.landscapeLock))
        }

        if !ValidRanges.screenSaverFront.contains(settings.screenSaverFront) {
            errors.append(.invalidScreenSaverFront(settings.screenSaverFront))
        }

        if !ValidRanges.screenSaverRear.contains(settings.screenSaverRear) {
            errors.append(.invalidScreenSaverRear(settings.screenSaverRear))
        }

        if !ValidRanges.defaultPreset.contains(settings.defaultPreset) {
            errors.append(.invalidDefaultPreset(settings.defaultPreset))
        }

        if !ValidRanges.frontLcdMode.contains(settings.frontLcdMode) {
            errors.append(.invalidFrontLcdMode(settings.frontLcdMode))
        }

        if !ValidRanges.gopSize.contains(settings.gopSize) {
            errors.append(.invalidGopSize(settings.gopSize))
        }

        if !ValidRanges.idrInterval.contains(settings.idrInterval) {
            errors.append(.invalidIdrInterval(settings.idrInterval))
        }

        if !ValidRanges.bitRateMode.contains(settings.bitRateMode) {
            errors.append(.invalidBitRateMode(settings.bitRateMode))
        }

        // Validate compatibility rules
        try validateCompatibilityData(settings)

        // Throw first error if any found
        if let firstError = errors.first {
            // Log validation error for crash reporting
            CrashReporter.shared.logError(
                "Settings Validation Failed",
                error: firstError,
                context: [
                    "error_type": String(describing: type(of: firstError)),
                    "error_description": firstError.localizedDescription,
                    "settings_summary": "Resolution: \(settings.videoResolution), FPS: \(settings.framesPerSecond), Lens: \(settings.videoLens)"
                ]
            )
            throw firstError
        }
    }

    // MARK: - ISO Value Mapping
    private func isoEnumToValue(_ enumValue: Int) -> Int {
        switch enumValue {
        case 0: return 6400
        case 1: return 1600
        case 2: return 400
        case 3: return 3200
        case 4: return 800
        case 7: return 200
        case 8: return 100
        default: return enumValue
        }
    }

    // MARK: - Compatibility Validation
    private func validateCompatibility(_ settings: GoProSettings) throws {
        try validateCompatibilityData(settings)
    }

    private func validateCompatibilityData(_ settings: any SettingsProtocol) throws {
        // High FPS with high resolution may not be supported on all cameras
        if settings.framesPerSecond <= 1 && settings.videoResolution <= 1 {
            // 120+ FPS with 4K - this might be too demanding
            ErrorHandler.warning("High FPS (\(settings.framesPerSecond)) with high resolution (\(settings.videoResolution)) may not be supported on all cameras")
        }

        // Hypersmooth with high FPS may have compatibility issues
        if settings.hypersmooth > 0 && settings.framesPerSecond <= 1 {
            ErrorHandler.warning("Hypersmooth with high FPS may have compatibility issues on some cameras")
        }

        // ISO min should not be higher than ISO max (compare actual ISO values, not enum values)
        let isoMinValue = isoEnumToValue(settings.isoMin)
        let isoMaxValue = isoEnumToValue(settings.isoMax)
        if isoMinValue > isoMaxValue {
            throw SettingsValidationError.incompatibleSettings("ISO min (\(isoMinValue)) cannot be higher than ISO max (\(isoMaxValue))")
        }

        // Protune settings compatibility
        if settings.protuneEnabled {
            // When protune is enabled, certain settings should be in specific ranges
            if settings.colorProfile != 1 {
                ErrorHandler.warning("Protune is enabled but color profile is not set to Flat (1)")
            }
        }
    }

    // MARK: - Quick Validation (for UI feedback)
    func quickValidateSettings(_ settings: GoProSettings) -> [String] {
        return quickValidateSettingsData(settings)
    }

    func quickValidateSettings(_ settings: GoProSettingsData) -> [String] {
        return quickValidateSettingsData(settings)
    }

    private func quickValidateSettingsData(_ settings: any SettingsProtocol) -> [String] {
        var warnings: [String] = []

        // Check for potentially problematic combinations
        if settings.framesPerSecond <= 1 && settings.videoResolution <= 1 {
            warnings.append("High FPS with 4K may not be supported on all cameras")
        }

        if settings.hypersmooth > 0 && settings.framesPerSecond <= 1 {
            warnings.append("Hypersmooth with high FPS may have compatibility issues")
        }

        // ISO min should not be higher than ISO max (compare actual ISO values, not enum values)
        let isoMinValue = isoEnumToValue(settings.isoMin)
        let isoMaxValue = isoEnumToValue(settings.isoMax)
        if isoMinValue > isoMaxValue {
            warnings.append("ISO min (\(isoMinValue)) cannot be higher than ISO max (\(isoMaxValue))")
        }

        if settings.protuneEnabled && settings.colorProfile != 1 {
            warnings.append("Protune is enabled but color profile is not Flat")
        }

        return warnings
    }

    // MARK: - Get Valid Options
    func getValidOptions(for setting: String) -> [Int] {
        switch setting {
        case "videoResolution":
            return Array(ValidRanges.videoResolution)
        case "framesPerSecond":
            return Array(ValidRanges.framesPerSecond)
        case "videoLens":
            return Array(ValidRanges.videoLens)
        case "antiFlicker":
            return Array(ValidRanges.antiFlicker)
        case "hypersmooth":
            return Array(ValidRanges.hypersmooth)
        case "videoPerformanceMode":
            return Array(ValidRanges.videoPerformanceMode)
        case "colorProfile":
            return Array(ValidRanges.colorProfile)
        case "lcdBrightness":
            return Array(ValidRanges.lcdBrightness)
        case "isoMax":
            return Array(ValidRanges.isoMax)
        case "isoMin":
            return Array(ValidRanges.isoMin)
        case "language":
            return Array(ValidRanges.language)
        case "beeps":
            return Array(ValidRanges.beeps)
        case "whiteBalance":
            return Array(ValidRanges.whiteBalance)
        case "ev":
            return Array(ValidRanges.ev)
        case "bitrate":
            return Array(ValidRanges.bitrate)
        case "rawAudio":
            return Array(ValidRanges.rawAudio)
        case "mode":
            return Array(ValidRanges.mode)
        case "shutter":
            return Array(ValidRanges.shutter)
        case "led":
            return Array(ValidRanges.led)
        case "wind":
            return Array(ValidRanges.wind)
        case "hindsight":
            return Array(ValidRanges.hindsight)
        case "voiceLanguageControl":
            return Array(ValidRanges.voiceLanguageControl)
        case "privacy":
            return Array(ValidRanges.privacy)
        case "autoLock":
            return Array(ValidRanges.autoLock)
        case "timer":
            return Array(ValidRanges.timer)
        case "videoCompression":
            return Array(ValidRanges.videoCompression)
        case "landscapeLock":
            return Array(ValidRanges.landscapeLock)
        case "screenSaverFront":
            return Array(ValidRanges.screenSaverFront)
        case "screenSaverRear":
            return Array(ValidRanges.screenSaverRear)
        case "defaultPreset":
            return Array(ValidRanges.defaultPreset)
        case "frontLcdMode":
            return Array(ValidRanges.frontLcdMode)
        case "gopSize":
            return Array(ValidRanges.gopSize)
        case "idrInterval":
            return Array(ValidRanges.idrInterval)
        case "bitRateMode":
            return Array(ValidRanges.bitRateMode)
        default:
            return []
        }
    }
}
