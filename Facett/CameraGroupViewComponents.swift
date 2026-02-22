import SwiftUI

// MARK: - Camera Group Row View
struct CameraGroupRowView: View {
    let group: CameraGroup
    let isActive: Bool
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    // Simple computed properties - no caching needed
    private var currentGroup: CameraGroup {
        cameraGroupManager.cameraGroups.first(where: { $0.id == group.id }) ?? group
    }

    private var status: GroupStatus {
        cameraGroupManager.getGroupStatus(for: currentGroup, bleManager: bleManager)
    }

    var body: some View {
        Button(action: {
            onActivate()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(currentGroup.name)
                                .font(.headline)
                                .fontWeight(.medium)

                            if isActive {
                                Text("Active")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }

                        Text(status.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Show camera count and status summary
                        CameraGroupSummaryView(group: currentGroup, status: status)
                    }

                    Spacer()

                    Menu {
                        Button("Edit") {
                            onEdit()
                        }

                        if !isActive {
                            Button("Set as Active") {
                                onActivate()
                            }
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    .accessibilityLabel("Group Actions")
                    .onTapGesture {} // Prevent menu tap from triggering row selection
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.green.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onActivate()
        }
    }
}

// MARK: - Camera in Group Row View
struct CameraInGroupRowView: View {
    let cameraSerial: String
    @ObservedObject var bleManager: BLEManager
    let onRemove: () -> Void

    private var cameraId: UUID? {
        CameraSerialResolver.shared.getUUID(forSerial: cameraSerial)
    }

    private func getCameraName() -> String {
        if let uuid = cameraId {
            if let discoveredCamera = bleManager.discoveredGoPros[uuid] {
                return CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: discoveredCamera.name)
            } else if let connectedCamera = bleManager.connectedGoPros[uuid] {
                return CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: connectedCamera.name)
            } else {
                return CameraIdentityManager.shared.getDisplayName(for: uuid)
            }
        }
        // Fallback to serial-based name
        return CameraIdentityManager.shared.getDisplayName(forSerial: cameraSerial)
    }

    var body: some View {
        if let uuid = cameraId, let camera = bleManager.connectedGoPros[uuid] {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getCameraName())
                        .font(.subheadline)

                    // Show battery level (quantized) for camera lists
                    if let batteryLevel = camera.status.batteryLevel {
                        let estimatedPercentage = batteryLevel * 25
                        HStack(spacing: 4) {
                            let batteryIconLevel = max(1, min(4, batteryLevel))

                            Image(systemName: camera.status.isUSBConnected == true ? "battery.\(batteryIconLevel).bolt" : "battery.\(batteryIconLevel)")
                                .font(.caption2)
                                .foregroundColor(camera.status.isUSBConnected == true ? .blue : CameraGroupManagementView.batteryColorFromLevel(batteryLevel))

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
                    } else {
                        EmptyView()
                    }
                }

                Spacer()

                Button("Remove") {
                    onRemove()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getCameraName())
                        .font(.subheadline)

                    Text("Camera not connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Remove") {
                    onRemove()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Camera Group Summary View
struct CameraGroupSummaryView: View {
    let group: CameraGroup
    let status: GroupStatus

    var body: some View {
        HStack(spacing: 12) {
            // Total cameras
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.caption)
                Text("\(status.totalCameras)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            // Connected count (total - disconnected)
            let connectedCount = status.totalCameras - status.disconnectedCameras
            if connectedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                    Text("\(connectedCount) connected")
                        .font(.caption)
                }
                .foregroundColor(.green)
            }

            // Ready cameras (synced and ready to use)
            if status.readyCameras > 0 && status.readyCameras == status.totalCameras {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("All ready")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
    }
}
