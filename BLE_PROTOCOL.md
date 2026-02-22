# GoPro BLE Protocol Documentation

## Overview

The GoPro Configurator app implements GoPro's proprietary Bluetooth Low Energy (BLE) protocol for camera control and status monitoring. This document details the protocol implementation, packet structure, and communication patterns.

## Protocol Architecture

### Communication Model

The BLE protocol follows a **client-server model** where:
- **iOS App (Client)**: Initiates commands and processes responses
- **GoPro Camera (Server)**: Responds to commands and sends status updates

### Service and Characteristic UUIDs

```swift
// GoPro BLE Service UUIDs
let GoProServiceUUID = CBUUID(string: "B5F90001-AA8D-11E3-9046-0002A5D5C51B")
let GoProControlUUID = CBUUID(string: "B5F90002-AA8D-11E3-9046-0002A5D5C51B")
let GoProResponseUUID = CBUUID(string: "B5F90003-AA8D-11E3-9046-0002A5D5C51B")
```

## Packet Structure

BLE 4.2 limits packets to 20 bytes. Larger messages are split across start + continuation packets.

Reference: https://gopro.github.io/OpenGoPro/ble/protocol/data_protocol.html

### Header Format

**Bit 7** determines start vs. continuation:

- **Bit 7 = 0 → Start packet.** Bits 6-5 select the length format:
  - `00` → General (5-bit): bits 4-0 = message length (max 31)
  - `01` → Extended 13-bit: bits 4-0 + next byte = message length
  - `10` → Extended 16-bit: next 2 bytes = message length (receive-only)
- **Bit 7 = 1 → Continuation packet.** Bits 3-0 = 4-bit sequence counter (wraps at 0xF)

### Start Packet Types

#### General (5-bit length)
```
Byte 0:  [0][00][5-bit message length]
Bytes 1+: message payload
```

#### Extended 13-bit
```
Byte 0:  [0][01][upper 5 bits of length]
Byte 1:  [lower 8 bits of length]
Bytes 2+: message payload
```

#### Extended 16-bit (receive-only, for messages >= 8192 bytes)
```
Byte 0:  [0][10][reserved]
Byte 1-2: 16-bit message length
Bytes 3+: message payload
```

### Continuation Packet
```
Byte 0:  [1][reserved][4-bit counter]
Bytes 1+: continuation payload (appended to accumulated message)
```

### Message Payload

For query responses (on the Query Response characteristic), the message payload is:
```
[QueryID (1 byte)] [Status (1 byte)] [TLV data...]
```

For command responses (on the Command Response characteristic):
```
[CommandID (1 byte)] [Status (1 byte)] [optional response data...]
```

## TLV (Type-Length-Value) Encoding

### TLV Structure

Each TLV entry follows this format:

```
┌─────────┬─────────┬─────────────┐
│ Type    │ Length  │ Value       │
│ (1 byte)│ (1 byte)│ (variable)  │
└─────────┴─────────┴─────────────┘
```

### TLV Types

The app supports numerous TLV types for different settings and status values:

```swift
enum TLVType: UInt8 {
    // Status TLVs
    case batteryLevel = 0x01
    case batteryPercentage = 0x02
    case isReady = 0x03
    case isRecording = 0x04
    case isUSBConnected = 0x05
    case sdCardRemaining = 0x06
    case isOverheating = 0x07
    case isBusy = 0x08
    case isEncoding = 0x09
    case gpsLock = 0x0A
    case isCold = 0x0B
    case sdCardWriteSpeedError = 0x0C
    case batteryPresent = 0x0D
    case externalBatteryPresent = 0x0E
    case connectedDevices = 0x0F
    case usbControlled = 0x10
    case cameraControlId = 0x11

    // Settings TLVs
    case videoResolution = 0x20
    case framesPerSecond = 0x21
    case autoPowerDown = 0x22
    case gps = 0x23
    case videoLens = 0x24
    case antiFlicker = 0x25
    case hypersmooth = 0x26
    case maxLens = 0x27
    case videoPerformanceMode = 0x28
    case colorProfile = 0x29
    case lcdBrightness = 0x2A
    case isoMax = 0x2B
    case language = 0x2C
    case voiceControl = 0x2D
    case beeps = 0x2E
    case isoMin = 0x2F
    case protuneEnabled = 0x30
    case whiteBalance = 0x31
    case ev = 0x32
    case bitrate = 0x33
    case rawAudio = 0x34
    case mode = 0x35
    case shutter = 0x36
    case led = 0x37
    case wind = 0x38
    case hindsight = 0x39
    case quickCapture = 0x3A
    case voiceLanguageControl = 0x3B

    // Additional settings
    case privacy = 0x40
    case autoLock = 0x41
    case wakeOnVoice = 0x42
    case timer = 0x43
    case videoCompression = 0x44
    case landscapeLock = 0x45
    case screenSaverFront = 0x46
    case screenSaverRear = 0x47
    case defaultPreset = 0x48
    case frontLcdMode = 0x49
    case gopSize = 0x4A
    case idrInterval = 0x4B
    case bitRateMode = 0x4C
    case audioProtune = 0x4D
    case noAudioTrack = 0x4E
}
```

