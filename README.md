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
- GoPro® HERO10 Black with GoPro Labs firmware (tested configuration; other models may work but are not officially supported)
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
xcodebuild test \
    -project Facett.xcodeproj \
    -scheme Facett \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:FacettTests \
    -quiet
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full list of test suites.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — System design and component overview
- [BLE_PROTOCOL.md](BLE_PROTOCOL.md) — GoPro BLE protocol details
- [CRASH_REPORTING.md](CRASH_REPORTING.md) — Crash reporting system
- [SUPPORT.md](SUPPORT.md) — FAQ, troubleshooting, and how to get help

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — Kevin Blackburn-Matzen

---

This product and/or service is not affiliated with, endorsed by or in any way associated with GoPro Inc. or its products and services. GoPro, HERO and their respective logos are trademarks or registered trademarks of GoPro, Inc.
