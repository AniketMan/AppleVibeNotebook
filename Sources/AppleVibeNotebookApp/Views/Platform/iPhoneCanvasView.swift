import SwiftUI
import Speech
import AVFoundation
import AppleVibeNotebook

#if os(iOS)
@Observable @MainActor
public final class VoiceCaptureEngine {
    public var isListening: Bool = false
    public var transcript: String = ""
    public var partialTranscript: String = ""
    public var confidenceLevel: Float = 0.0
    public var error: VoiceCaptureError?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    public init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    public func startListening() async throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceCaptureError.recognizerUnavailable
        }

        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw VoiceCaptureError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.partialTranscript = result.bestTranscription.formattedString

                if result.isFinal {
                    self.transcript = result.bestTranscription.formattedString
                    if let segment = result.bestTranscription.segments.last {
                        self.confidenceLevel = segment.confidence
                    }
                }
            }

            if let error {
                self.error = .recognitionFailed(error.localizedDescription)
                self.stopListening()
            }
        }
    }

    public func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    public func reset() {
        transcript = ""
        partialTranscript = ""
        confidenceLevel = 0.0
        error = nil
    }
}

public enum VoiceCaptureError: Error, LocalizedError {
    case recognizerUnavailable
    case requestCreationFailed
    case recognitionFailed(String)
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        case .recognitionFailed(let message):
            return "Recognition failed: \(message)"
        case .notAuthorized:
            return "Speech recognition not authorized"
        }
    }
}

public struct VoiceCommand: Identifiable {
    public let id = UUID()
    public let phrase: String
    public let intent: VoiceIntent
    public let confidence: Float
    public let timestamp: Date

    public init(phrase: String, intent: VoiceIntent, confidence: Float = 1.0) {
        self.phrase = phrase
        self.intent = intent
        self.confidence = confidence
        self.timestamp = Date()
    }
}

public enum VoiceIntent {
    case createComponent(String)
    case setProperty(property: String, value: String)
    case changeColor(String)
    case resize(width: Double?, height: Double?)
    case move(direction: Direction)
    case duplicate
    case delete
    case group
    case ungroup
    case undo
    case redo
    case save
    case preview
    case unknown

    public enum Direction {
        case up, down, left, right
    }
}

@Observable
public final class VoiceCommandParser {

    private let colorKeywords = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white", "gray", "grey"]
    private let componentKeywords = ["button", "text", "image", "card", "stack", "vstack", "hstack", "zstack", "toggle", "slider", "textfield", "input", "label", "icon"]
    private let directionKeywords = ["up", "down", "left", "right"]

    public init() {}

    public func parse(_ transcript: String) -> VoiceIntent {
        let lowercased = transcript.lowercased()
        let words = lowercased.split(separator: " ").map(String.init)

        if lowercased.contains("undo") {
            return .undo
        }

        if lowercased.contains("redo") {
            return .redo
        }

        if lowercased.contains("save") {
            return .save
        }

        if lowercased.contains("preview") || lowercased.contains("simulate") || lowercased.contains("run") {
            return .preview
        }

        if lowercased.contains("delete") || lowercased.contains("remove") {
            return .delete
        }

        if lowercased.contains("duplicate") || lowercased.contains("copy") {
            return .duplicate
        }

        if lowercased.contains("group") && !lowercased.contains("ungroup") {
            return .group
        }

        if lowercased.contains("ungroup") {
            return .ungroup
        }

        if lowercased.contains("add") || lowercased.contains("create") || lowercased.contains("insert") {
            for component in componentKeywords {
                if lowercased.contains(component) {
                    return .createComponent(component.capitalized)
                }
            }
        }

        if lowercased.contains("make it") || lowercased.contains("change to") || lowercased.contains("set color") {
            for color in colorKeywords {
                if lowercased.contains(color) {
                    return .changeColor(color)
                }
            }
        }

        for color in colorKeywords where lowercased.contains(color) && (lowercased.contains("color") || lowercased.contains("background")) {
            return .changeColor(color)
        }

        if lowercased.contains("move") {
            for direction in directionKeywords {
                if lowercased.contains(direction) {
                    let dir: VoiceIntent.Direction
                    switch direction {
                    case "up": dir = .up
                    case "down": dir = .down
                    case "left": dir = .left
                    case "right": dir = .right
                    default: continue
                    }
                    return .move(direction: dir)
                }
            }
        }

        if lowercased.contains("resize") || lowercased.contains("size") || lowercased.contains("width") || lowercased.contains("height") {
            let numbers = words.compactMap { Double($0) }
            if numbers.count >= 2 {
                return .resize(width: numbers[0], height: numbers[1])
            } else if numbers.count == 1 {
                if lowercased.contains("width") {
                    return .resize(width: numbers[0], height: nil)
                } else {
                    return .resize(width: nil, height: numbers[0])
                }
            }
        }

        return .unknown
    }
}

