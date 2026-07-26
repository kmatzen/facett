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

    /// Reassembly state is touched from the CoreBluetooth delegate queue (via
    /// processPacket) and from the device-query timer's queue (via checkTimeouts).
    /// Those are different queues, so the dictionaries below were being mutated
    /// concurrently. They do not drive SwiftUI, so unlike the connection state in
    /// BLEManager they do not need to live on main -- a dedicated serial queue is
    /// the cheaper discipline and keeps packet handling off the main thread.
    private let stateQueue = DispatchQueue(label: "com.kmatzen.facett.ble.reassembly")

    private var continuationBuffer: [String: Data] = [:]
    private var expectedMessageLength: [String: Int] = [:]
    private var lastPacketTime: [String: Date] = [:]
    /// Query/command ID of the message currently accumulating for each buffer key.
    private var bufferQueryID: [String: UInt8] = [:]
    /// Next expected 4-bit continuation sequence counter for each buffer key.
    private var nextSequence: [String: UInt8] = [:]

    /// Accumulation is a per-characteristic context: each notify characteristic
    /// carries one message at a time, but different characteristics (query
    /// responses on 0x0077, settings responses on 0x0075) stream independently.
    /// Keying by (peripheral, characteristic) makes continuation routing
    /// deterministic. Keying by query ID -- as this previously did -- invented
    /// concurrency the protocol does not have while ignoring the concurrency it
    /// does, so a continuation could be appended to an unrelated message's buffer.
    private func bufferKey(peripheralId: String, channelId: String) -> String {
        return "\(peripheralId)|\(channelId)"
    }

    // MARK: - Public Interface

    /// Process a BLE packet and return complete message data if available.
    /// Returns the TLV payload and query/command ID once the full message is assembled.
    /// - Parameters:
    ///   - channelId: the notify characteristic this packet arrived on. Packets
    ///     from different characteristics must not share an accumulation buffer.
    func processPacket(_ data: Data, peripheralId: String, channelId: String) -> (data: Data, queryID: UInt8)? {
        return stateQueue.sync { processPacketLocked(data, peripheralId: peripheralId, channelId: channelId) }
    }

    private func processPacketLocked(_ data: Data, peripheralId: String, channelId: String) -> (data: Data, queryID: UInt8)? {
        guard !data.isEmpty else {
            ErrorHandler.bleError("Received empty data")
            return nil
        }

        let header = data[0]
        let isContinuation = (header & 0x80) != 0
        let key = bufferKey(peripheralId: peripheralId, channelId: channelId)

        if isContinuation {
            return handleContinuationPacket(data: data, bufferKey: key)
        } else {
            return handleStartPacket(data: data, bufferKey: key)
        }
    }

    /// Discard the message accumulating on this buffer key, if any.
    private func discardBuffer(_ key: String) {
        continuationBuffer.removeValue(forKey: key)
        expectedMessageLength.removeValue(forKey: key)
        lastPacketTime.removeValue(forKey: key)
        bufferQueryID.removeValue(forKey: key)
        nextSequence.removeValue(forKey: key)
    }

    func clearBuffers() {
        stateQueue.sync { clearBuffersLocked() }
    }

    private func clearBuffersLocked() {
        continuationBuffer.removeAll()
        expectedMessageLength.removeAll()
        lastPacketTime.removeAll()
        bufferQueryID.removeAll()
        nextSequence.removeAll()
    }

    func clearBuffers(for peripheralId: String) {
        stateQueue.sync { clearBuffersLocked(for: peripheralId) }
    }

    private func clearBuffersLocked(for peripheralId: String) {
        // Match on the full peripheral component, not a bare prefix: a bare
        // prefix would let peripheral "p1" clear peripheral "p10"'s buffers.
        let keysToRemove = continuationBuffer.keys.filter {
            $0.hasPrefix("\(peripheralId)|")
        }
        for key in keysToRemove {
            discardBuffer(key)
        }
    }

    func getBufferState() -> (buffers: [String: Data], expectedLengths: [String: Int]) {
        return stateQueue.sync { (continuationBuffer, expectedMessageLength) }
    }

    /// Discard buffers that have gone quiet, and report how many were dropped.
    ///
    /// A timed-out buffer is known to be short. It used to be force-completed and
    /// parsed as TLV, which decoded whatever prefix happened to parse and applied
    /// it as real settings/status. Worse, the peripheral half of the buffer key
    /// was discarded on the way out, so the caller applied one camera's truncated
    /// data to every connected camera. Truncated data is now dropped outright.
    @discardableResult
    func checkTimeouts(timeoutInterval: TimeInterval = 5.0) -> Int {
        return stateQueue.sync { checkTimeoutsLocked(timeoutInterval: timeoutInterval) }
    }

    private func checkTimeoutsLocked(timeoutInterval: TimeInterval) -> Int {
        let now = Date()
        var keysToRemove: [String] = []

        for (bufferKey, lastTime) in lastPacketTime where now.timeIntervalSince(lastTime) > timeoutInterval {
            ErrorHandler.warning("Discarding timed-out partial message", context: [
                "buffer_key": bufferKey,
                "bytes_accumulated": String(continuationBuffer[bufferKey]?.count ?? 0),
                "bytes_expected": String(expectedMessageLength[bufferKey] ?? 0)
            ])
            keysToRemove.append(bufferKey)
        }

        for key in keysToRemove {
            discardBuffer(key)
        }

        return keysToRemove.count
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
    private func handleStartPacket(data: Data, bufferKey: String) -> (data: Data, queryID: UInt8)? {
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

        guard expectedTLVLength >= 0 else {
            ErrorHandler.bleError("Start packet declares a length shorter than its own header", context: [
                "message_length": String(messageLength)
            ])
            return nil
        }

        // A start packet on a characteristic that already has a message in
        // progress means the earlier message will never complete. Drop it
        // loudly rather than silently overwriting it.
        if let stale = continuationBuffer[bufferKey] {
            ErrorHandler.warning("Discarding incomplete message superseded by a new start packet", context: [
                "buffer_key": bufferKey,
                "bytes_accumulated": String(stale.count),
                "bytes_expected": String(expectedMessageLength[bufferKey] ?? 0)
            ])
            discardBuffer(bufferKey)
        }

        if tlvData.count >= expectedTLVLength {
            return (data: tlvData, queryID: queryID)
        }

        continuationBuffer[bufferKey] = tlvData
        expectedMessageLength[bufferKey] = expectedTLVLength
        lastPacketTime[bufferKey] = Date()
        bufferQueryID[bufferKey] = queryID
        nextSequence[bufferKey] = 0  // the first continuation packet carries counter 0

        return nil
    }

    /// Handle a continuation packet by appending its payload to an existing buffer.
    /// Continuation header: bit 7 = 1, bits 3-0 = sequence counter.
    /// Payload starts at byte 1.
    private func handleContinuationPacket(data: Data, bufferKey: String) -> (data: Data, queryID: UInt8)? {
        guard data.count >= 2 else {
            ErrorHandler.bleError("Continuation packet too short", context: ["data_length": String(data.count)])
            return nil
        }

        let payload = data.subdata(in: 1..<data.count)

        guard var buffer = continuationBuffer[bufferKey],
              let expectedLength = expectedMessageLength[bufferKey],
              let queryID = bufferQueryID[bufferKey],
              let expectedSequence = nextSequence[bufferKey] else {
            ErrorHandler.bleError("No message in progress for continuation packet", context: [
                "buffer_key": bufferKey
            ])
            return nil
        }

        // Bits 3-0 are the 4-bit sequence counter, wrapping at 0xF. A gap means
        // a packet was dropped or duplicated; the accumulated bytes can no longer
        // be trusted, since appending regardless would still satisfy the length
        // check and decode as plausible-but-wrong TLV.
        let sequence = data[0] & 0x0F
        guard sequence == expectedSequence else {
            ErrorHandler.warning("Continuation sequence gap - discarding message", context: [
                "buffer_key": bufferKey,
                "expected_sequence": String(expectedSequence),
                "received_sequence": String(sequence)
            ])
            discardBuffer(bufferKey)
            return nil
        }

        buffer.append(payload)
        lastPacketTime[bufferKey] = Date()
        nextSequence[bufferKey] = (expectedSequence + 1) & 0x0F

        if buffer.count >= expectedLength {
            discardBuffer(bufferKey)
            return (data: buffer, queryID: queryID)
        }

        continuationBuffer[bufferKey] = buffer
        return nil
    }
}
