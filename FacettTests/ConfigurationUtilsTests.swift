import XCTest
@testable import Facett

final class DefaultConfigurationsTests: XCTestCase {

    func testCreateDefaultConfigsReturnsFiveConfigs() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        XCTAssertEqual(configs.count, 5)
    }

    func testCreateDefaultConfigsHasExactlyOneDefault() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        let defaults = configs.filter { $0.isDefault }
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.first?.name, "Default")
    }

    func testCreateDefaultConfigsHasExpectedNames() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        let names = Set(configs.map { $0.name })
        XCTAssertEqual(names, ["Default", "Professional Video", "Action Sports", "Low Light", "Documentary"])
    }

    func testDefaultConfigMatchesGoProSettingsDefaults() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        guard let defaultConfig = configs.first(where: { $0.name == "Default" }) else {
            return XCTFail("Missing Default config")
        }
        let defaults = GoProSettingsData.defaultSettings()
        XCTAssertEqual(defaultConfig.settings.videoResolution, defaults.videoResolution)
        XCTAssertEqual(defaultConfig.settings.framesPerSecond, defaults.framesPerSecond)
        XCTAssertEqual(defaultConfig.settings.mode, defaults.mode)
    }

    func testProfessionalVideoConfigOverridesExpectedFields() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        guard let config = configs.first(where: { $0.name == "Professional Video" }) else {
            return XCTFail("Missing Professional Video config")
        }
        XCTAssertEqual(config.settings.videoResolution, 1)
        XCTAssertEqual(config.settings.colorProfile, 1)
        XCTAssertTrue(config.settings.protuneEnabled)
        XCTAssertEqual(config.settings.bitrate, 1)
    }

    func testActionSportsConfigOverridesExpectedFields() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        guard let config = configs.first(where: { $0.name == "Action Sports" }) else {
            return XCTFail("Missing Action Sports config")
        }
        XCTAssertEqual(config.settings.framesPerSecond, 1)
        XCTAssertTrue(config.settings.quickCapture)
        XCTAssertEqual(config.settings.ev, 5)
    }

    func testLowLightConfigOverridesExpectedFields() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        guard let config = configs.first(where: { $0.name == "Low Light" }) else {
            return XCTFail("Missing Low Light config")
        }
        XCTAssertEqual(config.settings.videoResolution, 4)
        XCTAssertEqual(config.settings.isoMax, 2)
        XCTAssertEqual(config.settings.isoMin, 6)
    }

    func testDocumentaryConfigOverridesExpectedFields() {
        let configs = DefaultConfigurations.createDefaultConfigs()
        guard let config = configs.first(where: { $0.name == "Documentary" }) else {
            return XCTFail("Missing Documentary config")
        }
        XCTAssertEqual(config.settings.colorProfile, 0)
        XCTAssertFalse(config.settings.protuneEnabled)
        XCTAssertTrue(config.settings.voiceControl)
    }

    func testFpsDescriptionKnownValues() {
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 0), "240.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 1), "120.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 2), "100.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 5), "60.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 6), "50.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 8), "30.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 9), "25.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 10), "24.0")
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 13), "200.0")
    }

    func testFpsDescriptionUnknownValue() {
        XCTAssertEqual(DefaultConfigurations.fpsDescription(for: 999), "Unknown")
    }
}

final class ConfigValidationTests: XCTestCase {

    func testValidateConfigReturnsWarningsAndErrorsWithoutCrashing() {
        // NOTE: SettingsValidator.ValidRanges is stale for several fields (antiFlicker,
        // rawAudio, hindsight, whiteBalance, ...) relative to the real, sparse GoPro
        // protocol value domains, so GoProSettingsData.defaultSettings() itself currently
        // fails validation. See https://github.com/kmatzen/facett/issues/94. This test
        // only exercises validateConfig's plumbing, not the accuracy of its range checks.
        let config = CameraConfig(name: "Test", description: "desc", isDefault: false)
        let result = ConfigValidation.validateConfig(config)
        XCTAssertEqual(result.isValid, result.errors.isEmpty)
    }

    func testValidateCurrentConfigWithNoSelectionFails() {
        let configManager = ConfigManager()
        configManager.selectedConfigId = nil
        let result = ConfigValidation.validateCurrentConfig(configManager)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors, ["No configuration selected"])
    }

    // MARK: - hasSettingsMismatch

    func testHasSettingsMismatchReturnsFalseWhenSettingsMatch() {
        let gopro = GoPro(identifier: UUID(), name: "Test Camera")
        let target = gopro.settings
        XCTAssertFalse(ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: target))
    }

    func testHasSettingsMismatchReturnsTrueWhenVideoResolutionDiffers() {
        let gopro = GoPro(identifier: UUID(), name: "Test Camera")
        var target = gopro.settings
        target.videoResolution = gopro.settings.videoResolution + 1
        XCTAssertTrue(ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: target))
    }

    func testHasSettingsMismatchReturnsTrueWhenGpsDiffers() {
        let gopro = GoPro(identifier: UUID(), name: "Test Camera")
        var target = gopro.settings
        target.gps = !gopro.settings.gps
        XCTAssertTrue(ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: target))
    }

    func testHasSettingsMismatchIgnoresShutterDifference() {
        let gopro = GoPro(identifier: UUID(), name: "Test Camera")
        var target = gopro.settings
        target.shutter = gopro.settings.shutter + 1
        XCTAssertFalse(ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: target))
    }

    func testHasSettingsMismatchSkippedWhileEncoding() {
        let gopro = GoPro(identifier: UUID(), name: "Test Camera")
        gopro.status.isEncoding = true
        var target = gopro.settings
        target.videoResolution = gopro.settings.videoResolution + 1
        XCTAssertFalse(ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: target))
    }
}
