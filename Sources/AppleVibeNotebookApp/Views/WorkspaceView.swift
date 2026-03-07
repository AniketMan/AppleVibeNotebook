import SwiftUI

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HSplitView {
            if appState.showCodePanel {
                CodePanelView()
                    .frame(minWidth: 300)
            }

            if appState.showPreviewPanel {
                PreviewPanelView()
                    .frame(minWidth: 300)
            }

            if appState.showReportPanel {
                ReportPanelView()
                    .frame(minWidth: 250)
            }

            if appState.showAIPanel {
                AISuggestionPanelView()
                    .frame(minWidth: 400, idealWidth: 500)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: Bindable(appState).showCodePanel) {
                    Image(systemName: "doc.text")
                }
                .help("Toggle Code Panel")

                Toggle(isOn: Bindable(appState).showPreviewPanel) {
                    Image(systemName: "eye")
                }
                .help("Toggle Preview Panel")

                Toggle(isOn: Bindable(appState).showReportPanel) {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                .help("Toggle Report Panel")

                Divider()

                Toggle(isOn: Bindable(appState).showAIPanel) {
                    Image(systemName: "sparkles")
                }
                .help("Toggle AI Assistant (⌘4)")
            }

            ToolbarItem {
                Button {
                    appState.showExportPanel = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(appState.generatedCode.isEmpty)
                .help("Export SwiftUI Code")
            }
        }
    }
}

struct CodePanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Generated Code")
                    .font(.headline)
                Spacer()
                if let file = appState.selectedGeneratedFile {
                    Text(file.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.bar)

            Divider()

            if let file = appState.selectedGeneratedFile {
                ScrollView {
                    Text(file.content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text",
                    description: Text("Select a generated file from the sidebar")
                )
            }
        }
        .background(.background)
    }
}

struct PreviewPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Live Preview")
                    .font(.headline)
                Spacer()

                Picker("Device", selection: .constant("iPhone 15 Pro")) {
                    Text("iPhone 15 Pro").tag("iPhone 15 Pro")
                    Text("iPad Pro").tag("iPad Pro")
                    Text("Mac").tag("Mac")
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            .padding()
            .background(.bar)

            Divider()

            if appState.generatedCode.isEmpty {
                ContentUnavailableView(
                    "No Preview Available",
                    systemImage: "eye.slash",
                    description: Text("Import a React project to see the preview")
                )
            } else {
                GeometryReader { geometry in
                    VStack {
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(.secondary.opacity(0.3), lineWidth: 8)
                            .background(
                                RoundedRectangle(cornerRadius: 36)
                                    .fill(.background)
                            )
                            .overlay {
                                VStack {
                                    Text("SwiftUI Preview")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)

                                    Text("Component preview will render here")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: min(geometry.size.width - 40, 300), height: min(geometry.size.height - 40, 600))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(white: 0.15))
    }
}

struct ReportPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversion Report")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.bar)

            Divider()

            if let report = appState.conversionReport {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Health Score")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ProgressView(value: report.healthPercentage / 100)
                                .tint(healthColor(for: report.healthPercentage))

                            Text("\(Int(report.healthPercentage))%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(healthColor(for: report.healthPercentage))
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Breakdown")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            StatRow(label: "Direct", count: report.directCount, color: .green)
                            StatRow(label: "Adapted", count: report.adaptedCount, color: .yellow)
                            StatRow(label: "Unsupported", count: report.unsupportedCount, color: .red)
                        }

                        Divider()

                        Button("Export Report") {
                            // Export markdown report
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "No Report",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Import a project to see the conversion report")
                )
            }
        }
        .background(.background)
    }

    private func healthColor(for percentage: Double) -> Color {
        switch percentage {
        case 80...: return .green
        case 50..<80: return .yellow
        default: return .red
        }
    }
}

struct StatRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
            Spacer()
            Text("\(count)")
                .fontWeight(.medium)
        }
    }
}

#Preview {
    WorkspaceView()
        .environment(AppState())
        .frame(width: 1200, height: 800)
}
