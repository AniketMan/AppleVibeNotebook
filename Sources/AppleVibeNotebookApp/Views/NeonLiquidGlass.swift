import SwiftUI

// MARK: - Neon Liquid Glass Effect
// Uses iOS 26+/macOS 26+ native .glassEffect() with inner neon glow

/// A SwiftUI view that creates a liquid glass effect with an inner neon glow.
/// Uses Apple's native `.glassEffect()` on iOS 26+/macOS 26+.
/// The key design: the neon glow goes INSIDE the glass, not outside.
public struct NeonLiquidGlass<Content: View>: View {
    let cornerRadius: CGFloat
    let neonColors: [Color]
    let glowIntensity: CGFloat
    let content: () -> Content

    @State private var animationPhase: Double = 0

    public init(
        cornerRadius: CGFloat = 32,
        neonColors: [Color] = [.cyan, .white, .purple, .cyan],
        glowIntensity: CGFloat = 1.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.neonColors = neonColors
        self.glowIntensity = glowIntensity
        self.content = content
    }

    public var body: some View {
        content()
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(innerNeonGlow) // Glow goes INSIDE
            .applyGlassEffect(cornerRadius: cornerRadius)
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    animationPhase = 1
                }
            }
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    // MARK: - Inner Neon Glow (KEY: Glow is INSIDE the glass)

    private var innerNeonGlow: some View {
        ZStack {
            // Inner gradient glow layer - widest, most diffuse
            RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                .strokeBorder(
                    innerNeonGradient,
                    lineWidth: 12 * glowIntensity
                )
                .blur(radius: 8 * glowIntensity)

            // Middle glow layer
            RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                .strokeBorder(
                    innerNeonGradient,
                    lineWidth: 6 * glowIntensity
                )
                .blur(radius: 4 * glowIntensity)

            // Inner bright core - sharp edge
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    innerNeonGradient,
                    lineWidth: 1.5
                )
                .blur(radius: 0.5)

            // Animated highlight shimmer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.8),
                            .clear,
                            .clear,
                            .clear,
                            .white.opacity(0.4),
                            .clear,
                            .clear,
                            .clear
                        ],
                        center: .center,
                        startAngle: .degrees(animationPhase * 360),
                        endAngle: .degrees(animationPhase * 360 + 360)
                    ),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Gradient

    private var innerNeonGradient: AngularGradient {
        AngularGradient(
            colors: neonColors,
            center: .center,
            startAngle: .degrees(animationPhase * 360),
            endAngle: .degrees(animationPhase * 360 + 360)
        )
    }
}

// MARK: - Native Glass Effect Extension

extension View {
    /// Applies native `.glassEffect()` on iOS 26+/macOS 26+
    /// Uses containerShape for corner radius as per Apple's Liquid Glass documentation
    @ViewBuilder
    func applyGlassEffect(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .containerShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .glassEffect()
        } else {
            self
        }
    }
}

// MARK: - Neon Liquid Glass Button

/// A button styled with the neon liquid glass effect.
public struct NeonLiquidGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            // Use native glass button style
            Button(action: action) {
                buttonContent
            }
            .buttonStyle(.glass)
        } else {
            // Fallback to custom implementation
            Button(action: action) {
                buttonContent
            }
            .buttonStyle(NeonGlassButtonStyle())
        }
    }

    private var buttonContent: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Fallback Button Style

struct NeonGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        NeonLiquidGlass(
            cornerRadius: 12,
            glowIntensity: configuration.isPressed ? 1.5 : 1.0
        ) {
            configuration.label
        }
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Neon Liquid Glass Card

/// A card container with the neon liquid glass effect.
public struct NeonLiquidGlassCard<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        NeonLiquidGlass(cornerRadius: 24) {
            content()
                .padding(20)
        }
    }
}

// MARK: - Neon Liquid Glass Panel

/// A larger panel with the neon liquid glass effect, suitable for main content areas.
public struct NeonLiquidGlassPanel<Content: View>: View {
    let title: String?
    let content: () -> Content

    public init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        NeonLiquidGlass(cornerRadius: 32, glowIntensity: 0.7) {
            VStack(alignment: .leading, spacing: 16) {
                if let title = title {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                content()
            }
            .padding(24)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies the neon liquid glass effect to any view.
    public func neonLiquidGlass(
        cornerRadius: CGFloat = 20,
        neonColors: [Color] = [.cyan, .white, .purple, .cyan],
        glowIntensity: CGFloat = 1.0
    ) -> some View {
        NeonLiquidGlass(
            cornerRadius: cornerRadius,
            neonColors: neonColors,
            glowIntensity: glowIntensity
        ) {
            self
        }
    }
}

// MARK: - Preview

#Preview("Neon Liquid Glass - Inner Glow") {
    ZStack {
        // Dark background
        Color.black
            .ignoresSafeArea()

        // Subtle background texture
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.12),
                Color(red: 0.02, green: 0.04, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 40) {
            // Main glass panel with inner glow
            NeonLiquidGlass(cornerRadius: 40) {
                VStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan)
                    Text("AppleVibeNotebook")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Canvas")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(40)
            }
            .frame(width: 280, height: 180)

            // Buttons row
            HStack(spacing: 20) {
                NeonLiquidGlassButton(title: "MIX", icon: "slider.horizontal.3") {}
                NeonLiquidGlassButton(title: "SELECT", icon: "checkmark.circle") {}
                NeonLiquidGlassButton(title: "MUTE", icon: "speaker.slash") {}
            }

            // Compact cards showing inner glow
            HStack(spacing: 16) {
                ForEach(0..<3) { i in
                    NeonLiquidGlass(
                        cornerRadius: 20,
                        neonColors: i == 0 ? [.cyan, .white, .cyan] :
                                   i == 1 ? [.purple, .white, .purple] :
                                           [.orange, .white, .orange],
                        glowIntensity: 0.8
                    ) {
                        VStack {
                            Image(systemName: ["music.note", "heart.fill", "star.fill"][i])
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 60, height: 60)
                    }
                }
            }
        }
    }
}
