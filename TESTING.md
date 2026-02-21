# Testing Strategy for Facett App

This document outlines the comprehensive testing strategy for the Facett app, which manages multiple GoPro cameras via BLE.

## Overview

Facett is a BLE-dependent iOS app that requires testing across multiple environments and scenarios. The testing strategy addresses the challenges of hardware dependencies, asynchronous operations, and real-world BLE interactions.

## Testing Challenges

### 1. Hardware Dependencies
- **Real GoPro cameras required** for full BLE testing
- **BLE hardware limitations** in iOS Simulator
- **Device-specific behavior** variations

### 2. Asynchronous Operations
- **BLE connection timing** is unpredictable
- **Command response delays** vary by camera model
- **State transitions** are complex and timing-dependent

### 3. Environment Differences
- **Simulator vs real device** behavior differs significantly
- **BLE signal strength** affects connection reliability
- **Network conditions** impact performance

## Testing Approaches

### 1. Unit Tests (No Hardware Required)
**Location**: `GoProConfiguratorTests/ParserTests.swift`, `GoProConfiguratorTests/SettingsTests.swift`

**What they test**:
- BLE packet parsing logic
- Settings validation
- Configuration management
- Business logic

**Advantages**:
- Fast execution
- No hardware dependencies
- Reliable and repeatable
- Can run in CI/CD

**Example**:
```swift
func testSinglePacketResponse() {
    let singlePacketData = Data([0x0E, 0x13, 0x00, 0x01, 0x01, 0x03, 0x02, 0x01, 0x00, 0x06, 0x01, 0x00, 0x08, 0x01, 0x00])
    let responses = parser.processPacket(singlePacketData, peripheralId: "test-peripheral")
    XCTAssertFalse(responses.isEmpty, "Single packet should return responses")
}
```

### 2. UI Tests (Simulator)
**Location**: `GoProConfiguratorUITests/UIWorkflowTests.swift`

**What they test**:
- User interface interactions
- Navigation flows
- Accessibility features
- UI state management

**Advantages**:
- Tests complete user workflows
- Validates UI behavior
- Can run in simulator
- Tests accessibility

**Example**:
```swift
func testConfigurationManagementWorkflow() {
    let configButton = app.buttons["Configurations"]
    configButton.tap()
    XCTAssertTrue(app.waitForExistence(timeout: 2), "Configuration management view should appear")
}
```

### 3. Integration Tests (Mocked BLE)
**Location**: `GoProConfiguratorTests/BLETestStrategy.swift`

**What they test**:
- Complete workflows with mocked BLE
- State transitions
- Error handling
- Command response processing

**Advantages**:
- Tests integration without hardware
- Predictable BLE responses
- Fast execution
- Good coverage

### 4. Manual Tests (Real Devices)
**Location**: `GoProConfiguratorTests/ManualTest.swift`

**What they test**:
- Real GoPro camera interactions
- Actual BLE communication
- Performance with real hardware
- Edge cases in real environment

**Advantages**:
- Tests real-world scenarios
- Validates actual hardware behavior
- Catches hardware-specific issues

### 5. Automated Device Tests (Real Devices)
**What they test**:
- BLE communication with real cameras
- Camera control functionality
- Recording operations
- Settings synchronization

**Requirements**:
- Real GoPro cameras
- Physical iOS device
- Stable BLE environment

## Test Categories

### A. Parser Tests (Unit)
Tests the `GoProBLEParser` class that handles BLE packet parsing:

- **Single packet responses**: Basic packet parsing
- **Multi-packet responses**: Continuation packet handling
- **Error conditions**: Invalid packets, timeouts
- **Edge cases**: Large packets, zero-length packets
- **Buffer management**: Multiple peripheral handling

### B. Settings Tests (Unit)
Tests settings validation and configuration management:

- **Settings validation**: Resolution/frame rate combinations
- **Configuration CRUD**: Create, read, update, delete
- **Camera group management**: Group creation and management
- **Settings synchronization**: Mismatch detection

### C. BLE Manager Tests (Integration)
Tests the `BLEManager` class with mocked BLE:

- **Connection management**: Connect/disconnect flows
- **Command sending**: BLE command transmission
- **Response handling**: Command response processing
- **Error recovery**: Connection failures, timeouts

### D. UI Tests (UI)
Tests user interface and workflows:

- **App launch**: Startup and initialization
- **Camera discovery**: Scanning and discovery UI
- **Configuration management**: Settings UI workflows
- **Recording controls**: Start/stop recording UI
- **Navigation**: View transitions

### E. End-to-End Tests (Manual/Automated)
Tests complete workflows with real hardware:

- **Camera connection**: Real BLE connection
- **Settings sync**: Actual camera settings synchronization
- **Recording operations**: Start/stop recording on real cameras
- **Performance**: Real-world performance validation

## Running Tests

### Using the Test Runner Script

The `run_tests.sh` script provides an easy way to run different types of tests:

```bash
# Run all tests
./run_tests.sh all

# Run only unit tests
./run_tests.sh unit

# Run only UI tests
./run_tests.sh ui

# Run only device tests (requires real device)
./run_tests.sh device

# Run only integration tests
./run_tests.sh integration
```

### Manual Test Execution

