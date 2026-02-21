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

Open `Facett.xcodeproj` in Xcode and build the `Facett` target.

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

