import Foundation
import CoreBluetooth

// MARK: - BLE Device State Manager
// Handles device discovery, connection tracking, and state management

class BLEDeviceStateManager: ObservableObject {

    // MARK: - Data Structures

    struct DeviceState {
        let uuid: UUID
        let peripheral: CBPeripheral
        let discoveredAt: Date
        var lastSeen: Date
        var connectionAttempts: Int = 0
        var lastConnectionAttempt: Date?
        var isConnecting: Bool = false
        var isConnected: Bool = false
        var isSleeping: Bool = false
        var isPoweringDown: Bool = false
    }

    struct ConnectionRetryStatus {
        var isRetrying: Bool = false
        var retryCount: Int = 0
        var lastRetryAttempt: Date?
        var maxRetryAttempts: Int = 3
        var retryDelay: TimeInterval = 1.0
    }

    // MARK: - Properties

    @Published var discoveredDevices: [UUID: DeviceState] = [:]
    @Published var connectedDevices: [UUID: DeviceState] = [:]
    @Published var connectingDevices: [UUID: DeviceState] = [:]
    @Published var connectionRetryStatus: [UUID: ConnectionRetryStatus] = [:]

    private var connectionRetryCount: [UUID: Int] = [:]
    private var connectionRetryTimers: [UUID: Timer] = [:]
    private var connectionAttemptTimers: [UUID: Timer] = [:]

    // Configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0
    private let connectionTimeout: TimeInterval = 10.0

    // Callbacks
    var onDeviceDiscovered: ((UUID, CBPeripheral) -> Void)?
    var onDeviceConnected: ((UUID, CBPeripheral) -> Void)?
    var onDeviceDisconnected: ((UUID, CBPeripheral) -> Void)?
    var onConnectionRetry: ((UUID, Int) -> Void)?
    var onConnectionTimeout: ((UUID) -> Void)?

    // MARK: - Public Interface

    /// Add a discovered device
    func addDiscoveredDevice(_ peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        let deviceState = DeviceState(
            uuid: uuid,
            peripheral: peripheral,
            discoveredAt: Date(),
            lastSeen: Date()
        )

        discoveredDevices[uuid] = deviceState

        log("Device discovered: \(peripheral.name ?? "Unknown") (\(uuid))")
        onDeviceDiscovered?(uuid, peripheral)
    }

    /// Update device last seen time
    func updateDeviceLastSeen(_ uuid: UUID) {
        discoveredDevices[uuid]?.lastSeen = Date()
    }

    /// Start connection to a device
    func startConnection(to uuid: UUID) {
        guard let deviceState = discoveredDevices[uuid] else {
            log("Cannot connect to unknown device: \(uuid)")
            return
        }

        var updatedState = deviceState
        updatedState.isConnecting = true
        updatedState.connectionAttempts += 1
        updatedState.lastConnectionAttempt = Date()

        discoveredDevices[uuid] = updatedState
        connectingDevices[uuid] = updatedState

        // Set up connection timeout
        connectionAttemptTimers[uuid] = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout(for: uuid)
        }

