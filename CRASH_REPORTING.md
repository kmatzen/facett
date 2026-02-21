# Crash and Bug Reporting System

## Overview

The Facett app now includes a comprehensive crash and bug reporting system that integrates with TestFlight for automatic crash reporting and provides users with the ability to submit detailed bug reports.

## Features

### 1. Automatic Crash Reporting
- **Signal-based crashes**: Captures SIGABRT, SIGSEGV, SIGBUS, SIGILL crashes
- **Exception handling**: Captures uncaught NSExceptions
- **Stack traces**: Records full thread stack traces at crash time
- **Device information**: Captures device model, iOS version, memory usage
- **App information**: Records app version, build number, TestFlight status

### 2. Manual Bug Reporting
- **User-friendly form**: Comprehensive bug report form accessible from the app
- **Categorized reports**: Bug reports can be categorized (UI/UX, Bluetooth, Camera, etc.)
- **Severity levels**: Low, Medium, High, Critical severity classification
- **Detailed information**: User steps, expected vs actual behavior
- **Device context**: Automatic device and app information collection

### 3. Error and Warning Logging
- **Programmatic logging**: `CrashReporter.logError()` and `CrashReporter.logWarning()`
- **Context preservation**: Rich context information with each log entry
- **Persistent storage**: All logs saved to device for later analysis

## Integration with TestFlight

### Automatic Crash Reports
When you distribute your app through TestFlight:
1. **Automatic collection**: TestFlight automatically collects crash reports
2. **Symbolication**: Apple provides symbolicated crash reports in App Store Connect
3. **No additional setup**: Works out of the box with your existing TestFlight setup

### Bug Reports
The bug reporting system is designed to work with TestFlight:
- **TestFlight detection**: Automatically detects when running from TestFlight
- **Ready for backend**: Bug reports are structured for easy backend integration
- **Local storage**: Reports stored locally until you implement backend upload

## How to Use

### For Users
1. **Access bug reporting**: Tap the "Bug Report" button in the management section
2. **Fill out the form**: Provide detailed information about the issue
3. **Submit**: Reports are saved locally and ready for upload

### For Developers
1. **Programmatic logging**:
   ```swift
   CrashReporter.shared.logError("BLE Connection Failed", error: error, context: ["peripheral": "GoPro-123"])
   CrashReporter.shared.logWarning("High memory usage detected", context: ["memory": "85%"])
   ```

2. **Manual bug reports**:
   ```swift
   CrashReporter.shared.reportBug(
       title: "Settings not saving",
       description: "Camera settings revert after app restart",
       severity: .high,
       category: .settings,
       userSteps: "1. Change video resolution\n2. Close app\n3. Reopen app",
       expectedBehavior: "Settings should persist",
       actualBehavior: "Settings revert to default"
   )
   ```

## File Structure

### Core Files
- `CrashReporter.swift`: Main crash reporting system
- `BugReportView.swift`: User interface for bug reporting

### Data Models
- `CrashLog`: Represents a crash with full context
- `BugReport`: Represents a user-submitted bug report
- `ErrorLog`: Represents a logged error
- `WarningLog`: Represents a logged warning

## Data Storage

### Local Storage
- **Crash logs**: `crash_logs.json` in app documents
- **Bug reports**: `bug_reports.json` in app documents
- **Error logs**: Individual `error_*.json` files
- **Warning logs**: Individual `warning_*.json` files

### Data Access
```swift
let (crashLogs, bugReports) = CrashReporter.shared.getAllReports()
let errorLogs = CrashReporter.shared.getCrashLogs()
let userReports = CrashReporter.shared.getBugReports()
```

## TestFlight Integration

### What TestFlight Provides
1. **Automatic crash collection**: No additional code needed
2. **Symbolicated reports**: Stack traces with readable function names
3. **Device information**: iOS version, device model, etc.
4. **App Store Connect dashboard**: View crashes in web interface

### What You Get
- **Crash frequency**: How often each crash occurs
- **Affected devices**: Which devices are experiencing crashes
- **iOS version distribution**: Which iOS versions are affected
- **User feedback**: TestFlight users can provide feedback

## Next Steps

### For Immediate Use
1. **Upload to TestFlight**: The crash reporting is already working
2. **Monitor crashes**: Check App Store Connect for crash reports
3. **User bug reports**: Access local bug reports from the app

### For Enhanced Reporting
1. **Backend integration**: Implement server upload for bug reports
2. **Analytics integration**: Connect with your analytics platform
3. **Custom dashboards**: Build custom reporting interfaces

## Privacy and Security

### Data Collected
- **Device information**: Model, iOS version, memory usage
- **App information**: Version, build number, TestFlight status
- **Crash data**: Stack traces, exception details
- **User reports**: Information provided by users

### Data Handling
- **Local storage**: All data stored locally on device
- **No automatic upload**: Data only uploaded when you implement it
- **User control**: Users can clear all reports via the app
- **TestFlight compliance**: Follows Apple's TestFlight guidelines

## Troubleshooting

### Common Issues
1. **No crash reports**: Ensure app is distributed through TestFlight
2. **Missing symbols**: Upload dSYM files to App Store Connect
3. **Local reports not showing**: Check file permissions in app documents

### Debug Mode
- **Verbose logging**: CrashReporter logs all operations
- **Local file inspection**: Check app documents for log files
- **Simulator testing**: All features work in iOS Simulator

## Best Practices

### For Crash Reporting
1. **Test thoroughly**: Test crash scenarios in development
2. **Monitor regularly**: Check TestFlight crash reports frequently
3. **Fix promptly**: Address high-frequency crashes quickly

### For Bug Reports
1. **Encourage reporting**: Make the bug report button easily accessible
2. **Provide guidance**: Help users provide useful information
3. **Follow up**: Respond to user reports when possible

### For Error Logging
1. **Log strategically**: Don't log everything, focus on actionable errors
2. **Include context**: Provide relevant context with each log
3. **Use appropriate levels**: Use warnings for recoverable issues, errors for failures

## Conclusion

The crash and bug reporting system provides comprehensive monitoring capabilities for your Facett app. With TestFlight integration, you'll get automatic crash reporting, and the manual bug reporting system gives users a way to provide detailed feedback about issues they encounter.

The system is designed to be privacy-conscious and follows Apple's guidelines for TestFlight apps. All data is stored locally until you choose to implement backend integration for enhanced reporting capabilities.
