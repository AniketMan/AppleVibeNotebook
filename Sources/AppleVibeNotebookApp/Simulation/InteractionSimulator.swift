import Foundation
import SwiftUI
import AppleVibeNotebook

// MARK: - Interaction Simulator

/// Simulates user interactions (tap, scroll, navigate) on canvas previews.
/// Records interaction sequences for testing and demonstration.
@Observable @MainActor
final class InteractionSimulator {

    // MARK: - State

    var isRecording: Bool = false
    var isPlaying: Bool = false
    var currentPlaybackIndex: Int = 0
    var recordedSequence: InteractionSequence?

    // MARK: - Configuration

    var playbackSpeed: PlaybackSpeed = .normal
    var showTouchIndicators: Bool = true
    var showNavigationOverlay: Bool = true

    // MARK: - Runtime

    private var playbackTask: Task<Void, Never>?
    private var touchIndicators: [TouchIndicator] = []

    // MARK: - Recording

    func startRecording() {
        isRecording = true
        recordedSequence = InteractionSequence(
            name: "Recording \(Date().formatted(.dateTime))",
            interactions: []
        )
    }

    func stopRecording() {
        isRecording = false
    }

    func recordInteraction(_ interaction: SimulatedInteraction) {
        guard isRecording else { return }
        recordedSequence?.interactions.append(interaction)
    }

    // MARK: - Playback

    func play(sequence: InteractionSequence, on canvasState: CanvasState) {
        guard !isPlaying else { return }

        isPlaying = true
        currentPlaybackIndex = 0

        playbackTask = Task { @MainActor in
            for (index, interaction) in sequence.interactions.enumerated() {
                guard !Task.isCancelled else { break }

                currentPlaybackIndex = index

                // Show touch indicator
                if showTouchIndicators {
                    await showTouchIndicator(at: interaction.location)
                }

                // Execute interaction
                await executeInteraction(interaction, on: canvasState)

                // Wait for next interaction
                let delay = interaction.delay / playbackSpeed.multiplier
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            isPlaying = false
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        touchIndicators.removeAll()
    }

    func pausePlayback() {
        // Implementation would pause the current task
    }

    func stepForward(on canvasState: CanvasState) {
        guard let sequence = recordedSequence,
              currentPlaybackIndex < sequence.interactions.count - 1 else { return }

        currentPlaybackIndex += 1
        let interaction = sequence.interactions[currentPlaybackIndex]

        Task { @MainActor in
            await executeInteraction(interaction, on: canvasState)
        }
    }

    func stepBackward(on canvasState: CanvasState) {
        guard currentPlaybackIndex > 0 else { return }

        currentPlaybackIndex -= 1
        // Note: Stepping backward would require state snapshots
    }

    // MARK: - Interaction Execution

    @MainActor
    private func executeInteraction(_ interaction: SimulatedInteraction, on canvasState: CanvasState) async {
        switch interaction.type {
        case .tap:
            executeTap(at: interaction.location, on: canvasState)

        case .doubleTap:
            executeTap(at: interaction.location, on: canvasState)
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            executeTap(at: interaction.location, on: canvasState)

        case .longPress:
            executeTap(at: interaction.location, on: canvasState)
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        case .swipe(let direction):
            await executeSwipe(from: interaction.location, direction: direction, on: canvasState)

        case .scroll(let delta):
            executeScroll(at: interaction.location, delta: delta, on: canvasState)

        case .pinch(let scale):
            executePinch(at: interaction.location, scale: scale, on: canvasState)

        case .drag(let endPoint):
            await executeDrag(from: interaction.location, to: endPoint, on: canvasState)
        }
    }

    private func executeTap(at location: CGPoint, on canvasState: CanvasState) {
        if let layer = canvasState.hitTest(at: location) {
            canvasState.selectLayer(layer.id)
        } else {
            canvasState.deselectAll()
        }
    }

    @MainActor
    private func executeSwipe(from start: CGPoint, direction: SwipeDirection, on canvasState: CanvasState) async {
        let distance: CGFloat = 200
        let endPoint: CGPoint

        switch direction {
        case .up:
            endPoint = CGPoint(x: start.x, y: start.y - distance)
        case .down:
            endPoint = CGPoint(x: start.x, y: start.y + distance)
        case .left:
            endPoint = CGPoint(x: start.x - distance, y: start.y)
        case .right:
            endPoint = CGPoint(x: start.x + distance, y: start.y)
        }

        await executeDrag(from: start, to: endPoint, on: canvasState)
    }

    private func executeScroll(at location: CGPoint, delta: CGPoint, on canvasState: CanvasState) {
        canvasState.pan(by: delta)
    }

    private func executePinch(at location: CGPoint, scale: CGFloat, on canvasState: CanvasState) {
        canvasState.zoom(to: canvasState.document.viewport.scale * scale, anchor: location)
    }

    @MainActor
    private func executeDrag(from start: CGPoint, to end: CGPoint, on canvasState: CanvasState) async {
        let steps = 10
        let stepDuration: UInt64 = 20_000_000 // 20ms per step

        for i in 0...steps {
            let progress = CGFloat(i) / CGFloat(steps)
            let currentPoint = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )

            if showTouchIndicators {
                updateTouchIndicator(at: currentPoint)
            }

            try? await Task.sleep(nanoseconds: stepDuration)
        }
    }

    // MARK: - Touch Indicators

    @MainActor
    private func showTouchIndicator(at location: CGPoint) async {
        let indicator = TouchIndicator(location: location)
        touchIndicators.append(indicator)

        // Animate appearance
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        // Remove indicator
        touchIndicators.removeAll { $0.id == indicator.id }
    }

    private func updateTouchIndicator(at location: CGPoint) {
        if let lastIndicator = touchIndicators.last {
            touchIndicators.removeAll { $0.id == lastIndicator.id }
        }
        touchIndicators.append(TouchIndicator(location: location))
    }
}

// MARK: - Supporting Types

struct InteractionSequence: Identifiable, Codable {
    let id = UUID()
    var name: String
    var interactions: [SimulatedInteraction]
    var createdAt: Date = Date()

