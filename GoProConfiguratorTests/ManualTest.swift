import Foundation

// Manual test for GoProBLEParser based on official GoPro OpenGoPro tutorial
// https://gopro.github.io/OpenGoPro/tutorials/parse-ble-responses#parsing-multiple-packet-tlv-responses

// Copy the GoProBLEParser class here for testing
class GoProBLEParser {

    // MARK: - Packet Reconstruction

    /// Continuation packet buffers for message reconstruction
    private var continuationBuffer: [String: Data] = [:] // Key: "peripheralID:queryID"
    private var expectedMessageLength: [String: Int] = [:] // Key: "peripheralID:queryID"
    private var bytesRemaining: [String: Int] = [:] // Track remaining bytes per peripheral

    /// Process a BLE packet and return parsed responses if complete
    /// - Parameters:
    ///   - data: Raw packet data from BLE
    ///   - peripheralId: Unique identifier for the peripheral
    /// - Returns: Array of parsed response types, empty if message is incomplete
    func processPacket(_ data: Data, peripheralId: String) -> [String] {
        guard !data.isEmpty else {
            return []
        }

        // Parse packet header according to GoPro BLE protocol
        let packetHeader = data[0]
        let packetType = (packetHeader >> 6) & 0x03 // Extract bits 7-6 for packet type
        let isContinuation = (packetHeader & 0x40) != 0 // Check continuation bit

        // Handle continuation packets (packet type 2 or continuation bit set)
        if packetType == 2 || isContinuation {
            return handleContinuationPacket(data: data, peripheralId: peripheralId)
        }

        // Handle initial packets (general packets)
        if data.count >= 4 {
            // Format: [Header (length)] [Operation ID] [Status] [Response data...]
            let totalLength = Int(data[0]) // First byte is total length
            let operationID = Int(data[1]) // Second byte is operation ID
            let status = data[2] // Third byte is status

            if status == 0x00 { // Success
                let responseData = data.subdata(in: 3..<data.count)
                let bufferKey = "\(peripheralId):\(operationID)"

                // Initialize buffer for this operation
                continuationBuffer[bufferKey] = responseData
                expectedMessageLength[bufferKey] = totalLength - 2 // Subtract header bytes
                bytesRemaining[bufferKey] = totalLength - 2 - responseData.count

                // Check if we have the complete message
                if responseData.count >= (totalLength - 2) {
                    let responses = parseTLVData(responseData, operationID: UInt8(operationID))

                    // Clear the buffer
                    continuationBuffer.removeValue(forKey: bufferKey)
                    expectedMessageLength.removeValue(forKey: bufferKey)
                    bytesRemaining.removeValue(forKey: bufferKey)

                    return responses
                } else {
                    return [] // Wait for continuation packets
                }
            }
        }

        return []
    }

    /// Handle continuation packets by appending data to existing buffers
    private func handleContinuationPacket(data: Data, peripheralId: String) -> [String] {
        guard data.count >= 1 else {
            return []
        }

        let packetHeader = data[0]
        let _ = packetHeader & 0x0F // Lower 4 bits are sequence counter (unused in this implementation)
        let responseData = data.subdata(in: 1..<data.count)

        // Find the buffer for this peripheral
        let bufferKeys = continuationBuffer.keys.filter { $0.hasPrefix(peripheralId) }

        if bufferKeys.isEmpty {
            return []
        }

        guard let bufferKey = bufferKeys.first,
              var buffer = continuationBuffer[bufferKey],
              let _ = expectedMessageLength[bufferKey],
              var remaining = bytesRemaining[bufferKey] else {
            return []
        }

        // Append to buffer
        buffer.append(responseData)
        continuationBuffer[bufferKey] = buffer
        remaining -= responseData.count
        bytesRemaining[bufferKey] = remaining

        // Check if we have the complete message
        if remaining <= 0 {
            // Extract operation ID from buffer key
            let operationIDString = bufferKey.split(separator: ":")[1]
            let operationID = UInt8(operationIDString) ?? 0

            let responses = parseTLVData(buffer, operationID: operationID)

            // Clear the buffer
            continuationBuffer.removeValue(forKey: bufferKey)
            expectedMessageLength.removeValue(forKey: bufferKey)
            bytesRemaining.removeValue(forKey: bufferKey)

            return responses
        }

        return [] // Still waiting for more packets
    }

