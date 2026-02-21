import Foundation

// MARK: - Camera Setting Description Functions
// This file contains all the description functions for GoPro camera settings
// These functions convert numeric setting values to human-readable strings

struct CameraSettingDescriptions {

    // MARK: - Video Settings

    static func resolutionDescription(for value: Int) -> String {
        switch value {
        case 1: return "4K"
        case 4: return "2.7K"
        case 6: return "2.7K 4:3"
        case 9: return "1080"
        case 18: return "4K 4:3"
        case 25: return "5K 4:3"
        case 100: return "5.3K"
        default: return "Unknown"
        }
    }

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

    static func modeDescription(for value: Int) -> String {
        switch value {
        case 12: return "Video"
        case 15: return "Looping"
        case 17: return "Photo"
        case 18: return "Night Photo"
        case 19: return "Burst Photo"
        case 13: return "Time Lapse Video"
        case 20: return "Time Lapse Photo"
        case 21: return "Night Lapse Photo"
        case 24: return "Time Warp Video"
        case 25: return "Live Burst"
        case 26: return "Night Lapse Video"
        case 27: return "Slo-Mo"
        default: return "Unknown"
        }
    }

    static func lensDescription(for value: Int) -> String {
        switch value {
        case 0: return "Wide"
        case 2: return "Narrow"
        case 3: return "Superview"
        case 4: return "Linear"
        case 7: return "Max SuperView"
        case 8: return "Linear + Horizon Leveling"
        default: return "Unknown"
        }
    }

    static func hypersmoothDescription(for value: Int) -> String {
        switch value {
        case 0: return "Off"
        case 1: return "Low"
        case 2: return "High"
        case 3: return "Boost"
        case 100: return "Standard"
        default: return "Unknown"
        }
    }

    static func bitrateDescription(for value: Int) -> String {
        switch value {
        case 1: return "High"
        case 0: return "Standard"
        default: return "Unknown"
        }
    }

    // MARK: - Photo Settings

    static func shutterDescription(for value: Int) -> String {
        switch value {
        case 0: return "Auto"
        default: return "\(value)"
        }
    }

    // MARK: - Audio Settings

    static func rawAudioDescription(for value: Int) -> String {
        switch value {
        case 2: return "High"
        case 1: return "Medium"
        case 0: return "Low"
        case 3: return "Off"
        default: return "Unknown"
        }
    }

    // MARK: - Power Settings

    static func autoPowerDownDescription(for value: Int) -> String {
        switch value {
        case 0: return "Never"
        case 4: return "5 Min"
        case 6: return "15 Min"
        case 7: return "30 Min"
        default: return "Unknown"
        }
    }

    // MARK: - Display Settings

    static func lcdBrightnessProfileDescription(for value: Int) -> String {
        return "\(value)%"
    }

    // MARK: - Image Quality Settings

    static func colorProfileDescription(for value: Int) -> String {
        switch value {
        case 0: return "GoPro"
        case 1: return "Flat"
        default: return "Unknown"
        }
    }

    static func isoMaxDescription(for value: Int) -> String {
        switch value {
        case 0: return "6400"
        case 3: return "3200"
        case 1: return "1600"
        case 4: return "800"
        case 2: return "400"
        case 7: return "200"
        case 8: return "100"
        default: return "Unknown"
        }
    }

    static func isoMinDescription(for value: Int) -> String {
        switch value {
        case 0: return "6400"
        case 3: return "3200"
        case 1: return "1600"
        case 4: return "800"
        case 2: return "400"
        case 7: return "200"
        case 8: return "100"
        default: return "Unknown"
        }
    }

    static func whiteBalanceDescription(for value: Int) -> String {
        switch value {
        case 3: return "6500K"
        case 7: return "6000K"
        case 2: return "5500K"
        case 12: return "5000K"
        case 11: return "4500K"
        case 0: return "Auto"
        case 4: return "Native"
        case 5: return "4000K"
        case 10: return "3200K"
        case 9: return "2800K"
        case 8: return "2300K"
        default: return "Unknown"
        }
    }

    static func evDescription(for value: Int) -> String {
        switch value {
        case 8: return "-2.0"
        case 7: return "-1.5"
        case 6: return "-1.0"
        case 5: return "-0.5"
        case 4: return "0.0"
        case 3: return "0.5"
        case 2: return "1.0"
        case 1: return "1.5"
        case 0: return "2.0"
        default: return "Unknown"
        }
    }

    // MARK: - Advanced Settings

    static func antiFlickerDescription(for value: Int) -> String {
        switch value {
        case 2: return "60Hz"
        case 3: return "50Hz"
        default: return "Unknown"
        }
    }

    static func windDescription(for value: Int) -> String {
        switch value {
        case 2: return "Auto"
        case 4: return "On"
        case 0: return "Off"
        default: return "Unknown"
        }
    }

    static func hindsightDescription(for value: Int) -> String {
        switch value {
        case 2: return "15 Seconds"
        case 3: return "30 Seconds"
        case 4: return "Off"
        default: return "Unknown"
        }
    }

    // MARK: - Additional Description Functions

    static func performanceModeDescription(for value: Int) -> String {
        switch value {
        case 0: return "Maximum Video Performance"
        case 1: return "Extended Battery"
        case 2: return "Tripod / Stationary Video"
        default: return "Unknown"
        }
    }

