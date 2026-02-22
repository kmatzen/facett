import XCTest

@MainActor
final class SnapshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testScreenshots() {
        snapshot("01-Dashboard")

        if app.buttons["Configurations"].exists {
            app.buttons["Configurations"].tap()
            sleep(1)
            snapshot("02-Configurations")

            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
            sleep(1)
        }

        if app.buttons["Camera Groups"].exists {
            app.buttons["Camera Groups"].tap()
            sleep(1)
            snapshot("03-CameraGroups")

            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
            sleep(1)
        }

        if app.buttons["Bug Report"].exists {
            app.buttons["Bug Report"].tap()
            sleep(1)
            snapshot("04-BugReport")

            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
            sleep(1)
        }
    }
}
