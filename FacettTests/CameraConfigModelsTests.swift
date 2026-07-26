import XCTest
@testable import Facett

final class GoProSettingsDataTests: XCTestCase {

    func testDefaultSettingsRoundTripsThroughJSON() throws {
        let original = GoProSettingsData.defaultSettings()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GoProSettingsData.self, from: data)

        XCTAssertEqual(decoded.videoResolution, original.videoResolution)
        XCTAssertEqual(decoded.framesPerSecond, original.framesPerSecond)
        XCTAssertEqual(decoded.gps, original.gps)
        XCTAssertEqual(decoded.protuneEnabled, original.protuneEnabled)
        XCTAssertEqual(decoded.noAudioTrack, original.noAudioTrack)
        XCTAssertEqual(decoded.bitRateMode, original.bitRateMode)
    }

    func testInitFromGoProSettingsCopiesAllFields() {
        var settings = GoProSettings()
        settings.videoResolution = 7
        settings.framesPerSecond = 3
        settings.gps = !settings.gps
        settings.ev = 9
        settings.audioProtune = !settings.audioProtune
        settings.noAudioTrack = !settings.noAudioTrack

        let data = GoProSettingsData(from: settings)

        XCTAssertEqual(data.videoResolution, settings.videoResolution)
        XCTAssertEqual(data.framesPerSecond, settings.framesPerSecond)
        XCTAssertEqual(data.gps, settings.gps)
        XCTAssertEqual(data.ev, settings.ev)
        XCTAssertEqual(data.audioProtune, settings.audioProtune)
        XCTAssertEqual(data.noAudioTrack, settings.noAudioTrack)
    }

    func testToGoProSettingsRoundTripsAllFields() {
        var settings = GoProSettings()
        settings.videoResolution = 2
        settings.hindsight = 3
        settings.wakeOnVoice = !settings.wakeOnVoice
        settings.landscapeLock = 1
        settings.gopSize = 5
        settings.idrInterval = 2

        let data = GoProSettingsData(from: settings)
        let roundTripped = data.toGoProSettings()

        XCTAssertEqual(roundTripped.videoResolution, settings.videoResolution)
        XCTAssertEqual(roundTripped.hindsight, settings.hindsight)
        XCTAssertEqual(roundTripped.wakeOnVoice, settings.wakeOnVoice)
        XCTAssertEqual(roundTripped.landscapeLock, settings.landscapeLock)
        XCTAssertEqual(roundTripped.gopSize, settings.gopSize)
        XCTAssertEqual(roundTripped.idrInterval, settings.idrInterval)
    }
}

final class CameraConfigTests: XCTestCase {

    func testDefaultInitializerUsesDefaultSettings() {
        let config = CameraConfig(name: "My Config")
        XCTAssertEqual(config.name, "My Config")
        XCTAssertEqual(config.description, "")
        XCTAssertFalse(config.isDefault)
        let defaults = GoProSettingsData.defaultSettings()
        XCTAssertEqual(config.settings.videoResolution, defaults.videoResolution)
    }

    func testInitializerAssignsUniqueIds() {
        let first = CameraConfig(name: "A")
        let second = CameraConfig(name: "B")
        XCTAssertNotEqual(first.id, second.id)
    }

    func testInitFromGoProSettingsCapturesCurrentValues() {
        var settings = GoProSettings()
        settings.videoResolution = 3

        let config = CameraConfig(name: "Custom", description: "desc", isDefault: true, from: settings)
        XCTAssertEqual(config.name, "Custom")
        XCTAssertTrue(config.isDefault)
        XCTAssertEqual(config.settings.videoResolution, 3)
    }

    func testCameraConfigCodableRoundTrip() throws {
        let original = CameraConfig(name: "Codable", description: "roundtrip", isDefault: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CameraConfig.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.isDefault, original.isDefault)
        XCTAssertEqual(decoded.settings.videoResolution, original.settings.videoResolution)
    }
}
