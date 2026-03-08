import SwiftUI
import UniformTypeIdentifiers
import AppleVibeNotebook

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var canvasState = CanvasState()
    @State private var cloudSync = CloudSyncService()

    var body: some View {
        @Bindable var state = appState

        Group {
            #if os(iOS)
            iPadMainInterface()
            #else
            macOSContentView()
            #endif
        }
        .environment(canvasState)
        .environment(cloudSync)
        .fileImporter(
            isPresented: $state.showImportPanel,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderImport(result)
        }
        .fileImporter(
            isPresented: $state.showSwiftUIImportPanel,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleSwiftUIImport(result)
        }
        .fileImporter(
            isPresented: $state.showZipImportPanel,
            allowedContentTypes: [UTType(filenameExtension: "zip")!],
            allowsMultipleSelection: false
        ) { result in
            handleZipImport(result)
        }
        .fileExporter(
            isPresented: $state.showExportPanel,
            document: CodeExportDocument(files: appState.generatedCode),
            contentType: .folder,
            defaultFilename: "\(appState.projectName.isEmpty ? "Untitled" : appState.projectName)_Export"
        ) { result in
            handleExport(result)
        }
        .alert("Error", isPresented: $state.showError) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
        .overlay {
            if appState.isProcessing {
                ProcessingOverlay()
            }
        }
        .sheet(isPresented: $state.showAPISettings) {
            APISettingsView()
        }
    }

    // MARK: - macOS Layout

    @ViewBuilder
    private func macOSContentView() -> some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if appState.activeNotebook != nil {
                NotebookEditorView()
            } else if appState.showAIPanel {
                AISuggestionPanelView()
            } else if appState.projectURL != nil {
                WorkspaceView()
            } else {
                WelcomeView()
            }
        }
        .navigationTitle(appState.activeNotebook?.name ?? "Apple Vibe Notebook")
    }

    // MARK: - iPad Main Interface (Per TECHNICAL_SPEC.md)

    @ViewBuilder
    private func iPadMainInterface() -> some View {
        ZStack {
            // Main Canvas Workspace
            CanvasWorkspaceView()

            // Liquid Glass Voice Companion (floating orb - per spec section 4.1)
            LiquidGlassCompanion()
        }
    }

  // MARK: - Import Handlers

  private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importProject(at: url, type: .react)
            }
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }
    }

    private func handleSwiftUIImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importProject(at: url, type: .swiftui)
            }
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }
    }

    private func handleZipImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importZipProject(at: url)
            }
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Exported to: \(url.path)")
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }
    }

    enum ImportType {
        case react
        case swiftui
    }

    @MainActor
    private func importProject(at url: URL, type: ImportType) async {
        appState.isProcessing = true
        appState.processingStatus = "Analyzing project..."
        appState.processingProgress = 0

        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "AppleVibeNotebook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access folder"])
            }
            defer { url.stopAccessingSecurityScopedResource() }

            appState.projectURL = url
            appState.projectName = url.lastPathComponent

            appState.processingStatus = "Discovering files..."
            appState.processingProgress = 0.1

            let sourceFiles = try discoverSourceFiles(in: url)
            appState.sourceFiles = sourceFiles

            appState.processingStatus = type == .react ? "Parsing React components..." : "Parsing SwiftUI views..."
            appState.processingProgress = 0.3

            if type == .react {
                let projectParser = ProjectParser()
                let ir = try await projectParser.parseProject(at: url.path)

                appState.processingStatus = "Generating SwiftUI code..."
                appState.processingProgress = 0.6

                let codeGenerator = SwiftSyntaxCodeGenerator()
                let generatedFiles = codeGenerator.generate(from: ir)

                appState.generatedCode = generatedFiles.map { file in
                    GeneratedFileInfo(
                        name: URL(fileURLWithPath: file.path).lastPathComponent,
                        content: file.content,
                        tier: .direct
                    )
                }

                appState.conversionReport = buildConversionReport(from: ir)
            } else {
                // TODO: SwiftUI → React conversion
                appState.processingStatus = "SwiftUI → React coming soon..."
                appState.processingProgress = 0.9
            }

            appState.processingProgress = 1.0
            appState.processingStatus = "Complete!"

            if let firstFile = appState.generatedCode.first {
                appState.selectedGeneratedFile = firstFile
            }

        } catch {
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }

        appState.isProcessing = false
    }

    @MainActor
    private func importZipProject(at url: URL) async {
        appState.isProcessing = true
        appState.processingStatus = "Extracting ZIP..."
        appState.processingProgress = 0

        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "AppleVibeNotebook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access file"])
            }
            defer { url.stopAccessingSecurityScopedResource() }

            appState.projectName = url.deletingPathExtension().lastPathComponent

            let projectParser = ProjectParser()
            let ir = try await projectParser.parseZipFile(at: url)

            appState.processingStatus = "Generating SwiftUI code..."
            appState.processingProgress = 0.6

            let codeGenerator = SwiftSyntaxCodeGenerator()
            let generatedFiles = codeGenerator.generate(from: ir)

            appState.generatedCode = generatedFiles.map { file in
                GeneratedFileInfo(
                    name: URL(fileURLWithPath: file.path).lastPathComponent,
                    content: file.content,
                    tier: .direct
                )
            }

            appState.conversionReport = buildConversionReport(from: ir)

            appState.processingProgress = 1.0

            if let firstFile = appState.generatedCode.first {
                appState.selectedGeneratedFile = firstFile
            }

        } catch {
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }

        appState.isProcessing = false
    }

    private func discoverSourceFiles(in url: URL) throws -> [SourceFileInfo] {
        var files: [SourceFileInfo] = []
        let fileManager = FileManager.default

        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let path = fileURL.path
            if path.contains("node_modules") || path.contains(".git") || path.contains(".build") { continue }

            let ext = fileURL.pathExtension.lowercased()
            let type: SourceFileInfo.FileType

            switch ext {
            case "jsx": type = .jsx
            case "tsx": type = .tsx
            case "css": type = .css
            case "scss": type = .scss
            case "json": type = .json
            case "swift": type = .swift
            default: continue
            }

            let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""

            files.append(SourceFileInfo(
                name: fileURL.lastPathComponent,
                path: fileURL.path.replacingOccurrences(of: url.path, with: ""),
                type: type,
                content: content
            ))
        }

        return files.sorted { $0.name < $1.name }
    }

    private func buildConversionReport(from ir: IntermediateRepresentation) -> ConversionReportInfo {
        var directCount = 0
        var entries: [ConversionEntryInfo] = []

        for sourceFile in ir.sourceFiles {
            for component in sourceFile.components {
                directCount += 1
                entries.append(ConversionEntryInfo(
                    sourceElement: component.name,
                    targetElement: "\(component.name)View",
                    tier: .direct,
                    notes: nil
                ))
            }
        }

        let markdown = """
        # Conversion Report

        ## Summary
        - **Total Components**: \(directCount)
        - **Direct**: \(directCount)

        ## Health: 100%
        """

        return ConversionReportInfo(
            totalComponents: directCount,
            directCount: directCount,
            adaptedCount: 0,
            unsupportedCount: 0,
            entries: entries,
            markdownContent: markdown
        )
    }
}

