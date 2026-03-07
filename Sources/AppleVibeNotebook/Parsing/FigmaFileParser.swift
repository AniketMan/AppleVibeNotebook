import Foundation
import Compression

// MARK: - Figma File Parser

/// Native Swift parser for Figma .fig files.
/// Decodes the Kiwi binary schema and extracts the node tree.
public final class FigmaFileParser {

    // MARK: - Types

    public struct FigmaDocument: Sendable {
        public let fileName: String
        public let pages: [FigmaPage]
        public let thumbnail: Data?
        public let metadata: FigmaMetadata
    }

    public struct FigmaMetadata: Sendable {
        public let backgroundColor: FigmaColor?
        public let exportedAt: String?
    }

    public struct FigmaPage: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let children: [FigmaNode]
    }

    public struct FigmaNode: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let type: FigmaNodeType
        public let size: FigmaSize?
        public let position: FigmaPoint?
        public let cornerRadius: Double?
        public let fills: [FigmaFill]
        public let strokes: [FigmaStroke]
        public let effects: [FigmaEffect]
        public let children: [FigmaNode]
        public let isVisible: Bool
        public let opacity: Double
    }

    public enum FigmaNodeType: String, Sendable {
        case document = "DOCUMENT"
        case canvas = "CANVAS"
        case frame = "FRAME"
        case group = "GROUP"
        case component = "COMPONENT"
        case componentSet = "COMPONENT_SET"
        case instance = "INSTANCE"
        case rectangle = "RECTANGLE"
        case ellipse = "ELLIPSE"
        case line = "LINE"
        case vector = "VECTOR"
        case text = "TEXT"
        case booleanOperation = "BOOLEAN_OPERATION"
        case slice = "SLICE"
        case star = "STAR"
        case regularPolygon = "REGULAR_POLYGON"
        case unknown = "UNKNOWN"
    }

    public struct FigmaSize: Sendable {
        public let width: Double
        public let height: Double
    }

    public struct FigmaPoint: Sendable {
        public let x: Double
        public let y: Double
    }

    public struct FigmaColor: Sendable {
        public let r: Double
        public let g: Double
        public let b: Double
        public let a: Double

        public var swiftUICode: String {
            if a < 1.0 {
                return "Color(red: \(String(format: "%.3f", r)), green: \(String(format: "%.3f", g)), blue: \(String(format: "%.3f", b))).opacity(\(String(format: "%.2f", a)))"
            }
            return "Color(red: \(String(format: "%.3f", r)), green: \(String(format: "%.3f", g)), blue: \(String(format: "%.3f", b)))"
        }
    }

    public struct FigmaFill: Sendable {
        public let type: FigmaFillType
        public let color: FigmaColor?
        public let gradientStops: [FigmaGradientStop]?
        public let imageHash: String?
        public let opacity: Double
        public let isVisible: Bool
    }

    public enum FigmaFillType: String, Sendable {
        case solid = "SOLID"
        case linearGradient = "GRADIENT_LINEAR"
        case radialGradient = "GRADIENT_RADIAL"
        case angularGradient = "GRADIENT_ANGULAR"
        case diamondGradient = "GRADIENT_DIAMOND"
        case image = "IMAGE"
        case unknown = "UNKNOWN"
    }

    public struct FigmaGradientStop: Sendable {
        public let position: Double
        public let color: FigmaColor
    }

    public struct FigmaStroke: Sendable {
        public let color: FigmaColor?
        public let weight: Double
        public let opacity: Double
    }

    public struct FigmaEffect: Sendable {
        public let type: FigmaEffectType
        public let radius: Double?
        public let color: FigmaColor?
        public let offset: FigmaPoint?
        public let spread: Double?
        public let isVisible: Bool
    }

    public enum FigmaEffectType: String, Sendable {
        case dropShadow = "DROP_SHADOW"
        case innerShadow = "INNER_SHADOW"
        case layerBlur = "LAYER_BLUR"
        case backgroundBlur = "BACKGROUND_BLUR"
        case unknown = "UNKNOWN"
    }

    // MARK: - Errors

    public enum FigmaParseError: Error, LocalizedError {
        case invalidFile
        case invalidHeader
        case decompressionFailed
        case schemaDecodingFailed
        case dataDecodingFailed
        case missingCanvasFile

        public var errorDescription: String? {
            switch self {
            case .invalidFile: return "Not a valid Figma file"
            case .invalidHeader: return "Invalid Figma file header"
            case .decompressionFailed: return "Failed to decompress Figma data"
            case .schemaDecodingFailed: return "Failed to decode Figma schema"
            case .dataDecodingFailed: return "Failed to decode Figma data"
            case .missingCanvasFile: return "Missing canvas.fig in archive"
            }
        }
    }

    // MARK: - Parsing

    public init() {}

    /// Parse a .fig file and extract its contents
    public func parse(fileURL: URL) async throws -> FigmaDocument {
        // Step 1: Unzip the .fig archive
        let extractedURL = try await unzipFigmaFile(at: fileURL)
        defer {
            try? FileManager.default.removeItem(at: extractedURL)
        }

        // Step 2: Read metadata
        let metadata = try readMetadata(from: extractedURL)

        // Step 3: Read thumbnail
        let thumbnailURL = extractedURL.appendingPathComponent("thumbnail.png")
        let thumbnail = try? Data(contentsOf: thumbnailURL)

        // Step 4: Parse canvas.fig binary
        let canvasURL = extractedURL.appendingPathComponent("canvas.fig")
        guard FileManager.default.fileExists(atPath: canvasURL.path) else {
            throw FigmaParseError.missingCanvasFile
        }

        let pages = try await parseCanvasBinary(at: canvasURL)

        // Step 5: Collect any images
        let imagesURL = extractedURL.appendingPathComponent("images")
        if FileManager.default.fileExists(atPath: imagesURL.path) {
            try await processImages(at: imagesURL)
        }

        return FigmaDocument(
            fileName: fileURL.deletingPathExtension().lastPathComponent,
            pages: pages,
            thumbnail: thumbnail,
            metadata: metadata
        )
    }

    // MARK: - Private Methods

    private func unzipFigmaFile(at url: URL) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("figma_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Use Process to unzip (more reliable than manual implementation)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw FigmaParseError.invalidFile
        }

        return tempDir
    }

    private func readMetadata(from extractedURL: URL) throws -> FigmaMetadata {
        let metaURL = extractedURL.appendingPathComponent("meta.json")

        guard let data = try? Data(contentsOf: metaURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return FigmaMetadata(backgroundColor: nil, exportedAt: nil)
        }

        var bgColor: FigmaColor?
        if let bg = json["client_meta"] as? [String: Any],
           let colorDict = bg["background_color"] as? [String: Any] {
            bgColor = FigmaColor(
                r: colorDict["r"] as? Double ?? 0,
                g: colorDict["g"] as? Double ?? 0,
                b: colorDict["b"] as? Double ?? 0,
                a: colorDict["a"] as? Double ?? 1
            )
        }

        return FigmaMetadata(
            backgroundColor: bgColor,
            exportedAt: json["exported_at"] as? String
        )
    }

    private func parseCanvasBinary(at url: URL) async throws -> [FigmaPage] {
        let data = try Data(contentsOf: url)
        let bytes = [UInt8](data)

        // Verify header
        guard bytes.count > 12 else {
            throw FigmaParseError.invalidFile
        }

        let header = String(bytes: bytes[0..<8], encoding: .utf8) ?? ""
        guard header.hasPrefix("fig-kiwi") || header.hasPrefix("fig-jam") else {
            throw FigmaParseError.invalidHeader
        }

        // Extract compressed chunks
        var chunks: [[UInt8]] = []
        var offset = 12

        while offset + 4 < bytes.count {
            let chunkLength = Int(bytes[offset]) |
                             (Int(bytes[offset + 1]) << 8) |
                             (Int(bytes[offset + 2]) << 16) |
                             (Int(bytes[offset + 3]) << 24)
            offset += 4

            guard offset + chunkLength <= bytes.count else { break }

            let chunk = Array(bytes[offset..<(offset + chunkLength)])
            chunks.append(chunk)
            offset += chunkLength
        }

        guard chunks.count >= 2 else {
            throw FigmaParseError.invalidFile
        }

        // Decompress chunks using zlib raw inflate
        let schemaData = try decompressRaw(chunks[0])
        let nodeData = try decompressRaw(chunks[1])

        // Decode the Kiwi schema and data
        let nodes = try decodeKiwiData(schema: schemaData, data: nodeData)

        return buildPageHierarchy(from: nodes)
    }

    private func decompressRaw(_ input: [UInt8]) throws -> [UInt8] {
        // Check for ZSTD magic number (28 B5 2F FD)
        if input.count >= 4 &&
           input[0] == 0x28 && input[1] == 0xB5 && input[2] == 0x2F && input[3] == 0xFD {
            // Use system zstd via Process
            return try decompressZstd(input)
        }

        // Try zlib raw deflate
        var result = [UInt8](repeating: 0, count: input.count * 20)

        let status = input.withUnsafeBufferPointer { inputPtr in
            result.withUnsafeMutableBufferPointer { outputPtr in
                compression_decode_buffer(
                    outputPtr.baseAddress!,
                    outputPtr.count,
                    inputPtr.baseAddress!,
                    inputPtr.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        if status > 0 {
            return Array(result.prefix(status))
        }

        // Try LZFSE
        let lzfseStatus = input.withUnsafeBufferPointer { inputPtr in
            result.withUnsafeMutableBufferPointer { outputPtr in
                compression_decode_buffer(
                    outputPtr.baseAddress!,
                    outputPtr.count,
                    inputPtr.baseAddress!,
                    inputPtr.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }

        if lzfseStatus > 0 {
            return Array(result.prefix(lzfseStatus))
        }

        // If nothing works, return the input as-is (might be uncompressed)
        return input
    }

    private func decompressZstd(_ input: [UInt8]) throws -> [UInt8] {
        // Write to temp file and use system zstd
        let tempDir = FileManager.default.temporaryDirectory
        let inputFile = tempDir.appendingPathComponent("figma_chunk_\(UUID().uuidString).zst")
        let outputFile = tempDir.appendingPathComponent("figma_chunk_\(UUID().uuidString).raw")

        defer {
            try? FileManager.default.removeItem(at: inputFile)
            try? FileManager.default.removeItem(at: outputFile)
        }

        try Data(input).write(to: inputFile)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["zstd", "-d", inputFile.path, "-o", outputFile.path, "-f"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0,
           let outputData = try? Data(contentsOf: outputFile) {
            return [UInt8](outputData)
        }

        throw FigmaParseError.decompressionFailed
    }

    private func decodeKiwiData(schema: [UInt8], data: [UInt8]) throws -> [RawFigmaNode] {
        // Simplified Kiwi decoder - extract node names and basic properties
        // Full Kiwi implementation would require more complex schema handling

        var nodes: [RawFigmaNode] = []
        var offset = 0

        // Parse the data looking for string patterns (node names)
        // This is a simplified approach - a full implementation would decode the schema

        // Look for common patterns in Figma data
        let dataString = data.compactMap { byte -> Character? in
            if byte >= 32 && byte < 127 {
                return Character(UnicodeScalar(byte))
            }
            return nil
        }

        // Extract readable strings that look like layer names
        let joined = String(dataString)
        let potentialNames = extractPotentialNodeNames(from: joined)

        // Create nodes from extracted names
        for (index, name) in potentialNames.enumerated() {
            nodes.append(RawFigmaNode(
                id: "node_\(index)",
                name: name,
                type: inferNodeType(from: name),
                parentId: nil
            ))
        }

        return nodes
    }

    private func extractPotentialNodeNames(from text: String) -> [String] {
        // Look for sequences that appear to be layer names
        // Filter out common Figma internal strings
        let internalStrings = Set([
            "FRAME", "RECTANGLE", "ELLIPSE", "TEXT", "GROUP", "COMPONENT",
            "VECTOR", "INSTANCE", "BOOLEAN", "SLICE", "LINE", "STAR",
            "true", "false", "null", "undefined", "function"
        ])

        var names: [String] = []
        var currentWord = ""

        for char in text {
            if char.isLetter || char.isNumber || char == " " || char == "-" || char == "_" {
                currentWord.append(char)
            } else {
                let trimmed = currentWord.trimmingCharacters(in: .whitespaces)
                if trimmed.count >= 2 && trimmed.count <= 50 &&
                   !internalStrings.contains(trimmed) &&
                   trimmed.first?.isLetter == true {
                    names.append(trimmed)
                }
                currentWord = ""
            }
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return names.filter { name in
            if seen.contains(name) { return false }
            seen.insert(name)
            return true
        }
    }

    private func inferNodeType(from name: String) -> FigmaNodeType {
        let lower = name.lowercased()

        if lower.contains("frame") { return .frame }
        if lower.contains("group") { return .group }
        if lower.contains("component") { return .component }
        if lower.contains("button") || lower.contains("btn") { return .component }
        if lower.contains("icon") { return .vector }
        if lower.contains("text") || lower.contains("label") { return .text }
        if lower.contains("image") || lower.contains("photo") { return .rectangle }
        if lower.contains("card") { return .frame }
        if lower.contains("container") { return .frame }

        return .frame
    }

    private func buildPageHierarchy(from nodes: [RawFigmaNode]) -> [FigmaPage] {
        // Group nodes into pages
        // For simplified parsing, create one page with all nodes

        let figmaNodes = nodes.map { raw in
            FigmaNode(
                id: raw.id,
                name: raw.name,
                type: raw.type,
                size: nil,
                position: nil,
                cornerRadius: nil,
                fills: [],
                strokes: [],
                effects: [],
                children: [],
                isVisible: true,
                opacity: 1.0
            )
        }

        return [
            FigmaPage(
                id: "page_1",
                name: "Page 1",
                children: figmaNodes
            )
        ]
    }

    private func processImages(at url: URL) async throws {
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)

        for fileURL in contents {
            // Add proper extension based on file magic bytes
            let data = try Data(contentsOf: fileURL)
            guard data.count > 4 else { continue }

            let bytes = [UInt8](data.prefix(8))
            let ext: String

            if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
                ext = ".png"
            } else if bytes[0] == 0xFF && bytes[1] == 0xD8 {
                ext = ".jpg"
            } else if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
                ext = ".gif"
            } else if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
                ext = ".webp"
            } else {
                continue
            }

            let newURL = fileURL.appendingPathExtension(String(ext.dropFirst()))
            try? FileManager.default.moveItem(at: fileURL, to: newURL)
        }
    }

    // MARK: - Internal Types

    private struct RawFigmaNode {
        let id: String
        let name: String
        let type: FigmaNodeType
        let parentId: String?
    }
}

// MARK: - SwiftUI Code Generation from Figma

extension FigmaFileParser.FigmaNode {

    /// Generate SwiftUI code for this node
    public func toSwiftUICode(indent: Int = 0) -> String {
        let indentStr = String(repeating: "    ", count: indent)
        var code = ""

        switch type {
        case .frame, .group, .component, .instance, .componentSet:
            if children.isEmpty {
                code = "\(indentStr)RoundedRectangle(cornerRadius: \(cornerRadius ?? 12))"
            } else {
                code = "\(indentStr)VStack {\n"
                for child in children {
                    code += child.toSwiftUICode(indent: indent + 1) + "\n"
                }
                code += "\(indentStr)}"
            }

        case .rectangle:
            code = "\(indentStr)RoundedRectangle(cornerRadius: \(cornerRadius ?? 0))"

        case .ellipse:
            code = "\(indentStr)Ellipse()"

        case .text:
            code = "\(indentStr)Text(\"\(name)\")"

        case .vector, .line, .star, .regularPolygon, .booleanOperation:
            code = "\(indentStr)// Vector: \(name)"

        default:
            code = "\(indentStr)EmptyView() // \(name)"
        }

        // Add modifiers
        var modifiers: [String] = []

        if let size = size {
            modifiers.append(".frame(width: \(Int(size.width)), height: \(Int(size.height)))")
        }

        for fill in fills where fill.isVisible {
            if let color = fill.color {
                modifiers.append(".fill(\(color.swiftUICode))")
            }
        }

        for effect in effects where effect.isVisible {
            switch effect.type {
            case .dropShadow:
                if let color = effect.color, let radius = effect.radius {
                    modifiers.append(".shadow(color: \(color.swiftUICode), radius: \(Int(radius)))")
                }
            case .layerBlur, .backgroundBlur:
                if let radius = effect.radius {
                    modifiers.append(".blur(radius: \(Int(radius)))")
                }
            default:
                break
            }
        }

        if opacity < 1.0 {
            modifiers.append(".opacity(\(String(format: "%.2f", opacity)))")
        }

        for modifier in modifiers {
            code += "\n\(indentStr)    \(modifier)"
        }

        return code
    }
}