## Command Structure

### Command Format

Commands sent to the camera follow this structure:

```swift
struct GoProCommand {
    let commandID: UInt8
    let parameters: [UInt8]
    let expectedResponse: ResponseType
}
```

### Common Commands

#### 1. **Get Settings Command**
```swift
let getSettingsCommand = GoProCommand(
    commandID: 0x01,
    parameters: [0x01], // Get all settings
    expectedResponse: .settings
)
```

#### 2. **Set Settings Command**
```swift
let setResolutionCommand = GoProCommand(
    commandID: 0x02,
    parameters: [
        0x20, // TLV Type: videoResolution
        0x01, // Length: 1 byte
        0x01  // Value: 4K
    ],
    expectedResponse: .acknowledgment
)
```

#### 3. **Get Status Command**
```swift
let getStatusCommand = GoProCommand(
    commandID: 0x03,
    parameters: [0x01], // Get all status
    expectedResponse: .status
)
```

#### 4. **Control Commands**
```swift
let startRecordingCommand = GoProCommand(
    commandID: 0x10,
    parameters: [0x01], // Start recording
    expectedResponse: .acknowledgment
)

let stopRecordingCommand = GoProCommand(
    commandID: 0x10,
    parameters: [0x00], // Stop recording
    expectedResponse: .acknowledgment
)
```

## Response Processing

### Response Types

Responses are parsed into strongly-typed `ResponseType` enum:

```swift
enum ResponseType {
    // Status responses
    case batteryLevel(Int)
    case batteryPercentage(Int)
    case overheating(Bool)
    case isBusy(Bool)
    case encoding(Bool)
    case videoEncodingDuration(Int32)
    case sdCardRemaining(Int64)
    case gpsLock(Bool)
    case isReady(Bool)
    case isCold(Bool)
    case sdCardWriteSpeedError(Bool)
    case usbConnected(Bool)
    case batteryPresent(Bool)
    case externalBatteryPresent(Bool)
    case connectedDevices(Int8)
    case usbControlled(Bool)
    case cameraControlId(Int)

    // Settings responses
    case videoResolution(Int)
    case framesPerSecond(Int)
    case autoPowerDown(Int)
    case gps(Bool)
    case videoLens(Int)
    case antiFlicker(Int)
    case hypersmooth(Int)
    case maxLens(Bool)
    case videoPerformanceMode(Int)
    case colorProfile(Int)
    case lcdBrightness(Int)
    case isoMax(Int)
    case language(Int)
    case voiceControl(Bool)
    case beeps(Int)
    case isoMin(Int)
    case protuneEnabled(Bool)
    case whiteBalance(Int)
    case ev(Int)
    case bitrate(Int)
    case rawAudio(Int)
    case mode(Int)
    case shutter(Int)
    case led(Int)
    case wind(Int)
    case hindsight(Int)
    case quickCapture(Bool)
    case voiceLanguageControl(Int)

    // Additional responses
    case privacy(Int)
    case autoLock(Int)
    case wakeOnVoice(Bool)
    case timer(Int)
    case videoCompression(Int)
    case landscapeLock(Int)
    case screenSaverFront(Int)
    case screenSaverRear(Int)
    case defaultPreset(Int)
    case frontLcdMode(Int)
    case gopSize(Int)
    case idrInterval(Int)
    case bitRateMode(Int)
    case audioProtune(Bool)
    case noAudioTrack(Bool)

    // Control responses
    case cameraControlStatus(Bool)
    case allowControlOverUsb(Bool)
    case turboTransfer(Bool)
    case sdRatingCheckError(Bool)
    case videoLowTempAlert(Bool)
    case battOkayForOta(Bool)
    case firstTimeUse(Bool)
    case mobileFriendlyVideo(Bool)
    case analyticsReady(Bool)
    case analyticsSize(Int)
    case nextPollMsec(Int)
    case inContextualMenu(Bool)
    case creatingPreset(Bool)
    case linuxCoreActive(Bool)
}
```

### TLV Parsing

The `GoProBLEParser` class handles TLV parsing:

