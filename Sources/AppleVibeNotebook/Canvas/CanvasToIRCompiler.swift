import Foundation
import CoreGraphics

// MARK: - Canvas to IR Compiler

/// Compiles canvas layers into Intermediate Representation.
/// Uses spatial layout heuristics to infer HStack/VStack/ZStack relationships.
public final class CanvasToIRCompiler {

    // Configuration
    public var horizontalThreshold: CGFloat = 20  // Max vertical difference for same row
    public var verticalThreshold: CGFloat = 20    // Max horizontal difference for same column
    public var overlapThreshold: CGFloat = 0.3    // Min overlap ratio for ZStack

    public init() {}

    // MARK: - Main Compilation

    /// Compiles a canvas document to an Intermediate Representation.
    public func compile(_ document: CanvasDocument) -> IntermediateRepresentation {
        let sortedLayers = document.visibleLayers

        // Group layers by containment (parent-child relationships)
        let rootLayers = sortedLayers.filter { $0.parentID == nil }

        // Build component for each root layer or group
        var components: [ComponentIR] = []

        // If there are artboards, each becomes a component
        let artboards = rootLayers.filter { $0.layerType == .artboard }
        if !artboards.isEmpty {
            for artboard in artboards {
                let childLayers = sortedLayers.filter { $0.parentID == artboard.id }
                let viewHierarchy = buildViewHierarchy(from: [artboard] + childLayers)

                let component = ComponentIR(
                    name: sanitizeName(artboard.name),
                    isDefault: artboards.first?.id == artboard.id,
                    sourceLocation: makeSourceLocation(),
                    viewHierarchy: viewHierarchy
                )
                components.append(component)
            }
        } else {
            // Single component from all layers
            let viewHierarchy = buildViewHierarchy(from: rootLayers)
            let component = ComponentIR(
                name: sanitizeName(document.name),
                isDefault: true,
                sourceLocation: makeSourceLocation(),
                viewHierarchy: viewHierarchy
            )
            components.append(component)
        }

        // Build source file
        let sourceFile = SourceFileIR(
            originalPath: "\(document.name).swift",
            components: components,
            imports: [ImportIR(originalModule: "SwiftUI", swiftImport: "SwiftUI", isRequired: true)],
            exports: components.map { ExportIR(name: $0.name, isDefault: $0.isDefault) }
        )

        // Build global styles from design tokens (if available)
        let globalStyles = GlobalStylesIR()

        return IntermediateRepresentation(
            sourceFiles: [sourceFile],
            globalStyles: globalStyles,
            metadata: ConversionMetadata(
                sourceProjectName: document.name,
                sourceProjectPath: ""
            )
        )
    }

    // MARK: - Source Location Helper

    private func makeSourceLocation() -> SourceLocation {
        SourceLocation(filePath: "", startLine: 0, startColumn: 0, endLine: 0, endColumn: 0)
    }

    // MARK: - View Hierarchy Building

    /// Builds a view hierarchy from layers using spatial analysis.
    private func buildViewHierarchy(from layers: [CanvasLayer]) -> ViewNodeIR {
        guard !layers.isEmpty else { return .empty }

        if layers.count == 1 {
            return buildViewNode(from: layers[0])
        }

        // Analyze spatial relationships
        let layoutAnalysis = analyzeLayout(layers)

        switch layoutAnalysis.primaryLayout {
        case .horizontal:
            return buildHStack(from: layers, analysis: layoutAnalysis)
        case .vertical:
            return buildVStack(from: layers, analysis: layoutAnalysis)
        case .stacked:
            return buildZStack(from: layers, analysis: layoutAnalysis)
        case .freeform:
            return buildZStackAbsolute(from: layers)
        }
    }

    /// Builds a view node from a single layer.
    private func buildViewNode(from layer: CanvasLayer) -> ViewNodeIR {
        switch layer.layerType {
        case .text:
            return buildTextNode(from: layer)
        case .image:
            return buildImageNode(from: layer)
        case .shape:
            return buildShapeNode(from: layer)
        case .element, .component:
            return buildElementNode(from: layer)
        case .container, .group:
            return buildContainerNode(from: layer)
        case .artboard:
            return buildArtboardNode(from: layer)
        case .mask:
            return buildMaskNode(from: layer)
        }
    }