#### Unit Tests
```bash
xcodebuild test \
    -project GoProConfigurator.xcodeproj \
    -scheme GPControl \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:GoProConfiguratorTests/ParserTests \
    -only-testing:GoProConfiguratorTests/SettingsTests
```

#### UI Tests
```bash
xcodebuild test \
    -project GoProConfigurator.xcodeproj \
    -scheme GPControl \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:GoProConfiguratorUITests/UIWorkflowTests
```

#### Device Tests
```bash
xcodebuild test \
    -project GoProConfigurator.xcodeproj \
    -scheme GPControl \
    -destination "platform=iOS,id=00008130-000578862861401C" \
    -only-testing:GoProConfiguratorTests/ManualTest
```

### Using Xcode

1. **Open the project** in Xcode
2. **Select the test target** (GoProConfiguratorTests or GoProConfiguratorUITests)
3. **Choose a destination** (Simulator or Device)
4. **Run tests** using Cmd+U or the Test button

## Test Data and Mocking

### Mock BLE Peripherals
```swift
class MockCBPeripheral: CBPeripheral {
    let mockIdentifier: UUID
    let mockName: String?

    init(identifier: UUID, name: String?) {
        self.mockIdentifier = identifier
        self.mockName = name
        super.init()
    }

    override var identifier: UUID { mockIdentifier }
    override var name: String? { mockName }
}
```

### Test Data Generator
```swift
class BLETestDataGenerator {
    static func singlePacketResponse(operationID: UInt8, status: UInt8 = 0x00, data: [UInt8] = []) -> Data {
        let totalLength = UInt8(3 + data.count)
        return Data([totalLength, operationID, status] + data)
    }
}
```

### Sample Test Data
```swift
struct TestData {
    static let sampleSettings = GoProSettings(
        resolution: .r4k,
        frameRate: .fps30,
        fov: .wide,
        isRecording: false,
        batteryPercentage: 85,
        batteryLevel: 3,
        isUSBConnected: false,
        isEncoding: false
    )
}
```

## Continuous Integration

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]
jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Unit Tests
        run: ./run_tests.sh unit

  ui-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run UI Tests
        run: ./run_tests.sh ui
```

### Local CI Setup
```bash
# Install xcpretty for better output formatting
gem install xcpretty

# Run tests before committing
./run_tests.sh unit && ./run_tests.sh ui
```

## Best Practices

### 1. Test Organization
- **Group related tests** in separate test classes
- **Use descriptive test names** that explain what is being tested
- **Follow AAA pattern**: Arrange, Act, Assert
- **Keep tests independent** and isolated

### 2. Mocking Strategy
- **Mock external dependencies** (BLE, file system)
- **Use realistic test data** that matches real scenarios
- **Test error conditions** with mocked failures
- **Validate mock interactions** when appropriate

### 3. Test Data Management
- **Use factory methods** for creating test objects
- **Centralize test data** in shared structures
- **Use realistic values** that match real-world scenarios
- **Clean up test data** after tests complete

### 4. Performance Testing
- **Measure critical operations** (BLE packet parsing, UI rendering)
- **Set performance baselines** and monitor for regressions
- **Test with realistic data sizes** and volumes
- **Profile memory usage** during long-running operations

### 5. Error Handling
- **Test error conditions** thoroughly
- **Validate error messages** and user feedback
- **Test recovery mechanisms** after failures
- **Ensure graceful degradation** when hardware is unavailable

## Troubleshooting

### Common Issues

#### 1. BLE Tests Failing in Simulator
**Problem**: BLE functionality doesn't work in iOS Simulator
**Solution**: Use mocked BLE for unit/integration tests, real devices for BLE tests

#### 2. Device Tests Timing Out
**Problem**: Real device tests take too long or timeout
**Solution**: Increase timeouts, use more reliable BLE environment, add retry logic

#### 3. UI Tests Flaky
**Problem**: UI tests fail intermittently
**Solution**: Add proper waits, use stable UI elements, avoid timing-dependent tests

#### 4. Test Data Inconsistencies
**Problem**: Tests fail due to changing test data
**Solution**: Use deterministic test data, mock external dependencies

### Debugging Tips

1. **Enable verbose logging** in test environment
2. **Use Xcode's test navigator** to run individual tests
3. **Add breakpoints** in test code for debugging
4. **Check device logs** for BLE-related issues
5. **Use Instruments** for performance profiling

## Future Improvements

### 1. Enhanced Mocking
- **More sophisticated BLE mocking** with realistic response patterns
- **Network condition simulation** (poor signal, interference)
- **Camera behavior simulation** (different models, firmware versions)

### 2. Automated Device Testing
- **CI/CD integration** with real devices
- **Automated camera setup** and teardown
- **Performance regression testing**

### 3. Test Coverage
- **Code coverage reporting** and monitoring
- **Mutation testing** for test quality
- **Property-based testing** for edge cases

### 4. Test Infrastructure
- **Test data management** system
- **Automated test environment** setup
- **Test result analysis** and reporting

## Conclusion

This testing strategy provides comprehensive coverage for the Facett app while addressing the unique challenges of BLE-dependent applications. By combining unit tests, UI tests, integration tests, and real device testing, we can ensure the app works reliably across different environments and scenarios.

The key is to use the right testing approach for each component and to maintain a balance between test coverage, execution speed, and reliability.
