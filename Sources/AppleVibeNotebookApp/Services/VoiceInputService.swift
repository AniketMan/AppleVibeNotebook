import Foundation
import Speech
import AVFoundation

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Voice Input Service

/// Service for capturing voice input and converting to text for AI assistance.
/// Uses Apple's Speech framework for on-device speech recognition.
@Observable
@MainActor
public final class VoiceInputService: NSObject {

    // MARK: - Types

    public enum VoiceState: Sendable {
        case idle
        case requesting
        case ready
        case listening
        case processing
        case error(String)
    }

    public struct Transcription: Identifiable, Sendable {
        public let id = UUID()
        public let text: String
        public let isFinal: Bool
        public let confidence: Double
        public let timestamp: Date
    }

    // MARK: - Properties

    public private(set) var state: VoiceState = .idle
    public private(set) var currentTranscription: String = ""
    public private(set) var transcriptionHistory: [Transcription] = []
    public private(set) var audioLevel: Float = 0

    public var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization

    public override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
    }

    // MARK: - Authorization

    /// Request permission for speech recognition
    public func requestAuthorization() async -> Bool {
        state = .requesting

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self.state = .ready
                        continuation.resume(returning: true)
                    case .denied:
                        self.state = .error("Speech recognition denied. Enable in System Settings > Privacy.")
                        continuation.resume(returning: false)
                    case .restricted:
                        self.state = .error("Speech recognition restricted on this device.")
                        continuation.resume(returning: false)
                    case .notDetermined:
                        self.state = .error("Speech recognition not determined.")
                        continuation.resume(returning: false)
                    @unknown default:
                        self.state = .error("Unknown authorization status.")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    // MARK: - Recording

    /// Start listening for voice input
    public func startListening() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceError.recognizerUnavailable
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // On-device for privacy

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level
            let channelData = buffer.floatChannelData?[0]
            let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelData?[$0] ?? 0 }
            let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

            Task { @MainActor in
                self?.audioLevel = rms * 10 // Scale for visualization
            }
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.currentTranscription = result.bestTranscription.formattedString

                    if result.isFinal {
                        let transcription = Transcription(
                            text: result.bestTranscription.formattedString,
                            isFinal: true,
                            confidence: Double(result.bestTranscription.segments.first?.confidence ?? 0),
                            timestamp: Date()
                        )
                        self.transcriptionHistory.insert(transcription, at: 0)
                        self.stopListening()
                    }
                }

                if let error = error {
                    self.state = .error(error.localizedDescription)
                    self.stopListening()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        state = .listening
        currentTranscription = ""
    }

    /// Stop listening
    public func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        audioLevel = 0

        if case .listening = state {
            state = .ready
        }
    }

    /// Toggle listening state
    public func toggleListening() throws {
        if isListening {
            stopListening()
        } else {
            try startListening()
        }
    }

    /// Clear transcription history
    public func clearHistory() {
        transcriptionHistory.removeAll()
        currentTranscription = ""
    }

    // MARK: - Errors

    public enum VoiceError: Error, LocalizedError {
        case recognizerUnavailable
        case requestCreationFailed
        case notAuthorized

        public var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognizer is not available"
            case .requestCreationFailed:
                return "Failed to create recognition request"
            case .notAuthorized:
                return "Speech recognition not authorized"
            }
        }
    }
}
