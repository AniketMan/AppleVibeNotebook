import SwiftUI
import AppleVibeNotebook

// MARK: - Code Editor View

/// Mac-only editable code panel with syntax highlighting.
/// Shows generated SwiftUI and React code in real-time.
struct CodeEditorView: View {
    @Bindable var canvasState: CanvasState
    @Bindable var syncEngine: CanvasSyncEngine

    @State private var selectedLanguage: CodeLanguageTab = .swiftUI
    @State private var isEditing = false
    @State private var editedCode = ""
    @State private var showCopyConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            header

            Divider()

            // Code content
            codeContent

            // Footer with actions
            footer
        }
        .background(Color(white: 0.12))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Language tabs
            HStack(spacing: 0) {
                ForEach(CodeLanguageTab.allCases) { tab in
                    Button {
                        selectedLanguage = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedLanguage == tab
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedLanguage == tab ? .accentColor : .secondary)
                }
            }
            .background(Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Spacer()

            // Sync status
            HStack(spacing: 6) {
                if syncEngine.isSyncing {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Syncing...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else if let lastSync = syncEngine.lastSyncTime {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text("Synced \(lastSync.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Toggle sync
            Toggle("Auto-sync", isOn: $syncEngine.autoSync)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
    }

    // MARK: - Code Content

    private var codeContent: some View {
        ScrollView {
            if isEditing {
                editableCodeView
            } else {
                readOnlyCodeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var readOnlyCodeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            let code = currentCode

            if code.isEmpty {
                emptyStateView
            } else {
                SyntaxHighlightedText(
                    code: code,
                    language: selectedLanguage == .swiftUI ? .swift : .typescript
                )
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var editableCodeView: some View {
        TextEditor(text: $editedCode)
            .font(.system(size: 13, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Code Generated")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add layers to the canvas to see generated code")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Line count
            let lineCount = currentCode.components(separatedBy: .newlines).count
            Text("\(lineCount) lines")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // Edit toggle
                Button {
                    if isEditing {
                        // Apply changes
                        applyCodeChanges()
                    } else {
                        editedCode = currentCode
                    }
                    isEditing.toggle()
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(CodeEditorButtonStyle())
                .help(isEditing ? "Apply Changes" : "Edit Code")

                // Copy button
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(CodeEditorButtonStyle())
                .help("Copy to Clipboard")

                // Export button
                Menu {
                    Button("Export as File...") {
                        exportAsFile()
                    }
                    Button("Export to Project...") {
                        exportToProject()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(CodeEditorButtonStyle())

                // Refresh button
                Button {
                    Task {
                        await syncEngine.syncNow(from: canvasState.document)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(CodeEditorButtonStyle())
                .help("Refresh Code")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
    }

    // MARK: - Computed Properties

    private var currentCode: String {
        switch selectedLanguage {
        case .swiftUI:
            return syncEngine.swiftUICode
        case .react:
            return syncEngine.reactCode
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentCode, forType: .string)
        #else
        UIPasteboard.general.string = currentCode
        #endif

        showCopyConfirmation = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCopyConfirmation = false
        }
    }

    private func exportAsFile() {
        // Would open file save dialog
    }

    private func exportToProject() {
        // Would show project export options
    }

    private func applyCodeChanges() {
        // Apply edited code back to canvas
        Task { @MainActor in
            if selectedLanguage == .swiftUI {
                var document = canvasState.document
                try? await syncEngine.syncCodeToCanvas(
                    swiftUICode: editedCode,
                    into: &document
                )
                canvasState.document = document
            } else {
                var document = canvasState.document
                try? await syncEngine.syncReactCodeToCanvas(
                    reactCode: editedCode,
                    into: &document
                )
                canvasState.document = document
            }
        }
    }
}

// MARK: - Code Language Tab

enum CodeLanguageTab: String, CaseIterable, Identifiable {
    case swiftUI = "SwiftUI"
    case react = "React"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .swiftUI: return "swift"
        case .react: return "atom"
        }
    }

    var fileExtension: String {
        switch self {
        case .swiftUI: return "swift"
        case .react: return "tsx"
        }
    }
}

// MARK: - Syntax Highlighted Text

struct SyntaxHighlightedText: View {
    let code: String
    let language: SyntaxLanguage

    enum SyntaxLanguage {
        case swift
        case typescript
    }

    var body: some View {
        Text(attributedCode)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
    }

    private var attributedCode: AttributedString {
        var result = AttributedString(code)

        // Apply syntax highlighting
        // This is a simplified version - a full implementation would use
        // a proper syntax highlighting library

        applyKeywordHighlighting(&result)
        applyStringHighlighting(&result)
        applyCommentHighlighting(&result)
        applyNumberHighlighting(&result)

        return result
    }

    private func applyKeywordHighlighting(_ text: inout AttributedString) {
        let keywords: [String]

        switch language {
        case .swift:
            keywords = [
                "import", "struct", "class", "func", "var", "let", "if", "else",
                "for", "while", "return", "some", "View", "body", "@State",
                "@Binding", "@Observable", "@Environment", "private", "public",
                "extension", "protocol", "enum", "case", "switch", "guard",
                "true", "false", "nil"
            ]
        case .typescript:
            keywords = [
                "import", "export", "const", "let", "var", "function", "return",
                "if", "else", "for", "while", "interface", "type", "class",
                "extends", "implements", "from", "default", "async", "await",
                "true", "false", "null", "undefined"
            ]
        }

        for keyword in keywords {
            highlightOccurrences(of: keyword, in: &text, with: .purple)
        }
    }

    private func applyStringHighlighting(_ text: inout AttributedString) {
        // Highlight strings in quotes
        let pattern = #"\"[^\"]*\""#
        highlightPattern(pattern, in: &text, with: Color(red: 0.8, green: 0.2, blue: 0.2))
    }

    private func applyCommentHighlighting(_ text: inout AttributedString) {
        // Highlight // comments
        let pattern = #"//.*$"#
        highlightPattern(pattern, in: &text, with: .gray)
    }

    private func applyNumberHighlighting(_ text: inout AttributedString) {
        // Highlight numbers
        let pattern = #"\b\d+\.?\d*\b"#
        highlightPattern(pattern, in: &text, with: Color(red: 0.4, green: 0.6, blue: 0.8))
    }

    private func highlightOccurrences(of word: String, in text: inout AttributedString, with color: Color) {
        let plainString = String(text.characters)
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(plainString.startIndex..., in: plainString)

        for match in regex.matches(in: plainString, range: range) {
            if let swiftRange = Range(match.range, in: plainString),
               let attrRange = Range(swiftRange, in: text) {
                text[attrRange].foregroundColor = color
            }
        }
    }

    private func highlightPattern(_ pattern: String, in text: inout AttributedString, with color: Color) {
        let plainString = String(text.characters)

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        let range = NSRange(plainString.startIndex..., in: plainString)

        for match in regex.matches(in: plainString, range: range) {
            if let swiftRange = Range(match.range, in: plainString),
               let attrRange = Range(swiftRange, in: text) {
                text[attrRange].foregroundColor = color
            }
        }
    }
}

// MARK: - Code Editor Button Style

struct CodeEditorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundColor(configuration.isPressed ? .accentColor : .secondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            )
    }
}

// MARK: - Minimap View

struct MinimapView: View {
    let code: String
    let visibleRange: Range<Int>

    var body: some View {
        GeometryReader { geometry in
            let lines = code.components(separatedBy: .newlines)
            let totalLines = lines.count
            let lineHeight = geometry.size.height / CGFloat(max(totalLines, 1))

            ZStack(alignment: .top) {
                // Code representation
                VStack(spacing: 0) {
                    ForEach(0..<min(totalLines, 500), id: \.self) { index in
                        Rectangle()
                            .fill(lineColor(for: lines[index]))
                            .frame(height: max(lineHeight, 1))
                    }
                }

                // Visible area indicator
                let startY = CGFloat(visibleRange.lowerBound) * lineHeight
                let height = CGFloat(visibleRange.count) * lineHeight

                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(height: height)
                    .offset(y: startY)
            }
        }
        .frame(width: 60)
        .background(Color(white: 0.1))
    }

    private func lineColor(for line: String) -> Color {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return .clear
        }
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
            return Color.gray.opacity(0.3)
        }
        if trimmed.hasPrefix("import") || trimmed.hasPrefix("struct") || trimmed.hasPrefix("func") {
            return Color.purple.opacity(0.5)
        }

        return Color.white.opacity(0.3)
    }
}

// MARK: - Preview

#Preview {
    let canvasState = CanvasState()
    let syncEngine = CanvasSyncEngine()
    syncEngine.swiftUICode = """
    import SwiftUI

    struct ContentView: View {
        @State private var count = 0

        var body: some View {
            VStack(spacing: 16) {
                Text("Hello, World!")
                    .font(.title)

                Button("Tap me") {
                    count += 1
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    """

    return CodeEditorView(canvasState: canvasState, syncEngine: syncEngine)
        .frame(width: 500, height: 600)
}
