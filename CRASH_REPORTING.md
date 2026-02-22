# Crash and Bug Reporting System

## Overview

Facett includes a crash and bug reporting system with automatic crash detection, programmatic error/warning logging, and a user-facing bug report form.

## Features

### Automatic Crash Reporting
- **Signal-based crashes**: Captures SIGABRT, SIGSEGV, SIGBUS, SIGILL
- **Exception handling**: Captures uncaught NSExceptions
- **Stack traces**: Records full thread stack traces at crash time
- **Device context**: Device model, iOS version, memory usage, app version

### Manual Bug Reporting
- **User-friendly form**: Accessible from the management section
- **Categorized reports**: UI/UX, Bluetooth, Camera, Settings, etc.
- **Severity levels**: Low, Medium, High, Critical
- **Rich context**: User steps, expected vs actual behavior, device info

### Error and Warning Logging
- **Programmatic logging**: `CrashReporter.logError()` and `CrashReporter.logWarning()`
- **Context preservation**: Rich context information with each log entry
- **Persistent storage**: All logs saved to device for later analysis

## Usage

### For Developers

```swift
CrashReporter.shared.logError(
    "BLE Connection Failed",
    error: error,
    context: ["peripheral": "GoPro-123"]
)

CrashReporter.shared.logWarning(
    "High memory usage detected",
    context: ["memory": "85%"]
)

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

### For Users
1. Tap the **Bug Report** button in the management section
2. Fill out the form with details about the issue
3. Submit — reports are saved locally

## File Structure

- `CrashReporter.swift` — core crash reporting and logging
- `BugReportView.swift` — user interface for bug reports

### Data Models
- `CrashLog` — crash with full stack trace and device context
- `BugReport` — user-submitted bug report
- `ErrorLog` — programmatically logged error
- `WarningLog` — programmatically logged warning

## Data Storage

All data is stored locally on-device:

| Data | Storage |
|------|---------|
| Crash logs | `crash_logs.json` in app documents |
| Bug reports | `bug_reports.json` in app documents |
| Error logs | Individual `error_*.json` files |
| Warning logs | Individual `warning_*.json` files |

### Accessing Reports

```swift
let (crashLogs, bugReports) = CrashReporter.shared.getAllReports()
```

## Privacy

- All data stored locally on device
- No automatic upload — data only sent when backend integration is implemented
- Users can clear all reports via the app

## Best Practices

- **Log strategically**: Focus on actionable errors, not routine operations
- **Include context**: Provide relevant BLE peripheral names, retry counts, etc.
- **Use appropriate levels**: Warnings for recoverable issues, errors for failures
- **Monitor regularly**: Review crash reports after each release
