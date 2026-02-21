import SwiftUI

// MARK: - Camera Selector View
struct CameraSelectorView: View {
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    let currentGroup: CameraGroup
    @Environment(\.dismiss) private var dismiss
    @State private var refreshTrigger = false
    @State private var pendingAdditions: Set<UUID> = [] // Track cameras waiting to be added after connection

    var availableCameras: [UUID: GoPro] {
        // Show both connected and discovered cameras
        // Start with connected cameras (they have priority and are guaranteed fresh)
        var cameras = bleManager.connectedGoPros

        // Add discovered cameras that aren't already connected
        for (uuid, gopro) in bleManager.discoveredGoPros {
            if cameras[uuid] == nil {
                cameras[uuid] = gopro
            }
        }

        // Filter out cameras that are already in the current group
        return cameras.filter { uuid, gopro in
            // If camera has a serial number, check if it's already in the group
            if let serial = gopro.status.apSSID {
                return !currentGroup.cameraSerials.contains(serial)
            }
            // Show cameras without serial numbers (discovered but not yet connected)
            return true
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if availableCameras.isEmpty {
                    EmptyStateView()
                } else {
                    CameraListView(
                        availableCameras: availableCameras,
                        currentGroup: currentGroup,
                        cameraGroupManager: cameraGroupManager,
                        bleManager: bleManager,
                        refreshTrigger: $refreshTrigger,
                        pendingAdditions: $pendingAdditions
                    )
                }
            }
            .navigationTitle("Add Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Refresh discovered cameras to clear stale entries
                // This only clears discovered cameras, not connected ones
                bleManager.refreshDiscoveredCameras()
            }
        }
    }
}

// MARK: - Empty State View
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No Available Cameras")
                .font(.headline)

            Text("No cameras have been discovered yet. Make sure cameras are powered on and in pairing mode.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Camera List View
private struct CameraListView: View {
    let availableCameras: [UUID: GoPro]
    let currentGroup: CameraGroup
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    @Binding var refreshTrigger: Bool
    @Binding var pendingAdditions: Set<UUID>

    var body: some View {
        List {
            ForEach(Array(availableCameras.keys).sorted(by: {
                let camera1 = availableCameras[$0]?.name ?? ""
                let camera2 = availableCameras[$1]?.name ?? ""
                return camera1 < camera2
            }), id: \.self) { cameraId in
                if let camera = availableCameras[cameraId] {
                    CameraRowView(
                        cameraId: cameraId,
                        camera: camera,
                        currentGroup: currentGroup,
                        cameraGroupManager: cameraGroupManager,
                        bleManager: bleManager,
                        refreshTrigger: $refreshTrigger,
                        pendingAdditions: $pendingAdditions
                    )
                }
            }
        }
    }
}

// MARK: - Camera Row View
private struct CameraRowView: View {
    let cameraId: UUID
    let camera: GoPro
    let currentGroup: CameraGroup
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    @Binding var refreshTrigger: Bool
    @Binding var pendingAdditions: Set<UUID>

    private var serial: String? {
        camera.status.apSSID
    }

    private var hasSerial: Bool {
        serial != nil
    }

    private var isInGroup: Bool {
        guard let serial = serial else { return false }
        guard let updatedGroup = cameraGroupManager.cameraGroups.first(where: { $0.id == currentGroup.id }) else { return false }
        return updatedGroup.cameraSerials.contains(serial)
    }

    private var isPending: Bool {
        pendingAdditions.contains(cameraId)
    }

    var body: some View {
        Button(action: {
            handleTap()
        }) {
            HStack {
                CameraInfoView(
                    cameraId: cameraId,
                    camera: camera,
                    hasSerial: hasSerial,
                    isPending: isPending,
                    bleManager: bleManager
                )

                Spacer()

                CameraStatusIconView(
                    hasSerial: hasSerial,
                    isInGroup: isInGroup,
                    isPending: isPending
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(isInGroup)
        .onChange(of: serial) { newSerial in
            // Auto-add camera when it gets a serial number (after connection)
            if let serial = newSerial, isPending {
                if let updatedGroup = cameraGroupManager.cameraGroups.first(where: { $0.id == currentGroup.id }) {
                    cameraGroupManager.addCameraToGroup(serial, group: updatedGroup)
                    pendingAdditions.remove(cameraId)
                    refreshTrigger.toggle()
                }
            }
        }
    }

    private func handleTap() {
        if let serial = serial {
            // Camera has serial number (already connected), add it to group immediately
            if let updatedGroup = cameraGroupManager.cameraGroups.first(where: { $0.id == currentGroup.id }) {
                cameraGroupManager.addCameraToGroup(serial, group: updatedGroup)
                refreshTrigger.toggle()
            }
        } else {
            // Camera doesn't have serial yet (discovered but not connected)
            // Connect first, then will auto-add when serial is received
            pendingAdditions.insert(cameraId)
            bleManager.connectToGoPro(uuid: cameraId)
        }
    }
}

// MARK: - Camera Info View
private struct CameraInfoView: View {
    let cameraId: UUID
    let camera: GoPro
    let hasSerial: Bool
    let isPending: Bool
    @ObservedObject var bleManager: BLEManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CameraNameAndStatusView(
                cameraId: cameraId,
                camera: camera,
                hasSerial: hasSerial,
                isPending: isPending,
                bleManager: bleManager
            )

            BatteryInfoView(camera: camera)
        }
    }
}

// MARK: - Camera Name and Status View
private struct CameraNameAndStatusView: View {
    let cameraId: UUID
    let camera: GoPro
    let hasSerial: Bool
    let isPending: Bool
    @ObservedObject var bleManager: BLEManager

    var body: some View {
        HStack {
            Text(CameraIdentityManager.shared.getDisplayName(for: cameraId, currentName: camera.name))
                .font(.subheadline)

            // Show connection status
            if isPending {
                Text("• Connecting...")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else if bleManager.connectedGoPros[cameraId] != nil {
                Text("• Connected")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("• Tap to connect")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Battery Info View
private struct BatteryInfoView: View {
    let camera: GoPro

    var body: some View {
        if let batteryLevel = camera.status.batteryLevel {
            let estimatedPercentage = batteryLevel * 25
            let batteryIconLevel = max(1, min(4, batteryLevel))

            HStack(spacing: 4) {
                Image(systemName: camera.status.isUSBConnected == true ? "battery.\(batteryIconLevel).bolt" : "battery.\(batteryIconLevel)")
                    .font(.caption2)
                    .foregroundColor(camera.status.isUSBConnected == true ? .blue : batteryColorFromLevel(batteryLevel))

                Text("~\(estimatedPercentage)%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Lightning badge for charging cameras
                if camera.status.isUSBConnected == true {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
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

// MARK: - Camera Status Icon View
private struct CameraStatusIconView: View {
    let hasSerial: Bool
    let isInGroup: Bool
    let isPending: Bool

    var body: some View {
        if isPending {
            ProgressView()
                .scaleEffect(0.8)
        } else if isInGroup {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if hasSerial {
            // Connected camera - show add icon
            Image(systemName: "plus.circle")
                .foregroundColor(.blue)
        } else {
            // Discovered camera - show connect icon
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.orange)
        }
    }
}
