import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Image Asset Importer

/// Imports images and generates SwiftUI code with proper asset catalog integration.
/// Supports PNG, JPEG, WebP, PDF vectors, and generates @2x/@3x variants.
public final class ImageAssetImporter {

    // MARK: - Types

    public struct ImportedAsset: Sendable {
        public let name: String
        public let originalURL: URL
        public let type: AssetType
        public let dimensions: CGSize?
        public let colorSpace: String?
        public let hasAlpha: Bool
        public let generatedCode: String
    }

    public enum AssetType: String, Sendable {
        case raster = "Raster Image"
        case vector = "Vector (PDF/SVG)"
        case appIcon = "App Icon"
        case symbol = "SF Symbol Compatible"
    }

    public struct ImportOptions: Sendable {
        public var generateScaleVariants: Bool = true
        public var preserveVector: Bool = true
        public var templateRenderMode: Bool = false
        public var resizingMode: ResizingMode = .stretch
        public var targetDirectory: URL?

        public enum ResizingMode: String, Sendable {
            case stretch = "stretch"
            case tile = "tile"
            case sliced = "sliced"
        }

        public init() {}
    }

    public enum ImportError: Error, LocalizedError {
        case unsupportedFormat(String)
        case invalidImage
        case fileNotFound
        case processingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let fmt): return "Unsupported image format: \(fmt)"
            case .invalidImage: return "Could not read image file"
            case .fileNotFound: return "Image file not found"
            case .processingFailed(let msg): return "Processing failed: \(msg)"
            }
        }
    }

    // MARK: - Properties

    private let supportedRasterFormats = ["png", "jpg", "jpeg", "webp", "heic", "gif"]
    private let supportedVectorFormats = ["pdf", "svg"]

    // MARK: - Public API

    public init() {}

    /// Import a single image file
    public func importImage(at url: URL, options: ImportOptions = ImportOptions()) throws -> ImportedAsset {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportError.fileNotFound
        }

        let ext = url.pathExtension.lowercased()
        let name = sanitizeAssetName(url.deletingPathExtension().lastPathComponent)

        if supportedVectorFormats.contains(ext) {
            return try importVectorAsset(at: url, name: name, options: options)
        } else if supportedRasterFormats.contains(ext) {
            return try importRasterAsset(at: url, name: name, options: options)
        } else {
            throw ImportError.unsupportedFormat(ext)
        }
    }

    /// Import multiple images
    public func importImages(at urls: [URL], options: ImportOptions = ImportOptions()) throws -> [ImportedAsset] {
        try urls.map { try importImage(at: $0, options: options) }
    }

    /// Generate Asset Catalog structure
    public func generateAssetCatalog(for assets: [ImportedAsset], catalogName: String = "Assets") -> String {
        var structure = """
        // Asset Catalog Structure for \(catalogName).xcassets
        //
        // \(catalogName).xcassets/
        """

        for asset in assets {
            structure += """

            // ├── \(asset.name).imageset/
            // │   ├── Contents.json
            """

            if asset.type == .raster {
                structure += """

                // │   ├── \(asset.name).png
                // │   ├── \(asset.name)@2x.png
                // │   └── \(asset.name)@3x.png
                """
            } else {
                structure += """

                // │   └── \(asset.name).pdf (or .svg)
                """
            }
        }

        return structure
    }

    // MARK: - Private Methods

    private func importRasterAsset(at url: URL, name: String, options: ImportOptions) throws -> ImportedAsset {
        #if canImport(AppKit)
        guard let image = NSImage(contentsOf: url) else {
            throw ImportError.invalidImage
        }

        let dimensions = image.size
        var hasAlpha = false
        var colorSpace = "sRGB"

        if let rep = image.representations.first as? NSBitmapImageRep {
            hasAlpha = rep.hasAlpha
            colorSpace = rep.colorSpaceName.rawValue
        }

        let code = generateRasterImageCode(
            name: name,
            dimensions: dimensions,
            options: options
        )

        return ImportedAsset(
            name: name,
            originalURL: url,
            type: .raster,
            dimensions: dimensions,
            colorSpace: colorSpace,
            hasAlpha: hasAlpha,
            generatedCode: code
        )
        #else
        let code = generateRasterImageCode(name: name, dimensions: nil, options: options)
        return ImportedAsset(
            name: name,
            originalURL: url,
            type: .raster,
            dimensions: nil,
            colorSpace: nil,
            hasAlpha: false,
            generatedCode: code
        )
        #endif
    }

    private func importVectorAsset(at url: URL, name: String, options: ImportOptions) throws -> ImportedAsset {
        let ext = url.pathExtension.lowercased()

        let code: String
        if ext == "svg" {
            code = generateSVGCode(name: name, url: url, options: options)
        } else {
            code = generatePDFVectorCode(name: name, options: options)
        }

        return ImportedAsset(
            name: name,
            originalURL: url,
            type: .vector,
            dimensions: nil,
            colorSpace: nil,
            hasAlpha: true,
            generatedCode: code
        )
    }

    private func generateRasterImageCode(name: String, dimensions: CGSize?, options: ImportOptions) -> String {
        let frameMod = dimensions.map {
            "\n        .frame(width: \(Int($0.width)), height: \(Int($0.height)))"
        } ?? ""

        let templateMod = options.templateRenderMode ?
            "\n        .renderingMode(.template)" : ""

        let resizableMod: String
        switch options.resizingMode {
        case .stretch:
            resizableMod = "\n        .resizable()"
        case .tile:
            resizableMod = "\n        .resizable(resizingMode: .tile)"
        case .sliced:
            resizableMod = "\n        .resizable(capInsets: EdgeInsets())"
        }

        return """
        import SwiftUI

        // MARK: - \(name) Image

        /// Image asset: \(name)
        /// - Loaded from Asset Catalog
        /// - Supports template rendering for dynamic tinting
        struct \(name)Image: View {
            var tintColor: Color? = nil
            var contentMode: ContentMode = .fit

            var body: some View {
                Image("\(name)")\(templateMod)\(resizableMod)
                    .aspectRatio(contentMode: contentMode)\(frameMod)
                    .foregroundStyle(tintColor ?? .primary)
            }
        }

        // MARK: - Convenience Extensions

        extension Image {
            /// Quick access to \(name) image
            static var \(name.lowercasedFirst): Image {
                Image("\(name)")
            }
        }

        // MARK: - Asset Catalog Contents.json

        /*
        {
          "images" : [
            {
              "filename" : "\(name).png",
              "idiom" : "universal",
              "scale" : "1x"
            },
            {
              "filename" : "\(name)@2x.png",
              "idiom" : "universal",
              "scale" : "2x"
            },
            {
              "filename" : "\(name)@3x.png",
              "idiom" : "universal",
              "scale" : "3x"
            }
          ],
          "info" : {
            "author" : "React2SwiftUI",
            "version" : 1
          },
          "properties" : {
            "template-rendering-intent" : "\(options.templateRenderMode ? "template" : "original")"
          }
        }
        */

        #Preview {
            VStack(spacing: 20) {
                \(name)Image()

                \(name)Image(tintColor: .blue)

                \(name)Image(tintColor: .red, contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }
            .padding()
        }
        """
    }

    private func generateSVGCode(name: String, url: URL, options: ImportOptions) -> String {
        return """
        import SwiftUI

        // MARK: - \(name) Vector Image

        /// Vector asset: \(name)
        /// Imported from SVG - use SVGParser for full path conversion
        /// This generates a template-mode image that responds to foregroundStyle

        struct \(name)Vector: View {
            var color: Color = .primary
            var size: CGSize = CGSize(width: 24, height: 24)

            var body: some View {
                // Option 1: Use as Image asset (add SVG to asset catalog)
                Image("\(name)")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .foregroundStyle(color)
            }
        }

        // MARK: - SF Symbol Style Usage

        /// For SF Symbol-like behavior, convert SVG to SwiftUI Shape
        /// Use SVGParser.toSwiftUIShape() for automatic conversion

        extension \(name)Vector {
            /// Create with semantic color
            static func primary(size: CGFloat = 24) -> \(name)Vector {
                \(name)Vector(color: .primary, size: CGSize(width: size, height: size))
            }

            /// Create with accent color
            static func accent(size: CGFloat = 24) -> \(name)Vector {
                \(name)Vector(color: .accentColor, size: CGSize(width: size, height: size))
            }
        }

        // MARK: - Asset Catalog Contents.json (for SVG)

        /*
        {
          "images" : [
            {
              "filename" : "\(name).svg",
              "idiom" : "universal"
            }
          ],
          "info" : {
            "author" : "React2SwiftUI",
            "version" : 1
          },
          "properties" : {
            "preserves-vector-representation" : true,
            "template-rendering-intent" : "template"
          }
        }
        */

        #Preview {
            HStack(spacing: 20) {
                \(name)Vector.primary()
                \(name)Vector(color: .blue, size: CGSize(width: 32, height: 32))
                \(name)Vector(color: .red, size: CGSize(width: 48, height: 48))
            }
            .padding()
        }
        """
    }

    private func generatePDFVectorCode(name: String, options: ImportOptions) -> String {
        return """
        import SwiftUI

        // MARK: - \(name) PDF Vector

        /// Vector asset: \(name)
        /// Imported from PDF - preserves vector data for crisp rendering at any size
        /// Template mode enabled for dynamic color tinting

        struct \(name)Vector: View {
            var color: Color = .primary
            var size: CGFloat? = nil

            var body: some View {
                Image("\(name)")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundStyle(color)
            }
        }

        // MARK: - Parameterized Variants

        extension \(name)Vector {
            /// Small size (16pt)
            static var small: \(name)Vector { \(name)Vector(size: 16) }

            /// Medium size (24pt)
            static var medium: \(name)Vector { \(name)Vector(size: 24) }

            /// Large size (32pt)
            static var large: \(name)Vector { \(name)Vector(size: 32) }

            /// Custom colored variant
            func colored(_ color: Color) -> \(name)Vector {
                var copy = self
                copy.color = color
                return copy
            }
        }

        // MARK: - Asset Catalog Contents.json (for PDF)

        /*
        {
          "images" : [
            {
              "filename" : "\(name).pdf",
              "idiom" : "universal"
            }
          ],
          "info" : {
            "author" : "React2SwiftUI",
            "version" : 1
          },
          "properties" : {
            "preserves-vector-representation" : true,
            "template-rendering-intent" : "template"
          }
        }
        */

        #Preview {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    \(name)Vector.small
                    \(name)Vector.medium
                    \(name)Vector.large
                }

                HStack(spacing: 20) {
                    \(name)Vector.medium.colored(.blue)
                    \(name)Vector.medium.colored(.green)
                    \(name)Vector.medium.colored(.orange)
                }
            }
            .padding()
        }
        """
    }

    private func sanitizeAssetName(_ name: String) -> String {
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

        return result.isEmpty ? "Asset" : result
    }
}

// MARK: - String Extension

private extension String {
    var lowercasedFirst: String {
        guard let first = first else { return self }
        return first.lowercased() + dropFirst()
    }
}
