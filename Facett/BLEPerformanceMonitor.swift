import Foundation
import CoreBluetooth

// MARK: - Command Response Time
struct CommandResponseTime {
    let commandName: String
    let responseTime: TimeInterval
    let timestamp: Date
    let success: Bool
}

// MARK: - BLE Performance Monitor
// Handles performance metrics, connection health monitoring, and stability tracking

class BLEPerformanceMonitor: ObservableObject {

    // MARK: - Data Structures

    struct PerformanceMetrics {
        var totalCommands: Int = 0
        var successfulCommands: Int = 0
        var failedCommands: Int = 0
        var averageResponseTime: TimeInterval = 0
        var totalResponseTime: TimeInterval = 0
        var lastUpdated: Date = Date()

        var successRate: Double {
            guard totalCommands > 0 else { return 0 }
            return Double(successfulCommands) / Double(totalCommands)
        }
    }

    struct ConnectionHealth {
        var stabilityScore: Double = 1.0
        var disconnectionCount: Int = 0
        var lastDisconnection: Date?
        var averageResponseTime: TimeInterval = 0
        var healthStatus: HealthStatus = .excellent

        enum HealthStatus {
            case excellent
            case good
            case fair
            case poor
            case critical
        }
    }

    struct ConnectionStability {
        var totalConnections: Int = 0
        var successfulConnections: Int = 0
        var failedConnections: Int = 0
        var averageConnectionTime: TimeInterval = 0
        var lastConnectionAttempt: Date?

        var stabilityScore: Double {
            guard totalConnections > 0 else { return 1.0 }
            return Double(successfulConnections) / Double(totalConnections)
        }
    }


    // MARK: - Properties

    private var performanceMetrics: [UUID: PerformanceMetrics] = [:]
    private var connectionHealth: [UUID: ConnectionHealth] = [:]
    private var connectionStability: [UUID: ConnectionStability] = [:]
    private var commandStartTimes: [UUID: [String: Date]] = [:]
    private var healthMonitoringTimers: [UUID: Timer] = [:]
    private var performanceMonitoringTimers: [UUID: Timer] = [:]

    // Configuration
    private let healthMonitoringInterval: TimeInterval = 30.0
    private let performanceMonitoringInterval: TimeInterval = 60.0
    private let maxResponseTime: TimeInterval = 10.0
    private let minStabilityScore: Double = 0.8
    private let maxCommandLatencyHistory: Int = 100
    private let healthDegradationThreshold: Double = 0.6

    // Callbacks
    var onHealthDegradation: ((UUID, ConnectionHealth) -> Void)?
    var onPerformanceReport: ((UUID, PerformanceMetrics) -> Void)?

    // MARK: - Public Interface

    /// Start monitoring performance for a device
    func startPerformanceMonitoring(for uuid: UUID) {
        // Initialize metrics if not exists
        if performanceMetrics[uuid] == nil {
            performanceMetrics[uuid] = PerformanceMetrics()
        }

        // Start performance monitoring timer
        performanceMonitoringTimers[uuid] = Timer.scheduledTimer(withTimeInterval: performanceMonitoringInterval, repeats: true) { [weak self] _ in
            self?.reportPerformanceMetrics(for: uuid)
        }
    }

    /// Stop performance monitoring for a device
    func stopPerformanceMonitoring(for uuid: UUID) {
        performanceMonitoringTimers[uuid]?.invalidate()
        performanceMonitoringTimers.removeValue(forKey: uuid)
    }

    /// Start connection health monitoring for a device
    func startConnectionHealthMonitoring(for uuid: UUID) {
        // Initialize health if not exists
        if connectionHealth[uuid] == nil {
            connectionHealth[uuid] = ConnectionHealth()
        }

        // Start health monitoring timer
        healthMonitoringTimers[uuid] = Timer.scheduledTimer(withTimeInterval: healthMonitoringInterval, repeats: true) { [weak self] _ in
            self?.updateConnectionHealth(for: uuid)
        }
    }

    /// Stop connection health monitoring for a device
    func stopConnectionHealthMonitoring(for uuid: UUID) {
        healthMonitoringTimers[uuid]?.invalidate()
        healthMonitoringTimers.removeValue(forKey: uuid)
    }

    /// Record command start time
    func recordCommandStart(for uuid: UUID, commandName: String) -> Date {
        let startTime = Date()
        commandStartTimes[uuid, default: [:]][commandName] = startTime
        return startTime
    }