    static func languageDescription(for value: Int) -> String {
        switch value {
        case 0: return "English"
        case 1: return "French"
        case 2: return "German"
        case 3: return "Spanish"
        case 4: return "Italian"
        case 5: return "Portuguese"
        case 6: return "Russian"
        case 7: return "Chinese"
        case 8: return "Japanese"
        case 9: return "Korean"
        default: return "Unknown"
        }
    }

    static func beepsDescription(for value: Int) -> String {
        switch value {
        case 0: return "Off"
        case 1: return "Low"
        case 2: return "High"
        default: return "Unknown"
        }
    }

    static func ledDescription(for value: Int) -> String {
        switch value {
        case 0: return "Off"
        case 1: return "2%"
        case 2: return "100%"
        default: return "Unknown"
        }
    }

    static func voiceLanguageControlDescription(for value: Int) -> String {
        switch value {
        case 0: return "English - US"
        default: return "\(value)"
        }
    }

    static func privacyDescription(for value: Int) -> String {
        switch value {
        case 0: return "Off"
        case 1: return "On"
        default: return "Unknown"
        }
    }

    static func autoLockDescription(for value: Int) -> String {
        switch value {
        case 0: return "Never"
        case 1: return "1 Minute"
        case 2: return "2 Minutes"
        case 3: return "3 Minutes"
        case 4: return "5 Minutes"
        default: return "Unknown"
        }
    }

    static func timerDescription(for value: Int) -> String {
        switch value {
        case 0: return "Off"
        case 1: return "3 Seconds"
        case 2: return "10 Seconds"
        default: return "Unknown"
        }
    }

    static func landscapeLockDescription(for value: Int) -> String {
        switch value {
        case 0: return "Off"
        case 1: return "On"
        default: return "Unknown"
        }
    }

    static func frontLcdModeDescription(for value: Int) -> String {
        switch value {
        case 0: return "Off"
        case 1: return "On"
        default: return "Unknown"
        }
    }

    static func defaultPresetDescription(for value: Int) -> String {
        switch value {
        case 0: return "Standard"
        case 1: return "Activity"
        case 2: return "Cinematic"
        case 3: return "Slo-Mo"
        case 4: return "Photo"
        case 5: return "Time Lapse"
        case 6: return "Night Lapse"
        default: return "Unknown"
        }
    }

    static func videoCompressionDescription(for value: Int) -> String {
        switch value {
        case 0: return "H.264"
        case 1: return "H.265"
        default: return "Unknown"
        }
    }

    static func screenSaverDescription(for value: Int) -> String {
        switch value {
        case 0: return "Never"
        case 1: return "1 Minute"
        case 2: return "2 Minutes"
        case 3: return "3 Minutes"
        case 4: return "5 Minutes"
        default: return "Unknown"
        }
    }

    static func bitRateModeDescription(for value: Int) -> String {
        switch value {
        case 0: return "Auto"
        case 1: return "Manual"
        default: return "Unknown"
        }
    }
}

// MARK: - Convenience Functions for Backward Compatibility
// These functions maintain the same interface as the original private functions

func resolutionDescription(for value: Int) -> String {
    return CameraSettingDescriptions.resolutionDescription(for: value)
}

func fpsDescription(for value: Int) -> String {
    return CameraSettingDescriptions.fpsDescription(for: value)
}

func modeDescription(for value: Int) -> String {
    return CameraSettingDescriptions.modeDescription(for: value)
}

func lensDescription(for value: Int) -> String {
    return CameraSettingDescriptions.lensDescription(for: value)
}

func hypersmoothDescription(for value: Int) -> String {
    return CameraSettingDescriptions.hypersmoothDescription(for: value)
}

func bitrateDescription(for value: Int) -> String {
    return CameraSettingDescriptions.bitrateDescription(for: value)
}

func shutterDescription(for value: Int) -> String {
    return CameraSettingDescriptions.shutterDescription(for: value)
}

func rawAudioDescription(for value: Int) -> String {
    return CameraSettingDescriptions.rawAudioDescription(for: value)
}

func autoPowerDownDescription(for value: Int) -> String {
    return CameraSettingDescriptions.autoPowerDownDescription(for: value)
}

func lcdBrightnessProfileDescription(for value: Int) -> String {
    return CameraSettingDescriptions.lcdBrightnessProfileDescription(for: value)
}

func colorProfileDescription(for value: Int) -> String {
    return CameraSettingDescriptions.colorProfileDescription(for: value)
}

func isoMaxDescription(for value: Int) -> String {
    return CameraSettingDescriptions.isoMaxDescription(for: value)
}

func isoMinDescription(for value: Int) -> String {
    return CameraSettingDescriptions.isoMinDescription(for: value)
}

func whiteBalanceDescription(for value: Int) -> String {
    return CameraSettingDescriptions.whiteBalanceDescription(for: value)
}

func evDescription(for value: Int) -> String {
    return CameraSettingDescriptions.evDescription(for: value)
}

func antiFlickerDescription(for value: Int) -> String {
    return CameraSettingDescriptions.antiFlickerDescription(for: value)
}

func windDescription(for value: Int) -> String {
    return CameraSettingDescriptions.windDescription(for: value)
}

func hindsightDescription(for value: Int) -> String {
    return CameraSettingDescriptions.hindsightDescription(for: value)
}