```swift
private func parseTLVData(_ data: Data, queryID: UInt8) -> [ResponseType] {
    var responses: [ResponseType] = []
    var offset = 0

    while offset < data.count {
        guard offset + 2 <= data.count else { break }

        let type = data[offset]
        let length = data[offset + 1]

        guard offset + 2 + Int(length) <= data.count else { break }

        let valueData = data.subdata(in: (offset + 2)..<(offset + 2 + Int(length)))
        let response = parseTLVEntry(type: type, value: valueData)

        if let response = response {
            responses.append(response)
        }

        offset += 2 + Int(length)
    }

    return responses
}
```

## Multi-Packet Message Handling

### Packet Reconstruction

For large responses that span multiple packets, the parser implements packet reconstruction:

```swift
private func handleContinuationPacket(data: Data, peripheralId: String) -> [ResponseType] {
    let bufferKey = "\(peripheralId):\(currentQueryID)"

    // Append data to existing buffer
    if var existingBuffer = continuationBuffer[bufferKey] {
        existingBuffer.append(data)
        continuationBuffer[bufferKey] = existingBuffer

        // Check if message is complete
        if let expectedLength = expectedMessageLength[bufferKey],
           existingBuffer.count >= expectedLength {

            let responses = parseTLVData(existingBuffer, queryID: UInt8(currentQueryID))

            // Clear buffer
            continuationBuffer.removeValue(forKey: bufferKey)
            expectedMessageLength.removeValue(forKey: bufferKey)
            lastPacketTime.removeValue(forKey: bufferKey)

            return responses
        }
    }

    return []
}
```

### Buffer Management

The parser maintains buffers for each peripheral and query ID:

```swift
// Continuation packet buffers for message reconstruction
private var continuationBuffer: [String: Data] = [:] // Key: "peripheralID:queryID"
private var expectedMessageLength: [String: Int] = [:] // Key: "peripheralID:queryID"
private var lastPacketTime: [String: Date] = [:] // Track when last packet was received
```

## Connection Management

### Discovery Process

```swift
func startScanning() {
    guard centralManager.state == .poweredOn else {
        log("Central manager not powered on")
        return
    }

    log("Starting scan for GoPro devices...")
    isScanning = true

    // Scan for GoPro devices with specific service UUIDs
    centralManager.scanForPeripherals(
        withServices: [GoProServiceUUID],
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    )
}
```

### Connection Process

```swift
func connectToGoPro(_ peripheral: CBPeripheral) {
    log("Attempting to connect to \(peripheral.name ?? "unknown device")")

    // Store peripheral for connection
    discoveredPeripherals[peripheral.identifier] = peripheral

    // Attempt connection
    centralManager.connect(peripheral, options: nil)

    // Set connection timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout) {
        self.handleConnectionTimeout(for: peripheral.identifier)
    }
}
```

### Connection Retry Logic

```swift
private func attemptReconnection(for peripheral: CBPeripheral) {
    let retryCount = connectionRetryCount[peripheral.identifier] ?? 0

    if retryCount < maxRetryAttempts {
        log("Attempting reconnection \(retryCount + 1)/\(maxRetryAttempts) for \(peripheral.name ?? "unknown device")")

        connectionRetryCount[peripheral.identifier] = retryCount + 1

        // Exponential backoff
        let delay = TimeInterval(pow(2.0, Double(retryCount))) * baseRetryDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.centralManager.connect(peripheral, options: nil)
        }
    } else {
        log("Max retry attempts reached for \(peripheral.name ?? "unknown device")")
        connectionRetryCount.removeValue(forKey: peripheral.identifier)
    }
}
```

## Command Queue Management

### Command Sending

```swift
private func sendCommand(_ command: GoProCommand, to gopro: GoPro) {
    guard gopro.hasControl else {
        log("No control over \(gopro.name ?? "unknown camera")")
        return
    }

    // Add to pending commands queue
    pendingCommands[gopro.id] = command

    // Prepare command data
    var commandData = Data()
    commandData.append(command.commandID)
    commandData.append(contentsOf: command.parameters)

    // Send command
    if let characteristic = getControlCharacteristic(for: gopro) {
        gopro.peripheral.writeValue(commandData, for: characteristic, type: .withResponse)

        log("Sent command \(String(format: "0x%02X", command.commandID)) to \(gopro.name ?? "unknown camera")")

        // Set command timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + commandTimeout) {
            self.handleCommandTimeout(for: gopro.id)
        }
    }
}
```

### Response Handling

```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard error == nil else {
        log("Error receiving data: \(error!.localizedDescription)")
        return
    }

    guard let data = characteristic.value else {
        log("No data received")
        return
    }

    // Find corresponding GoPro
    guard let gopro = connectedGopros.first(where: { $0.peripheral == peripheral }) else {
        log("Received data from unknown peripheral")
        return
    }

    // Parse response
    let responses = parser.processPacket(data, peripheralId: peripheral.identifier.uuidString)

    // Update GoPro settings based on responses
    for response in responses {
        updateGoProSettings(gopro, with: response)
    }

    // Handle pending commands
    handleCommandResponse(for: gopro.id, responses: responses)
}
```

