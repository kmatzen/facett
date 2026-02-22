import XCTest

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
        snapshot("01-Dashboard")

        let configurationsText = app.staticTexts["Configurations"]
        if configurationsText.exists {
            configurationsText.tap()
            sleep(1)
            snapshot("02-Configurations")
            dismissSheet()
        }

        let cameraGroupsText = app.staticTexts["Camera Groups"]
        if cameraGroupsText.exists {
            cameraGroupsText.tap()
            sleep(1)
            snapshot("03-CameraGroups")
            dismissSheet()
        }

        let bugReportsText = app.staticTexts["Bug Reports"]
        if bugReportsText.exists {
            bugReportsText.tap()
            sleep(1)
            snapshot("04-BugReport")
            dismissSheet()
        }
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
