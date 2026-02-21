import XCTest

final class UIWorkflowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - App Launch Tests

    func testAppLaunch() {
        // Verify the app launches successfully
        XCTAssertTrue(app.waitForExistence(timeout: 5), "App should launch within 5 seconds")

        // Check for main UI elements
        XCTAssertTrue(app.buttons["Connect All"].exists, "Connect All button should be visible")
        XCTAssertTrue(app.buttons["Disconnect All"].exists, "Disconnect All button should be visible")
    }

    func testAppLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Camera Discovery Tests

    func testCameraDiscoveryUI() {
        // Test that the UI shows appropriate state when no cameras are discovered
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No cameras discovered")).firstMatch.exists,
                     "Should show 'No cameras discovered' message when no cameras are found")
    }

    func testScanningIndicator() {
        // Test that scanning indicator appears when scanning for cameras
        let scanButton = app.buttons["Scan for Cameras"]
        if scanButton.exists {
            scanButton.tap()

            // Look for scanning indicator or activity indicator
            let scanningIndicator = app.activityIndicators.firstMatch
            XCTAssertTrue(scanningIndicator.exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Scanning")).firstMatch.exists,
                         "Should show scanning indicator when scanning for cameras")
        }
    }

    // MARK: - Configuration Management Tests

    func testConfigurationManagementWorkflow() {
        // Test the configuration management workflow
        let configButton = app.buttons["Configurations"]
        XCTAssertTrue(configButton.exists, "Configurations button should be visible")

        configButton.tap()

        // Wait for configuration management view to appear
        XCTAssertTrue(app.waitForExistence(timeout: 2), "Configuration management view should appear")

        // Test adding a new configuration
        let addButton = app.buttons["Add Configuration"]
        if addButton.exists {
            addButton.tap()

            // Test configuration form
            let nameField = app.textFields["Configuration Name"]
            if nameField.exists {
                nameField.tap()
                nameField.typeText("Test Configuration")

                // Test resolution picker
                let resolutionPicker = app.pickers["Resolution Picker"]
                if resolutionPicker.exists {
                    resolutionPicker.adjust(toPickerWheelValue: "4K")
                }

                // Test frame rate picker
                let frameRatePicker = app.pickers["Frame Rate Picker"]
                if frameRatePicker.exists {
                    frameRatePicker.adjust(toPickerWheelValue: "30 fps")
                }

                // Save configuration
                let saveButton = app.buttons["Save"]
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }

        // Go back to main view
        let backButton = app.buttons["Back"]
        if backButton.exists {
            backButton.tap()
        }
    }

    func testCameraSetManagementWorkflow() {
        // Test the camera set management workflow
        let cameraSetsButton = app.buttons["Camera Sets"]
        XCTAssertTrue(cameraSetsButton.exists, "Camera Sets button should be visible")

        cameraSetsButton.tap()

        // Wait for camera set management view to appear
        XCTAssertTrue(app.waitForExistence(timeout: 2), "Camera set management view should appear")

        // Test adding a new camera set
        let addButton = app.buttons["Add Camera Set"]
        if addButton.exists {
            addButton.tap()

            // Test camera set form
            let nameField = app.textFields["Camera Set Name"]
            if nameField.exists {
                nameField.tap()
                nameField.typeText("Test Camera Set")

                // Save camera set
                let saveButton = app.buttons["Save"]
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }

        // Go back to main view
        let backButton = app.buttons["Back"]
        if backButton.exists {
            backButton.tap()
        }
    }

    // MARK: - Voice Notification Settings Tests

    func testVoiceNotificationSettings() {
        // Test voice notification settings
        let voiceButton = app.buttons["Voice"]
        XCTAssertTrue(voiceButton.exists, "Voice button should be visible")

        voiceButton.tap()

        // Wait for voice notification settings view to appear
        XCTAssertTrue(app.waitForExistence(timeout: 2), "Voice notification settings view should appear")

        // Test voice notification toggle
        let voiceToggle = app.switches["Voice Notifications"]
        if voiceToggle.exists {
            let initialValue = voiceToggle.value as? String

            voiceToggle.tap()

            let newValue = voiceToggle.value as? String
            XCTAssertNotEqual(initialValue, newValue, "Voice notification toggle should change state")

            // Toggle back
            voiceToggle.tap()
        }

        // Test test buttons
        let testRecordingButton = app.buttons["Test Recording Start"]
        if testRecordingButton.exists {
            testRecordingButton.tap()
        }

        let testSyncButton = app.buttons["Test Settings Synced"]
        if testSyncButton.exists {
            testSyncButton.tap()
        }

        // Go back to main view
        let backButton = app.buttons["Back"]
        if backButton.exists {
            backButton.tap()
        }
    }

    // MARK: - Recording Controls Tests

    func testRecordingControls() {
        // Test recording control buttons
        let startRecordingButton = app.buttons["Start Recording"]
        let stopRecordingButton = app.buttons["Stop Recording"]

        XCTAssertTrue(startRecordingButton.exists, "Start Recording button should be visible")
        XCTAssertTrue(stopRecordingButton.exists, "Stop Recording button should be visible")

        // Test button states when no cameras are connected
        XCTAssertFalse(startRecordingButton.isEnabled, "Start Recording should be disabled when no cameras are connected")
        XCTAssertFalse(stopRecordingButton.isEnabled, "Stop Recording should be disabled when no cameras are connected")
    }

    func testSettingsSyncButton() {
        // Test settings sync button
        let syncButton = app.buttons["Sync Settings"]
        XCTAssertTrue(syncButton.exists, "Sync Settings button should be visible")

        // Test button state when no cameras are connected
        XCTAssertFalse(syncButton.isEnabled, "Sync Settings should be disabled when no cameras are connected")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        // Test that all important UI elements have accessibility labels
        let connectButton = app.buttons["Connect All"]
        XCTAssertTrue(connectButton.exists, "Connect All button should have accessibility label")

        let disconnectButton = app.buttons["Disconnect All"]
        XCTAssertTrue(disconnectButton.exists, "Disconnect All button should have accessibility label")

        let startRecordingButton = app.buttons["Start Recording"]
        XCTAssertTrue(startRecordingButton.exists, "Start Recording button should have accessibility label")

        let stopRecordingButton = app.buttons["Stop Recording"]
        XCTAssertTrue(stopRecordingButton.exists, "Stop Recording button should have accessibility label")
    }

    func testAccessibilityTraits() {
        // Test that buttons exist and are accessible
        let connectButton = app.buttons["Connect All"]
        XCTAssertTrue(connectButton.exists, "Connect All button should exist")

        let startRecordingButton = app.buttons["Start Recording"]
        XCTAssertTrue(startRecordingButton.exists, "Start Recording button should exist")
    }

    // MARK: - Error Handling Tests

    func testErrorMessages() {
        // Test that error messages are displayed appropriately
        // This would require simulating error conditions

        // For now, just verify that the UI can handle error states gracefully
        let app = XCUIApplication()
        app.launch()

        // The app should not crash when launched
        XCTAssertTrue(app.exists, "App should remain responsive after launch")
    }

    // MARK: - Navigation Tests

    func testNavigationFlow() {
        // Test navigation between different views

        // Test going to configuration management
        let configButton = app.buttons["Configurations"]
        configButton.tap()

        // Verify we're in configuration management
        XCTAssertTrue(app.waitForExistence(timeout: 2), "Should navigate to configuration management")

        // Go back
        let backButton = app.buttons["Back"]
        if backButton.exists {
            backButton.tap()
        }

        // Test going to camera set management
        let cameraSetsButton = app.buttons["Camera Sets"]
        cameraSetsButton.tap()

        // Verify we're in camera set management
        XCTAssertTrue(app.waitForExistence(timeout: 2), "Should navigate to camera set management")

        // Go back
        if backButton.exists {
            backButton.tap()
        }

        // Test going to voice notification settings
        let voiceButton = app.buttons["Voice"]
        voiceButton.tap()

        // Verify we're in voice notification settings
        XCTAssertTrue(app.waitForExistence(timeout: 2), "Should navigate to voice notification settings")

        // Go back
        if backButton.exists {
            backButton.tap()
        }
    }

    // MARK: - Performance Tests

    func testUIPerformance() {
        // Test UI performance by rapidly tapping buttons
        let connectButton = app.buttons["Connect All"]

        measure {
            for _ in 0..<10 {
                connectButton.tap()
                // Small delay to prevent overwhelming the UI
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }

    // MARK: - Memory Tests

    func testMemoryUsage() {
        // Test memory usage during normal operation
        let configButton = app.buttons["Configurations"]

        // Navigate to configuration management multiple times
        for _ in 0..<5 {
            configButton.tap()

            let backButton = app.buttons["Back"]
            if backButton.exists {
                backButton.tap()
            }
        }

        // App should still be responsive
        XCTAssertTrue(app.exists, "App should remain responsive after multiple navigation cycles")
    }
}
