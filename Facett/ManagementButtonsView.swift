import SwiftUI

// MARK: - Management Button Component
struct ManagementButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )

                // Title and Subtitle
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Management Buttons View
struct ManagementButtonsView: View {
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var configManager: ConfigManager
    @Binding var showingCameraGroupManagement: Bool
    @Binding var showingConfigManagement: Bool
    @Binding var showingVoiceNotificationSettings: Bool
    @Binding var showingBugReportForm: Bool
    @Binding var showingAbout: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ManagementButton(
                    title: "Camera Groups",
                    subtitle: "\(cameraGroupManager.cameraGroups.count) groups",
                    icon: "camera.on.rectangle.fill",
                    color: .blue,
                    action: { showingCameraGroupManagement = true }
                )

                ManagementButton(
                    title: "Configurations",
                    subtitle: "\(configManager.configs.count) configs",
                    icon: "gearshape.2.fill",
                    color: .orange,
                    action: { showingConfigManagement = true }
                )
            }

            HStack(spacing: 12) {
                ManagementButton(
                    title: "Voice Notifications",
                    subtitle: "Settings",
                    icon: "speaker.wave.2.fill",
                    color: .purple,
                    action: { showingVoiceNotificationSettings = true }
                )

                ManagementButton(
                    title: "Bug Reports",
                    subtitle: "Report Issues",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    action: { showingBugReportForm = true }
                )
            }

            HStack(spacing: 12) {
                ManagementButton(
                    title: "About",
                    subtitle: "Info & Legal",
                    icon: "info.circle.fill",
                    color: .gray,
                    action: { showingAbout = true }
                )
            }
        }
    }
}

// MARK: - Action Buttons View
struct ActionButtonsView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var speechManager: SpeechManager

    var body: some View {
        VStack(spacing: 10) {
            // Commented out advanced features - can be re-enabled if needed
            /*
            ActionButton(label: "Power Down All", color: .red) {
                bleManager.powerDownAllDevices()
            }

            HStack {
                ActionButton(label: "Enable AP All", color:.green) {
                    bleManager.enableAPAllDevices()
                }
                ActionButton(label: "Disable AP All", color:.red) {
                    bleManager.disableAPAllDevices()
                }
            }

            HStack {
                ActionButton(label: "Enable Turbo Transfer All", color:.green) {
                    bleManager.enableTurboTransferAllDevices()
                }
                ActionButton(label: "Disable Turbo Transfer All", color:.red) {
                    bleManager.disableTurboTransferAllDevices()
                }
            }
            */
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        TimeoutButton(label: label, color: color, action: {
            triggerHapticFeedback() // Add haptic feedback
            action() // Perform the button's action
        }, font: .body, padding: 8, cornerRadius: 10, timeout: 1, maxWidth: .infinity) {
            EmptyView()
        }
        .contentShape(Rectangle()) // Ensures the button's hit area is large enough
    }

    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Timeout Button
struct TimeoutButton<Content: View>: View {
    let label: String
    let color: Color
    let action: () -> Void
    let font: Font
    let padding: CGFloat
    let cornerRadius: CGFloat
    let timeout: TimeInterval
    let maxWidth: CGFloat?
    @ViewBuilder let content: Content

    @State private var isDisabled = false
    @State private var showSpinner = false

    var body: some View {
        Button(action: handlePress) {
            HStack {
                if showSpinner {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    content // Use custom content when not showing spinner
                }
                if !label.isEmpty {
                    Text(label)
                        .font(font)
                }
            }
            .padding(padding)
            .frame(maxWidth: maxWidth)
            .background(isDisabled ? color.opacity(0.5) : color)
            .foregroundColor(.white)
            .cornerRadius(cornerRadius)
        }
        .disabled(isDisabled)
    }

    private func handlePress() {
        action()
        isDisabled = true
        showSpinner = true

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            isDisabled = false
            showSpinner = false
        }
    }
}

// MARK: - Toggle View
struct ToggleView: View {
    @Binding var show: Bool
    let label: String

    var body: some View {
        TimeoutButton(
            label: show ? "Hide \(label)" : "Show \(label)",
            color: .blue,
            action: {
                triggerHapticFeedback() // Add haptic feedback
                show.toggle() // Toggle the state
            },
            font: .caption,
            padding: 8,
            cornerRadius: 5,
            timeout: 0,
            maxWidth: nil
        ) {
            EmptyView()
        }
    }

    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
