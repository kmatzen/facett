import Foundation
import os.log
import CoreBluetooth

// MARK: - Standardized Error Handling System

/// Centralized error handling and logging system
class ErrorHandler {
    static let shared = ErrorHandler()

    private let logger = Logger(subsystem: "com.matzen.facett", category: "ErrorHandler")

    private init() {}

    // MARK: - Error Logging

    /// Log an error with full context and automatic crash reporting
    func logError(
        _ message: String,
        error: Error? = nil,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let fullMessage = "[\(fileName):\(line)] \(function): \(message)"

        // Log to system logger
        logger.error("\(fullMessage)")

        // Log to crash reporter for tracking
        CrashReporter.shared.logError(
            message,
            error: error,
            context: context.merging([
                "file": fileName,
                "function": function,
                "line": String(line)
            ]) { _, new in new }
        )

        // Print to console in debug builds
        #if DEBUG
        print("❌ ERROR: \(fullMessage)")
        if let error = error {
            print("   Error: \(error.localizedDescription)")
        }
        if !context.isEmpty {
            let contextStr = context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            print("   Context: \(contextStr)")
        }
        #endif
    }

    /// Log a warning with context
    func logWarning(
        _ message: String,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let fullMessage = "[\(fileName):\(line)] \(function): \(message)"

        // Log to system logger
        logger.warning("\(fullMessage)")

        // Log to crash reporter for tracking
        CrashReporter.shared.logWarning(
            message,
            context: context.merging([
                "file": fileName,
                "function": function,
                "line": String(line)
            ]) { _, new in new }
        )

        // Print to console in debug builds
        #if DEBUG
        print("⚠️ WARNING: \(fullMessage)")
        if !context.isEmpty {
            let contextStr = context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            print("   Context: \(contextStr)")
        }
        #endif
    }

    /// Log informational message
    func logInfo(
        _ message: String,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let fullMessage = "[\(fileName):\(line)] \(function): \(message)"

        // Log to system logger
        logger.info("\(fullMessage)")

        // Print to console in debug builds
        #if DEBUG
        print("ℹ️ INFO: \(fullMessage)")
        if !context.isEmpty {
            let contextStr = context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            print("   Context: \(contextStr)")
        }
        #endif
    }

    /// Log debug message (only in debug builds)
    func logDebug(
        _ message: String,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let fullMessage = "[\(fileName):\(line)] \(function): \(message)"

        // Log to system logger
        logger.debug("\(fullMessage)")

        // Print to console
        print("🔍 DEBUG: \(fullMessage)")
        if !context.isEmpty {
            let contextStr = context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            print("   Context: \(contextStr)")
        }
        #endif
    }

    // MARK: - Specialized Logging

    /// Log BLE-specific errors with enhanced context
    func logBLEError(
        _ message: String,
        peripheral: CBPeripheral? = nil,
        characteristic: CBCharacteristic? = nil,
        error: Error? = nil,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var bleContext = context

        if let peripheral = peripheral {
            bleContext["peripheral_name"] = peripheral.name ?? "Unknown"
            bleContext["peripheral_id"] = peripheral.identifier.uuidString
            bleContext["peripheral_state"] = peripheralStateString(peripheral.state)
        }

        if let characteristic = characteristic {
            bleContext["characteristic_uuid"] = characteristic.uuid.uuidString
            bleContext["characteristic_properties"] = characteristicPropertiesString(characteristic.properties)
        }

        if let error = error {
            bleContext["error_description"] = error.localizedDescription
            if let nsError = error as NSError? {
                bleContext["error_domain"] = nsError.domain
                bleContext["error_code"] = String(nsError.code)
            }
        }

        logError("🔵 BLE: \(message)", error: error, context: bleContext, file: file, function: function, line: line)
    }

    /// Log camera-specific errors with enhanced context
    func logCameraError(
        _ message: String,
        camera: GoPro? = nil,
        error: Error? = nil,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var cameraContext = context

        if let camera = camera {
            cameraContext["camera_name"] = camera.name ?? "Unknown"
            cameraContext["camera_id"] = camera.id.uuidString
            cameraContext["has_control"] = String(camera.hasControl)
            cameraContext["battery_level"] = camera.status.batteryLevel.map { String($0) } ?? "Unknown"
            cameraContext["is_connected"] = String(camera.peripheral.state == .connected)
        }

        logError("📷 Camera: \(message)", error: error, context: cameraContext, file: file, function: function, line: line)
    }

