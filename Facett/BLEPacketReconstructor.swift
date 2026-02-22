import Foundation

/// Handles BLE packet reconstruction for multi-packet messages per the GoPro Open API spec.
///
/// Packet header formats (from https://gopro.github.io/OpenGoPro/ble/protocol/data_protocol.html):
/// - Bit 7 = 0: Start packet; Bits 6-5 determine format:
///   - 00: General (5-bit length in bits 4-0)
///   - 01: Extended 13-bit (bits 4-0 + next byte = 13-bit length)
///   - 10: Extended 16-bit (next 2 bytes = 16-bit length, receive-only)
/// - Bit 7 = 1: Continuation packet; Bits 3-0 = 4-bit sequence counter
class BLEPacketReconstructor {

    // MARK: - Properties

    private var continuationBuffer: [String: Data] = [:]
    private var expectedMessageLength: [String: Int] = [:]
    private var lastPacketTime: [String: Date] = [:]

    // MARK: - Public Interface

    /// Process a BLE packet and return complete message data if available.
    /// Returns the TLV payload and query/command ID once the full message is assembled.
    func processPacket(_ data: Data, peripheralId: String) -> (data: Data, queryID: UInt8)? {
        guard !data.isEmpty else {
            ErrorHandler.bleError("Received empty data")
            return nil
        }

        let header = data[0]
        let isContinuation = (header & 0x80) != 0

        if isContinuation {
            return handleContinuationPacket(data: data, peripheralId: peripheralId)
        } else {
            return handleStartPacket(data: data, peripheralId: peripheralId)
        }
    }

    func clearBuffers() {
        continuationBuffer.removeAll()
        expectedMessageLength.removeAll()
        lastPacketTime.removeAll()
    }

    func clearBuffers(for peripheralId: String) {
        let keysToRemove = continuationBuffer.keys.filter { $0.hasPrefix(peripheralId) }
        for key in keysToRemove {
            continuationBuffer.removeValue(forKey: key)
            expectedMessageLength.removeValue(forKey: key)
            lastPacketTime.removeValue(forKey: key)
        }
    }

    func getBufferState() -> (buffers: [String: Data], expectedLengths: [String: Int]) {
        return (continuationBuffer, expectedMessageLength)
    }

    func checkTimeouts(timeoutInterval: TimeInterval = 5.0) -> [(data: Data, queryID: UInt8)] {
        let now = Date()
        var results: [(data: Data, queryID: UInt8)] = []
        var keysToRemove: [String] = []

        for (bufferKey, lastTime) in lastPacketTime {
            if now.timeIntervalSince(lastTime) > timeoutInterval {
                ErrorHandler.warning("Timeout detected for buffer", context: ["buffer_key": bufferKey])

                if let buffer = continuationBuffer[bufferKey] {
                    let parts = bufferKey.split(separator: ":")
                    let queryID = parts.count >= 2 ? (UInt8(parts[1]) ?? 0) : 0
                    results.append((data: buffer, queryID: queryID))
                }

                keysToRemove.append(bufferKey)
            }
        }

        for key in keysToRemove {
            continuationBuffer.removeValue(forKey: key)
            expectedMessageLength.removeValue(forKey: key)
            lastPacketTime.removeValue(forKey: key)
        }

        return results
    }

    // MARK: - Private Methods

    /// Parse a start packet header and extract the message length and payload offset.
    /// Returns (messageLength, payloadStartIndex) or nil on error.
    private func parseStartHeader(_ data: Data) -> (messageLength: Int, payloadStart: Int)? {
        let header = data[0]
        let headerType = (header >> 5) & 0x03

        switch headerType {
        case 0b00:
            // General (5-bit): message length in bits 4-0
            let messageLength = Int(header & 0x1F)
            return (messageLength, 1)

        case 0b01:
            // Extended 13-bit: bits 4-0 of header + next byte
            guard data.count >= 2 else {
                ErrorHandler.bleError("Extended 13-bit packet too short", context: ["data_length": String(data.count)])
                return nil
            }
            let messageLength = (Int(header & 0x1F) << 8) | Int(data[1])
            return (messageLength, 2)

        case 0b10:
            // Extended 16-bit: next 2 bytes (receive-only format for messages >= 8192 bytes)
            guard data.count >= 3 else {
                ErrorHandler.bleError("Extended 16-bit packet too short", context: ["data_length": String(data.count)])
                return nil
            }
            let messageLength = (Int(data[1]) << 8) | Int(data[2])
            return (messageLength, 3)

        default:
            ErrorHandler.bleError("Reserved header type", context: ["header": String(format: "0x%02X", header)])
            return nil
        }
    }

