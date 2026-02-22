# Facett

[![Build & Test](https://github.com/kmatzen/facett/actions/workflows/build.yml/badge.svg)](https://github.com/kmatzen/facett/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A SwiftUI iOS app for controlling multiple GoPro cameras simultaneously via Bluetooth Low Energy (BLE).

Facett is built for multi-camera shoots — connect a fleet of GoPros, organize them into groups, sync settings across the group, and start/stop recording on all cameras at once.

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

```bash
git clone https://github.com/kmatzen/facett.git
cd facett
open Facett.xcodeproj
```

Build and run the `Facett` scheme targeting an iOS Simulator or physical device.

## Testing

```bash
./run_tests.sh unit          # Unit tests (no hardware)
./run_tests.sh ui            # UI tests (simulator)
./run_tests.sh integration   # Integration tests (mocked BLE)
./run_tests.sh device        # Device tests (real GoPro required)
./run_tests.sh all           # All of the above
```

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — System design and component overview
- [BLE_PROTOCOL.md](BLE_PROTOCOL.md) — GoPro BLE protocol details
- [CRASH_REPORTING.md](CRASH_REPORTING.md) — Crash reporting system

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — Kevin Blackburn-Matzen
