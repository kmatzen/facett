import Foundation
import CoreBluetooth

// MARK: - BLE Connection Handler
class BLEConnectionHandler {
    private weak var bleManager: BLEManager?

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    // MARK: - Connection Management

    func handleConnectionSuccess(_ peripheral: CBPeripheral) {
        guard let bleManager = bleManager else { return }

        let uuid = peripheral.identifier
        let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)

        ErrorHandler.info("Connected to \(cameraName)")

        guard let gopro = bleManager.connectingGoPros[uuid] else {
            return
        }

        // Note: Camera name will be stored when we receive the apSSID (serial number)
        // in BLEResponseHandler after the camera connects and sends status

        // Notify connection manager to cancel timeout timers
        bleManager.connectionManager.handleConnectionSuccess(uuid)

        // Clear retry status on successful connection on main thread
        DispatchQueue.main.async {
            bleManager.connectionRetryStatus.removeValue(forKey: uuid)
        }

        // UI updates must happen on main thread
        DispatchQueue.main.async {
            bleManager.connectedGoPros[uuid] = gopro // Move to connected list
            bleManager.connectingGoPros.removeValue(forKey: uuid) // Remove from connecting list
            bleManager.discoveredGoPros.removeValue(forKey: uuid) // Remove from discovered list

            // Reset initialization flag for new connection
            gopro.hasReceivedInitialStatus = false

            // Notify that camera is connected
            bleManager.onCameraConnected?(uuid)
        }

        gopro.peripheral.delegate = bleManager
        gopro.peripheral.discoverServices([BLEManager.Constants.UUIDs.goproService, BLEManager.Constants.UUIDs.goproWiFiService])
    }

    func handleDisconnection(_ peripheral: CBPeripheral, error: Error?) {
        guard let bleManager = bleManager else { return }

        let uuid = peripheral.identifier
        let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)
        ErrorHandler.info("\(cameraName) disconnected.")

        bleManager.connectionManager.cancelConnectionRetry(for: uuid)
        bleManager.cleanupDeviceState(for: uuid)

        DispatchQueue.main.async {
            let isSleeping = bleManager.isDeviceSleeping(uuid)
            let wasConnected = bleManager.connectedGoPros[uuid] != nil

            if let gopro = bleManager.connectedGoPros[uuid] {
                bleManager.connectedGoPros.removeValue(forKey: uuid)
                if !isSleeping {
                    bleManager.discoveredGoPros[uuid] = gopro
                } else {
                    ErrorHandler.debug("\(cameraName) is sleeping - not moving to discovered list")
                }
            } else if let gopro = bleManager.connectingGoPros[uuid] {
                bleManager.connectingGoPros.removeValue(forKey: uuid)
                if !isSleeping {
                    bleManager.discoveredGoPros[uuid] = gopro
                } else {
                    ErrorHandler.debug("\(cameraName) is sleeping - not moving to discovered list")
                }
            }

            if wasConnected && !isSleeping {
                bleManager.scheduleReconnectIfNeeded(for: uuid)
            }
        }
    }

    // MARK: - Service Discovery

    func handleServiceDiscovery(_ peripheral: CBPeripheral, error: Error?) {
        guard bleManager != nil else { return }

        let uuid = peripheral.identifier

        if let error = error {
            ErrorHandler.error("Error discovering services for \(CameraIdentityManager.shared.getDisplayName(for: uuid)): \(error.localizedDescription)")
            return
        }

        // Ensure services exist
        guard let services = peripheral.services else {
            ErrorHandler.error("No services found for \(peripheral.name ?? "a device")")
            return
        }

        // Iterate through discovered services
        for service in services {
            if service.uuid == BLEManager.Constants.UUIDs.goproService {
                ErrorHandler.debug("Discovered GoPro service for \(peripheral.name ?? "a device")")

                // Discover characteristics for the GoPro service
                peripheral.discoverCharacteristics(
                    [
                        BLEManager.Constants.UUIDs.query,
                        BLEManager.Constants.UUIDs.queryResponse,
                        BLEManager.Constants.UUIDs.command,
                        BLEManager.Constants.UUIDs.commandResponse,
                        BLEManager.Constants.UUIDs.settings,
                        BLEManager.Constants.UUIDs.settingsResponse
                    ],
                    for: service
                )
            } else if service.uuid == BLEManager.Constants.UUIDs.goproWiFiService {
                ErrorHandler.debug("Discovered GoPro WiFi Access Point service for \(peripheral.name ?? "a device")")

                // Discover characteristics for the GoPro WiFi service
                peripheral.discoverCharacteristics(
                    [
                        BLEManager.Constants.UUIDs.wifiAPSSID,
                        BLEManager.Constants.UUIDs.wifiAPPassword,
                        BLEManager.Constants.UUIDs.wifiAPPower,
                        BLEManager.Constants.UUIDs.wifiAPState
                    ],
                    for: service
                )
            }
        }
    }

    // MARK: - Characteristic Discovery

    func handleCharacteristicDiscovery(_ peripheral: CBPeripheral, service: CBService, error: Error?) {
        guard let bleManager = bleManager else { return }

        let uuid = peripheral.identifier

        if let error = error {
            ErrorHandler.error("Error discovering characteristics for \(CameraIdentityManager.shared.getDisplayName(for: uuid)): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            ErrorHandler.error("No characteristics found for service \(service.uuid)")
            return
        }

        let deviceName = peripheral.name ?? "a device"
        var discoveredNames: [String] = []

        for characteristic in characteristics {
            switch characteristic.uuid {
            case BLEManager.Constants.UUIDs.query:
                discoveredNames.append("Query")

            case BLEManager.Constants.UUIDs.queryResponse:
                discoveredNames.append("Query Response")
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }

            case BLEManager.Constants.UUIDs.command:
                discoveredNames.append("Command")

            case BLEManager.Constants.UUIDs.commandResponse:
                discoveredNames.append("Command Response")
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }

            case BLEManager.Constants.UUIDs.settings:
                discoveredNames.append("Settings")

            case BLEManager.Constants.UUIDs.settingsResponse:
                discoveredNames.append("Settings Response")
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }

            case BLEManager.Constants.UUIDs.wifiAPSSID:
                discoveredNames.append("WiFi SSID")
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }

            case BLEManager.Constants.UUIDs.wifiAPPassword:
                discoveredNames.append("WiFi Password")
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }

            case BLEManager.Constants.UUIDs.wifiAPPower:
                discoveredNames.append("WiFi Power")

            case BLEManager.Constants.UUIDs.wifiAPState:
                discoveredNames.append("WiFi State")
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
                if characteristic.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }

            default:
                ErrorHandler.debug("Unknown characteristic \(characteristic.uuid) for \(deviceName)")
            }
        }

        if !discoveredNames.isEmpty {
            ErrorHandler.debug("Configured \(discoveredNames.count) characteristics for \(deviceName): \(discoveredNames.joined(separator: ", "))")
        }

        bleManager.claimControl(for: peripheral.identifier)
    }
}
