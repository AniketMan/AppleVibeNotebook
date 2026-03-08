import Foundation
import CoreGraphics

// MARK: - Canvas Document

/// The core document model for CanvasCode — wraps IR with spatial/visual metadata.
/// Follows Procreate's layer-based mental model for intuitive visual design.
public struct CanvasDocument: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var layers: [CanvasLayer]
    public var layerGroups: [LayerGroup]
    public var viewport: CanvasViewport
    public var grid: CanvasGrid
    public var metadata: CanvasMetadata

    public init(
        id: UUID = UUID(),
        name: String = "Untitled Canvas",
        layers: [CanvasLayer] = [],
        layerGroups: [LayerGroup] = [],
        viewport: CanvasViewport = CanvasViewport(),
        grid: CanvasGrid = CanvasGrid(),
        metadata: CanvasMetadata = CanvasMetadata()
    ) {
        self.id = id
        self.name = name
        self.layers = layers
        self.layerGroups = layerGroups
        self.viewport = viewport
        self.grid = grid
        self.metadata = metadata
    }

    // MARK: - Layer Operations

    /// Returns layers in render order (bottom to top)
    public var sortedLayers: [CanvasLayer] {
        layers.sorted { $0.zIndex < $1.zIndex }
    }

    /// Returns only visible layers
    public var visibleLayers: [CanvasLayer] {
        sortedLayers.filter { $0.isVisible }
    }

    /// Adds a new layer at the top of the stack
    public mutating func addLayer(_ layer: CanvasLayer) {
        var newLayer = layer
        newLayer.zIndex = (layers.map(\.zIndex).max() ?? 0) + 1
        layers.append(newLayer)
    }

    /// Removes a layer by ID
    public mutating func removeLayer(id: UUID) {
        layers.removeAll { $0.id == id }
    }

    /// Moves layer to a new z-index position
    public mutating func moveLayer(id: UUID, to newIndex: Int) {
        guard let layerIndex = layers.firstIndex(where: { $0.id == id }) else { return }
        var layer = layers.remove(at: layerIndex)
        layer.zIndex = newIndex

        // Reorder all z-indices
        for i in 0..<layers.count {
            if layers[i].zIndex >= newIndex {
                layers[i].zIndex += 1
            }
        }
        layers.append(layer)
    }

    /// Duplicates a layer
    public mutating func duplicateLayer(id: UUID) -> UUID? {
        guard let layer = layers.first(where: { $0.id == id }) else { return nil }
        var newLayer = layer
        newLayer.id = UUID()
        newLayer.name = "\(layer.name) Copy"
        newLayer.frame.origin.x += 20
        newLayer.frame.origin.y += 20
        addLayer(newLayer)
        return newLayer.id
    }

    /// Merges multiple layers into one
    public mutating func mergeLayers(ids: [UUID]) -> UUID? {
        guard ids.count > 1 else { return nil }
        let layersToMerge = layers.filter { ids.contains($0.id) }.sorted { $0.zIndex < $1.zIndex }
        guard let baseLayer = layersToMerge.first else { return nil }

        // Calculate bounding box
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for layer in layersToMerge {
            minX = min(minX, layer.frame.minX)
            minY = min(minY, layer.frame.minY)
            maxX = max(maxX, layer.frame.maxX)
            maxY = max(maxY, layer.frame.maxY)
        }

        var merged = CanvasLayer(
            name: "Merged Layer",
            frame: CanvasFrame(origin: CGPoint(x: minX, y: minY), size: CGSize(width: maxX - minX, height: maxY - minY)),
            layerType: .group
        )
        merged.children = layersToMerge.map(\.id)
        merged.zIndex = baseLayer.zIndex

        // Remove merged layers
        layers.removeAll { ids.contains($0.id) }
        layers.append(merged)

        return merged.id
    }
}

// MARK: - Canvas Layer

