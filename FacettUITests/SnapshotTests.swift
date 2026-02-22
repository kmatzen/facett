import XCTest
import SnapshotTesting

@MainActor
final class SnapshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-DEMO_MODE"]
        setupSnapshot(app)
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testScreenshots() {
        assertScreenshot("01-Dashboard")

        let configurationsText = app.staticTexts["Configurations"]
        if configurationsText.exists {
            configurationsText.tap()
            sleep(1)
            assertScreenshot("02-Configurations")
            dismissSheet()
        }

        let cameraGroupsText = app.staticTexts["Camera Groups"]
        if cameraGroupsText.exists {
            cameraGroupsText.tap()
            sleep(1)
            assertScreenshot("03-CameraGroups")
            dismissSheet()
        }

        let bugReportsText = app.staticTexts["Bug Reports"]
        if bugReportsText.exists {
            bugReportsText.tap()
            sleep(1)
            assertScreenshot("04-BugReport")
            dismissSheet()
        }
    }

    // MARK: - Helpers

    /// Captures a fastlane screenshot and asserts visual regression via swift-snapshot-testing.
    private func assertScreenshot(_ name: String, precision: Float = 0.995, perceptualPrecision: Float = 0.98, file: StaticString = #file, testName: String = #function, line: UInt = #line) {
        snapshot(name)
        let image = XCUIScreen.main.screenshot().image
        assertSnapshot(
            of: image,
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    private func dismissSheet() {
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        } else {
            app.swipeDown()
            sleep(1)
        }
    }
}
