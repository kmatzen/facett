# Crash & Bug Reporting

Facett includes automatic crash detection, programmatic error/warning logging, and a user-facing bug report form.

## Automatic Crash Reporting

- **Signal handlers**: SIGABRT, SIGSEGV, SIGBUS, SIGILL
- **Exception handler**: uncaught `NSException`s
- **Captured data**: full stack trace, device model, iOS version, memory usage, app version

## Programmatic Logging

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
```

## Bug Report Form

Users can submit bug reports from the management section. Reports include category, severity, reproduction steps, and expected vs. actual behavior.

## Files

| File | Role |
|------|------|
| `CrashReporter.swift` | Core crash reporting and logging |
| `BugReportView.swift` | User-facing bug report form |

## Data Models

| Model | Content |
|-------|---------|
| `CrashLog` | Stack trace + device context |
| `BugReport` | User-submitted report |
| `ErrorLog` | Programmatically logged error |
| `WarningLog` | Programmatically logged warning |

## Storage

All data is stored locally on-device. No automatic upload.

| Data | Location |
|------|----------|
| Crash logs | `crash_logs.json` in app documents |
| Bug reports | `bug_reports.json` in app documents |
| Error logs | `error_*.json` files |
| Warning logs | `warning_*.json` files |

```swift
let (crashLogs, bugReports) = CrashReporter.shared.getAllReports()
```
