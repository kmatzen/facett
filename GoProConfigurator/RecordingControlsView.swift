import SwiftUI

// MARK: - Recording Controls View
struct RecordingControlsView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var configManager: ConfigManager
    let handleRecordingAction: () -> Void
    @State private var recordingPulse = false
    @State private var isConnectingSet = false
    @State private var syncRotation: Double = 0
    @State private var previouslyAllOnlineAndInSync = false

    private var isAnyCameraRecording: Bool {
        let cameras = cameraGroupManager.activeGroup != nil ?
            cameraGroupManager.activeGroup!.cameraIds.compactMap { bleManager.connectedGoPros[$0] } :
            Array(bleManager.connectedGoPros.values)

        return cameras.contains { $0.status.isEncoding == true }
    }

    private var connectedCameraCount: Int {
        if let activeGroup = cameraGroupManager.activeGroup {
            return activeGroup.cameraIds.filter { bleManager.connectedGoPros[$0] != nil }.count
        } else {
            return bleManager.connectedGoPros.count
        }
    }

    private var totalCamerasInGroup: Int {
        if let activeGroup = cameraGroupManager.activeGroup {
            return activeGroup.cameraIds.count
        } else {
            return bleManager.discoveredGoPros.count
        }
    }

    private var allCamerasOnlineAndInSync: Bool {
        guard let activeGroup = cameraGroupManager.activeGroup else {
            // If no active group, check all connected cameras are in sync
            let targetSettings = configManager.getTargetSettings(for: nil)
            return bleManager.connectedGoPros.values.allSatisfy { gopro in
                // Camera must be ready (not just connected)
                guard gopro.status.isReady == true else {
                    return false
                }

                // If camera is recording, be more lenient with settings checks
                if gopro.status.isEncoding == true {
                    return true // Consider recording cameras as "in sync" to avoid false positives
                }
                return !ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: targetSettings)
            }
        }

        // Check that all cameras in the group are online and in sync
        let targetSettings = configManager.getTargetSettings(for: activeGroup)

        return activeGroup.cameraIds.allSatisfy { cameraId in
            guard let gopro = bleManager.connectedGoPros[cameraId] else {
                return false // Camera is offline
            }

            // Camera must be ready (not just connected)
            guard gopro.status.isReady == true else {
                return false
            }

            // If camera is recording, be more lenient with settings checks
            if gopro.status.isEncoding == true {
                return true // Consider recording cameras as "in sync" to avoid false positives
            }

            // Check if camera is in sync
            return !ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: targetSettings)
        }
    }

    private var recordingCameraCount: Int {
        let cameras = cameraGroupManager.activeGroup != nil ?
            cameraGroupManager.activeGroup!.cameraIds.compactMap { bleManager.connectedGoPros[$0] } :
            Array(bleManager.connectedGoPros.values)

        return cameras.filter { $0.status.isEncoding == true }.count
    }

    private var groupName: String {
        if let activeGroup = cameraGroupManager.activeGroup {
            return activeGroup.name
        } else {
            return "All Cameras"
        }
    }

    private var discoveredCameraCount: Int {
        if let activeGroup = cameraGroupManager.activeGroup {
            return activeGroup.cameraIds.filter { bleManager.discoveredGoPros[$0] != nil }.count
        } else {
            return bleManager.discoveredGoPros.count
        }
    }

    private var groupStatus: GroupStatus? {
        guard let activeGroup = cameraGroupManager.activeGroup else { return nil }
        return cameraGroupManager.getGroupStatus(for: activeGroup, bleManager: bleManager)
    }

    private func hasSettingsMismatchesInGroup(_ cameraGroup: CameraGroup) -> Bool {
        // Check if any connected camera in the group has mismatched settings
        for cameraId in cameraGroup.cameraIds {
            if let gopro = bleManager.connectedGoPros[cameraId] {
                // Skip settings mismatch checks for recording cameras to avoid false positives
                if gopro.status.isEncoding == true {
                    continue
                }

                let targetSettings = configManager.getTargetSettings(for: cameraGroup)
                if ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: targetSettings) {
                    return true
                }
            }
        }
        return false
    }

    private func hasMismatchedSettings(for gopro: GoPro, targetSettings: GoProSettings) -> Bool {
        return ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: targetSettings)
    }

    private var recordingButtonStrokeColor: Color {
        if isAnyCameraRecording {
            return .red
        } else if allCamerasOnlineAndInSync {
            return .green
        } else {
            return .gray
        }
    }

    private var recordingButtonDisabled: Bool {
        return !isAnyCameraRecording && !allCamerasOnlineAndInSync
    }

    private var recordingButtonOpacity: Double {
        return recordingButtonDisabled ? 0.5 : 1.0
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main Recording Controls Row
            HStack(spacing: 16) {
                // Recording Status and Info
                RecordingStatusView(
                    groupName: groupName,
                    isAnyCameraRecording: isAnyCameraRecording,
                    recordingPulse: $recordingPulse,
                    connectedCameraCount: connectedCameraCount,
                    cameraGroupManager: cameraGroupManager,
                    groupStatus: groupStatus
                )

                Spacer()

                // Primary Control Buttons
                HStack(spacing: 12) {
                    // Settings Sync Button (only show if there are mismatches)
                    if let activeGroup = cameraGroupManager.activeGroup,
                       hasSettingsMismatchesInGroup(activeGroup) {
                        Button(action: {
                            bleManager.sendSettingsToCamerasInGroup(activeGroup.cameraSerials, configManager: configManager, cameraGroupManager: cameraGroupManager)
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(syncRotation))
                                .onAppear {
                                    if configManager.autoSyncEnabled && configManager.isAutoSyncing {
                                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                            syncRotation = 360
                                        }
                                    }
                                }
                                .onChange(of: configManager.autoSyncEnabled && configManager.isAutoSyncing) { isSyncing in
                                    if isSyncing {
                                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                            syncRotation = 360
                                        }
                                    } else {
                                        syncRotation = 0
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .background(configManager.autoSyncEnabled && configManager.isAutoSyncing ? Color.blue.opacity(0.8) : Color.blue)
                                .clipShape(Circle())
                        }
                        .disabled(configManager.autoSyncEnabled && configManager.isAutoSyncing)
                        .opacity(configManager.autoSyncEnabled && configManager.isAutoSyncing ? 0.6 : 1.0)
                    }

                    // Voice Control Button
                    Button(action: {
                        speechManager.toggleListening()
                    }) {
                        Image(systemName: speechManager.isListening ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(speechManager.isListening ? Color.blue : Color.gray)
                            .clipShape(Circle())
                    }
                    .scaleEffect(speechManager.isListening ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: speechManager.isListening)

                    // Main Recording Button
                    Button(action: {
                        if isAnyCameraRecording {
                            // Stop recording
                            if let activeGroup = cameraGroupManager.activeGroup {
                                bleManager.stopRecordingForCamerasInSet(activeGroup.cameraSerials)
                            } else {
                                bleManager.stopRecordingAllDevices()
                            }
                        } else {
                            // Start recording - only if all cameras are online and in sync
                            if allCamerasOnlineAndInSync {
                                handleRecordingAction()
                            }
                        }
                    }) {
                        ZStack {
                            // Outer ring
                            Circle()
                                .stroke(recordingButtonStrokeColor, lineWidth: 3)
                                .frame(width: 60, height: 60)

                            // Inner button
                            if isAnyCameraRecording {
                                // Stop button (square)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red)
                                    .frame(width: 20, height: 20)
                            } else {
                                // Record button (circle)
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                    .scaleEffect(isAnyCameraRecording ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isAnyCameraRecording)
                    .disabled(recordingButtonDisabled)
                    .opacity(recordingButtonOpacity)
                }
            }

            // Secondary Camera Management Controls Row
            HStack(spacing: 8) {
                // Connect All Button
                Button(action: {
                    if cameraGroupManager.activeGroup != nil {
                        // Connect cameras in active group
                        let cameraIds = Set(cameraGroupManager.activeGroup!.cameraIds)
                        bleManager.setTargetCameras(cameraIds)

                        for cameraId in cameraGroupManager.activeGroup!.cameraIds {
                            if bleManager.discoveredGoPros[cameraId] != nil {
                                bleManager.connectToGoPro(uuid: cameraId)
                            }
                        }
                    } else {
                        // Connect all discovered cameras
                        bleManager.connectCameras()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi")
                            .font(.system(size: 12, weight: .medium))
                        Text("Connect")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .disabled(discoveredCameraCount == 0)
                .opacity(discoveredCameraCount == 0 ? 0.5 : 1.0)

                // Disconnect All Button
                Button(action: {
                    if cameraGroupManager.activeGroup != nil {
                        // Disconnect cameras in active group
                        for cameraId in cameraGroupManager.activeGroup!.cameraIds {
                            if bleManager.connectedGoPros[cameraId] != nil {
                                bleManager.disconnectFromGoPro(uuid: cameraId)
                            }
                        }
                        // Clear target cameras for this group
                        bleManager.clearTargetCameras()
                    } else {
                        // Disconnect all cameras
                        bleManager.disconnectCameras()
                        bleManager.clearTargetCameras()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12, weight: .medium))
                        Text("Disconnect")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                .disabled(connectedCameraCount == 0)
                .opacity(connectedCameraCount == 0 ? 0.5 : 1.0)

                // Sleep All Button
                Button(action: {
                    if cameraGroupManager.activeGroup != nil {
                        // Sleep cameras in active group
                        for cameraId in cameraGroupManager.activeGroup!.cameraIds {
                            if bleManager.connectedGoPros[cameraId] != nil {
                                bleManager.disconnectFromGoPro(uuid: cameraId, sleep: true)
                            }
                        }
                    } else {
                        // Sleep all cameras
                        bleManager.putCamerasToSleep()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("Sleep")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .disabled(connectedCameraCount == 0)
                .opacity(connectedCameraCount == 0 ? 0.5 : 1.0)

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isAnyCameraRecording ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .onChange(of: allCamerasOnlineAndInSync) { newValue in
            // Auto-stop recording if cameras go offline or out of sync while recording
            if isAnyCameraRecording && !newValue {
                ErrorHandler.info("🛑 Auto-stopping recording: cameras went offline or out of sync")

                if let activeGroup = cameraGroupManager.activeGroup {
                    bleManager.stopRecordingForCamerasInSet(activeGroup.cameraSerials)
                } else {
                    bleManager.stopRecordingAllDevices()
                }
            }

            previouslyAllOnlineAndInSync = newValue
        }
        .onAppear {
            previouslyAllOnlineAndInSync = allCamerasOnlineAndInSync
        }
    }
}

// MARK: - Recording Status View
struct RecordingStatusView: View {
    let groupName: String
    let isAnyCameraRecording: Bool
    @Binding var recordingPulse: Bool
    let connectedCameraCount: Int
    let cameraGroupManager: CameraGroupManager
    let groupStatus: GroupStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Recording indicator with pulse animation
                RecordingPulseIndicatorView(
                    isRecording: isAnyCameraRecording,
                    recordingPulse: $recordingPulse
                )

                Text(groupName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            HStack(spacing: 16) {
                // Camera count with status
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Show connected count and total if different
                    if let activeGroup = cameraGroupManager.activeGroup,
                       activeGroup.cameraIds.count != connectedCameraCount {
                        Text("\(connectedCameraCount) of \(activeGroup.cameraIds.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .kerning(0.5)
                            .fixedSize(horizontal: true, vertical: false)
                    } else {
                        Text("\(connectedCameraCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    // Set status indicator
                    if cameraGroupManager.activeGroup != nil,
                       let status = groupStatus {
                        Image(systemName: status.overallStatus.icon)
                            .font(.caption)
                            .foregroundColor(status.overallStatus.color)
                    }
                }

                // Recording status - removed text to prevent squishing
                if isAnyCameraRecording {
                    HStack(spacing: 4) {
                        Image(systemName: "record.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Recording Pulse Indicator View
struct RecordingPulseIndicatorView: View {
    let isRecording: Bool
    @Binding var recordingPulse: Bool

    var body: some View {
        Circle()
            .fill(isRecording ? Color.red : Color.gray)
            .frame(width: 12, height: 12)
            .scaleEffect(isRecording && recordingPulse ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recordingPulse)
            .onAppear {
                if isRecording {
                    recordingPulse = true
                }
            }
            .onChange(of: isRecording) { recording in
                recordingPulse = recording
            }
    }
}
