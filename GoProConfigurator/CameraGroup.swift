import Foundation
import SwiftUI

// MARK: - Camera Group Models
struct CameraGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var cameraSerials: Set<String> // Serial numbers (from apSSID) instead of UUIDs
    var isActive: Bool
    var configId: UUID? // Reference to a CameraConfig

    init(name: String, cameraSerials: Set<String> = [], configId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.cameraSerials = cameraSerials
        self.isActive = false
        self.configId = configId
    }

    /// Helper to get current UUIDs for all cameras in this group
    var cameraIds: Set<UUID> {
        Set(cameraSerials.compactMap { serial in
            CameraSerialNumberManager.shared.getUUID(forSerial: serial)
        })
    }
}

// MARK: - Camera Status
enum CameraStatus: String, CaseIterable {
    case ready = "Ready"
    case error = "Error"
    case settingsMismatch = "Settings Mismatch"
    case modeMismatch = "Wrong Mode"
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case initializing = "Initializing"
    case recording = "Recording"
    case lowBattery = "Low Battery"
    case noSDCard = "No SD Card"
    case overheating = "Overheating"

    var color: Color {
        switch self {
        case .ready:
            return .green
        case .error, .overheating:
            return .red
        case .settingsMismatch:
            return .orange
        case .modeMismatch:
            return .orange
        case .disconnected:
            return .gray
        case .connecting:
            return .blue
        case .initializing:
            return .blue
        case .recording:
            return .purple
        case .lowBattery:
            return .yellow
        case .noSDCard:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .settingsMismatch:
            return "exclamationmark.triangle.fill"
        case .modeMismatch:
            return "camera.rotate.fill"
        case .disconnected:
            return "wifi.slash"
        case .connecting:
            return "wifi"
        case .initializing:
            return "arrow.clockwise"
        case .recording:
            return "record.circle.fill"
        case .lowBattery:
            return "battery.25"
        case .noSDCard:
            return "externaldrive.badge.exclamationmark"
        case .overheating:
            return "thermometer.sun.fill"
        }
    }
}

// MARK: - Group Status
struct GroupStatus {
    let totalCameras: Int
    let readyCameras: Int
    let errorCameras: Int
    let disconnectedCameras: Int
    let recordingCameras: Int
    let connectingCameras: Int
    let initializingCameras: Int

    var overallStatus: CameraStatus {
        if errorCameras > 0 {
            return .error
        } else if recordingCameras > 0 {
            // If any cameras are recording, show recording status
            return .recording
        } else if connectingCameras > 0 {
            // If any cameras are actively connecting, show connecting status
            return .connecting
        } else if initializingCameras > 0 {
            // If any cameras are initializing, show initializing status
            return .initializing
        } else if readyCameras == totalCameras {
            return .ready
        } else if disconnectedCameras == totalCameras {
            return .disconnected
        } else if disconnectedCameras > 0 {
            // If some cameras are disconnected, show settings mismatch
            return .settingsMismatch
        } else {
            return .error // Fallback for unexpected states
        }
    }

