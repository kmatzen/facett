# Facett

A SwiftUI iOS app for controlling multiple GoPro cameras simultaneously via Bluetooth Low Energy (BLE).

## Features

- **BLE Discovery & Connection** — Automatically discover and connect to GoPro Hero 9+ cameras
- **Camera Groups** — Organize cameras into groups for coordinated control
- **Recording Control** — Start/stop recording on all cameras simultaneously or individually
- **Status Dashboard** — Monitor battery, storage, and recording status across all cameras
- **Configuration Management** — Apply shared capture settings (resolution, lens, exposure, white balance)
- **Timecode Jamming** — Sync timecode across cameras via QR codes (requires GoPro Labs firmware)
- **Voice Control** — Hands-free operation via speech recognition
- **QR Code Generation** — Generate configuration QR codes for GoPro Labs settings

## Requirements

- iOS 16.6+
- iPhone or iPad with Bluetooth 4.0+
- GoPro Hero 9 or later (GoPro Labs firmware recommended)
- Xcode 15+

## Building

Open `GoProConfigurator.xcodeproj` in Xcode and build the `Facett` target.

## Testing

```bash
./run_tests.sh unit          # Unit tests (no hardware)
./run_tests.sh ui            # UI tests (simulator)
./run_tests.sh integration   # Integration tests (mocked BLE)
./run_tests.sh device        # Device tests (real GoPro required)
./run_tests.sh all           # All of the above
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system design. The app follows SwiftUI + MVVM with a BLE communication stack.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — System design and component overview
- [API_REFERENCE.md](API_REFERENCE.md) — Public API documentation
- [BLE_PROTOCOL.md](BLE_PROTOCOL.md) — GoPro BLE protocol details
- [STATE_MACHINES.md](STATE_MACHINES.md) — State machine documentation
- [CAMERA_UUID_MIGRATION.md](CAMERA_UUID_MIGRATION.md) — Camera identity migration notes
- [CRASH_REPORTING.md](CRASH_REPORTING.md) — Crash reporting system
- [TESTING.md](TESTING.md) — Testing strategy and guidelines

---

## Agent Instructions: Remaining Cleanup Work

> **This section documents all remaining work from [gopro-tools#14](https://github.com/kmatzen/gopro-tools/issues/14) that needs to be completed in this repo.**

### 1. Rename Xcode Project to Match "Facett"

The project has three different names that need to be unified under **Facett**:

| Context | Current Name | Target |
|---------|-------------|--------|
| Xcode project file | `GoProConfigurator.xcodeproj` | `Facett.xcodeproj` |
| Source folder | `GoProConfigurator/` | `Facett/` |
| Test folders | `GoProConfiguratorTests/`, `GoProConfiguratorUITests/` | `FacettTests/`, `FacettUITests/` |
| App entry struct | `FacettApp` in `GoProConfiguratorApp.swift` | `FacettApp` in `FacettApp.swift` |
| `run_tests.sh` PROJECT_NAME | `GoProConfigurator` | `Facett` |
| `run_tests.sh` SCHEME_NAME | `GPControl` | `Facett` |
| Test imports | `@testable import Facett` | Already correct |

**How to rename:**
1. Rename `GoProConfigurator.xcodeproj` → `Facett.xcodeproj`
2. Rename `GoProConfigurator/` → `Facett/`
3. Rename `GoProConfiguratorTests/` → `FacettTests/`
4. Rename `GoProConfiguratorUITests/` → `FacettUITests/`
5. Rename `GoProConfigurator/GoProConfiguratorApp.swift` → `Facett/FacettApp.swift`
6. Update ALL references in `project.pbxproj` — search-replace `GoProConfigurator` → `Facett` in file/group references, paths, and target names. Be careful not to break the pbxproj structure.
7. Update `run_tests.sh` variables: `PROJECT_NAME="Facett"`, `SCHEME_NAME="Facett"`
8. Create a shared scheme named `Facett` (or verify one exists after the rename). The current scheme files are under `xcuserdata/` which is gitignored — a shared scheme under `xcshareddata/` should be created for CI.
9. Update test target references in `project.pbxproj`: the test bundle names reference `GoProConfiguratorTests` and `GoProConfiguratorUITests`.

### 2. Remove Adobe / Organization References

| Item | Current Value | New Value |
|------|---------------|-----------|
| Bundle ID in `project.pbxproj` | `com.adobe.matzen.facett` | `com.matzen.facett` |
| Dev team (app) in `project.pbxproj` | `LH3PFZAX3C` | Owner's personal team ID (leave as `""` or a placeholder `PERSONAL_TEAM_ID` if unknown) |
| Dev team (tests) in `project.pbxproj` | `R5326Y7EZ4` | Same as app team |
| Logger subsystem in `CrashReporter.swift` | `com.adobe.matzen.Facett` | `com.matzen.facett` |
| Logger subsystem in `DataPersistenceManager.swift` | `com.adobe.matzen.Facett` | `com.matzen.facett` |
| Logger subsystem in `ErrorHandling.swift` | `com.adobe.matzen.Facett` | `com.matzen.facett` |
| BLE queue label in `BLEManager.swift` | `com.matzen.goproConfigurator.bleCommandQueue` | `com.matzen.facett.bleCommandQueue` |
| Test bundle IDs in `project.pbxproj` | `matzen.GoProConfiguratorTests`, `matzen.GoProConfiguratorUITests` | `com.matzen.FacettTests`, `com.matzen.FacettUITests` |
| Logger subsystem in `API_REFERENCE.md` | `com.adobe.matzen.Facett` | `com.matzen.facett` |

### 3. Documentation Cleanup

These docs have stale references that need updating:

- **`API_REFERENCE.md`**: References `CameraSet` and `CameraSetManager` — should be `CameraGroup` and `CameraGroupManager`. Also references `CameraSerialNumberManager` — should be `CameraIdentityManager`.
- **`ARCHITECTURE.md`**: References `CameraSet` / `CameraSetManager` — update to `CameraGroup` / `CameraGroupManager`. Also references `CameraSerialNumberManager`.
- **`CAMERA_UUID_MIGRATION.md`**: References `CameraSerialNumberManager.swift` — the actual file is `CameraIdentityManager.swift`.
- **`TESTING.md`**: May reference `GPControl` scheme — update to `Facett`.
- **All docs**: Search for `GoProConfigurator` references and update to `Facett` where appropriate.

Files confirmed to have stale `CameraSerialNumberManager` references:
- `GoProConfigurator/ContentView.swift`
- `GoProConfigurator/CameraGroup.swift`
- `GoProConfigurator/CameraIdentityManager.swift`
- `GoProConfigurator/BLEResponseHandler.swift`
- `GoProConfigurator/CameraViews.swift`
- `GoProConfigurator/BLEManager.swift`
- `GoProConfigurator/CameraGroupViewComponents.swift`
- `CAMERA_UUID_MIGRATION.md`

**Note:** The Swift source files use `CameraSerialNumberManager` in comments only (documentation references); the actual class is `CameraIdentityManager`. Update the comments.

### 4. `run_tests.sh` Cleanup

- Remove hardcoded `DEVICE_ID="00008130-000578862861401C"` — make it configurable via env var or auto-detect
- Update `PROJECT_NAME` and `SCHEME_NAME` after rename
- Test target names in `-only-testing:` flags will need updating after folder rename

### 5. Code Quality

- **`BLEManager.swift` line ~647**: Has a self-deprecated `log()` method marked `@available(*, deprecated)`. Remove it or migrate callers to `ErrorHandler`.
- **`.onChange(of:)` closures**: The app uses the iOS 14-16 style `.onChange(of:) { newValue in }` syntax. If deployment target stays at 16.6, this is fine. If raised to 17+, migrate to the new two-parameter closure style `.onChange(of:) { oldValue, newValue in }`.
- **UI tests**: `GoProConfiguratorUITests.swift` and launch tests may have `#available` checks for macOS 10.15 / iOS 13.0 — clean up for current deployment target.

