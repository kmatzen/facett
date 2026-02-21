import Foundation

// MARK: - TLV Entry

/// Represents a single TLV (Type-Length-Value) entry
struct TLVEntry {
    let type: UInt8
    let length: Int
    let value: Int
    let valueData: Data

    /// Get the string representation of the TLV entry
    var description: String {
        return "Type: \(type), Length: \(length), Value: \(value)"
    }

    /// Get the string value if this TLV contains string data
    var stringValue: String {
        return String(data: valueData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: "") ?? ""
    }
}

// MARK: - TLV Parser

/// Handles parsing of TLV (Type-Length-Value) data structures from GoPro BLE packets
class BLETLVParser {

    // MARK: - Public Interface

    /// Parse TLV (Type-Length-Value) data into individual TLV entries
    /// - Parameter data: Raw TLV data
    /// - Returns: Array of TLV entries
    func parseTLVData(_ data: Data) -> [TLVEntry] {
        var entries: [TLVEntry] = []
        var offset = 0

        while offset < data.count {
            guard offset + 2 <= data.count else {
                ErrorHandler.bleError("Not enough data for TLV header", context: [
                    "offset": String(offset),
                    "data_size": String(data.count)
                ])
                break
            }

            let type = data[offset]
            let length = Int(data[offset + 1])

            guard offset + 2 + length <= data.count else {
                ErrorHandler.bleError("TLV value extends beyond data bounds", context: [
                    "type": String(type),
                    "length": String(length),
                    "offset": String(offset),
                    "data_size": String(data.count)
                ])
                break
            }

            let valueData = data.subdata(in: (offset + 2)..<(offset + 2 + length))
            let value = parseValue(valueData)

            let entry = TLVEntry(type: type, length: length, value: value, valueData: valueData)
            entries.append(entry)

            offset += 2 + length
        }

        return entries
    }

    /// Parse a value from raw data using big-endian byte order
    /// - Parameter data: Raw data bytes
    /// - Returns: Parsed integer value
    func parseValue(_ data: Data) -> Int {
        var value: Int = 0

        // GoPro BLE protocol uses big-endian (most significant byte first)
        for (index, byte) in data.enumerated() {
            let shift = (data.count - 1 - index) * 8
            let contribution = Int(byte) << shift
            value += contribution
        }

        return value
    }

    /// Parse a string value from raw data
    /// - Parameter data: Raw data bytes
    /// - Returns: Cleaned string value
    func parseStringValue(_ data: Data) -> String {
        // Convert bytes to string, filtering out null bytes
        let string = String(data: data, encoding: .utf8) ?? ""
        let cleanString = string.replacingOccurrences(of: "\0", with: "")

        return cleanString
    }
}

// MARK: - Response Mapper

/// Maps TLV entries to specific ResponseType values based on query ID and TLV type
class BLEResponseMapper {

    private let tlvParser = BLETLVParser()

    // MARK: - Public Interface

    /// Map TLV entries to ResponseType values
    /// - Parameters:
    ///   - entries: Array of TLV entries
    ///   - queryID: Query ID that identifies the type of response
    /// - Returns: Array of mapped ResponseType values
    func mapToResponseTypes(entries: [TLVEntry], queryID: UInt8) -> [ResponseType] {
        var responses: [ResponseType] = []

        for entry in entries {
            if let response = mapToResponseType(entry: entry, queryID: queryID) {
                responses.append(response)
            }
        }

        return responses
    }

    /// Map a single TLV entry to a ResponseType
    /// - Parameters:
    ///   - entry: TLV entry to map
    ///   - queryID: Query ID that identifies the type of response
    /// - Returns: Mapped ResponseType or nil if no mapping exists
    func mapToResponseType(entry: TLVEntry, queryID: UInt8) -> ResponseType? {
        switch queryID {
        case 19: // Status query
            return mapStatusResponse(entry: entry)
        case 18, 20: // Settings queries (18 = FPS, 20 = other settings)
            return mapSettingsResponse(entry: entry)
        default:
            ErrorHandler.bleError("Unknown query ID", context: [
                "query_id": String(queryID),
                "tlv_type": String(entry.type)
            ])
            return nil
        }
    }

