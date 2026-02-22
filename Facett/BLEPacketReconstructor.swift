import Foundation

/// Handles BLE packet reconstruction for multi-packet messages
class BLEPacketReconstructor {

    // MARK: - Properties

    /// Continuation packet buffers for message reconstruction
    private var continuationBuffer: [String: Data] = [:] // Key: "peripheralID:queryID"
    private var expectedMessageLength: [String: Int] = [:] // Key: "peripheralID:queryID"
    private var lastPacketTime: [String: Date] = [:] // Track when last packet was received

    // MARK: - Public Interface

    /// Process a BLE packet and return complete message data if available
    /// - Parameters:
    ///   - data: Raw packet data from BLE
    ///   - peripheralId: Unique identifier for the peripheral
    /// - Returns: Complete message data if available, nil if message is incomplete
    func processPacket(_ data: Data, peripheralId: String) -> (data: Data, queryID: UInt8)? {
        guard !data.isEmpty else {
            ErrorHandler.bleError("Received empty data")
            return nil
        }

        // Parse packet header according to GoPro BLE protocol
        let packetHeader = data[0]
        let packetType = (packetHeader >> 6) & 0x03 // Extract bits 7-6 for packet type

        ErrorHandler.debug("Received packet type \(packetType)", context: [
            "peripheral_id": peripheralId,
            "data": data.map { String(format: "%02x", $0) }.joined(separator: " ")
        ])

        // Handle continuation packets with message reconstruction
        let isContinuationBit = (packetHeader & 0x20) != 0

        // Check if this looks like an initial packet
        let looksLikeInitialPacket = data.count >= 4 &&
                                   data[3] == 0 &&
                                   packetType != 2 &&
                                   isContinuationBit

        // Process as continuation packet if:
        // 1. It's a type 2 packet, OR
        // 2. It has continuation bit set AND doesn't look like an initial packet
        if packetType == 2 || (isContinuationBit && !looksLikeInitialPacket) {
            ErrorHandler.debug("Processing continuation packet", context: ["peripheral_id": peripheralId])
            return handleContinuationPacket(data: data, peripheralId: peripheralId)
        }

        // Handle initial packets
        return handleInitialPacket(data: data, peripheralId: peripheralId)
    }

    /// Clear all buffers (useful for testing and error recovery)
    func clearBuffers() {
        continuationBuffer.removeAll()
        expectedMessageLength.removeAll()
        lastPacketTime.removeAll()
    }

    /// Clear buffers for a specific peripheral
    func clearBuffers(for peripheralId: String) {
        let keysToRemove = continuationBuffer.keys.filter { $0.hasPrefix(peripheralId) }
        for key in keysToRemove {
            continuationBuffer.removeValue(forKey: key)
            expectedMessageLength.removeValue(forKey: key)
            lastPacketTime.removeValue(forKey: key)
        }
    }

    /// Get current buffer state (useful for testing)
    func getBufferState() -> (buffers: [String: Data], expectedLengths: [String: Int]) {
        return (continuationBuffer, expectedMessageLength)
    }

    /// Check for timeouts and force completion of incomplete responses
    /// - Parameter timeoutInterval: Timeout interval in seconds (default: 5 seconds)
    /// - Returns: Array of complete message data from timed out buffers
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

        // Clean up timed out buffers
        for key in keysToRemove {
            continuationBuffer.removeValue(forKey: key)
            expectedMessageLength.removeValue(forKey: key)
            lastPacketTime.removeValue(forKey: key)
        }

