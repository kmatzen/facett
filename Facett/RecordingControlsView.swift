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

    private var effectiveGroup: CameraGroup {
        cameraGroupManager.effectiveGroup(bleManager: bleManager)
    }

    private var effectiveCameras: [GoPro] {
        effectiveGroup.cameraIds.compactMap { bleManager.connectedGoPros[$0] }
    }

    private var isAnyCameraRecording: Bool {
        effectiveCameras.contains { $0.status.isEncoding == true }
    }

    private var connectedCameraCount: Int {
        effectiveGroup.cameraIds.filter { bleManager.connectedGoPros[$0] != nil }.count
    }

    private var totalCamerasInGroup: Int {
        effectiveGroup.cameraIds.count
    }

    private var allCamerasOnlineAndInSync: Bool {
        let group = effectiveGroup
        let targetSettings = configManager.getTargetSettings(for: cameraGroupManager.activeGroup)

        return group.cameraIds.allSatisfy { cameraId in
            guard let gopro = bleManager.connectedGoPros[cameraId] else {
                return false
            }
            guard gopro.status.isReady == true else {
                return false
            }
            if gopro.status.isEncoding == true {
                return true
            }
            return !ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: targetSettings)
        }
    }

    private var recordingCameraCount: Int {
        effectiveCameras.filter { $0.status.isEncoding == true }.count
    }

    private var groupName: String {
        effectiveGroup.name
    }

    private var discoveredCameraCount: Int {
        effectiveGroup.cameraIds.filter { bleManager.discoveredGoPros[$0] != nil }.count
    }

    private var groupStatus: GroupStatus {
        cameraGroupManager.getGroupStatus(for: effectiveGroup, bleManager: bleManager)
    }

    private var hasSettingsMismatches: Bool {
        let group = effectiveGroup
        let targetSettings = configManager.getTargetSettings(for: cameraGroupManager.activeGroup)
        for cameraId in group.cameraIds {
            if let gopro = bleManager.connectedGoPros[cameraId] {
                if gopro.status.isEncoding == true { continue }
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
                    totalCameraCount: totalCamerasInGroup,
                    groupStatus: groupStatus
                )

                Spacer()

                // Primary Control Buttons
                HStack(spacing: 12) {
                    if hasSettingsMismatches {
                        Button(action: {
                            bleManager.sendSettingsToCamerasInGroup(effectiveGroup.cameraSerials, configManager: configManager, cameraGroupManager: cameraGroupManager)
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
                            bleManager.stopRecordingForCamerasInSet(effectiveGroup.cameraSerials)
                        } else if allCamerasOnlineAndInSync {
                            handleRecordingAction()
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
                    let group = effectiveGroup
                    let cameraIds = Set(group.cameraIds)
                    bleManager.setTargetCameras(cameraIds)
                    let discoveredInGroup = cameraIds.filter { bleManager.discoveredGoPros[$0] != nil }
                    bleManager.connectStaggered(Array(discoveredInGroup))
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
                        for cameraId in effectiveGroup.cameraIds {
                            if bleManager.connectedGoPros[cameraId] != nil {
                                bleManager.disconnectFromGoPro(uuid: cameraId)
                            }
                        }
                    } else {
                        bleManager.disconnectCameras()
                    }
                    bleManager.clearTargetCameras()
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
                        for cameraId in effectiveGroup.cameraIds {
                            if bleManager.connectedGoPros[cameraId] != nil {
                                bleManager.disconnectFromGoPro(uuid: cameraId, sleep: true)
                            }
                        }
                    } else {
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
            if isAnyCameraRecording && !newValue {
                ErrorHandler.info("Auto-stopping recording: cameras went offline or out of sync")
                bleManager.stopRecordingForCamerasInSet(effectiveGroup.cameraSerials)
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
    let totalCameraCount: Int
    let groupStatus: GroupStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
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
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if totalCameraCount != connectedCameraCount {
                        Text("\(connectedCameraCount) of \(totalCameraCount)")
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

                    Image(systemName: groupStatus.overallStatus.icon)
                        .font(.caption)
                        .foregroundColor(groupStatus.overallStatus.color)
                }

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
