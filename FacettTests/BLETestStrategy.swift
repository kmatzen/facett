import XCTest
import CoreBluetooth
@testable import Facett

/// Base class for BLE-related tests
class BLETestBase: XCTestCase {
    var configManager: ConfigManager!
    var cameraGroupManager: CameraGroupManager!

    override func setUp() {
        super.setUp()
        configManager = ConfigManager()
        cameraGroupManager = CameraGroupManager(configManager: configManager)
    }

    override func tearDown() {
        configManager = nil
        cameraGroupManager = nil
        super.tearDown()
    }
}

/// Test data and utilities for BLE tests
struct TestData {
    static let sampleSettings: GoProSettingsData = {
        let settings = GoProSettingsData.defaultSettings()
        return settings
    }()

    static let sampleConfiguration: CameraConfig = {
        var config = CameraConfig(name: "Test Config", description: "Test configuration", isDefault: false)
        config.settings = sampleSettings
        return config
    }()
}