    // MARK: - Private Methods

    /// Map status response types
    private func mapStatusResponse(entry: TLVEntry) -> ResponseType? {
        switch entry.type {
        case 1: return .batteryPresent(entry.value == 1)
        case 2:
            return .batteryLevel(Int(entry.value)) // Internal Battery Bars (quantized level)
        case 3:
            return .externalBatteryPresent(entry.value == 1) // External Battery Present
        case 6: return .overheating(entry.value == 1)
        case 8: return .isBusy(entry.value == 1)
        case 10: return .encoding(entry.value == 1)
        case 13: return .videoEncodingDuration(Int32(entry.value))
        case 31: return .connectedDevices(Int8(entry.value))
        case 54: return .sdCardRemaining(Int64(entry.value))
        case 68: return .gpsLock(entry.value == 1)
        case 70:
            return .batteryPercentage(Int(entry.value)) // Internal Battery Percentage (0-100)
        case 82: return .isReady(entry.value == 1)
        case 85: return .isCold(entry.value == 1)
        case 111: return .sdCardWriteSpeedError(entry.value == 1)
        case 114: return .cameraControlId(Int(entry.value))
        case 115: return .usbConnected(entry.value == 1)
        case 116: return .usbControlled(entry.value == 1)
        case 58: return .turboMode(entry.value != 0) // Turbo mode status
        case 91: return .ev(entry.value) // Exposure Value status

        // WiFi credential mappings - these are string data, not integer data
        case 29:
            let ssid = entry.stringValue
            return .wifiSSID(ssid) // WiFi SSID
        case 30:
            let apSSID = entry.stringValue
            return .apSSID(apSSID) // AP SSID
        case 69:
            return .apState(entry.value) // AP State
        case 71:
            let password = entry.stringValue
            return .wifiPassword(password) // WiFi Password
        case 72:
            let apPassword = entry.stringValue
            return .apPassword(apPassword) // AP Password
        case 73:
            let password = entry.stringValue
            return .wifiPassword(password) // WiFi Password (alternative)
        case 74:
            let apPassword = entry.stringValue
            return .apPassword(apPassword) // AP Password (alternative)
        case 75:
            let password = entry.stringValue
            return .wifiPassword(password) // WiFi Password (alternative)

        // Additional status mappings from firmware analysis
        case 113: return .turboTransfer(entry.value == 1)
        case 78: return .mobileFriendlyVideo(entry.value == 1)
        case 63: return .inContextualMenu(entry.value == 1)
        case 109: return .creatingPreset(entry.value == 1)
        case 104: return .linuxCoreActive(entry.value == 1)
        default:
            ErrorHandler.debug("Unknown status type", context: [
                "type": String(entry.type),
                "value": String(entry.value)
            ])
            return nil
        }
    }

