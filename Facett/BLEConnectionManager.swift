import SwiftUI
import CoreBluetooth

// MARK: - Connection Retry Status
enum ConnectionRetryStatus {
    case connecting
    case retrying(attempt: Int, maxAttempts: Int)
    case failed(error: String)
    case abandoned(maxAttempts: Int)

    var displayText: String {
        switch self {
        case .connecting:
            return "Connecting..."
        case .retrying(let attempt, let maxAttempts):
            return "Retrying... (\(attempt)/\(maxAttempts))"
        case .failed(let error):
            return "Failed: \(error)"
        case .abandoned(let maxAttempts):
            return "Failed after \(maxAttempts) attempts"
        }
    }

    var icon: String {
        switch self {
        case .connecting:
            return "wifi"
        case .retrying:
            return "arrow.clockwise"
        case .failed:
            return "exclamationmark.triangle"
        case .abandoned:
            return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .connecting:
            return .blue
        case .retrying:
            return .orange
        case .failed:
            return .red
        case .abandoned:
            return .gray
        }
    }
}

// MARK: - Connection Health
struct ConnectionHealth {
    let stabilityScore: Double
    let averageResponseTime: TimeInterval
    let connectionCount: Int
    let lastConnected: Date?

    var healthStatus: String {
        switch stabilityScore {
        case 0.8...1.0:
            return "Excellent"
        case 0.6..<0.8:
            return "Good"
        case 0.4..<0.6:
            return "Fair"
        default:
            return "Poor"
        }
    }
}

// MARK: - BLE Connection Manager
class BLEConnectionManager: ObservableObject {
    // Published properties for UI binding
    @Published var connectionRetryStatus: [UUID: ConnectionRetryStatus] = [:]
    @Published var connectionHealth: [UUID: ConnectionHealth] = [:]

    // Connection tracking
    private var connectionRetryCount: [UUID: Int] = [:]
    private var connectionRetryTimers: [UUID: Timer] = [:]
    private var connectionAttemptTimers: [UUID: Timer] = [:]
    private var maxRetryAttempts = 3
    private var connectionTimeout: TimeInterval = 10.0

    // Callbacks
    var onConnectionSuccess: ((UUID) -> Void)?
    var onConnectionFailed: ((UUID, Error) -> Void)?
    var onRetryAttempt: ((UUID, Int) -> Void)?

    // MARK: - Connection Management

    /// Start connection retry process for a device
    func startConnectionRetry(for uuid: UUID, maxAttempts: Int = 3) {
        ErrorHandler.info("🔄 Starting connection retry for device \(uuid)")

        connectionRetryCount[uuid] = 0
        maxRetryAttempts = maxAttempts

        updateRetryStatus(uuid, status: .connecting)
        attemptConnection(uuid)
    }

    /// Attempt connection to a device
    private func attemptConnection(_ uuid: UUID) {
        guard let currentAttempt = connectionRetryCount[uuid] else { return }

        ErrorHandler.info("🔗 Connection attempt \(currentAttempt + 1)/\(maxRetryAttempts) for device \(uuid)")

        // Start connection timeout timer
        connectionAttemptTimers[uuid] = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout(uuid)
        }

        // Update retry status
        if currentAttempt > 0 {
            updateRetryStatus(uuid, status: .retrying(attempt: currentAttempt + 1, maxAttempts: maxRetryAttempts))
        }

        onRetryAttempt?(uuid, currentAttempt + 1)
    }

    /// Handle successful connection
    func handleConnectionSuccess(_ uuid: UUID) {
        ErrorHandler.info("✅ Connection successful for device \(uuid)")

        // Cancel timers
        connectionAttemptTimers[uuid]?.invalidate()
        connectionRetryTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)
        connectionRetryTimers.removeValue(forKey: uuid)

        // Reset retry count
        connectionRetryCount.removeValue(forKey: uuid)

        // Update health
        updateConnectionHealth(uuid, success: true)

        onConnectionSuccess?(uuid)
    }

    /// Handle connection failure
    func handleConnectionFailure(_ uuid: UUID, error: Error) {
        ErrorHandler.info("❌ Connection failed for device \(uuid): \(error.localizedDescription)")

        // Cancel attempt timer
        connectionAttemptTimers[uuid]?.invalidate()
        connectionAttemptTimers.removeValue(forKey: uuid)

        guard let currentAttempt = connectionRetryCount[uuid] else { return }

        if currentAttempt < maxRetryAttempts - 1 {
            // Schedule retry
            let retryDelay = TimeInterval(currentAttempt + 1) * 2.0 // Exponential backoff
            connectionRetryCount[uuid] = currentAttempt + 1

            connectionRetryTimers[uuid] = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
                self?.attemptConnection(uuid)
            }
        } else {
            // Max attempts reached
            updateRetryStatus(uuid, status: .abandoned(maxAttempts: maxRetryAttempts))
            connectionRetryCount.removeValue(forKey: uuid)
            updateConnectionHealth(uuid, success: false)
            onConnectionFailed?(uuid, error)
        }
    }

    /// Handle connection timeout
    private func handleConnectionTimeout(_ uuid: UUID) {
        ErrorHandler.info("⏰ Connection timeout for device \(uuid)")
        handleConnectionFailure(uuid, error: NSError(domain: "BLEConnection", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]))
    }

    /// Cancel connection retry for a device
    func cancelConnectionRetry(for uuid: UUID) {
        ErrorHandler.info("🛑 Cancelling connection retry for device \(uuid)")

        connectionRetryTimers[uuid]?.invalidate()
        connectionAttemptTimers[uuid]?.invalidate()
        connectionRetryTimers.removeValue(forKey: uuid)
        connectionAttemptTimers.removeValue(forKey: uuid)
        connectionRetryCount.removeValue(forKey: uuid)
        connectionRetryStatus.removeValue(forKey: uuid)
    }

    /// Update retry status for a device
    private func updateRetryStatus(_ uuid: UUID, status: ConnectionRetryStatus) {
        DispatchQueue.main.async {
            self.connectionRetryStatus[uuid] = status
        }
    }

    /// Update connection health for a device
    private func updateConnectionHealth(_ uuid: UUID, success: Bool) {
        let currentHealth = connectionHealth[uuid]
        let newConnectionCount = (currentHealth?.connectionCount ?? 0) + 1
        let newStabilityScore = success ? min(1.0, (currentHealth?.stabilityScore ?? 0.5) + 0.1) : max(0.0, (currentHealth?.stabilityScore ?? 0.5) - 0.2)

        let health = ConnectionHealth(
            stabilityScore: newStabilityScore,
            averageResponseTime: currentHealth?.averageResponseTime ?? 0.0,
            connectionCount: newConnectionCount,
            lastConnected: success ? Date() : currentHealth?.lastConnected
        )

        DispatchQueue.main.async {
            self.connectionHealth[uuid] = health
        }
    }

    /// Get connection retry status for a device
    func getRetryStatus(for uuid: UUID) -> ConnectionRetryStatus? {
        return connectionRetryStatus[uuid]
    }

    /// Check if device is currently retrying connection
    func isRetryingConnection(for uuid: UUID) -> Bool {
        return connectionRetryCount[uuid] != nil
    }

    /// Clean up resources
    deinit {
        connectionRetryTimers.values.forEach { $0.invalidate() }
        connectionAttemptTimers.values.forEach { $0.invalidate() }
    }
}