    /// Record command completion
    func recordCommandCompletion(for uuid: UUID, commandName: String, startTime: Date, success: Bool, retryCount: Int = 0) {
        let responseTime = Date().timeIntervalSince(startTime)

        var metrics = performanceMetrics[uuid] ?? PerformanceMetrics()
        metrics.totalCommands += 1
        metrics.totalResponseTime += responseTime
        metrics.averageResponseTime = metrics.totalResponseTime / Double(metrics.totalCommands)

        if success {
            metrics.successfulCommands += 1
        } else {
            metrics.failedCommands += 1
        }

        metrics.lastUpdated = Date()
        performanceMetrics[uuid] = metrics

        // Create response time record
        let responseTimeRecord = CommandResponseTime(
            commandName: commandName,
            responseTime: responseTime,
            timestamp: Date(),
            success: success
        )

        // Update connection health based on response time
        updateConnectionHealth(for: uuid, responseTime: responseTimeRecord)

        // Clean up command start time
        commandStartTimes[uuid]?.removeValue(forKey: commandName)
    }

    /// Record disconnection
    func recordDisconnection(for uuid: UUID) {
        var health = connectionHealth[uuid] ?? ConnectionHealth()
        health.disconnectionCount += 1
        health.lastDisconnection = Date()
        health.stabilityScore = max(0, health.stabilityScore - 0.1)
        connectionHealth[uuid] = health

        var stability = connectionStability[uuid] ?? ConnectionStability()
        stability.totalConnections += 1
        stability.failedConnections += 1
        connectionStability[uuid] = stability
    }

    /// Record successful connection
    func recordSuccessfulConnection(for uuid: UUID) {
        var stability = connectionStability[uuid] ?? ConnectionStability()
        stability.totalConnections += 1
        stability.successfulConnections += 1
        stability.lastConnectionAttempt = Date()
        connectionStability[uuid] = stability

        var health = connectionHealth[uuid] ?? ConnectionHealth()
        health.stabilityScore = min(1.0, health.stabilityScore + 0.05)
        connectionHealth[uuid] = health
    }

    /// Get performance metrics for a device
    func getPerformanceMetrics(for uuid: UUID) -> PerformanceMetrics? {
        return performanceMetrics[uuid]
    }

    /// Get connection health for a device
    func getConnectionHealth(for uuid: UUID) -> ConnectionHealth? {
        return connectionHealth[uuid]
    }

    /// Get connection stability for a device
    func getConnectionStability(for uuid: UUID) -> ConnectionStability? {
        return connectionStability[uuid]
    }

    /// Reset all metrics for a device
    func resetMetrics(for uuid: UUID) {
        performanceMetrics.removeValue(forKey: uuid)
        connectionHealth.removeValue(forKey: uuid)
        connectionStability.removeValue(forKey: uuid)
        commandStartTimes.removeValue(forKey: uuid)
    }

    /// Reset all metrics for all devices
    func resetAllMetrics() {
        for timer in healthMonitoringTimers.values {
            timer.invalidate()
        }
        for timer in performanceMonitoringTimers.values {
            timer.invalidate()
        }

        performanceMetrics.removeAll()
        connectionHealth.removeAll()
        connectionStability.removeAll()
        commandStartTimes.removeAll()
        healthMonitoringTimers.removeAll()
        performanceMonitoringTimers.removeAll()
    }

    // MARK: - Private Methods

    private func updateConnectionHealth(for uuid: UUID, responseTime: CommandResponseTime) {
        var health = connectionHealth[uuid] ?? ConnectionHealth()

        // Update average response time
        if health.averageResponseTime == 0 {
            health.averageResponseTime = responseTime.responseTime
        } else {
            health.averageResponseTime = (health.averageResponseTime + responseTime.responseTime) / 2
        }

        // Adjust stability score based on response time and success
        if responseTime.responseTime > maxResponseTime {
            health.stabilityScore = max(0, health.stabilityScore - 0.05)
        } else if responseTime.success {
            health.stabilityScore = min(1.0, health.stabilityScore + 0.01)
        }

        // Update health status
        health.healthStatus = determineHealthStatus(stabilityScore: health.stabilityScore, responseTime: health.averageResponseTime)

        connectionHealth[uuid] = health

        // Check for health degradation
        if health.healthStatus == .poor || health.healthStatus == .critical {
            onHealthDegradation?(uuid, health)
        }
    }

    private func updateConnectionHealth(for uuid: UUID) {
        guard let health = connectionHealth[uuid] else { return }

        // Check if health has degraded
        if health.stabilityScore < minStabilityScore {
            onHealthDegradation?(uuid, health)
        }
    }

    private func determineHealthStatus(stabilityScore: Double, responseTime: TimeInterval) -> ConnectionHealth.HealthStatus {
        if stabilityScore >= 0.9 && responseTime < 2.0 {
            return .excellent
        } else if stabilityScore >= 0.8 && responseTime < 5.0 {
            return .good
        } else if stabilityScore >= 0.6 && responseTime < 8.0 {
            return .fair
        } else if stabilityScore >= 0.4 && responseTime < 12.0 {
            return .poor
        } else {
            return .critical
        }
    }