    /// Map settings response types
    private func mapSettingsResponse(entry: TLVEntry) -> ResponseType? {
        switch entry.type {
        case 2: return .videoResolution(Int(entry.value))
        case 3: return .framesPerSecond(Int(entry.value))
        case 13: return .isoMax(Int(entry.value))
        case 54: return .quickCapture(entry.value == 1)
        case 59: return .autoPowerDown(Int(entry.value))
        case 83: return .gps(entry.value == 1)
        case 84: return .language(Int(entry.value))
        case 85: return .voiceLanguageControl(Int(entry.value))
        case 86: return .voiceControl(entry.value == 1)
        case 87: return .beeps(Int(entry.value))
        case 88: return .lcdBrightness(Int(entry.value))
        case 91: return .led(Int(entry.value))
        case 102: return .isoMin(Int(entry.value))
        case 114: return .protuneEnabled(entry.value == 1)
        case 115: return .whiteBalance(Int(entry.value))
        case 116: return .colorProfile(Int(entry.value))
        case 118: return .ev(Int(entry.value))
        case 121: return .videoLens(Int(entry.value))
        case 124: return .bitrate(Int(entry.value))
        case 134: return .antiFlicker(Int(entry.value))
        case 135: return .hypersmooth(Int(entry.value))
        case 139: return .rawAudio(Int(entry.value))
        case 144: return .mode(Int(entry.value))
        case 145: return .shutter(Int(entry.value))
        case 149: return .wind(Int(entry.value))
        case 162: return .maxLens(entry.value == 1)
        case 167: return .hindsight(Int(entry.value))
        case 173: return .videoPerformanceMode(Int(entry.value))

        // New settings mappings from firmware analysis
        case 48: return .privacy(Int(entry.value))
        case 103: return .autoLock(Int(entry.value))
        case 104: return .wakeOnVoice(entry.value == 1)
        case 105: return .timer(Int(entry.value))
        case 106: return .videoCompression(Int(entry.value))
        case 112: return .landscapeLock(Int(entry.value))
        case 154: return .frontLcdMode(Int(entry.value))
        case 158: return .screenSaverFront(Int(entry.value))
        case 159: return .screenSaverRear(Int(entry.value))
        case 161: return .defaultPreset(Int(entry.value))
        case 60: return .secondaryStreamGopSize(Int(entry.value))
        case 61: return .secondaryStreamIdrInterval(Int(entry.value))
        case 62: return .secondaryStreamBitRate(Int(entry.value))
        case 64: return .secondaryStreamWindowSize(Int(entry.value))
        case 65: return .gopSize(Int(entry.value))
        case 66: return .idrInterval(Int(entry.value))
        case 67: return .bitRateMode(Int(entry.value))
        case 79: return .audioProtune(entry.value == 1)
        case 96: return .noAudioTrack(entry.value == 1)
        default:
            ErrorHandler.debug("Unknown settings type", context: [
                "type": String(entry.type),
                "value": String(entry.value)
            ])
            return nil
        }
    }
}

// MARK: - GoPro BLE Parser

/// Parser for GoPro BLE protocol packets
/// Handles packet reconstruction, TLV parsing, and response type mapping using specialized components
class GoProBLEParser {

    // MARK: - Properties

    private let packetReconstructor = BLEPacketReconstructor()
    private let tlvParser = BLETLVParser()
    private let responseMapper = BLEResponseMapper()

    // MARK: - Public Interface

    /// Process a BLE packet and return parsed responses if complete
    /// - Parameters:
    ///   - data: Raw packet data from BLE
    ///   - peripheralId: Unique identifier for the peripheral
    /// - Returns: Array of parsed response types, empty if message is incomplete
    func processPacket(_ data: Data, peripheralId: String) -> [ResponseType] {
        // Use packet reconstructor to get complete message data
        guard let (messageData, queryID) = packetReconstructor.processPacket(data, peripheralId: peripheralId) else {
            return [] // Message is incomplete, waiting for more packets
        }

        // Parse TLV data from complete message
        let tlvEntries = tlvParser.parseTLVData(messageData)

        // Map TLV entries to response types
        let responses = responseMapper.mapToResponseTypes(entries: tlvEntries, queryID: queryID)

        ErrorHandler.debug("Processed complete BLE message", context: [
            "peripheral_id": peripheralId,
            "query_id": String(queryID),
            "tlv_entries_count": String(tlvEntries.count),
            "responses_count": String(responses.count)
        ])

        return responses
    }

    /// Clear all buffers (useful for testing and error recovery)
    func clearBuffers() {
        packetReconstructor.clearBuffers()
    }

