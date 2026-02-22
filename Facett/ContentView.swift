import SwiftUI

// MARK: - ContentView
struct ContentView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var cameraGroupManager: CameraGroupManager
    @ObservedObject var configManager: ConfigManager
    @State private var showQr = false
    @State private var selectedDevice: IdentifiableUUID? = nil
    @State var enterKeyHandler = EnterKeyHandler()
    @StateObject private var speechManager = SpeechManager()
    @State private var recordAll: Bool = false
    @State private var showingCameraGroupManagement = false
    @State private var showingConfigManagement = false
    @State private var showingVoiceNotificationSettings = false
    @State private var showingBugReportForm = false
    @State private var showingAbout = false
    @State private var autoSyncTimer: Timer?
    @State private var syncRotation: Double = 0
    @State private var showModeMismatchModal = false
    @State private var modeMismatchCameras: [GoPro] = []

    // MARK: - Helper Functions

    private func checkAndNotifyModeMismatches() {
        let mismatchedCameras = checkForModeMismatches()

        if !mismatchedCameras.isEmpty && !showModeMismatchModal {
            modeMismatchCameras = mismatchedCameras
            showModeMismatchModal = true
        }
    }

    private func checkForModeMismatches() -> [GoPro] {
        let group = cameraGroupManager.effectiveGroup(bleManager: bleManager)
        let camerasToCheck = group.cameraIds.compactMap { bleManager.connectedGoPros[$0] }

        let mismatchedCameras = camerasToCheck.filter { camera in
            if camera.status.isEncoding == true {
                return false
            }
            return camera.settings.mode != 12
        }

        if mismatchedCameras.isEmpty {
            ErrorHandler.debug("Mode mismatch check: all \(camerasToCheck.count) cameras in video mode")
        } else {
            ErrorHandler.info(
                "Mode Mismatch Detected",
                context: [
                    "mismatched_count": mismatchedCameras.count,
                    "total_checked": camerasToCheck.count,
                    "mismatched_cameras": mismatchedCameras.map { camera in
                        let name = CameraIdentityManager.shared.getDisplayName(for: camera.peripheral.identifier, currentName: camera.name)
                        return "\(name): mode \(camera.settings.mode)"
                    }
                ]
            )
        }

        return mismatchedCameras
    }

    private func handleRecordingAction() {
        let mismatchedCameras = checkForModeMismatches()

        if !mismatchedCameras.isEmpty {
            modeMismatchCameras = mismatchedCameras
            showModeMismatchModal = true
        } else {
            ErrorHandler.info("Starting recording for group")
            let group = cameraGroupManager.effectiveGroup(bleManager: bleManager)
            bleManager.startRecordingForCamerasInSet(group.cameraSerials)
        }
    }

    private func createModeMismatchMessage() -> String {
        let cameraNames = modeMismatchCameras.map { camera in
            CameraIdentityManager.shared.getDisplayName(for: camera.peripheral.identifier, currentName: camera.name)
        }.joined(separator: ", ")

        return "The following cameras are not in video mode " +
            "and need to be manually switched:\n\n\(cameraNames)\n\n" +
            "Please use the camera's physical controls to switch " +
            "them to video mode, then try recording again."
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                    VStack(spacing: 0) {
                        // Recording Controls at the very top
                        RecordingControlsView(
                            bleManager: bleManager,
                            cameraGroupManager: cameraGroupManager,
                            speechManager: speechManager,
                            configManager: configManager,
                            handleRecordingAction: handleRecordingAction
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)

                        if isLandscape {
                            HStack {
                                ScrollView {
                                    VStack {
                                        VStack(spacing: 20) {
                                            deviceListSection
                                        }
                                    }
                                    .padding(.horizontal, 2) // Apply 2 points of padding to leading and trailing sides
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(width: geometry.size.width * 0.55) // Left column (wider)

                                ScrollView {
                                    VStack {
                                        VStack(spacing: 20) {
                                            mainContentSection
                                        }
                                    }
                                    .padding(.horizontal, 2) // Apply 2 points of padding to leading and trailing sides
                                    .frame(alignment: .trailing)
                                }
                                .frame(width: geometry.size.width * 0.45) // Right column (narrower)
                            }
                        } else {
                            ScrollView {
                                VStack {
                                    VStack(spacing: 20) {
                                        deviceListSection
                                        mainContentSection
                                    }
                                }
                                .padding()
                            }
                        }
                    }

                    EnterKeyHandlerView(enterKeyHandler: enterKeyHandler)
                        .frame(width: 0, height: 0)
                }
                .onAppear {
                    QRCodeResources.initialize() // Trigger proactive initialization

                    // Setup callback for immediate sync when camera status is updated
                    bleManager.onCameraStatusUpdated = { [weak configManager, weak bleManager, weak cameraGroupManager] cameraId in
                        guard let configManager = configManager,
                              let bleManager = bleManager,
                              let cameraGroupManager = cameraGroupManager else { return }

                        ErrorHandler.debug("Camera '\(cameraId)' received initial status - triggering sync check")
                        configManager.checkAndTriggerAutoSync(bleManager: bleManager, cameraGroupManager: cameraGroupManager)

                        // Check for mode mismatches and show modal if needed
                        DispatchQueue.main.async {
                            self.checkAndNotifyModeMismatches()
                        }
                    }

                    // Setup auto-sync timer
                    autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                        configManager.checkAndTriggerAutoSync(bleManager: bleManager, cameraGroupManager: cameraGroupManager)

                        // Also check for mode mismatches periodically
                        DispatchQueue.main.async {
                            self.checkAndNotifyModeMismatches()
                        }
                    }

                    speechManager.onStartCommand = {
                        ErrorHandler.info("Voice command 'start' detected")
                        let group = cameraGroupManager.effectiveGroup(bleManager: bleManager)
                        bleManager.startRecordingForCamerasInSet(group.cameraSerials)
                        recordAll = true
                    }

                    speechManager.onStopCommand = {
                        ErrorHandler.info("Voice command 'stop' detected")
                        let group = cameraGroupManager.effectiveGroup(bleManager: bleManager)
                        bleManager.stopRecordingForCamerasInSet(group.cameraSerials)
                        recordAll = false
                    }

                    enterKeyHandler.enterKeyAction = {
                        ErrorHandler.info("Enter key detected!")
                        let group = cameraGroupManager.effectiveGroup(bleManager: bleManager)
                        if recordAll {
                            ErrorHandler.info("Stopping recording on all devices")
                            bleManager.stopRecordingForCamerasInSet(group.cameraSerials)
                            recordAll = false
                        } else {
                            ErrorHandler.info("Starting recording on all devices")
                            bleManager.startRecordingForCamerasInSet(group.cameraSerials)
                            recordAll = true
                        }
                    }
                }
                .onDisappear {
                    enterKeyHandler.enterKeyAction = nil
                    autoSyncTimer?.invalidate()
                    autoSyncTimer = nil
                    bleManager.onCameraStatusUpdated = nil
                }
        }
    }

    private var mainContentSection: some View {
        VStack(spacing: 20) {
            ActiveGroupSummaryView(
                set: cameraGroupManager.effectiveGroup(bleManager: bleManager),
                cameraGroupManager: cameraGroupManager,
                bleManager: bleManager,
                configManager: configManager
            )

            // Management Buttons - Modern Design
            ManagementButtonsView(
                cameraGroupManager: cameraGroupManager,
                configManager: configManager,
                showingCameraGroupManagement: $showingCameraGroupManagement,
                showingConfigManagement: $showingConfigManagement,
                showingVoiceNotificationSettings: $showingVoiceNotificationSettings,
                showingBugReportForm: $showingBugReportForm,
                showingAbout: $showingAbout
            )

            // QR Code Section - Prominent placement
            QRCodeSection(showQr: $showQr, configManager: configManager)

            // Other action buttons and controls
            ActionButtonsView(bleManager: bleManager, cameraGroupManager: cameraGroupManager, speechManager: speechManager)

            Spacer()
        }
    }

    private var deviceListSection: some View {
        VStack(spacing: 16) {
        }
        .sheet(isPresented: $showingCameraGroupManagement) {
            CameraGroupManagementView(
                cameraGroupManager: cameraGroupManager,
                bleManager: bleManager
            )
        }
        .sheet(isPresented: $showingConfigManagement) {
            ConfigManagementView(
                configManager: configManager,
                cameraGroupManager: cameraGroupManager,
                bleManager: bleManager
            )
        }
        .sheet(isPresented: $showingVoiceNotificationSettings) {
            VoiceNotificationSettingsView()
        }
        .sheet(isPresented: $showingBugReportForm) {
            BugReportView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert("Camera Mode Mismatch", isPresented: $showModeMismatchModal) {
            Button("OK") {
                showModeMismatchModal = false
            }
        } message: {
            Text(createModeMismatchMessage())
        }
    }
}

// MARK: - IdentifiableUUID
struct IdentifiableUUID: Identifiable {
    let id: UUID
}