### 6. App Store Readiness

- [ ] **App icon**: Verify `Assets.xcassets/AppIcon.appiconset` has all required sizes including 1024×1024 marketing icon. Check `Contents.json`.
- [ ] **Privacy policy URL**: Required for App Store — the app uses Bluetooth and speech recognition. Create one and add it to App Store Connect metadata.
- [ ] **Info.plist**: Currently empty `<dict/>`. All metadata lives in build settings (`INFOPLIST_KEY_*`). Verify completeness for App Review — especially BLE usage description, microphone usage, and speech recognition usage.
- [ ] **Usage descriptions**: Audit build settings for `NSBluetoothAlwaysUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` — ensure they are clear and user-friendly.
- [ ] **Minimum deployment target**: Currently iOS 16.6 for app, iOS 18.2 for unit tests. Align these.
- [ ] **Swift version**: Currently 5.0 in build settings. Consider updating to match current Xcode.
- [ ] **Launch screen**: Uses `LaunchScreen.storyboard` with a static `launch.png`. Consider a proper SwiftUI launch screen.
- [ ] **Marketing version**: Currently `1.0` / build `1`. Set appropriately.

### 7. CI/CD (GitHub Actions)

Create `.github/workflows/build.yml`:
- Use `macos-latest` runner
- Build the Facett scheme for iOS Simulator
- Run unit tests (`FacettTests/ParserTests`, `FacettTests/SettingsTests`)
- Optional: Add SwiftLint
- Optional: Fastlane for TestFlight/App Store deployment

### 8. Update `gopro-tools` Repo

After this repo is complete, the parent `gopro-tools` repo needs:
- Remove the `GoProConfigurator/` directory
- Update `README.md` line ~107 and ~142 to point to `https://github.com/kmatzen/facett`
- Update `docs/workflows/ios_app_control_gopros.md` to reference the new repo
- Update `docs/index.md` line ~64
- Update `docs/ORGANIZATION.md` lines ~30, ~53
- Update `rigdesign/README.md` references
- Update `docs/reference/wifi-transfer.md` references
- Update `setup/README.md` to remove Adobe TestFlight instructions and reference the new repo
- Update `.gitignore` to remove `GoProConfigurator/` entries
- Consider removing `setup/README.md` entirely or keeping it as a standalone rig operation guide

### Priority Order

1. **Rename project** (Section 1) — most impactful, do first
2. **Remove Adobe references** (Section 2) — required for App Store
3. **Documentation cleanup** (Section 3) — fix stale names
4. **run_tests.sh cleanup** (Section 4) — align with rename
5. **Code quality** (Section 5) — minor improvements
6. **App Store readiness** (Section 6) — verify/document
7. **CI/CD** (Section 7) — nice to have
8. **Update gopro-tools** (Section 8) — do last, after everything else is stable