public struct iPhoneCanvasView: View {
    @Bindable var canvasState: CanvasState
    @State private var voiceEngine = VoiceCaptureEngine()
    @State private var voiceParser = VoiceCommandParser()
    @State private var isVoiceMode = false
    @State private var commandHistory: [VoiceCommand] = []
    @State private var showVoiceOverlay = false
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    init(canvasState: CanvasState) {
        self.canvasState = canvasState
    }

    public var body: some View {
        ZStack {
            InfiniteCanvasView(canvasState: canvasState)

            VStack {
                Spacer()

                if showVoiceOverlay {
                    voiceTranscriptOverlay
                }

                bottomControls
            }

            if isVoiceMode {
                pulsingVoiceIndicator
            }
        }
        .onAppear {
            hapticFeedback.prepare()
        }
    }

    private var voiceTranscriptOverlay: some View {
        VStack(spacing: 12) {
            if !voiceEngine.partialTranscript.isEmpty {
                Text(voiceEngine.partialTranscript)
                    .font(.title3.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !commandHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(commandHistory.suffix(5)) { command in
                            CommandHistoryChip(command: command)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var bottomControls: some View {
        HStack(spacing: 24) {
            toolSelector

            Spacer()

            voiceCaptureButton

            Spacer()

            quickActionsMenu
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    private var toolSelector: some View {
        Menu {
            ForEach([CanvasTool.select, .hand, .pencil, .text, .rectangle], id: \.self) { tool in
                Button {
                    hapticFeedback.impactOccurred()
                } label: {
                    Label(tool.rawValue, systemImage: tool.icon)
                }
            }
        } label: {
            Image(systemName: CanvasTool.select.icon)
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.quaternary))
        }
    }

    private var voiceCaptureButton: some View {
        Button {
            Task {
                await toggleVoiceCapture()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isVoiceMode ? Color.red : Color.accentColor)
                    .frame(width: 72, height: 72)

                if isVoiceMode {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 3)
                        .frame(width: 88, height: 88)
                        .scaleEffect(isVoiceMode ? 1.2 : 1.0)
                        .opacity(isVoiceMode ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: isVoiceMode)
                }

                Image(systemName: isVoiceMode ? "stop.fill" : "mic.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isVoiceMode ? "Stop voice capture" : "Start voice capture")
    }

    private var quickActionsMenu: some View {
        Menu {
            Button {
                canvasState.undo()
                hapticFeedback.impactOccurred()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!canvasState.canUndo)

            Button {
                canvasState.redo()
                hapticFeedback.impactOccurred()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!canvasState.canRedo)

            Divider()

            Button {
                // Preview action
            } label: {
                Label("Preview", systemImage: "play.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.quaternary))
        }
    }

    private var pulsingVoiceIndicator: some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Color.red)
                            .frame(width: 4, height: 16)
                            .scaleEffect(y: voiceEngine.isListening ? 1.5 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.1),
                                value: voiceEngine.isListening
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding()
            }
            Spacer()
        }
    }

    private func toggleVoiceCapture() async {
        if isVoiceMode {
            voiceEngine.stopListening()
            isVoiceMode = false

            if !voiceEngine.transcript.isEmpty {
                processVoiceCommand(voiceEngine.transcript)
            }

            withAnimation {
                showVoiceOverlay = false
            }
            voiceEngine.reset()
        } else {
            let authorized = await voiceEngine.requestAuthorization()
            guard authorized else {
                voiceEngine.error = .notAuthorized
                return
            }

            do {
                try await voiceEngine.startListening()
                isVoiceMode = true
                hapticFeedback.impactOccurred()

                withAnimation {
                    showVoiceOverlay = true
                }
            } catch {
                print("Voice capture failed: \(error)")
            }
        }
    }

    private func processVoiceCommand(_ transcript: String) {
        let intent = voiceParser.parse(transcript)
        let command = VoiceCommand(
            phrase: transcript,
            intent: intent,
            confidence: voiceEngine.confidenceLevel
        )
        commandHistory.append(command)

        executeCommand(intent)
        hapticFeedback.impactOccurred()
    }

    private func executeCommand(_ intent: VoiceIntent) {
        switch intent {
        case .createComponent(let name):
            let frame = CanvasFrame(
                origin: CGPoint(x: 100, y: 100),
                size: CGSize(width: 120, height: 44)
            )
            let layer = CanvasLayer(
                id: UUID(),
                name: name,
                frame: frame,
                zIndex: canvasState.document.layers.count,
                layerType: .element
            )
            canvasState.addLayer(layer)

        case .changeColor(let color):
            guard let layerId = canvasState.selectedLayerIDs.first,
                  var layer = canvasState.document.layers.first(where: { $0.id == layerId }) else { return }

            layer.backgroundFill = FillConfig(fillType: .solid, color: CanvasColor(colorName: color))
            canvasState.updateLayer(id: layerId) { $0 = layer }

        case .move(let direction):
            guard let layerId = canvasState.selectedLayerIDs.first,
                  var layer = canvasState.document.layers.first(where: { $0.id == layerId }) else { return }

            let offset: Double = 20
            switch direction {
            case .up: layer.frame.origin.y -= offset
            case .down: layer.frame.origin.y += offset
            case .left: layer.frame.origin.x -= offset
            case .right: layer.frame.origin.x += offset
            }
            canvasState.updateLayer(id: layerId) { $0 = layer }

        case .resize(let width, let height):
            guard let layerId = canvasState.selectedLayerIDs.first,
                  var layer = canvasState.document.layers.first(where: { $0.id == layerId }) else { return }

            if let w = width { layer.frame.size.width = w }
            if let h = height { layer.frame.size.height = h }
            canvasState.updateLayer(id: layerId) { $0 = layer }

        case .duplicate:
            canvasState.duplicateSelectedLayers()

        case .delete:
            canvasState.deleteSelectedLayers()

        case .group:
            canvasState.groupSelectedLayers()

        case .ungroup:
            // Ungroup not yet implemented - would need to track group membership
            break

        case .undo:
            canvasState.undo()

        case .redo:
            canvasState.redo()

        case .save, .preview, .setProperty, .unknown:
            break
        }
    }
}

private struct CommandHistoryChip: View {
    let command: VoiceCommand

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForIntent(command.intent))
                .font(.caption)

            Text(command.phrase)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary)
        .clipShape(Capsule())
    }

    private func iconForIntent(_ intent: VoiceIntent) -> String {
        switch intent {
        case .createComponent: return "plus.square"
        case .changeColor: return "paintpalette"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .resize: return "arrow.up.left.and.arrow.down.right"
        case .duplicate: return "plus.square.on.square"
        case .delete: return "trash"
        case .group: return "square.stack.3d.up"
        case .ungroup: return "square.stack.3d.down.right"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .save: return "square.and.arrow.down"
        case .preview: return "play"
        case .setProperty: return "slider.horizontal.3"
        case .unknown: return "questionmark"
        }
    }
}

extension CanvasColor {
    init(colorName: String) {
        switch colorName.lowercased() {
        case "red": self.init(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        case "blue": self.init(red: 0, green: 0.48, blue: 1, alpha: 1)
        case "green": self.init(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
        case "yellow": self.init(red: 1, green: 0.8, blue: 0, alpha: 1)
        case "orange": self.init(red: 1, green: 0.58, blue: 0, alpha: 1)
        case "purple": self.init(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)
        case "pink": self.init(red: 1, green: 0.18, blue: 0.33, alpha: 1)
        case "black": self.init(red: 0, green: 0, blue: 0, alpha: 1)
        case "white": self.init(red: 1, green: 1, blue: 1, alpha: 1)
        case "gray", "grey": self.init(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
        default: self.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        }
    }
}
#endif
