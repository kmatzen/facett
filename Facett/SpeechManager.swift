//
//  SpeechManager.swift
//  Facett
//
//  Created by Kevin Matzen on 5/12/25.
//


import Foundation
import AVFoundation
import Speech

class SpeechManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @Published var isListening = false
    var onStartCommand: (() -> Void)? = nil
    var onStopCommand: (() -> Void)? = nil

    var transcriptPosition: Int = 0

    init() {
        // Don't request permissions on init - wait until first use
    }

    private func requestAuthorization() async -> Bool {
        // Check current authorization status
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        // If already authorized, return true
        if speechStatus == .authorized {
            return true
        }

        // If denied or restricted, return false
        if speechStatus == .denied || speechStatus == .restricted {
            return false
        }

        // Request authorization
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            Task {
                let authorized = await requestAuthorization()
                if authorized {
                    try? startListening()
                } else {
                    ErrorHandler.warning("Speech recognition not authorized")
                }
            }
        }
    }

    private func startListening() throws {
        transcriptPosition = 0
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let segments = result.bestTranscription.segments

                while self.transcriptPosition < segments.count {
                    let segment = segments[self.transcriptPosition]
                    let word = segment.substring.lowercased()
                    ErrorHandler.debug("Processing new word: \(word)")

                    if word == "start" {
                        self.onStartCommand?()
                    } else if word == "stop" {
                        self.onStopCommand?()
                    }

                    self.transcriptPosition += 1
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self.stopListening()
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    private func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask = nil
        recognitionRequest = nil
        if Thread.isMainThread {
            isListening = false
        } else {
            DispatchQueue.main.async { self.isListening = false }
        }
    }
}