    var statusMessage: String {
        if totalCameras == 0 {
            return "No cameras in group"
        }

        var parts: [String] = []
        if readyCameras > 0 {
            parts.append("\(readyCameras) ready")
        }
        if recordingCameras > 0 {
            parts.append("\(recordingCameras) recording")
        }
        if connectingCameras > 0 {
            parts.append("\(connectingCameras) connecting")
        }
        if initializingCameras > 0 {
            parts.append("\(initializingCameras) initializing")
        }
        if errorCameras > 0 {
            parts.append("\(errorCameras) errors")
        }
        if disconnectedCameras > 0 {
            parts.append("\(disconnectedCameras) disconnected")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Camera Group Manager
class CameraGroupManager: ObservableObject {
    @Published var cameraGroups: [CameraGroup] = []
    @Published var activeGroupId: UUID?

    private let userDefaults = UserDefaults.standard
    private let cameraGroupsKey = "CameraGroups"
    private let activeGroupKey = "ActiveGroupId"

    // Reference to ConfigManager
    private let configManager: ConfigManager

    init(configManager: ConfigManager) {
        self.configManager = configManager
        loadCameraGroups()
    }

    // MARK: - Group Management
    func addCameraGroup(name: String) {
        let newGroup = CameraGroup(name: name)
        cameraGroups.append(newGroup)

        // Auto-select the new camera group if no active group exists
        if activeGroupId == nil {
            activeGroupId = newGroup.id
            userDefaults.set(newGroup.id.uuidString, forKey: activeGroupKey)
        }

        saveCameraGroups()
    }

    func removeCameraGroup(_ group: CameraGroup) {
        cameraGroups.removeAll { $0.id == group.id }
        if activeGroupId == group.id {
            activeGroupId = cameraGroups.first?.id
        }
        saveCameraGroups()
    }

    func updateCameraGroup(_ group: CameraGroup) {
        if let index = cameraGroups.firstIndex(where: { $0.id == group.id }) {
            cameraGroups[index] = group
            saveCameraGroups()
        }
    }

    func setActiveGroup(_ group: CameraGroup?) {
        activeGroupId = group?.id
        userDefaults.set(group?.id.uuidString, forKey: activeGroupKey)
    }

    var activeGroup: CameraGroup? {
        cameraGroups.first { $0.id == activeGroupId }
    }

    // MARK: - Camera Management
    func addCameraToGroup(_ cameraSerial: String, group: CameraGroup) {
        var updatedGroup = group
        updatedGroup.cameraSerials.insert(cameraSerial)
        updateCameraGroup(updatedGroup)
    }

    func removeCameraFromGroup(_ cameraSerial: String, group: CameraGroup) {
        var updatedGroup = group
        updatedGroup.cameraSerials.remove(cameraSerial)
        updateCameraGroup(updatedGroup)
    }

    func getCamerasInActiveGroup(from bleManager: BLEManager) -> [UUID: GoPro] {
        guard let activeGroup = activeGroup else { return [:] }

        // Look up which UUIDs correspond to the serial numbers in this group
        return bleManager.connectedGoPros.filter { uuid, gopro in
            guard let serial = gopro.status.apSSID else { return false }
            return activeGroup.cameraSerials.contains(serial)
        }
    }

    func assignConfigToGroup(_ configId: UUID, group: CameraGroup, bleManager: BLEManager) {
        var updatedGroup = group
        updatedGroup.configId = configId
        updateCameraGroup(updatedGroup)

        // Trigger auto-sync if enabled
        configManager.checkAndTriggerAutoSync(bleManager: bleManager, cameraGroupManager: self)
    }

    func getGroupStatus(for group: CameraGroup, bleManager: BLEManager) -> GroupStatus {
        // Find connected cameras that match serial numbers in this group
        let cameras = bleManager.connectedGoPros.filter { uuid, gopro in
            guard let serial = gopro.status.apSSID else { return false }
            return group.cameraSerials.contains(serial)
        }

        let totalCameras = group.cameraSerials.count
        let connectedCameras = cameras.count
        let disconnectedCameras = totalCameras - connectedCameras

        // Count cameras that are actively being connected
        let connectingCameras = bleManager.connectingGoPros.filter { uuid, gopro in
            guard let serial = gopro.status.apSSID else { return false }
            return group.cameraSerials.contains(serial)
        }.count

        var readyCameras = 0
        var errorCameras = 0
        var recordingCameras = 0
        var initializingCameras = 0

        for (_, camera) in cameras {
            let status = getCameraStatus(camera, bleManager: bleManager)
            switch status {
            case .ready:
                readyCameras += 1
            case .error, .overheating, .noSDCard:
                errorCameras += 1
            case .recording:
                recordingCameras += 1
            case .initializing:
                initializingCameras += 1
            default:
                break
            }
        }

        return GroupStatus(
            totalCameras: totalCameras,
            readyCameras: readyCameras,
            errorCameras: errorCameras,
            disconnectedCameras: disconnectedCameras,
            recordingCameras: recordingCameras,
            connectingCameras: connectingCameras,
            initializingCameras: initializingCameras
        )
    }

    func getCameraStatus(_ camera: GoPro, bleManager: BLEManager) -> CameraStatus {
        // If camera hasn't received initial status yet, show initializing
        if !camera.hasReceivedInitialStatus {
            return .initializing
        }

        // Check for critical errors first
        if camera.status.isOverheating == true {
            return .overheating
        }

        if camera.status.sdCardRemaining == nil || camera.status.sdCardRemaining == 0 {
            return .noSDCard
        }

        if let batteryLevel = camera.status.batteryLevel, batteryLevel <= 1 {
            return .lowBattery
        }

        if camera.status.isEncoding == true {
            return .recording
        }

        // Check for mode mismatch first (this is more critical than settings mismatch)
        if hasModeMismatch(camera) {
            return .modeMismatch
        }

        // Check if settings match defaults
        if hasSettingsMismatch(camera, bleManager: bleManager) {
            return .settingsMismatch
        }

        // Check if camera is ready
        if camera.status.isReady == true {
            return .ready
        }

        return .error
    }

    private func hasModeMismatch(_ camera: GoPro) -> Bool {
        // Skip mode mismatch checks for recording cameras to avoid false positives
        if camera.status.isEncoding == true {
            return false
        }

        // Check if camera is in video mode (required for recording)
        // Mode 12 = Video, Mode 17 = Photo, Mode 19 = Multishot (Burst Photo)
        let currentMode = camera.settings.mode
        let isMismatch = currentMode != 12

        return isMismatch
    }

    private func modeDescription(_ mode: Int) -> String {
        return CameraMode.fromInt(mode).description
    }

    private func hasSettingsMismatch(_ camera: GoPro, bleManager: BLEManager) -> Bool {
        // Skip settings mismatch checks for recording cameras to avoid false positives
        if camera.status.isEncoding == true {
            return false
        }

        // Get target settings using centralized logic
        let targetSettings = configManager.getTargetSettings(for: activeGroup)

        // Use the comprehensive settings mismatch check from ConfigValidation
        return ConfigValidation.hasSettingsMismatch(gopro: camera, targetSettings: targetSettings)
    }

    // MARK: - State Transition Handling

    /// Handle camera reconnection after disconnection
    func handleCameraReconnection(_ camera: GoPro) {
        // Reset connection-related state
        camera.hasReceivedInitialStatus = false

        // Trigger status refresh
        // This will be handled by the BLE manager's connection logic
    }

    /// Handle settings sync completion
    func handleSettingsSyncComplete(_ camera: GoPro) {
        // Settings sync is complete, camera should now be ready
        // The status will be updated on the next status check
    }

    /// Handle control loss during recording
    func handleControlLoss(_ camera: GoPro) {
        // Camera lost control, attempt to reclaim
        camera.hasControl = false
        // The BLE manager should handle reclaiming control
    }

    /// Handle battery recovery from low battery
    func handleBatteryRecovery(_ camera: GoPro) {
        // Battery level recovered, update status
        // This will be handled by the next status update
    }

    // MARK: - Persistence
    private func saveCameraGroups() {
        DispatchQueue.global(qos: .utility).async {
            if let encoded = try? JSONEncoder().encode(self.cameraGroups) {
                DispatchQueue.main.async {
                    self.userDefaults.set(encoded, forKey: self.cameraGroupsKey)
                }
            }
        }
    }

    private func loadCameraGroups() {
        DispatchQueue.global(qos: .utility).async {
            if let data = self.userDefaults.data(forKey: self.cameraGroupsKey),
               let decoded = try? JSONDecoder().decode([CameraGroup].self, from: data) {
                DispatchQueue.main.async {
                    self.cameraGroups = decoded
                }
            }

            if let activeGroupString = self.userDefaults.string(forKey: self.activeGroupKey),
               let activeGroupUUID = UUID(uuidString: activeGroupString) {
                DispatchQueue.main.async {
                    self.activeGroupId = activeGroupUUID
                }
            }
        }
    }
}