    /// Parse TLV (Type-Length-Value) data into response types
    private func parseTLVData(_ data: Data, operationID: UInt8) -> [String] {
        var responses: [String] = []
        var offset = 0

        while offset < data.count {
            guard offset + 2 <= data.count else {
                break
            }

            let type = data[offset]
            let length = Int(data[offset + 1])

            guard offset + 2 + length <= data.count else {
                break
            }

            let valueData = data.subdata(in: (offset + 2)..<(offset + 2 + length))
            let value = parseValue(valueData)

            let response = mapToResponseType(type: type, value: value, operationID: operationID)
            responses.append(response)

            offset += 2 + length
        }

        return responses
    }

    /// Parse a value from raw data
    private func parseValue(_ data: Data) -> Int {
        var value: Int = 0
        for (index, byte) in data.enumerated() {
            value += Int(byte) << (index * 8)
        }
        return value
    }

    /// Map TLV type and value to ResponseType
    private func mapToResponseType(type: UInt8, value: Int, operationID: UInt8) -> String {
        switch operationID {
        case 19: // Status query
            return mapStatusResponse(type: type, value: value)
        case 20: // Settings query
            return mapSettingsResponse(type: type, value: value)
        default:
            return "Unknown operation ID: \(operationID), Type: \(type), Value: \(value)"
        }
    }

    /// Map status response types
    private func mapStatusResponse(type: UInt8, value: Int) -> String {
        switch type {
        case 1: return "Battery Level: \(value)"
        case 2: return "Battery Percentage: \(value)%"
        case 6: return "Overheating: \(value != 0)"
        case 8: return "Is Busy: \(value != 0)"
        case 10: return "Encoding: \(value != 0)"
        case 13: return "Video Encoding Duration: \(value)"
        case 31: return "SD Card Remaining: \(value)"
        case 54: return "USB Connected: \(value != 0)"
        case 68: return "GPS Lock: \(value != 0)"
        case 70: return "WiFi Bars: \(value)"
        case 82: return "Camera Mode: \(value)"
        case 85: return "Video Mode: \(value)"
        case 111: return "Photo Mode: \(value)"
        case 114: return "Multi Shot Mode: \(value)"
        case 115: return "Shutter: \(value)"
        case 116: return "Flat Mode: \(value)"
        default:
            return "Unknown status type: \(type) with value: \(value)"
        }
    }

    /// Map settings response types
    private func mapSettingsResponse(type: UInt8, value: Int) -> String {
        switch type {
        case 32: return "Video Resolution: \(value)"
        case 18: return "Frames Per Second: \(value)"
        case 2: return "Auto Power Down: \(value)"
        case 3: return "GPS: \(value != 0)"
        case 59: return "Video Lens: \(value)"
        case 83: return "Anti Flicker: \(value)"
        case 121: return "Hypersmooth: \(value)"
        case 134: return "Max Lens: \(value != 0)"
        case 135: return "Video Performance Mode: \(value)"
        case 162: return "Color Profile: \(value)"
        case 173: return "LCD Brightness: \(value)"
        case 149: return "ISO Max: \(value)"
        case 118: return "Language: \(value)"
        case 124: return "Voice Control: \(value != 0)"
        case 139: return "Beeps: \(value)"
        case 144: return "ISO Min: \(value)"
        case 145: return "Protune Enabled: \(value != 0)"
        case 13: return "White Balance: \(value)"
        case 91: return "EV: \(value)"
        case 115: return "Bitrate: \(value)"
        case 116: return "Raw Audio: \(value)"
        case 167: return "Mode: \(value)"
        case 84: return "Shutter: \(value)"
        case 86: return "LED: \(value)"
        case 87: return "Wind: \(value)"
        case 88: return "Hindsight: \(value)"
        case 114: return "Quick Capture: \(value != 0)"
        case 54: return "Voice Language Control: \(value)"
        case 85: return "Video Protune: \(value != 0)"
        case 102: return "Video Stabilization: \(value)"
        case 96: return "Video Field of View: \(value)"
        default:
            return "Unknown settings type: \(type) with value: \(value)"
        }
    }

    /// Clear all buffers (useful for testing and error recovery)
    func clearBuffers() {
        continuationBuffer.removeAll()
        expectedMessageLength.removeAll()
        bytesRemaining.removeAll()
    }

    /// Get current buffer state (useful for testing)
    func getBufferState() -> (buffers: [String: Data], expectedLengths: [String: Int], remaining: [String: Int]) {
        return (continuationBuffer, expectedMessageLength, bytesRemaining)
    }
}