    // MARK: - Error Recovery

    /// Execute operation with automatic error recovery and logging
    func executeWithRecovery<T>(
        operation: String,
        maxAttempts: Int = 3,
        delay: TimeInterval = 2.0,
        context: [String: Any] = [:],
        block: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = delay

        for attempt in 1...maxAttempts {
            do {
                let result = try await block()

                if attempt > 1 {
                    logInfo("✅ Operation '\(operation)' succeeded on attempt \(attempt)", context: context)
                }

                return result
            } catch {
                lastError = error

                if attempt < maxAttempts {
                    logWarning("🔄 Operation '\(operation)' failed (attempt \(attempt)/\(maxAttempts)), retrying in \(String(format: "%.1f", currentDelay))s...",
                              context: context.merging(["error": error.localizedDescription, "attempt": String(attempt)]) { _, new in new })

                    // Wait before retry with exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay = min(currentDelay * 1.5, 30.0) // Cap at 30 seconds
                } else {
                    logError("❌ Operation '\(operation)' failed after \(maxAttempts) attempts",
                            error: error, context: context.merging(["final_attempt": "true"]) { _, new in new })
                }
            }
        }

        throw lastError ?? NSError(domain: "ErrorHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }

    /// Execute BLE operation with specialized error handling
    func executeBLEOperation<T>(
        operation: String,
        peripheral: CBPeripheral? = nil,
        maxAttempts: Int = 3,
        context: [String: Any] = [:],
        block: @escaping () async throws -> T
    ) async throws -> T {
        var bleContext = context

        if let peripheral = peripheral {
            bleContext["peripheral_name"] = peripheral.name ?? "Unknown"
            bleContext["peripheral_id"] = peripheral.identifier.uuidString
            bleContext["peripheral_state"] = peripheralStateString(peripheral.state)
        }

        return try await executeWithRecovery(
            operation: "BLE: \(operation)",
            maxAttempts: maxAttempts,
            delay: 1.0, // Shorter delay for BLE operations
            context: bleContext,
            block: block
        )
    }

    /// Execute operation with graceful degradation
    func executeWithFallback<T>(
        operation: String,
        fallback: T,
        context: [String: Any] = [:],
        block: @escaping () async throws -> T
    ) async -> T {
        do {
            let result = try await block()
            logInfo("✅ Operation '\(operation)' succeeded", context: context)
            return result
        } catch {
            logWarning("⚠️ Operation '\(operation)' failed, using fallback",
                      context: context.merging(["error": error.localizedDescription, "fallback_used": "true"]) { _, new in new })
            return fallback
        }
    }

    // MARK: - Helper Functions

    private func peripheralStateString(_ state: CBPeripheralState) -> String {
        switch state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting"
        @unknown default: return "Unknown"
        }
    }

    private func characteristicPropertiesString(_ properties: CBCharacteristicProperties) -> String {
        var props: [String] = []
        if properties.contains(.read) { props.append("Read") }
        if properties.contains(.write) { props.append("Write") }
        if properties.contains(.writeWithoutResponse) { props.append("WriteWithoutResponse") }
        if properties.contains(.notify) { props.append("Notify") }
        if properties.contains(.indicate) { props.append("Indicate") }
        return props.joined(separator: ", ")
    }
}

// MARK: - Convenience Extensions

extension ErrorHandler {
    /// Quick error logging for common patterns
    static func error(_ message: String, error: Error? = nil, context: [String: Any] = [:]) {
        shared.logError(message, error: error, context: context)
    }

    static func warning(_ message: String, context: [String: Any] = [:]) {
        shared.logWarning(message, context: context)
    }

    static func info(_ message: String, context: [String: Any] = [:]) {
        shared.logInfo(message, context: context)
    }

    static func debug(_ message: String, context: [String: Any] = [:]) {
        shared.logDebug(message, context: context)
    }

