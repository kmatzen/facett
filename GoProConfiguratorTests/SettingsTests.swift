import XCTest
@testable import Facett

final class SettingsTests: XCTestCase {
    var configManager: ConfigManager!
    var cameraGroupManager: CameraGroupManager!
    var settingsValidator: SettingsValidator!

    override func setUp() {
        super.setUp()
        configManager = ConfigManager()
        cameraGroupManager = CameraGroupManager(configManager: configManager)
        settingsValidator = SettingsValidator.shared
    }

    override func tearDown() {
        configManager = nil
        cameraGroupManager = nil
        settingsValidator = nil
        super.tearDown()
    }

    // MARK: - Basic Tests

    func testConfigManagerInitialization() {
        XCTAssertNotNil(configManager, "ConfigManager should be initialized")
        XCTAssertNotNil(configManager.configs, "ConfigManager should have configs property")
    }

    func testCameraGroupManagerInitialization() {
        XCTAssertNotNil(cameraGroupManager, "CameraGroupManager should be initialized")
        XCTAssertNotNil(cameraGroupManager.cameraGroups, "CameraGroupManager should have cameraGroups property")
    }

    func testSettingsValidatorInitialization() {
        XCTAssertNotNil(settingsValidator, "SettingsValidator should be initialized")
    }

    // MARK: - Simple Settings Tests

    func testDefaultSettings() {
        let settings = GoProSettingsData.defaultSettings()
        XCTAssertNotNil(settings, "Default settings should be created")
    }

    func testSettingsValidatorWithDefaultSettings() {
        // Create settings with valid values that are within the validator's ranges
        let validSettings = GoProSettingsData(
            videoResolution: 1, // 4K (valid: 0...4)
            framesPerSecond: 5, // 60 FPS (valid: 0...13)
            videoLens: 0, // Wide (valid: 0...2)
            antiFlicker: 0, // 50 Hz (valid: 0...1)
            hypersmooth: 0, // Off (valid: 0...2)
            maxLens: false,
            videoPerformanceMode: 0, // Maximum Performance (valid: 0...1)
            colorProfile: 1, // Flat (valid: 0...1)
            bitrate: 1, // High (valid: 0...1)
            mode: 0, // Video (valid: 0...1)
            shutter: 0, // Auto (valid: 0...1)
            ev: 4, // Neutral (valid: 0...5)
            rawAudio: 0, // Off (valid: 0...1)
            autoPowerDown: 7, // 30 minutes (valid: 0...7)
            gps: true,
            quickCapture: false,
            voiceControl: false,
            hindsight: 0, // Off (valid: 0...1)
            wind: 0, // Off (valid: 0...1)
            isoMax: 1, // 1600 (valid: 0...2)
            isoMin: 8, // 100 (valid: 0...8)
            whiteBalance: 0, // Auto (valid: 0...1)
            protuneEnabled: true,
            lcdBrightness: 2, // 100% (valid: 0...2)
            language: 0, // English (valid: 0...1)
            beeps: 0, // Off (valid: 0...2)
            led: 2, // Off (valid: 0...2)
            voiceLanguageControl: 0, // English (valid: 0...1)
            privacy: 0, // (valid: 0...1)
            autoLock: 0, // (valid: 0...1)
            wakeOnVoice: false,
            timer: 0, // (valid: 0...1)
            videoCompression: 0, // (valid: 0...1)
            landscapeLock: 0, // (valid: 0...1)
            screenSaverFront: 0, // (valid: 0...1)
            screenSaverRear: 0, // (valid: 0...1)
            defaultPreset: 0, // (valid: 0...1)
            frontLcdMode: 0, // (valid: 0...1)
            gopSize: 0, // (valid: 0...1)
            idrInterval: 0, // (valid: 0...1)
            bitRateMode: 0, // (valid: 0...1)
            audioProtune: false,
            noAudioTrack: false
        )

        do {
            try settingsValidator.validateSettings(validSettings)
            // If we get here, validation passed
            XCTAssertTrue(true, "Valid settings should pass validation")
        } catch {
            XCTFail("Valid settings should not throw validation error: \(error)")
        }
    }

    // MARK: - Configuration Management Tests

    func testCreateConfiguration() {
        let settings = GoProSettingsData.defaultSettings()

        var config = CameraConfig(name: "Test Config", description: "Test configuration", isDefault: false)
        config.settings = settings
        configManager.addConfig(config)

        let createdConfig = configManager.configs.first { $0.name == "Test Config" }

        XCTAssertNotNil(createdConfig, "Configuration should be created")
        XCTAssertEqual(createdConfig?.name, "Test Config", "Configuration name should match")
    }

        func testDeleteConfiguration() {
        let settings = GoProSettingsData.defaultSettings()

        var config = CameraConfig(name: "Delete Test Config", description: "Test configuration", isDefault: false)
        config.settings = settings
        configManager.addConfig(config)

        let initialCount = configManager.configs.count
        let configToDelete = configManager.configs.first { $0.name == "Delete Test Config" }

        XCTAssertNotNil(configToDelete, "Configuration should exist before deletion")

        configManager.deleteConfig(configToDelete!.id)

        let finalCount = configManager.configs.count
        XCTAssertEqual(finalCount, initialCount - 1, "Configuration should be deleted")
    }

    // MARK: - Camera Group Management Tests

    func testCreateCameraGroup() {
        cameraGroupManager.addCameraGroup(name: "Test Group")

        let createdGroup = cameraGroupManager.cameraGroups.first { $0.name == "Test Group" }

        XCTAssertNotNil(createdGroup, "Camera group should be created")
        XCTAssertEqual(createdGroup?.name, "Test Group", "Camera group name should match")
        XCTAssertEqual(createdGroup?.cameraIds.count, 0, "New camera group should have no cameras")
    }

    func testDeleteCameraGroup() {
        cameraGroupManager.addCameraGroup(name: "Delete Test Group")

        let initialCount = cameraGroupManager.cameraGroups.count
        let groupToDelete = cameraGroupManager.cameraGroups.first { $0.name == "Delete Test Group" }

        XCTAssertNotNil(groupToDelete, "Camera group should exist before deletion")

        cameraGroupManager.removeCameraGroup(groupToDelete!)

        let finalCount = cameraGroupManager.cameraGroups.count
        XCTAssertEqual(finalCount, initialCount - 1, "Camera group should be deleted")
    }
}
