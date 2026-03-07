import SwiftUI
import UniformTypeIdentifiers
import AppleVibeNotebook

// MARK: - Figma Asset Browser View

struct FigmaAssetBrowserView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var figmaDocument: FigmaFileParser.FigmaDocument?
    @State private var selectedNodes: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedPages: Set<String> = []
    @State private var searchText = ""
    @State private var showFileImporter = false

    var body: some View {
        ZStack {
            // Dark background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.08),
                    Color(red: 0.05, green: 0.08, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let document = figmaDocument {
                documentBrowserContent(document)
            } else {
                emptyStateContent
            }

            if isLoading {
                loadingOverlay
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "fig")!],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: 32) {
            NeonLiquidGlass(cornerRadius: 40) {
                VStack(spacing: 20) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    VStack(spacing: 8) {
                        Text("Import Figma File")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Select a .fig file to browse and import assets")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(40)
            }
            .frame(width: 320, height: 240)

            Button {
                showFileImporter = true
            } label: {
                NeonLiquidGlass(cornerRadius: 16, glowIntensity: 0.8) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                        Text("Choose Figma File")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Document Browser

    private func documentBrowserContent(_ document: FigmaFileParser.FigmaDocument) -> some View {
        VStack(spacing: 0) {
            // Header
            headerView(document)

            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 0) {
                // Left: Asset Tree
                assetTreeView(document)
                    .frame(width: 320)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Right: Preview & Code
                previewPane
            }
        }
    }

    private func headerView(_ document: FigmaFileParser.FigmaDocument) -> some View {
        HStack(spacing: 16) {
            // Thumbnail
            if let thumbnailData = document.thumbnail,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "doc.richtext")
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(countAllNodes(in: document)) layers • \(document.pages.count) pages")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search layers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .frame(width: 220)

            // Actions
            Button {
                importSelectedAssets()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import \(selectedNodes.count > 0 ? "(\(selectedNodes.count))" : "All")")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.cyan, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(selectedNodes.isEmpty && flattenedNodes(from: document).isEmpty)

            Button {
                figmaDocument = nil
                selectedNodes = []
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(8)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }

    private func assetTreeView(_ document: FigmaFileParser.FigmaDocument) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(document.pages) { page in
                    pageRow(page)
                }
            }
            .padding(12)
        }
        .background(Color.black.opacity(0.2))
    }

    private func pageRow(_ page: FigmaFileParser.FigmaPage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedPages.contains(page.id) {
                        expandedPages.remove(page.id)
                    } else {
                        expandedPages.insert(page.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expandedPages.contains(page.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 12)

                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.cyan)

                    Text(page.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(page.children.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedPages.contains(page.id) {
                ForEach(filteredNodes(page.children)) { node in
                    nodeRow(node, indent: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func nodeRow(_ node: FigmaFileParser.FigmaNode, indent: Int) -> some View {
        let isSelected = selectedNodes.contains(node.id)

        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isSelected {
                        selectedNodes.remove(node.id)
                    } else {
                        selectedNodes.insert(node.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? .cyan : .white.opacity(0.3))

                    Image(systemName: iconForNodeType(node.type))
                        .font(.system(size: 11))
                        .foregroundStyle(colorForNodeType(node.type))

                    Text(node.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(node.isVisible ? 0.9 : 0.4))
                        .lineLimit(1)

                    Spacer()

                    if let size = node.size {
                        Text("\(Int(size.width))×\(Int(size.height))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.vertical, 6)
                .padding(.leading, CGFloat(indent * 16 + 8))
                .padding(.trailing, 8)
                .background(isSelected ? Color.cyan.opacity(0.15) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Recursively show children (limited depth) - use ForEach with AnyView to break type recursion
            if indent < 3 && !node.children.isEmpty {
                ForEach(filteredNodes(node.children)) { child in
                    AnyView(nodeRow(child, indent: indent + 1))
                }
            }
        }
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            if selectedNodes.isEmpty {
                // Empty selection state
                VStack(spacing: 16) {
                    Image(systemName: "square.dashed")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))

                    Text("Select layers to preview")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show preview and code for selected nodes
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(selectedNodeObjects, id: \.id) { node in
                            nodePreviewCard(node)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.black.opacity(0.1))
    }

    private func nodePreviewCard(_ node: FigmaFileParser.FigmaNode) -> some View {
        NeonLiquidGlass(cornerRadius: 16, glowIntensity: 0.4) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: iconForNodeType(node.type))
                        .foregroundStyle(colorForNodeType(node.type))

                    Text(node.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(node.type.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }

                // Properties
                if let size = node.size {
                    HStack(spacing: 16) {
                        propertyBadge(label: "W", value: "\(Int(size.width))")
                        propertyBadge(label: "H", value: "\(Int(size.height))")
                        if let radius = node.cornerRadius {
                            propertyBadge(label: "R", value: "\(Int(radius))")
                        }
                    }
                }

                // Generated SwiftUI Code
                VStack(alignment: .leading, spacing: 8) {
                    Text("SwiftUI Code")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.cyan)

                    Text(node.toSwiftUICode())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
        }
    }

    private func propertyBadge(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.cyan)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            NeonLiquidGlass(cornerRadius: 24) {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.cyan)

                    Text("Parsing Figma file...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(32)
            }
        }
    }

    // MARK: - Helpers

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadFigmaFile(at: url)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadFigmaFile(at url: URL) {
        isLoading = true

        Task {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "FigmaImport", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Cannot access file"])
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let parser = FigmaFileParser()
                let document = try await parser.parse(fileURL: url)

                await MainActor.run {
                    self.figmaDocument = document
                    self.expandedPages = Set(document.pages.map { $0.id })
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func filteredNodes(_ nodes: [FigmaFileParser.FigmaNode]) -> [FigmaFileParser.FigmaNode] {
        guard !searchText.isEmpty else { return nodes }
        return nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func flattenedNodes(from document: FigmaFileParser.FigmaDocument) -> [FigmaFileParser.FigmaNode] {
        var all: [FigmaFileParser.FigmaNode] = []
        for page in document.pages {
            all.append(contentsOf: flattenNodes(page.children))
        }
        return all
    }

    private func flattenNodes(_ nodes: [FigmaFileParser.FigmaNode]) -> [FigmaFileParser.FigmaNode] {
        var result: [FigmaFileParser.FigmaNode] = []
        for node in nodes {
            result.append(node)
            result.append(contentsOf: flattenNodes(node.children))
        }
        return result
    }

    private var selectedNodeObjects: [FigmaFileParser.FigmaNode] {
        guard let document = figmaDocument else { return [] }
        let all = flattenedNodes(from: document)
        return all.filter { selectedNodes.contains($0.id) }
    }

    private func countAllNodes(in document: FigmaFileParser.FigmaDocument) -> Int {
        flattenedNodes(from: document).count
    }

    private func iconForNodeType(_ type: FigmaFileParser.FigmaNodeType) -> String {
        switch type {
        case .frame: return "rectangle"
        case .group: return "folder"
        case .component: return "cube"
        case .componentSet: return "square.stack.3d.up"
        case .instance: return "square.on.square"
        case .rectangle: return "rectangle.fill"
        case .ellipse: return "circle.fill"
        case .text: return "textformat"
        case .vector: return "pencil.tip"
        case .line: return "line.diagonal"
        case .star: return "star.fill"
        default: return "square.dashed"
        }
    }

    private func colorForNodeType(_ type: FigmaFileParser.FigmaNodeType) -> Color {
        switch type {
        case .frame: return .purple
        case .group: return .yellow
        case .component, .componentSet: return .green
        case .instance: return .mint
        case .rectangle, .ellipse: return .blue
        case .text: return .orange
        case .vector, .line, .star: return .pink
        default: return .gray
        }
    }

    private func importSelectedAssets() {
        guard let document = figmaDocument else { return }

        let nodesToImport = selectedNodes.isEmpty
            ? flattenedNodes(from: document)
            : selectedNodeObjects

        // Generate SwiftUI code for selected nodes
        var generatedCode = """
        import SwiftUI

        // Generated from Figma: \(document.fileName)
        // Imported \(nodesToImport.count) layers

        """

        for node in nodesToImport {
            generatedCode += """

            // MARK: - \(node.name)

            struct \(sanitizeName(node.name))View: View {
                var body: some View {
            \(node.toSwiftUICode(indent: 2))
                }
            }

            """
        }

        // Add to app state
        appState.generatedCode.append(GeneratedFileInfo(
            name: "\(document.fileName)_Figma.swift",
            content: generatedCode,
            tier: .direct
        ))

        dismiss()
    }

    private func sanitizeName(_ name: String) -> String {
        let validChars = CharacterSet.alphanumerics
        var result = ""
        var capitalizeNext = true

        for char in name {
            if let scalar = char.unicodeScalars.first, validChars.contains(scalar) {
                if capitalizeNext {
                    result += char.uppercased()
                    capitalizeNext = false
                } else {
                    result += String(char)
                }
            } else {
                capitalizeNext = true
            }
        }

        return result.isEmpty ? "FigmaComponent" : result
    }
}

#Preview {
    FigmaAssetBrowserView()
        .environment(AppState())
        .frame(width: 1000, height: 700)
}
