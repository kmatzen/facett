import Foundation
import CoreBluetooth

// MARK: - BLE Response Handler
class BLEResponseHandler {
    private weak var bleManager: BLEManager?

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    // MARK: - Query Response Handling
    func handleQueryResponse(_ data: Data, for peripheral: CBPeripheral) {
        let responses = parseResponseType(from: data, peripheral: peripheral)
        updateGoProStatus(uuid: peripheral.identifier, with: responses)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func updateGoProStatus(uuid: UUID, with responses: [ResponseType]) {
        guard let bleManager = bleManager else { return }

        DispatchQueue.main.async { [weak bleManager] in
            guard let bleManager = bleManager,
                  let gopro = bleManager.connectedGoPros[uuid] else { return }

            // Remove from cameras being connected from group when status is updated
            bleManager.camerasBeingConnectedFromGroup.remove(uuid)

            // Mark camera as having received initial status if this is the first update
            let wasFirstUpdate = !gopro.hasReceivedInitialStatus
            if wasFirstUpdate {
                gopro.hasReceivedInitialStatus = true

                // Sync time when camera first connects and is ready for commands
                let cameraName = CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: gopro.name)
                ErrorHandler.info("Syncing time for newly connected camera: \(cameraName)")
                bleManager.setDateTime(for: uuid)
            }

            for response in responses {
                switch response {
                case .batteryLevel(let level):
                    gopro.status.batteryLevel = level
                    // According to Open GoPro BLE API, battery level 4 indicates charging
                    let isNowCharging = (level == 4)
                    gopro.status.isUSBConnected = isNowCharging

                case .batteryPercentage(let percentage):
                    gopro.status.batteryPercentage = percentage
                    // Post notification to refresh UI
                case .overheating(let isOverheating):
                    gopro.status.isOverheating = isOverheating
                case .isBusy(let isBusy):
                    gopro.status.isBusy = isBusy
                case .encoding(let isEncoding):
                    gopro.status.isEncoding = isEncoding
                case .videoEncodingDuration(let seconds):
                    gopro.status.videoEncodingDuration = seconds
                case .sdCardRemaining(let remaining):
                    gopro.status.sdCardRemaining = remaining

                case .gpsLock(let hasLock):
                    gopro.status.hasGPSLock = hasLock
                case .isReady(let isReady):
                    gopro.status.isReady = isReady
                case .isCold(let isCold):
                    gopro.status.isCold = isCold
                case .sdCardWriteSpeedError(let hasError):
                    gopro.status.hasSDCardWriteSpeedError = hasError
                case .usbConnected(let isConnected):
                    // Note: We're now using battery level to determine charging status instead of this USB connection status
                    // This prevents conflicts between the two different charging detection methods
                    ErrorHandler.debug("USB Connection status received (ignored - using battery level instead)",
                                      context: ["camera_name": gopro.name ?? "Unknown", "is_connected": String(isConnected)])
                case .batteryPresent(let isPresent):
                    gopro.status.isBatteryPresent = isPresent
                case .externalBatteryPresent(let isPresent):
                    gopro.status.isExternalBatteryPresent = isPresent
                case .connectedDevices(let count):
                    gopro.status.connectedDevices = count
                case .usbControlled(let isControlled):
                    gopro.status.usbControlled = isControlled
                case .cameraControlId(let id):
                    if id != 2 {
                        ErrorHandler.debug("Reclaiming control of \(uuid)")
                        bleManager.connectedGoPros[uuid]?.hasControl = false
                        bleManager.claimControl(for: uuid)
                    }
                    gopro.status.cameraControlId = id

                // Settings
                case .videoResolution(let resolution):
                    gopro.updateSetting(\.videoResolution, value: resolution)
                case .framesPerSecond(let fps):
                    gopro.updateSetting(\.framesPerSecond, value: fps)
                case .autoPowerDown(let autoOff):
                    gopro.updateSetting(\.autoPowerDown, value: autoOff)
                case .gps(let gpsEnabled):
                    gopro.updateSetting(\.gps, value: gpsEnabled)
                case .videoLens(let lens):
                    gopro.updateSetting(\.videoLens, value: lens)
                case .antiFlicker(let antiFlicker):
                    gopro.updateSetting(\.antiFlicker, value: antiFlicker)
                case .hypersmooth(let hypersmooth):
                    gopro.updateSetting(\.hypersmooth, value: hypersmooth)
                case .maxLens(let maxLens):
                    gopro.updateSetting(\.maxLens, value: maxLens)
                case .videoPerformanceMode(let mode):
                    gopro.updateSetting(\.videoPerformanceMode, value: mode)
                case .colorProfile(let profile):
                    gopro.updateSetting(\.colorProfile, value: profile)
                case .lcdBrightness(let brightness):
                    gopro.updateSetting(\.lcdBrightness, value: brightness)
                case .isoMax(let iso):
                    gopro.updateSetting(\.isoMax, value: iso)
                case .language(let language):
                    gopro.updateSetting(\.language, value: language)
                case .voiceControl(let voiceControl):
                    gopro.updateSetting(\.voiceControl, value: voiceControl)
                case .beeps(let beeps):
                    gopro.updateSetting(\.beeps, value: beeps)
                case .isoMin(let iso):
                    gopro.updateSetting(\.isoMin, value: iso)
                case .protuneEnabled(let protune):
                    gopro.updateSetting(\.protuneEnabled, value: protune)
                case .whiteBalance(let whiteBalance):
                    gopro.updateSetting(\.whiteBalance, value: whiteBalance)
                case .ev(let ev):
                    gopro.updateSetting(\.ev, value: ev)
                case .bitrate(let bitrate):
                    gopro.updateSetting(\.bitrate, value: bitrate)
                case .rawAudio(let rawAudio):
                    gopro.updateSetting(\.rawAudio, value: rawAudio)
                case .mode(let mode):
                    gopro.updateSetting(\.mode, value: mode)
                case .shutter(let shutter):
                    gopro.updateSetting(\.shutter, value: shutter)
                case .led(let led):
                    gopro.updateSetting(\.led, value: led)
                case .wind(let wind):
                    gopro.updateSetting(\.wind, value: wind)
                case .hindsight(let hindsight):
                    gopro.updateSetting(\.hindsight, value: hindsight)
                case .quickCapture(let quickCapture):
                    gopro.updateSetting(\.quickCapture, value: quickCapture)
                case .voiceLanguageControl(let voiceLanguage):
                    gopro.updateSetting(\.voiceLanguageControl, value: voiceLanguage)

                // Additional status and settings cases
                case .wifiBars(let bars):
                    gopro.status.wifiBars = bars
                case .cameraMode(let mode):
                    gopro.status.cameraMode = mode
                case .videoMode(let mode):
                    gopro.status.videoMode = mode
                    gopro.updateSetting(\.mode, value: mode)
                case .photoMode(let mode):
                    gopro.status.photoMode = mode
                case .multiShotMode(let mode):
                    gopro.status.multiShotMode = mode
                case .flatMode(let mode):
                    gopro.status.flatMode = mode
                case .videoProtune(let protune):
                    gopro.status.videoProtune = protune
                    gopro.updateSetting(\.protuneEnabled, value: protune)
                case .videoStabilization(let stabilization):
                    gopro.status.videoStabilization = stabilization
                    gopro.updateSetting(\.hypersmooth, value: stabilization)
                case .videoFieldOfView(let fov):
                    gopro.status.videoFieldOfView = fov
                    gopro.updateSetting(\.videoLens, value: fov)
                case .turboMode(let turbo):
                    gopro.status.turboMode = turbo

                // WiFi credentials
                case .wifiSSID(let ssid):
                    gopro.status.wifiSSID = ssid
                case .apSSID(let ssid):
                    gopro.status.apSSID = ssid
                    // Store serial number mapping and check for UUID changes
                    self.handleSerialNumberUpdate(ssid: ssid, uuid: uuid)
                case .apState(let state):
                    gopro.status.apState = state
                case .wifiPassword(let password):
                    gopro.status.wifiPassword = password
                case .apPassword(let password):
                    gopro.status.apPassword = password

                // New settings from firmware analysis
                case .privacy(let privacy):
                    gopro.updateSetting(\.privacy, value: privacy)
                case .autoLock(let autoLock):
                    gopro.updateSetting(\.autoLock, value: autoLock)
                case .wakeOnVoice(let wakeOnVoice):
                    gopro.updateSetting(\.wakeOnVoice, value: wakeOnVoice)
                case .timer(let timer):
                    gopro.updateSetting(\.timer, value: timer)
                case .videoCompression(let compression):
                    gopro.updateSetting(\.videoCompression, value: compression)
                case .landscapeLock(let landscapeLock):
                    gopro.updateSetting(\.landscapeLock, value: landscapeLock)
                case .screenSaverFront(let screenSaver):
                    gopro.updateSetting(\.screenSaverFront, value: screenSaver)
                case .screenSaverRear(let screenSaver):
                    gopro.updateSetting(\.screenSaverRear, value: screenSaver)
                case .defaultPreset(let defaultPreset):
                    gopro.updateSetting(\.defaultPreset, value: defaultPreset)
                case .frontLcdMode(let frontLcdMode):
                    gopro.updateSetting(\.frontLcdMode, value: frontLcdMode)
                case .gopSize(let gopSize):
                    gopro.updateSetting(\.gopSize, value: gopSize)
                case .idrInterval(let idrInterval):
                    gopro.updateSetting(\.idrInterval, value: idrInterval)
                case .bitRateMode(let bitRateMode):
                    gopro.updateSetting(\.bitRateMode, value: bitRateMode)
                case .audioProtune(let audioProtune):
                    gopro.updateSetting(\.audioProtune, value: audioProtune)
                case .noAudioTrack(let noAudioTrack):
                    gopro.updateSetting(\.noAudioTrack, value: noAudioTrack)
                case .secondaryStreamGopSize(let secondaryStreamGopSize):
                    // Secondary stream properties no longer exist in GoProSettings
                    ErrorHandler.debug("Secondary stream GOP size received: \(secondaryStreamGopSize) (ignored)")
                case .secondaryStreamIdrInterval(let secondaryStreamIdrInterval):
                    // Secondary stream properties no longer exist in GoProSettings
                    ErrorHandler.debug("Secondary stream IDR interval received: \(secondaryStreamIdrInterval) (ignored)")
                case .secondaryStreamBitRate(let secondaryStreamBitRate):
                    // Secondary stream properties no longer exist in GoProSettings
                    ErrorHandler.debug("Secondary stream bit rate received: \(secondaryStreamBitRate) (ignored)")
                case .secondaryStreamWindowSize(let secondaryStreamWindowSize):
                    // Secondary stream properties no longer exist in GoProSettings
                    ErrorHandler.debug("Secondary stream window size received: \(secondaryStreamWindowSize) (ignored)")

                // New status from firmware analysis
                case .cameraControlStatus(let cameraControlStatus):
                    gopro.status.cameraControlStatus = cameraControlStatus
                case .allowControlOverUsb(let allowControlOverUsb):
                    gopro.status.allowControlOverUsb = allowControlOverUsb
                case .turboTransfer(let turboTransfer):
                    gopro.status.turboTransfer = turboTransfer
                case .sdRatingCheckError(let sdRatingCheckError):
                    gopro.status.sdRatingCheckError = sdRatingCheckError
                case .videoLowTempAlert(let videoLowTempAlert):
                    gopro.status.videoLowTempAlert = videoLowTempAlert
                case .battOkayForOta(let battOkayForOta):
                    gopro.status.battOkayForOta = battOkayForOta
                case .firstTimeUse(let firstTimeUse):
                    gopro.status.firstTimeUse = firstTimeUse
                case .mobileFriendlyVideo(let mobileFriendlyVideo):
                    gopro.status.mobileFriendlyVideo = mobileFriendlyVideo
                case .analyticsReady(let analyticsReady):
                    gopro.status.analyticsReady = analyticsReady
                case .analyticsSize(let analyticsSize):
                    gopro.status.analyticsSize = analyticsSize
                case .nextPollMsec(let nextPollMsec):
                    gopro.status.nextPollMsec = nextPollMsec
                case .inContextualMenu(let inContextualMenu):
                    gopro.status.inContextualMenu = inContextualMenu
                case .creatingPreset(let creatingPreset):
                    gopro.status.creatingPreset = creatingPreset
                case .linuxCoreActive(let linuxCoreActive):
                    gopro.status.linuxCoreActive = linuxCoreActive
                }
            }

            bleManager.connectedGoPros[uuid] = gopro

            // Record successful query response for health monitoring
            if let queryStartTime = bleManager.lastQueryTimes[uuid] {
                let responseTime = Date().timeIntervalSince(queryStartTime)
                bleManager.recordQuerySuccess(for: uuid, responseTime: responseTime)
            }

            // Trigger immediate sync if this was the first status update and auto-sync is enabled
            if wasFirstUpdate {
                ErrorHandler.info("Camera received initial status - checking for immediate sync",
                                 context: ["camera_name": CameraIdentityManager.shared.getDisplayName(for: uuid, currentName: gopro.name), "camera_id": uuid.uuidString])
                bleManager.onCameraStatusUpdated?(uuid)
            }
        }
    }

    // MARK: - Response Parsing
    private func parseResponseType(from data: Data, peripheral: CBPeripheral) -> [ResponseType] {
        guard let bleManager = bleManager else { return [] }

        // Log the raw data
        ErrorHandler.debug("Parsing response data: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")

        let peripheralId = peripheral.identifier.uuidString
        let responses = bleManager.bleParser.processPacket(data, peripheralId: peripheralId)

        return responses
    }

    // MARK: - Serial Number Handling

    /// Handle serial number update from apSSID - store mapping
    private func handleSerialNumberUpdate(ssid: String, uuid: UUID) {
        // Store the serial number mapping for lookup
        CameraSerialResolver.shared.storeUUID(uuid, forSerial: ssid)

        // Store the display name mapping using serial number
        if let gopro = bleManager?.connectedGoPros[uuid],
           let peripheralName = gopro.name {
            CameraIdentityManager.shared.storeCameraName(peripheralName, forSerial: ssid)
        }
    }
}