        return results
    }

    // MARK: - Private Methods

    /// Handle initial packets (single or first packet of multi-packet message)
    private func handleInitialPacket(data: Data, peripheralId: String) -> (data: Data, queryID: UInt8)? {
        guard data.count >= 4 else {
            ErrorHandler.bleError("Initial packet too short", context: ["data_length": String(data.count)])
            return nil
        }

        let totalLength: Int
        let queryID: Int
        let _: Int // statusByte (unused for now)
        let tlvStartIndex: Int

        if data[3] == 0 {
            // Format 1: [packetHeader] [totalLength] [queryID] [status=0] [TLV data...]
            let packetTotalLength = Int(data[1])
            queryID = Int(data[2])
            _ = Int(data[3]) // statusByte
            tlvStartIndex = 4
            // For multipart responses, totalLength is the TLV data length (packet total - header bytes)
            totalLength = packetTotalLength - 2  // Subtract [queryID][status] from total
        } else {
            // Format 2: [packetHeader] [queryID] [status] [TLV data...]
            // This is a single-packet response, so totalLength = packet length - header
            totalLength = data.count - 3  // Total data minus [header][queryID][status]
            queryID = Int(data[1])
            _ = Int(data[2]) // statusByte
            tlvStartIndex = 3
        }

        let tlvData = data.subdata(in: tlvStartIndex..<data.count)

        // Always use the buffer-based approach for consistency
        let bufferKey = "\(peripheralId):\(queryID)"
        continuationBuffer[bufferKey] = tlvData
        expectedMessageLength[bufferKey] = totalLength
        lastPacketTime[bufferKey] = Date()

        ErrorHandler.debug("Initialized buffer for queryID", context: [
            "query_id": String(queryID),
            "tlv_data_length": String(tlvData.count),
            "expected_total": String(totalLength)
        ])

        // Check if we already have the complete message (single packet case)
        if tlvData.count >= totalLength {
            ErrorHandler.debug("Complete message received in single packet", context: ["query_id": String(queryID)])

            // Clear the buffer
            continuationBuffer.removeValue(forKey: bufferKey)
            expectedMessageLength.removeValue(forKey: bufferKey)
            lastPacketTime.removeValue(forKey: bufferKey)

            return (data: tlvData, queryID: UInt8(queryID))
        } else {
            ErrorHandler.debug("Incomplete message, waiting for continuation packets", context: ["query_id": String(queryID)])
            return nil // Wait for continuation packets
        }
    }

    /// Handle continuation packets by appending data to existing buffers
    private func handleContinuationPacket(data: Data, peripheralId: String) -> (data: Data, queryID: UInt8)? {
        guard data.count >= 3 else {
            ErrorHandler.bleError("Continuation packet too short", context: ["data_length": String(data.count)])
            return nil
        }

        let sequenceCounter = data[0] & 0x0F // Lower 4 bits are sequence counter
        let status = data[2] // Third byte is status

        ErrorHandler.debug("Continuation packet received", context: [
            "sequence": String(sequenceCounter),
            "status": String(status),
            "peripheral_id": peripheralId
        ])

        let bufferKeys = continuationBuffer.keys.filter { $0.hasPrefix(peripheralId) }

        if bufferKeys.isEmpty {
            return handleFirstPacketOfMultipart(data: data, peripheralId: peripheralId)
        }

        // When multiple buffers exist, pick the most recently active one.
        // Continuation packets don't carry a query ID, so we use recency
        // as the best heuristic. The GoPro BLE protocol expects one
        // multipart response per characteristic at a time.
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

        // Extract TLV data from continuation packet
        let packetType = (data[0] >> 6) & 0x03 // Extract bits 7-6 for packet type
        let tlvData: Data
        if packetType == 2 { // Type 2 packet
            tlvData = data.subdata(in: 1..<data.count)
        } else { // Type 1 packet with continuation bit
            tlvData = data.subdata(in: 1..<data.count)
        }

        ErrorHandler.debug("Extracted TLV data from continuation packet", context: [
            "tlv_data_length": String(tlvData.count),
            "packet_type": String(packetType)
        ])

        // Append to buffer
        buffer.append(tlvData)
        continuationBuffer[bufferKey] = buffer
        lastPacketTime[bufferKey] = Date()

        ErrorHandler.debug("Buffer updated", context: [
            "buffer_length": String(buffer.count),
            "expected_length": String(expectedLength)
        ])

        // Check if we have the complete message
        if buffer.count >= expectedLength {
            ErrorHandler.debug("Complete message received from continuation packets", context: [
                "buffer_length": String(buffer.count)
            ])

            // Extract query ID from buffer key
            let queryIDString = bufferKey.split(separator: ":")[1]
            let queryID = UInt8(queryIDString) ?? 0

            // Clear the buffer
            continuationBuffer.removeValue(forKey: bufferKey)
            expectedMessageLength.removeValue(forKey: bufferKey)
            lastPacketTime.removeValue(forKey: bufferKey)

            return (data: buffer, queryID: queryID)
        }

        return nil // Still waiting for more packets
    }

    /// Handle the first packet of a multipart response
    private func handleFirstPacketOfMultipart(data: Data, peripheralId: String) -> (data: Data, queryID: UInt8)? {
        let packetType = (data[0] >> 6) & 0x03
        let isContinuationBit = (data[0] & 0x20) != 0
        let looksLikeInitialPacket = data.count >= 4 &&
                                   data[3] == 0 &&
                                   packetType != 2 &&
                                   isContinuationBit

        if looksLikeInitialPacket {
            ErrorHandler.debug("First packet of multipart response detected", context: ["peripheral_id": peripheralId])

            let packetTotalLength = Int(data[1])
            let queryID = Int(data[2])
            let tlvData = data.subdata(in: 4..<data.count)

            let bufferKey = "\(peripheralId):\(queryID)"
            continuationBuffer[bufferKey] = tlvData
            // For multipart responses, expectedMessageLength is the TLV data length (packet total - header bytes)
            expectedMessageLength[bufferKey] = packetTotalLength - 2  // Subtract [queryID][status] from total
            lastPacketTime[bufferKey] = Date()

            let expectedTLVLength = packetTotalLength - 2  // Subtract [queryID][status] from total
            ErrorHandler.debug("Initialized buffer for multipart response", context: [
                "query_id": String(queryID),
                "tlv_data_length": String(tlvData.count),
                "expected_total": String(expectedTLVLength)
            ])

            // Check if we already have the complete message
            if tlvData.count >= expectedTLVLength {
                ErrorHandler.debug("Complete message received in single packet for multipart response", context: ["query_id": String(queryID)])

                // Clear the buffer
                continuationBuffer.removeValue(forKey: bufferKey)
                expectedMessageLength.removeValue(forKey: bufferKey)
                lastPacketTime.removeValue(forKey: bufferKey)

                return (data: tlvData, queryID: UInt8(queryID))
            } else {
                ErrorHandler.debug("Incomplete multipart message, waiting for continuation packets", context: ["query_id": String(queryID)])
                return nil // Wait for continuation packets
            }
        } else {
            ErrorHandler.bleError("No buffer found for peripheral", context: ["peripheral_id": peripheralId])
            return nil
        }
    }
}
