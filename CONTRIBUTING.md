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

```bash
./run_tests.sh unit    # Run unit tests
```

Test classes live in `FacettTests/`. Key suites:
- `PacketReconstructorTests` / `TLVParserTests` / `ResponseMapperTests` — BLE protocol parsing
- `GoProCommandTests` — command byte array correctness
- `SettingsTests` — configuration management
- `StateMachineTests` — state machine logic

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