/// A layer on the canvas — the fundamental unit of composition (like Procreate layers).
/// Each layer wraps a ViewNodeIR and adds visual/spatial metadata.
public struct CanvasLayer: Codable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var frame: CanvasFrame
    public var rotation: Double  // Degrees
    public var opacity: Double   // 0.0 - 1.0
    public var blendMode: BlendMode
    public var isVisible: Bool
    public var isLocked: Bool
    public var zIndex: Int
    public var layerType: LayerType

    // IR linkage
    public var viewNodeID: UUID?
    public var componentID: UUID?

    // Hierarchy
    public var parentID: UUID?
    public var children: [UUID]

    // Visual state
    public var thumbnail: Data?
    public var shadowConfig: ShadowConfig?
    public var borderConfig: BorderConfig?
    public var backgroundFill: FillConfig?

    public init(
        id: UUID = UUID(),
        name: String = "Layer",
        frame: CanvasFrame = CanvasFrame(),
        rotation: Double = 0,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        isVisible: Bool = true,
        isLocked: Bool = false,
        zIndex: Int = 0,
        layerType: LayerType = .element,
        viewNodeID: UUID? = nil,
        componentID: UUID? = nil,
        parentID: UUID? = nil,
        children: [UUID] = [],
        thumbnail: Data? = nil,
        shadowConfig: ShadowConfig? = nil,
        borderConfig: BorderConfig? = nil,
        backgroundFill: FillConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.rotation = rotation
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.zIndex = zIndex
        self.layerType = layerType
        self.viewNodeID = viewNodeID
        self.componentID = componentID
        self.parentID = parentID
        self.children = children
        self.thumbnail = thumbnail
        self.shadowConfig = shadowConfig
        self.borderConfig = borderConfig
        self.backgroundFill = backgroundFill
    }

    /// Creates a layer from a ViewNodeIR
    public static func from(viewNode: ViewIR, frame: CanvasFrame) -> CanvasLayer {
        CanvasLayer(
            name: viewNode.viewType.rawValue,
            frame: frame,
            layerType: .element,
            viewNodeID: viewNode.id
        )
    }
}

// MARK: - Layer Type

public enum LayerType: String, Codable, Sendable, CaseIterable {
    case element        // Single UI element (Button, Text, Image, etc.)
    case container      // Layout container (HStack, VStack, ZStack)
    case component      // Reusable component instance
    case group          // User-created layer group
    case artboard       // Top-level artboard (like a Figma frame)
    case mask           // Mask layer
    case shape          // Vector shape
    case text           // Text layer
    case image          // Image layer

    public var icon: String {
        switch self {
        case .element: return "square"
        case .container: return "square.stack.3d.up"
        case .component: return "puzzlepiece.extension"
        case .group: return "folder"
        case .artboard: return "rectangle.on.rectangle"
        case .mask: return "theatermasks"
        case .shape: return "star"
        case .text: return "textformat"
        case .image: return "photo"
        }
    }
}

// MARK: - Blend Mode

public enum BlendMode: String, Codable, Sendable, CaseIterable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge
    case colorBurn
    case softLight
    case hardLight
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity
}

// MARK: - Layer Group

/// Groups multiple layers together (like Procreate layer groups)
public struct LayerGroup: Codable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var layerIDs: [UUID]
    public var isExpanded: Bool
    public var isVisible: Bool
    public var opacity: Double
    public var blendMode: BlendMode

    public init(
        id: UUID = UUID(),
        name: String = "Group",
        layerIDs: [UUID] = [],
        isExpanded: Bool = true,
        isVisible: Bool = true,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal
    ) {
        self.id = id
        self.name = name
        self.layerIDs = layerIDs
        self.isExpanded = isExpanded
        self.isVisible = isVisible
        self.opacity = opacity
        self.blendMode = blendMode
    }
}

// MARK: - Canvas Frame

/// Position and size of a layer on the canvas
public struct CanvasFrame: Codable, Sendable {
    public var origin: CGPoint
    public var size: CGSize
    public var anchor: AnchorPoint

    public init(
        origin: CGPoint = .zero,
        size: CGSize = CGSize(width: 100, height: 100),
        anchor: AnchorPoint = .center
    ) {
        self.origin = origin
        self.size = size
        self.anchor = anchor
    }

    public var minX: CGFloat { origin.x }
    public var minY: CGFloat { origin.y }
    public var maxX: CGFloat { origin.x + size.width }
    public var maxY: CGFloat { origin.y + size.height }
    public var midX: CGFloat { origin.x + size.width / 2 }
    public var midY: CGFloat { origin.y + size.height / 2 }
    public var center: CGPoint { CGPoint(x: midX, y: midY) }

    public var cgRect: CGRect {
        CGRect(origin: origin, size: size)
    }

    public func contains(_ point: CGPoint) -> Bool {
        cgRect.contains(point)
    }

