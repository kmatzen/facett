# Contributing to Facett

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork the repository
2. Clone your fork and create a branch from `main`
3. Make your changes
4. Run the tests and linter
5. Open a pull request

## Development Setup

- Xcode 15+
- iOS 16.6+ deployment target
- SwiftLint installed (`brew install swiftlint`)

```bash
open Facett.xcodeproj
```

## Code Style

- SwiftLint enforces style rules — run `swiftlint lint --strict` before pushing
- Follow existing naming conventions in the codebase
- Avoid adding comments that just narrate what the code does

## Testing

All PRs must pass the existing test suite. Add tests for new functionality.

### Running Tests

```bash
./run_tests.sh unit          # Unit tests (no hardware)
./run_tests.sh ui            # UI tests (simulator)
./run_tests.sh integration   # Integration tests (mocked BLE)
./run_tests.sh device        # Device tests (real GoPro required)
./run_tests.sh all           # All of the above
```

Or run directly with xcodebuild:

```bash
xcodebuild test \
    -project Facett.xcodeproj \
    -scheme Facett \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:FacettTests \
    -quiet
```

### Test Suites

| Suite | What it covers |
|-------|---------------|
| `PacketReconstructorTests` | BLE packet header parsing, multi-packet assembly |
| `TLVParserTests` | TLV decoding (single/multiple entries, edge cases) |
| `ResponseMapperTests` | TLV → `ResponseType` mapping |
| `BLEParserPipelineTests` | End-to-end parsing pipeline |
| `GoProCommandTests` | Command byte array correctness |
| `SettingsTests` | Configuration management, validation |
| `StateMachineTests` | State machine priority and transitions |
| `CameraGroupTests` | Group CRUD, serial management |
| `CameraSettingDescriptionTests` | Human-readable setting descriptions |
| `ErrorHandlerTests` | Recovery strategy selection |

### Notes

- BLE hardware tests require a real GoPro and a physical iOS device
- Unit and UI tests run fine in the iOS Simulator
- CI runs unit tests automatically on every push and PR

## Pull Requests

- Keep PRs focused — one logical change per PR
- Write a clear title and description explaining *why*, not just *what*
- Reference any related issues (e.g., "Fixes #123")
- Make sure CI passes before requesting review

## Commit Messages

- Use imperative mood ("Add feature" not "Added feature")
- First line: concise summary (50 chars or less ideal)
- Body: explain the *why* if the change isn't obvious

## Reporting Issues

- Search existing issues first to avoid duplicates
- Include steps to reproduce for bugs
- Mention your iOS version, device model, and GoPro model if relevant
- Logs from the app's crash reporter are helpful

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
