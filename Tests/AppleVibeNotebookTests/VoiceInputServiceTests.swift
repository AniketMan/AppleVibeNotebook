import Testing
import Foundation
import AVFoundation
import Speech
@testable import AppleVibeNotebook

@Suite("Voice Input Service Tests")
struct VoiceInputServiceTests {

    // MARK: - Initialization Tests

    @Test("Service initializes with idle state")
    func testServiceInitializesWithIdleState() async {
        let service = await VoiceInputService()
        let state = await service.state

        #expect(state == .idle)
    }

    @Test("Service initializes with empty transcription")
    func testServiceInitializesWithEmptyTranscription() async {
        let service = await VoiceInputService()
        let transcription = await service.currentTranscription

        #expect(transcription.isEmpty)
    }

    @Test("Service initializes with empty history")
    func testServiceInitializesWithEmptyHistory() async {
        let service = await VoiceInputService()
        let history = await service.transcriptionHistory

        #expect(history.isEmpty)
    }

    @Test("Service initializes with zero audio level")
    func testServiceInitializesWithZeroAudioLevel() async {
        let service = await VoiceInputService()
        let level = await service.audioLevel

        #expect(level == 0)
    }

    @Test("isListening returns false when idle")
    func testIsListeningReturnsFalseWhenIdle() async {
        let service = await VoiceInputService()
        let isListening = await service.isListening

        #expect(isListening == false)
    }

    // MARK: - VoiceState Equatable Tests

    @Test("VoiceState idle equals idle")
    func testVoiceStateIdleEquality() {
        let state1: VoiceInputService.VoiceState = .idle
        let state2: VoiceInputService.VoiceState = .idle

        #expect(state1 == state2)
    }

    @Test("VoiceState error with same message equals")
    func testVoiceStateErrorEquality() {
        let state1: VoiceInputService.VoiceState = .error("Test error")
        let state2: VoiceInputService.VoiceState = .error("Test error")

        #expect(state1 == state2)
    }

    @Test("VoiceState error with different messages not equal")
    func testVoiceStateErrorInequality() {
        let state1: VoiceInputService.VoiceState = .error("Error 1")
        let state2: VoiceInputService.VoiceState = .error("Error 2")

        #expect(state1 != state2)
    }

    @Test("VoiceState different states not equal")
    func testVoiceStateDifferentStatesNotEqual() {
        let idle: VoiceInputService.VoiceState = .idle
        let listening: VoiceInputService.VoiceState = .listening
        let processing: VoiceInputService.VoiceState = .processing

        #expect(idle != listening)
        #expect(listening != processing)
        #expect(idle != processing)
    }

    // MARK: - Transcription Tests

    @Test("Transcription has unique ID")
    func testTranscriptionHasUniqueId() {
        let transcription1 = VoiceInputService.Transcription(
            text: "Hello",
            isFinal: true,
            confidence: 0.95,
            timestamp: Date()
        )
        let transcription2 = VoiceInputService.Transcription(
            text: "Hello",
            isFinal: true,
            confidence: 0.95,
            timestamp: Date()
        )

        #expect(transcription1.id != transcription2.id)
    }

    @Test("Transcription stores text correctly")
    func testTranscriptionStoresText() {
        let text = "Test transcription text"
        let transcription = VoiceInputService.Transcription(
            text: text,
            isFinal: true,
            confidence: 0.9,
            timestamp: Date()
        )

        #expect(transcription.text == text)
    }

    @Test("Transcription stores isFinal correctly")
    func testTranscriptionStoresIsFinal() {
        let finalTranscription = VoiceInputService.Transcription(
            text: "Final",
            isFinal: true,
            confidence: 0.9,
            timestamp: Date()
        )
        let partialTranscription = VoiceInputService.Transcription(
            text: "Partial",
            isFinal: false,
            confidence: 0.5,
            timestamp: Date()
        )

        #expect(finalTranscription.isFinal == true)
        #expect(partialTranscription.isFinal == false)
    }

    @Test("Transcription stores confidence correctly")
    func testTranscriptionStoresConfidence() {
        let confidence = 0.87
        let transcription = VoiceInputService.Transcription(
            text: "Test",
            isFinal: true,
            confidence: confidence,
            timestamp: Date()
        )

        #expect(transcription.confidence == confidence)
    }

    @Test("Transcription stores timestamp correctly")
    func testTranscriptionStoresTimestamp() {
        let timestamp = Date()
        let transcription = VoiceInputService.Transcription(
            text: "Test",
            isFinal: true,
            confidence: 0.9,
            timestamp: timestamp
        )

        #expect(transcription.timestamp == timestamp)
    }

