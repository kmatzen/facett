import Foundation

// MARK: - Default Configurations
class DefaultConfigurations {

    /// Creates the default set of camera configurations
    static func createDefaultConfigs() -> [CameraConfig] {
        // Default Config - must match BLEManager.defaultGoProSettings exactly
        let defaultConfig = CameraConfig(
            name: "Default",
            description: "Standard settings for general use",
            isDefault: true
        )
        // Use the exact default settings without any modifications

        // Professional Video Config
        var professionalConfig = CameraConfig(
            name: "Professional Video",
            description: "High-quality settings for professional video production",
            isDefault: false
        )
        var professionalSettings = professionalConfig.settings
        professionalSettings.videoResolution = 1 // 4K
        professionalSettings.framesPerSecond = 5 // 60 FPS
        professionalSettings.colorProfile = 1 // Flat
        professionalSettings.protuneEnabled = true
        professionalSettings.ev = 4 // Neutral
        professionalSettings.bitrate = 1 // High
        professionalSettings.rawAudio = 2 // High
        professionalConfig.settings = professionalSettings

        // Action Sports Config
        var actionConfig = CameraConfig(
            name: "Action Sports",
            description: "Optimized for fast-paced action and sports",
            isDefault: false
        )
        var actionSettings = actionConfig.settings
        actionSettings.videoResolution = 1 // 4K
        actionSettings.framesPerSecond = 1 // 120 FPS (more compatible than 240 FPS)
        actionSettings.hypersmooth = 0 // Off (for compatibility with older cameras)
        actionSettings.quickCapture = true
        actionSettings.ev = 5 // Slightly brighter
        actionSettings.rawAudio = 2 // High
        actionConfig.settings = actionSettings

        // Low Light Config
        var lowLightConfig = CameraConfig(
            name: "Low Light",
            description: "Optimized for shooting in low light conditions",
            isDefault: false
        )
        var lowLightSettings = lowLightConfig.settings
        lowLightSettings.videoResolution = 4 // 2.7K (better low light)
        lowLightSettings.framesPerSecond = 8 // 30 FPS
        lowLightSettings.isoMax = 2 // Higher ISO
        lowLightSettings.isoMin = 6 // Lower minimum ISO
        lowLightSettings.ev = 5 // Brighter exposure
        lowLightSettings.whiteBalance = 1 // Auto
        lowLightSettings.rawAudio = 2 // High
        lowLightConfig.settings = lowLightSettings

        // Documentary Config
        var documentaryConfig = CameraConfig(
            name: "Documentary",
            description: "Balanced settings for documentary and interview work",
            isDefault: false
        )
        var documentarySettings = documentaryConfig.settings
        documentarySettings.videoResolution = 1 // 4K
        documentarySettings.framesPerSecond = 8 // 30 FPS
        documentarySettings.colorProfile = 0 // Natural
        documentarySettings.protuneEnabled = false
        documentarySettings.ev = 4 // Neutral
        documentarySettings.voiceControl = true
        documentarySettings.rawAudio = 2 // High
        documentaryConfig.settings = documentarySettings

        return [defaultConfig, professionalConfig, actionConfig, lowLightConfig, documentaryConfig]
    }

    /// Helper function for FPS descriptions
    static func fpsDescription(for value: Int) -> String {
        switch value {
        case 0: return "240.0"
        case 1: return "120.0"
        case 2: return "100.0"
        case 5: return "60.0"
        case 6: return "50.0"
        case 8: return "30.0"
        case 9: return "25.0"
        case 10: return "24.0"
        case 13: return "200.0"
        default: return "Unknown"
        }
    }
}

// MARK: - Configuration Validation
class ConfigValidation {

    /// Validates the current selected configuration
    static func validateCurrentConfig(_ configManager: ConfigManager) -> (isValid: Bool, warnings: [String], errors: [String]) {
        guard let selectedConfig = configManager.getSelectedConfig() else {
            return (false, [], ["No configuration selected"])
        }

        return validateConfig(selectedConfig)
    }

    /// Validates a specific configuration
    static func validateConfig(_ config: CameraConfig) -> (isValid: Bool, warnings: [String], errors: [String]) {
        var warnings: [String] = []
        var errors: [String] = []

        // Validate settings
        do {
            try SettingsValidator.shared.validateSettings(config.settings)
        } catch {
            errors.append(error.localizedDescription)
        }

        // Get warnings for potentially problematic combinations
        warnings = SettingsValidator.shared.quickValidateSettings(config.settings)

        return (errors.isEmpty, warnings, errors)
    }

    /// Checks if a camera's settings match the target settings
    /// Only checks settings that are actually configurable and part of the sync process
    static func hasSettingsMismatch(gopro: GoPro, targetSettings: GoProSettings) -> Bool {
        // Skip settings mismatch checks for recording cameras to avoid false positives
        // Some settings change or become unavailable during recording
        if gopro.status.isEncoding == true {
            return false
        }

        // Only check settings that are actually sent during sync (see sendSettings in BLEManager)
        // These correspond to the settings IDs that are actually transmitted to the camera

        if gopro.settings.videoResolution != targetSettings.videoResolution {
            return true
        }
        if gopro.settings.framesPerSecond != targetSettings.framesPerSecond {
            return true
        }
        // Core settings that are actually synced
        if gopro.settings.autoPowerDown != targetSettings.autoPowerDown {
            return true
        }
        if gopro.settings.gps != targetSettings.gps {
            return true
        }
        if gopro.settings.videoLens != targetSettings.videoLens {
            return true
        }
        if gopro.settings.antiFlicker != targetSettings.antiFlicker {
            return true
        }
        if gopro.settings.hypersmooth != targetSettings.hypersmooth {
            return true
        }
        if gopro.settings.maxLens != targetSettings.maxLens {
            return true
        }
        if gopro.settings.videoPerformanceMode != targetSettings.videoPerformanceMode {
            return true
        }
        if gopro.settings.isoMax != targetSettings.isoMax {
            return true
        }
        if gopro.settings.isoMin != targetSettings.isoMin {
            return true
        }
        if gopro.settings.whiteBalance != targetSettings.whiteBalance {
            return true
        }
        if gopro.settings.colorProfile != targetSettings.colorProfile {
            return true
        }
        if gopro.settings.ev != targetSettings.ev {
            return true
        }
        if gopro.settings.bitrate != targetSettings.bitrate {
            return true
        }
        if gopro.settings.rawAudio != targetSettings.rawAudio {
            return true
        }

        // Additional settings that ARE actually synced (from sendSettings function)
        if gopro.settings.mode != targetSettings.mode {
            return true
        }
        if gopro.settings.hindsight != targetSettings.hindsight {
            return true
        }
        if gopro.settings.quickCapture != targetSettings.quickCapture {
            return true
        }
        if gopro.settings.wind != targetSettings.wind {
            return true
        }
        if gopro.settings.protuneEnabled != targetSettings.protuneEnabled {
            return true
        }
        if gopro.settings.lcdBrightness != targetSettings.lcdBrightness {
            return true
        }

        // Note: Shutter is intentionally NOT checked because it changes during recording
        // The camera automatically adjusts shutter when recording starts/stops

        return false
    }
}
