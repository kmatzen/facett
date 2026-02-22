import SwiftUI

// MARK: - Configuration Management View
struct ConfigManagementView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddConfig = false
    @State private var selectedConfigForEdit: CameraConfig?

    var body: some View {
        NavigationView {
            List {
                Section("Auto-Sync") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Auto-Sync Settings")
                                    .font(.headline)
                                    .fontWeight(.medium)

                                // Auto-sync status indicator
                                if configManager.isAutoSyncing {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("Syncing...")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }

                            Text("Automatically sync camera settings when they differ from the selected configuration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { configManager.autoSyncEnabled },
                            set: { newValue in
                                configManager.autoSyncEnabled = newValue
                                configManager.saveAutoSyncSetting()
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }

                Section("Configurations") {
                    ForEach(configManager.configs) { config in
                        ConfigRowView(
                            config: config,
                            isSelected: configManager.selectedConfigId == config.id,
                            onSelect: {
                                configManager.selectConfigAndSync(config.id, bleManager: bleManager, cameraGroupManager: cameraGroupManager)
                            },
                            onEdit: {
                                selectedConfigForEdit = config
                            },
                            onDuplicate: {
                                _ = configManager.duplicateConfig(config.id)
                            },
                            onDelete: {
                                configManager.deleteConfig(config.id)
                            },
                            onSetDefault: {
                                configManager.setDefaultConfig(config.id)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Configurations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Config") {
                        showingAddConfig = true
                    }
                }
            }
            .sheet(isPresented: $showingAddConfig) {
                ConfigEditorView(
                    configManager: configManager,
                    bleManager: bleManager,
                    cameraGroupManager: cameraGroupManager,
                    editingConfig: nil
                )
            }
            .sheet(item: $selectedConfigForEdit) { config in
                ConfigEditorView(
                    configManager: configManager,
                    bleManager: bleManager,
                    cameraGroupManager: cameraGroupManager,
                    editingConfig: config
                )
            }
        }
    }
}

// MARK: - Configuration Row View
struct ConfigRowView: View {
    let config: CameraConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onSetDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(config.name)
                            .font(.headline)
                            .fontWeight(.medium)

                        if config.isDefault {
                            Text("Default")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }

                        if isSelected {
                            Text("Selected")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    if !config.description.isEmpty {
                        Text(config.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Show key settings summary
                    ConfigSummaryView(settings: config.settings)
                }

                Spacer()

                Menu {
                    Button("Edit") {
                        onEdit()
                    }

                    Button("Duplicate") {
                        onDuplicate()
                    }

                    if !config.isDefault {
                        Button("Set as Default") {
                            onSetDefault()
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
                .accessibilityLabel("Config Actions")
                .onTapGesture {} // Prevent menu tap from triggering row selection
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Configuration Summary View
struct ConfigSummaryView: View {
    let settings: GoProSettingsData

    var body: some View {
        HStack(spacing: 12) {
            ConfigSummaryItem(
                label: "Res",
                value: resolutionDescription(for: settings.videoResolution)
            )

            ConfigSummaryItem(
                label: "FPS",
                value: fpsDescription(for: settings.framesPerSecond)
            )

            ConfigSummaryItem(
                label: "Profile",
                value: colorProfileDescription(for: settings.colorProfile)
            )

            if settings.protuneEnabled {
                ConfigSummaryItem(
                    label: "ProTune",
                    value: "On"
                )
            }
        }
    }

    private func resolutionDescription(for value: Int) -> String {
        switch value {
        case 1: return "4K"
        case 4: return "2.7K"
        case 6: return "2.7K 4:3"
        case 9: return "1080"
        case 18: return "4K 4:3"
        case 25: return "5K 4:3"
        case 100: return "5.3K"
        default: return "Unknown"
        }
    }

    private func fpsDescription(for value: Int) -> String {
        switch value {
        case 0: return "240"
        case 1: return "120"
        case 2: return "100"
        case 5: return "60"
        case 6: return "50"
        case 8: return "30"
        case 9: return "25"
        case 10: return "24"
        case 13: return "200"
        default: return "Unknown"
        }
    }

    private func colorProfileDescription(for value: Int) -> String {
        switch value {
        case 0: return "Natural"
        case 1: return "Flat"
        case 2: return "GoPro"
        default: return "Unknown"
        }
    }
}

// MARK: - Configuration Summary Item
struct ConfigSummaryItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }
}



// MARK: - Configuration Editor View
struct ConfigEditorView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    let editingConfig: CameraConfig?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var settings: GoProSettingsData = GoProSettingsData.defaultSettings()

    var body: some View {
        NavigationView {
            Form {
                Section("Configuration Details") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Video Settings") {
                    Picker("Resolution", selection: $settings.videoResolution) {
                        Text("4K").tag(1)
                        Text("2.7K").tag(4)
                        Text("2.7K 4:3").tag(6)
                        Text("1080").tag(9)
                        Text("4K 4:3").tag(18)
                        Text("5K 4:3").tag(25)
                        Text("5.3K").tag(100)
                    }

                    Picker("Frame Rate", selection: $settings.framesPerSecond) {
                        Text("240 FPS").tag(0)
                        Text("120 FPS").tag(1)
                        Text("100 FPS").tag(2)
                        Text("60 FPS").tag(5)
                        Text("50 FPS").tag(6)
                        Text("30 FPS").tag(8)
                        Text("25 FPS").tag(9)
                        Text("24 FPS").tag(10)
                        Text("200 FPS").tag(13)
                    }

                    Picker("Color Profile", selection: $settings.colorProfile) {
                        Text("GoPro").tag(0)
                        Text("Flat").tag(1)
                    }

                    Toggle("ProTune Enabled", isOn: $settings.protuneEnabled)
                }

                Section("Camera Behavior") {
                    Picker("Auto Power Down", selection: $settings.autoPowerDown) {
                        Text("Never").tag(0)
                        Text("5 Minutes").tag(4)
                        Text("15 Minutes").tag(6)
                        Text("30 Minutes").tag(7)
                    }

                    Toggle("GPS", isOn: $settings.gps)
                    Toggle("Quick Capture", isOn: $settings.quickCapture)
                    Toggle("Voice Control", isOn: $settings.voiceControl)
                }

                Section("Image Quality") {
                    Picker("ISO Max", selection: $settings.isoMax) {
                        Text("100").tag(8)
                        Text("200").tag(7)
                        Text("400").tag(2)
                        Text("800").tag(4)
                        Text("1600").tag(1)
                        Text("3200").tag(3)
                        Text("6400").tag(0)
                    }

                    Picker("ISO Min", selection: $settings.isoMin) {
                        Text("100").tag(8)
                        Text("200").tag(7)
                        Text("400").tag(2)
                        Text("800").tag(4)
                        Text("1600").tag(1)
                        Text("3200").tag(3)
                        Text("6400").tag(0)
                    }

                    Picker("White Balance", selection: $settings.whiteBalance) {
                        Text("Auto").tag(0)
                        Text("2300K").tag(8)
                        Text("2800K").tag(9)
                        Text("3200K").tag(10)
                        Text("4000K").tag(5)
                        Text("4500K").tag(11)
                        Text("5000K").tag(12)
                        Text("5500K").tag(2)
                        Text("6000K").tag(7)
                        Text("6500K").tag(3)
                        Text("Native").tag(4)
                    }

                    Picker("EV", selection: $settings.ev) {
                        Text("-2.0").tag(8)
                        Text("-1.5").tag(7)
                        Text("-1.0").tag(6)
                        Text("-0.5").tag(5)
                        Text("0.0").tag(4)
                        Text("+0.5").tag(3)
                        Text("+1.0").tag(2)
                        Text("+1.5").tag(1)
                        Text("+2.0").tag(0)
                    }

                    Picker("Shutter", selection: $settings.shutter) {
                        Text("Auto").tag(0)
                        Text("1/24").tag(1)
                        Text("1/30").tag(2)
                        Text("1/48").tag(3)
                        Text("1/50").tag(4)
                        Text("1/60").tag(5)
                        Text("1/96").tag(6)
                        Text("1/100").tag(7)
                        Text("1/120").tag(8)
                        Text("1/192").tag(9)
                        Text("1/200").tag(10)
                        Text("1/240").tag(11)
                        Text("1/360").tag(12)
                        Text("1/400").tag(13)
                        Text("1/480").tag(14)
                    }
                }

                Section("Video Advanced") {
                    Picker("Video Lens", selection: $settings.videoLens) {
                        Text("Wide").tag(0)
                        Text("Linear").tag(4)
                        Text("Narrow").tag(6)
                    }

                    Picker("HyperSmooth", selection: $settings.hypersmooth) {
                        Text("Off").tag(0)
                        Text("On").tag(1)
                        Text("High").tag(2)
                        Text("Boost").tag(3)
                        Text("Auto Boost").tag(4)
                    }

                    Toggle("Max Lens", isOn: $settings.maxLens)

                    Picker("Video Performance Mode", selection: $settings.videoPerformanceMode) {
                        Text("Maximum Performance").tag(0)
                        Text("Extended Battery").tag(1)
                        Text("Tripod/Stationary").tag(2)
                    }

                    Picker("Bitrate", selection: $settings.bitrate) {
                        Text("Standard").tag(0)
                        Text("High").tag(1)
                    }

                    Picker("Anti-Flicker", selection: $settings.antiFlicker) {
                        Text("50Hz").tag(1)
                        Text("60Hz").tag(2)
                        Text("Auto").tag(3)
                    }
                }

                Section("Audio") {
                    Picker("Raw Audio", selection: $settings.rawAudio) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                        Text("Off").tag(3)
                    }

                    Picker("Wind Noise Reduction", selection: $settings.wind) {
                        Text("Off").tag(0)
                        Text("On").tag(1)
                        Text("Auto").tag(2)
                    }

                    Toggle("Audio ProTune", isOn: $settings.audioProtune)
                    Toggle("No Audio Track", isOn: $settings.noAudioTrack)
                }

                Section("Interface & Controls") {
                    Picker("LCD Brightness", selection: $settings.lcdBrightness) {
                        Text("10%").tag(10)
                        Text("20%").tag(20)
                        Text("30%").tag(30)
                        Text("40%").tag(40)
                        Text("50%").tag(50)
                        Text("60%").tag(60)
                        Text("70%").tag(70)
                        Text("80%").tag(80)
                        Text("90%").tag(90)
                        Text("100%").tag(100)
                    }

                    Picker("Language", selection: $settings.language) {
                        Text("English").tag(0)
                        Text("Chinese (Simplified)").tag(1)
                        Text("Chinese (Traditional)").tag(2)
                        Text("Japanese").tag(3)
                        Text("Korean").tag(4)
                        Text("Spanish").tag(5)
                        Text("French").tag(6)
                        Text("German").tag(7)
                        Text("Italian").tag(8)
                        Text("Portuguese").tag(9)
                        Text("Russian").tag(10)
                    }

                    Picker("Beeps", selection: $settings.beeps) {
                        Text("Off").tag(0)
                        Text("70%").tag(1)
                        Text("100%").tag(2)
                    }

                    Picker("LED", selection: $settings.led) {
                        Text("All On").tag(0)
                        Text("All Off").tag(5)
                        Text("Front Off").tag(1)
                        Text("Status Only").tag(2)
                    }
                }

                Section("Advanced Features") {
                    Picker("Hindsight", selection: $settings.hindsight) {
                        Text("15 Seconds").tag(1)
                        Text("30 Seconds").tag(2)
                        Text("Off").tag(4)
                    }

                    Picker("Timer", selection: $settings.timer) {
                        Text("Off").tag(0)
                        Text("3 Seconds").tag(1)
                        Text("10 Seconds").tag(2)
                    }

                    Toggle("Wake on Voice", isOn: $settings.wakeOnVoice)

                    Picker("Privacy", selection: $settings.privacy) {
                        Text("Off").tag(0)
                        Text("On").tag(1)
                    }

                    Picker("Auto Lock", selection: $settings.autoLock) {
                        Text("Off").tag(0)
                        Text("On").tag(1)
                    }

                    Picker("Video Compression", selection: $settings.videoCompression) {
                        Text("HEVC").tag(0)
                        Text("H.264").tag(1)
                    }

                    Picker("Landscape Lock", selection: $settings.landscapeLock) {
                        Text("Off").tag(0)
                        Text("On").tag(1)
                        Text("Up").tag(2)
                        Text("Down").tag(3)
                    }
                }
            }
            .navigationTitle(editingConfig != nil ? "Edit Configuration" : "New Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let config = editingConfig {
                    name = config.name
                    description = config.description
                    settings = config.settings
                }
            }
        }
    }

    private func saveConfiguration() {
        if let existingConfig = editingConfig {
            // Update existing config
            var updatedConfig = existingConfig
            updatedConfig.name = name
            updatedConfig.description = description
            updatedConfig.settings = settings
            configManager.updateConfig(updatedConfig)
        } else {
            // Create new config
            var newConfig = CameraConfig(
                name: name,
                description: description,
                isDefault: false
            )
            newConfig.settings = settings
            configManager.addConfig(newConfig)
        }

        // Trigger auto-sync if enabled
        configManager.checkAndTriggerAutoSync(bleManager: bleManager, cameraGroupManager: cameraGroupManager)

        dismiss()
    }
}
