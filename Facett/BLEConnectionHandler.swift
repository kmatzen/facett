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
        ErrorHandler.info("\(CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)) disconnected.")

        DispatchQueue.main.async {
            // Check if device was intentionally put to sleep - don't move to discovered list if so
            let isSleeping = bleManager.isDeviceSleeping(uuid)

            if let gopro = bleManager.connectedGoPros[uuid] {
                bleManager.connectedGoPros.removeValue(forKey: uuid)
                if !isSleeping {
                    bleManager.discoveredGoPros[uuid] = gopro // Move back to discovered list only if not sleeping
                } else {
                    ErrorHandler.info("🌙 \(CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)) is sleeping - not moving to discovered list")
                }
            } else if let gopro = bleManager.connectingGoPros[uuid] {
                bleManager.connectingGoPros.removeValue(forKey: uuid)
                if !isSleeping {
                    bleManager.discoveredGoPros[uuid] = gopro // Move back to discovered list only if not sleeping
                } else {
                    ErrorHandler.info("🌙 \(CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: peripheral.name)) is sleeping - not moving to discovered list")
                }
            }
        }
    }

    // MARK: - Service Discovery

    func handleServiceDiscovery(_ peripheral: CBPeripheral, error: Error?) {
        guard let bleManager = bleManager else { return }

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
                ErrorHandler.info("Discovered GoPro service for \(peripheral.name ?? "a device")")

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
                ErrorHandler.info("Discovered GoPro WiFi Access Point service for \(peripheral.name ?? "a device")")

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

        for characteristic in characteristics {
            switch characteristic.uuid {
            case BLEManager.Constants.UUIDs.query:
                ErrorHandler.info("Discovered 'Query' characteristic for \(peripheral.name ?? "a device")")

            case BLEManager.Constants.UUIDs.queryResponse:
                ErrorHandler.info("Discovered 'Query Response' characteristic for \(peripheral.name ?? "a device")")
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic) // Enable notifications
                    ErrorHandler.info("Subscribed to notifications for 'Query Response'")
                }

            case BLEManager.Constants.UUIDs.command:
                ErrorHandler.info("Discovered 'Command' characteristic for \(peripheral.name ?? "a device")")

            case BLEManager.Constants.UUIDs.commandResponse:
                ErrorHandler.info("Discovered 'Command Response' characteristic for \(peripheral.name ?? "a device")")
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic) // Enable notifications
                    ErrorHandler.info("Subscribed to notifications for 'Command Response'")
                }

            case BLEManager.Constants.UUIDs.settings:
                ErrorHandler.info("Discovered 'Settings' characteristic for \(peripheral.name ?? "a device")")

            case BLEManager.Constants.UUIDs.settingsResponse:
                ErrorHandler.info("Discovered 'Settings Response' characteristic for \(peripheral.name ?? "a device")")
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic) // Enable notifications
                    ErrorHandler.info("Subscribed to notifications for 'Settings Response'")
                }

            // GoPro WiFi Access Point characteristics
            case BLEManager.Constants.UUIDs.wifiAPSSID:
                ErrorHandler.info("Discovered 'WiFi AP SSID' characteristic for \(peripheral.name ?? "a device")")
                if characteristic.properties.contains(.read) {
                    // Read the current WiFi SSID
                    peripheral.readValue(for: characteristic)
                    ErrorHandler.info("Reading WiFi AP SSID from \(peripheral.name ?? "a device")")
                }

            case BLEManager.Constants.UUIDs.wifiAPPassword:
                ErrorHandler.info("Discovered 'WiFi AP Password' characteristic for \(peripheral.name ?? "a device")")
                if characteristic.properties.contains(.read) {
                    // Read the current WiFi password
                    peripheral.readValue(for: characteristic)
                    ErrorHandler.info("Reading WiFi AP Password from \(peripheral.name ?? "a device")")
                }

            case BLEManager.Constants.UUIDs.wifiAPPower:
                ErrorHandler.info("Discovered 'WiFi AP Power' characteristic for \(peripheral.name ?? "a device")")

            case BLEManager.Constants.UUIDs.wifiAPState:
                ErrorHandler.info("Discovered 'WiFi AP State' characteristic for \(peripheral.name ?? "a device")")
                if characteristic.properties.contains(.read) {
                    // Read the current WiFi AP state
                    peripheral.readValue(for: characteristic)
                    ErrorHandler.info("Reading WiFi AP State from \(peripheral.name ?? "a device")")
                }
                if characteristic.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: characteristic) // Enable indications
                    ErrorHandler.info("Subscribed to indications for 'WiFi AP State'")
                }

            default:
                ErrorHandler.info("Discovered unknown characteristic \(characteristic.uuid) for \(peripheral.name ?? "a device")")
            }
        }

        bleManager.claimControl(for: peripheral.identifier)
    }
}
