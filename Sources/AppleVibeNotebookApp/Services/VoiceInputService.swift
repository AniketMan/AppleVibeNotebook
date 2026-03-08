import Foundation
import Speech
import AVFoundation
import Combine

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Voice Input Service

/// Service for capturing voice input and converting to text for AI assistance.
/// Uses Apple's Speech framework for on-device speech recognition.
///
/// Note: This class is @MainActor isolated to avoid Swift Concurrency data race issues
/// with SFSpeechRecognizer callbacks.
@MainActor
public final class VoiceInputService: NSObject, ObservableObject {

    // MARK: - Types

    public enum VoiceState: Sendable, Equatable {
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

    // MARK: - Published Properties

    @Published public private(set) var state: VoiceState = .idle
    @Published public private(set) var currentTranscription: String = ""
    @Published public private(set) var transcriptionHistory: [Transcription] = []
    @Published public private(set) var audioLevel: Float = 0

    public var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    // MARK: - Private Properties

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
    public nonisolated func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        return await MainActor.run {
            self.state = .requesting

            switch status {
            case .authorized:
                self.state = .ready
                return true
            case .denied:
                self.state = .error("Speech recognition denied. Enable in System Settings > Privacy.")
                return false
            case .restricted:
                self.state = .error("Speech recognition restricted on this device.")
                return false
            case .notDetermined:
                self.state = .error("Speech recognition not determined.")
                return false
            @unknown default:
                self.state = .error("Unknown authorization status.")
                return false
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

        // Configure audio session for iOS
        #if os(iOS) || os(watchOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // On-device for privacy

        // Configure audio input
        let inputNode = audioEngine.inputNode

        guard inputNode.numberOfInputs > 0 else {
            throw VoiceError.noAudioInput
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw VoiceError.invalidAudioFormat
        }

        // Install audio tap - this callback runs on audio thread
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level from buffer
            let channelData = buffer.floatChannelData?[0]
            let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelData?[$0] ?? 0 }
            let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let level = rms * 10

            // Update on main actor
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
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
        case noAudioInput
        case invalidAudioFormat

        public var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognizer is not available"
            case .requestCreationFailed:
                return "Failed to create recognition request"
            case .notAuthorized:
                return "Speech recognition not authorized"
            case .noAudioInput:
                return "No audio input available. Please check your microphone settings."
            case .invalidAudioFormat:
                return "Invalid audio format. Please check your audio device settings."
            }
        }
    }
}