    var duration: TimeInterval {
        interactions.reduce(0) { $0 + $1.delay }
    }
}

struct SimulatedInteraction: Identifiable, Codable {
    let id = UUID()
    let type: InteractionTypeSimulated
    let location: CGPoint
    let delay: TimeInterval  // Delay before this interaction
    var layerID: UUID?

    init(type: InteractionTypeSimulated, location: CGPoint, delay: TimeInterval = 0.5, layerID: UUID? = nil) {
        self.type = type
        self.location = location
        self.delay = delay
        self.layerID = layerID
    }
}

enum InteractionTypeSimulated: Codable {
    case tap
    case doubleTap
    case longPress
    case swipe(SwipeDirection)
    case scroll(CGPoint)
    case pinch(CGFloat)
    case drag(CGPoint)
}

enum SwipeDirection: String, Codable, CaseIterable {
    case up, down, left, right

    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }
}

enum PlaybackSpeed: Double, CaseIterable {
    case slow = 0.5
    case normal = 1.0
    case fast = 2.0
    case veryFast = 4.0

    var multiplier: Double { rawValue }

    var label: String {
        switch self {
        case .slow: return "0.5x"
        case .normal: return "1x"
        case .fast: return "2x"
        case .veryFast: return "4x"
        }
    }
}

struct TouchIndicator: Identifiable {
    let id = UUID()
    let location: CGPoint
    let timestamp = Date()
}

// MARK: - Touch Indicator View

struct TouchIndicatorView: View {
    let indicator: TouchIndicator

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.5))
            .frame(width: 60, height: 60)
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .position(indicator.location)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }
                withAnimation(.easeIn(duration: 0.2).delay(0.1)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Interaction Recorder View

struct InteractionRecorderView: View {
    @Bindable var simulator: InteractionSimulator

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Interaction Recorder")
                    .font(.headline)

                Spacer()

                // Recording indicator
                if simulator.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Recording")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()

            Divider()

            // Controls
            HStack(spacing: 12) {
                // Record button
                Button {
                    if simulator.isRecording {
                        simulator.stopRecording()
                    } else {
                        simulator.startRecording()
                    }
                } label: {
                    Image(systemName: simulator.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 24))
                        .foregroundColor(simulator.isRecording ? .red : .primary)
                }
                .buttonStyle(.plain)

                // Play button
                Button {
                    if simulator.isPlaying {
                        simulator.stopPlayback()
                    } else if let sequence = simulator.recordedSequence {
                        // Would need canvasState passed in
                    }
                } label: {
                    Image(systemName: simulator.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
                .disabled(simulator.recordedSequence == nil)

                Spacer()

                // Playback speed
                Picker("Speed", selection: $simulator.playbackSpeed) {
                    ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .frame(width: 80)
            }
            .padding()

            Divider()

            // Interaction list
            if let sequence = simulator.recordedSequence {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(sequence.interactions.enumerated()), id: \.element.id) { index, interaction in
                            InteractionRowView(
                                interaction: interaction,
                                index: index,
                                isCurrentlyPlaying: simulator.isPlaying && index == simulator.currentPlaybackIndex
                            )
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No Interactions Recorded")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Press record and interact with the canvas")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 280)
        .background(Color(white: 0.15))
    }
}

struct InteractionRowView: View {
    let interaction: SimulatedInteraction
    let index: Int
    let isCurrentlyPlaying: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Index
            Text("\(index + 1)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 24)

            // Icon
            Image(systemName: iconForType)
                .foregroundColor(isCurrentlyPlaying ? .accentColor : .secondary)

            // Type
            Text(labelForType)
                .font(.system(size: 12))

            Spacer()

            // Location
            Text("(\(Int(interaction.location.x)), \(Int(interaction.location.y)))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrentlyPlaying ? Color.accentColor.opacity(0.2) : Color.clear)
        )
    }

    private var iconForType: String {
        switch interaction.type {
        case .tap: return "hand.tap"
        case .doubleTap: return "hand.tap.fill"
        case .longPress: return "hand.point.up.left"
        case .swipe: return "hand.draw"
        case .scroll: return "scroll"
        case .pinch: return "arrow.up.left.and.arrow.down.right"
        case .drag: return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    private var labelForType: String {
        switch interaction.type {
        case .tap: return "Tap"
        case .doubleTap: return "Double Tap"
        case .longPress: return "Long Press"
        case .swipe(let direction): return "Swipe \(direction.rawValue.capitalized)"
        case .scroll: return "Scroll"
        case .pinch(let scale): return "Pinch \(scale > 1 ? "Out" : "In")"
        case .drag: return "Drag"
        }
    }
}

// MARK: - Preview

#Preview {
    InteractionRecorderView(simulator: InteractionSimulator())
}