// XCTest test class for GoProBLEParser
import XCTest

class GoProBLEParserTests: XCTestCase {

    var parser: GoProBLEParser!

    override func setUp() {
        super.setUp()
        parser = GoProBLEParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testSinglePacketResponse() {
        // Test 1: Single packet response (like Get Version Command)
        // Format: [Header (length)] [Operation ID] [Status] [Response data...]
        // Fixed: 0x0E = 14 bytes total, 0x13 = Operation ID 19, 0x00 = Success, then TLV data
        let singlePacketData = Data([0x0E, 0x13, 0x00, 0x01, 0x01, 0x03, 0x02, 0x01, 0x00, 0x06, 0x01, 0x00, 0x08, 0x01, 0x00])
        let responses = parser.processPacket(singlePacketData, peripheralId: "test-peripheral")

        XCTAssertFalse(responses.isEmpty, "Single packet should return responses")
        print("Single packet responses: \(responses)")
    }

    func testMultipartResponse() {
        // Test 2: Multipart response (like Hardware Info) - using actual GoPro example
        // Fixed: Status should be 0x00 for success, not 0x3C
        let firstPacketData = Data([0x20, 0x5B, 0x00, 0x04, 0x00, 0x00, 0x00, 0x3E, 0x0C, 0x48, 0x45, 0x52, 0x4F, 0x31, 0x32, 0x20, 0x42, 0x6C, 0x61])
        let firstResponses = parser.processPacket(firstPacketData, peripheralId: "test-peripheral")

        // First packet should not be complete
        XCTAssertTrue(firstResponses.isEmpty, "First packet should not be complete")

        // Continuation packets based on tutorial: 80:63:6B:04:30:78:30:35:0F:48:32:33:2E:30:31:2E:30:31:2E:39
        let continuationPacket1 = Data([0x80, 0x63, 0x6B, 0x04, 0x30, 0x78, 0x30, 0x35, 0x0F, 0x48, 0x32, 0x33, 0x2E, 0x30, 0x31, 0x2E, 0x30, 0x31, 0x2E, 0x39])
        let responses2 = parser.processPacket(continuationPacket1, peripheralId: "test-peripheral")

        XCTAssertFalse(responses2.isEmpty, "Continuation packet should return responses")
        print("Multipart responses: \(responses2)")
    }

    func testBatteryPercentage() {
        // Test 3: Battery percentage test (97%) - using correct format
        // Format: [0x05] [0x13] [0x00] [0x02] [0x01] [0x61]
        // 0x05 = 5 bytes total, 0x13 = Operation ID 19, 0x00 = Success, 0x02 0x01 0x61 = TLV data
        let batteryPacketData = Data([0x05, 0x13, 0x00, 0x02, 0x01, 0x61]) // 0x61 = 97
        let batteryResponses = parser.processPacket(batteryPacketData, peripheralId: "test-peripheral")

        XCTAssertFalse(batteryResponses.isEmpty, "Battery packet should return responses")
        XCTAssertTrue(batteryResponses.contains { $0.contains("97%") }, "Should contain 97% battery")
        print("Battery responses: \(batteryResponses)")
    }

    func testSettingsQuery() {
        // Test 4: Settings query - using correct format
        // Format: [0x05] [0x14] [0x00] [0x20] [0x01] [0x02]
        // 0x05 = 5 bytes total, 0x14 = Operation ID 20, 0x00 = Success, 0x20 0x01 0x02 = TLV data
        let settingsPacketData = Data([0x05, 0x14, 0x00, 0x20, 0x01, 0x02]) // Video Resolution: 2
        let settingsResponses = parser.processPacket(settingsPacketData, peripheralId: "test-peripheral")

        XCTAssertFalse(settingsResponses.isEmpty, "Settings packet should return responses")
        XCTAssertTrue(settingsResponses.contains { $0.contains("Video Resolution: 2") }, "Should contain Video Resolution: 2")
        print("Settings responses: \(settingsResponses)")
    }

    // MARK: - Additional Protocol Tests

    func testErrorPacket() {
        // Test 5: Error packet - status code 0x01 (error)
        let errorPacketData = Data([0x05, 0x13, 0x01, 0x02, 0x01, 0x61]) // Error status
        let errorResponses = parser.processPacket(errorPacketData, peripheralId: "test-peripheral")

        // Should not process error packets (status != 0x00)
        XCTAssertTrue(errorResponses.isEmpty, "Error packets should not be processed")
        print("Error packet responses: \(errorResponses)")
    }

    func testMultiByteValues() {
        // Test 6: Multi-byte TLV values (2-byte and 4-byte integers)
        // Format: [0x08] [0x13] [0x00] [0x02] [0x02] [0x61] [0x00] [0x31] [0x04] [0x00] [0x00] [0x00] [0x01]
        // 0x08 = 8 bytes total, 0x13 = Operation ID 19, 0x00 = Success
        // 0x02 0x02 0x61 0x00 = 2-byte value (0x0061 = 97)
        // 0x31 0x04 0x00 0x00 0x00 0x01 = 4-byte value (0x01000000 = 16777216)
        let multiBytePacketData = Data([0x08, 0x13, 0x00, 0x02, 0x02, 0x61, 0x00, 0x31, 0x04, 0x00, 0x00, 0x00, 0x01])
        let multiByteResponses = parser.processPacket(multiBytePacketData, peripheralId: "test-peripheral")

        XCTAssertFalse(multiByteResponses.isEmpty, "Multi-byte packet should return responses")
        XCTAssertTrue(multiByteResponses.contains { $0.contains("97%") }, "Should contain 2-byte battery value")
        print("Multi-byte responses: \(multiByteResponses)")
    }

    func testMalformedPacket() {
        // Test 7: Malformed packet - TLV length extends beyond packet bounds
        let malformedPacketData = Data([0x05, 0x13, 0x00, 0x02, 0x10, 0x61]) // Length 16 but only 1 byte available
        let malformedResponses = parser.processPacket(malformedPacketData, peripheralId: "test-peripheral")

        // Should handle gracefully without crashing
        XCTAssertTrue(malformedResponses.isEmpty, "Malformed packets should be handled gracefully")
        print("Malformed packet responses: \(malformedResponses)")
    }

    func testUnknownOperationID() {
        // Test 8: Unknown operation ID (not 19 or 20)
        let unknownOpPacketData = Data([0x05, 0x99, 0x00, 0x02, 0x01, 0x61]) // Operation ID 153
        let unknownOpResponses = parser.processPacket(unknownOpPacketData, peripheralId: "test-peripheral")

        // Should process unknown operation IDs and provide descriptive feedback
        XCTAssertFalse(unknownOpResponses.isEmpty, "Unknown operation IDs should be processed")
        XCTAssertTrue(unknownOpResponses.contains { $0.contains("Unknown operation ID: 153") }, "Should contain unknown operation ID message")
        print("Unknown operation ID responses: \(unknownOpResponses)")
    }

    func testBufferStateManagement() {
        // Test 9: Buffer state management and cleanup
        let parser = GoProBLEParser()

        // Start a multipart response
        let firstPacketData = Data([0x20, 0x5B, 0x00, 0x04, 0x00, 0x00, 0x00, 0x3E, 0x0C, 0x48, 0x45, 0x52, 0x4F, 0x31, 0x32, 0x20, 0x42, 0x6C, 0x61])
        let _ = parser.processPacket(firstPacketData, peripheralId: "test-peripheral")

        // Check buffer state
        let bufferState = parser.getBufferState()
        XCTAssertFalse(bufferState.buffers.isEmpty, "Should have buffer after first packet")

        // Clear buffers
        parser.clearBuffers()
        let clearedState = parser.getBufferState()
        XCTAssertTrue(clearedState.buffers.isEmpty, "Buffers should be cleared")
        print("Buffer state management test passed")
    }

    func testMultiplePeripherals() {
        // Test 10: Multiple peripherals with independent buffers
        let parser = GoProBLEParser()

        // Start multipart response for peripheral A
        let firstPacketA = Data([0x20, 0x5B, 0x00, 0x04, 0x00, 0x00, 0x00, 0x3E, 0x0C, 0x48, 0x45, 0x52, 0x4F, 0x31, 0x32, 0x20, 0x42, 0x6C, 0x61])
        let _ = parser.processPacket(firstPacketA, peripheralId: "peripheral-A")

        // Start different response for peripheral B
        let firstPacketB = Data([0x0E, 0x13, 0x00, 0x01, 0x01, 0x03, 0x02, 0x01, 0x00, 0x06, 0x01, 0x00, 0x08, 0x01, 0x00])
        let responsesB = parser.processPacket(firstPacketB, peripheralId: "peripheral-B")

        // Peripheral B should complete immediately
        XCTAssertFalse(responsesB.isEmpty, "Peripheral B should complete immediately")

        // Check buffer state
        let bufferState = parser.getBufferState()
        XCTAssertTrue(bufferState.buffers.keys.contains { $0.hasPrefix("peripheral-A") }, "Should have buffer for peripheral A")
        XCTAssertFalse(bufferState.buffers.keys.contains { $0.hasPrefix("peripheral-B") }, "Should not have buffer for peripheral B")

        print("Multiple peripherals test passed")
    }

    func testContinuationPacketSequence() {
        // Test 11: Proper continuation packet sequence handling
        let parser = GoProBLEParser()

        // Start multipart response
        let firstPacketData = Data([0x20, 0x5B, 0x00, 0x04, 0x00, 0x00, 0x00, 0x3E, 0x0C, 0x48, 0x45, 0x52, 0x4F, 0x31, 0x32, 0x20, 0x42, 0x6C, 0x61])
        let _ = parser.processPacket(firstPacketData, peripheralId: "test-peripheral")

        // Send continuation packet
        let continuationPacket1 = Data([0x80, 0x63, 0x6B, 0x04, 0x30, 0x78, 0x30, 0x35, 0x0F, 0x48, 0x32, 0x33, 0x2E, 0x30, 0x31, 0x2E, 0x30, 0x31, 0x2E, 0x39])
        let responses = parser.processPacket(continuationPacket1, peripheralId: "test-peripheral")

        // Should complete the message
        XCTAssertFalse(responses.isEmpty, "Continuation packet should complete the message")

        // Buffer should be cleared
        let bufferState = parser.getBufferState()
        XCTAssertTrue(bufferState.buffers.isEmpty, "Buffer should be cleared after completion")

        print("Continuation packet sequence test passed")
    }

    func testRealGoProData() {
        // Test 12: Real GoPro data from user logs - this is the most important test!
        // This uses the exact packet sequence from your actual GoPro device
        let parser = GoProBLEParser()
        let peripheralId = "2842C0A5-45B9-25F4-574A-F265889ED53B"

        // First packet: 20 3f 13 00 01 01 01 02 01 04 06 01 00 08 01 00 0a 01 00 0d
        let firstPacket = Data([0x20, 0x3f, 0x13, 0x00, 0x01, 0x01, 0x01, 0x02, 0x01, 0x04, 0x06, 0x01, 0x00, 0x08, 0x01, 0x00, 0x0a, 0x01, 0x00, 0x0d])
        let responses1 = parser.processPacket(firstPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses1.isEmpty, "First packet should be incomplete")

        // Second packet: 80 04 00 00 00 00 1f 01 00 36 08 00 00 00 00 1d c2 a4 00 3a
        let secondPacket = Data([0x80, 0x04, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x01, 0x00, 0x36, 0x08, 0x00, 0x00, 0x00, 0x00, 0x1d, 0xc2, 0xa4, 0x00, 0x3a])
        let responses2 = parser.processPacket(secondPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses2.isEmpty, "Second packet should be incomplete")

        // Third packet: 81 01 00 44 01 00 46 01 63 52 01 01 55 01 00 6f 01 00 72 01
        let thirdPacket = Data([0x81, 0x01, 0x00, 0x44, 0x01, 0x00, 0x46, 0x01, 0x63, 0x52, 0x01, 0x01, 0x55, 0x01, 0x00, 0x6f, 0x01, 0x00, 0x72, 0x01])
        let responses3 = parser.processPacket(thirdPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses3.isEmpty, "Third packet should be incomplete")

        // Fourth packet: 82 02 73 01 00 74 01 00
        let fourthPacket = Data([0x82, 0x02, 0x73, 0x01, 0x00, 0x74, 0x01, 0x00])
        let responses4 = parser.processPacket(fourthPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses4.isEmpty, "Fourth packet should still be incomplete")

        // Fifth packet: 0b 12 00 36 01 00 55 01 00 66 01 08
        let fifthPacket = Data([0x0b, 0x12, 0x00, 0x36, 0x01, 0x00, 0x55, 0x01, 0x00, 0x66, 0x01, 0x08])
        let responses5 = parser.processPacket(fifthPacket, peripheralId: peripheralId)

        // This should complete the message and return parsed responses
        XCTAssertFalse(responses5.isEmpty, "Fifth packet should complete the message")

        // Verify specific expected responses
        let responseStrings = responses4.joined(separator: ", ")
        print("Real GoPro responses: \(responseStrings)")

        // Check for expected battery percentage (should not be 4%)
        let hasBatteryPercentage = responses4.contains { $0.contains("Battery Percentage:") }
        XCTAssertTrue(hasBatteryPercentage, "Should contain battery percentage")

        // Check for various status fields we expect
        let hasUSBConnected = responses4.contains { $0.contains("USB Connected:") }
        XCTAssertTrue(hasUSBConnected, "Should contain USB connected status")

        // Verify buffer is cleared after completion
        let bufferState = parser.getBufferState()
        XCTAssertTrue(bufferState.buffers.isEmpty, "Buffer should be cleared after completion")

        print("Real GoPro data test completed successfully!")
    }

    func testRealGoProDataExpectedBytes() {
        // Test 13: Verify we extract the expected number of bytes from real data
        let parser = GoProBLEParser()
        let peripheralId = "2842C0A5-45B9-25F4-574A-F265889ED53B"

        // Process first packet (expect 63 bytes total)
        let firstPacket = Data([0x20, 0x3f, 0x13, 0x00, 0x01, 0x01, 0x01, 0x02, 0x01, 0x04, 0x06, 0x01, 0x00, 0x08, 0x01, 0x00, 0x0a, 0x01, 0x00, 0x0d])
        let _ = parser.processPacket(firstPacket, peripheralId: peripheralId)

        // Check initial buffer state
        var bufferState = parser.getBufferState()
        XCTAssertFalse(bufferState.buffers.isEmpty, "Should have buffer after first packet")

        let bufferKey = bufferState.buffers.keys.first!
        let initialBytes = bufferState.buffers[bufferKey]!.count
        let expectedTotalBytes = 63 // From packet header 0x3f

        print("Initial buffer: \(initialBytes) bytes, expecting \(expectedTotalBytes) total")
        XCTAssertEqual(initialBytes, 16, "First packet should contribute 16 bytes")

        // Process continuation packets and verify byte accumulation
        let secondPacket = Data([0x80, 0x04, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x01, 0x00, 0x36, 0x08, 0x00, 0x00, 0x00, 0x00, 0x1d, 0xc2, 0xa4, 0x00, 0x3a])
        let _ = parser.processPacket(secondPacket, peripheralId: peripheralId)

        bufferState = parser.getBufferState()
        let bytesAfterSecond = bufferState.buffers[bufferKey]!.count
        print("After second packet: \(bytesAfterSecond) bytes")

        // With our fix, we should extract 19 bytes from the second packet (not 17)
        XCTAssertEqual(bytesAfterSecond, initialBytes + 19, "Second packet should contribute 19 bytes with the fix")

        // Process third packet
        let thirdPacket = Data([0x81, 0x01, 0x00, 0x44, 0x01, 0x00, 0x46, 0x01, 0x63, 0x52, 0x01, 0x01, 0x55, 0x01, 0x00, 0x6f, 0x01, 0x00, 0x72, 0x01])
        let _ = parser.processPacket(thirdPacket, peripheralId: peripheralId)

        bufferState = parser.getBufferState()
        let bytesAfterThird = bufferState.buffers[bufferKey]!.count
        print("After third packet: \(bytesAfterThird) bytes")

        // Third packet should contribute 19 bytes
        XCTAssertEqual(bytesAfterThird, bytesAfterSecond + 19, "Third packet should contribute 19 bytes")

        // Process fourth packet
        let fourthPacket = Data([0x82, 0x02, 0x73, 0x01, 0x00, 0x74, 0x01, 0x00])
        let _ = parser.processPacket(fourthPacket, peripheralId: peripheralId)

        bufferState = parser.getBufferState()
        let bytesAfterFourth = bufferState.buffers[bufferKey]!.count
        print("After fourth packet: \(bytesAfterFourth) bytes")

        // Fourth packet should contribute 7 bytes
        XCTAssertEqual(bytesAfterFourth, bytesAfterThird + 7, "Fourth packet should contribute 7 bytes")

        // Process fifth packet (the one that was being missed!)
        let fifthPacket = Data([0x0b, 0x12, 0x00, 0x36, 0x01, 0x00, 0x55, 0x01, 0x00, 0x66, 0x01, 0x08])
        let _ = parser.processPacket(fifthPacket, peripheralId: peripheralId)

        bufferState = parser.getBufferState()
        let bytesAfterFifth = bufferState.buffers[bufferKey]!.count
        print("After fifth packet: \(bytesAfterFifth) bytes")

        // Fifth packet should contribute 11 bytes and complete the message
        XCTAssertEqual(bytesAfterFifth, bytesAfterFourth + 11, "Fifth packet should contribute 11 bytes")
        XCTAssertEqual(bytesAfterFifth, 63, "Total should be exactly 63 bytes")

        print("Byte extraction verification completed!")
    }

    func testRealGoProDataWithFifthPacket() {
        // Test 15: Test the specific fifth packet issue from the latest real data
        let parser = GoProBLEParser()
        let peripheralId = "2842C0A5-45B9-25F4-574A-F265889ED53B"

        // First packet: 20 3f 13 00 01 01 01 02 01 04 06 01 00 08 01 00 0a 01 00 0d
        let firstPacket = Data([0x20, 0x3f, 0x13, 0x00, 0x01, 0x01, 0x01, 0x02, 0x01, 0x04, 0x06, 0x01, 0x00, 0x08, 0x01, 0x00, 0x0a, 0x01, 0x00, 0x0d])
        let responses1 = parser.processPacket(firstPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses1.isEmpty, "First packet should be incomplete")

        // Second packet: 80 04 00 00 00 00 1f 01 00 36 08 00 00 00 00 1d c2 a4 00 3a
        let secondPacket = Data([0x80, 0x04, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x01, 0x00, 0x36, 0x08, 0x00, 0x00, 0x00, 0x00, 0x1d, 0xc2, 0xa4, 0x00, 0x3a])
        let responses2 = parser.processPacket(secondPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses2.isEmpty, "Second packet should still be incomplete")

        // Third packet: 81 01 00 44 01 00 46 01 63 52 01 01 55 01 00 6f 01 00 72 01
        let thirdPacket = Data([0x81, 0x01, 0x00, 0x44, 0x01, 0x00, 0x46, 0x01, 0x63, 0x52, 0x01, 0x01, 0x55, 0x01, 0x00, 0x6f, 0x01, 0x00, 0x72, 0x01])
        let responses3 = parser.processPacket(thirdPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses3.isEmpty, "Third packet should still be incomplete")

        // Fourth packet: 82 02 73 01 00 74 01 00
        let fourthPacket = Data([0x82, 0x02, 0x73, 0x01, 0x00, 0x74, 0x01, 0x00])
        let responses4 = parser.processPacket(fourthPacket, peripheralId: peripheralId)
        XCTAssertTrue(responses4.isEmpty, "Fourth packet should still be incomplete")

        // Fifth packet: 0b 12 00 36 01 00 55 01 00 66 01 08
        // This is actually a SEPARATE message for query ID 18 (settings), not a continuation of query ID 19
        let fifthPacket = Data([0x0b, 0x12, 0x00, 0x36, 0x01, 0x00, 0x55, 0x01, 0x00, 0x66, 0x01, 0x08])
        let responses5 = parser.processPacket(fifthPacket, peripheralId: peripheralId)

        // This should return responses for the settings query (ID 18)
        XCTAssertFalse(responses5.isEmpty, "Fifth packet should return settings responses")

        // Check for specific responses from settings query (ID 18)
        let responseTypes = responses5.map { String(describing: $0) }
        // Query ID 18 responses should be settings-related, not status-related
        print("Query ID 18 responses: \(responseTypes)")

        // Verify that query ID 19 buffer is still incomplete (waiting for more packets)
        let bufferState = parser.getBufferState()
        let queryID19Buffer = bufferState.buffers["\(peripheralId):19"]
        XCTAssertNotNil(queryID19Buffer, "Query ID 19 buffer should still exist (incomplete)")
        XCTAssertEqual(queryID19Buffer?.count, 61, "Query ID 19 should still have 61 bytes (incomplete)")

        print("Fifth packet test completed successfully!")
    }

    func testTwoStreamsConcurrently() {
        // Test 16: Test handling of two concurrent streams (query ID 19 and 18)
        let parser = GoProBLEParser()
        let peripheralId = "2842C0A5-45B9-25F4-574A-F265889ED53B"

        // Process the multipart response for query ID 19 (4 packets, but incomplete)
        let packets = [
            Data([0x20, 0x3f, 0x13, 0x00, 0x01, 0x01, 0x01, 0x02, 0x01, 0x04, 0x06, 0x01, 0x00, 0x08, 0x01, 0x00, 0x0a, 0x01, 0x00, 0x0d]),
            Data([0x80, 0x04, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x01, 0x00, 0x36, 0x08, 0x00, 0x00, 0x00, 0x00, 0x1d, 0xc2, 0xa4, 0x00, 0x3a]),
            Data([0x81, 0x01, 0x00, 0x44, 0x01, 0x00, 0x46, 0x01, 0x63, 0x52, 0x01, 0x01, 0x55, 0x01, 0x00, 0x6f, 0x01, 0x00, 0x72, 0x01]),
            Data([0x82, 0x02, 0x73, 0x01, 0x00, 0x74, 0x01, 0x00])
        ]

        for (i, packet) in packets.enumerated() {
            let responses = parser.processPacket(packet, peripheralId: peripheralId)
            XCTAssertTrue(responses.isEmpty, "Packet \(i+1) should be incomplete for query ID 19")
        }

        // Verify query ID 19 buffer exists and has 61 bytes
        var bufferState = parser.getBufferState()
        XCTAssertEqual(bufferState.buffers["\(peripheralId):19"]?.count, 61, "Query ID 19 should have 61 bytes")

        // Process the settings response for query ID 18 (single packet, complete)
        let settingsPacket = Data([0x0b, 0x12, 0x00, 0x36, 0x01, 0x00, 0x55, 0x01, 0x00, 0x66, 0x01, 0x08])
        let settingsResponses = parser.processPacket(settingsPacket, peripheralId: peripheralId)
        XCTAssertFalse(settingsResponses.isEmpty, "Settings packet should return responses for query ID 18")

        // Verify both streams are tracked separately
        bufferState = parser.getBufferState()
        XCTAssertNotNil(bufferState.buffers["\(peripheralId):19"], "Query ID 19 buffer should still exist")
        XCTAssertNil(bufferState.buffers["\(peripheralId):18"], "Query ID 18 buffer should be cleared (complete)")

        // Simulate final packet to complete query ID 19 (need 2 more bytes)
        let finalPacket = Data([0x83, 0x02, 0xAA, 0xBB]) // 2 bytes of dummy data to complete
        let finalResponses = parser.processPacket(finalPacket, peripheralId: peripheralId)
        XCTAssertFalse(finalResponses.isEmpty, "Final packet should complete query ID 19")

        // Verify all buffers are now cleared
        bufferState = parser.getBufferState()
        XCTAssertTrue(bufferState.buffers.isEmpty, "All buffers should be cleared after completion")

        print("Two streams test completed successfully!")
    }

    func testSinglePacketFormat2() {
        // Test 17: Test the alternative single packet format [header][queryID][status][TLV]
        // This is the format used by query ID 18: 0b 12 00 36 01 00 55 01 00 66 01 08
        let parser = GoProBLEParser()
        let peripheralId = "test-peripheral"

        let packet = Data([0x0b, 0x12, 0x00, 0x36, 0x01, 0x00, 0x55, 0x01, 0x00, 0x66, 0x01, 0x08])
        let responses = parser.processPacket(packet, peripheralId: peripheralId)

        XCTAssertFalse(responses.isEmpty, "Single packet format 2 should return responses")

        // Verify the buffer is cleared immediately (single packet completion)
        let bufferState = parser.getBufferState()
        XCTAssertTrue(bufferState.buffers.isEmpty, "Buffer should be cleared for completed single packet")

        print("Single packet format 2 responses: \\(responses)")
        print("Single packet format 2 test completed successfully!")
    }

    func testInvalidPacketTypes() {
        // Test 14: Invalid packet types and edge cases
        let parser = GoProBLEParser()

        // Empty packet
        let emptyResponses = parser.processPacket(Data(), peripheralId: "test-peripheral")
        XCTAssertTrue(emptyResponses.isEmpty, "Empty packets should be handled gracefully")

        // Too short packet
        let shortResponses = parser.processPacket(Data([0x01, 0x02]), peripheralId: "test-peripheral")
        XCTAssertTrue(shortResponses.isEmpty, "Too short packets should be handled gracefully")

        // Invalid packet type (type 3 - error packets)
        let errorTypeResponses = parser.processPacket(Data([0xC0, 0x01, 0x02, 0x03]), peripheralId: "test-peripheral")
        XCTAssertTrue(errorTypeResponses.isEmpty, "Error packet types should be handled gracefully")

        print("Invalid packet types test passed")
    }
}
