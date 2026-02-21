import Foundation
import AVFoundation

// MARK: - Voice Notification Manager
@MainActor
class VoiceNotificationManager: NSObject, ObservableObject {
    static let shared = VoiceNotificationManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?

    @Published var voiceNotificationsEnabled: Bool = false

    private let persistenceManager = DataPersistenceManager.shared
    private let voiceNotificationsKey = "VoiceNotificationsEnabled"

    override init() {
        super.init()
        loadSettings()
        synthesizer.delegate = self
    }

    // MARK: - Settings Management

    private func loadSettings() {
        do {
            if let enabled: Bool = try persistenceManager.retrieveSimpleValue(Bool.self, forKey: voiceNotificationsKey) {
                voiceNotificationsEnabled = enabled
            }
        } catch {
            ErrorHandler.error("Failed to load voice notification settings", error: error)
            // Fall back to default value
            voiceNotificationsEnabled = false
        }
    }

    func setVoiceNotificationsEnabled(_ enabled: Bool) {
        voiceNotificationsEnabled = enabled
        do {
            persistenceManager.storeSimpleValue(enabled, forKey: voiceNotificationsKey)
        } catch {
            ErrorHandler.error("Failed to save voice notification settings", error: error)
        }
    }

    // MARK: - Voice Notifications

    func speak(_ text: String, priority: NotificationPriority = .normal) {
        guard voiceNotificationsEnabled else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8

        // Adjust volume based on priority
        switch priority {
        case .high:
            utterance.volume = 1.0
            utterance.rate = 0.4 // Slower for important messages
        case .normal:
            utterance.volume = 0.8
            utterance.rate = 0.5
        case .low:
            utterance.volume = 0.6
            utterance.rate = 0.6
        }

        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    // MARK: - Recording Notifications

    func notifyRecordingStarted(cameraCount: Int = 1) {
        let message: String
        if cameraCount == 1 {
            message = "Recording started"
        } else {
            message = "Recording started on \(cameraCount) cameras"
        }
        speak(message, priority: .high)
    }

    func notifyRecordingStopped(cameraCount: Int = 1) {
        let message: String
        if cameraCount == 1 {
            message = "Recording stopped"
        } else {
            message = "Recording stopped on \(cameraCount) cameras"
        }
        speak(message, priority: .normal)
    }

    func notifyRecordingError(cameraName: String? = nil, error: String? = nil) {
        let message: String
        if let cameraName = cameraName {
            message = "Recording error on \(cameraName)"
        } else {
            message = "Recording error occurred"
        }

        if let error = error {
            speak("\(message): \(error)", priority: .high)
        } else {
            speak(message, priority: .high)
        }
    }

    func notifyCameraConnected(cameraName: String) {
        speak("\(cameraName) connected", priority: .low)
    }

    func notifyCameraDisconnected(cameraName: String) {
        speak("\(cameraName) disconnected", priority: .normal)
    }

    func notifySettingsSynced(cameraCount: Int = 1) {
        let message: String
        if cameraCount == 1 {
            message = "Settings synced"
        } else {
            message = "Settings synced to \(cameraCount) cameras"
        }
        speak(message, priority: .low)
    }

    // MARK: - Utility Methods

    func isSpeaking() -> Bool {
        return synthesizer.isSpeaking
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceNotificationManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            currentUtterance = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            currentUtterance = nil
        }
    }
}

// MARK: - Notification Priority

enum NotificationPriority {
    case high    // Errors, important events
    case normal  // Regular events
    case low     // Status updates
}
