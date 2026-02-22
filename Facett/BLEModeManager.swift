import Foundation
import Combine
import CoreBluetooth

/// Manages camera mode operations for GoPro cameras
class BLEModeManager {

    // MARK: - Dependencies
    private weak var bleManager: BLEManager?

    private let modeSwitchTimeout: TimeInterval = 5.0
    private var pendingModeSwitches: [UUID: AnyCancellable] = [:]

    // MARK: - Initialization
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    // MARK: - Mode Operations

    /// Get the current camera mode
    func getCameraMode(_ gopro: GoPro) -> CameraMode {
        // Check the mode field from camera settings
        let modeValue = gopro.settings.mode
        let cameraMode: CameraMode

        switch modeValue {
        case 12: cameraMode = .video
        case 17: cameraMode = .photo
        case 19: cameraMode = .multishot  // Burst Photo
        case 15: cameraMode = .looping
        case 18: cameraMode = .nightPhoto
        case 13: cameraMode = .timeLapseVideo
        case 20: cameraMode = .timeLapsePhoto
        case 21: cameraMode = .nightLapsePhoto
        case 24: cameraMode = .timeWarpVideo
        case 25: cameraMode = .liveBurst
        case 26: cameraMode = .nightLapseVideo
        case 27: cameraMode = .sloMo
        default: cameraMode = .unknown
        }

        return cameraMode
    }

    /// Switch camera to a specific mode
    func switchToMode(_ mode: CameraMode, for uuid: UUID, completion: @escaping (Bool) -> Void) {
        guard let bleManager = bleManager else {
            completion(false)
            return
        }

        guard let gopro = bleManager.connectedGoPros[uuid] else {
            bleManager.log("❌ Cannot switch mode - camera not found: \(uuid)")
            completion(false)
            return
        }

        let modeName = mode.description
        bleManager.log("🔄 Switching \(gopro.peripheral.name ?? "camera") to \(modeName) mode")

        if let gopro = bleManager.connectedGoPros[uuid] {
            let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: gopro.name)
            ErrorHandler.info(
                "Switch to \(modeName) Mode for \(cameraName)",
                context: [
                    "camera_id": uuid.uuidString,
                    "mode": modeName
                ]
            )
        }

        bleManager.sendCommand([3, 144, 1, UInt8(mode.rawValue)],
                    to: uuid,
                    commandName: "switch to \(modeName.lowercased()) mode",
                    requiresControl: true)

        awaitModeChange(uuid: uuid, expectedMode: mode, modeName: modeName, completion: completion)
    }

    /// Subscribe to status updates and complete as soon as the mode matches.
    /// Falls back to timeout after modeSwitchTimeout seconds.
    private func awaitModeChange(uuid: UUID, expectedMode: CameraMode, modeName: String, completion: @escaping (Bool) -> Void) {
        guard let bleManager = bleManager else {
            completion(false)
            return
        }

        // Cancel any existing subscription for this camera
        pendingModeSwitches[uuid]?.cancel()

        var completed = false
        let startTime = Date()

        let subscription = bleManager.$connectedGoPros
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cameras in
                guard !completed, let self = self else { return }

                guard let gopro = cameras[uuid] else {
                    completed = true
                    self.pendingModeSwitches.removeValue(forKey: uuid)
                    completion(false)
                    return
                }

                if self.getCameraMode(gopro) == expectedMode {
                    completed = true
                    self.pendingModeSwitches.removeValue(forKey: uuid)
                    let elapsed = Date().timeIntervalSince(startTime)
                    bleManager.log("✅ Successfully switched to \(modeName) mode in \(String(format: "%.1f", elapsed))s")
                    completion(true)
                }
            }

        pendingModeSwitches[uuid] = subscription

        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + modeSwitchTimeout) { [weak self] in
            guard !completed, let self = self else { return }
            completed = true
            self.pendingModeSwitches[uuid]?.cancel()
            self.pendingModeSwitches.removeValue(forKey: uuid)

            if let gopro = bleManager.connectedGoPros[uuid] {
                let currentMode = self.getCameraMode(gopro)
                bleManager.log("❌ Failed to switch to \(modeName) mode after \(String(format: "%.1f", self.modeSwitchTimeout))s (current: \(currentMode.description))")
            }
            completion(false)
        }
    }

    /// Switch camera to video mode (convenience method)
    func switchToVideoMode(for uuid: UUID, completion: @escaping (Bool) -> Void) {
        switchToMode(.video, for: uuid, completion: completion)
    }

    /// Switch camera to photo mode (convenience method)
    func switchToPhotoMode(for uuid: UUID, completion: @escaping (Bool) -> Void) {
        switchToMode(.photo, for: uuid, completion: completion)
    }

    /// Switch camera to multishot mode (convenience method)
    func switchToMultishotMode(for uuid: UUID, completion: @escaping (Bool) -> Void) {
        switchToMode(.multishot, for: uuid, completion: completion)
    }

    /// Switch all connected cameras to a specific mode
    func switchAllCamerasToMode(_ mode: CameraMode, completion: @escaping ([UUID: Bool]) -> Void) {
        guard let bleManager = bleManager else {
            completion([:])
            return
        }

        let cameraIds = Array(bleManager.connectedGoPros.keys)
        var results: [UUID: Bool] = [:]
        let group = DispatchGroup()

        for uuid in cameraIds {
            group.enter()
            switchToMode(mode, for: uuid) { success in
                results[uuid] = success
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }

    /// Check if all cameras are in the same mode
    func areAllCamerasInMode(_ mode: CameraMode) -> Bool {
        guard let bleManager = bleManager else { return false }

        return bleManager.connectedGoPros.values.allSatisfy { gopro in
            getCameraMode(gopro) == mode
        }
    }

    /// Get cameras that are not in the specified mode
    func getCamerasNotInMode(_ mode: CameraMode) -> [GoPro] {
        guard let bleManager = bleManager else { return [] }

        return bleManager.connectedGoPros.values.filter { gopro in
            getCameraMode(gopro) != mode
        }
    }

    /// Get mode mismatch information for UI display
    func getModeMismatchInfo() -> (mismatchedCameras: [GoPro], targetMode: CameraMode) {
        guard bleManager != nil else { return ([], .unknown) }

        // For recording operations, we want all cameras in video mode
        let targetMode: CameraMode = .video
        let mismatchedCameras = getCamerasNotInMode(targetMode)

        return (mismatchedCameras, targetMode)
    }

    // MARK: - Helper Methods

    /// Helper function to describe mode values
    func modeDescription(_ mode: Int) -> String {
        return CameraMode.fromInt(mode).description
    }

    /// Get a human-readable description of the current mode for a camera
    func getCurrentModeDescription(for uuid: UUID) -> String {
        guard let bleManager = bleManager,
              let gopro = bleManager.connectedGoPros[uuid] else {
            return "Unknown"
        }

        return getCameraMode(gopro).description
    }
}
