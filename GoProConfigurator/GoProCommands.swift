import Foundation

// MARK: - GoPro Command Definitions
// Centralized command definitions to eliminate hardcoded arrays throughout the codebase

struct GoProCommands {

    // MARK: - Status Query Commands
    struct Status {
        // Consolidated status query - includes all status fields we need (20 byte limit)
        static let status1: [UInt8] = [19, 19, 1, 2, 3, 6, 8, 10, 13, 31, 68, 70, 82, 85, 111, 114, 115, 116, 54, 113] // Added back type 3 (external battery present)
        static let status2: [UInt8] = [4, 19, 78, 63, 109, 104]

        // WiFi credentials query (separate query to avoid exceeding 20-byte limit)
        static let wifiCredentials: [UInt8] = [19, 19, 29, 30, 69, 71, 72] // WiFi SSID, AP SSID, AP State, WiFi Password, AP Password

        // Alternative WiFi credentials query with different TLV types
        static let wifiCredentialsAlt: [UInt8] = [19, 19, 29, 30, 69, 73, 74, 75] // Try different TLV types for passwords

        // GPCAMERA_GET_WIFI_CONFIG command
        static let getWiFiConfig: [UInt8] = [4, 241, 108, 8, 0] // Command to get WiFi configuration
    }

    // MARK: - Settings Query Commands
    struct Settings {
        // Consolidated settings query - includes all settings we need (20 byte limit each)
        static let settings1: [UInt8] = [19, 18, 96, 102, 54, 85, 2, 3, 59, 83, 121, 134, 135, 162, 173, 149, 118, 124, 139, 144]
        static let settings2: [UInt8] = [15, 18, 145, 13, 91, 115, 116, 167, 84, 86, 87, 88, 114, 79, 96]
        static let settings3: [UInt8] = [18, 18, 48, 103, 104, 105, 106, 112, 154, 158, 159, 161, 60, 61, 62, 64, 65, 66, 67]
    }

    // MARK: - Control Commands
    struct Control {
        // Claim control
        static let claimControl: [UInt8] = [3, 23, 1, 1]

        // Release control
        static let releaseControl: [UInt8] = [3, 23, 1, 0]

        // Sleep command
        static let sleep: [UInt8] = [3, 23, 1, 2]

        // Power down command
        static let powerDown: [UInt8] = [3, 23, 1, 3]
    }

    // MARK: - AP (Access Point) Commands
    struct AccessPoint {
        // Enable AP
        static let enable: [UInt8] = [3, 23, 1, 1]

        // Disable AP
        static let disable: [UInt8] = [3, 23, 1, 0]
    }

    // MARK: - Turbo Transfer Commands
    struct TurboTransfer {
        // Enable turbo transfer
        static let enable: [UInt8] = [4, 241, 107, 8, 1]

        // Disable turbo transfer
        static let disable: [UInt8] = [4, 241, 107, 8, 0]
    }

    // MARK: - Recording Commands
    struct Recording {
        // Start recording
        static let start: [UInt8] = [3, 23, 1, 1]

        // Stop recording
        static let stop: [UInt8] = [3, 23, 1, 0]
    }

    // MARK: - Mode Commands
    struct Mode {
        // Set video mode
        static let video: [UInt8] = [3, 23, 1, 12]

        // Set photo mode
        static let photo: [UInt8] = [3, 23, 1, 17]

        // Set multishot mode
        static let multishot: [UInt8] = [3, 23, 1, 19]
    }
}

// MARK: - Command Categories
enum CommandCategory {
    case status
    case settings
    case control
    case accessPoint
    case turboTransfer
    case recording
    case mode
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

// MARK: - Command Metadata
struct CommandMetadata {
    let command: [UInt8]
    let name: String
    let category: CommandCategory
    let priority: CommandPriority
    let timeout: TimeInterval
    let requiresControl: Bool

