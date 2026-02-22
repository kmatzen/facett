import SwiftUI
import CoreBluetooth
import Combine

// MARK: - Camera Status Card View
struct CameraStatusCardView: View {
    let camera: GoPro
    let status: CameraStatus
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var configManager: ConfigManager
    @State var isFlashing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with status icon and camera name
            HStack {
                if configManager.autoSyncEnabled && configManager.isAutoSyncing && isCameraBeingSynced() {
                    // Show spinning sync icon during sync
                    SpinningSyncIcon()
                } else {
                    // Show normal status icon
                    StatusIconView(
                        icon: status.icon,
                        color: status.color
                    )
                }

                Text(CameraIdentityManager.shared.getDisplayName(for: camera.peripheral.identifier, currentName: camera.name))
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                // Recording indicator and record/stop button
                if let isEncoding = camera.status.isEncoding {
                    TimeoutButton(
                        label: "",
                        color: .clear,
                        action: {
                            if isEncoding {
                                bleManager.stopRecording(for: camera.peripheral.identifier)
                            } else {
                                bleManager.startRecording(for: camera.peripheral.identifier)
                            }
                        },
                        font: .body,
                        padding: 0,
                        cornerRadius: 0,
                        timeout: 1,
                        maxWidth: nil
                    ) {
                        if isEncoding {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 16, height: 16)
                                .opacity(isFlashing ? 1.0 : 0.3)
                                .onAppear {
                                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever()) {
                                        isFlashing = true
                                    }
                                }
                                .onDisappear {
                                    isFlashing = false
                                }
                        }
                    }
                }
            }

            // Status text
            Text(status.rawValue)
                .font(.caption2)
                .foregroundColor(status.color)
                .fontWeight(.medium)

            // Battery and key status indicators
            VStack(alignment: .leading, spacing: 4) {
                // Battery indicator
                if let batteryPercentage = camera.status.batteryPercentage {
                    HStack {
                        let batteryIconLevel = max(1, min(4, (batteryPercentage + 24) / 25))
                        Image(systemName: camera.status.isUSBConnected == true ? "battery.\(batteryIconLevel).bolt" : "battery.\(batteryIconLevel)")
                            .foregroundColor(camera.status.isUSBConnected == true ? .blue : batteryColorFromPercentage(batteryPercentage))
                        Text("\(batteryPercentage)%")
                            .font(.caption2)

                        // Lightning badge for charging cameras
                        if camera.status.isUSBConnected == true {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }

                        Spacer()

                        // GPS and SD card indicators
                        HStack(spacing: 4) {
                            if camera.status.hasGPSLock == true {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }

                            if let sdCardRemaining = camera.status.sdCardRemaining {
                                Text("\(String(format: "%.1f", Double(sdCardRemaining) / 1_048_576))GB")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } else if let batteryLevel = camera.status.batteryLevel {
                    // Fallback to battery level if percentage not available
                    HStack {
                        let batteryIconLevel = max(1, min(4, batteryLevel))
                        Image(systemName: camera.status.isUSBConnected == true ? "battery.\(batteryIconLevel).bolt" : "battery.\(batteryIconLevel)")
                            .foregroundColor(camera.status.isUSBConnected == true ? .blue : batteryColorFromLevel(batteryLevel))
                        Text("~\(batteryLevel * 25)%")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Lightning badge for charging cameras
                        if camera.status.isUSBConnected == true {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }

                        Spacer()

                        // GPS and SD card indicators
                        HStack(spacing: 4) {
                            if camera.status.hasGPSLock == true {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }

                            if let sdCardRemaining = camera.status.sdCardRemaining {
                                Text("\(String(format: "%.1f", Double(sdCardRemaining) / 1_048_576))GB")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // Additional status indicators
                HStack(spacing: 4) {
                    if camera.status.turboTransfer == true {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    if camera.status.mobileFriendlyVideo == true {
                        Image(systemName: "iphone")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    if camera.status.cameraControlStatus == true {
                        Image(systemName: "hand.raised.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    if camera.status.allowControlOverUsb == true {
                        Image(systemName: "cable.connector")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helper Methods

    private func isCameraBeingSynced() -> Bool {
        // Skip settings mismatch checks for recording cameras to avoid false positives
        if camera.status.isEncoding == true {
            return false
        }
        // Check if this specific camera has mismatched settings that would trigger a sync
        let targetSettings = configManager.getTargetSettings()
        return ConfigValidation.hasSettingsMismatch(gopro: camera, targetSettings: targetSettings)
    }

    private func batteryColorFromPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 0...20: return .red
        case 21...40: return .orange
        case 41...60: return .yellow
        default: return .green
        }
    }

    private func batteryColorFromLevel(_ level: Int) -> Color {
        switch level {
        case 0...1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}

// MARK: - Disconnected Camera Card View
struct DisconnectedCameraCardView: View {
    let cameraId: UUID
    @ObservedObject var bleManager: BLEManager
    @State private var isConnecting = false

    var isDiscovered: Bool {
        bleManager.discoveredGoPros[cameraId] != nil
    }

    var cameraName: String {
        if let camera = bleManager.discoveredGoPros[cameraId] {
            // Use current name from peripheral and store it
            return CameraIdentityManager.shared.getDisplayName(for: cameraId, currentName: camera.name)
        }
        // Use stored name or fallback
        return CameraIdentityManager.shared.getDisplayName(for: cameraId)
    }

    var statusColor: Color {
        if isDiscovered {
            return .orange
        } else {
            return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with status icon and camera name
            HStack {
                StatusIconView(
                    icon: isDiscovered ? "wifi.exclamationmark" : "wifi.slash",
                    color: statusColor
                )

                Text(cameraName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(isDiscovered ? .primary : .secondary)

                Spacer()
            }

            // Action indicator
            HStack {
                if let retryStatus = bleManager.connectionRetryStatus[cameraId] {
                    // Show retry status from BLEManager
                    Image(systemName: retryStatus.icon)
                        .font(.caption2)
                        .foregroundColor(retryStatus.color)
                    Text(retryStatus.displayText)
                        .font(.caption2)
                        .foregroundColor(retryStatus.color)
                } else if isConnecting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    Text("Connecting...")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else if isDiscovered {
                    Image(systemName: "hand.tap")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Tap to connect")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Not found")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Spacer()
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isConnecting ? Color.blue.opacity(0.5) : statusColor.opacity(0.3), lineWidth: 1)
        )
        .opacity(isConnecting ? 0.7 : 1.0)
        .scaleEffect(isConnecting ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isConnecting)
        .onTapGesture {
            // Only try to connect if camera is discovered and not already connecting or retrying
            if isDiscovered && !isConnecting && bleManager.connectionRetryStatus[cameraId] == nil {
                isConnecting = true
                bleManager.connectToGoPro(uuid: cameraId)
            }
        }
        .onAppear {
            // If this camera is being connected from the set button, show connecting animation
            if bleManager.camerasBeingConnectedFromGroup.contains(cameraId) {
                isConnecting = true
            }
        }
        .onReceive(bleManager.$connectedGoPros) { connectedGoPros in
            // Reset connecting state when camera connects
            if connectedGoPros[cameraId] != nil {
                isConnecting = false
            }
        }
        .onReceive(bleManager.$connectionRetryStatus) { retryStatus in
            // Update connecting state based on retry status
            if retryStatus[cameraId] != nil {
                isConnecting = false // Stop local connecting animation when retry status is set
            }
        }
        .onReceive(Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()) { _ in // Cosmetic: UI connecting-spinner timeout
            if isConnecting {
                isConnecting = false
            }
        }
        .onReceive(bleManager.$camerasBeingConnectedFromGroup) { camerasBeingConnected in
            // Start connecting animation when this camera is added to the set being connected
            if camerasBeingConnected.contains(cameraId) && !isConnecting {
                isConnecting = true
            }
        }
    }
}

// MARK: - Active Group Summary View
struct ActiveGroupSummaryView: View {
    let set: CameraGroup
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var configManager: ConfigManager
    @State private var selectedCamera: GoPro?

    // Simple computed properties - no caching needed
    private var status: GroupStatus {
        cameraGroupManager.getGroupStatus(for: set, bleManager: bleManager)
    }

    private var cameras: [UUID: GoPro] {
        // Include all cameras in the set, whether connected or discovered
        var allCameras: [UUID: GoPro] = [:]

        for serial in set.cameraSerials {
            // Look up the current UUID for this serial number
            guard let cameraId = CameraSerialResolver.shared.getUUID(forSerial: serial) else {
                continue
            }

            // First try to get connected camera
            if let connectedCamera = bleManager.connectedGoPros[cameraId] {
                allCameras[cameraId] = connectedCamera
            }
            // If not connected, try to get discovered camera
            else if let discoveredCamera = bleManager.discoveredGoPros[cameraId] {
                allCameras[cameraId] = discoveredCamera
            }
        }

        return allCameras
    }

    var body: some View {
        VStack(spacing: 12) {
            // Overall Status
            HStack {
                StatusIconView(
                    icon: status.overallStatus.icon,
                    color: status.overallStatus.color
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Group Status: \(status.overallStatus.rawValue)")
                        .font(.headline)
                    Text(status.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Camera Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(set.cameraSerials).sorted(), id: \.self) { (serial: String) in
                    if let cameraId = CameraSerialResolver.shared.getUUID(forSerial: serial) {
                        if let connectedCamera = bleManager.connectedGoPros[cameraId] {
                            // Camera is fully connected - show full status
                            CameraStatusCardView(
                                camera: connectedCamera,
                                status: cameraGroupManager.getCameraStatus(connectedCamera, bleManager: bleManager),
                                bleManager: bleManager,
                                configManager: configManager
                            )
                            .onTapGesture {
                                selectedCamera = connectedCamera
                            }
                        } else {
                            // Camera is either discovered but not connected, or not found at all
                            DisconnectedCameraCardView(
                                cameraId: cameraId,
                                bleManager: bleManager
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(item: $selectedCamera) { camera in
            CameraDetailsSheet(
                camera: camera,
                bleManager: bleManager,
                cameraGroupManager: cameraGroupManager
            )
        }
    }
}
