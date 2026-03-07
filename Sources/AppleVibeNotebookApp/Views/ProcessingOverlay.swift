import SwiftUI

struct ProcessingOverlay: View {
    @Environment(AppState.self) private var appState
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .blur(radius: 2)

            // Processing card
            NeonLiquidGlass(
                cornerRadius: 32,
                neonColors: progressColors,
                glowIntensity: 1.2
            ) {
                VStack(spacing: 24) {
                    // Animated progress ring
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 6)
                            .frame(width: 80, height: 80)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: appState.processingProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [.cyan, .white, .purple, .cyan],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        // Rotating glow indicator
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 12, height: 12)
                            .blur(radius: 4)
                            .offset(y: -40)
                            .rotationEffect(.degrees(rotationAngle))

                        // Center icon
                        Image(systemName: processingIcon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .white],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(pulseScale)
                    }

                    VStack(spacing: 8) {
                        Text(appState.processingStatus)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("\(Int(appState.processingProgress * 100))%")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .white, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * appState.processingProgress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: appState.processingProgress)
                        }
                    }
                    .frame(height: 8)
                    .frame(maxWidth: 200)
                }
                .padding(40)
            }
            .frame(width: 300, height: 280)
        }
        .onAppear {
            startAnimations()
        }
    }

    private var progressColors: [Color] {
        if appState.processingProgress < 0.33 {
            return [.cyan, .cyan.opacity(0.8), .white.opacity(0.6), .cyan]
        } else if appState.processingProgress < 0.66 {
            return [.cyan, .white, .cyan]
        } else {
            return [.cyan, .white, .purple, .cyan]
        }
    }

    private var processingIcon: String {
        if appState.processingProgress < 0.3 {
            return "magnifyingglass"
        } else if appState.processingProgress < 0.6 {
            return "doc.text.magnifyingglass"
        } else if appState.processingProgress < 0.9 {
            return "hammer.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.08, blue: 0.12)
            .ignoresSafeArea()

        ProcessingOverlay()
            .environment({
                let state = AppState()
                state.processingStatus = "Parsing React components..."
                state.processingProgress = 0.45
                return state
            }())
    }
}