    // MARK: - Node Builders

    private func buildTextNode(from layer: CanvasLayer) -> ViewNodeIR {
        let textIR = TextIR(
            content: .literal(layer.name),
            modifiers: buildModifiers(from: layer),
            sourceLocation: makeSourceLocation()
        )
        return .text(textIR)
    }

    private func buildImageNode(from layer: CanvasLayer) -> ViewNodeIR {
        let viewIR = ViewIR(
            viewType: .image,
            initArguments: [InitArgumentIR(label: "systemName", value: .literal("\"photo\""))],
            modifiers: buildModifiers(from: layer),
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildShapeNode(from layer: CanvasLayer) -> ViewNodeIR {
        let cornerRadius = layer.borderConfig?.cornerRadius ?? 0
        let isCircle = cornerRadius >= min(layer.frame.size.width, layer.frame.size.height) / 2

        let viewType: SwiftUIViewType = isCircle ? .circle : .roundedRectangle
        var initArgs: [InitArgumentIR] = []

        if !isCircle && cornerRadius > 0 {
            initArgs.append(InitArgumentIR(label: "cornerRadius", value: .literal("\(Int(cornerRadius))")))
        }

        let viewIR = ViewIR(
            viewType: viewType,
            initArguments: initArgs,
            modifiers: buildModifiers(from: layer),
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildElementNode(from layer: CanvasLayer) -> ViewNodeIR {
        // Map to appropriate SwiftUI view based on component
        // Since we can't use custom types with String enum, use group as container
        let viewIR = ViewIR(
            viewType: .group,
            modifiers: buildModifiers(from: layer),
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildContainerNode(from layer: CanvasLayer) -> ViewNodeIR {
        let viewIR = ViewIR(
            viewType: .vStack,
            modifiers: buildModifiers(from: layer),
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildArtboardNode(from layer: CanvasLayer) -> ViewNodeIR {
        var modifiers = buildModifiers(from: layer)

        // Add frame modifier for artboard size
        modifiers.insert(ModifierIR(
            modifier: .frame,
            arguments: [
                InitArgumentIR(label: "width", value: .literal("\(Int(layer.frame.size.width))")),
                InitArgumentIR(label: "height", value: .literal("\(Int(layer.frame.size.height))"))
            ]
        ), at: 0)

        let viewIR = ViewIR(
            viewType: .vStack,
            modifiers: modifiers,
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildMaskNode(from layer: CanvasLayer) -> ViewNodeIR {
        let viewIR = ViewIR(
            viewType: .rectangle,
            modifiers: buildModifiers(from: layer),
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    // MARK: - Stack Builders

    private func buildHStack(from layers: [CanvasLayer], analysis: LayoutAnalysis) -> ViewNodeIR {
        let sortedLayers = layers.sorted { $0.frame.origin.x < $1.frame.origin.x }
        let children = sortedLayers.map { buildViewNode(from: $0) }

        let spacing = analysis.suggestedSpacing
        var initArgs: [InitArgumentIR] = []
        if spacing > 0 {
            initArgs.append(InitArgumentIR(label: "spacing", value: .literal("\(Int(spacing))")))
        }

        let viewIR = ViewIR(
            viewType: .hStack,
            initArguments: initArgs,
            children: children,
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildVStack(from layers: [CanvasLayer], analysis: LayoutAnalysis) -> ViewNodeIR {
        let sortedLayers = layers.sorted { $0.frame.origin.y < $1.frame.origin.y }
        let children = sortedLayers.map { buildViewNode(from: $0) }

        let spacing = analysis.suggestedSpacing
        var initArgs: [InitArgumentIR] = []
        if spacing > 0 {
            initArgs.append(InitArgumentIR(label: "spacing", value: .literal("\(Int(spacing))")))
        }

        let viewIR = ViewIR(
            viewType: .vStack,
            initArguments: initArgs,
            children: children,
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildZStack(from layers: [CanvasLayer], analysis: LayoutAnalysis) -> ViewNodeIR {
        let sortedLayers = layers.sorted { $0.zIndex < $1.zIndex }
        let children = sortedLayers.map { buildViewNode(from: $0) }

        let viewIR = ViewIR(
            viewType: .zStack,
            children: children,
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    private func buildZStackAbsolute(from layers: [CanvasLayer]) -> ViewNodeIR {
        let sortedLayers = layers.sorted { $0.zIndex < $1.zIndex }
        let children = sortedLayers.map { layer -> ViewNodeIR in
            let baseNode = buildViewNode(from: layer)

            // Add position modifier for absolute positioning
            if case .view(let viewIR) = baseNode {
                var updatedModifiers = viewIR.modifiers
                updatedModifiers.append(ModifierIR(
                    modifier: .position,
                    arguments: [
                        InitArgumentIR(label: "x", value: .literal("\(Int(layer.frame.midX))")),
                        InitArgumentIR(label: "y", value: .literal("\(Int(layer.frame.midY))"))
                    ]
                ))

                // Create a new ViewIR with the updated modifiers
                let updatedViewIR = ViewIR(
                    id: viewIR.id,
                    viewType: viewIR.viewType,
                    initArguments: viewIR.initArguments,
                    modifiers: updatedModifiers,
                    children: viewIR.children,
                    sourceLocation: viewIR.sourceLocation,
                    conversionTier: viewIR.conversionTier
                )
                return .view(updatedViewIR)
            }

            return baseNode
        }

        let viewIR = ViewIR(
            viewType: .zStack,
            children: children,
            sourceLocation: makeSourceLocation()
        )
        return .view(viewIR)
    }

    // MARK: - Modifier Building

    private func buildModifiers(from layer: CanvasLayer) -> [ModifierIR] {
        var modifiers: [ModifierIR] = []

        // Frame
        modifiers.append(ModifierIR(
            modifier: .frame,
            arguments: [
                InitArgumentIR(label: "width", value: .literal("\(Int(layer.frame.size.width))")),
                InitArgumentIR(label: "height", value: .literal("\(Int(layer.frame.size.height))"))
            ]
        ))

        // Background
        if let fill = layer.backgroundFill, fill.fillType == .solid, let color = fill.color {
            let colorCode = colorToSwiftUI(color)
            modifiers.append(ModifierIR(
                modifier: .background,
                arguments: [InitArgumentIR(value: .literal(colorCode))]
            ))
        }

        // Corner radius
        if let border = layer.borderConfig, border.cornerRadius > 0 {
            modifiers.append(ModifierIR(
                modifier: .cornerRadius,
                arguments: [InitArgumentIR(value: .literal("\(Int(border.cornerRadius))"))]
            ))
        }

        // Border
        if let border = layer.borderConfig, border.width > 0 {
            let colorCode = colorToSwiftUI(border.color)
            modifiers.append(ModifierIR(
                modifier: .overlay,
                arguments: [InitArgumentIR(value: .literal(
                    "RoundedRectangle(cornerRadius: \(Int(border.cornerRadius))).stroke(\(colorCode), lineWidth: \(Int(border.width)))"
                ))]
            ))
        }

        // Shadow
        if let shadow = layer.shadowConfig, shadow.radius > 0 {
            modifiers.append(ModifierIR(
                modifier: .shadow,
                arguments: [
                    InitArgumentIR(label: "radius", value: .literal("\(Int(shadow.radius))")),
                    InitArgumentIR(label: "x", value: .literal("\(Int(shadow.offset.x))")),
                    InitArgumentIR(label: "y", value: .literal("\(Int(shadow.offset.y))"))
                ]
            ))
        }

        // Opacity
        if layer.opacity < 1.0 {
            modifiers.append(ModifierIR(
                modifier: .opacity,
                arguments: [InitArgumentIR(value: .literal(String(format: "%.2f", layer.opacity)))]
            ))
        }

        // Rotation
        if layer.rotation != 0 {
            modifiers.append(ModifierIR(
                modifier: .rotationEffect,
                arguments: [InitArgumentIR(value: .literal(".degrees(\(Int(layer.rotation)))"))]
            ))
        }

        return modifiers
    }

    // MARK: - Layout Analysis

    private func analyzeLayout(_ layers: [CanvasLayer]) -> LayoutAnalysis {
        guard layers.count >= 2 else {
            return LayoutAnalysis(primaryLayout: .freeform, suggestedSpacing: 0)
        }

        // Check for overlaps
        var hasSignificantOverlap = false
        for i in 0..<layers.count {
            for j in (i+1)..<layers.count {
                if calculateOverlap(layers[i].frame, layers[j].frame) > overlapThreshold {
                    hasSignificantOverlap = true
                    break
                }
            }
        }

        if hasSignificantOverlap {
            return LayoutAnalysis(primaryLayout: .stacked, suggestedSpacing: 0)
        }

        // Check for horizontal alignment
        let sortedByX = layers.sorted { $0.frame.origin.x < $1.frame.origin.x }
        var isHorizontal = true
        var horizontalSpacings: [CGFloat] = []

        for i in 0..<(sortedByX.count - 1) {
            let current = sortedByX[i]
            let next = sortedByX[i + 1]

            // Check if vertically aligned
            let yDiff = abs(current.frame.midY - next.frame.midY)
            if yDiff > horizontalThreshold {
                isHorizontal = false
                break
            }

            horizontalSpacings.append(next.frame.minX - current.frame.maxX)
        }

        if isHorizontal {
            let avgSpacing = horizontalSpacings.isEmpty ? 0 : horizontalSpacings.reduce(0, +) / CGFloat(horizontalSpacings.count)
            return LayoutAnalysis(primaryLayout: .horizontal, suggestedSpacing: max(0, avgSpacing))
        }

        // Check for vertical alignment
        let sortedByY = layers.sorted { $0.frame.origin.y < $1.frame.origin.y }
        var isVertical = true
        var verticalSpacings: [CGFloat] = []

        for i in 0..<(sortedByY.count - 1) {
            let current = sortedByY[i]
            let next = sortedByY[i + 1]

            // Check if horizontally aligned
            let xDiff = abs(current.frame.midX - next.frame.midX)
            if xDiff > verticalThreshold {
                isVertical = false
                break
            }

            verticalSpacings.append(next.frame.minY - current.frame.maxY)
        }

        if isVertical {
            let avgSpacing = verticalSpacings.isEmpty ? 0 : verticalSpacings.reduce(0, +) / CGFloat(verticalSpacings.count)
            return LayoutAnalysis(primaryLayout: .vertical, suggestedSpacing: max(0, avgSpacing))
        }

        return LayoutAnalysis(primaryLayout: .freeform, suggestedSpacing: 0)
    }

    private func calculateOverlap(_ frame1: CanvasFrame, _ frame2: CanvasFrame) -> CGFloat {
        let intersection = frame1.cgRect.intersection(frame2.cgRect)
        if intersection.isNull { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let smallerArea = min(
            frame1.size.width * frame1.size.height,
            frame2.size.width * frame2.size.height
        )

        return intersectionArea / smallerArea
    }

    // MARK: - Helpers

    private func sanitizeName(_ name: String) -> String {
        var result = name.replacingOccurrences(of: " ", with: "")
        result = result.replacingOccurrences(of: "-", with: "")

        // Ensure starts with uppercase letter
        if let first = result.first, first.isLowercase {
            result = first.uppercased() + result.dropFirst()
        }

        // Remove non-alphanumeric characters
        result = result.filter { $0.isLetter || $0.isNumber }

        return result.isEmpty ? "View" : result
    }

    private func colorToSwiftUI(_ color: CanvasColor) -> String {
        if color.red == 0 && color.green == 0 && color.blue == 0 {
            return color.alpha == 1 ? "Color.black" : "Color.black.opacity(\(String(format: "%.2f", color.alpha)))"
        }
        if color.red == 1 && color.green == 1 && color.blue == 1 {
            return color.alpha == 1 ? "Color.white" : "Color.white.opacity(\(String(format: "%.2f", color.alpha)))"
        }

        // Check for accent color
        if abs(color.red - 0) < 0.01 && abs(color.green - 0.48) < 0.01 && abs(color.blue - 1) < 0.01 {
            return "Color.accentColor"
        }

        return "Color(red: \(String(format: "%.3f", color.red)), green: \(String(format: "%.3f", color.green)), blue: \(String(format: "%.3f", color.blue)))"
    }
}

// MARK: - Layout Analysis Result

struct LayoutAnalysis {
    enum LayoutType {
        case horizontal
        case vertical
        case stacked
        case freeform
    }

    let primaryLayout: LayoutType
    let suggestedSpacing: CGFloat
}