// MARK: - Notebook Editor View (Placeholder)

struct NotebookEditorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            if let notebook = appState.activeNotebook {
                Text(notebook.name)
                    .font(.largeTitle)
                Text("\(notebook.cells.count) cells")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Conversion Mode

enum ConversionMode {
    case reactToSwift
    case swiftToReact
}

// MARK: - Convert Tool View (iPad)

struct ConvertToolView: View {
    @Environment(AppState.self) private var appState
    var mode: ConversionMode?

    var body: some View {
        VStack(spacing: 24) {
            Text("Code Converter")
                .font(.largeTitle.bold())

            if let mode = mode {
                // Single mode view
                switch mode {
                case .reactToSwift:
                    conversionButton(
                        icon: "arrow.right",
                        title: "React → SwiftUI",
                        action: { appState.showImportPanel = true }
                    )
                case .swiftToReact:
                    conversionButton(
                        icon: "arrow.left",
                        title: "SwiftUI → React",
                        action: { appState.showSwiftUIImportPanel = true }
                    )
                }
            } else {
                // Both options
                HStack(spacing: 20) {
                    conversionButton(
                        icon: "arrow.right",
                        title: "React → SwiftUI",
                        action: { appState.showImportPanel = true }
                    )

                    conversionButton(
                        icon: "arrow.left",
                        title: "SwiftUI → React",
                        action: { appState.showSwiftUIImportPanel = true }
                    )
                }
                .padding()
            }
        }
        .navigationTitle("Convert")
    }

    @ViewBuilder
    private func conversionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Export Document

struct CodeExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.folder]

    let files: [GeneratedFileInfo]

    init(files: [GeneratedFileInfo]) {
        self.files = files
    }

    init(configuration: ReadConfiguration) throws {
        self.files = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let folderWrapper = FileWrapper(directoryWithFileWrappers: [:])

        for file in files {
            if let data = file.content.data(using: .utf8) {
                let fileWrapper = FileWrapper(regularFileWithContents: data)
                fileWrapper.preferredFilename = file.name
                folderWrapper.addFileWrapper(fileWrapper)
            }
        }

        return folderWrapper
    }
}

// MARK: - Feature Card (iPad Welcome)

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tint)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 140, height: 120)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
