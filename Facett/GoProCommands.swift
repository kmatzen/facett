import Foundation

// MARK: - GoPro Command Definitions
// Centralized command definitions for the GoPro BLE protocol.
// Byte arrays include the General (5-bit) packet header as the first byte.
// See: https://gopro.github.io/OpenGoPro/ble/protocol/data_protocol.html

struct GoProCommands {

    // MARK: - Status Query Commands
    // Query ID 0x13 = Get Status Values
    // Format: [header (length)] [0x13] [statusID1] [statusID2] ...
    struct Status {
        static let status1: [UInt8] = [19, 0x13, 1, 2, 3, 6, 8, 10, 13, 31, 68, 70, 82, 85, 111, 114, 115, 116, 54, 113]
        static let status2: [UInt8] = [4, 0x13, 78, 63, 109, 104]

        static let wifiCredentials: [UInt8] = [19, 0x13, 29, 30, 69, 71, 72]
        static let wifiCredentialsAlt: [UInt8] = [19, 0x13, 29, 30, 69, 73, 74, 75]

        // Protobuf: Feature 0xF1, Action 0x6C (undocumented)
        static let getWiFiConfig: [UInt8] = [4, 0xF1, 0x6C, 0x08, 0x00]
    }

    // MARK: - Settings Query Commands
    // Query ID 0x12 = Get Setting Values
    // Format: [header (length)] [0x12] [settingID1] [settingID2] ...
    struct Settings {
        static let settings1: [UInt8] = [19, 0x12, 96, 102, 54, 85, 2, 3, 59, 83, 121, 134, 135, 162, 173, 149, 118, 124, 139, 144]
        static let settings2: [UInt8] = [15, 0x12, 145, 13, 91, 115, 116, 167, 84, 86, 87, 88, 114, 79, 96]
        static let settings3: [UInt8] = [18, 0x12, 48, 103, 104, 105, 106, 112, 154, 158, 159, 161, 60, 61, 62, 64, 65, 66, 67]
    }

    // MARK: - Control Commands
    struct Control {
        // Protobuf: Feature 0xF1, Action 0x69 (RequestSetCameraControlStatus)
        // Value 2 = EXTERNAL (app claims control)
        static let claimControl: [UInt8] = [0x04, 0xF1, 0x69, 0x08, 0x02]

        // Protobuf: Feature 0xF1, Action 0x69 (RequestSetCameraControlStatus)
        // Value 0 = IDLE (app releases control)
        static let releaseControl: [UInt8] = [0x04, 0xF1, 0x69, 0x08, 0x00]

        // TLV Command ID 0x05 = Sleep
        static let sleep: [UInt8] = [0x01, 0x05]

        // TLV Command ID 0x11 = Reboot
        static let reboot: [UInt8] = [0x01, 0x11]
    }

    // MARK: - AP (Access Point) Commands
    // TLV Command ID 0x17 = Set AP Control
    struct AccessPoint {
        // Parameter: 1 = enable
        static let enable: [UInt8] = [0x03, 0x17, 0x01, 0x01]

        // Parameter: 0 = disable
        static let disable: [UInt8] = [0x03, 0x17, 0x01, 0x00]
    }

    // MARK: - Turbo Transfer Commands
    // Protobuf: Feature 0xF1, Action 0x6B (RequestSetTurboActive)
    struct TurboTransfer {
        static let enable: [UInt8] = [0x04, 0xF1, 0x6B, 0x08, 0x01]
        static let disable: [UInt8] = [0x04, 0xF1, 0x6B, 0x08, 0x00]
    }

    // MARK: - Recording Commands
    // TLV Command ID 0x01 = Set Shutter
    struct Recording {
        // Parameter: 1 = shutter on (start recording)
        static let start: [UInt8] = [0x03, 0x01, 0x01, 0x01]

        // Parameter: 0 = shutter off (stop recording)
        static let stop: [UInt8] = [0x03, 0x01, 0x01, 0x00]
    }

    // MARK: - Mode Commands
    // Set Setting: Setting ID 144 (0x90) = camera mode (undocumented)
    // CameraMode raw values: video=12, photo=17, multishot=19
    struct Mode {
        static let video: [UInt8] = [0x03, 0x90, 0x01, 0x0C]
        static let photo: [UInt8] = [0x03, 0x90, 0x01, 0x11]
        static let multishot: [UInt8] = [0x03, 0x90, 0x01, 0x13]
    }

    // MARK: - Keep Alive
    // TLV Command ID 0x5B, sent on the Setting characteristic
    struct KeepAlive {
        static let ping: [UInt8] = [0x02, 0x5B, 0x42]
    }
}

// MARK: - Command Priority
enum CommandPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: CommandPriority, rhs: CommandPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
