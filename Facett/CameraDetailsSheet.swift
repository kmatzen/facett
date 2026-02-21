import SwiftUI

// MARK: - Camera Details Sheet
struct CameraDetailsSheet: View {
    let camera: GoPro
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(CameraIdentityManager.shared.getDisplayName(for: camera.peripheral.identifier, currentName: camera.name))
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        HStack {
                            Text("Serial: \(camera.peripheral.identifier.uuidString.prefix(8))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            // Status indicator
                            let status = cameraGroupManager.getCameraStatus(camera, bleManager: bleManager)
                            HStack(spacing: 4) {
                                Image(systemName: status.icon)
                                    .foregroundColor(status.color)
                                Text(status.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(status.color)
                            }
                        }
                    }

                    // Connection Status & Disconnect Button
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi")
                                .foregroundColor(.green)
                            Text("Connected")
                                .font(.headline)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        Button("Disconnect") {
                            bleManager.disconnectFromGoPro(uuid: camera.peripheral.identifier)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)

                    // Time Synchronization
                    timeSyncSection()

                    // Battery & Power
                    batterySection()

                    // Recording & Media
                    recordingSection()

                    // Storage & GPS
                    storageSection()

                    // Video Settings
                    videoSettingsSection()

                    // Camera Settings
                    cameraSettingsSection()

                    // Advanced Settings
                    advancedSettingsSection()

                    // System & Connectivity
                    systemSection()

                    // Status & Health
                    statusSection()

                    // Additional Settings
                    additionalSettingsSection()
                }
                .padding()
            }
            .navigationTitle("Camera Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timeSyncSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Synchronization")
                .font(.headline)

            HStack(spacing: 12) {
                if let lastSyncDate = camera.status.lastTimeSyncDate {
                    Image(systemName: "clock.fill")
                        .font(.title)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(lastSyncDate))
                            .font(.title3)
                            .fontWeight(.medium)

                        Text(timeAgoString(from: lastSyncDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.title)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not Synced")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)

                        Text("Time sync pending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func batterySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery & Power")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Main battery display
                HStack(spacing: 12) {
                    if let batteryPercentage = camera.status.batteryPercentage {
                        let batteryIconLevel = max(1, min(4, (batteryPercentage + 24) / 25))
                        Image(systemName: camera.status.isUSBConnected == true ? "battery.\(batteryIconLevel).bolt" : "battery.\(batteryIconLevel)")
                            .font(.title)
                            .foregroundColor(camera.status.isUSBConnected == true ? .blue : batteryColorFromPercentage(batteryPercentage))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(batteryPercentage)%")
                                .font(.title2)
                                .fontWeight(.semibold)

                            if camera.status.isUSBConnected == true {
                                Text("Charging")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    Spacer()
                }

                // Battery details
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    if let isBatteryPresent = camera.status.isBatteryPresent {
                        batteryDetailItem(
                            icon: isBatteryPresent ? "battery.100" : "battery.0",
                            title: "Internal Battery",
                            value: isBatteryPresent ? "Present" : "Missing",
                            color: isBatteryPresent ? .green : .red
                        )
                    }

                    if let isExternalBatteryPresent = camera.status.isExternalBatteryPresent {
                        batteryDetailItem(
                            icon: isExternalBatteryPresent ? "battery.100.bolt" : "battery.0",
                            title: "External Battery",
                            value: isExternalBatteryPresent ? "Present" : "Not Present",
                            color: isExternalBatteryPresent ? .green : .gray
                        )
                    }

                    if let battOkayForOta = camera.status.battOkayForOta {
                        batteryDetailItem(
                            icon: battOkayForOta ? "checkmark.circle" : "battery.25",
                            title: "Update Ready",
                            value: battOkayForOta ? "Yes" : "No",
                            color: battOkayForOta ? .green : .orange
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func recordingSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording & Media")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Recording status
                HStack(spacing: 12) {
                    if let isEncoding = camera.status.isEncoding {
                        Image(systemName: isEncoding ? "record.circle.fill" : "stop.circle")
                            .font(.title)
                            .foregroundColor(isEncoding ? .red : .gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEncoding ? "Recording" : "Stopped")
                                .font(.title3)
                                .fontWeight(.medium)

                            if isEncoding, let duration = camera.status.videoEncodingDuration {
                                Text("Duration: \(duration)s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "questionmark.circle")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("Unknown")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                // Media details
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {

                    mediaDetailItem(
                        icon: "camera",
                        title: "Mode",
                        value: CameraSettingDescriptions.modeDescription(for: camera.settings.mode),
                        color: .blue
                    )

                    if let videoEncodingDuration = camera.status.videoEncodingDuration {
                        mediaDetailItem(
                            icon: "clock",
                            title: "Encoding Duration",
                            value: "\(videoEncodingDuration)s",
                            color: .blue
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func storageSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage & GPS")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                if let sdCardRemaining = camera.status.sdCardRemaining {
                    storageDetailItem(
                        icon: "sdcard",
                        title: "SD Card",
                        value: "\(String(format: "%.1f", Double(sdCardRemaining) / 1_048_576)) GB",
                        color: .blue
                    )
                } else {
                    storageDetailItem(
                        icon: "sdcard",
                        title: "SD Card",
                        value: "Unknown",
                        color: .gray
                    )
                }

                if camera.status.hasGPSLock == true {
                    storageDetailItem(
                        icon: "location.fill",
                        title: "GPS",
                        value: "Active",
                        color: .green
                    )
                }

                if let hasSDCardWriteSpeedError = camera.status.hasSDCardWriteSpeedError {
                    storageDetailItem(
                        icon: hasSDCardWriteSpeedError ? "exclamationmark.triangle.fill" : "checkmark.circle",
                        title: "SD Speed",
                        value: hasSDCardWriteSpeedError ? "Error" : "OK",
                        color: hasSDCardWriteSpeedError ? .red : .green
                    )
                } else {
                    storageDetailItem(
                        icon: "location.slash",
                        title: "GPS",
                        value: "Inactive",
                        color: .gray
                    )
                }

            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func videoSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Settings")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                settingItem("Resolution", CameraSettingDescriptions.resolutionDescription(for: camera.settings.videoResolution))
                settingItem("FPS", CameraSettingDescriptions.fpsDescription(for: camera.settings.framesPerSecond))
                settingItem("Lens", CameraSettingDescriptions.lensDescription(for: camera.settings.videoLens))
                settingItem("HyperSmooth", CameraSettingDescriptions.hypersmoothDescription(for: camera.settings.hypersmooth))
                settingItem("Color Profile", CameraSettingDescriptions.colorProfileDescription(for: camera.settings.colorProfile))
                settingItem("Performance", CameraSettingDescriptions.performanceModeDescription(for: camera.settings.videoPerformanceMode))
                settingItem("Bitrate", CameraSettingDescriptions.bitrateDescription(for: camera.settings.bitrate))
                settingItem("Raw Audio", CameraSettingDescriptions.rawAudioDescription(for: camera.settings.rawAudio))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func cameraSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Settings")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                settingItem("Auto Power Down", CameraSettingDescriptions.autoPowerDownDescription(for: camera.settings.autoPowerDown))
                settingItem("Anti-Flicker", CameraSettingDescriptions.antiFlickerDescription(for: camera.settings.antiFlicker))
                settingItem("LCD Brightness", CameraSettingDescriptions.lcdBrightnessProfileDescription(for: camera.settings.lcdBrightness))
                settingItem("Language", CameraSettingDescriptions.languageDescription(for: camera.settings.language))
                settingItem("Beeps", CameraSettingDescriptions.beepsDescription(for: camera.settings.beeps))
                settingItem("LED", CameraSettingDescriptions.ledDescription(for: camera.settings.led))
                settingItem("Voice Control", camera.settings.voiceControl ? "On" : "Off")
                settingItem("Quick Capture", camera.settings.quickCapture ? "On" : "Off")
                settingItem("ProTune", camera.settings.protuneEnabled ? "On" : "Off")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func advancedSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced Settings")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                settingItem("ISO Max", CameraSettingDescriptions.isoMaxDescription(for: camera.settings.isoMax))
                settingItem("ISO Min", CameraSettingDescriptions.isoMinDescription(for: camera.settings.isoMin))
                settingItem("White Balance", CameraSettingDescriptions.whiteBalanceDescription(for: camera.settings.whiteBalance))
                settingItem("EV Compensation", CameraSettingDescriptions.evDescription(for: camera.settings.ev))

                if let turboMode = camera.status.turboMode {
                    settingItem("Turbo Mode", turboMode ? "On" : "Off")
                }
                settingItem("Shutter", CameraSettingDescriptions.shutterDescription(for: camera.settings.shutter))
                settingItem("Wind Noise", CameraSettingDescriptions.windDescription(for: camera.settings.wind))
                settingItem("Hindsight", CameraSettingDescriptions.hindsightDescription(for: camera.settings.hindsight))
                settingItem("Timer", CameraSettingDescriptions.timerDescription(for: camera.settings.timer))
                settingItem("GPS", camera.settings.gps ? "On" : "Off")
                settingItem("Max Lens", camera.settings.maxLens ? "On" : "Off")
                if let wifiBars = camera.status.wifiBars {
                    settingItem("WiFi Signal", "\(wifiBars) bars")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func systemSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System & Connectivity")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {

                if let mobileFriendly = camera.status.mobileFriendlyVideo {
                    systemDetailItem(
                        icon: mobileFriendly ? "iphone" : "iphone.slash",
                        title: "Mobile Friendly",
                        value: mobileFriendly ? "On" : "Off",
                        color: mobileFriendly ? .blue : .gray
                    )
                }

                if let turboTransfer = camera.status.turboTransfer {
                    systemDetailItem(
                        icon: turboTransfer ? "bolt.fill" : "bolt.slash",
                        title: "Turbo Transfer",
                        value: turboTransfer ? "On" : "Off",
                        color: turboTransfer ? .orange : .gray
                    )
                }

                if let cameraControl = camera.status.cameraControlStatus {
                    systemDetailItem(
                        icon: cameraControl ? "hand.raised.fill" : "hand.raised.slash",
                        title: "Camera Control",
                        value: cameraControl ? "On" : "Off",
                        color: cameraControl ? .green : .gray
                    )
                }

                if let allowControlOverUsb = camera.status.allowControlOverUsb {
                    systemDetailItem(
                        icon: allowControlOverUsb ? "cable.connector" : "cable.connector.slash",
                        title: "USB Control",
                        value: allowControlOverUsb ? "Allowed" : "Disabled",
                        color: allowControlOverUsb ? .purple : .gray
                    )
                }

                if let wifiBars = camera.status.wifiBars {
                    systemDetailItem(
                        icon: "wifi",
                        title: "WiFi Signal",
                        value: "\(wifiBars)/4",
                        color: .blue
                    )
                }

                if let connectedDevices = camera.status.connectedDevices {
                    systemDetailItem(
                        icon: "devices",
                        title: "Connected Devices",
                        value: "\(connectedDevices)",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statusSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status & Health")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                if let isReady = camera.status.isReady {
                    statusDetailItem(
                        icon: isReady ? "checkmark.circle.fill" : "xmark.circle.fill",
                        title: "Ready",
                        value: isReady ? "Yes" : "No",
                        color: isReady ? .green : .red
                    )
                }

                if let isBusy = camera.status.isBusy {
                    statusDetailItem(
                        icon: isBusy ? "hourglass" : "checkmark.circle",
                        title: "Busy",
                        value: isBusy ? "Yes" : "No",
                        color: isBusy ? .orange : .green
                    )
                }

                if let isOverheating = camera.status.isOverheating {
                    statusDetailItem(
                        icon: isOverheating ? "thermometer.sun.fill" : "thermometer",
                        title: "Overheating",
                        value: isOverheating ? "Yes" : "No",
                        color: isOverheating ? .red : .blue
                    )
                }

                if let isCold = camera.status.isCold {
                    statusDetailItem(
                        icon: isCold ? "thermometer.snowflake" : "thermometer",
                        title: "Cold Environment",
                        value: isCold ? "Yes" : "No",
                        color: isCold ? .blue : .gray
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func batteryDetailItem(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func mediaDetailItem(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func storageDetailItem(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func settingItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func systemDetailItem(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func statusDetailItem(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func additionalSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Settings")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                settingItem("Voice Language", "\(camera.settings.voiceLanguageControl)")
                settingItem("Privacy", "\(camera.settings.privacy)")
                settingItem("Auto Lock", "\(camera.settings.autoLock)")
                settingItem("Wake on Voice", camera.settings.wakeOnVoice ? "On" : "Off")
                settingItem("Video Compression", "\(camera.settings.videoCompression)")
                settingItem("Landscape Lock", "\(camera.settings.landscapeLock)")
                settingItem("Default Preset", "\(camera.settings.defaultPreset)")
                settingItem("Front LCD Mode", "\(camera.settings.frontLcdMode)")
                settingItem("GOP Size", "\(camera.settings.gopSize)")
                settingItem("IDR Interval", "\(camera.settings.idrInterval)")
                settingItem("Bit Rate Mode", "\(camera.settings.bitRateMode)")
                settingItem("Audio ProTune", camera.settings.audioProtune ? "On" : "Off")
                settingItem("No Audio Track", camera.settings.noAudioTrack ? "Yes" : "No")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Time Sync Helper Functions

    // Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    // Helper function to create human-readable time ago string
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)

        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Helper Functions
private func batteryColorFromPercentage(_ percentage: Int) -> Color {
    switch percentage {
    case 0...20: return .red
    case 21...50: return .orange
    case 51...80: return .yellow
    default: return .green
    }
}
