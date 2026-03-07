import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateGlow = false

    private var glowColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var backgroundColor: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.08),
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.02, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(white: 0.96),
                    Color(white: 0.92),
                    Color(white: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            // Ambient glow spots
            Circle()
                .fill(glowColor.opacity(colorScheme == .dark ? 0.06 : 0.04))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: -150, y: -200)

            Circle()
                .fill(glowColor.opacity(colorScheme == .dark ? 0.04 : 0.03))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 200, y: 150)

            VStack(spacing: 50) {
                Spacer()

                // Main logo card with adaptive neon glow
                NeonLiquidGlass(
                    cornerRadius: 48,
                    neonColors: colorScheme == .dark
                        ? [.white.opacity(0.9), .white, .white.opacity(0.9)]
                        : [.black.opacity(0.6), .black.opacity(0.8), .black.opacity(0.6)],
                    glowIntensity: animateGlow ? 1.2 : 0.8
                ) {
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 72, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: colorScheme == .dark
                                        ? [.white.opacity(0.8), .white, .white.opacity(0.8)]
                                        : [.black.opacity(0.6), .black.opacity(0.9), .black.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.breathe, options: .repeating)

                        VStack(spacing: 8) {
                            Text("Apple Vibe")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? .white : .black)

                            Text("Notebook")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                        }
                    }
                    .padding(48)
                }
                .frame(width: 340, height: 280)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animateGlow = true
                    }
                }

                Text("Build SwiftUI & React apps with AI")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))

                // Action buttons
                VStack(spacing: 16) {
                    VibeActionButton(
                        title: "New Notebook",
                        subtitle: "Start building with AI assistance",
                        systemImage: "plus.rectangle.on.rectangle",
                        accentColor: glowColor,
                        colorScheme: colorScheme,
                        action: { appState.createNewNotebook() }
                    )

                    VibeActionButton(
                        title: "AI Code Assistant",
                        subtitle: "Generate SwiftUI or React from prompts",
                        systemImage: "sparkles",
                        accentColor: glowColor,
                        colorScheme: colorScheme,
                        action: { appState.showAIPanel = true }
                    )

                    Divider()
                        .background((colorScheme == .dark ? Color.white : Color.black).opacity(0.1))
                        .padding(.vertical, 8)

                    HStack(spacing: 12) {
                        VibeCompactButton(
                            title: "React → SwiftUI",
                            systemImage: "arrow.right",
                            colorScheme: colorScheme,
                            action: { appState.showImportPanel = true }
                        )

                        VibeCompactButton(
                            title: "SwiftUI → React",
                            systemImage: "arrow.left",
                            colorScheme: colorScheme,
                            action: { appState.showSwiftUIImportPanel = true }
                        )
                    }
                }
                .frame(maxWidth: 420)

                Spacer()

                // Feature badges
                VStack(spacing: 12) {
                    Text("Powered by Apple Intelligence & External AI Providers")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4))

                    HStack(spacing: 24) {
                        VibeFeatureBadge(icon: "apple.logo", text: "On-Device AI", colorScheme: colorScheme)
                        VibeFeatureBadge(icon: "globe", text: "Cloud Providers", colorScheme: colorScheme)
                        VibeFeatureBadge(icon: "eye", text: "Vision Models", colorScheme: colorScheme)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Vibe Action Button

struct VibeActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accentColor: Color
    var colorScheme: ColorScheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            NeonLiquidGlass(
                cornerRadius: 16,
                neonColors: isHovered
                    ? [accentColor, accentColor.opacity(0.8), accentColor]
                    : [accentColor.opacity(0.4), accentColor.opacity(0.2), accentColor.opacity(0.4)],
                glowIntensity: isHovered ? 1.2 : 0.5
            ) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(accentColor.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)

                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Vibe Compact Button

struct VibeCompactButton: View {
    let title: String
    let systemImage: String
    var colorScheme: ColorScheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            NeonLiquidGlass(
                cornerRadius: 12,
                neonColors: colorScheme == .dark
                    ? [.white.opacity(isHovered ? 0.6 : 0.2)]
                    : [.black.opacity(isHovered ? 0.4 : 0.15)],
                glowIntensity: isHovered ? 0.8 : 0.3
            ) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .medium))
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Vibe Feature Badge

struct VibeFeatureBadge: View {
    let icon: String
    let text: String
    var colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
        }
    }
}

#Preview("Dark Mode") {
    WelcomeView()
        .environment(AppState())
        .frame(width: 900, height: 700)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    WelcomeView()
        .environment(AppState())
        .frame(width: 900, height: 700)
        .preferredColorScheme(.light)
}
