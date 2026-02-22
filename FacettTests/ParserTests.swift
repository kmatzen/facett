import XCTest
@testable import Facett

// MARK: - Packet Reconstructor Tests

final class PacketReconstructorTests: XCTestCase {
    var reconstructor: BLEPacketReconstructor!

    override func setUp() {
        super.setUp()
        reconstructor = BLEPacketReconstructor()
    }

    override func tearDown() {
        reconstructor = nil
        super.tearDown()
    }

    // MARK: - Empty / Invalid Input

    func testEmptyData() {
        let result = reconstructor.processPacket(Data(), peripheralId: "p1")
        XCTAssertNil(result)
    }

    // MARK: - General (5-bit) Single-Packet Responses

    func testGeneralSinglePacketStatusResponse() {
        // Simulated status query response (query ID 0x13):
        // Message: [0x13] [0x00 (success)] [TLV: type=70, len=1, val=85 (battery 85%)]
        // Message length = 5 bytes → header = 0b000_00101 = 0x05
        let packet = Data([0x05, 0x13, 0x00, 70, 0x01, 0x55])
        let result = reconstructor.processPacket(packet, peripheralId: "p1")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.queryID, 0x13)
        // TLV data should be [70, 0x01, 0x55]
        XCTAssertEqual(result?.data, Data([70, 0x01, 0x55]))
    }

    func testGeneralSinglePacketSettingsResponse() {
        // Settings query response (query ID 0x12):
        // Message: [0x12] [0x00] [TLV: type=2, len=1, val=1 (4K resolution)]
        // Message length = 5 → header = 0x05
        let packet = Data([0x05, 0x12, 0x00, 2, 0x01, 0x01])
        let result = reconstructor.processPacket(packet, peripheralId: "p1")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.queryID, 0x12)
        XCTAssertEqual(result?.data, Data([2, 0x01, 0x01]))
    }

    func testGeneralMultipleTLVEntries() {
        // Status response with two TLV entries:
        // [type=70, len=1, val=50] [type=2, len=1, val=3]
        // Message: [0x13] [0x00] [70, 1, 50, 2, 1, 3] → length = 8
        let packet = Data([0x08, 0x13, 0x00, 70, 0x01, 50, 2, 0x01, 3])
        let result = reconstructor.processPacket(packet, peripheralId: "p1")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.queryID, 0x13)
        XCTAssertEqual(result?.data.count, 6)
    }

    // MARK: - Extended 13-bit Multi-Packet Responses

    func testExtended13BitSinglePacket() {
        // Extended 13-bit header: bits 7-5 = 001, bits 4-0 + byte1 = 13-bit length
        // Message length = 5 → upper 5 bits = 0, lower 8 bits = 5
        // Header byte 0 = 0b001_00000 = 0x20, byte 1 = 0x05
        // Message: [0x13] [0x00] [70, 1, 85]
        let packet = Data([0x20, 0x05, 0x13, 0x00, 70, 0x01, 0x55])
        let result = reconstructor.processPacket(packet, peripheralId: "p1")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.queryID, 0x13)
        XCTAssertEqual(result?.data, Data([70, 0x01, 0x55]))
    }

    func testExtended13BitMultiPacket() {
        // First packet: Extended 13-bit, message length = 25 (more than fits in one 20-byte BLE packet)
        // Header: 0b001_00000 = 0x20, length_low = 25
        // Message starts: [0x13] [0x00] [TLV data...]
        // First packet carries header(2) + queryID(1) + status(1) + 16 bytes TLV = 20 bytes total
        var firstPacket = Data([0x20, 25, 0x13, 0x00])
        let tlvChunk1 = Data(repeating: 0xAA, count: 16) // 16 bytes of TLV in first packet
        firstPacket.append(tlvChunk1)

        let result1 = reconstructor.processPacket(firstPacket, peripheralId: "p1")
        XCTAssertNil(result1, "First packet should not complete the message (16 of 23 TLV bytes)")

        // Continuation packet: header 0x80 (bit7=1, counter=0), then 7 remaining TLV bytes
        var contPacket = Data([0x80])
        let tlvChunk2 = Data(repeating: 0xBB, count: 7)
        contPacket.append(tlvChunk2)

        let result2 = reconstructor.processPacket(contPacket, peripheralId: "p1")
        XCTAssertNotNil(result2, "Second packet should complete the message")
        XCTAssertEqual(result2?.queryID, 0x13)
        XCTAssertEqual(result2?.data.count, 23) // 25 - 2 (queryID + status)
    }

    func testExtended13BitThreePackets() {
        // Message length = 40 → needs 3 packets
        // Packet 1 (Extended 13-bit): header(2) + queryID + status + 16 TLV bytes = 20 bytes
        var pkt1 = Data([0x20, 40, 0x12, 0x00])
        pkt1.append(Data(repeating: 0x01, count: 16))

        // Packet 2 (continuation, counter=0): header(1) + 19 TLV bytes = 20 bytes
        var pkt2 = Data([0x80])
        pkt2.append(Data(repeating: 0x02, count: 19))

        // Packet 3 (continuation, counter=1): header(1) + 3 remaining TLV bytes
        var pkt3 = Data([0x81])
        pkt3.append(Data(repeating: 0x03, count: 3))

        XCTAssertNil(reconstructor.processPacket(pkt1, peripheralId: "p1"))
        XCTAssertNil(reconstructor.processPacket(pkt2, peripheralId: "p1"))

        let result = reconstructor.processPacket(pkt3, peripheralId: "p1")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.queryID, 0x12)
        XCTAssertEqual(result?.data.count, 38) // 40 - 2
    }

    // MARK: - Extended 16-bit (receive-only)

    func testExtended16Bit() {
        // Header: bits 7-5 = 010 → 0b010_00000 = 0x40, then 2-byte length
        // Message length = 5
        let packet = Data([0x40, 0x00, 0x05, 0x13, 0x00, 70, 0x01, 0x55])
        let result = reconstructor.processPacket(packet, peripheralId: "p1")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.queryID, 0x13)
        XCTAssertEqual(result?.data, Data([70, 0x01, 0x55]))
    }

    // MARK: - Continuation Packet Edge Cases

    func testContinuationWithNoBuffer() {
        // Continuation packet with no prior start packet should be dropped
        let contPacket = Data([0x80, 0x01, 0x02, 0x03])
        let result = reconstructor.processPacket(contPacket, peripheralId: "p1")
        XCTAssertNil(result)
    }

    func testContinuationCounterWraparound() {
        // Start a multi-packet message, then send continuations with counters 0-15
        var pkt1 = Data([0x20, 200, 0x13, 0x00]) // Extended 13-bit, length = 200
        pkt1.append(Data(repeating: 0xAA, count: 16))

        XCTAssertNil(reconstructor.processPacket(pkt1, peripheralId: "p1"))

        // Send continuations until we reach 198 TLV bytes (200 - 2)
        var accumulated = 16
        var counter: UInt8 = 0
        while accumulated < 198 {
            let remaining = 198 - accumulated
            let chunkSize = min(19, remaining)
            var pkt = Data([0x80 | (counter & 0x0F)])
            pkt.append(Data(repeating: UInt8(counter), count: chunkSize))
            let result = reconstructor.processPacket(pkt, peripheralId: "p1")

            accumulated += chunkSize
            if accumulated >= 198 {
                XCTAssertNotNil(result, "Final continuation should complete the message")
                XCTAssertEqual(result?.data.count, 198)
            } else {
                XCTAssertNil(result)
            }
            counter = (counter + 1) & 0x0F
        }
    }

    // MARK: - Multiple Peripherals

    func testInterleavedPeripherals() {
        // Start multi-packet messages for two different peripherals
        var pkt1a = Data([0x20, 25, 0x13, 0x00])
        pkt1a.append(Data(repeating: 0xAA, count: 16))

        var pkt1b = Data([0x20, 25, 0x12, 0x00])
        pkt1b.append(Data(repeating: 0xBB, count: 16))

        XCTAssertNil(reconstructor.processPacket(pkt1a, peripheralId: "p1"))
        XCTAssertNil(reconstructor.processPacket(pkt1b, peripheralId: "p2"))

        // Continuation for p2
        var cont2 = Data([0x80])
        cont2.append(Data(repeating: 0xCC, count: 7))
        let result2 = reconstructor.processPacket(cont2, peripheralId: "p2")
        XCTAssertNotNil(result2)
        XCTAssertEqual(result2?.queryID, 0x12)

        // Continuation for p1
        var cont1 = Data([0x80])
        cont1.append(Data(repeating: 0xDD, count: 7))
        let result1 = reconstructor.processPacket(cont1, peripheralId: "p1")
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1?.queryID, 0x13)
    }

    // MARK: - Buffer Management

    func testClearBuffers() {
        var pkt = Data([0x20, 25, 0x13, 0x00])
        pkt.append(Data(repeating: 0xAA, count: 16))
        XCTAssertNil(reconstructor.processPacket(pkt, peripheralId: "p1"))

        let state1 = reconstructor.getBufferState()
        XCTAssertFalse(state1.buffers.isEmpty)

        reconstructor.clearBuffers()
        let state2 = reconstructor.getBufferState()
        XCTAssertTrue(state2.buffers.isEmpty)
    }

    func testClearBuffersForPeripheral() {
        var pkt1 = Data([0x20, 25, 0x13, 0x00])
        pkt1.append(Data(repeating: 0xAA, count: 16))
        var pkt2 = Data([0x20, 25, 0x12, 0x00])
        pkt2.append(Data(repeating: 0xBB, count: 16))

        XCTAssertNil(reconstructor.processPacket(pkt1, peripheralId: "p1"))
        XCTAssertNil(reconstructor.processPacket(pkt2, peripheralId: "p2"))

        reconstructor.clearBuffers(for: "p1")
        let state = reconstructor.getBufferState()
        XCTAssertTrue(state.buffers.keys.allSatisfy { !$0.hasPrefix("p1") })
        XCTAssertFalse(state.buffers.isEmpty) // p2 still has a buffer
    }

    func testTimeout() {
        var pkt = Data([0x20, 25, 0x13, 0x00])
        pkt.append(Data(repeating: 0xAA, count: 16))
        XCTAssertNil(reconstructor.processPacket(pkt, peripheralId: "p1"))

        // With a 0-second timeout, the buffer should be returned immediately
        let results = reconstructor.checkTimeouts(timeoutInterval: 0)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].queryID, 0x13)

        // Buffer should be cleared after timeout
        let state = reconstructor.getBufferState()
        XCTAssertTrue(state.buffers.isEmpty)
    }
}