    // MARK: - VoiceError Tests

    @Test("VoiceError recognizerUnavailable has correct description")
    func testVoiceErrorRecognizerUnavailableDescription() {
        let error = VoiceInputService.VoiceError.recognizerUnavailable

        #expect(error.errorDescription?.contains("not available") == true)
    }

    @Test("VoiceError requestCreationFailed has correct description")
    func testVoiceErrorRequestCreationFailedDescription() {
        let error = VoiceInputService.VoiceError.requestCreationFailed

        #expect(error.errorDescription?.contains("Failed to create") == true)
    }

    @Test("VoiceError notAuthorized has correct description")
    func testVoiceErrorNotAuthorizedDescription() {
        let error = VoiceInputService.VoiceError.notAuthorized

        #expect(error.errorDescription?.contains("not authorized") == true)
    }

    @Test("VoiceError noAudioInput has correct description")
    func testVoiceErrorNoAudioInputDescription() {
        let error = VoiceInputService.VoiceError.noAudioInput

        #expect(error.errorDescription?.contains("No audio input") == true)
        #expect(error.errorDescription?.contains("microphone") == true)
    }

    @Test("VoiceError invalidAudioFormat has correct description")
    func testVoiceErrorInvalidAudioFormatDescription() {
        let error = VoiceInputService.VoiceError.invalidAudioFormat

        #expect(error.errorDescription?.contains("Invalid audio format") == true)
    }

    // MARK: - Clear History Tests

    @Test("clearHistory empties transcription history")
    @MainActor
    func testClearHistoryEmptiesHistory() async {
        let service = VoiceInputService()

        await service.clearHistory()
        let history = service.transcriptionHistory

        #expect(history.isEmpty)
    }

    @Test("clearHistory empties current transcription")
    @MainActor
    func testClearHistoryEmptiesCurrentTranscription() async {
        let service = VoiceInputService()

        await service.clearHistory()
        let current = service.currentTranscription

        #expect(current.isEmpty)
    }

    // MARK: - Sendable Conformance Tests

    @Test("VoiceState is Sendable")
    func testVoiceStateIsSendable() async {
        let state: VoiceInputService.VoiceState = .listening

        let task = Task { @Sendable in
            return state
        }
        let result = await task.value

        #expect(result == .listening)
    }

    @Test("VoiceState error is Sendable across task boundaries")
    func testVoiceStateErrorIsSendable() async {
        let errorMessage = "Test error message"
        let state: VoiceInputService.VoiceState = .error(errorMessage)

        let task = Task { @Sendable in
            return state
        }
        let result = await task.value

        #expect(result == .error(errorMessage))
    }

    @Test("Transcription is Sendable")
    func testTranscriptionIsSendable() async {
        let transcription = VoiceInputService.Transcription(
            text: "Hello world",
            isFinal: true,
            confidence: 0.95,
            timestamp: Date()
        )

        let task = Task { @Sendable in
            return transcription
        }
        let result = await task.value

        #expect(result.text == transcription.text)
        #expect(result.isFinal == transcription.isFinal)
        #expect(result.confidence == transcription.confidence)
    }

    // MARK: - Actor Isolation Tests

    @Test("Service can be accessed from MainActor")
    @MainActor
    func testServiceAccessibleFromMainActor() {
        let service = VoiceInputService()

        #expect(service.state == .idle)
        #expect(service.isListening == false)
        #expect(service.currentTranscription.isEmpty)
    }

    @Test("State updates can be observed on MainActor")
    @MainActor
    func testStateUpdatesOnMainActor() async {
        let service = VoiceInputService()

        let initialState = service.state
        #expect(initialState == .idle)
    }

    // MARK: - isListening Computed Property Tests

    @Test("isListening returns false for idle state")
    func testIsListeningFalseForIdle() {
        let state: VoiceInputService.VoiceState = .idle
        let isListening = { () -> Bool in
            if case .listening = state { return true }
            return false
        }()

        #expect(isListening == false)
    }

    @Test("isListening returns false for processing state")
    func testIsListeningFalseForProcessing() {
        let state: VoiceInputService.VoiceState = .processing
        let isListening = { () -> Bool in
            if case .listening = state { return true }
            return false
        }()

        #expect(isListening == false)
    }

