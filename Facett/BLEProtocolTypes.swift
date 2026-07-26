import Foundation

// Protocol-level model types used by the BLE layer. These are standalone: they
// were declared alongside BLEManager but are not part of it, and BLEManager.swift
// sits at SwiftLint's 2600-line file ceiling, so it cannot take on changes
// without something moving out first.

// MARK: - Camera Mode Enum

enum CameraMode: Int, CaseIterable {
    case video = 12
    case photo = 17
    case multishot = 19  // Burst Photo (closest to multishot)
    case looping = 15
    case nightPhoto = 18
    case timeLapseVideo = 13
    case timeLapsePhoto = 20
    case nightLapsePhoto = 21
    case timeWarpVideo = 24
    case liveBurst = 25
    case nightLapseVideo = 26
    case sloMo = 27
    case unknown = -1

    var description: String {
        switch self {
        case .video: return "Video"
        case .photo: return "Photo"
        case .multishot: return "Multishot (Burst Photo)"
        case .looping: return "Looping"
        case .nightPhoto: return "Night Photo"
        case .timeLapseVideo: return "Time Lapse Video"
        case .timeLapsePhoto: return "Time Lapse Photo"
        case .nightLapsePhoto: return "Night Lapse Photo"
        case .timeWarpVideo: return "Time Warp Video"
        case .liveBurst: return "Live Burst"
        case .nightLapseVideo: return "Night Lapse Video"
        case .sloMo: return "Slo-Mo"
        case .unknown: return "Unknown"
        }
    }

    static func fromInt(_ mode: Int) -> CameraMode {
        return CameraMode(rawValue: mode) ?? .unknown
    }
}

struct GoProSetting {
    let id: UInt8
    let valueLength: UInt8
    let expectedValue: UInt8
    let description: String
}

enum ResponseType {
    // Status
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

    // Setting
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

            // Additional status and settings cases
        case wifiBars(Int)
        case cameraMode(Int)
        case videoMode(Int)
        case photoMode(Int)
        case multiShotMode(Int)
        case flatMode(Int)
        case videoProtune(Bool)
        case videoStabilization(Int)
        case videoFieldOfView(Int)
        case turboMode(Bool)

        // WiFi credentials
        case wifiSSID(String)
        case apSSID(String)
        case apState(Int)
        case wifiPassword(String)
        case apPassword(String)

    // New settings from firmware analysis
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
    case secondaryStreamGopSize(Int)
    case secondaryStreamIdrInterval(Int)
    case secondaryStreamBitRate(Int)
    case secondaryStreamWindowSize(Int)
    case gopSize(Int)
    case idrInterval(Int)
    case bitRateMode(Int)
    case audioProtune(Bool)
    case noAudioTrack(Bool)

    // New status from firmware analysis
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
