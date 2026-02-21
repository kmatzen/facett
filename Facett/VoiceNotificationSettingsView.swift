import SwiftUI

struct VoiceNotificationSettingsView: View {
    @ObservedObject var voiceNotificationManager = VoiceNotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice Notifications")) {
                    Toggle("Enable Voice Notifications", isOn: $voiceNotificationManager.voiceNotificationsEnabled)
                        .onChange(of: voiceNotificationManager.voiceNotificationsEnabled) { newValue in
                            voiceNotificationManager.setVoiceNotificationsEnabled(newValue)
                        }

                    if voiceNotificationManager.voiceNotificationsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Voice notifications will announce:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Recording start/stop", systemImage: "record.circle")
                                Label("Recording errors", systemImage: "exclamationmark.triangle")
                                Label("Camera connections", systemImage: "wifi")
                                Label("Settings sync completion", systemImage: "gear")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }

                Section(header: Text("Test Voice Notifications")) {
                    Button("Test Recording Started") {
                        voiceNotificationManager.notifyRecordingStarted(cameraCount: 2)
                    }
                    .disabled(!voiceNotificationManager.voiceNotificationsEnabled)

                    Button("Test Recording Stopped") {
                        voiceNotificationManager.notifyRecordingStopped(cameraCount: 2)
                    }
                    .disabled(!voiceNotificationManager.voiceNotificationsEnabled)

                    Button("Test Recording Error") {
                        voiceNotificationManager.notifyRecordingError(cameraName: "Front Camera", error: "SD card full")
                    }
                    .disabled(!voiceNotificationManager.voiceNotificationsEnabled)

                    Button("Test Camera Connected") {
                        voiceNotificationManager.notifyCameraConnected(cameraName: "GoPro Hero 11")
                    }
                    .disabled(!voiceNotificationManager.voiceNotificationsEnabled)
                }

                Section(header: Text("About"), footer: Text("Voice notifications use text-to-speech to announce important events when you're focused on filming and can't look at the screen.")) {
                    HStack {
                        Text("Voice Engine")
                        Spacer()
                        Text("AVSpeechSynthesizer")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Language")
                        Spacer()
                        Text("English (US)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Voice Notifications")
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
}

#Preview {
    VoiceNotificationSettingsView()
}
