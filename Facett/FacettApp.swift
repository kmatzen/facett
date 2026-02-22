import SwiftUI

@main
struct FacettApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject var bleManager = BLEManager()
    @StateObject var configManager: ConfigManager
    @StateObject var cameraGroupManager: CameraGroupManager

    init() {
        // Initialize crash reporter
        _ = CrashReporter.shared

        let configManager = ConfigManager()
        self._configManager = StateObject(wrappedValue: configManager)
        self._cameraGroupManager = StateObject(wrappedValue: CameraGroupManager(configManager: configManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                bleManager: bleManager,
                cameraGroupManager: cameraGroupManager,
                configManager: configManager
            )
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                UIApplication.shared.isIdleTimerDisabled = true
            default:
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
}
