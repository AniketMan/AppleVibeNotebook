import SwiftUI
import Speech

// MARK: - Liquid Glass Companion (Voice Input UI)
// Per TECHNICAL_SPEC.md Section 4.1:
// "The voice interface is embodied as a Liquid Glass orb — a living, breathing,
// translucent blob that floats on the screen. It is not a static microphone button.
// It has personality. It has a life of its own."

struct LiquidGlassCompanion: View {
    @Environment(AppState.self) private var appState
    @StateObject private var voiceService = VoiceInputService()
    @State private var aiService = AICodeSuggestionService()

    // Orb state
    @State private var isListening = false
    @State private var isProcessing = false
    @State private var audioLevel: CGFloat = 0
    @State private var transcript = ""
    @State private var aiResponse = ""
    @State private var showResponse = false
    @State private var showTextInput = false
    @State private var textInputValue = ""
    @State private var errorMessage = ""

    // Position (draggable per spec)
    @State private var orbPosition: CGPoint = CGPoint(x: 80, y: 120)
    @State private var dragOffset: CGSize = .zero

    // Animation phases
    @State private var breathePhase: Double = 0
    @State private var glowPhase: Double = 0
    @State private var pulsePhase: Double = 0

    // Orb size
    private let orbSize: CGFloat = 64

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Response bubble (when AI responds)
                if showResponse && !aiResponse.isEmpty {
                    responseBubble
                        .position(
                            x: min(orbPosition.x + 140, geometry.size.width - 160),
                            y: orbPosition.y
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                // Text input panel (fallback for voice)
                if showTextInput {
                    textInputPanel
                        .position(
                            x: min(orbPosition.x + 180, geometry.size.width - 180),
                            y: orbPosition.y
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                // The Liquid Glass Orb
                liquidGlassOrb
                    .position(
                        x: orbPosition.x + dragOffset.width,
                        y: orbPosition.y + dragOffset.height
                    )
                    .gesture(dragGesture(in: geometry))
                    .onTapGesture {
                        handleOrbTap()
                    }
                    .onLongPressGesture {
                        // Long press shows text input as fallback
                        withAnimation(.spring(response: 0.3)) {
                            showTextInput.toggle()
                            showResponse = false
                        }
                    }
            }
        }
        .onAppear {
            startIdleAnimations()
        }
    }

    // MARK: - Liquid Glass Orb

    private var liquidGlassOrb: some View {
        ZStack {
            // Outer glow (audio reactive)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            orbGlowColor.opacity(0.6 * audioReactiveScale),
                            orbGlowColor.opacity(0.2 * audioReactiveScale),
                            .clear
                        ],
                        center: .center,
                        startRadius: orbSize * 0.4,
                        endRadius: orbSize * 1.2
                    )
                )
                .frame(width: orbSize * 2.5, height: orbSize * 2.5)
                .blur(radius: 10)