// MARK: - TLV Parser Tests

final class TLVParserTests: XCTestCase {
    var tlvParser: BLETLVParser!

    override func setUp() {
        super.setUp()
        tlvParser = BLETLVParser()
    }

    override func tearDown() {
        tlvParser = nil
        super.tearDown()
    }

    func testSingleTLVEntry() {
        // Type=70 (battery %), Length=1, Value=85
        let data = Data([70, 0x01, 85])
        let entries = tlvParser.parseTLVData(data)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].type, 70)
        XCTAssertEqual(entries[0].length, 1)
        XCTAssertEqual(entries[0].value, 85)
    }

    func testMultipleTLVEntries() {
        // [type=1, len=1, val=1] [type=2, len=1, val=3] [type=70, len=1, val=50]
        let data = Data([1, 1, 1, 2, 1, 3, 70, 1, 50])
        let entries = tlvParser.parseTLVData(data)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].type, 1)
        XCTAssertEqual(entries[0].value, 1)
        XCTAssertEqual(entries[1].type, 2)
        XCTAssertEqual(entries[1].value, 3)
        XCTAssertEqual(entries[2].type, 70)
        XCTAssertEqual(entries[2].value, 50)
    }

    func testMultiByteValue() {
        // Type=54 (SD card remaining KB), Length=4, Value = 0x003D0900 = 4,000,000
        let data = Data([54, 4, 0x00, 0x3D, 0x09, 0x00])
        let entries = tlvParser.parseTLVData(data)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].type, 54)
        XCTAssertEqual(entries[0].length, 4)
        XCTAssertEqual(entries[0].value, 4_000_000)
    }

    func testBigEndianTwoByteValue() {
        // Type=13, Length=2, Value = 0x01F4 = 500 (video duration in seconds)
        let data = Data([13, 2, 0x01, 0xF4])
        let entries = tlvParser.parseTLVData(data)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].value, 500)
    }

    func testZeroLengthValue() {
        // Type=8, Length=0 → no value bytes
        let data = Data([8, 0])
        let entries = tlvParser.parseTLVData(data)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].type, 8)
        XCTAssertEqual(entries[0].length, 0)
        XCTAssertEqual(entries[0].value, 0)
    }

    func testTruncatedEntry() {
        // Type=70, Length=4, but only 2 value bytes available → should stop parsing
        let data = Data([70, 4, 0x01, 0x02])
        let entries = tlvParser.parseTLVData(data)
        XCTAssertEqual(entries.count, 0)
    }

    func testEmptyData() {
        let entries = tlvParser.parseTLVData(Data())
        XCTAssertTrue(entries.isEmpty)
    }

    func testStringValue() {
        // Simulate an AP SSID (type 30): "GP12345678"
        let ssidBytes: [UInt8] = Array("GP12345678".utf8)
        var data = Data([30, UInt8(ssidBytes.count)])
        data.append(Data(ssidBytes))

        let entries = tlvParser.parseTLVData(data)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].stringValue, "GP12345678")
    }
}