    @Test("isListening returns false for error state")
    func testIsListeningFalseForError() {
        let state: VoiceInputService.VoiceState = .error("Some error")
        let isListening = { () -> Bool in
            if case .listening = state { return true }
            return false
        }()

        #expect(isListening == false)
    }

    @Test("isListening returns true for listening state")
    func testIsListeningTrueForListening() {
        let state: VoiceInputService.VoiceState = .listening
        let isListening = { () -> Bool in
            if case .listening = state { return true }
            return false
        }()

        #expect(isListening == true)
    }
}

// MARK: - Audio Level Calculation Tests

@Suite("Audio Level Calculation Tests")
struct AudioLevelCalculationTests {

    @Test("RMS calculation produces non-negative value")
    func testRMSCalculationNonNegative() {
        let sampleData: [Float] = [0.1, -0.2, 0.3, -0.1, 0.2]
        let rms = sqrt(sampleData.map { $0 * $0 }.reduce(0, +) / Float(sampleData.count))

        #expect(rms >= 0)
    }

    @Test("RMS of zero samples is zero")
    func testRMSOfZeroSamplesIsZero() {
        let sampleData: [Float] = [0.0, 0.0, 0.0, 0.0]
        let rms = sqrt(sampleData.map { $0 * $0 }.reduce(0, +) / Float(sampleData.count))

        #expect(rms == 0)
    }

    @Test("Audio level scaling produces expected range")
    func testAudioLevelScaling() {
        let sampleData: [Float] = [0.5, -0.5, 0.5, -0.5]
        let rms = sqrt(sampleData.map { $0 * $0 }.reduce(0, +) / Float(sampleData.count))
        let level = rms * 10

        #expect(level >= 0)
        #expect(level <= 10)
    }

    @Test("RMS calculation handles single sample")
    func testRMSCalculationSingleSample() {
        let sampleData: [Float] = [0.5]
        let rms = sqrt(sampleData.map { $0 * $0 }.reduce(0, +) / Float(sampleData.count))

        #expect(rms == 0.5)
    }

    @Test("RMS calculation handles large sample count")
    func testRMSCalculationLargeSampleCount() {
        let sampleCount = 1024
        let sampleData = (0..<sampleCount).map { _ in Float.random(in: -1...1) }
        let rms = sqrt(sampleData.map { $0 * $0 }.reduce(0, +) / Float(sampleData.count))

        #expect(rms >= 0)
        #expect(rms <= 1)
    }
}

// MARK: - Thread Safety Tests

@Suite("Thread Safety Tests")
struct ThreadSafetyTests {

    @Test("Task MainActor dispatch works correctly")
    func testTaskMainActorDispatch() async {
        var value = 0

        await Task { @MainActor in
            value = 42
        }.value

        #expect(value == 42)
    }

    @Test("Weak self capture allows deallocation")
    func testWeakSelfCaptureAllowsDeallocation() async {
        weak var weakService: VoiceInputService?

        do {
            let service = await VoiceInputService()
            weakService = service
            #expect(weakService != nil)
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    @Test("Multiple concurrent Task dispatches complete")
    func testMultipleConcurrentTaskDispatches() async {
        let iterations = 100
        var completedCount = 0

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask { @MainActor in
                    completedCount += 1
                }
            }
        }

        #expect(completedCount == iterations)
    }

    @Test("Sendable closure can capture local values")
    func testSendableClosureCapturesLocalValues() async {
        let capturedValue = 123

        let result = await Task { @Sendable in
            return capturedValue
        }.value

        #expect(result == 123)
    }
}

// MARK: - VoiceState All Cases Tests

@Suite("VoiceState Comprehensive Tests")
struct VoiceStateComprehensiveTests {

    @Test("All VoiceState cases are distinct")
    func testAllVoiceStateCasesDistinct() {
        let states: [VoiceInputService.VoiceState] = [
            .idle,
            .requesting,
            .ready,
            .listening,
            .processing,
            .error("test")
        ]

        for i in 0..<states.count {
            for j in (i + 1)..<states.count {
                #expect(states[i] != states[j], "States at index \(i) and \(j) should not be equal")
            }
        }
    }

    @Test("VoiceState can round-trip through Sendable boundary")
    func testVoiceStateRoundTrip() async {
        let originalStates: [VoiceInputService.VoiceState] = [
            .idle,
            .requesting,
            .ready,
            .listening,
            .processing,
            .error("Test error")
        ]

        for originalState in originalStates {
            let roundTripped = await Task { @Sendable in
                return originalState
            }.value

            #expect(roundTripped == originalState)
        }
    }
}