    /// Get current buffer state (useful for testing)
    func getBufferState() -> (buffers: [String: Data], expectedLengths: [String: Int]) {
        return packetReconstructor.getBufferState()
    }

    /// Check for timeouts and force completion of incomplete responses
    /// - Parameter timeoutInterval: Timeout interval in seconds (default: 5 seconds)
    /// - Returns: Array of parsed responses from timed out buffers
    func checkTimeouts(timeoutInterval: TimeInterval = 5.0) -> [ResponseType] {
        let timeoutResults = packetReconstructor.checkTimeouts(timeoutInterval: timeoutInterval)
        var responses: [ResponseType] = []

        for (messageData, queryID) in timeoutResults {
            // Parse TLV data from timed out message
            let tlvEntries = tlvParser.parseTLVData(messageData)

            // Map TLV entries to response types
            let timeoutResponses = responseMapper.mapToResponseTypes(entries: tlvEntries, queryID: queryID)
            responses.append(contentsOf: timeoutResponses)
        }

        return responses
    }
}

// MARK: - Response Type Extensions

extension ResponseType {
    /// Get the string representation of the response type
    var description: String {
        switch self {
        case .batteryLevel(let value): return "Battery Level: \(value)"
        case .batteryPercentage(let value): return "Battery Percentage: \(value)%"
        case .overheating(let value): return "Overheating: \(value)"
        case .isBusy(let value): return "Is Busy: \(value)"
        case .encoding(let value): return "Encoding: \(value)"
        case .videoEncodingDuration(let value): return "Video Encoding Duration: \(value)"
        case .sdCardRemaining(let value): return "SD Card Remaining: \(value)"
        case .gpsLock(let value): return "GPS Lock: \(value)"
        case .isReady(let value): return "Is Ready: \(value)"
        case .isCold(let value): return "Is Cold: \(value)"
        case .sdCardWriteSpeedError(let value): return "SD Card Write Speed Error: \(value)"
        case .usbConnected(let value): return "USB Connected: \(value)"
        case .batteryPresent(let value): return "Battery Present: \(value)"
        case .externalBatteryPresent(let value): return "External Battery Present: \(value)"
        case .connectedDevices(let value): return "Connected Devices: \(value)"
        case .usbControlled(let value): return "USB Controlled: \(value)"
        case .cameraControlId(let value): return "Camera Control ID: \(value)"
        case .videoResolution(let value): return "Video Resolution: \(value)"
        case .framesPerSecond(let value): return "Frames Per Second: \(value)"
        case .autoPowerDown(let value): return "Auto Power Down: \(value)"
        case .gps(let value): return "GPS: \(value)"
        case .videoLens(let value): return "Video Lens: \(value)"
        case .antiFlicker(let value): return "Anti Flicker: \(value)"
        case .hypersmooth(let value): return "Hypersmooth: \(value)"
        case .maxLens(let value): return "Max Lens: \(value)"
        case .videoPerformanceMode(let value): return "Video Performance Mode: \(value)"
        case .colorProfile(let value): return "Color Profile: \(value)"
        case .lcdBrightness(let value): return "LCD Brightness: \(value)"
        case .isoMax(let value): return "ISO Max: \(value)"
        case .language(let value): return "Language: \(value)"
        case .voiceControl(let value): return "Voice Control: \(value)"
        case .beeps(let value): return "Beeps: \(value)"
        case .isoMin(let value): return "ISO Min: \(value)"
        case .protuneEnabled(let value): return "Protune Enabled: \(value)"
        case .whiteBalance(let value): return "White Balance: \(value)"
        case .ev(let value): return "EV: \(value)"
        case .bitrate(let value): return "Bitrate: \(value)"
        case .rawAudio(let value): return "Raw Audio: \(value)"
        case .mode(let value): return "Mode: \(value)"
        case .shutter(let value): return "Shutter: \(value)"
        case .led(let value): return "LED: \(value)"
        case .wind(let value): return "Wind: \(value)"
        case .hindsight(let value): return "Hindsight: \(value)"
        case .quickCapture(let value): return "Quick Capture: \(value)"
        case .voiceLanguageControl(let value): return "Voice Language Control: \(value)"
        case .videoProtune(let value): return "Video Protune: \(value)"
        case .videoStabilization(let value): return "Video Stabilization: \(value)"
        case .videoFieldOfView(let value): return "Video Field of View: \(value)"
        case .wifiBars(let value): return "WiFi Bars: \(value)"
        case .cameraMode(let value): return "Camera Mode: \(value)"
        case .videoMode(let value): return "Video Mode: \(value)"
        case .photoMode(let value): return "Photo Mode: \(value)"
        case .multiShotMode(let value): return "Multi Shot Mode: \(value)"
        case .flatMode(let value): return "Flat Mode: \(value)"
        case .turboMode(let value): return "Turbo Mode: \(value)"

        // WiFi credentials
        case .wifiSSID(let value): return "WiFi SSID: \(value)"
        case .apSSID(let value): return "AP SSID: \(value)"
        case .apState(let value): return "AP State: \(value)"
        case .wifiPassword(let value): return "WiFi Password: \(value)"
        case .apPassword(let value): return "AP Password: \(value)"

        // New settings from firmware analysis
        case .privacy(let value): return "Privacy: \(value)"
        case .autoLock(let value): return "Auto Lock: \(value)"
        case .wakeOnVoice(let value): return "Wake On Voice: \(value)"
        case .timer(let value): return "Timer: \(value)"
        case .videoCompression(let value): return "Video Compression: \(value)"
        case .landscapeLock(let value): return "Landscape Lock: \(value)"
        case .screenSaverFront(let value): return "Screen Saver Front: \(value)"
        case .screenSaverRear(let value): return "Screen Saver Rear: \(value)"
        case .defaultPreset(let value): return "Default Preset: \(value)"
        case .frontLcdMode(let value): return "Front LCD Mode: \(value)"
        case .secondaryStreamGopSize(let value): return "Secondary Stream GOP Size: \(value)"
        case .secondaryStreamIdrInterval(let value): return "Secondary Stream IDR Interval: \(value)"
        case .secondaryStreamBitRate(let value): return "Secondary Stream Bit Rate: \(value)"
        case .secondaryStreamWindowSize(let value): return "Secondary Stream Window Size: \(value)"
        case .gopSize(let value): return "GOP Size: \(value)"
        case .idrInterval(let value): return "IDR Interval: \(value)"
        case .bitRateMode(let value): return "Bit Rate Mode: \(value)"
        case .audioProtune(let value): return "Audio Protune: \(value)"
        case .noAudioTrack(let value): return "No Audio Track: \(value)"

        // New status from firmware analysis
        case .cameraControlStatus(let value): return "Camera Control Status: \(value)"
        case .allowControlOverUsb(let value): return "Allow Control Over USB: \(value)"
        case .turboTransfer(let value): return "Turbo Transfer: \(value)"
        case .sdRatingCheckError(let value): return "SD Rating Check Error: \(value)"
        case .videoLowTempAlert(let value): return "Video Low Temp Alert: \(value)"
        case .battOkayForOta(let value): return "Battery OK for OTA: \(value)"
        case .firstTimeUse(let value): return "First Time Use: \(value)"
        case .mobileFriendlyVideo(let value): return "Mobile Friendly Video: \(value)"
        case .analyticsReady(let value): return "Analytics Ready: \(value)"
        case .analyticsSize(let value): return "Analytics Size: \(value)"
        case .nextPollMsec(let value): return "Next Poll Msec: \(value)"
        case .inContextualMenu(let value): return "In Contextual Menu: \(value)"
        case .creatingPreset(let value): return "Creating Preset: \(value)"
        case .linuxCoreActive(let value): return "Linux Core Active: \(value)"
        }
    }
}
