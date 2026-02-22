# Facett — Architecture

## Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI Views Layer                      │
├─────────────────────────────────────────────────────────────┤
│                   ViewModels & Managers                     │
├─────────────────────────────────────────────────────────────┤
│                    Business Logic Layer                     │
├─────────────────────────────────────────────────────────────┤
│                    Data Models Layer                        │
├─────────────────────────────────────────────────────────────┤
│                   Core Bluetooth Layer                      │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

| Component | File(s) | Purpose |
|-----------|---------|---------|
| App entry point | `FacettApp.swift` | Lifecycle, dependency injection, idle timer |
| BLE Manager | `BLEManager.swift` | Discovery, connection, command sending, error recovery |
| Config Manager | `CameraConfig.swift`, `ConfigManager.swift` | Camera presets, settings validation, sync |
| Group Manager | `CameraGroup.swift`, `CameraGroupManager.swift` | Multi-camera groups, coordinated control |
| Crash Reporter | `CrashReporter.swift` | Signal/exception handlers, error logging |
| Error Handler | `ErrorHandler.swift` | Centralized logging with severity levels |

## View Hierarchy

```
ContentView
├── ActiveSetSummaryView
│   ├── CameraStatusRow
│   ├── BatteryIndicator
│   └── SettingsMismatchIndicator
├── CameraGroupViews
│   ├── CameraListView
│   ├── CameraGroupRow
│   └── CameraDetailView
├── ConfigManagementView
│   ├── ConfigList
│   ├── ConfigEditor
│   └── SettingsValidator
└── ManagementButtons
    ├── ConnectAllButton
    ├── CameraGroupsButton
    ├── ConfigurationsButton
    └── BugReportButton
```

## Key Data Models

| Model | Type | Role |
|-------|------|------|
| `GoProSettings` | `ObservableObject` | Live camera state with `@Published` properties |
| `GoProSettingsData` | `Codable` | Persistent settings storage with defaults |
| `CameraConfig` | `Identifiable, Codable` | Named preset (name, description, settings) |
| `CameraGroup` | `Identifiable, Codable` | Group of cameras by serial (`cameraSerials: Set<String>`) |
| `CameraStatus` | `enum` | Ready, Error, Recording, Disconnected, etc. |
| `GroupStatus` | `struct` | Aggregate counts across a group |

## Specialized Docs

- [STATE_MACHINES.md](STATE_MACHINES.md) — State definitions, transitions, debugging
- [BLE_PROTOCOL.md](BLE_PROTOCOL.md) — Packet formats, header encoding, TLV structure
- [CRASH_REPORTING.md](CRASH_REPORTING.md) — Crash and error logging system