## Error Handling

### Connection Errors

```swift
func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    log("Failed to connect to \(peripheral.name ?? "a device"): \(error?.localizedDescription ?? "unknown error")")

    // Log error for crash reporting
    CrashReporter.shared.logError(
        "BLE Connection Failed",
        error: error,
        context: [
            "peripheral_name": peripheral.name ?? "Unknown",
            "retry_count": "\(connectionRetryCount[peripheral.identifier] ?? 0)"
        ]
    )

    // Attempt reconnection
    attemptReconnection(for: peripheral)
}
```

### Command Timeouts

```swift
private func handleCommandTimeout(for goproId: UUID) {
    guard let command = pendingCommands[goproId] else { return }

    log("Command timeout for \(String(format: "0x%02X", command.commandID))")

    // Remove from pending commands
    pendingCommands.removeValue(forKey: goproId)

    // Log timeout for crash reporting
    CrashReporter.shared.logError(
        "BLE Command Timeout",
        error: nil,
        context: [
            "command_id": String(format: "0x%02X", command.commandID),
            "gopro_id": goproId.uuidString
        ]
    )
}
```

## Performance Optimizations

### Command Batching

```swift
private func batchCommands(_ commands: [GoProCommand]) -> [GoProCommand] {
    // Group related commands to reduce BLE overhead
    var batchedCommands: [GoProCommand] = []
    var currentBatch: [UInt8] = []

    for command in commands {
        if currentBatch.count + command.parameters.count > maxBatchSize {
            // Flush current batch
            if !currentBatch.isEmpty {
                batchedCommands.append(GoProCommand(
                    commandID: 0x0F, // Batch command
                    parameters: currentBatch,
                    expectedResponse: .acknowledgment
                ))
                currentBatch = []
            }
        }

        currentBatch.append(command.commandID)
        currentBatch.append(contentsOf: command.parameters)
    }

    // Add final batch
    if !currentBatch.isEmpty {
        batchedCommands.append(GoProCommand(
            commandID: 0x0F,
            parameters: currentBatch,
            expectedResponse: .acknowledgment
        ))
    }

    return batchedCommands
}
```

### Connection Pooling

```swift
private func manageConnectionPool() {
    let maxConnections = 5 // Limit concurrent connections

    if connectedGopros.count >= maxConnections {
        // Disconnect oldest connection
        if let oldestGopro = connectedGopros.first {
            disconnectFromGoPro(oldestGopro)
        }
    }
}
```

## Security Considerations

### Device Validation

```swift
private func validateGoProDevice(_ peripheral: CBPeripheral) -> Bool {
    // Validate device name pattern
    guard let name = peripheral.name else { return false }

    // GoPro devices typically have names like "GP12345678" or "HERO10 Black"
    let goProNamePattern = #"^(GP\d{8}|HERO\d+\s+\w+)$"#
    return name.range(of: goProNamePattern, options: .regularExpression) != nil
}
```

### Command Validation

```swift
private func validateCommand(_ command: GoProCommand) -> Bool {
    // Validate command ID range
    guard command.commandID >= 0x01 && command.commandID <= 0xFF else {
        return false
    }

    // Validate parameter length
    guard command.parameters.count <= maxParameterLength else {
        return false
    }

    return true
}
```

## Debugging and Logging

### Packet Logging

```swift
private func logPacket(_ data: Data, direction: String) {
    let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
    log("\(direction) packet: \(hexString)")
}
```

### Connection State Logging

```swift
private func logConnectionState(_ state: CBPeripheralState, for peripheral: CBPeripheral) {
    let stateString: String
    switch state {
    case .disconnected:
        stateString = "Disconnected"
    case .connecting:
        stateString = "Connecting"
    case .connected:
        stateString = "Connected"
    case .disconnecting:
        stateString = "Disconnecting"
    @unknown default:
        stateString = "Unknown"
    }

    log("\(peripheral.name ?? "Unknown device") state: \(stateString)")
}
```

## Conclusion

The BLE protocol implementation provides a robust foundation for GoPro camera communication. The packet-based approach with TLV encoding allows for efficient transmission of complex settings and status data, while the multi-packet reconstruction handles large responses gracefully.

The connection management system includes sophisticated retry logic and error handling, ensuring reliable communication even in challenging network conditions. The command queue system prevents flooding the camera with commands while maintaining responsiveness.

This implementation supports the full range of GoPro camera settings and status monitoring, making it suitable for professional camera management applications.
