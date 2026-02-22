import SwiftUI

// MARK: - Camera Group Management View
struct CameraGroupManagementView: View {
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddGroup = false
    @State private var selectedGroupForEdit: CameraGroup?

    var body: some View {
        NavigationView {
            List {
                Section("Camera Groups") {
                    ForEach(cameraGroupManager.cameraGroups) { group in
                        CameraGroupRowView(
                            group: group,
                            isActive: cameraGroupManager.activeGroupId == group.id,
                            cameraGroupManager: cameraGroupManager,
                            bleManager: bleManager,
                            onActivate: {
                                cameraGroupManager.setActiveGroup(group)
                            },
                            onEdit: {
                                selectedGroupForEdit = group
                            },
                            onDelete: {
                                cameraGroupManager.removeCameraGroup(group)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Camera Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Group") {
                        showingAddGroup = true
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddCameraGroupView(cameraGroupManager: cameraGroupManager, isPresented: $showingAddGroup)
            }
            .sheet(item: $selectedGroupForEdit) { group in
                CameraGroupEditorView(
                    group: group,
                    cameraGroupManager: cameraGroupManager,
                    bleManager: bleManager,
                    isPresented: Binding(
                        get: { selectedGroupForEdit != nil },
                        set: { if !$0 { selectedGroupForEdit = nil } }
                    )
                )
            }
        }
    }
}

// MARK: - Battery Color Helpers
extension CameraGroupManagementView {
    static func batteryColorFromLevel(_ level: Int) -> Color {
        switch level {
        case 0...1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}

// MARK: - Add Camera Group View
struct AddCameraGroupView: View {
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @Binding var isPresented: Bool
    @State private var groupName = ""

    private func createGroup() {
        cameraGroupManager.addCameraGroup(name: groupName)
        isPresented = false
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Camera Group")
                .font(.title)
                .fontWeight(.semibold)

            Text("Enter a name for your camera group:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Group Name", text: $groupName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Create") {
                    if groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        groupName = "New Camera Group"
                    }
                    createGroup()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Camera Group Editor View
struct CameraGroupEditorView: View {
    let group: CameraGroup
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    @Binding var isPresented: Bool
    @State private var groupName: String
    @State private var showingCameraSelector = false

    init(group: CameraGroup, cameraGroupManager: CameraGroupManager, bleManager: BLEManager, isPresented: Binding<Bool>) {
        self.group = group
        self.cameraGroupManager = cameraGroupManager
        self.bleManager = bleManager
        self._isPresented = isPresented
        self._groupName = State(initialValue: group.name)
    }

    private var currentGroup: CameraGroup? {
        cameraGroupManager.cameraGroups.first(where: { $0.id == group.id })
    }

    var body: some View {
        Form {
            // Name section
            Section("Group Name") {
                TextField("Group Name", text: $groupName)
                    .textFieldStyle(.roundedBorder)
            }

            // Cameras section
            Section {
                if let currentGroup = currentGroup, !currentGroup.cameraSerials.isEmpty {
                    ForEach(Array(currentGroup.cameraSerials), id: \.self) { cameraSerial in
                        // Use plain row styling inside a Form
                        CameraInGroupRowView(
                            cameraSerial: cameraSerial,
                            bleManager: bleManager,
                            onRemove: {
                                cameraGroupManager.removeCameraFromGroup(cameraSerial, group: currentGroup)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Text("No cameras in this group")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 4)
                }
            } header: {
                // Custom header with inline Add button
                HStack {
                    let count = currentGroup?.cameraSerials.count ?? 0
                    Text("Cameras in Group (\(count))")
                    Spacer()
                    Button("Add Camera") {
                        showingCameraSelector = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("AddCameraButton")
                }
            }
        }
        .navigationTitle("Edit Camera Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    if var updatedGroup = currentGroup {
                        updatedGroup.name = groupName
                        cameraGroupManager.updateCameraGroup(updatedGroup)

                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()

                        // Dismiss the view
                        isPresented = false
                    }
                }
                .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .sheet(isPresented: $showingCameraSelector) {
            if let currentGroup = currentGroup {
                CameraSelectorView(
                    cameraGroupManager: cameraGroupManager,
                    bleManager: bleManager,
                    currentGroup: currentGroup
                )
            }
        }
    }
}
