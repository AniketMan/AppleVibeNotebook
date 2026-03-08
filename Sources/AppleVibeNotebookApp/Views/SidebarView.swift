import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedFile) {
            // AI Assistant section
            Section("AI Assistant") {
                Button {
                    appState.showAIPanel.toggle()
                } label: {
                    Label {
                        HStack {
                            Text("Code Assistant")
                            Spacer()
                            if appState.showAIPanel {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    } icon: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                    }
                }
                .buttonStyle(.plain)
            }

            if !appState.sourceFiles.isEmpty {
                Section("Source Files") {
                    ForEach(groupedFiles.keys.sorted(), id: \.self) { folder in
                        DisclosureGroup(folder.isEmpty ? "Root" : folder) {
                            ForEach(groupedFiles[folder] ?? []) { file in
                                FileRow(file: file)
                                    .tag(file)
                            }
                        }
                    }
                }
            }

            if !appState.generatedCode.isEmpty {
                Section("Generated SwiftUI") {
                    ForEach(appState.generatedCode) { file in
                        GeneratedFileRow(file: file)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        .toolbar {
            ToolbarItem {
                Button {
                    appState.showImportPanel = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var groupedFiles: [String: [SourceFileInfo]] {
        Dictionary(grouping: appState.sourceFiles) { file in
            let components = file.path.split(separator: "/").dropLast()
            return components.joined(separator: "/")
        }
    }
}

struct FileRow: View {
    let file: SourceFileInfo

    var body: some View {
        Label {
            Text(file.name)
                .lineLimit(1)
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        switch file.type {
        case .jsx, .tsx, .swift: return "swift"
        case .css, .scss: return "paintpalette"
        case .json: return "doc.text"
        case .other: return "doc"
        }
    }

    private var iconColor: Color {
        switch file.type {
        case .jsx: return .orange
        case .tsx: return .blue
        case .swift: return .orange
        case .css, .scss: return .pink
        case .json: return .gray
        case .other: return .secondary
        }
    }
}

struct GeneratedFileRow: View {
    @Environment(AppState.self) private var appState
    let file: GeneratedFileInfo

    var body: some View {
        Button {
            appState.selectedGeneratedFile = file
        } label: {
            Label {
                HStack {
                    Text(file.name)
                        .lineLimit(1)
                    Spacer()
                    Circle()
                        .fill(file.tier.color)
                        .frame(width: 8, height: 8)
                }
            } icon: {
                Image(systemName: "swift")
                    .foregroundStyle(.orange)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
            .environment(AppState())
    } detail: {
        Text("Detail")
    }
}