// MARK: - Response Mapper Tests

final class ResponseMapperTests: XCTestCase {
    var mapper: BLEResponseMapper!
    var tlvParser: BLETLVParser!

    override func setUp() {
        super.setUp()
        mapper = BLEResponseMapper()
        tlvParser = BLETLVParser()
    }

    override func tearDown() {
        mapper = nil
        tlvParser = nil
        super.tearDown()
    }

    // MARK: - Status Responses (Query ID 0x13 = 19)

    func testBatteryPresentStatus() {
        let entries = tlvParser.parseTLVData(Data([1, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        XCTAssertEqual(responses.count, 1)
        if case .batteryPresent(let present) = responses[0] {
            XCTAssertTrue(present)
        } else {
            XCTFail("Expected batteryPresent response")
        }
    }

    func testBatteryLevelStatus() {
        // Status ID 2 = battery level (bars), value 3
        let entries = tlvParser.parseTLVData(Data([2, 1, 3]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        XCTAssertEqual(responses.count, 1)
        if case .batteryLevel(let level) = responses[0] {
            XCTAssertEqual(level, 3)
        } else {
            XCTFail("Expected batteryLevel response")
        }
    }

    func testBatteryPercentageStatus() {
        // Status ID 70 = battery percentage, value 85
        let entries = tlvParser.parseTLVData(Data([70, 1, 85]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        XCTAssertEqual(responses.count, 1)
        if case .batteryPercentage(let pct) = responses[0] {
            XCTAssertEqual(pct, 85)
        } else {
            XCTFail("Expected batteryPercentage response")
        }
    }

    func testOverheatingStatus() {
        let entries = tlvParser.parseTLVData(Data([6, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        if case .overheating(let hot) = responses[0] {
            XCTAssertTrue(hot)
        } else {
            XCTFail("Expected overheating response")
        }
    }

    func testEncodingStatus() {
        let entries = tlvParser.parseTLVData(Data([10, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        if case .encoding(let enc) = responses[0] {
            XCTAssertTrue(enc)
        } else {
            XCTFail("Expected encoding response")
        }
    }

    func testIsReadyStatus() {
        // Status ID 82 = system ready
        let entries = tlvParser.parseTLVData(Data([82, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        if case .isReady(let ready) = responses[0] {
            XCTAssertTrue(ready)
        } else {
            XCTFail("Expected isReady response")
        }
    }

    func testGPSLockStatus() {
        // Status ID 68 = GPS lock
        let entries = tlvParser.parseTLVData(Data([68, 1, 0]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        if case .gpsLock(let lock) = responses[0] {
            XCTAssertFalse(lock)
        } else {
            XCTFail("Expected gpsLock response")
        }
    }

    func testCameraControlIdStatus() {
        // Status ID 114 = camera control ID
        let entries = tlvParser.parseTLVData(Data([114, 1, 2]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        if case .cameraControlId(let id) = responses[0] {
            XCTAssertEqual(id, 2)
        } else {
            XCTFail("Expected cameraControlId response")
        }
    }

    func testSDCardRemainingStatus() {
        // Status ID 54 = SD card remaining KB, 4 bytes → 4,000,000 KB
        let entries = tlvParser.parseTLVData(Data([54, 4, 0x00, 0x3D, 0x09, 0x00]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        if case .sdCardRemaining(let kb) = responses[0] {
            XCTAssertEqual(kb, 4_000_000)
        } else {
            XCTFail("Expected sdCardRemaining response")
        }
    }

    func testMultipleStatusResponses() {
        // Two TLV entries: battery present (1) + battery percentage (85%)
        let data = Data([1, 1, 1, 70, 1, 85])
        let entries = tlvParser.parseTLVData(data)
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 19)
        XCTAssertEqual(responses.count, 2)
    }

    // MARK: - Settings Responses (Query ID 0x12 = 18)

    func testVideoResolutionSetting() {
        // Setting ID 2 = video resolution, value 1 (4K)
        let entries = tlvParser.parseTLVData(Data([2, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 18)
        if case .videoResolution(let res) = responses[0] {
            XCTAssertEqual(res, 1)
        } else {
            XCTFail("Expected videoResolution response")
        }
    }

    func testFPSSetting() {
        // Setting ID 3 = FPS, value 5 (60fps)
        let entries = tlvParser.parseTLVData(Data([3, 1, 5]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 18)
        if case .framesPerSecond(let fps) = responses[0] {
            XCTAssertEqual(fps, 5)
        } else {
            XCTFail("Expected framesPerSecond response")
        }
    }

    func testGPSSetting() {
        // Setting ID 83 = GPS, value 1 (enabled)
        let entries = tlvParser.parseTLVData(Data([83, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 18)
        if case .gps(let enabled) = responses[0] {
            XCTAssertTrue(enabled)
        } else {
            XCTFail("Expected gps response")
        }
    }

    func testAntiFlickerSetting() {
        // Setting ID 134 = anti-flicker
        let entries = tlvParser.parseTLVData(Data([134, 1, 0]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 18)
        if case .antiFlicker(let val) = responses[0] {
            XCTAssertEqual(val, 0)
        } else {
            XCTFail("Expected antiFlicker response")
        }
    }

    func testModeSetting() {
        // Setting ID 144 = mode (undocumented), value 12 (video)
        let entries = tlvParser.parseTLVData(Data([144, 1, 12]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 18)
        if case .mode(let mode) = responses[0] {
            XCTAssertEqual(mode, 12)
        } else {
            XCTFail("Expected mode response")
        }
    }

    func testMaxLensSetting() {
        // Setting ID 162 = max lens, value 1 (enabled)
        let entries = tlvParser.parseTLVData(Data([162, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 18)
        if case .maxLens(let enabled) = responses[0] {
            XCTAssertTrue(enabled)
        } else {
            XCTFail("Expected maxLens response")
        }
    }

    func testUnknownQueryID() {
        let entries = tlvParser.parseTLVData(Data([1, 1, 1]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 99)
        XCTAssertTrue(responses.isEmpty)
    }

    // MARK: - Query ID 20 (Settings variant)

    func testQueryID20RoutesToSettings() {
        // Query ID 20 should also be treated as settings
        let entries = tlvParser.parseTLVData(Data([2, 1, 3]))
        let responses = mapper.mapToResponseTypes(entries: entries, queryID: 20)
        if case .videoResolution(let res) = responses[0] {
            XCTAssertEqual(res, 3)
        } else {
            XCTFail("Expected videoResolution via query ID 20")
        }
    }
}

// MARK: - Full Pipeline Tests (GoProBLEParser)

final class BLEParserPipelineTests: XCTestCase {
    var parser: GoProBLEParser!

    override func setUp() {
        super.setUp()
        parser = GoProBLEParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testEmptyData() {
        let responses = parser.processPacket(Data(), peripheralId: "p1")
        XCTAssertTrue(responses.isEmpty)
    }

    func testSinglePacketBatteryStatus() {
        // General header, status query response with battery percentage = 85%
        // Header: length = 5 → 0x05
        // Message: [0x13] [0x00] [70, 1, 85]
        let packet = Data([0x05, 0x13, 0x00, 70, 0x01, 85])
        let responses: [ResponseType] = parser.processPacket(packet, peripheralId: "p1")

        XCTAssertEqual(responses.count, 1)
        if case .batteryPercentage(let pct) = responses[0] {
            XCTAssertEqual(pct, 85)
        } else {
            XCTFail("Expected batteryPercentage")
        }
    }

    func testSinglePacketMultipleStatuses() {
        // Status response with: battery present (1=yes), battery level (2=3 bars), overheating (6=no)
        // TLV: [1,1,1] [2,1,3] [6,1,0] = 9 bytes
        // Message: [0x13] [0x00] + 9 = 11 bytes
        let packet = Data([11, 0x13, 0x00, 1, 1, 1, 2, 1, 3, 6, 1, 0])
        let responses = parser.processPacket(packet, peripheralId: "p1")

        XCTAssertEqual(responses.count, 3)
    }

    func testMultiPacketSettingsResponse() {
        // Simulate a settings response that spans two packets
        // Extended 13-bit header, message length = 23 (queryID + status + 21 TLV bytes)
        // TLV: 7 entries of [settingID, 1, value] = 21 bytes
        let settingsEntries: [(UInt8, UInt8)] = [
            (2, 1),   // video resolution = 1 (4K)
            (3, 5),   // FPS = 5 (60fps)
            (83, 1),  // GPS = enabled
            (134, 0), // anti-flicker = 50Hz
            (135, 1), // hypersmooth = on
            (162, 0), // max lens = off
            (173, 0) // video perf mode = max
        ]

        var tlvData = Data()
        for (id, val) in settingsEntries {
            tlvData.append(contentsOf: [id, 0x01, val])
        }

        let messageLength = 2 + tlvData.count // queryID + status + TLV

        // First packet (Extended 13-bit): [header, length_low, queryID, status, TLV chunk 1]
        var pkt1 = Data([0x20, UInt8(messageLength), 0x12, 0x00])
        let chunk1Size = min(tlvData.count, 16) // 20 - 4 header bytes
        pkt1.append(tlvData.subdata(in: 0..<chunk1Size))

        let responses1 = parser.processPacket(pkt1, peripheralId: "p1")
        XCTAssertTrue(responses1.isEmpty, "First packet should not produce responses yet")

        // Continuation packet with remaining TLV data
        var pkt2 = Data([0x80])
        pkt2.append(tlvData.subdata(in: chunk1Size..<tlvData.count))

        let responses2 = parser.processPacket(pkt2, peripheralId: "p1")
        XCTAssertEqual(responses2.count, 7, "Should parse all 7 settings")
    }

    func testBufferCleanup() {
        parser.clearBuffers()
        let state = parser.getBufferState()
        XCTAssertTrue(state.buffers.isEmpty)
    }
}

// MARK: - Command Byte Verification Tests

final class GoProCommandTests: XCTestCase {

    func testStatusQueryFormat() {
        let cmd = GoProCommands.Status.status1
        XCTAssertEqual(cmd[0], 19, "Header should indicate 19-byte message")
        XCTAssertEqual(cmd[1], 0x13, "Query ID should be 0x13 (Get Status Values)")
        XCTAssertEqual(cmd.count, 20, "Should fit in one BLE packet (20 bytes)")
    }

    func testSettingsQueryFormat() {
        let cmd = GoProCommands.Settings.settings1
        XCTAssertEqual(cmd[0], 19, "Header should indicate 19-byte message")
        XCTAssertEqual(cmd[1], 0x12, "Query ID should be 0x12 (Get Setting Values)")
        XCTAssertEqual(cmd.count, 20)
    }

    func testRecordingStartCommand() {
        // Set Shutter: Command ID 0x01, param length 1, param value 1
        let cmd = GoProCommands.Recording.start
        XCTAssertEqual(cmd, [0x03, 0x01, 0x01, 0x01])
        XCTAssertEqual(cmd[0] & 0x1F, 3, "Message length should be 3")
        XCTAssertEqual(cmd[1], 0x01, "Command ID should be Set Shutter (0x01)")
    }

    func testRecordingStopCommand() {
        let cmd = GoProCommands.Recording.stop
        XCTAssertEqual(cmd, [0x03, 0x01, 0x01, 0x00])
        XCTAssertEqual(cmd[3], 0x00, "Shutter parameter should be 0 (off)")
    }

    func testSleepCommand() {
        // Sleep: Command ID 0x05, no parameters
        let cmd = GoProCommands.Control.sleep
        XCTAssertEqual(cmd, [0x01, 0x05])
        XCTAssertEqual(cmd[0] & 0x1F, 1, "Message length should be 1")
        XCTAssertEqual(cmd[1], 0x05, "Command ID should be Sleep (0x05)")
    }

    func testClaimControlCommand() {
        // Protobuf: Feature 0xF1, Action 0x69, payload [0x08, 0x02]
        let cmd = GoProCommands.Control.claimControl
        XCTAssertEqual(cmd[0] & 0x1F, 4, "Message length should be 4")
        XCTAssertEqual(cmd[1], 0xF1, "Feature ID should be 0xF1")
        XCTAssertEqual(cmd[2], 0x69, "Action ID should be 0x69 (Set Camera Control)")
        XCTAssertEqual(cmd[4], 0x02, "Control value should be 2 (EXTERNAL)")
    }

    func testReleaseControlCommand() {
        let cmd = GoProCommands.Control.releaseControl
        XCTAssertEqual(cmd[1], 0xF1)
        XCTAssertEqual(cmd[2], 0x69)
        XCTAssertEqual(cmd[4], 0x00, "Control value should be 0 (IDLE)")
    }

    func testAPEnableCommand() {
        // Set AP Control: Command ID 0x17, param 1 = enable
        let cmd = GoProCommands.AccessPoint.enable
        XCTAssertEqual(cmd, [0x03, 0x17, 0x01, 0x01])
    }

    func testAPDisableCommand() {
        let cmd = GoProCommands.AccessPoint.disable
        XCTAssertEqual(cmd, [0x03, 0x17, 0x01, 0x00])
    }

    func testTurboTransferCommand() {
        let cmd = GoProCommands.TurboTransfer.enable
        XCTAssertEqual(cmd[1], 0xF1, "Feature ID should be 0xF1")
        XCTAssertEqual(cmd[2], 0x6B, "Action ID should be 0x6B (Set Turbo Transfer)")
    }

    func testModeVideoCommand() {
        // Set Setting 144 (0x90) to 12 (video)
        let cmd = GoProCommands.Mode.video
        XCTAssertEqual(cmd[1], 0x90, "Setting ID should be 0x90 (mode)")
        XCTAssertEqual(cmd[3], 12, "Mode value should be 12 (video)")
    }

    func testModePhotoCommand() {
        let cmd = GoProCommands.Mode.photo
        XCTAssertEqual(cmd[1], 0x90)
        XCTAssertEqual(cmd[3], 17, "Mode value should be 17 (photo)")
    }

    func testModeMultishotCommand() {
        let cmd = GoProCommands.Mode.multishot
        XCTAssertEqual(cmd[1], 0x90)
        XCTAssertEqual(cmd[3], 19, "Mode value should be 19 (multishot)")
    }

    func testCommandsAreUnique() {
        // Verify no two distinct commands share the same byte arrays
        let commands: [(String, [UInt8])] = [
            ("Control.claimControl", GoProCommands.Control.claimControl),
            ("Control.releaseControl", GoProCommands.Control.releaseControl),
            ("Control.sleep", GoProCommands.Control.sleep),
            ("Control.reboot", GoProCommands.Control.reboot),
            ("AccessPoint.enable", GoProCommands.AccessPoint.enable),
            ("AccessPoint.disable", GoProCommands.AccessPoint.disable),
            ("TurboTransfer.enable", GoProCommands.TurboTransfer.enable),
            ("TurboTransfer.disable", GoProCommands.TurboTransfer.disable),
            ("Recording.start", GoProCommands.Recording.start),
            ("Recording.stop", GoProCommands.Recording.stop),
            ("Mode.video", GoProCommands.Mode.video),
            ("Mode.photo", GoProCommands.Mode.photo),
            ("Mode.multishot", GoProCommands.Mode.multishot)
        ]

        for i in 0..<commands.count {
            for j in (i + 1)..<commands.count {
                let (name1, bytes1) = commands[i]
                let (name2, bytes2) = commands[j]
                XCTAssertNotEqual(bytes1, bytes2, "\(name1) and \(name2) must not share the same byte array")
            }
        }
    }

    func testHeaderLengthConsistency() {
        // For each command, verify the header byte's 5-bit length matches actual payload
        let commands: [String: [UInt8]] = [
            "sleep": GoProCommands.Control.sleep,
            "reboot": GoProCommands.Control.reboot,
            "claimControl": GoProCommands.Control.claimControl,
            "releaseControl": GoProCommands.Control.releaseControl,
            "apEnable": GoProCommands.AccessPoint.enable,
            "apDisable": GoProCommands.AccessPoint.disable,
            "turboEnable": GoProCommands.TurboTransfer.enable,
            "turboDisable": GoProCommands.TurboTransfer.disable,
            "recStart": GoProCommands.Recording.start,
            "recStop": GoProCommands.Recording.stop,
            "modeVideo": GoProCommands.Mode.video,
            "modePhoto": GoProCommands.Mode.photo,
            "modeMultishot": GoProCommands.Mode.multishot,
            "keepAlive": GoProCommands.KeepAlive.ping
        ]

        for (name, cmd) in commands {
            let declaredLength = Int(cmd[0] & 0x1F)
            let actualPayload = cmd.count - 1
            XCTAssertEqual(declaredLength, actualPayload,
                           "\(name): header says \(declaredLength) bytes but payload is \(actualPayload)")
        }
    }
}