            // Main orb body with glass effect
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: orbSize * breatheScale, height: orbSize * breatheScale)
                .overlay(
                    // Inner gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    orbGlowColor.opacity(0.2),
                                    .clear
                                ],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: orbSize * 0.5
                            )
                        )
                )
                .overlay(
                    // Neon edge glow
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: neonColors,
                                center: .center,
                                startAngle: .degrees(glowPhase * 360),
                                endAngle: .degrees(glowPhase * 360 + 360)
                            ),
                            lineWidth: isListening ? 3 : 1.5
                        )
                        .blur(radius: isListening ? 4 : 2)
                )
                .shadow(color: orbGlowColor.opacity(0.5), radius: isListening ? 20 : 10)

            // Microphone icon / waveform
            if isListening {
                // Waveform visualization when listening
                waveformView
            } else if isProcessing {
                // Processing indicator
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(0.8)
            } else {
                // Microphone icon when idle
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .opacity(0.9)
            }
        }
        .scaleEffect(isListening ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isListening)
    }

    // MARK: - Waveform View (audio reactive)

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: 4, height: waveformHeight(for: i))
                    .animation(
                        .easeInOut(duration: 0.15).delay(Double(i) * 0.05),
                        value: audioLevel
                    )
            }
        }
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxAdditional: CGFloat = 20
        let phase = sin(Double(index) * 0.8 + pulsePhase * 10)
        return baseHeight + maxAdditional * audioLevel * CGFloat(0.5 + 0.5 * phase)
    }

    // MARK: - Response Bubble

    private var responseBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Response")
                    .font(.caption.bold())
                Spacer()
                Button {
                    withAnimation {
                        showResponse = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Text(aiResponse)
                .font(.callout)
                .lineLimit(6)
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10)
    }

    // MARK: - Text Input Panel (Fallback for Voice)

    private var textInputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(.blue)
                Text("Text Input")
                    .font(.caption.bold())
                Spacer()
                Button {
                    withAnimation {
                        showTextInput = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Describe what you want to build...", text: $textInputValue, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .lineLimit(3...6)

            HStack {
                Text("Long-press orb for text mode")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if !textInputValue.isEmpty {
                        processWithAI(textInputValue)
                        showTextInput = false
                        textInputValue = ""
                    }
                } label: {
                    Label("Generate", systemImage: "sparkles")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(textInputValue.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10)
    }

    // MARK: - Gesture

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                // Update position and reset offset
                let newX = orbPosition.x + value.translation.width
                let newY = orbPosition.y + value.translation.height

                // Keep within bounds
                orbPosition.x = min(max(orbSize, newX), geometry.size.width - orbSize)
                orbPosition.y = min(max(orbSize, newY), geometry.size.height - orbSize)
                dragOffset = .zero
            }
    }

    // MARK: - Actions

    private func handleOrbTap() {
        if showTextInput {
            // Close text input if open
            withAnimation(.spring(response: 0.3)) {
                showTextInput = false
            }
            return
        }

        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        Task { @MainActor in
            do {
                let authorized = await voiceService.requestAuthorization()
                guard authorized else {
                    // Show text input as fallback
                    withAnimation(.spring(response: 0.3)) {
                        showTextInput = true
                        aiResponse = "Voice unavailable. Use text input instead (long-press orb)."
                        showResponse = true
                    }
                    return
                }

                try voiceService.startListening()
                withAnimation(.spring(response: 0.3)) {
                    isListening = true
                }
                startAudioLevelSimulation()
            } catch {
                // Microphone/audio errors - show text input fallback
                print("Voice error: \(error.localizedDescription)")
                withAnimation(.spring(response: 0.3)) {
                    showTextInput = true
                    aiResponse = "Microphone unavailable: \(error.localizedDescription)\n\nUse text input instead."
                    showResponse = true
                }
            }
        }
    }

    private func stopListening() {
        voiceService.stopListening()
        withAnimation(.spring(response: 0.3)) {
            isListening = false
        }

        // Get transcript and process with AI
        let finalTranscript = voiceService.currentTranscription
        if !finalTranscript.isEmpty {
            processWithAI(finalTranscript)
        }
    }

    private func processWithAI(_ input: String) {
        withAnimation(.spring(response: 0.3)) {
            isProcessing = true
            showResponse = false
        }

        Task { @MainActor in
            do {
                let suggestion = try await aiService.suggest(
                    code: input,
                    type: .completion,
                    context: "User voice command for UI generation"
                )
                withAnimation(.spring(response: 0.3)) {
                    aiResponse = suggestion.suggestedCode.isEmpty ? suggestion.explanation : suggestion.suggestedCode
                    showResponse = true
                    isProcessing = false
                }
            } catch {
                withAnimation(.spring(response: 0.3)) {
                    aiResponse = "AI Error: \(error.localizedDescription)"
                    showResponse = true
                    isProcessing = false
                }
            }
        }
    }

    // MARK: - Animations

    private func startIdleAnimations() {
        // Breathing animation (gentle scale)
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breathePhase = 1
        }

        // Glow rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            glowPhase = 1
        }

        // Pulse for audio
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            pulsePhase += 0.05
        }
    }

    private func startAudioLevelSimulation() {
        // Simulate audio levels (in real app, use actual audio metering)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isListening {
                // Simulate varying audio levels
                audioLevel = CGFloat.random(in: 0.2...1.0)
            } else {
                audioLevel = 0
                timer.invalidate()
            }
        }
    }

    // MARK: - Computed Properties

    private var breatheScale: CGFloat {
        1.0 + 0.05 * sin(breathePhase * .pi)
    }

    private var audioReactiveScale: CGFloat {
        isListening ? (0.5 + audioLevel * 0.5) : 0.3
    }

    private var orbGlowColor: Color {
        if isProcessing {
            return .purple
        } else if isListening {
            return .cyan
        } else {
            return .blue
        }
    }

    private var neonColors: [Color] {
        if isListening {
            return [.cyan, .white, .cyan, .white, .cyan]
        } else if isProcessing {
            return [.purple, .white, .purple, .white, .purple]
        } else {
            return [.blue.opacity(0.5), .white.opacity(0.3), .blue.opacity(0.5)]
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LiquidGlassCompanion()
            .environment(AppState())
    }
}
