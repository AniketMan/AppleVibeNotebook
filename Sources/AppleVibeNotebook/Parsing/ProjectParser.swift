import Foundation

// MARK: - Project Parser

/// Parses an entire React project (folder or zip) and converts it to IR.
/// Handles file discovery, CSS linking, and component relationships.
public final class ProjectParser: @unchecked Sendable {

    private let reactParser: ReactParser
    private let cssParser: CSSParser
    private let fileManager: FileManager

    public struct Configuration: Sendable {
        public var sourcePaths: [String]
        public var excludePatterns: [String]
        public var includeCSSModules: Bool
        public var includeNodeModules: Bool

        public init(
            sourcePaths: [String] = ["src", "components", "pages", "app"],
            excludePatterns: [String] = ["node_modules", ".git", "dist", "build", "__tests__", "*.test.*", "*.spec.*"],
            includeCSSModules: Bool = true,
            includeNodeModules: Bool = false
        ) {
            self.sourcePaths = sourcePaths
            self.excludePatterns = excludePatterns
            self.includeCSSModules = includeCSSModules
            self.includeNodeModules = includeNodeModules
        }
    }

    public enum ParserError: Error, LocalizedError {
        case projectNotFound(String)
        case invalidProjectStructure(String)
        case fileReadError(String)
        case parseError(String, Error)
        case zipExtractionFailed(String)

        public var errorDescription: String? {
            switch self {
            case .projectNotFound(let path): return "Project not found at: \(path)"
            case .invalidProjectStructure(let msg): return "Invalid project structure: \(msg)"
            case .fileReadError(let path): return "Failed to read file: \(path)"
            case .parseError(let file, let error): return "Parse error in \(file): \(error.localizedDescription)"
            case .zipExtractionFailed(let msg): return "ZIP extraction failed: \(msg)"
            }
        }
    }

    public init(
        reactParser: ReactParser? = nil,
        cssParser: CSSParser? = nil
    ) {
        self.reactParser = reactParser ?? ReactParser()
        self.cssParser = cssParser ?? CSSParser()
        self.fileManager = FileManager.default
    }

    // MARK: - Public API