    public func intersects(_ other: CanvasFrame) -> Bool {
        cgRect.intersects(other.cgRect)
    }
}

public enum AnchorPoint: String, Codable, Sendable, CaseIterable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    public var offset: CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: 0, y: 0)
        case .topCenter: return CGPoint(x: 0.5, y: 0)
        case .topRight: return CGPoint(x: 1, y: 0)
        case .centerLeft: return CGPoint(x: 0, y: 0.5)
        case .center: return CGPoint(x: 0.5, y: 0.5)
        case .centerRight: return CGPoint(x: 1, y: 0.5)
        case .bottomLeft: return CGPoint(x: 0, y: 1)
        case .bottomCenter: return CGPoint(x: 0.5, y: 1)
        case .bottomRight: return CGPoint(x: 1, y: 1)
        }
    }
}

// MARK: - Canvas Viewport

/// The visible portion of the infinite canvas
public struct CanvasViewport: Codable, Sendable {
    public var offset: CGPoint     // Pan offset
    public var scale: CGFloat      // Zoom level (1.0 = 100%)
    public var minScale: CGFloat
    public var maxScale: CGFloat
    public var visibleRect: CGRect

    public init(
        offset: CGPoint = .zero,
        scale: CGFloat = 1.0,
        minScale: CGFloat = 0.1,
        maxScale: CGFloat = 10.0,
        visibleRect: CGRect = .zero
    ) {
        self.offset = offset
        self.scale = scale
        self.minScale = minScale
        self.maxScale = maxScale
        self.visibleRect = visibleRect
    }

    /// Converts a screen point to canvas coordinates
    public func screenToCanvas(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - offset.x) / scale,
            y: (screenPoint.y - offset.y) / scale
        )
    }

    /// Converts a canvas point to screen coordinates
    public func canvasToScreen(_ canvasPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: canvasPoint.x * scale + offset.x,
            y: canvasPoint.y * scale + offset.y
        )
    }

    /// Zooms to fit the given rect in the viewport
    public mutating func zoomToFit(_ rect: CGRect, padding: CGFloat = 50) {
        let paddedRect = rect.insetBy(dx: -padding, dy: -padding)
        let scaleX = visibleRect.width / paddedRect.width
        let scaleY = visibleRect.height / paddedRect.height
        scale = min(scaleX, scaleY).clamped(to: minScale...maxScale)

        let centerX = visibleRect.midX - paddedRect.midX * scale
        let centerY = visibleRect.midY - paddedRect.midY * scale
        offset = CGPoint(x: centerX, y: centerY)
    }

    /// Zoom percentage string
    public var zoomPercentage: String {
        "\(Int(scale * 100))%"
    }
}

// MARK: - Canvas Grid

/// Grid configuration for snapping and alignment
public struct CanvasGrid: Codable, Sendable {
    public var isVisible: Bool
    public var spacing: CGFloat
    public var subdivisions: Int
    public var color: CanvasColor
    public var snapToGrid: Bool
    public var snapThreshold: CGFloat

    public init(
        isVisible: Bool = true,
        spacing: CGFloat = 20,
        subdivisions: Int = 4,
        color: CanvasColor = CanvasColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.2),
        snapToGrid: Bool = true,
        snapThreshold: CGFloat = 5
    ) {
        self.isVisible = isVisible
        self.spacing = spacing
        self.subdivisions = subdivisions
        self.color = color
        self.snapToGrid = snapToGrid
        self.snapThreshold = snapThreshold
    }

    /// Snaps a point to the nearest grid intersection
    public func snap(_ point: CGPoint) -> CGPoint {
        guard snapToGrid else { return point }
        let subSpacing = spacing / CGFloat(subdivisions)
        return CGPoint(
            x: (point.x / subSpacing).rounded() * subSpacing,
            y: (point.y / subSpacing).rounded() * subSpacing
        )
    }
}

// MARK: - Canvas Metadata

public struct CanvasMetadata: Codable, Sendable {
    public var createdAt: Date
    public var modifiedAt: Date
    public var author: String
    public var version: String
    public var targetPlatform: TargetPlatform
    public var devicePreset: DevicePreset?

    public init(
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        author: String = "",
        version: String = "1.0.0",
        targetPlatform: TargetPlatform = .swiftUI,
        devicePreset: DevicePreset? = nil
    ) {
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.author = author
        self.version = version
        self.targetPlatform = targetPlatform
        self.devicePreset = devicePreset
    }
}