    init(command: [UInt8], name: String, category: CommandCategory, priority: CommandPriority = .normal, timeout: TimeInterval = 5.0, requiresControl: Bool = false) {
        self.command = command
        self.name = name
        self.category = category
        self.priority = priority
        self.timeout = timeout
        self.requiresControl = requiresControl
    }
}

// MARK: - Command Registry
class GoProCommandRegistry {
    static let shared = GoProCommandRegistry()

    private var commands: [String: CommandMetadata] = [:]

    private init() {
        registerDefaultCommands()
    }

    private func registerDefaultCommands() {
        // Status commands
        register(GoProCommands.Status.status1, name: "consolidated status1", category: .status, priority: .high)
        register(GoProCommands.Status.status2, name: "consolidated status2", category: .status, priority: .high)
        register(GoProCommands.Status.wifiCredentials, name: "WiFi credentials", category: .status, priority: .normal)
        register(GoProCommands.Status.wifiCredentialsAlt, name: "WiFi credentials alt", category: .status, priority: .normal)
        register(GoProCommands.Status.getWiFiConfig, name: "get WiFi config", category: .status, priority: .normal)

        // Settings commands
        register(GoProCommands.Settings.settings1, name: "consolidated settings1", category: .settings, priority: .normal)
        register(GoProCommands.Settings.settings2, name: "consolidated settings2", category: .settings, priority: .normal)
        register(GoProCommands.Settings.settings3, name: "consolidated settings3", category: .settings, priority: .normal)

        // Control commands
        register(GoProCommands.Control.claimControl, name: "claim control", category: .control, priority: .critical, requiresControl: true)
        register(GoProCommands.Control.releaseControl, name: "release control", category: .control, priority: .critical, requiresControl: true)
        register(GoProCommands.Control.sleep, name: "sleep", category: .control, priority: .high, requiresControl: true)
        register(GoProCommands.Control.powerDown, name: "power down", category: .control, priority: .high, requiresControl: true)

        // AP commands
        register(GoProCommands.AccessPoint.enable, name: "enable AP", category: .accessPoint, priority: .normal)
        register(GoProCommands.AccessPoint.disable, name: "disable AP", category: .accessPoint, priority: .normal)

        // Turbo transfer commands
        register(GoProCommands.TurboTransfer.enable, name: "enable turbo transfer", category: .turboTransfer, priority: .normal)
        register(GoProCommands.TurboTransfer.disable, name: "disable turbo transfer", category: .turboTransfer, priority: .normal)

        // Recording commands
        register(GoProCommands.Recording.start, name: "start recording", category: .recording, priority: .high, requiresControl: true)
        register(GoProCommands.Recording.stop, name: "stop recording", category: .recording, priority: .high, requiresControl: true)

        // Mode commands
        register(GoProCommands.Mode.video, name: "set video mode", category: .mode, priority: .normal)
        register(GoProCommands.Mode.photo, name: "set photo mode", category: .mode, priority: .normal)
        register(GoProCommands.Mode.multishot, name: "set multishot mode", category: .mode, priority: .normal)
    }

    private func register(_ command: [UInt8], name: String, category: CommandCategory, priority: CommandPriority = .normal, timeout: TimeInterval = 5.0, requiresControl: Bool = false) {
        let key = command.map { String(format: "%02X", $0) }.joined()
        let metadata = CommandMetadata(command: command, name: name, category: category, priority: priority, timeout: timeout, requiresControl: requiresControl)
        commands[key] = metadata
    }

    func getMetadata(for command: [UInt8]) -> CommandMetadata? {
        let key = command.map { String(format: "%02X", $0) }.joined()
        return commands[key]
    }

    func getCommands(by category: CommandCategory) -> [CommandMetadata] {
        return commands.values.filter { $0.category == category }
    }

    func getCommands(by priority: CommandPriority) -> [CommandMetadata] {
        return commands.values.filter { $0.priority == priority }
    }
}
