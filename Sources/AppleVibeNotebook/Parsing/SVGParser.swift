import Foundation
import CoreGraphics

// MARK: - SVG Parser

/// Parses SVG files and extracts paths, shapes, and styling for conversion to SwiftUI.
/// Generates parameterized SwiftUI code that follows Apple's design guidelines.
public final class SVGParser: NSObject, XMLParserDelegate {

    // MARK: - Types

    public struct SVGDocument {
        public let viewBox: SVGViewBox?
        public let width: Double?
        public let height: Double?
        public let paths: [SVGPathData]
        public let rects: [SVGRectData]
        public let circles: [SVGCircleData]
        public let ellipses: [SVGEllipseData]
    }

    public struct SVGViewBox {
        public let minX: Double
        public let minY: Double
        public let width: Double
        public let height: Double
    }

    public struct SVGPathData {
        public let id: String?
        public let d: String
        public let fill: String?
        public let stroke: String?
        public let strokeWidth: Double?
        public let opacity: Double?
        public let transform: String?
    }

    public struct SVGRectData {
        public let id: String?
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
        public let rx: Double?
        public let ry: Double?
        public let fill: String?
        public let stroke: String?
        public let strokeWidth: Double?
    }

    public struct SVGCircleData {
        public let id: String?
        public let cx: Double
        public let cy: Double
        public let r: Double
        public let fill: String?
        public let stroke: String?
        public let strokeWidth: Double?
    }

    public struct SVGEllipseData {
        public let id: String?
        public let cx: Double
        public let cy: Double
        public let rx: Double
        public let ry: Double
        public let fill: String?
        public let stroke: String?
        public let strokeWidth: Double?
    }

    public enum ParseError: Error, LocalizedError {
        case invalidFile
        case parseError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidFile: return "Not a valid SVG file"
            case .parseError(let msg): return "SVG parse error: \(msg)"
            }
        }
    }

    // MARK: - Parsing State

    private var paths: [SVGPathData] = []
    private var rects: [SVGRectData] = []
    private var circles: [SVGCircleData] = []
    private var ellipses: [SVGEllipseData] = []
    private var viewBox: SVGViewBox?
    private var width: Double?
    private var height: Double?
    private var parseError: Error?

    // MARK: - Public API

    public override init() {
        super.init()
    }

    /// Parse an SVG file from URL
    public func parse(fileURL: URL) throws -> SVGDocument {
        let data = try Data(contentsOf: fileURL)
        return try parse(data: data)
    }

    /// Parse SVG from string
    public func parse(string: String) throws -> SVGDocument {
        guard let data = string.data(using: .utf8) else {
            throw ParseError.invalidFile
        }
        return try parse(data: data)
    }

    /// Parse SVG from data
    public func parse(data: Data) throws -> SVGDocument {
        paths = []
        rects = []
        circles = []
        ellipses = []
        viewBox = nil
        width = nil
        height = nil
        parseError = nil

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        if let error = parseError {
            throw error
        }

        return SVGDocument(
            viewBox: viewBox,
            width: width,
            height: height,
            paths: paths,
            rects: rects,
            circles: circles,
            ellipses: ellipses
        )
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes: [String: String]) {
        switch elementName.lowercased() {
        case "svg":
            parseSVGRoot(attributes)
        case "path":
            if let path = parsePath(attributes) {
                paths.append(path)
            }
        case "rect":
            if let rect = parseRect(attributes) {
                rects.append(rect)
            }
        case "circle":
            if let circle = parseCircle(attributes) {
                circles.append(circle)
            }
        case "ellipse":
            if let ellipse = parseEllipse(attributes) {
                ellipses.append(ellipse)
            }
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = ParseError.parseError(error.localizedDescription)
    }

    // MARK: - Private Parsing

    private func parseSVGRoot(_ attrs: [String: String]) {
        if let vb = attrs["viewBox"] {
            let parts = vb.split(separator: " ").compactMap { Double($0) }
            if parts.count == 4 {
                viewBox = SVGViewBox(minX: parts[0], minY: parts[1], width: parts[2], height: parts[3])
            }
        }
        width = parseLength(attrs["width"])
        height = parseLength(attrs["height"])
    }

    private func parsePath(_ attrs: [String: String]) -> SVGPathData? {
        guard let d = attrs["d"] else { return nil }
        return SVGPathData(
            id: attrs["id"],
            d: d,
            fill: attrs["fill"],
            stroke: attrs["stroke"],
            strokeWidth: parseLength(attrs["stroke-width"]),
            opacity: parseLength(attrs["opacity"]),
            transform: attrs["transform"]
        )
    }

    private func parseRect(_ attrs: [String: String]) -> SVGRectData? {
        let x = parseLength(attrs["x"]) ?? 0
        let y = parseLength(attrs["y"]) ?? 0
        let w = parseLength(attrs["width"]) ?? 0
        let h = parseLength(attrs["height"]) ?? 0

        return SVGRectData(
            id: attrs["id"],
            x: x, y: y, width: w, height: h,
            rx: parseLength(attrs["rx"]),
            ry: parseLength(attrs["ry"]),
            fill: attrs["fill"],
            stroke: attrs["stroke"],
            strokeWidth: parseLength(attrs["stroke-width"])
        )
    }

    private func parseCircle(_ attrs: [String: String]) -> SVGCircleData? {
        let cx = parseLength(attrs["cx"]) ?? 0
        let cy = parseLength(attrs["cy"]) ?? 0
        let r = parseLength(attrs["r"]) ?? 0

        return SVGCircleData(
            id: attrs["id"],
            cx: cx, cy: cy, r: r,
            fill: attrs["fill"],
            stroke: attrs["stroke"],
            strokeWidth: parseLength(attrs["stroke-width"])
        )
    }

    private func parseEllipse(_ attrs: [String: String]) -> SVGEllipseData? {
        let cx = parseLength(attrs["cx"]) ?? 0
        let cy = parseLength(attrs["cy"]) ?? 0
        let rx = parseLength(attrs["rx"]) ?? 0
        let ry = parseLength(attrs["ry"]) ?? 0

        return SVGEllipseData(
            id: attrs["id"],
            cx: cx, cy: cy, rx: rx, ry: ry,
            fill: attrs["fill"],
            stroke: attrs["stroke"],
            strokeWidth: parseLength(attrs["stroke-width"])
        )
    }

    private func parseLength(_ value: String?) -> Double? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "px", with: "")
            .replacingOccurrences(of: "pt", with: "")
        return Double(trimmed)
    }
}

