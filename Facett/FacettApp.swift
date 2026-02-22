import SwiftUI

@main
struct FacettApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject var bleManager = BLEManager()
    @StateObject var configManager: ConfigManager
    @StateObject var cameraGroupManager: CameraGroupManager

    static var isDemoMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-DEMO_MODE")
    }

    init() {
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
            .onAppear {
                if FacettApp.isDemoMode {
                    DemoDataProvider.populate(
                        bleManager: bleManager,
                        cameraGroupManager: cameraGroupManager,
                        configManager: configManager
                    )
                }
            }
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

// MARK: - Demo Data Provider
enum DemoDataProvider {
    struct DemoCamera {
        let uuid: UUID
        let name: String
        let serial: String
        let battery: Int
        let sdRemaining: Int64
        let isEncoding: Bool
        let encodingDuration: Int32
    }

    static let cameras: [DemoCamera] = [
        DemoCamera(uuid: UUID(), name: "GoPro 0841", serial: "GP0841",
                   battery: 87, sdRemaining: 58_000_000, isEncoding: true, encodingDuration: 127),
        DemoCamera(uuid: UUID(), name: "GoPro 2759", serial: "GP2759",
                   battery: 64, sdRemaining: 42_000_000, isEncoding: true, encodingDuration: 127),
        DemoCamera(uuid: UUID(), name: "GoPro 4103", serial: "GP4103",
                   battery: 93, sdRemaining: 110_000_000, isEncoding: true, encodingDuration: 127),
        DemoCamera(uuid: UUID(), name: "GoPro 6287", serial: "GP6287",
                   battery: 51, sdRemaining: 31_000_000, isEncoding: true, encodingDuration: 127),
        DemoCamera(uuid: UUID(), name: "GoPro 9520", serial: "GP9520",
                   battery: 78, sdRemaining: 72_000_000, isEncoding: false, encodingDuration: 0),
    ]

    static func populate(bleManager: BLEManager, cameraGroupManager: CameraGroupManager, configManager: ConfigManager) {
        for cam in cameras {
            let gopro = GoPro(identifier: cam.uuid, name: cam.name)
            gopro.hasControl = true
            gopro.hasReceivedInitialStatus = true
            gopro.settings.mode = 12 // video mode

            gopro.status.batteryPercentage = cam.battery
            gopro.status.batteryLevel = cam.battery / 25
            gopro.status.isBatteryPresent = true
            gopro.status.sdCardRemaining = cam.sdRemaining
            gopro.status.isReady = true
            gopro.status.isEncoding = cam.isEncoding
            gopro.status.videoEncodingDuration = cam.encodingDuration
            gopro.status.wifiBars = 3
            gopro.status.isOverheating = false
            gopro.status.isBusy = false
            gopro.status.isCold = false
            gopro.status.apSSID = cam.serial

            CameraSerialResolver.shared.storeUUID(cam.uuid, forSerial: cam.serial)
            CameraIdentityManager.shared.storeCameraName(cam.name, forSerial: cam.serial)

            bleManager.connectedGoPros[cam.uuid] = gopro
        }

        let serials = Set(cameras.map(\.serial))
        let mainGroup = CameraGroup(name: "Main Setup", cameraSerials: serials, configId: configManager.configs.first?.id)
        cameraGroupManager.cameraGroups = [mainGroup]
        cameraGroupManager.setActiveGroup(mainGroup)
    }
}
