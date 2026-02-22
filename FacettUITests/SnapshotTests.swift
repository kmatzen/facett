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

        app.swipeUp()
        sleep(1)

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

        app.swipeDown()
        sleep(1)

        let cameraCard = app.staticTexts["GoPro 0841"]
        if cameraCard.exists {
            cameraCard.tap()
            sleep(2)
            assertScreenshot("05-CameraDetails")
            dismissSheet()
        }
    }

    func testEditConfigScreenshot() {
        app.swipeUp()
        sleep(1)

        let configurationsText = app.staticTexts["Configurations"]
        if configurationsText.exists {
            configurationsText.tap()
            sleep(1)

            let actionsButton = app.buttons.matching(identifier: "Config Actions").firstMatch
            if actionsButton.waitForExistence(timeout: 3) {
                actionsButton.tap()
                sleep(1)
                let editButton = app.buttons["Edit"]
                if editButton.waitForExistence(timeout: 3) {
                    editButton.tap()
                    sleep(1)
                    assertScreenshot("06-EditConfiguration")
                }
            }
        }
    }

    func testEditCameraGroupScreenshot() {
        app.swipeUp()
        sleep(1)

        let cameraGroupsText = app.staticTexts["Camera Groups"]
        if cameraGroupsText.exists {
            cameraGroupsText.tap()
            sleep(1)

            let ellipsisButton = app.buttons["Group Actions"]
            if ellipsisButton.waitForExistence(timeout: 3) {
                ellipsisButton.tap()
                sleep(1)
                let editButton = app.buttons["Edit"]
                if editButton.waitForExistence(timeout: 3) {
                    editButton.tap()
                    sleep(1)
                    assertScreenshot("07-EditCameraGroup")
                }
            }
        }
    }

    func testAddCameraScreenshot() {
        app.swipeUp()
        sleep(1)

        let cameraGroupsText = app.staticTexts["Camera Groups"]
        if cameraGroupsText.exists {
            cameraGroupsText.tap()
            sleep(1)

            let ellipsisButton = app.buttons["Group Actions"]
            if ellipsisButton.waitForExistence(timeout: 3) {
                ellipsisButton.tap()
                sleep(1)
                let editButton = app.buttons["Edit"]
                if editButton.waitForExistence(timeout: 3) {
                    editButton.tap()
                    sleep(1)

                    let addCameraButton = app.buttons["AddCameraButton"]
                    if addCameraButton.waitForExistence(timeout: 3) {
                        addCameraButton.tap()
                        sleep(1)
                        assertScreenshot("08-AddCamera")
                    }
                }
            }
        }
    }

    func testAddCameraGroupScreenshot() {
        app.swipeUp()
        sleep(1)

        let cameraGroupsText = app.staticTexts["Camera Groups"]
        if cameraGroupsText.exists {
            cameraGroupsText.tap()
            sleep(1)

            let addGroupButton = app.buttons["Add Group"]
            if addGroupButton.waitForExistence(timeout: 3) {
                addGroupButton.tap()
                sleep(1)
                assertScreenshot("09-AddCameraGroup")
            }
        }
    }

    func testVoiceNotificationsScreenshot() {
        app.swipeUp()
        sleep(1)

        let voiceText = app.staticTexts["Voice Notifications"]
        if voiceText.exists {
            voiceText.tap()
            sleep(1)
            assertScreenshot("10-VoiceNotifications")
        }
    }

    func testQRCodeScreenshot() {
        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(1)

        let qrCodesButton = app.staticTexts["QR Codes"]
        if qrCodesButton.exists {
            qrCodesButton.tap()
            sleep(2)
            app.swipeUp()
            sleep(1)
            app.swipeUp()
            sleep(1)
            snapshot("11-QRCodes")
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
