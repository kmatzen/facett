import XCTest
@testable import Facett

final class ParserTests: XCTestCase {
    var parser: GoProBLEParser!

    override func setUp() {
        super.setUp()
        parser = GoProBLEParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testParserInitialization() {
        XCTAssertNotNil(parser, "Parser should be initialized")
    }

    func testEmptyData() {
        let emptyData = Data()
        let responses = parser.processPacket(emptyData, peripheralId: "test-peripheral")

        XCTAssertTrue(responses.isEmpty, "Empty data should return no responses")
    }

    func testInvalidPacket() {
        let invalidData = Data([0xFF, 0xFF, 0xFF]) // Invalid packet
        let responses = parser.processPacket(invalidData, peripheralId: "test-peripheral")

        XCTAssertTrue(responses.isEmpty, "Invalid packet should return no responses")
    }

    func testShortPacket() {
        let shortData = Data([0x01, 0x02]) // Too short to be valid
        let responses = parser.processPacket(shortData, peripheralId: "test-peripheral")

        XCTAssertTrue(responses.isEmpty, "Short packet should return no responses")
    }

    func testMultiplePeripherals() {
        // Test that different peripherals can be processed independently
        let data1 = Data([0x01, 0x02, 0x03, 0x04])
        let data2 = Data([0x05, 0x06, 0x07, 0x08])

        let responses1 = parser.processPacket(data1, peripheralId: "peripheral-1")
        let responses2 = parser.processPacket(data2, peripheralId: "peripheral-2")

        // Both should return empty responses since the data is invalid
        XCTAssertTrue(responses1.isEmpty, "Invalid data for peripheral 1 should return no responses")
        XCTAssertTrue(responses2.isEmpty, "Invalid data for peripheral 2 should return no responses")
    }

    func testBufferCleanup() {
        // Test that the parser can handle multiple calls without crashing
        let data = Data([0x01, 0x02, 0x03, 0x04])

        // Multiple calls should not crash
        _ = parser.processPacket(data, peripheralId: "test-peripheral")
        _ = parser.processPacket(data, peripheralId: "test-peripheral")
        _ = parser.processPacket(data, peripheralId: "test-peripheral")

        XCTAssertTrue(true, "Multiple calls should not crash")
    }
}