// MARK: - SwiftUI Code Generation

extension SVGParser.SVGDocument {

    /// Generate a parameterized SwiftUI Shape from this SVG
    public func toSwiftUIShape(name: String = "SVGShape") -> String {
        let vbWidth = viewBox?.width ?? 100
        let vbHeight = viewBox?.height ?? 100

        var code = """
        import SwiftUI

        /// Parameterized SwiftUI Shape generated from SVG
        /// Supports dynamic fill, stroke, and sizing via SwiftUI modifiers
        struct \(name): Shape {
            func path(in rect: CGRect) -> Path {
                var path = Path()
                let scaleX = rect.width / \(vbWidth)
                let scaleY = rect.height / \(vbHeight)
                let scale = min(scaleX, scaleY)

        """

        for rect in rects {
            if let rx = rect.rx, rx > 0 {
                code += "        path.addRoundedRect(in: CGRect(x: \(rect.x) * scale, y: \(rect.y) * scale, width: \(rect.width) * scale, height: \(rect.height) * scale), cornerSize: CGSize(width: \(rx) * scale, height: \(rect.ry ?? rx) * scale))\n"
            } else {
                code += "        path.addRect(CGRect(x: \(rect.x) * scale, y: \(rect.y) * scale, width: \(rect.width) * scale, height: \(rect.height) * scale))\n"
            }
        }

        for circle in circles {
            code += "        path.addEllipse(in: CGRect(x: (\(circle.cx) - \(circle.r)) * scale, y: (\(circle.cy) - \(circle.r)) * scale, width: \(circle.r * 2) * scale, height: \(circle.r * 2) * scale))\n"
        }

        for ellipse in ellipses {
            code += "        path.addEllipse(in: CGRect(x: (\(ellipse.cx) - \(ellipse.rx)) * scale, y: (\(ellipse.cy) - \(ellipse.ry)) * scale, width: \(ellipse.rx * 2) * scale, height: \(ellipse.ry * 2) * scale))\n"
        }

        for (index, pathData) in paths.enumerated() {
            code += "        // Path \(index + 1): \(pathData.id ?? "unnamed")\n"
            code += "        // TODO: Parse path data: \(pathData.d.prefix(50))...\n"
        }

        code += """

                return path
            }
        }

        #Preview {
            VStack(spacing: 20) {
                \(name)()
                    .fill(.blue)
                    .frame(width: 100, height: 100)

                \(name)()
                    .stroke(.red, lineWidth: 2)
                    .frame(width: 100, height: 100)
            }
            .padding()
        }
        """

        return code
    }
}