    /// Handle a start packet (first or only packet of a message).
    /// Message payload format for queries: [QueryID] [Status] [TLV data...]
    private func handleStartPacket(data: Data, peripheralId: String) -> (data: Data, queryID: UInt8)? {
        guard let (messageLength, payloadStart) = parseStartHeader(data) else {
            return nil
        }

        let payloadInThisPacket = data.subdata(in: payloadStart..<data.count)

        guard payloadInThisPacket.count >= 2 else {
            ErrorHandler.bleError("Start packet payload too short for query response", context: [
                "payload_length": String(payloadInThisPacket.count)
            ])
            return nil
        }

        let queryID = payloadInThisPacket[0]
        // payloadInThisPacket[1] is the status byte (0 = success)
        let tlvData = payloadInThisPacket.count > 2 ? payloadInThisPacket.subdata(in: 2..<payloadInThisPacket.count) : Data()
        let expectedTLVLength = messageLength - 2

        let bufferKey = "\(peripheralId):\(queryID)"
        continuationBuffer[bufferKey] = tlvData
        expectedMessageLength[bufferKey] = expectedTLVLength
        lastPacketTime[bufferKey] = Date()

        if tlvData.count >= expectedTLVLength {
            continuationBuffer.removeValue(forKey: bufferKey)
            expectedMessageLength.removeValue(forKey: bufferKey)
            lastPacketTime.removeValue(forKey: bufferKey)
            return (data: tlvData, queryID: queryID)
        }

        return nil
    }

    /// Handle a continuation packet by appending its payload to an existing buffer.
    /// Continuation header: bit 7 = 1, bits 3-0 = sequence counter.
    /// Payload starts at byte 1.
    private func handleContinuationPacket(data: Data, peripheralId: String) -> (data: Data, queryID: UInt8)? {
        guard data.count >= 2 else {
            ErrorHandler.bleError("Continuation packet too short", context: ["data_length": String(data.count)])
            return nil
        }

        let payload = data.subdata(in: 1..<data.count)

        let bufferKeys = continuationBuffer.keys.filter { $0.hasPrefix(peripheralId) }

        if bufferKeys.isEmpty {
            ErrorHandler.bleError("No buffer found for continuation packet", context: ["peripheral_id": peripheralId])
            return nil
        }

        let bufferKey: String
        if bufferKeys.count == 1 {
            bufferKey = bufferKeys[0]
        } else if let mostRecent = bufferKeys.max(by: { (lastPacketTime[$0] ?? .distantPast) < (lastPacketTime[$1] ?? .distantPast) }) {
            bufferKey = mostRecent
        } else {
            ErrorHandler.bleError("No buffer key found for continuation packet", context: ["peripheral_id": peripheralId])
            return nil
        }

        guard var buffer = continuationBuffer[bufferKey],
              let expectedLength = expectedMessageLength[bufferKey] else {
            ErrorHandler.bleError("Buffer or expected length not found", context: ["buffer_key": bufferKey])
            return nil
        }

        buffer.append(payload)
        continuationBuffer[bufferKey] = buffer
        lastPacketTime[bufferKey] = Date()

        if buffer.count >= expectedLength {
            let parts = bufferKey.split(separator: ":")
            let queryID = parts.count >= 2 ? (UInt8(parts[1]) ?? 0) : 0

            continuationBuffer.removeValue(forKey: bufferKey)
            expectedMessageLength.removeValue(forKey: bufferKey)
            lastPacketTime.removeValue(forKey: bufferKey)

            return (data: buffer, queryID: queryID)
        }

        return nil
    }
}