    static func bleError(_ message: String, peripheral: CBPeripheral? = nil, error: Error? = nil, context: [String: Any] = [:]) {
        shared.logBLEError(message, peripheral: peripheral, error: error, context: context)
    }

    static func cameraError(_ message: String, camera: GoPro? = nil, error: Error? = nil, context: [String: Any] = [:]) {
        shared.logCameraError(message, camera: camera, error: error, context: context)
    }

    static func executeBLEOperation<T>(
        _ operation: String,
        peripheral: CBPeripheral? = nil,
        maxAttempts: Int = 3,
        context: [String: Any] = [:],
        block: @escaping () async throws -> T
    ) async throws -> T {
        return try await shared.executeBLEOperation(
            operation: operation,
            peripheral: peripheral,
            maxAttempts: maxAttempts,
            context: context,
            block: block
        )
    }
}

// MARK: - BLE Error Recovery Strategies

extension ErrorHandler {

    /// Handle BLE connection errors with recovery strategies
    func handleBLEConnectionError(_ error: Error, peripheral: CBPeripheral, context: [String: Any] = [:]) {
        logBLEError("Connection error occurred", peripheral: peripheral, error: error, context: context)

        // Implement recovery strategies based on error type
        if let nsError = error as NSError? {
            switch nsError.code {
            case 7: // Connection timeout
                logInfo("🔄 Connection timeout detected, implementing recovery strategy", context: context)
                // Could trigger reconnection logic here

            case 6: // Connection failed
                logInfo("🔄 Connection failed, implementing recovery strategy", context: context)
                // Could trigger device reset or different connection approach

            case 10: // Peripheral disconnected
                logInfo("🔄 Peripheral disconnected, implementing recovery strategy", context: context)
                // Could trigger reconnection with backoff

            default:
                logWarning("⚠️ Unhandled BLE connection error code: \(nsError.code)", context: context)
            }
        }
    }

    /// Handle BLE command errors with recovery strategies
    func handleBLECommandError(_ error: Error, peripheral: CBPeripheral, command: String, context: [String: Any] = [:]) {
        logBLEError("Command error occurred", peripheral: peripheral, error: error, context: context.merging(["command": command]) { _, new in new })

        // Implement recovery strategies based on error type
        if let nsError = error as NSError? {
            switch nsError.code {
            case 5: // Authentication insufficient
                logInfo("🔐 Authentication error, may need to re-establish control", context: context)
                // Could trigger control reclamation

            case 3: // Attribute not found
                logInfo("🔍 Attribute not found, may need to rediscover services", context: context)
                // Could trigger service rediscovery

            case 2: // Read not permitted
                logInfo("🚫 Read not permitted, may need to check permissions", context: context)
                // Could trigger permission check

            default:
                logWarning("⚠️ Unhandled BLE command error code: \(nsError.code)", context: context)
            }
        }
    }

    /// Get recovery strategy for BLE error
    func getBLERecoveryStrategy(for error: Error) -> BLERecoveryStrategy {
        if let nsError = error as NSError? {
            switch nsError.code {
            case 7: // Connection timeout
                return .reconnectWithBackoff
            case 6: // Connection failed
                return .resetAndRetry
            case 10: // Peripheral disconnected
                return .reconnect
            case 5: // Authentication insufficient
                return .reclaimControl
            case 3: // Attribute not found
                return .rediscoverServices
            case 2: // Read not permitted
                return .checkPermissions
            default:
                return .none
            }
        }
        return .none
    }
}

// MARK: - BLE Recovery Strategies

enum BLERecoveryStrategy {
    case none
    case reconnect
    case reconnectWithBackoff
    case resetAndRetry
    case reclaimControl
    case rediscoverServices
    case checkPermissions

    var description: String {
        switch self {
        case .none: return "No recovery needed"
        case .reconnect: return "Reconnect to device"
        case .reconnectWithBackoff: return "Reconnect with exponential backoff"
        case .resetAndRetry: return "Reset connection and retry"
        case .reclaimControl: return "Reclaim camera control"
        case .rediscoverServices: return "Rediscover BLE services"
        case .checkPermissions: return "Check BLE permissions"
        }
    }
}
