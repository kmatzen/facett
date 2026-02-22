import SwiftUI
import CoreBluetooth

// ConnectionRetryStatus enum is now defined in BLEConnectionManager.swift

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

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var connectedGoPros: [UUID: GoPro] = [:]
    @Published var connectingGoPros: [UUID: GoPro] = [:] // Tracks GoPros in the process of connecting
    @Published var camerasBeingConnectedFromGroup: Set<UUID> = [] // Tracks cameras being connected via group button
    @Published var connectionRetryStatus: [UUID: ConnectionRetryStatus] = [:] // Tracks retry status for UI feedback

    // Callback for immediate sync triggering
    var onCameraStatusUpdated: ((UUID) -> Void)?
    var onCameraConnected: ((UUID) -> Void)?

    // MARK: - BLE Component Managers
    private let connectionManager = BLEConnectionManager()
    private let performanceMonitor = BLEPerformanceMonitor()
    private let deviceStateManager = BLEDeviceStateManager()
    private let wifiManager = BLEWiFiManager()
    private var recordingManager: BLERecordingManager!
    private var modeManager: BLEModeManager!
    private var responseHandler: BLEResponseHandler!
    private var connectionHandler: BLEConnectionHandler!

    // Connection retry tracking
    private var connectionRetryCount: [UUID: Int] = [:]
    private var connectionRetryTimers: [UUID: Timer] = [:]
    private var connectionAttemptTimers: [UUID: Timer] = [:] // Timeout for individual attempts
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0 // Base delay for exponential backoff
    private let maxRetryDelay: TimeInterval = 30.0 // Maximum delay between retries
    private let connectionTimeout: TimeInterval = 10.0 // Timeout for individual connection attempts

    // Command timeout tracking
    private var pendingCommands: [UUID: [PendingCommand]] = [:]
    private let defaultCommandTimeout: TimeInterval = 5.0 // Default timeout for commands
    private let commandRetryAttempts = 2 // Number of retry attempts for failed commands

    // MARK: - Command Timeout Infrastructure

    // PendingCommand struct for tracking commands awaiting responses
    private struct PendingCommand {
        let command: [UInt8]
        let commandName: String
        let timestamp: Date
        let timeout: TimeInterval
        let retryCount: Int
        let requiresControl: Bool
    }

    /// Add a command to the pending commands list with timeout tracking
    private func addPendingCommand(_ command: [UInt8], commandName: String, to uuid: UUID, timeout: TimeInterval = 5.0, requiresControl: Bool = false) {
        let pendingCommand = PendingCommand(
            command: command,
            commandName: commandName,
            timestamp: Date(),
            timeout: timeout,
            retryCount: 0,
            requiresControl: requiresControl
        )

        if pendingCommands[uuid] == nil {
            pendingCommands[uuid] = []
        }
        pendingCommands[uuid]?.append(pendingCommand)

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.handleCommandTimeout(for: uuid, command: command, commandName: commandName)
        }
    }

    /// Remove a command from pending commands when response is received
    private func removePendingCommand(_ command: [UInt8], from uuid: UUID) {
        pendingCommands[uuid]?.removeAll { $0.command == command }
    }

    /// Find and remove the first pending command matching a response command type
    private func removeMatchingPendingCommand(responseCommandType: UInt8, from uuid: UUID) {
        guard let pendingList = pendingCommands[uuid] else { return }
        if let match = pendingList.first(where: { $0.command.count > 1 && $0.command[1] == responseCommandType }) {
            removePendingCommand(match.command, from: uuid)
        } else if let first = pendingList.first {
            removePendingCommand(first.command, from: uuid)
        }
    }

    /// Handle command timeout
    private func handleCommandTimeout(for uuid: UUID, command: [UInt8], commandName: String) {
        guard let pendingCommandList = pendingCommands[uuid],
              let pendingCommand = pendingCommandList.first(where: { $0.command == command }) else {
            return // Command already completed or removed
        }

        log("⏰ Command timeout for '\(commandName)' to \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        // Check if we should retry
        if pendingCommand.retryCount < commandRetryAttempts {
            log("🔄 Retrying command '\(commandName)' (attempt \(pendingCommand.retryCount + 1)/\(commandRetryAttempts))")

            // Remove the old pending command
            removePendingCommand(command, from: uuid)

            // Create new pending command with incremented retry count
            let retryCommand = PendingCommand(
                command: command,
                commandName: commandName,
                timestamp: Date(),
                timeout: pendingCommand.timeout,
                retryCount: pendingCommand.retryCount + 1,
                requiresControl: pendingCommand.requiresControl
            )

            pendingCommands[uuid]?.append(retryCommand)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendCommand(command, to: uuid, commandName: commandName, requiresControl: pendingCommand.requiresControl)
            }
        } else {
            log("❌ Command '\(commandName)' failed after \(commandRetryAttempts) attempts")
            removePendingCommand(command, from: uuid)
        }
    }

    /// Add a command to the queue with priority-based ordering
    private func queueCommand(_ command: [UInt8], commandName: String, to uuid: UUID, requiresControl: Bool = false, priority: CommandPriority = .normal) {
        log("📋 Queuing command: \(commandName) (priority: \(priority)) for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        // Check queue size limit
        if let currentQueue = commandQueues[uuid], currentQueue.count >= maxQueueSize {
            log("⚠️ Command queue full for \(CameraIdentityManager.shared.getDisplayName(for: uuid)), dropping command: \(commandName)")
            return
        }

        let queuedCommand = QueuedCommand(
            command: command,
            commandName: commandName,
            requiresControl: requiresControl,
            timestamp: Date(),
            priority: priority
        )

        if commandQueues[uuid] == nil {
            commandQueues[uuid] = []
        }

        // Insert command in priority order (highest priority first)
        if let currentQueue = commandQueues[uuid] {
            var insertIndex = currentQueue.count
            for (index, existingCommand) in currentQueue.enumerated() {
                if queuedCommand.priority.rawValue > existingCommand.priority.rawValue {
                    insertIndex = index
                    break
                }
            }
            commandQueues[uuid]?.insert(queuedCommand, at: insertIndex)
            log("📝 Command inserted at index \(insertIndex), queue now has \(commandQueues[uuid]?.count ?? 0) commands")
        } else {
            commandQueues[uuid] = [queuedCommand]
            log("📝 First command added to queue, queue now has 1 command")
        }

        // Start queue processing timer if not already running
        if commandQueueTimers[uuid] == nil {
            log("🚀 Starting timer for new queue")
            startCommandQueueTimer(for: uuid)
        } else {
            log("⏰ Timer already running for this camera")
        }
    }

    /// Start the command queue processing timer for a specific camera
    private func startCommandQueueTimer(for uuid: UUID) {
        log("⏰ Starting command queue timer for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        // Ensure timer is created on main thread and added to main run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let timer = Timer.scheduledTimer(withTimeInterval: self.commandQueueInterval, repeats: true) { [weak self] _ in
                self?.processCommandQueue(for: uuid)
            }
            self.commandQueueTimers[uuid] = timer
            log("✅ Timer created and scheduled for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")
        }
    }

    /// Process the command queue for a specific camera
    private func processCommandQueue(for uuid: UUID) {
        log("🔄 Processing command queue for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        guard let queue = commandQueues[uuid] else {
            log("❌ No command queue found for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")
            commandQueueTimers[uuid]?.invalidate()
            commandQueueTimers[uuid] = nil
            return
        }

        guard !queue.isEmpty else {
            log("📭 Queue is empty for \(CameraIdentityManager.shared.getDisplayName(for: uuid)), stopping timer")
            // Queue is empty, stop the timer
            commandQueueTimers[uuid]?.invalidate()
            commandQueueTimers[uuid] = nil
            return
        }

        log("📋 Queue has \(queue.count) commands for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        // Get the highest priority command
        guard let nextCommand = queue.first else { return }

        // Check if we can send a command (rate limiting)
        let now = Date()
        let recentCommands = pendingCommands[uuid]?.filter {
            now.timeIntervalSince($0.timestamp) < 1.0
        } ?? []

        // Allow high and critical priority commands to bypass rate limiting
        let shouldBypassRateLimit = nextCommand.priority == .high || nextCommand.priority == .critical

        if !shouldBypassRateLimit && recentCommands.count >= Int(maxCommandsPerSecond) {
            // Rate limit reached, wait for next interval
            let now = Date()
            let lastLogTime = lastRateLimitLogTime[uuid] ?? Date.distantPast
            if now.timeIntervalSince(lastLogTime) > 5.0 { // Log at most once every 5 seconds
                log("⏸️ Rate limit reached for \(CameraIdentityManager.shared.getDisplayName(for: uuid)) - \(recentCommands.count)/\(Int(maxCommandsPerSecond)) commands in last second")
                lastRateLimitLogTime[uuid] = now
            }
            return
        }

        // Remove from queue
        commandQueues[uuid]?.removeFirst()

        // Send the command
        log("🚀 Processing queued command: \(nextCommand.commandName) (priority: \(nextCommand.priority))")
        sendCommandDirectly(nextCommand.command, to: uuid, commandName: nextCommand.commandName, requiresControl: nextCommand.requiresControl)
    }

    /// Send a command directly (bypasses queue, used by queue processor)
    private func sendCommandDirectly(_ command: [UInt8], to uuid: UUID, commandName: String, requiresControl: Bool = false) {
        guard let gopro = connectedGoPros[uuid] else {
            log("❌ Camera not found for direct command: \(commandName)")
            return
        }

        // Validate peripheral state before sending command
        guard gopro.peripheral.state == .connected else {
            log("❌ Cannot send direct command to \(gopro.peripheral.name ?? "device") - peripheral state: \(gopro.peripheral.state.rawValue)")
            return
        }

        // If this command requires having control, check and log if we don't have it
        if requiresControl && !gopro.hasControl {
            log("❌ Command requires control but camera doesn't have control: \(commandName)")
            return
        }

        guard let characteristic = findCharacteristic(for: gopro.peripheral, uuid: Constants.UUIDs.command) else {
            log("❌ Command characteristic not found for \(gopro.peripheral.name ?? "a device")")
            return
        }

        // Add command to pending commands for timeout tracking
        addPendingCommand(command, commandName: commandName, to: uuid, timeout: defaultCommandTimeout, requiresControl: requiresControl)

        log("📡 Writing command to peripheral: \(commandName)")
        bleCommandQueue.async {
            gopro.peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
        }

        log("📤 Sent \(commandName) command to \(gopro.peripheral.name ?? "a device")")
    }

    // MARK: - Connection Retry Helpers

    /// Calculate exponential backoff delay for retry attempts
    private func calculateRetryDelay(for attempt: Int) -> TimeInterval {
        let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
        return min(delay, maxRetryDelay)
    }

    /// Check if a peripheral is in a valid state for connection retry
    private func isValidForRetry(_ peripheral: CBPeripheral) -> Bool {
        switch peripheral.state {
        case .disconnected:
            return true
        case .connecting:
            return false // Already connecting
        case .connected:
            return false // Already connected
        case .disconnecting:
            return false // Currently disconnecting
        @unknown default:
            return false
        }
    }

    // Straggler connection management
    private var stragglerRetryTimer: Timer?
    private var stragglerRetryCount: [UUID: Int] = [:]
    private let maxStragglerRetries = 5
    private let stragglerRetryInterval: TimeInterval = 15.0 // 15 seconds between straggler checks
    private var targetConnectedCameras: Set<UUID> = [] // Cameras that should be connected

    // Command response tracking for sleep/power down commands
    private var pendingSleepCommands: Set<UUID> = []
    private var pendingPowerDownCommands: Set<UUID> = []

    // BLE Parser for packet processing
    let bleParser = GoProBLEParser()
    @Published var discoveredGoPros: [UUID: GoPro] = [:]
    @Published var statusMessage: String = "Scanning for devices..."



    private var centralManager: CBCentralManager!
    private var deviceQueryTimer: Timer?
    private var deviceScanTimer: Timer?
    private var timeoutCheckTimer: Timer?
    private var settingsQueryCounter = 0 // Counter to reduce settings query frequency

    private let bleCommandQueue = DispatchQueue(label: "com.kmatzen.facett.bleCommandQueue")

    // Command queue management
    private var commandQueues: [UUID: [QueuedCommand]] = [:]
    private var commandQueueTimers: [UUID: Timer] = [:]
    private let maxCommandsPerSecond = 5.0 // Rate limit: max 5 commands per second per camera
    private let maxQueueSize = 20 // Maximum commands queued per camera
    private let commandQueueInterval: TimeInterval = 0.2 // Process queue every 200ms
    private var lastRateLimitLogTime: [UUID: Date] = [:] // Cooldown for rate limit logging


    // Error recovery tracking
    private var serviceDiscoveryRetries: [UUID: Int] = [:]
    private var characteristicDiscoveryRetries: [UUID: Int] = [:]
    private var commandWriteRetries: [UUID: Int] = [:]
    private let maxServiceDiscoveryRetries = 3
    private let maxCharacteristicDiscoveryRetries = 3
    private let maxCommandWriteRetries = 3
    private let errorRecoveryDelay: TimeInterval = 1.0 // Base delay for error recovery

    // Connection health monitoring
    private var connectionHealthScores: [UUID: ConnectionHealth] = [:]
    var lastQueryTimes: [UUID: Date] = [:]
    private var queryResponseTimes: [UUID: [TimeInterval]] = [:]
    private var querySuccessCounts: [UUID: Int] = [:]
    private var queryFailureCounts: [UUID: Int] = [:]
    private let healthCheckInterval: TimeInterval = 30.0 // Check health every 30 seconds
    private let maxResponseTimeHistory = 10 // Keep last 10 response times
    private let healthDegradationThreshold = 0.7 // Health score below this triggers action

    // Performance monitoring
    private var performanceMetrics: [UUID: PerformanceMetrics] = [:]
    private var commandResponseTimes: [UUID: [CommandResponseTime]] = [:]
    private var connectionStabilityMetrics: [UUID: ConnectionStability] = [:]
    private let performanceReportingInterval: TimeInterval = 60.0 // Report every minute
    private var lastPerformanceReport: Date = Date()

    // MARK: - Command Queue Infrastructure

    private struct QueuedCommand {
        let command: [UInt8]
        let commandName: String
        let requiresControl: Bool
        let timestamp: Date
        let priority: CommandPriority
    }

    // CommandPriority is now defined in BLECommandManager.swift

    // ConnectionHealth is now defined in BLEConnectionManager.swift

    // MARK: - Performance Monitoring Data Structures

    private struct PerformanceMetrics {
        let timestamp: Date
        let totalCommands: Int
        let successfulCommands: Int
        let failedCommands: Int
        let averageResponseTime: TimeInterval
        let maxResponseTime: TimeInterval
        let minResponseTime: TimeInterval
        let connectionUptime: TimeInterval
        let disconnectionCount: Int
        let retryCount: Int
        let queueOverflowCount: Int

        var successRate: Double {
            guard totalCommands > 0 else { return 0.0 }
            return Double(successfulCommands) / Double(totalCommands)
        }

        var isPerformingWell: Bool {
            return successRate >= 0.95 && averageResponseTime <= 1.0 && disconnectionCount == 0
        }
    }

    private struct CommandResponseTime {
        let commandName: String
        let startTime: Date
        let endTime: Date
        let responseTime: TimeInterval
        let success: Bool
        let retryCount: Int

        init(commandName: String, startTime: Date, endTime: Date, success: Bool, retryCount: Int = 0) {
            self.commandName = commandName
            self.startTime = startTime
            self.endTime = endTime
            self.responseTime = endTime.timeIntervalSince(startTime)
            self.success = success
            self.retryCount = retryCount
        }
    }

    private struct ConnectionStability {
        let connectionStartTime: Date
        let lastDisconnectionTime: Date?
        let disconnectionCount: Int
        let totalUptime: TimeInterval
        let averageUptime: TimeInterval
        let stabilityScore: Double // 0.0 to 1.0

        var isStable: Bool {
            return stabilityScore >= 0.8 && disconnectionCount <= 2
        }
    }

    struct Constants {
        struct UUIDs {
            static let goproService = CBUUID(string: "FEA6")
            static let query = CBUUID(string: "b5f90076-aa8d-11e3-9046-0002a5d5c51b")
            static let queryResponse = CBUUID(string: "b5f90077-aa8d-11e3-9046-0002a5d5c51b")
            static let command = CBUUID(string: "b5f90072-aa8d-11e3-9046-0002a5d5c51b")
            static let commandResponse = CBUUID(string: "b5f90073-aa8d-11e3-9046-0002a5d5c51b")
            static let settings = CBUUID(string: "b5f90074-aa8d-11e3-9046-0002a5d5c51b")
            static let settingsResponse = CBUUID(string: "b5f90075-aa8d-11e3-9046-0002a5d5c51b")

            // GoPro WiFi Access Point Service (GP-0001)
            static let goproWiFiService = CBUUID(string: "b5f90001-aa8d-11e3-9046-0002a5d5c51b")
            static let wifiAPSSID = CBUUID(string: "b5f90002-aa8d-11e3-9046-0002a5d5c51b") // GP-0002
            static let wifiAPPassword = CBUUID(string: "b5f90003-aa8d-11e3-9046-0002a5d5c51b") // GP-0003
            static let wifiAPPower = CBUUID(string: "b5f90004-aa8d-11e3-9046-0002a5d5c51b") // GP-0004
            static let wifiAPState = CBUUID(string: "b5f90005-aa8d-11e3-9046-0002a5d5c51b") // GP-0005
        }
    }

    // Command registry for centralized command management

    override init() {
        super.init()

        // Initialize response handler after super.init()
        responseHandler = BLEResponseHandler(bleManager: self)
        connectionHandler = BLEConnectionHandler(bleManager: self)

        // Initialize mode manager first
        modeManager = BLEModeManager(bleManager: self)

        // Initialize recording manager with mode manager
        recordingManager = BLERecordingManager(bleManager: self, modeManager: modeManager)

        // Use a background queue for BLE operations to avoid blocking UI
        let bleQueue = DispatchQueue(label: "com.kmatzen.facett.ble", qos: .utility)
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)

        // Set up component callbacks
        setupComponentCallbacks()

        startDeviceScanTimer();
        startDeviceQueryTimer()
    }

    // MARK: - Component Setup
    private func setupComponentCallbacks() {
        // Device monitor is available but auto-reconnection is disabled
    }

    // MARK: - Component Integration Helpers
    private func updateConnectionStatusFromComponent(_ uuid: UUID) {
        if let status = connectionManager.getRetryStatus(for: uuid) {
            DispatchQueue.main.async {
                self.connectionRetryStatus[uuid] = status
            }
        }
    }

    /// Clean up all state associated with a disconnected device
    func cleanupDeviceState(for uuid: UUID) {
        connectionRetryTimers[uuid]?.invalidate()
        connectionRetryTimers.removeValue(forKey: uuid)

        connectionAttemptTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)

        commandQueueTimers[uuid]?.invalidate()
        commandQueueTimers.removeValue(forKey: uuid)

        commandQueues.removeValue(forKey: uuid)
        pendingCommands.removeValue(forKey: uuid)
        connectionRetryCount.removeValue(forKey: uuid)

        bleParser.clearBuffers(for: uuid.uuidString)

        performanceMonitor.recordDisconnection(for: uuid)
    }

    deinit {
        stopDeviceQueryTimer()
        stopDeviceScanTimer()
        stopStragglerRetryTimer()
        connectionRetryTimers.values.forEach { $0.invalidate() }
        connectionRetryTimers.removeAll()
        connectionAttemptTimers.values.forEach { $0.invalidate() }
        connectionAttemptTimers.removeAll()
        commandQueueTimers.values.forEach { $0.invalidate() }
        commandQueueTimers.removeAll()
    }

    /// Logs items with a timestamp, similar to `print`.
    /// - Parameters:
    ///   - items: Zero or more items to log.
    ///   - separator: A string to insert between each item. Default is a single space.
    ///   - terminator: The string to print after all items have been logged. Default is a newline.
    // MARK: - Logging (Deprecated - Use ErrorHandler instead)
    func log(
        _ items: Any...,
        separator: String = " ",
        terminator: String = "\n"
    ) {
        // Convert all items to a single string
        let message = items.map { "\($0)" }.joined(separator: separator)

        // Use standardized error handler for logging
        ErrorHandler.info(message)
    }

    func sendCommand(
        _ command: [UInt8],
        to uuid: UUID,
        commandName: String,
        requiresControl: Bool = false,
        priority: CommandPriority = .normal
    ) {
        // Queue the command instead of sending directly
        queueCommand(command, commandName: commandName, to: uuid, requiresControl: requiresControl, priority: priority)
    }

    private func sendCommand(
        to peripheral: CBPeripheral,
        characteristicUUID: CBUUID,
        command: [UInt8],
        description: String
    ) {
        // Validate peripheral state before sending command
        guard peripheral.state == .connected else {
            log("❌ Cannot send command to \(peripheral.name ?? "device") - peripheral state: \(peripheral.state.rawValue)")
            return
        }

        guard let characteristic = findCharacteristic(for: peripheral, uuid: characteristicUUID) else {
            log("Characteristic \(characteristicUUID) not found for \(peripheral.name ?? "a device").")
            return
        }

        bleCommandQueue.async {
            peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
        }
        log("Sent \(description) command to \(peripheral.name ?? "a device"). Command: \(command)")
    }

    // MARK: - AP Commands

    func enableAP(for uuid: UUID) {
        sendCommand(GoProCommands.AccessPoint.enable,
                    to: uuid,
                    commandName: "enable AP")
    }

    func disableAP(for uuid: UUID) {
        sendCommand(GoProCommands.AccessPoint.disable,
                    to: uuid,
                    commandName: "disable AP")
    }

    // MARK: - Turbo Transfer Commands

    func enableTurboTransfer(for uuid: UUID) {
        sendCommand(GoProCommands.TurboTransfer.enable,
                    to: uuid,
                    commandName: "enable turbo transfer")
    }

    func disableTurboTransfer(for uuid: UUID) {
        sendCommand(GoProCommands.TurboTransfer.disable,
                    to: uuid,
                    commandName: "disable turbo transfer")
    }

    // MARK: - Claim Control

    func claimControl(for uuid: UUID) {
        sendCommand([4, 241, 105, 8, 2],
                    to: uuid,
                    commandName: "claim control",
                    priority: .high)
    }

    func releaseControl(for uuid: UUID) {
        sendCommand([4, 241, 105, 8, 0],
                    to: uuid,
                    commandName: "release control",
                    priority: .high)
    }

    // MARK: - Recording Commands

    func startRecording(for uuid: UUID) {
        recordingManager.startRecording(for: uuid)
    }

    func stopRecording(for uuid: UUID) {
        recordingManager.stopRecording(for: uuid)
    }

    // MARK: - Mode Management

    /// Switch camera to a specific mode
    func switchToMode(_ mode: CameraMode, for uuid: UUID, completion: @escaping (Bool) -> Void) {
        modeManager.switchToMode(mode, for: uuid, completion: completion)
    }

    /// Switch camera to video mode
    func switchToVideoMode(for uuid: UUID, completion: @escaping (Bool) -> Void) {
        modeManager.switchToVideoMode(for: uuid, completion: completion)
    }

    /// Switch camera to photo mode
    func switchToPhotoMode(for uuid: UUID, completion: @escaping (Bool) -> Void) {
        modeManager.switchToPhotoMode(for: uuid, completion: completion)
    }

    /// Switch all cameras to a specific mode
    func switchAllCamerasToMode(_ mode: CameraMode, completion: @escaping ([UUID: Bool]) -> Void) {
        modeManager.switchAllCamerasToMode(mode, completion: completion)
    }

    /// Get cameras that are not in the specified mode
    func getCamerasNotInMode(_ mode: CameraMode) -> [GoPro] {
        return modeManager.getCamerasNotInMode(mode)
    }

    /// Get mode mismatch information for UI display
    func getModeMismatchInfo() -> (mismatchedCameras: [GoPro], targetMode: CameraMode) {
        return modeManager.getModeMismatchInfo()
    }

    /// Get current mode description for a camera
    func getCurrentModeDescription(for uuid: UUID) -> String {
        return modeManager.getCurrentModeDescription(for: uuid)
    }



    func setDateTime(for uuid: UUID) {


        guard let gopro = connectedGoPros[uuid] else { return }
        guard let characteristic = findCharacteristic(for: gopro.peripheral, uuid: Constants.UUIDs.command) else {
            log("Command characteristic not found for \(gopro.peripheral.name ?? "a device").")
            return
        }

        // Get the current date and time
        let now = Date()
        let calendar = Calendar.current
        let year = UInt16(calendar.component(.year, from: now))
        let month = UInt8(calendar.component(.month, from: now))
        let day = UInt8(calendar.component(.day, from: now))
        let hour = UInt8(calendar.component(.hour, from: now))
        let minute = UInt8(calendar.component(.minute, from: now))
        let second = UInt8(calendar.component(.second, from: now))

        // Serialize the date and time into the required 7-byte format
        let dateTimeCommand: [UInt8] = [
            9,
            0x0D, // Command ID for "Set Date Time"
            7,
            UInt8((year >> 8) & 0xFF), // Year (high byte)
            UInt8(year & 0xFF),        // Year (low byte)
            month,                     // Month
            day,                       // Day
            hour,                      // Hour
            minute,                    // Minute
            second                     // Second
        ]

        // Send the command
        bleCommandQueue.async {
            gopro.peripheral.writeValue(Data(dateTimeCommand), for: characteristic, type: .withResponse)
        }

        // Record the time sync on the main thread
        DispatchQueue.main.async {
            gopro.status.lastTimeSyncDate = now
        }

        log("Sent Set Date Time command to \(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name)). Date: \(year)-\(month)-\(day) \(hour):\(minute):\(second)")
    }

    // MARK: - CBCentralManagerDelegate Conformance
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            log("Bluetooth is not available.")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let gopro = GoPro(peripheral: peripheral)
        guard connectedGoPros[peripheral.identifier] == nil else { return }

        // Don't add sleeping devices to discovered list
        guard !deviceStateManager.isDeviceSleeping(peripheral.identifier) else { return }

        // UI updates must happen on main thread
        DispatchQueue.main.async {
            self.addDevice(to: \.discoveredGoPros, gopro: gopro)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionHandler.handleConnectionSuccess(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectionHandler.handleDisconnection(peripheral, error: error)
    }


    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let cameraName = CameraIdentityManager.shared.getDisplayName(for: peripheral.identifier, currentName: peripheral.name)
        let errorDescription = error?.localizedDescription ?? "unknown error"
        log("❌ Failed to connect to \(cameraName): \(errorDescription)")

        // Log error for crash reporting with enhanced context
        CrashReporter.shared.logError(
            "BLE Connection Failed",
            error: error,
            context: [
                "peripheral_name": peripheral.name ?? "Unknown",
                "peripheral_id": peripheral.identifier.uuidString,
                "peripheral_state": peripheralStateString(peripheral.state),
                "error_description": errorDescription,
                "error_code": error?._code.description ?? "unknown",
                "error_domain": error?._domain ?? "unknown"
            ],
            appStateContext: createAppStateContext()
        )

        let uuid = peripheral.identifier
        let currentRetryCount = connectionRetryCount[uuid] ?? 0

        DispatchQueue.main.async {
            if let gopro = self.connectingGoPros[uuid] {
                // Check if we should retry
                if currentRetryCount < self.maxRetryAttempts {
                    // Retry connection
                    self.connectionRetryCount[uuid] = currentRetryCount + 1
                    let retryDelay = self.calculateRetryDelay(for: currentRetryCount + 1)
                    self.log("🔄 Retrying connection to \(cameraName) (attempt \(currentRetryCount + 1)/\(self.maxRetryAttempts)) in \(String(format: "%.1f", retryDelay))s...")

                    // Update retry status for UI on main thread
                    DispatchQueue.main.async {
                        self.connectionRetryStatus[uuid] = .retrying(attempt: currentRetryCount + 1, maxAttempts: self.maxRetryAttempts)
                    }

                    // Schedule retry after exponential backoff delay
                    self.connectionRetryTimers[uuid] = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
                        self?.retryConnection(for: uuid)
                    }
                } else {
                    // Max retries reached, give up
                    self.log("❌ Max connection retries reached for \(cameraName), giving up after \(self.maxRetryAttempts) attempts")
                    self.discoveredGoPros[uuid] = gopro // Move back to discovered list
                    self.connectingGoPros.removeValue(forKey: uuid) // Remove from connecting list
                    self.connectionRetryCount.removeValue(forKey: uuid)
                    self.connectionRetryTimers.removeValue(forKey: uuid)
                    self.connectionAttemptTimers.removeValue(forKey: uuid)
                    self.camerasBeingConnectedFromGroup.remove(uuid)

                    // Set final failure status for UI on main thread
                    DispatchQueue.main.async {
                        self.connectionRetryStatus[uuid] = .abandoned(maxAttempts: self.maxRetryAttempts)
                    }

                    // Log final failure for crash reporting
                    CrashReporter.shared.logError(
                        "BLE Connection Abandoned",
                        error: error,
                        context: [
                            "peripheral_name": peripheral.name ?? "Unknown",
                            "peripheral_id": peripheral.identifier.uuidString,
                            "final_error": errorDescription,
                            "total_retry_attempts": "\(self.maxRetryAttempts)",
                            "abandonment_reason": "max_retries_exceeded"
                        ]
                    )
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        connectionHandler.handleServiceDiscovery(peripheral, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        connectionHandler.handleCharacteristicDiscovery(peripheral, service: service, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Handle errors in reading the value
        if let error = error {
            log("Error reading value for \(characteristic.uuid): \(error.localizedDescription)")

            // Handle specific authentication errors
            if let nsError = error as NSError?, nsError.domain == "CBATTErrorDomain" {
                switch nsError.code {
                case 5: // Authentication is insufficient
                    log("🔐 Authentication insufficient for \(peripheral.name ?? "device"). Attempting to re-establish connection...")
                    handleAuthenticationError(for: peripheral)
                case 3: // Write not permitted
                    log("🚫 Write not permitted for \(characteristic.uuid). May need to claim control first.")
                case 2: // Read not permitted
                    log("🚫 Read not permitted for \(characteristic.uuid). May need proper authorization.")
                default:
                    log("⚠️ BLE ATT Error \(nsError.code): \(error.localizedDescription)")
                }
            }
            return
        }

        // Ensure characteristic value exists
        guard let data = characteristic.value else {
            ErrorHandler.error("Characteristic value unexpectedly nil", context: ["uuid": characteristic.uuid.uuidString])
            return
        }

        // Add detailed logging for all incoming data
        // Handle specific characteristics based on UUID
        switch characteristic.uuid {
        case Constants.UUIDs.queryResponse:
            log("🔍 QUERY RESPONSE: Processing query response for \(peripheral.name ?? "a device")")
            responseHandler.handleQueryResponse(data, for: peripheral)

        case Constants.UUIDs.commandResponse:
            log("🔍 COMMAND RESPONSE: Processing command response for \(peripheral.name ?? "a device")")
            handleCommandResponse(data, for: peripheral)

        case Constants.UUIDs.settingsResponse:
            log("🔍 SETTINGS RESPONSE: Processing settings response for \(peripheral.name ?? "a device")")
            handleSettingsResponse(data, for: peripheral)

        // GoPro WiFi Access Point characteristics
        case Constants.UUIDs.wifiAPSSID:
            ErrorHandler.debug("Processing WiFi AP SSID response for \(peripheral.name ?? "a device")")
            wifiManager.handleWiFiSSIDResponse(data, for: peripheral) { [weak self] uuid, ssid in
                if let gopro = self?.connectedGoPros[uuid] {
                    self?.wifiManager.updateWiFiSSID(for: uuid, ssid: ssid, gopro: gopro)
                }
            }

        case Constants.UUIDs.wifiAPPassword:
            ErrorHandler.debug("Processing WiFi AP Password response for \(peripheral.name ?? "a device")")
            wifiManager.handleWiFiPasswordResponse(data, for: peripheral) { [weak self] uuid, password in
                if let gopro = self?.connectedGoPros[uuid] {
                    self?.wifiManager.updateWiFiPassword(for: uuid, password: password, gopro: gopro)
                }
            }

        case Constants.UUIDs.wifiAPState:
            ErrorHandler.debug("Processing WiFi AP State response for \(peripheral.name ?? "a device")")
            wifiManager.handleWiFiStateResponse(data, for: peripheral) { [weak self] uuid, state in
                if let gopro = self?.connectedGoPros[uuid] {
                    self?.wifiManager.updateWiFiState(for: uuid, state: state, gopro: gopro)
                }
            }

        default:
            log("⚠️ WARNING: Received value for unknown characteristic \(characteristic.uuid).")
        }
    }

    // MARK: - Write Value Delegate Methods

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = peripheral.identifier
        let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)

        if let error = error {
            log("❌ Write failed for \(cameraName): \(error.localizedDescription)")

            // Handle specific authentication errors
            if let nsError = error as NSError?, nsError.domain == "CBATTErrorDomain" {
                switch nsError.code {
                case 5: // Authentication is insufficient
                    log("🔐 Write authentication insufficient for \(cameraName). Attempting to re-establish connection...")
                    handleAuthenticationError(for: peripheral)
                    return
                case 3: // Write not permitted
                    log("🚫 Write not permitted for \(characteristic.uuid). May need to claim control first.")
                case 2: // Read not permitted
                    log("🚫 Read not permitted for \(characteristic.uuid). May need proper authorization.")
                default:
                    log("⚠️ BLE ATT Write Error \(nsError.code): \(error.localizedDescription)")
                }
            }

            // Log error for crash reporting
            CrashReporter.shared.logError(
                "BLE Write Failed",
                error: error,
                context: [
                    "peripheral_name": peripheral.name ?? "Unknown",
                    "peripheral_id": uuid.uuidString,
                    "characteristic_uuid": characteristic.uuid.uuidString,
                    "error_description": error.localizedDescription
                ]
            )

            // Handle write failure - retry if we have pending commands
            if let pendingCommandList = pendingCommands[uuid], let firstCommand = pendingCommandList.first {
                log("🔄 Retrying write for '\(firstCommand.commandName)' to \(cameraName)")

                // Remove the failed command from pending list
                removePendingCommand(firstCommand.command, from: uuid)

                // Use error recovery system for retry
                recoverCommandWrite(for: uuid, command: firstCommand.command, commandName: firstCommand.commandName, characteristic: characteristic)
            }
        } else {
            // Write succeeded - this is normal, no logging needed
            // The actual command response will be handled by didUpdateValueFor
        }
    }

    private func handleCommandResponse(_ data: Data, for peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        let cameraName = peripheral.name ?? "Unknown"

        // First, check for special 5-byte responses (claim control, turbo enable/disable, etc.).
        if handleFiveByteResponse(data, for: peripheral) {
            if data.count > 1 {
                removeMatchingPendingCommand(responseCommandType: data[1], from: uuid)
            }
            return
        }

        // If it's not one of the special cases, handle the more generic 3+ byte responses.
        // Validate minimum response length.
        guard data.count >= 3 else {
            let error = "Invalid command response data - too short (\(data.count) bytes)"
            let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)
            ErrorHandler.error(
                "Generic Command failed for \(cameraName): \(error)",
                context: ["camera_id": uuid.uuidString, "data_length": String(data.count)]
            )
            log(error)
            return
        }

        let responseLength = data[0] // First byte: length of the response
        let commandType = data[1]    // Second byte: command type
        let success = data[2] == 0   // Third byte: success indicator (0 = success)

        // Ensure the response length matches the actual size of the data (minus the length byte).
        guard data.count - 1 == responseLength else {
            let error = "Mismatched response length - expected \(responseLength + 1), got \(data.count)"
            let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)
            ErrorHandler.error(
                "Generic Command failed for \(cameraName): \(error)",
                context: ["camera_id": uuid.uuidString, "data_length": String(data.count)]
            )
            log("Mismatched response length for \(cameraName).")
            return
        }

        // Handle sleep and power down command responses
        if commandType == 1 { // Sleep/Power down command type
            if data.count >= 4 && data[3] == 5 { // Sleep command
                if pendingSleepCommands.contains(uuid) {
                    log("Sleep command response received for \(peripheral.name ?? "device"), disconnecting")
                    pendingSleepCommands.remove(uuid)
                    centralManager.cancelPeripheralConnection(peripheral)
                    return
                }
            } else if data.count >= 4 && data[3] == 4 { // Power down command
                if pendingPowerDownCommands.contains(uuid) {
                    log("Power down command response received for \(peripheral.name ?? "device"), disconnecting")
                    pendingPowerDownCommands.remove(uuid)
                    centralManager.cancelPeripheralConnection(peripheral)
                    return
                }
            } else if data.count >= 4 {
                // Handle other command type 1 responses
                let subCommand = data[3]
                log("Command type 1 sub-command response: \(subCommand)")
                return
            }
        }

        // Handle AP command responses (command type 23)
        if commandType == 23 { // AP enable/disable command type
            log("AP command response received for \(peripheral.name ?? "device")")
            return
        }

        // Handle the generic case with enhanced logging
        let camera = connectedGoPros[uuid] ?? GoPro(peripheral: peripheral)
        let commandName = "Command Type \(commandType)"

        if success {
            ErrorHandler.info(
                "Command '\(commandName)' succeeded for \(camera.name ?? "Unknown")"
            )
            log("Command response success for \(cameraName). Command type: \(commandType).")
        } else {
            let errorMsg = "Command failed - type \(commandType)"
            ErrorHandler.error(
                "Command '\(commandName)' failed for \(camera.name ?? "Unknown"): \(errorMsg)"
            )
            log("⚠️ WARNING: Unhandled command response error for \(cameraName). Command type: \(commandType).")
            log("Command response error for \(cameraName). Command type: \(commandType).")
        }

        removeMatchingPendingCommand(responseCommandType: commandType, from: uuid)
    }

    // MARK: - Handle Special 5-Byte Responses
    /// Returns `true` if the data matched and handled one of the special 5-byte responses.
    private func handleFiveByteResponse(_ data: Data, for peripheral: CBPeripheral) -> Bool {
        // We only handle 5-byte responses of the form [4, 241, x, 8, y]
        guard data.count == 5,
              data[0] == 4,
              data[1] == 241,
              data[3] == 8 else {
            return false
        }

        let code = data[2]
        let value = data[4]

        switch (code, value) {
        case (233, 1):
            // Claimed control
            if let gopro = connectedGoPros[peripheral.identifier] {
                gopro.hasControl = true
                log("Claimed control")
            }
            return true

        case (233, 0):
            if let gopro = connectedGoPros[peripheral.identifier] {
                gopro.hasControl = false
                log("Lost control")
            }
            return true

        case (235, 1):
            // Turbo transfer enabled
            log("Turbo transfer enabled")
            return true

        case (235, 0):
            // Turbo transfer disabled
            log("Turbo transfer disabled")
            return true

        case (108, _):
            // GPCAMERA_GET_WIFI_CONFIG response
            return true

        case (236, _):
            // Unknown command response (0xEC)
            return true

        default:
            // Log unknown 5-byte response instead of crashing
            return false
        }
    }

    private func handleSettingsResponse(_ data: Data, for peripheral: CBPeripheral) {
        // Process settings response data as needed
        log("Processed Settings Response for \(peripheral.name ?? "a device"). Data: \(data)")
        verifySettings(data, for: peripheral)

        // Parse the response to update camera settings with actual values from the camera
        responseHandler.handleQueryResponse(data, for: peripheral)

        // Force a settings query to get the updated state
        // This ensures the camera's settings are properly reflected in the UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.queryAllSettings(from: peripheral)
        }
    }

    // MARK: - WiFi Characteristic Handlers (Moved to BLEWiFiManager)

    func verifySettings(_ response: Data, for peripheral: CBPeripheral) {


        // Convert the response to a byte array for loging
        let byteArray = response.map { String(format: "0x%02X", $0) }.joined(separator: " ")

        if response[2] == 0 {
            log("\(peripheral.name ?? "Device") settings applied successfully. Response bytes: \(byteArray)")
        } else {
            log("\(peripheral.name ?? "Device") settings verification failed. Response bytes: \(byteArray)")
        }
    }

    /// Convert CBPeripheralState to readable string
    private func peripheralStateString(_ state: CBPeripheralState) -> String {
        switch state {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Error Recovery Methods

    /// Attempt to recover from service discovery failure
    private func recoverServiceDiscovery(for uuid: UUID) {
        let currentRetries = serviceDiscoveryRetries[uuid] ?? 0

        if currentRetries >= maxServiceDiscoveryRetries {
            log("❌ Max service discovery retries reached for \(CameraIdentityManager.shared.getDisplayName(for: uuid)), giving up")
            serviceDiscoveryRetries.removeValue(forKey: uuid)
            return
        }

        serviceDiscoveryRetries[uuid] = currentRetries + 1
        let delay = errorRecoveryDelay * Double(currentRetries + 1)

        log("🔄 Retrying service discovery for \(CameraIdentityManager.shared.getDisplayName(for: uuid)) (attempt \(currentRetries + 1)/\(maxServiceDiscoveryRetries)) in \(String(format: "%.1f", delay)) seconds")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let gopro = self.connectedGoPros[uuid] else { return }
            gopro.peripheral.discoverServices([Constants.UUIDs.goproService, Constants.UUIDs.goproWiFiService])
        }
    }

    /// Attempt to recover from characteristic discovery failure
    private func recoverCharacteristicDiscovery(for uuid: UUID, service: CBService) {
        let currentRetries = characteristicDiscoveryRetries[uuid] ?? 0

        if currentRetries >= maxCharacteristicDiscoveryRetries {
            log("❌ Max characteristic discovery retries reached for \(CameraIdentityManager.shared.getDisplayName(for: uuid)), giving up")
            characteristicDiscoveryRetries.removeValue(forKey: uuid)
            return
        }

        characteristicDiscoveryRetries[uuid] = currentRetries + 1
        let delay = errorRecoveryDelay * Double(currentRetries + 1)

        log("🔄 Retrying characteristic discovery for \(CameraIdentityManager.shared.getDisplayName(for: uuid)) (attempt \(currentRetries + 1)/\(maxCharacteristicDiscoveryRetries)) in \(String(format: "%.1f", delay)) seconds")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let gopro = self.connectedGoPros[uuid] else { return }
            gopro.peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    /// Attempt to recover from command write failure
    private func recoverCommandWrite(for uuid: UUID, command: [UInt8], commandName: String, characteristic: CBCharacteristic) {
        let currentRetries = commandWriteRetries[uuid] ?? 0

        if currentRetries >= maxCommandWriteRetries {
            log("❌ Max command write retries reached for \(CameraIdentityManager.shared.getDisplayName(for: uuid)), giving up on \(commandName)")
            commandWriteRetries.removeValue(forKey: uuid)
            return
        }

        commandWriteRetries[uuid] = currentRetries + 1
        let delay = errorRecoveryDelay * Double(currentRetries + 1)

        log("🔄 Retrying command write for \(CameraIdentityManager.shared.getDisplayName(for: uuid)) (attempt \(currentRetries + 1)/\(maxCommandWriteRetries)) in \(String(format: "%.1f", delay)) seconds")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let gopro = self.connectedGoPros[uuid] else { return }

            // Validate peripheral state before retry
            guard gopro.peripheral.state == .connected else {
                self.log("❌ Cannot retry command write to \(gopro.peripheral.name ?? "device") - peripheral state: \(gopro.peripheral.state.rawValue)")
                return
            }

            let data = Data(command)
            gopro.peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    /// Reset error recovery state for a camera
    private func resetErrorRecoveryState(for uuid: UUID) {
        serviceDiscoveryRetries.removeValue(forKey: uuid)
        characteristicDiscoveryRetries.removeValue(forKey: uuid)
        commandWriteRetries.removeValue(forKey: uuid)
        log("✅ Error recovery state reset for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")
    }

    /// Handle authentication errors by attempting to re-establish connection
    private func handleAuthenticationError(for peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        log("🔐 Handling authentication error for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        // Disconnect and reconnect to re-establish authentication
        centralManager.cancelPeripheralConnection(peripheral)

        // Clear any pending commands for this device
        pendingCommands[uuid]?.removeAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.log("🔄 Attempting to reconnect after authentication error...")
            self?.centralManager.connect(peripheral, options: nil)
        }
    }

    /// Attempt to recover from control loss
    private func recoverControlLoss(for uuid: UUID) {
        log("🔄 Attempting to recover control for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        // Try to reclaim control
        claimControl(for: uuid)
    }

    // MARK: - Connection Health Monitoring

    /// Start connection health monitoring for a camera
    private func startConnectionHealthMonitoring(for uuid: UUID) {
        log("🏥 Starting connection health monitoring for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        // Initialize health tracking
        connectionHealthScores[uuid] = ConnectionHealth(
            stabilityScore: 1.0,
            averageResponseTime: 0.0,
            connectionCount: 0,
            lastConnected: Date()
        )
        querySuccessCounts[uuid] = 0
        queryFailureCounts[uuid] = 0
        queryResponseTimes[uuid] = []
    }

    /// Stop connection health monitoring for a camera
    private func stopConnectionHealthMonitoring(for uuid: UUID) {
        connectionHealthScores.removeValue(forKey: uuid)
        lastQueryTimes.removeValue(forKey: uuid)
        queryResponseTimes.removeValue(forKey: uuid)
        querySuccessCounts.removeValue(forKey: uuid)
        queryFailureCounts.removeValue(forKey: uuid)
        log("🏥 Stopped connection health monitoring for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")
    }

    /// Record a successful query response
    func recordQuerySuccess(for uuid: UUID, responseTime: TimeInterval) {
        querySuccessCounts[uuid] = (querySuccessCounts[uuid] ?? 0) + 1

        // Track response times
        if queryResponseTimes[uuid] == nil {
            queryResponseTimes[uuid] = []
        }
        queryResponseTimes[uuid]?.append(responseTime)

        // Keep only recent response times
        if let times = queryResponseTimes[uuid], times.count > maxResponseTimeHistory {
            queryResponseTimes[uuid] = Array(times.suffix(maxResponseTimeHistory))
        }

        updateConnectionHealth(for: uuid)
    }

    /// Record a failed query
    private func recordQueryFailure(for uuid: UUID) {
        queryFailureCounts[uuid] = (queryFailureCounts[uuid] ?? 0) + 1
        updateConnectionHealth(for: uuid)
    }

    /// Update connection health score for a camera
    private func updateConnectionHealth(for uuid: UUID) {
        let successCount = querySuccessCounts[uuid] ?? 0
        let failureCount = queryFailureCounts[uuid] ?? 0
        let totalQueries = successCount + failureCount

        guard totalQueries > 0 else { return }

        let successRate = Double(successCount) / Double(totalQueries)
        let responseTimes = queryResponseTimes[uuid] ?? []
        let averageResponseTime = responseTimes.isEmpty ? 0.0 : responseTimes.reduce(0, +) / Double(responseTimes.count)

        // Calculate health score based on success rate and response time
        var healthScore = successRate

        // Penalize slow response times (over 2 seconds is considered slow)
        if averageResponseTime > 2.0 {
            let responseTimePenalty = min(0.3, (averageResponseTime - 2.0) * 0.1)
            healthScore -= responseTimePenalty
        }

        // Ensure score is between 0 and 1
        healthScore = max(0.0, min(1.0, healthScore))

        // Detect issues
        var issues: [String] = []
        if successRate < 0.8 {
            issues.append("Low success rate (\(Int(successRate * 100))%)")
        }
        if averageResponseTime > 2.0 {
            issues.append("Slow response time (\(String(format: "%.1f", averageResponseTime))s)")
        }
        if totalQueries < 5 {
            issues.append("Insufficient data")
        }

        let health = ConnectionHealth(
            stabilityScore: healthScore,
            averageResponseTime: averageResponseTime,
            connectionCount: 0,
            lastConnected: Date()
        )

        connectionHealthScores[uuid] = health

        // Log health status if it's degraded
        if healthScore < 0.7 || successRate < 0.8 {
            log("⚠️ Connection health degraded for \(CameraIdentityManager.shared.getDisplayName(for: uuid)): score=\(String(format: "%.2f", healthScore)), success=\(Int(successRate * 100))%, avgTime=\(String(format: "%.1f", averageResponseTime))s, issues=\(issues.joined(separator: ", "))")
        }

        // Take action if health is critically low
        if healthScore < healthDegradationThreshold {
            handleConnectionHealthDegradation(for: uuid, health: health)
        }
    }

    /// Handle connection health degradation
    private func handleConnectionHealthDegradation(for uuid: UUID, health: ConnectionHealth) {
        log("🚨 Critical connection health degradation for \(CameraIdentityManager.shared.getDisplayName(for: uuid)): stability=\(String(format: "%.2f", health.stabilityScore))")

        // Log for crash reporting
        CrashReporter.shared.logError(
            "Connection Health Degradation",
            error: NSError(domain: "ConnectionHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection health degraded"]),
            context: [
                "peripheral_id": uuid.uuidString,
                "stability_score": String(health.stabilityScore),
                "average_response_time": String(health.averageResponseTime),
                "connection_count": String(health.connectionCount)
            ]
        )

        // Attempt recovery actions based on the issues
        if health.stabilityScore < 0.7 {
            log("🔄 Attempting to recover from low stability for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")
            // Could trigger a reconnection or service rediscovery
        }

        if health.averageResponseTime > 5.0 {
            log("🔄 Attempting to recover from slow response time for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")
            // Could reduce query frequency or trigger optimization
        }
    }

    /// Get connection health for a camera
    private func getConnectionHealth(for uuid: UUID) -> ConnectionHealth? {
        return connectionHealthScores[uuid]
    }

    /// Reset connection health for a camera
    private func resetConnectionHealth(for uuid: UUID) {
        stopConnectionHealthMonitoring(for: uuid)
        startConnectionHealthMonitoring(for: uuid)
        log("🔄 Connection health reset for \(CameraIdentityManager.shared.getDisplayName(for: uuid))")
    }

    // MARK: - Performance Monitoring (Delegated to BLEPerformanceMonitor)

    /// Start performance monitoring for a camera
    private func startPerformanceMonitoring(for uuid: UUID) {
        performanceMonitor.startPerformanceMonitoring(for: uuid)
    }

    /// Stop performance monitoring for a camera
    private func stopPerformanceMonitoring(for uuid: UUID) {
        performanceMonitor.stopPerformanceMonitoring(for: uuid)
    }

    /// Record command start time for performance tracking
    private func recordCommandStart(for uuid: UUID, commandName: String) -> Date {
        return performanceMonitor.recordCommandStart(for: uuid, commandName: commandName)
    }

    /// Record command completion for performance tracking
    private func recordCommandCompletion(for uuid: UUID, commandName: String, startTime: Date, success: Bool, retryCount: Int = 0) {
        performanceMonitor.recordCommandCompletion(for: uuid, commandName: commandName, startTime: startTime, success: success, retryCount: retryCount)
    }

    // Performance metrics are now handled by BLEPerformanceMonitor

    /// Report performance metrics for all cameras
    private func reportPerformanceMetrics() {
        for (uuid, metrics) in performanceMetrics {
            let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid)

            // Log performance summary
            log("📊 Performance Report for \(cameraName): commands=\(metrics.totalCommands), success=\(Int(metrics.successRate * 100))%, avgTime=\(String(format: "%.2f", metrics.averageResponseTime))s, uptime=\(String(format: "%.1f", metrics.connectionUptime))s, retries=\(metrics.retryCount)")

            // Report to crash reporter if performance is poor
            if !metrics.isPerformingWell {
                CrashReporter.shared.logWarning(
                    "Poor BLE Performance Detected",
                    context: [
                        "peripheral_id": uuid.uuidString,
                        "camera_name": cameraName,
                        "total_commands": String(metrics.totalCommands),
                        "success_rate": String(metrics.successRate),
                        "average_response_time": String(metrics.averageResponseTime),
                        "max_response_time": String(metrics.maxResponseTime),
                        "retry_count": String(metrics.retryCount),
                        "connection_uptime": String(metrics.connectionUptime)
                    ],
                    appStateContext: createAppStateContext()
                )
            }
        }
    }

    /// Record disconnection for stability tracking
    private func recordDisconnection(for uuid: UUID) {
        guard let stability = connectionStabilityMetrics[uuid] else { return }

        let newDisconnectionCount = stability.disconnectionCount + 1
        let newTotalUptime = stability.totalUptime + Date().timeIntervalSince(stability.connectionStartTime)
        let newAverageUptime = newTotalUptime / Double(newDisconnectionCount)

        // Calculate stability score (fewer disconnections = higher score)
        let stabilityScore = max(0.0, 1.0 - (Double(newDisconnectionCount) * 0.2))

        let updatedStability = ConnectionStability(
            connectionStartTime: stability.connectionStartTime,
            lastDisconnectionTime: Date(),
            disconnectionCount: newDisconnectionCount,
            totalUptime: newTotalUptime,
            averageUptime: newAverageUptime,
            stabilityScore: stabilityScore
        )

        connectionStabilityMetrics[uuid] = updatedStability

        // Update performance metrics disconnection count
        if let metrics = performanceMetrics[uuid] {
            let updatedMetrics = PerformanceMetrics(
                timestamp: metrics.timestamp,
                totalCommands: metrics.totalCommands,
                successfulCommands: metrics.successfulCommands,
                failedCommands: metrics.failedCommands,
                averageResponseTime: metrics.averageResponseTime,
                maxResponseTime: metrics.maxResponseTime,
                minResponseTime: metrics.minResponseTime,
                connectionUptime: metrics.connectionUptime,
                disconnectionCount: newDisconnectionCount,
                retryCount: metrics.retryCount,
                queueOverflowCount: metrics.queueOverflowCount
            )
            performanceMetrics[uuid] = updatedMetrics
        }

        if !updatedStability.isStable {
            log("⚠️ Connection stability issue for \(CameraIdentityManager.shared.getDisplayName(for: uuid)): disconnections=\(newDisconnectionCount), stability=\(String(format: "%.2f", stabilityScore))")
        }
    }

    /// Get performance metrics for a camera
    private func getPerformanceMetrics(for uuid: UUID) -> PerformanceMetrics? {
        return performanceMetrics[uuid]
    }

    /// Get connection stability for a camera
    private func getConnectionStability(for uuid: UUID) -> ConnectionStability? {
        return connectionStabilityMetrics[uuid]
    }


    // MARK: - Device Management
    private func addDevice(to collection: ReferenceWritableKeyPath<BLEManager, [UUID: GoPro]>, gopro: GoPro) {


        self[keyPath: collection][gopro.peripheral.identifier] = gopro

        // Note: Camera name will be stored when we receive the apSSID (serial number)
        // in BLEResponseHandler after the camera connects and sends status
    }

    private func removeDevice(from collection: ReferenceWritableKeyPath<BLEManager, [UUID: GoPro]>, uuid: UUID) {


        self[keyPath: collection].removeValue(forKey: uuid)
    }

    private func updateDevice(
        in collection: ReferenceWritableKeyPath<BLEManager, [UUID: GoPro]>,
        uuid: UUID,
        gopro: GoPro?
    ) {


        if let gopro = gopro {
            self[keyPath: collection][uuid] = gopro
        } else {
            self[keyPath: collection].removeValue(forKey: uuid)
        }
    }

    // MARK: - Bluetooth Scanning and Connection
    func startScanning(reset: Bool = true) {
        if reset {
            DispatchQueue.main.async {
                self.resetDeviceState()
            }
        }

        if centralManager.state == .poweredOn {
            log("Scanning for GoPro devices...")
            centralManager.scanForPeripherals(withServices: [Constants.UUIDs.goproService, Constants.UUIDs.goproWiFiService], options: nil)
        } else {
            log("Bluetooth is not ready.")
        }
    }

    /// Refresh discovered cameras without disconnecting connected ones
    func refreshDiscoveredCameras() {
        DispatchQueue.main.async {
            // Clear only discovered cameras (not connected ones)
            self.discoveredGoPros.removeAll()
        }

        // Restart scanning to find cameras that are currently in range
        if centralManager.state == .poweredOn {
            centralManager.stopScan()
            centralManager.scanForPeripherals(withServices: [Constants.UUIDs.goproService, Constants.UUIDs.goproWiFiService], options: nil)
            log("🔄 Refreshed discovered cameras list")
        }
    }

    func connectAll() {
        DispatchQueue.main.async {
            for (uuid, _) in self.discoveredGoPros {
                self.connectToGoPro(uuid: uuid)
            }
        }
    }

    private func resetDeviceState() {
        for (_, gopro) in connectedGoPros {
            centralManager.cancelPeripheralConnection(gopro.peripheral)
        }
        self.connectedGoPros.removeAll()
        self.discoveredGoPros.removeAll()

        // Clean up retry timers
        for timer in connectionRetryTimers.values {
            timer.invalidate()
        }
        for timer in connectionAttemptTimers.values {
            timer.invalidate()
        }
        connectionRetryTimers.removeAll()
        connectionAttemptTimers.removeAll()
        connectionRetryCount.removeAll()
        connectionRetryStatus.removeAll()

        // Clean up pending commands
        pendingCommands.removeAll()

        // Clean up command queues
        for timer in commandQueueTimers.values {
            timer.invalidate()
        }
        commandQueues.removeAll()
        commandQueueTimers.removeAll()
        lastRateLimitLogTime.removeAll()

        // Clean up peripheral state monitoring (removed - auto-reconnection disabled)

        // Clean up error recovery state
        serviceDiscoveryRetries.removeAll()
        characteristicDiscoveryRetries.removeAll()
        commandWriteRetries.removeAll()

        // Clean up connection health monitoring
        connectionHealthScores.removeAll()
        lastQueryTimes.removeAll()
        queryResponseTimes.removeAll()
        querySuccessCounts.removeAll()
        queryFailureCounts.removeAll()

        // Clean up performance monitoring
        performanceMetrics.removeAll()
        commandResponseTimes.removeAll()
        connectionStabilityMetrics.removeAll()

        // Clean up straggler management
        stopStragglerRetryTimer()
        targetConnectedCameras.removeAll()
        stragglerRetryCount.removeAll()

        // Clean up pending command tracking
        pendingSleepCommands.removeAll()
        pendingPowerDownCommands.removeAll()
    }

    func connectToGoPro(uuid: UUID) {
        guard let gopro = discoveredGoPros[uuid], connectedGoPros[uuid] == nil, connectingGoPros[uuid] == nil else { return }

        // Clear sleep state when manually connecting (user wants to wake the camera)
        if deviceStateManager.isDeviceSleeping(uuid) {
            log("🌅 Clearing sleep state for \(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name)) - manual connection requested")
            deviceStateManager.setDeviceSleeping(uuid, isSleeping: false)
        }

        // Check if peripheral is in a valid state for connection
        guard isValidForRetry(gopro.peripheral) else {
            log("❌ Cannot connect to \(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name)) - peripheral not in valid state")
            return
        }

        let cameraName = CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name)
        log("🔗 Connecting to \(cameraName)...")
        gopro.peripheral.delegate = self

        // Use connection manager for retry logic
        connectionManager.startConnectionRetry(for: uuid)

        // Set initial connection status on main thread
        DispatchQueue.main.async {
            self.connectionRetryStatus[uuid] = .connecting
            self.connectingGoPros[uuid] = gopro
        }

        centralManager.connect(gopro.peripheral, options: nil)
    }

    /// Handle connection timeout for a specific camera
    private func handleConnectionTimeout(for uuid: UUID) {
        guard let gopro = connectingGoPros[uuid] else { return }

        let cameraName = CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name)
        log("⏰ Connection timeout for \(cameraName) after \(connectionTimeout)s")

        // Log timeout for crash reporting with detailed context
        CrashReporter.shared.logError(
            "BLE Connection Timeout",
            error: nil,
            context: [
                "peripheral_name": gopro.peripheral.name ?? "Unknown",
                "peripheral_id": gopro.peripheral.identifier.uuidString,
                "peripheral_state": peripheralStateString(gopro.peripheral.state),
                "timeout_duration": "\(connectionTimeout)s",
                "retry_count": "\(connectionRetryCount[uuid] ?? 0)"
            ],
            appStateContext: createAppStateContext()
        )

        // Cancel the connection attempt
        centralManager.cancelPeripheralConnection(gopro.peripheral)

        // Clean up
        DispatchQueue.main.async {
            self.connectingGoPros.removeValue(forKey: uuid)
            self.connectionAttemptTimers.removeValue(forKey: uuid)
        }

        // Trigger retry logic by calling the existing connection failure handler
        centralManager(centralManager, didFailToConnect: gopro.peripheral, error: nil)
    }

    private func retryConnection(for uuid: UUID) {
        guard let gopro = discoveredGoPros[uuid], connectedGoPros[uuid] == nil else { return }

        // Check if device was intentionally put to sleep - don't retry if so
        if deviceStateManager.isDeviceSleeping(uuid) {
            log("🌙 Device \(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name)) is sleeping - skipping retry")
            return
        }

        // Check if peripheral is in a valid state for retry
        guard isValidForRetry(gopro.peripheral) else {
            log("❌ Cannot retry connection to \(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name)) - peripheral not in valid state")
            return
        }

        log("Retrying connection to \(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.peripheral.name))...")
        gopro.peripheral.delegate = self

        DispatchQueue.main.async {
            self.connectingGoPros[uuid] = gopro // Add to connecting list

            // Set up connection timeout for retry attempt
            self.connectionAttemptTimers[uuid] = Timer.scheduledTimer(withTimeInterval: self.connectionTimeout, repeats: false) { [weak self] _ in
                self?.handleConnectionTimeout(for: uuid)
            }
        }
        centralManager.connect(gopro.peripheral, options: nil)
    }

    func disconnectFromGoPro(uuid: UUID, sleep: Bool = false) {
        guard let gopro = connectedGoPros[uuid] else { return }

        if sleep {
            // For sleep, first release control, then send sleep command
            releaseControl(for: uuid)

            // Wait a moment for control release, then send sleep command
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.sendSleepCommand(to: gopro)
            }
        } else {
            // For normal disconnect, release control and disconnect immediately
            releaseControl(for: uuid)
            centralManager.cancelPeripheralConnection(gopro.peripheral)
            log("Disconnecting \(gopro.peripheral.name ?? "GoPro")...")
        }
    }

    func powerDownGoPro(uuid: UUID) {


        guard let gopro = connectedGoPros[uuid] else { return }

            sendPowerDownCommand(to: gopro)

        removeDevice(from: \.connectedGoPros, uuid: uuid) // Use key path for connectedGoPros
        log("\(gopro.peripheral.name ?? "GoPro") powered down.")
    }


    private func sendCommand(_ command: [UInt8], to gopro: GoPro, actionDescription: String, priority: CommandPriority = .critical) {
        // Use the queue system for consistency
        sendCommand(command, to: gopro.peripheral.identifier, commandName: actionDescription, priority: priority)
    }

    private func sendSleepCommand(to gopro: GoPro) {
        let sleepCommand: [UInt8] = [1, 5]
        let uuid = gopro.peripheral.identifier

        // Track this as a pending sleep command
        pendingSleepCommands.insert(uuid)

        // Mark device as sleeping
        deviceStateManager.setDeviceSleeping(uuid, isSleeping: true)

        // Cancel any pending connection retry timers
        connectionRetryTimers[uuid]?.invalidate()
        connectionRetryTimers.removeValue(forKey: uuid)
        connectionAttemptTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)
        connectionRetryCount.removeValue(forKey: uuid)

        log("💤 Sending camera to sleep: \(CameraIdentityManager.shared.getDisplayName(for: uuid))")

        sendCommand(sleepCommand, to: gopro, actionDescription: "Sending to sleep")

        // Set a timeout to disconnect if no response is received
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if self.pendingSleepCommands.contains(uuid) {
                self.log("Sleep command timeout for \(gopro.peripheral.name ?? "device"), disconnecting anyway")
                self.pendingSleepCommands.remove(uuid)
                self.centralManager.cancelPeripheralConnection(gopro.peripheral)
            }
        }
    }

    private func sendPowerDownCommand(to gopro: GoPro) {
        let powerDownCommand: [UInt8] = [1, 4]
        let uuid = gopro.peripheral.identifier

        // Track this as a pending power down command
        pendingPowerDownCommands.insert(uuid)

        sendCommand(powerDownCommand, to: gopro, actionDescription: "Powering down")

        // Set a timeout to disconnect if no response is received
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if self.pendingPowerDownCommands.contains(uuid) {
                self.log("Power down command timeout for \(gopro.peripheral.name ?? "device"), disconnecting anyway")
                self.pendingPowerDownCommands.remove(uuid)
                self.centralManager.cancelPeripheralConnection(gopro.peripheral)
            }
        }
    }

    // MARK: - Device State Helpers

    /// Check if a device is sleeping
    func isDeviceSleeping(_ uuid: UUID) -> Bool {
        return deviceStateManager.isDeviceSleeping(uuid)
    }

    // MARK: - Query Timer Management

    func startDeviceQueryTimer() {
        // CRITICAL FIX: Run timer on background queue to avoid blocking main thread during keyboard presentation
        let bleQueue = DispatchQueue(label: "com.kmatzen.facett.ble.timer", qos: .utility)
        bleQueue.async {
            DispatchQueue.main.async {
                self.deviceQueryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }

                    // Run heavy BLE operations on background queue
                    bleQueue.async {
                        // Check for timeouts in multipart responses
                        let timeoutResponses = self.bleParser.checkTimeouts(timeoutInterval: 3.0)
                        if !timeoutResponses.isEmpty {
                            ErrorHandler.debug("Processing \(timeoutResponses.count) responses from timed out buffers")
                            DispatchQueue.main.async {
                                for uuid in self.connectedGoPros.keys {
                                    self.responseHandler.updateGoProStatus(uuid: uuid, with: timeoutResponses)
                                }
                            }
                        }

                        // Query devices on background thread
                        for uuid in self.connectedGoPros.keys {
                            self.queryDevice(for: uuid)
                        }

                        // Restart timer
                        self.startDeviceQueryTimer()
                    }
                }
            }
        }
    }

    func startDeviceScanTimer() {
        // CRITICAL FIX: Run scan timer operations on background queue to avoid blocking main thread
        let bleQueue = DispatchQueue(label: "com.kmatzen.facett.ble.scan", qos: .utility)
        DispatchQueue.main.async {
            self.deviceScanTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                // Run scanning operations on background queue
                bleQueue.async {
                    if self.connectingGoPros.isEmpty {
                        self.startScanning(reset: false)
                    }

                    self.startDeviceScanTimer()
                }
            }
        }
    }

    func stopDeviceQueryTimer() {
        DispatchQueue.main.async {
            if let timer = self.deviceQueryTimer {
                timer.invalidate()
                self.deviceQueryTimer = nil
            }
        }
    }

    func stopDeviceScanTimer() {
        DispatchQueue.main.async {
            if let timer = self.deviceScanTimer {
                timer.invalidate()
                self.deviceScanTimer = nil
            }
        }
    }

    func pauseScanning() {
        DispatchQueue.main.async {
            self.stopDeviceScanTimer()
            self.stopDeviceQueryTimer()
        }
        centralManager.stopScan()
    }

    func resumeScanning() {
        startDeviceScanTimer()
        startDeviceQueryTimer()
    }

    private func queryDevice(for uuid: UUID) {
        guard let gopro = connectedGoPros[uuid] else { return; }

        // Check if there are any pending multipart responses for this device
        let peripheralId = gopro.peripheral.identifier.uuidString
        let hasPendingResponse = bleParser.getBufferState().buffers.keys.contains { $0.hasPrefix(peripheralId) }

        if hasPendingResponse {
            ErrorHandler.debug("Skipping query - multipart response in progress",
                              context: ["camera_name": gopro.name ?? "Unknown", "camera_id": uuid.uuidString])
            return
        }

        // Record query start time for health monitoring
        lastQueryTimes[uuid] = Date()

        // Always query status (critical for UI updates)
        queryDeviceStatus(for: gopro.peripheral, command: GoProCommands.Status.status1, description: "consolidated status1")
        queryDeviceStatus(for: gopro.peripheral, command: GoProCommands.Status.status2, description: "consolidated status2")

        // Query WiFi credentials (for WiFi export feature)
        queryDeviceStatus(for: gopro.peripheral, command: GoProCommands.Status.wifiCredentials, description: "WiFi credentials")

        // Only query settings every 4th cycle (reduce BLE load by 60%)
        settingsQueryCounter += 1
        if settingsQueryCounter >= 4 {
            settingsQueryCounter = 0
            queryDeviceSetting(for: gopro.peripheral, command: GoProCommands.Settings.settings1, description: "consolidated settings1")
            queryDeviceSetting(for: gopro.peripheral, command: GoProCommands.Settings.settings2, description: "consolidated settings2")
            queryDeviceSetting(for: gopro.peripheral, command: GoProCommands.Settings.settings3, description: "consolidated settings3")
        }
    }

    private func queryDeviceStatus(for peripheral: CBPeripheral, command: [UInt8], description: String) {
        sendCommand(
            to: peripheral,
            characteristicUUID: Constants.UUIDs.query,
            command: command,
            description: description
        )
    }

    private func queryDeviceSetting(for peripheral: CBPeripheral, command: [UInt8], description: String) {


        guard connectedGoPros[peripheral.identifier]?.hasControl == true else {
            return
        }

        guard let characteristic = findCharacteristic(for: peripheral, uuid: Constants.UUIDs.query) else {
            log("Query characteristic not found for \(peripheral.name ?? "a device").")
            return
        }

        bleCommandQueue.async{
            peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
        }
        log("Requested \(description) for \(peripheral.name ?? "a device"). Command: \(command).")
    }

    private func queryAllSettings(from peripheral: CBPeripheral) {
        // Query all settings to get the updated state after sending settings
            queryDeviceSetting(for: peripheral, command: GoProCommands.Settings.settings1, description: "consolidated settings1")
            queryDeviceSetting(for: peripheral, command: GoProCommands.Settings.settings2, description: "consolidated settings2")
            queryDeviceSetting(for: peripheral, command: GoProCommands.Settings.settings3, description: "consolidated settings3")
    }

    // MARK: - Utility Functions
    private func findCharacteristic(for peripheral: CBPeripheral, uuid: CBUUID) -> CBCharacteristic? {


        return peripheral.services?.flatMap { $0.characteristics ?? [] }.first { $0.uuid == uuid }
    }



    // MARK: - Sleep and Wake Operations
    func putCamerasToSleep() {
        connectedGoPros.keys.forEach { disconnectFromGoPro(uuid: $0, sleep: true) }
    }

    func connectCameras() {
        // Set target cameras to all discovered cameras
        targetConnectedCameras = Set(discoveredGoPros.keys)

        // Start straggler retry timer
        startStragglerRetryTimer()

        // Connect all discovered cameras
        discoveredGoPros.keys.forEach { connectToGoPro(uuid: $0) }
    }

    func disconnectCameras() {
        connectedGoPros.keys.forEach { disconnectFromGoPro(uuid: $0, sleep: false) }
        clearTargetCameras()
    }

    func powerDownAllDevices() {
        connectedGoPros.forEach {_, gopro in
            powerDownGoPro(uuid: gopro.peripheral.identifier)
        }
    }

    func enableAPAllDevices() {
        connectedGoPros.forEach {_, gopro in
            enableAP(for: gopro.peripheral.identifier)
        }
    }

    func disableAPAllDevices() {
        connectedGoPros.forEach {_, gopro in
            disableAP(for: gopro.peripheral.identifier)
        }
    }

    func getWiFiCredentialsForAllDevices() {
        connectedGoPros.forEach {_, gopro in
            // Try the legacy TLV method first
            queryDeviceStatus(for: gopro.peripheral, command: GoProCommands.Status.wifiCredentials, description: "WiFi credentials")

            // Try alternative TLV types for passwords
            queryDeviceStatus(for: gopro.peripheral, command: GoProCommands.Status.wifiCredentialsAlt, description: "WiFi credentials alternative")

            // Try GPCAMERA_GET_WIFI_CONFIG command
            sendCommand(GoProCommands.Status.getWiFiConfig, to: gopro.peripheral.identifier, commandName: "get WiFi config")

            // Try reading from the official GoPro WiFi service characteristics
            readWiFiCredentialsFromService(for: gopro.peripheral)
        }
    }

    func readWiFiCredentialsFromService(for peripheral: CBPeripheral) {
        // Find the GoPro WiFi service
        guard let wifiService = peripheral.services?.first(where: { $0.uuid == Constants.UUIDs.goproWiFiService }) else {
            return
        }

        // Find and read the WiFi SSID characteristic
        if let ssidCharacteristic = wifiService.characteristics?.first(where: { $0.uuid == Constants.UUIDs.wifiAPSSID }) {
            if ssidCharacteristic.properties.contains(.read) {
                peripheral.readValue(for: ssidCharacteristic)
            }
        }

        // Find and read the WiFi password characteristic
        if let passwordCharacteristic = wifiService.characteristics?.first(where: { $0.uuid == Constants.UUIDs.wifiAPPassword }) {
            if passwordCharacteristic.properties.contains(.read) {
                peripheral.readValue(for: passwordCharacteristic)
            }
        }

        // Find and read the WiFi AP state characteristic
        if let stateCharacteristic = wifiService.characteristics?.first(where: { $0.uuid == Constants.UUIDs.wifiAPState }) {
            if stateCharacteristic.properties.contains(.read) {
                peripheral.readValue(for: stateCharacteristic)
            }
        }
    }

    // MARK: - WiFi Configuration Commands

    func getWiFiConfig(for uuid: UUID) {
        wifiManager.getWiFiConfig(for: uuid) { [weak self] command, uuid, commandName in
            self?.sendCommand(command, to: uuid, commandName: commandName)
        }
    }

    func disableTurboTransferAllDevices() {
        connectedGoPros.forEach {_, gopro in
            disableTurboTransfer(for: gopro.peripheral.identifier)
        }
    }

    func enableTurboTransferAllDevices() {
        connectedGoPros.forEach {_, gopro in
            enableTurboTransfer(for: gopro.peripheral.identifier)
        }
    }

    // MARK: - Straggler Connection Management

    private func startStragglerRetryTimer() {
        stopStragglerRetryTimer() // Stop any existing timer

        stragglerRetryTimer = Timer.scheduledTimer(withTimeInterval: stragglerRetryInterval, repeats: true) { [weak self] _ in
            self?.checkAndRetryStragglers()
        }
    }

    private func stopStragglerRetryTimer() {
        stragglerRetryTimer?.invalidate()
        stragglerRetryTimer = nil
    }

    private func checkAndRetryStragglers() {
        // Only proceed if we have target cameras to connect
        guard !targetConnectedCameras.isEmpty else { return }

        // Find cameras that should be connected but aren't
        let stragglers = targetConnectedCameras.filter { cameraId in
            // Camera should be connected if it's discovered but not connected and not currently connecting
            return discoveredGoPros[cameraId] != nil &&
                   connectedGoPros[cameraId] == nil &&
                   connectingGoPros[cameraId] == nil
        }

        if !stragglers.isEmpty {
            log("🔄 Found \(stragglers.count) straggler cameras, attempting to reconnect...")

            for cameraId in stragglers {
                let currentRetryCount = stragglerRetryCount[cameraId] ?? 0

                if currentRetryCount < maxStragglerRetries {
                    stragglerRetryCount[cameraId] = currentRetryCount + 1
                    log("🔄 Retrying straggler camera \(CameraIdentityManager.shared.getDisplayName(for: cameraId)) (attempt \(currentRetryCount + 1)/\(maxStragglerRetries))")
                    connectToGoPro(uuid: cameraId)
                } else {
                    log("❌ Giving up on straggler camera \(CameraIdentityManager.shared.getDisplayName(for: cameraId)) after \(maxStragglerRetries) attempts")
                    // Remove from target cameras if we've given up
                    targetConnectedCameras.remove(cameraId)
                }
            }
        } else {
            // All target cameras are connected or connecting, stop the timer
            log("✅ All target cameras connected, stopping straggler retry timer")
            stopStragglerRetryTimer()
            logConnectionSummary()
        }
    }

    func setTargetCameras(_ cameraIds: Set<UUID>) {
        targetConnectedCameras = cameraIds
        if !cameraIds.isEmpty {
            startStragglerRetryTimer()
        } else {
            stopStragglerRetryTimer()
        }
    }

    func clearTargetCameras() {
        targetConnectedCameras.removeAll()
        stopStragglerRetryTimer()
        stragglerRetryCount.removeAll()
    }

    /// Log a summary of connection status for debugging
    private func logConnectionSummary() {
        let totalDiscovered = discoveredGoPros.count
        let totalConnected = connectedGoPros.count
        let totalConnecting = connectingGoPros.count
        let totalFailed = totalDiscovered - totalConnected - totalConnecting

        log("📊 Connection Summary: \(totalConnected) connected, \(totalConnecting) connecting, \(totalFailed) failed out of \(totalDiscovered) discovered")

        if totalFailed > 0 {
            let failedCameras = discoveredGoPros.keys.filter { uuid in
                connectedGoPros[uuid] == nil && connectingGoPros[uuid] == nil
            }

            for uuid in failedCameras {
                let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid)
                let retryCount = connectionRetryCount[uuid] ?? 0
                log("❌ Failed: \(cameraName) (retries: \(retryCount)/\(maxRetryAttempts))")
            }
        }
    }

    /// Create app state context for crash reporting
    func createAppStateContext(activeGroup: String? = nil) -> AppStateContext {
        return AppStateContext(
            connectedCameras: connectedGoPros.count,
            discoveredCameras: discoveredGoPros.count,
            activeGroup: activeGroup,
            appState: nil, // Will be determined by CrashReporter
            backgroundTimeRemaining: nil // Will be determined by CrashReporter
        )
    }



    func sendSettingsToCamerasInGroup(_ cameraSerials: Set<String>, configManager: ConfigManager, cameraGroupManager: CameraGroupManager) {
        // Get target settings using centralized logic
        let targetSettings = configManager.getTargetSettings(for: cameraGroupManager.activeGroup)

        // Convert serials to UUIDs
        let cameraIds = cameraSerials.compactMap { serial -> UUID? in
            return CameraSerialResolver.shared.getUUID(forSerial: serial)
        }

        let cameraCount = cameraIds.count
        connectedGoPros.forEach { uuid, gopro in
            if cameraIds.contains(uuid) {
                sendSettings(to: gopro.peripheral, settings: targetSettings)
            }
        }

        // Voice notification for settings sync completion
        DispatchQueue.main.async {
            VoiceNotificationManager.shared.notifySettingsSynced(cameraCount: cameraCount)
        }
    }

    func startRecordingAllDevices() {
        recordingManager.startRecordingAllDevices()
    }

    func stopRecordingAllDevices() {
        recordingManager.stopRecordingAllDevices()
    }

    func startRecordingForCamerasInSet(_ cameraSerials: Set<String>) {
        // Convert serial numbers to UUIDs
        let cameraIds = cameraSerials.compactMap { serial -> UUID? in
            return CameraSerialResolver.shared.getUUID(forSerial: serial)
        }
        recordingManager.startRecordingForCamerasInSet(Set(cameraIds))
    }

    func stopRecordingForCamerasInSet(_ cameraSerials: Set<String>) {
        // Convert serial numbers to UUIDs
        let cameraIds = cameraSerials.compactMap { serial -> UUID? in
            return CameraSerialResolver.shared.getUUID(forSerial: serial)
        }
        recordingManager.stopRecordingForCamerasInSet(Set(cameraIds))
    }

    func sendSettings(to peripheral: CBPeripheral, settings: GoProSettings? = nil) {
        guard let characteristic = findCharacteristic(for: peripheral, uuid: Constants.UUIDs.settings) else {
            log("Settings characteristic not found for \(peripheral.name ?? "a device").")
            return
        }

        guard let targetSettings = settings else {
            log("No target settings provided")
            return
        }

        // Settings will be updated when we receive responses from the camera

        // Explicitly send each setting
        sendSetting(peripheral, characteristic, id: 2, value: targetSettings.videoResolution)
        sendSetting(peripheral, characteristic, id: 3, value: targetSettings.framesPerSecond)
        sendSetting(peripheral, characteristic, id: 59, value: targetSettings.autoPowerDown)
        sendSetting(peripheral, characteristic, id: 83, value: targetSettings.gps ? 1 : 0)
        sendSetting(peripheral, characteristic, id: 121, value: targetSettings.videoLens)
        sendSetting(peripheral, characteristic, id: 134, value: targetSettings.antiFlicker)
        sendSetting(peripheral, characteristic, id: 135, value: targetSettings.hypersmooth)
        sendSetting(peripheral, characteristic, id: 162, value: targetSettings.maxLens ? 1 : 0)
        sendSetting(peripheral, characteristic, id: 173, value: targetSettings.videoPerformanceMode)
        sendSetting(peripheral, characteristic, id: 13, value: targetSettings.isoMax)
        sendSetting(peripheral, characteristic, id: 102, value: targetSettings.isoMin)
        sendSetting(peripheral, characteristic, id: 115, value: targetSettings.whiteBalance)
        sendSetting(peripheral, characteristic, id: 116, value: targetSettings.colorProfile)
        sendSetting(peripheral, characteristic, id: 118, value: targetSettings.ev)
        sendSetting(peripheral, characteristic, id: 124, value: targetSettings.bitrate)
        sendSetting(peripheral, characteristic, id: 139, value: targetSettings.rawAudio)
        // Note: Mode setting (id: 144) is not sent via BLE as the protocol cannot change capture mode
        // Users must manually switch cameras to video mode using the camera's physical controls
        sendSetting(peripheral, characteristic, id: 145, value: targetSettings.shutter)
        sendSetting(peripheral, characteristic, id: 149, value: targetSettings.wind)
        sendSetting(peripheral, characteristic, id: 167, value: targetSettings.hindsight)
        sendSetting(peripheral, characteristic, id: 54, value: targetSettings.quickCapture ? 1 : 0)
        sendSetting(peripheral, characteristic, id: 86, value: targetSettings.voiceControl ? 1 : 0)
        sendSetting(peripheral, characteristic, id: 114, value: targetSettings.protuneEnabled ? 1 : 0)
        sendSetting(peripheral, characteristic, id: 88, value: targetSettings.lcdBrightness)
        sendSetting(peripheral, characteristic, id: 84, value: targetSettings.language)
        sendSetting(peripheral, characteristic, id: 87, value: targetSettings.beeps)
        sendSetting(peripheral, characteristic, id: 91, value: targetSettings.led)

        // Send the current date and time
        setDateTime(for: peripheral.identifier)
    }

    private func sendSetting(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic, id: UInt8, value: Int) {
        let command: [UInt8] = [
            3, // Length of the command
            id, // Setting ID
            1, // Length of the value
            UInt8(value) // Value
        ]
        let data = Data(command)
        bleCommandQueue.async {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
        log("Sent setting ID \(id) with value \(value) to \(peripheral.name ?? "a device"). Command: \(command)")
    }

    func configureAllDevices() {


        connectedGoPros.forEach { _, gopro in
            sendSettings(to: gopro.peripheral)
        }
    }
}

extension GoPro {
    func value(forSettingId id: UInt8) -> Any? {
        switch id {
        case 2: return settings.videoResolution
        case 3: return settings.framesPerSecond
        case 59: return settings.autoPowerDown
        case 83: return settings.gps ? 1 : 0
        case 121: return settings.videoLens
        case 134: return settings.antiFlicker
        case 135: return settings.hypersmooth
        case 162: return settings.maxLens ? 1 : 0
        case 173: return settings.videoPerformanceMode
        case 13: return settings.isoMax
        case 84: return settings.language
        case 86: return settings.voiceControl ? 1 : 0
        case 87: return settings.beeps
        case 88: return settings.lcdBrightness
        case 91: return settings.led
        case 102: return settings.isoMin
        case 114: return settings.protuneEnabled ? 1 : 0
        case 115: return settings.whiteBalance
        case 116: return settings.colorProfile
        case 118: return settings.ev
        case 124: return settings.bitrate
        case 139: return settings.rawAudio
        case 144: return settings.mode
        case 145: return settings.shutter
        case 149: return settings.wind
        case 167: return settings.hindsight
        case 54: return settings.quickCapture ? 1 : 0
        case 85: return settings.voiceLanguageControl
        default: return nil
        }
    }
}
