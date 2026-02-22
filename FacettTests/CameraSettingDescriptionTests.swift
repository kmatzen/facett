import XCTest
@testable import Facett

final class CameraSettingDescriptionTests: XCTestCase {

    // MARK: - Resolution

    func testResolutionKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.resolutionDescription(for: 1), "4K")
        XCTAssertEqual(CameraSettingDescriptions.resolutionDescription(for: 9), "1080")
        XCTAssertEqual(CameraSettingDescriptions.resolutionDescription(for: 100), "5.3K")
    }

    func testResolutionUnknownValue() {
        XCTAssertEqual(CameraSettingDescriptions.resolutionDescription(for: 999), "Unknown")
    }

    // MARK: - FPS

    func testFPSKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.fpsDescription(for: 0), "240.0")
        XCTAssertEqual(CameraSettingDescriptions.fpsDescription(for: 5), "60.0")
        XCTAssertEqual(CameraSettingDescriptions.fpsDescription(for: 8), "30.0")
        XCTAssertEqual(CameraSettingDescriptions.fpsDescription(for: 10), "24.0")
    }

    func testFPSUnknownValue() {
        XCTAssertEqual(CameraSettingDescriptions.fpsDescription(for: -1), "Unknown")
    }

    // MARK: - Mode

    func testModeKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.modeDescription(for: 12), "Video")
        XCTAssertEqual(CameraSettingDescriptions.modeDescription(for: 17), "Photo")
    }

    func testModeUnknownValue() {
        XCTAssertEqual(CameraSettingDescriptions.modeDescription(for: 0), "Unknown")
    }

    // MARK: - Lens

    func testLensKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.lensDescription(for: 0), "Wide")
        XCTAssertEqual(CameraSettingDescriptions.lensDescription(for: 4), "Linear")
    }

    func testLensUnknownValue() {
        XCTAssertEqual(CameraSettingDescriptions.lensDescription(for: 99), "Unknown")
    }

    // MARK: - Hypersmooth

    func testHypersmoothKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.hypersmoothDescription(for: 0), "Off")
        XCTAssertEqual(CameraSettingDescriptions.hypersmoothDescription(for: 1), "Low")
        XCTAssertEqual(CameraSettingDescriptions.hypersmoothDescription(for: 2), "High")
        XCTAssertEqual(CameraSettingDescriptions.hypersmoothDescription(for: 3), "Boost")
    }

    // MARK: - White Balance

    func testWhiteBalanceKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.whiteBalanceDescription(for: 0), "Auto")
        XCTAssertEqual(CameraSettingDescriptions.whiteBalanceDescription(for: 5), "4000K")
    }

    // MARK: - EV

    func testEVKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.evDescription(for: 4), "0.0")
        XCTAssertEqual(CameraSettingDescriptions.evDescription(for: 8), "-2.0")
        XCTAssertEqual(CameraSettingDescriptions.evDescription(for: 0), "2.0")
    }

    // MARK: - Anti-Flicker

    func testAntiFlickerKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.antiFlickerDescription(for: 2), "60Hz")
        XCTAssertEqual(CameraSettingDescriptions.antiFlickerDescription(for: 3), "50Hz")
    }

    // MARK: - Auto Power Down

    func testAutoPowerDownKnownValues() {
        XCTAssertEqual(CameraSettingDescriptions.autoPowerDownDescription(for: 0), "Never")
        XCTAssertEqual(CameraSettingDescriptions.autoPowerDownDescription(for: 4), "5 Min")
        XCTAssertEqual(CameraSettingDescriptions.autoPowerDownDescription(for: 6), "15 Min")
    }
}
