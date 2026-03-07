import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("accessLevel") private var accessLevel = "public"
    @AppStorage("generatePreviews") private var generatePreviews = true
    @AppStorage("generateDocumentation") private var generateDocumentation = true
    @AppStorage("indentWidth") private var indentWidth = 4

    var body: some View {
        TabView {
            GeneralSettingsView(
                accessLevel: $accessLevel,
                generatePreviews: $generatePreviews,
                generateDocumentation: $generateDocumentation,
                indentWidth: $indentWidth
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            MappingSettingsView()
                .tabItem {
                    Label("Mappings", systemImage: "arrow.triangle.2.circlepath")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @Binding var accessLevel: String
    @Binding var generatePreviews: Bool
    @Binding var generateDocumentation: Bool
    @Binding var indentWidth: Int

    var body: some View {
        Form {
            Section("Code Generation") {
                Picker("Access Level", selection: $accessLevel) {
                    Text("Public").tag("public")
                    Text("Internal").tag("internal")
                    Text("Private").tag("private")
                }

                Stepper("Indent Width: \(indentWidth)", value: $indentWidth, in: 2...8)

                Toggle("Generate Preview Providers", isOn: $generatePreviews)

                Toggle("Generate Documentation", isOn: $generateDocumentation)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct MappingSettingsView: View {
    var body: some View {
        Form {
            Section("User Corrections") {
                Text("Custom mappings you've defined will appear here")
                    .foregroundStyle(.secondary)
            }

            Section("Actions") {
                Button("Reset All Mappings") {
                    // Reset mappings
                }
                .foregroundStyle(.red)

                Button("Export Mappings...") {
                    // Export mappings
                }

                Button("Import Mappings...") {
                    // Import mappings
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("AppleVibeNotebook")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundStyle(.secondary)

            Text("Convert React & CSS projects to native SwiftUI code with deterministic mappings and live preview.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Text("Built with ❤️ for Apple Silicon")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