public enum TargetPlatform: String, Codable, Sendable, CaseIterable {
    case swiftUI = "SwiftUI"
    case react = "React"
    case hybrid = "Hybrid"

    public var icon: String {
        switch self {
        case .swiftUI: return "swift"
        case .react: return "atom"
        case .hybrid: return "arrow.triangle.2.circlepath"
        }
    }
}

public enum DevicePreset: String, Codable, Sendable, CaseIterable {
    case iPhoneSE = "iPhone SE"
    case iPhone15 = "iPhone 15"
    case iPhone15Pro = "iPhone 15 Pro"
    case iPhone15ProMax = "iPhone 15 Pro Max"
    case iPadMini = "iPad mini"
    case iPad = "iPad"
    case iPadPro11 = "iPad Pro 11\""
    case iPadPro13 = "iPad Pro 13\""
    case macBookAir = "MacBook Air"
    case macBookPro14 = "MacBook Pro 14\""
    case macBookPro16 = "MacBook Pro 16\""
    case custom = "Custom"

    public var size: CGSize {
        switch self {
        case .iPhoneSE: return CGSize(width: 375, height: 667)
        case .iPhone15: return CGSize(width: 393, height: 852)
        case .iPhone15Pro: return CGSize(width: 393, height: 852)
        case .iPhone15ProMax: return CGSize(width: 430, height: 932)
        case .iPadMini: return CGSize(width: 744, height: 1133)
        case .iPad: return CGSize(width: 820, height: 1180)
        case .iPadPro11: return CGSize(width: 834, height: 1194)
        case .iPadPro13: return CGSize(width: 1024, height: 1366)
        case .macBookAir: return CGSize(width: 1440, height: 900)
        case .macBookPro14: return CGSize(width: 1512, height: 982)
        case .macBookPro16: return CGSize(width: 1728, height: 1117)
        case .custom: return CGSize(width: 800, height: 600)
        }
    }
}

// MARK: - Visual Configs

public struct ShadowConfig: Codable, Sendable, Equatable {
    public var color: CanvasColor
    public var radius: CGFloat
    public var offset: CGPoint

    public init(
        color: CanvasColor = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.25),
        radius: CGFloat = 10,
        offset: CGPoint = CGPoint(x: 0, y: 4)
    ) {
        self.color = color
        self.radius = radius
        self.offset = offset
    }
}

public struct BorderConfig: Codable, Sendable, Equatable {
    public var color: CanvasColor
    public var width: CGFloat
    public var cornerRadius: CGFloat

    public init(
        color: CanvasColor = CanvasColor(red: 0, green: 0, blue: 0, alpha: 1),
        width: CGFloat = 1,
        cornerRadius: CGFloat = 0
    ) {
        self.color = color
        self.width = width
        self.cornerRadius = cornerRadius
    }
}

public struct FillConfig: Codable, Sendable {
    public var fillType: FillType
    public var color: CanvasColor?
    public var gradient: GradientConfig?
    public var imageData: Data?

    public init(
        fillType: FillType = .solid,
        color: CanvasColor? = nil,
        gradient: GradientConfig? = nil,
        imageData: Data? = nil
    ) {
        self.fillType = fillType
        self.color = color
        self.gradient = gradient
        self.imageData = imageData
    }

    public enum FillType: String, Codable, Sendable {
        case solid, gradient, image, none
    }
}

public struct GradientConfig: Codable, Sendable, Equatable {
    public var type: GradientType
    public var colors: [CanvasColor]
    public var stops: [CGFloat]
    public var startPoint: CGPoint
    public var endPoint: CGPoint

    public enum GradientType: String, Codable, Sendable {
        case linear, radial, angular
    }

    public init(
        type: GradientType = .linear,
        colors: [CanvasColor] = [],
        stops: [CGFloat] = [],
        startPoint: CGPoint = CGPoint(x: 0.5, y: 0),
        endPoint: CGPoint = CGPoint(x: 0.5, y: 1)
    ) {
        self.type = type
        self.colors = colors
        self.stops = stops
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

public struct CanvasColor: Codable, Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = CanvasColor(red: 1, green: 1, blue: 1)
    public static let black = CanvasColor(red: 0, green: 0, blue: 0)
    public static let clear = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let accent = CanvasColor(red: 0.0, green: 0.48, blue: 1.0)
}

// MARK: - Extensions

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