    /// Parses a React project from a folder path.
    public func parseProject(
        at path: String,
        configuration: Configuration = Configuration()
    ) async throws -> IntermediateRepresentation {
        let url = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: path) else {
            throw ParserError.projectNotFound(path)
        }

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            return try await parseProjectFolder(at: url, configuration: configuration)
        } else if path.hasSuffix(".zip") {
            return try await parseZipFile(at: url, configuration: configuration)
        } else {
            throw ParserError.invalidProjectStructure("Expected a folder or .zip file")
        }
    }

    /// Parses a React project from a ZIP file.
    public func parseZipFile(
        at url: URL,
        configuration: Configuration = Configuration()
    ) async throws -> IntermediateRepresentation {
        try Task.checkCancellation()

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        try await extractZip(at: url, to: tempDir)

        try Task.checkCancellation()

        let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let projectRoot: URL

        if contents.count == 1, contents[0].hasDirectoryPath {
            projectRoot = contents[0]
        } else {
            projectRoot = tempDir
        }

        return try await parseProjectFolder(at: projectRoot, configuration: configuration)
    }

    // MARK: - Folder Parsing

    private func parseProjectFolder(
        at url: URL,
        configuration: Configuration
    ) async throws -> IntermediateRepresentation {
        try Task.checkCancellation()

        let projectName = url.lastPathComponent
        let projectPath = url.path

        var discoveredFiles = DiscoveredFiles()
        try discoverFiles(in: url, into: &discoveredFiles, configuration: configuration, basePath: url)

        try Task.checkCancellation()

        var allStyles: [String: ComputedCSSStyle] = [:]
        for cssFile in discoveredFiles.cssFiles {
            try Task.checkCancellation()
            do {
                let styles = try cssParser.parseCSSFile(at: cssFile)
                for (selector, style) in styles {
                    allStyles[selector] = style
                }
            } catch {
                print("Warning: Failed to parse CSS file \(cssFile.path): \(error)")
            }
        }

        let irBuilder = IRBuilder(projectName: projectName, projectPath: projectPath)

        let designTokens = extractDesignTokens(from: allStyles)
        for token in designTokens {
            if let color = token.value as? CSSColor {
                irBuilder.addColor(name: token.name, color: color)
            } else if let value = token.value as? Double {
                irBuilder.addSpacing(name: token.name, value: value)
            }
        }

        try Task.checkCancellation()

        for jsxFile in discoveredFiles.jsxFiles {
            try Task.checkCancellation()
            do {
                let content = try String(contentsOf: jsxFile, encoding: .utf8)
                let isTypeScript = jsxFile.pathExtension == "tsx" || jsxFile.pathExtension == "ts"
                let relativePath = jsxFile.path.replacingOccurrences(of: projectPath, with: "")

                let linkedStyles = resolveLinkedStyles(for: jsxFile, allStyles: allStyles, cssFiles: discoveredFiles.cssFiles)
                let mergedStyles = allStyles.merging(linkedStyles) { $1 }

                let parsedFile = try reactParser.parseFile(
                    source: content,
                    filePath: relativePath,
                    isTypeScript: isTypeScript
                )

                let sourceFileIR = try reactParser.convertToIR(
                    parsedFile: parsedFile,
                    cssStyles: mergedStyles
                )

                irBuilder.addSourceFile(sourceFileIR)
            } catch {
                print("Warning: Failed to parse file \(jsxFile.path): \(error)")
            }
        }

        return irBuilder.build()
    }

    // MARK: - File Discovery

    private struct DiscoveredFiles {
        var jsxFiles: [URL] = []
        var cssFiles: [URL] = []
        var jsonFiles: [URL] = []
    }

    private func discoverFiles(
        in directory: URL,
        into discovered: inout DiscoveredFiles,
        configuration: Configuration,
        basePath: URL
    ) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let name = item.lastPathComponent

            if shouldExclude(name: name, configuration: configuration) {
                continue
            }

            if isDirectory {
                let relativePath = item.path.replacingOccurrences(of: basePath.path, with: "")
                let shouldSearch = configuration.sourcePaths.isEmpty ||
                    configuration.sourcePaths.contains { relativePath.contains($0) } ||
                    directory.path != basePath.path

                if shouldSearch {
                    try discoverFiles(in: item, into: &discovered, configuration: configuration, basePath: basePath)
                }
            } else {
                let ext = item.pathExtension.lowercased()

                switch ext {
                case "jsx", "tsx":
                    discovered.jsxFiles.append(item)
                case "js", "ts":
                    if isReactFile(item) {
                        discovered.jsxFiles.append(item)
                    }
                case "css":
                    discovered.cssFiles.append(item)
                case "scss", "sass", "less":
                    discovered.cssFiles.append(item)
                case "json":
                    if name == "package.json" || name == "tsconfig.json" {
                        discovered.jsonFiles.append(item)
                    }
                default:
                    break
                }
            }
        }
    }

    private func shouldExclude(name: String, configuration: Configuration) -> Bool {
        for pattern in configuration.excludePatterns {
            if pattern.contains("*") {
                let regex = pattern
                    .replacingOccurrences(of: ".", with: "\\.")
                    .replacingOccurrences(of: "*", with: ".*")

                if let regex = try? NSRegularExpression(pattern: "^\(regex)$", options: []),
                   regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) != nil {
                    return true
                }
            } else if name == pattern {
                return true
            }
        }
        return false
    }

    private func isReactFile(_ url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8).prefix(1000) else {
            return false
        }

        return content.contains("import React") ||
               content.contains("from 'react'") ||
               content.contains("from \"react\"") ||
               content.contains("JSX") ||
               content.contains("</>") ||
               content.contains("</")
    }

    // MARK: - Style Resolution

    private func resolveLinkedStyles(
        for jsxFile: URL,
        allStyles: [String: ComputedCSSStyle],
        cssFiles: [URL]
    ) -> [String: ComputedCSSStyle] {
        let jsxName = jsxFile.deletingPathExtension().lastPathComponent
        let jsxDir = jsxFile.deletingLastPathComponent()

        var linkedStyles: [String: ComputedCSSStyle] = [:]

        let possibleCSSNames = [
            "\(jsxName).css",
            "\(jsxName).module.css",
            "\(jsxName).styles.css",
            "styles.css",
            "index.css"
        ]

        for cssFile in cssFiles {
            let cssName = cssFile.lastPathComponent

            if possibleCSSNames.contains(cssName) {
                let cssDir = cssFile.deletingLastPathComponent()

                if cssDir.path == jsxDir.path || cssDir.path.contains(jsxDir.lastPathComponent) {
                    if let styles = try? cssParser.parseCSSFile(at: cssFile) {
                        for (selector, style) in styles {
                            linkedStyles[selector] = style
                        }
                    }
                }
            }
        }

        return linkedStyles
    }

    // MARK: - Design Token Extraction

    private func extractDesignTokens(from styles: [String: ComputedCSSStyle]) -> [(name: String, value: Any)] {
        var tokens: [(name: String, value: Any)] = []
        var colorCounts: [String: Int] = [:]
        var spacingValues: Set<Double> = []

        for (_, style) in styles {
            if let color = style.color {
                let hex = colorToHex(color)
                colorCounts[hex, default: 0] += 1
            }
            if let bg = style.backgroundColor {
                let hex = colorToHex(bg)
                colorCounts[hex, default: 0] += 1
            }

            if let padding = style.paddingTop, padding.unit == .px {
                spacingValues.insert(padding.value)
            }
            if let padding = style.paddingRight, padding.unit == .px {
                spacingValues.insert(padding.value)
            }
            if let margin = style.marginTop, margin.unit == .px {
                spacingValues.insert(margin.value)
            }
            if let margin = style.marginRight, margin.unit == .px {
                spacingValues.insert(margin.value)
            }
            if let gap = style.gap, gap.unit == .px {
                spacingValues.insert(gap.value)
            }
        }

        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let frequentColors = sortedColors.prefix(10)

        for (index, (hex, _)) in frequentColors.enumerated() {
            if let color = hexToColor(hex) {
                let name = "color\(index + 1)"
                tokens.append((name: name, value: color))
            }
        }

        let sortedSpacing = spacingValues.sorted()
        let spacingNames = ["xxs", "xs", "sm", "md", "lg", "xl", "xxl"]

        for (index, value) in sortedSpacing.prefix(7).enumerated() {
            let name = spacingNames[index]
            tokens.append((name: name, value: value))
        }

        return tokens
    }

    private func colorToHex(_ color: CSSColor) -> String {
        let r = Int(color.red * 255)
        let g = Int(color.green * 255)
        let b = Int(color.blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func hexToColor(_ hex: String) -> CSSColor? {
        var hexString = hex.trimmingCharacters(in: .whitespaces)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6 else { return nil }

        let r = Double(Int(hexString.prefix(2), radix: 16) ?? 0) / 255
        let g = Double(Int(hexString.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255
        let b = Double(Int(hexString.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255

        return CSSColor(red: r, green: g, blue: b, alpha: 1)
    }

    // MARK: - ZIP Extraction

    private func extractZip(at source: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", source.path, "-d", destination.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ParserError.zipExtractionFailed(errorMessage)
        }
    }
}

// MARK: - Project Analysis

public extension ProjectParser {

    /// Analyzes a project and returns statistics without full parsing.
    func analyzeProject(at path: String) throws -> ProjectAnalysis {
        let url = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: path) else {
            throw ParserError.projectNotFound(path)
        }

        var analysis = ProjectAnalysis()

        var discovered = DiscoveredFiles()
        try discoverFiles(in: url, into: &discovered, configuration: Configuration(), basePath: url)

        analysis.totalJSXFiles = discovered.jsxFiles.count
        analysis.totalCSSFiles = discovered.cssFiles.count

        for jsxFile in discovered.jsxFiles {
            let ext = jsxFile.pathExtension.lowercased()
            if ext == "tsx" || ext == "ts" {
                analysis.usesTypeScript = true
                break
            }
        }

        for cssFile in discovered.cssFiles {
            let name = cssFile.lastPathComponent
            if name.contains(".module.") {
                analysis.usesCSSModules = true
            }
            if name.hasSuffix(".scss") || name.hasSuffix(".sass") {
                analysis.usesSASS = true
            }
        }

        let packageJSON = url.appendingPathComponent("package.json")
        if fileManager.fileExists(atPath: packageJSON.path),
           let data = try? Data(contentsOf: packageJSON),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deps = json["dependencies"] as? [String: Any] {

            analysis.detectedLibraries = Array(deps.keys)

            if deps["styled-components"] != nil || deps["@emotion/react"] != nil {
                analysis.usesCSS_in_JS = true
            }
            if deps["tailwindcss"] != nil {
                analysis.usesTailwind = true
            }
            if deps["framer-motion"] != nil || deps["react-spring"] != nil {
                analysis.usesAnimationLibrary = true
            }
        }

        return analysis
    }
}

/// Results of project analysis.
public struct ProjectAnalysis: Sendable {
    public var totalJSXFiles: Int = 0
    public var totalCSSFiles: Int = 0
    public var usesTypeScript: Bool = false
    public var usesCSSModules: Bool = false
    public var usesSASS: Bool = false
    public var usesCSS_in_JS: Bool = false
    public var usesTailwind: Bool = false
    public var usesAnimationLibrary: Bool = false
    public var detectedLibraries: [String] = []

    public var estimatedComplexity: String {
        let score = totalJSXFiles + totalCSSFiles + (usesTypeScript ? 10 : 0) + (usesCSS_in_JS ? 20 : 0)

        switch score {
        case 0..<10: return "Simple"
        case 10..<50: return "Medium"
        case 50..<100: return "Complex"
        default: return "Very Complex"
        }
    }
}
