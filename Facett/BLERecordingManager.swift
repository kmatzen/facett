import Foundation
import CoreBluetooth
import UIKit

/// Manages recording operations for GoPro cameras
class BLERecordingManager {

    // MARK: - Dependencies
    private weak var bleManager: BLEManager?
    private weak var modeManager: BLEModeManager?

    // MARK: - Initialization
    init(bleManager: BLEManager, modeManager: BLEModeManager) {
        self.bleManager = bleManager
        self.modeManager = modeManager
    }

    // MARK: - Haptic Feedback
    private func recordingStartedHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()

        // Add a second lighter feedback for better feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let lightFeedback = UIImpactFeedbackGenerator(style: .light)
            lightFeedback.impactOccurred()
        }
    }

    private func recordingStoppedHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }

    // MARK: - Recording Operations

    /// Start recording for a specific camera
    func startRecording(for uuid: UUID) {
        guard let bleManager = bleManager else { return }
        guard let gopro = bleManager.connectedGoPros[uuid] else {
            bleManager.log("❌ Cannot start recording - camera not found: \(uuid)")
            return
        }

        bleManager.log("🎬 Starting recording for \(gopro.peripheral.name ?? "camera")")

        // Check camera mode before sending recording command
        let currentMode = modeManager?.getCameraMode(gopro) ?? .unknown

        bleManager.log("📹 Current mode: \(currentMode.description)")

        // If camera is not in video mode, switch it first
        if currentMode != .video {
            bleManager.log("🔄 Switching to video mode first")

            // Switch to video mode first
            modeManager?.switchToVideoMode(for: uuid) { [weak self] success in
                if success {
                    self?.bleManager?.log("✅ Mode switch successful, starting recording")
                    // Now start recording
                    self?.sendRecordingCommand(to: uuid, commandName: "start recording")
                } else {
                    self?.bleManager?.log("❌ Mode switch failed, cannot start recording")
                }
            }
        } else {
            // Camera is already in video mode, start recording directly
            sendRecordingCommand(to: uuid, commandName: "start recording")
        }
    }

    /// Stop recording for a specific camera
    func stopRecording(for uuid: UUID) {
        guard let bleManager = bleManager else { return }
        guard bleManager.connectedGoPros[uuid] != nil else { return }

        // Provide haptic feedback for recording stop
        DispatchQueue.main.async {
            self.recordingStoppedHaptic()
        }

        sendRecordingCommand(to: uuid, commandName: "stop recording")
    }

    /// Start recording for all connected cameras
    func startRecordingAllDevices() {
        guard let bleManager = bleManager else { return }
        let cameraCount = bleManager.connectedGoPros.count
        // Provide haptic feedback and voice notification for all devices recording start
        DispatchQueue.main.async {
            self.recordingStartedHaptic()
            VoiceNotificationManager.shared.notifyRecordingStarted(cameraCount: cameraCount)
        }

        bleManager.connectedGoPros.forEach { _, gopro in
            startRecording(for: gopro.peripheral.identifier)
        }
    }

    /// Stop recording for all connected cameras
    func stopRecordingAllDevices() {
        guard let bleManager = bleManager else { return }
        let cameraCount = bleManager.connectedGoPros.count
        // Provide haptic feedback and voice notification for all devices recording stop
        DispatchQueue.main.async {
            self.recordingStoppedHaptic()
            VoiceNotificationManager.shared.notifyRecordingStopped(cameraCount: cameraCount)
        }

        bleManager.connectedGoPros.forEach { _, gopro in
            stopRecording(for: gopro.peripheral.identifier)
        }
    }

    /// Start recording for cameras in a specific set
    func startRecordingForCamerasInSet(_ cameraIds: Set<UUID>) {
        guard let bleManager = bleManager else { return }
        let cameraCount = cameraIds.count
        // Provide haptic feedback and voice notification for batch recording start
        DispatchQueue.main.async {
            self.recordingStartedHaptic()
            VoiceNotificationManager.shared.notifyRecordingStarted(cameraCount: cameraCount)
        }

        bleManager.connectedGoPros.forEach { uuid, gopro in
            if cameraIds.contains(uuid) {
                startRecording(for: gopro.peripheral.identifier)
            }
        }
    }

    /// Stop recording for cameras in a specific set
    func stopRecordingForCamerasInSet(_ cameraIds: Set<UUID>) {
        guard let bleManager = bleManager else { return }
        let cameraCount = cameraIds.count
        // Provide haptic feedback and voice notification for batch recording stop
        DispatchQueue.main.async {
            self.recordingStoppedHaptic()
            VoiceNotificationManager.shared.notifyRecordingStopped(cameraCount: cameraCount)
        }

        bleManager.connectedGoPros.forEach { uuid, gopro in
            if cameraIds.contains(uuid) {
                stopRecording(for: gopro.peripheral.identifier)
            }
        }
    }

    // MARK: - Private Helper Methods

    /// Send the actual recording command
    private func sendRecordingCommand(to uuid: UUID, commandName: String) {
        guard let bleManager = bleManager else { return }

        bleManager.log("🎥 Sending recording command: \(commandName) to \(uuid)")

        let command: [UInt8] = [3, 1, 1, commandName.contains("start") ? 1 : 0]
        bleManager.log("📤 Recording command bytes: \(command.map { String(format: "0x%02X", $0) }.joined(separator: " "))")

        bleManager.sendCommand(command,
                    to: uuid,
                    commandName: commandName,
                    requiresControl: true,
                    priority: .high)
    }
}
