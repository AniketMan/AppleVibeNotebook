import SwiftUI

@main
struct AppleVibeNotebookApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        #if os(macOS)
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Notebook") {
                    appState.createNewNotebook()
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Import React Project...") {
                    appState.showImportPanel = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Import SwiftUI Project...") {
                    appState.showSwiftUIImportPanel = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Export Code...") {
                    appState.showExportPanel = true
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.generatedCode.isEmpty)
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle AI Panel") {
                    withAnimation {
                        appState.showAIPanel.toggle()
                    }
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Toggle Preview Panel") {
                    withAnimation {
                        appState.showPreviewPanel.toggle()
                    }
                }
                .keyboardShortcut("2", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
        }
        #endif
    }
}

// MARK: - App State

@Observable
final class AppState {
    // Notebook State
    var notebooks: [Notebook] = []
    var activeNotebook: Notebook?
    var activeCell: NotebookCell?

    // Project State
    var projectURL: URL?
    var projectName: String = ""
    var isProcessing: Bool = false
    var processingProgress: Double = 0
    var processingStatus: String = ""

    // Source Files
    var sourceFiles: [SourceFileInfo] = []
    var selectedFile: SourceFileInfo?

    // Generated Code
    var generatedCode: [GeneratedFileInfo] = []
    var selectedGeneratedFile: GeneratedFileInfo?

    // Conversion Report
    var conversionReport: ConversionReportInfo?

    // Panels & Dialogs
    var showImportPanel: Bool = false
    var showSwiftUIImportPanel: Bool = false
    var showZipImportPanel: Bool = false
    var showExportPanel: Bool = false
    var showCodePanel: Bool = true
    var showPreviewPanel: Bool = true
    var showReportPanel: Bool = false
    var showAIPanel: Bool = false
    var showAPISettings: Bool = false

    // Error Handling
    var errorMessage: String?
    var showError: Bool = false

    // Notebook Methods
    func createNewNotebook() {
        let notebook = Notebook(
            id: UUID(),
            name: "Untitled Notebook",
            cells: [NotebookCell(type: .code, language: .swiftui)],
            createdAt: Date()
        )
        notebooks.append(notebook)
        activeNotebook = notebook
        activeCell = notebook.cells.first
    }
}

// MARK: - Notebook Model

struct Notebook: Identifiable, Hashable {
    let id: UUID
    var name: String
    var cells: [NotebookCell]
    let createdAt: Date
    var modifiedAt: Date = Date()

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Notebook, rhs: Notebook) -> Bool {
        lhs.id == rhs.id
    }
}

struct NotebookCell: Identifiable, Hashable {
    let id: UUID
    var type: CellType
    var language: CodeLanguage
    var content: String
    var output: CellOutput?
    var isRunning: Bool = false

    init(id: UUID = UUID(), type: CellType, language: CodeLanguage, content: String = "") {
        self.id = id
        self.type = type
        self.language = language
        self.content = content
    }

    enum CellType: String, Codable {
        case code
        case markdown
        case preview
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NotebookCell, rhs: NotebookCell) -> Bool {
        lhs.id == rhs.id
    }
}

enum CodeLanguage: String, CaseIterable, Codable, Identifiable {
    case swiftui = "SwiftUI"
    case react = "React"
    case jsx = "JSX"
    case typescript = "TypeScript"
    case css = "CSS"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .swiftui: return "swift"
        case .react, .jsx: return "jsx"
        case .typescript: return "tsx"
        case .css: return "css"
        }
    }

    var iconName: String {
        switch self {
        case .swiftui: return "swift"
        case .react, .jsx: return "atom"
        case .typescript: return "t.square"
        case .css: return "paintbrush"
        }
    }
}

struct CellOutput: Identifiable, Hashable {
    let id = UUID()
    var type: OutputType
    var content: String
    var timestamp: Date = Date()

    enum OutputType: String {
        case text
        case preview
        case error
        case image
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CellOutput, rhs: CellOutput) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Source File Info

struct SourceFileInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let type: FileType
    var content: String = ""

    enum FileType: String {
        case jsx, tsx, css, scss, json, swift, other
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SourceFileInfo, rhs: SourceFileInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Generated File Info

struct GeneratedFileInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let content: String
    let tier: ConversionTierInfo

    enum ConversionTierInfo: String {
        case direct = "Direct"
        case adapted = "Adapted"
        case unsupported = "Unsupported"

        var color: Color {
            switch self {
            case .direct: return .green
            case .adapted: return .yellow
            case .unsupported: return .red
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GeneratedFileInfo, rhs: GeneratedFileInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Conversion Report

struct ConversionReportInfo {
    let totalComponents: Int
    let directCount: Int
    let adaptedCount: Int
    let unsupportedCount: Int
    let entries: [ConversionEntryInfo]
    let markdownContent: String

    var healthPercentage: Double {
        guard totalComponents > 0 else { return 0 }
        return Double(directCount + adaptedCount) / Double(totalComponents) * 100
    }
}

struct ConversionEntryInfo: Identifiable {
    let id = UUID()
    let sourceElement: String
    let targetElement: String
    let tier: GeneratedFileInfo.ConversionTierInfo
    let notes: String?
}