        log("Starting connection to device: \(uuid)")
    }

    /// Handle successful connection
    func handleSuccessfulConnection(_ uuid: UUID) {
        guard let deviceState = discoveredDevices[uuid] else { return }

        var updatedState = deviceState
        updatedState.isConnecting = false
        updatedState.isConnected = true

        discoveredDevices[uuid] = updatedState
        connectedDevices[uuid] = updatedState
        connectingDevices.removeValue(forKey: uuid)

        // Clean up timers
        connectionAttemptTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)
        connectionRetryTimers[uuid]?.invalidate()
        connectionRetryTimers.removeValue(forKey: uuid)

        // Reset retry count
        connectionRetryCount.removeValue(forKey: uuid)
        connectionRetryStatus.removeValue(forKey: uuid)

        log("Device connected: \(uuid)")
        onDeviceConnected?(uuid, deviceState.peripheral)
    }

    /// Handle connection failure
    func handleConnectionFailure(_ uuid: UUID) {
        guard let deviceState = discoveredDevices[uuid] else { return }

        var updatedState = deviceState
        updatedState.isConnecting = false

        discoveredDevices[uuid] = updatedState
        connectingDevices.removeValue(forKey: uuid)

        // Clean up connection attempt timer
        connectionAttemptTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)

        // Start retry logic
        startConnectionRetry(for: uuid)

        log("Connection failed for device: \(uuid)")
    }

    /// Handle device disconnection
    func handleDeviceDisconnection(_ uuid: UUID) {
        guard let deviceState = discoveredDevices[uuid] else { return }

        var updatedState = deviceState
        updatedState.isConnected = false
        updatedState.isConnecting = false

        discoveredDevices[uuid] = updatedState
        connectedDevices.removeValue(forKey: uuid)
        connectingDevices.removeValue(forKey: uuid)

        // Clean up timers
        connectionAttemptTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)
        connectionRetryTimers[uuid]?.invalidate()
        connectionRetryTimers.removeValue(forKey: uuid)

        log("Device disconnected: \(uuid)")
        onDeviceDisconnected?(uuid, deviceState.peripheral)
    }

    /// Set device sleeping state
    func setDeviceSleeping(_ uuid: UUID, isSleeping: Bool) {
        discoveredDevices[uuid]?.isSleeping = isSleeping
        connectedDevices[uuid]?.isSleeping = isSleeping
    }

    /// Set device powering down state
    func setDevicePoweringDown(_ uuid: UUID, isPoweringDown: Bool) {
        discoveredDevices[uuid]?.isPoweringDown = isPoweringDown
        connectedDevices[uuid]?.isPoweringDown = isPoweringDown
    }

    /// Get device state
    func getDeviceState(for uuid: UUID) -> DeviceState? {
        return discoveredDevices[uuid]
    }

    /// Get connected device state
    func getConnectedDeviceState(for uuid: UUID) -> DeviceState? {
        return connectedDevices[uuid]
    }

    /// Check if device is connected
    func isDeviceConnected(_ uuid: UUID) -> Bool {
        return connectedDevices[uuid]?.isConnected ?? false
    }

    /// Check if device is connecting
    func isDeviceConnecting(_ uuid: UUID) -> Bool {
        return connectingDevices[uuid]?.isConnecting ?? false
    }

    /// Check if device is sleeping
    func isDeviceSleeping(_ uuid: UUID) -> Bool {
        return discoveredDevices[uuid]?.isSleeping ?? false
    }

    /// Check if device is powering down
    func isDevicePoweringDown(_ uuid: UUID) -> Bool {
        return discoveredDevices[uuid]?.isPoweringDown ?? false
    }

    /// Remove device from all collections
    func removeDevice(_ uuid: UUID) {
        discoveredDevices.removeValue(forKey: uuid)
        connectedDevices.removeValue(forKey: uuid)
        connectingDevices.removeValue(forKey: uuid)
        connectionRetryStatus.removeValue(forKey: uuid)
        connectionRetryCount.removeValue(forKey: uuid)

        // Clean up timers
        connectionRetryTimers[uuid]?.invalidate()
        connectionRetryTimers.removeValue(forKey: uuid)
        connectionAttemptTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)

        log("Device removed: \(uuid)")
    }

    /// Clear all devices
    func clearAllDevices() {
        for timer in connectionRetryTimers.values {
            timer.invalidate()
        }
        for timer in connectionAttemptTimers.values {
            timer.invalidate()
        }

        discoveredDevices.removeAll()
        connectedDevices.removeAll()
        connectingDevices.removeAll()
        connectionRetryStatus.removeAll()
        connectionRetryCount.removeAll()
        connectionRetryTimers.removeAll()
        connectionAttemptTimers.removeAll()

        log("All devices cleared")
    }

    /// Get all connected device UUIDs
    func getConnectedDeviceUUIDs() -> [UUID] {
        return Array(connectedDevices.keys)
    }

    /// Get all discovered device UUIDs
    func getDiscoveredDeviceUUIDs() -> [UUID] {
        return Array(discoveredDevices.keys)
    }

    /// Get all connecting device UUIDs
    func getConnectingDeviceUUIDs() -> [UUID] {
        return Array(connectingDevices.keys)
    }

    // MARK: - Private Methods

    private func startConnectionRetry(for uuid: UUID) {
        let retryCount = connectionRetryCount[uuid] ?? 0

        guard retryCount < maxRetryAttempts else {
            log("Max retry attempts reached for device: \(uuid)")
            return
        }

        connectionRetryCount[uuid] = retryCount + 1

        var retryStatus = connectionRetryStatus[uuid] ?? ConnectionRetryStatus()
        retryStatus.isRetrying = true
        retryStatus.retryCount = retryCount + 1
        retryStatus.lastRetryAttempt = Date()
        connectionRetryStatus[uuid] = retryStatus

        let delay = calculateRetryDelay(for: retryCount + 1)

        log("Retrying connection to device \(uuid) (\(retryCount + 1)/\(maxRetryAttempts)) in \(delay)s")

        connectionRetryTimers[uuid] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.onConnectionRetry?(uuid, retryCount + 1)
        }
    }

    private func handleConnectionTimeout(for uuid: UUID) {
        log("Connection timeout for device: \(uuid)")
        onConnectionTimeout?(uuid)
        handleConnectionFailure(uuid)
    }

    private func calculateRetryDelay(for attempt: Int) -> TimeInterval {
        let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
        return min(delay, maxRetryDelay)
    }

    private func log(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        ErrorHandler.debug("BLEDeviceStateManager: \(message)")
    }
}