    private func reportPerformanceMetrics(for uuid: UUID) {
        guard let metrics = performanceMetrics[uuid] else { return }
        onPerformanceReport?(uuid, metrics)
    }

    // MARK: - Enhanced Performance Monitoring

    /// Get comprehensive performance report for a device
    func getComprehensiveReport(for uuid: UUID) -> ComprehensivePerformanceReport? {
        guard let performance = performanceMetrics[uuid],
              let health = connectionHealth[uuid],
              let stability = connectionStability[uuid] else {
            return nil
        }

        return ComprehensivePerformanceReport(
            deviceId: uuid,
            performance: performance,
            health: health,
            stability: stability,
            timestamp: Date()
        )
    }

    /// Check if device performance is degrading
    func isPerformanceDegrading(for uuid: UUID) -> Bool {
        guard let health = connectionHealth[uuid] else { return false }
        return health.stabilityScore < healthDegradationThreshold
    }

    /// Get performance trend for a device
    func getPerformanceTrend(for uuid: UUID) -> PerformanceTrend {
        guard let performance = performanceMetrics[uuid] else { return .unknown }

        // Simple trend analysis based on recent performance
        if performance.successRate >= 0.9 && performance.averageResponseTime < 2.0 {
            return .excellent
        } else if performance.successRate >= 0.8 && performance.averageResponseTime < 5.0 {
            return .good
        } else if performance.successRate >= 0.6 && performance.averageResponseTime < 8.0 {
            return .fair
        } else if performance.successRate >= 0.4 {
            return .poor
        } else {
            return .critical
        }
    }

    /// Optimize performance for a device
    func optimizePerformance(for uuid: UUID) -> PerformanceOptimization {
        guard let performance = performanceMetrics[uuid],
              let health = connectionHealth[uuid] else {
            return .none
        }

        var optimizations: [PerformanceOptimization] = []

        // Check response time
        if performance.averageResponseTime > 5.0 {
            optimizations.append(.reduceCommandFrequency)
        }

        // Check success rate
        if performance.successRate < 0.8 {
            optimizations.append(.increaseRetryAttempts)
        }

        // Check stability
        if health.stabilityScore < 0.7 {
            optimizations.append(.implementBackoff)
        }

        // Check connection count
        if let stability = connectionStability[uuid], stability.totalConnections > 10 {
            optimizations.append(.reduceConnectionAttempts)
        }

        return optimizations.first ?? .none
    }

    /// Reset performance metrics for a device
    func resetPerformanceMetrics(for uuid: UUID) {
        performanceMetrics.removeValue(forKey: uuid)
        connectionHealth.removeValue(forKey: uuid)
        connectionStability.removeValue(forKey: uuid)
        commandStartTimes.removeValue(forKey: uuid)

        ErrorHandler.debug("Reset performance metrics for device \(uuid)")
    }
}

// MARK: - Enhanced Performance Types

struct ComprehensivePerformanceReport {
    let deviceId: UUID
    let performance: BLEPerformanceMonitor.PerformanceMetrics
    let health: BLEPerformanceMonitor.ConnectionHealth
    let stability: BLEPerformanceMonitor.ConnectionStability
    let timestamp: Date

    var overallScore: Double {
        let performanceScore = performance.successRate
        let healthScore = health.stabilityScore
        let stabilityScore = stability.stabilityScore

        return (performanceScore + healthScore + stabilityScore) / 3.0
    }

    var recommendations: [String] {
        var recommendations: [String] = []

        if performance.successRate < 0.8 {
            recommendations.append("Consider increasing retry attempts for commands")
        }

        if performance.averageResponseTime > 5.0 {
            recommendations.append("Reduce command frequency to improve response times")
        }

        if health.stabilityScore < 0.7 {
            recommendations.append("Implement connection backoff strategy")
        }

        if stability.totalConnections > 10 {
            recommendations.append("Reduce connection attempts to improve stability")
        }

        return recommendations
    }
}

enum PerformanceTrend {
    case excellent
    case good
    case fair
    case poor
    case critical
    case unknown

    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        case .unknown: return "gray"
        }
    }
}

enum PerformanceOptimization {
    case none
    case reduceCommandFrequency
    case increaseRetryAttempts
    case implementBackoff
    case reduceConnectionAttempts
    case optimizeQueueSize
    case adjustTimeout

    var description: String {
        switch self {
        case .none: return "No optimization needed"
        case .reduceCommandFrequency: return "Reduce command frequency"
        case .increaseRetryAttempts: return "Increase retry attempts"
        case .implementBackoff: return "Implement exponential backoff"
        case .reduceConnectionAttempts: return "Reduce connection attempts"
        case .optimizeQueueSize: return "Optimize command queue size"
        case .adjustTimeout: return "Adjust command timeout"
        }
    }
}
