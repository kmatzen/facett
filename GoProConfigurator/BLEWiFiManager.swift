import Foundation
import CoreBluetooth

/// Manages WiFi-related BLE operations for GoPro cameras
class BLEWiFiManager {
    private let errorHandler = ErrorHandler.shared

    // MARK: - WiFi Configuration Commands

    func getWiFiConfig(for uuid: UUID, commandSender: @escaping ([UInt8], UUID, String) -> Void) {
        commandSender(GoProCommands.Status.getWiFiConfig, uuid, "get WiFi config")
    }

    // MARK: - WiFi Characteristic Handlers

    func handleWiFiSSIDResponse(_ data: Data, for peripheral: CBPeripheral, statusUpdater: @escaping (UUID, String) -> Void) {
        // Parse the SSID as a string
        if let ssid = String(data: data, encoding: .utf8) {
            let cleanSSID = ssid.replacingOccurrences(of: "\0", with: "")

            DispatchQueue.main.async {
                statusUpdater(peripheral.identifier, cleanSSID)
            }

            ErrorHandler.debug("WiFi SSID received: \(cleanSSID)")
        } else {
            ErrorHandler.warning("Failed to parse WiFi SSID from data")
        }
    }

    func handleWiFiPasswordResponse(_ data: Data, for peripheral: CBPeripheral, statusUpdater: @escaping (UUID, String) -> Void) {
        // Parse the password as a string
        if let password = String(data: data, encoding: .utf8) {
            let cleanPassword = password.replacingOccurrences(of: "\0", with: "")

            DispatchQueue.main.async {
                statusUpdater(peripheral.identifier, cleanPassword)
            }

            ErrorHandler.debug("WiFi password received")
        } else {
            ErrorHandler.warning("Failed to parse WiFi password from data")
        }
    }

    func handleWiFiStateResponse(_ data: Data, for peripheral: CBPeripheral, statusUpdater: @escaping (UUID, Int) -> Void) {
        // Parse the state as an integer
        if data.count >= 1 {
            let state = Int(data[0])

            DispatchQueue.main.async {
                statusUpdater(peripheral.identifier, state)
            }

            ErrorHandler.debug("WiFi state received: \(state)")
        } else {
            ErrorHandler.warning("Failed to parse WiFi state from data")
        }
    }

    // MARK: - WiFi Status Updates

    func updateWiFiSSID(for uuid: UUID, ssid: String, gopro: GoPro) {
        gopro.status.wifiSSID = ssid
        gopro.status.apSSID = ssid // Also update AP SSID
    }

    func updateWiFiPassword(for uuid: UUID, password: String, gopro: GoPro) {
        gopro.status.wifiPassword = password
        gopro.status.apPassword = password // Also update AP password
    }

    func updateWiFiState(for uuid: UUID, state: Int, gopro: GoPro) {
        gopro.status.apState = state
    }

    // MARK: - WiFi Configuration Validation

    func validateWiFiConfiguration(for gopro: GoPro) -> Bool {
        // Check if we have valid WiFi configuration
        let hasSSID = !(gopro.status.wifiSSID?.isEmpty ?? true)
        let hasPassword = !(gopro.status.wifiPassword?.isEmpty ?? true)
        let hasValidState = gopro.status.apState != nil

        return hasSSID && hasPassword && hasValidState
    }

    // MARK: - WiFi Status Description

    func getWiFiStatusDescription(for gopro: GoPro) -> String {
        guard let state = gopro.status.apState else {
            return "Unknown"
        }

        switch state {
        case 0:
            return "Disabled"
        case 1:
            return "Enabled"
        case 2:
            return "Starting"
        case 3:
            return "Stopping"
        default:
            return "Unknown (\(state))"
        }
    }

    // MARK: - WiFi Connection Helpers

    func canConnectToWiFi(for gopro: GoPro) -> Bool {
        return validateWiFiConfiguration(for: gopro) && gopro.status.apState == 1
    }

    func getWiFiConnectionInfo(for gopro: GoPro) -> (ssid: String?, password: String?, state: String) {
        return (
            ssid: gopro.status.wifiSSID,
            password: gopro.status.wifiPassword,
            state: getWiFiStatusDescription(for: gopro)
        )
    }
}
