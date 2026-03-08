import Foundation
import CoreGraphics

// MARK: - Code to Canvas Compiler

/// Compiles SwiftUI or React code into canvas layers.
/// Enables bidirectional sync: canvas ↔ code.
public final class CodeToCanvasCompiler {

    public enum SourceLanguage {
        case swiftUI
        case react
    }

    private let language: SourceLanguage

    public init(language: SourceLanguage = .swiftUI) {
        self.language = language
    }

    // MARK: - Main Compilation

    /// Compiles IR into a canvas document.
    public func compile(_ ir: IntermediateRepresentation, into document: inout CanvasDocument) {
        // Clear existing layers or merge based on strategy
        document.layers.removeAll()

        var yOffset: CGFloat = 0

        for sourceFile in ir.sourceFiles {
            for component in sourceFile.components {
                let layers = compileComponent(component, startingAt: CGPoint(x: 100, y: yOffset))
                for layer in layers {
                    document.addLayer(layer)
                }

                // Calculate next component position
                if let lastLayer = layers.last {
                    yOffset = lastLayer.frame.maxY + 100
                }
            }
        }
    }

    /// Compiles a single component into canvas layers.
    public func compileComponent(_ component: ComponentIR, startingAt origin: CGPoint) -> [CanvasLayer] {
        var layers: [CanvasLayer] = []

        // Create artboard for the component
        var artboard = CanvasLayer(
            name: component.name,
            frame: CanvasFrame(
                origin: origin,
                size: CGSize(width: 393, height: 852) // iPhone 15 default
            ),
            layerType: .artboard,
            backgroundFill: FillConfig(fillType: .solid, color: .white)
        )
        artboard.componentID = component.id
        layers.append(artboard)

        // Compile view hierarchy
        let childLayers = compileViewNode(
            component.viewHierarchy,
            parentID: artboard.id,
            bounds: CGRect(
                origin: CGPoint(x: origin.x + 16, y: origin.y + 16),
                size: CGSize(width: 393 - 32, height: 852 - 32)
            ),
            zIndex: 1
        )
        layers.append(contentsOf: childLayers)

        return layers
    }

    // MARK: - View Node Compilation

    private func compileViewNode(
        _ node: ViewNodeIR,
        parentID: UUID?,
        bounds: CGRect,
        zIndex: Int
    ) -> [CanvasLayer] {
        switch node {
        case .view(let viewIR):
            return compileView(viewIR, parentID: parentID, bounds: bounds, zIndex: zIndex)
        case .text(let textIR):
            return compileText(textIR, parentID: parentID, bounds: bounds, zIndex: zIndex)
        case .conditional(let conditionalIR):
            return compileConditional(conditionalIR, parentID: parentID, bounds: bounds, zIndex: zIndex)
        case .loop(let loopIR):
            return compileLoop(loopIR, parentID: parentID, bounds: bounds, zIndex: zIndex)
        case .group(let children):
            return compileGroup(children, parentID: parentID, bounds: bounds, zIndex: zIndex)
        case .empty:
            return []
        case .unsupported:
            return []
        }
    }

    private func compileView(
        _ view: ViewIR,
        parentID: UUID?,
        bounds: CGRect,
        zIndex: Int
    ) -> [CanvasLayer] {
        var layers: [CanvasLayer] = []

        // Extract frame from modifiers
        let frame = extractFrame(from: view.modifiers, defaultBounds: bounds)

        // Create layer based on view type
        var layer = CanvasLayer(
            name: viewTypeName(view.viewType),
            frame: CanvasFrame(origin: frame.origin, size: frame.size),
            zIndex: zIndex,
            layerType: viewTypeToLayerType(view.viewType)
        )
        layer.parentID = parentID
        layer.viewNodeID = view.id

        // Apply visual modifiers
        applyModifiers(view.modifiers, to: &layer)

        layers.append(layer)

        // Compile children
        if !view.children.isEmpty {
            let childBounds = CGRect(
                origin: CGPoint(x: frame.minX + 8, y: frame.minY + 8),
                size: CGSize(width: frame.width - 16, height: frame.height - 16)
            )

            switch view.viewType {
            case .hStack:
                layers.append(contentsOf: compileHStackChildren(view.children, parentID: layer.id, bounds: childBounds, startingZIndex: zIndex + 1))
            case .vStack:
                layers.append(contentsOf: compileVStackChildren(view.children, parentID: layer.id, bounds: childBounds, startingZIndex: zIndex + 1))
            case .zStack:
                layers.append(contentsOf: compileZStackChildren(view.children, parentID: layer.id, bounds: childBounds, startingZIndex: zIndex + 1))
            default:
                var childZIndex = zIndex + 1
                for child in view.children {
                    layers.append(contentsOf: compileViewNode(child, parentID: layer.id, bounds: childBounds, zIndex: childZIndex))
                    childZIndex += 1
                }
            }
        }

        return layers
    }

    private func compileText(
        _ text: TextIR,
        parentID: UUID?,
        bounds: CGRect,
        zIndex: Int
    ) -> [CanvasLayer] {
        let content = extractTextContent(text.content)
        let frame = extractFrame(from: text.modifiers, defaultBounds: CGRect(
            origin: bounds.origin,
            size: CGSize(width: min(bounds.width, 200), height: 24)
        ))

        var layer = CanvasLayer(
            name: content,
            frame: CanvasFrame(origin: frame.origin, size: frame.size),
            zIndex: zIndex,
            layerType: .text
        )
        layer.parentID = parentID

        applyModifiers(text.modifiers, to: &layer)

        return [layer]
    }

    private func compileConditional(
        _ conditional: ConditionalIR,
        parentID: UUID?,
        bounds: CGRect,
        zIndex: Int
    ) -> [CanvasLayer] {
        // For now, only compile the true branch
        return compileViewNode(conditional.trueBranch, parentID: parentID, bounds: bounds, zIndex: zIndex)
    }

    private func compileLoop(
        _ loop: LoopIR,
        parentID: UUID?,
        bounds: CGRect,
        zIndex: Int
    ) -> [CanvasLayer] {
        // Create a few sample iterations
        var layers: [CanvasLayer] = []
        var currentY = bounds.minY

        for i in 0..<3 {
            let iterBounds = CGRect(
                origin: CGPoint(x: bounds.minX, y: currentY),
                size: CGSize(width: bounds.width, height: 60)
            )
            let iterLayers = compileViewNode(loop.body, parentID: parentID, bounds: iterBounds, zIndex: zIndex + i)
            layers.append(contentsOf: iterLayers)
            currentY += 68
        }

        return layers
    }

    private func compileGroup(
        _ children: [ViewNodeIR],
        parentID: UUID?,
        bounds: CGRect,
        zIndex: Int
    ) -> [CanvasLayer] {
        var layers: [CanvasLayer] = []
        var currentZIndex = zIndex

        for child in children {
            layers.append(contentsOf: compileViewNode(child, parentID: parentID, bounds: bounds, zIndex: currentZIndex))
            currentZIndex += 1
        }

        return layers
    }

    // MARK: - Stack Children Compilation

    private func compileHStackChildren(
        _ children: [ViewNodeIR],
        parentID: UUID?,
        bounds: CGRect,
        startingZIndex: Int
    ) -> [CanvasLayer] {
        var layers: [CanvasLayer] = []
        let spacing: CGFloat = 8
        let childWidth = (bounds.width - spacing * CGFloat(children.count - 1)) / CGFloat(children.count)
        var currentX = bounds.minX
        var zIndex = startingZIndex

        for child in children {
            let childBounds = CGRect(
                origin: CGPoint(x: currentX, y: bounds.minY),
                size: CGSize(width: childWidth, height: bounds.height)
            )
            layers.append(contentsOf: compileViewNode(child, parentID: parentID, bounds: childBounds, zIndex: zIndex))
            currentX += childWidth + spacing
            zIndex += 1
        }

        return layers
    }

    private func compileVStackChildren(
        _ children: [ViewNodeIR],
        parentID: UUID?,
        bounds: CGRect,
        startingZIndex: Int
    ) -> [CanvasLayer] {
        var layers: [CanvasLayer] = []
        let spacing: CGFloat = 8
        let childHeight = (bounds.height - spacing * CGFloat(children.count - 1)) / CGFloat(children.count)
        var currentY = bounds.minY
        var zIndex = startingZIndex

        for child in children {
            let childBounds = CGRect(
                origin: CGPoint(x: bounds.minX, y: currentY),
                size: CGSize(width: bounds.width, height: childHeight)
            )
            layers.append(contentsOf: compileViewNode(child, parentID: parentID, bounds: childBounds, zIndex: zIndex))
            currentY += childHeight + spacing
            zIndex += 1
        }

        return layers
    }

    private func compileZStackChildren(
        _ children: [ViewNodeIR],
        parentID: UUID?,
        bounds: CGRect,
        startingZIndex: Int
    ) -> [CanvasLayer] {
        var layers: [CanvasLayer] = []
        var zIndex = startingZIndex

        for child in children {
            layers.append(contentsOf: compileViewNode(child, parentID: parentID, bounds: bounds, zIndex: zIndex))
            zIndex += 1
        }

        return layers
    }

    // MARK: - Modifier Extraction

    private func extractFrame(from modifiers: [ModifierIR], defaultBounds: CGRect) -> CGRect {
        var width = defaultBounds.width
        var height = defaultBounds.height
        var x = defaultBounds.minX
        var y = defaultBounds.minY

        for modifier in modifiers {
            switch modifier.modifier {
            case .frame:
                for arg in modifier.arguments {
                    if arg.label == "width", case .literal(let v) = arg.value, let w = Double(v) {
                        width = w
                    }
                    if arg.label == "height", case .literal(let v) = arg.value, let h = Double(v) {
                        height = h
                    }
                }

            case .position:
                for arg in modifier.arguments {
                    if arg.label == "x", case .literal(let v) = arg.value, let px = Double(v) {
                        x = px
                    }
                    if arg.label == "y", case .literal(let v) = arg.value, let py = Double(v) {
                        y = py
                    }
                }

            default:
                break
            }
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func applyModifiers(_ modifiers: [ModifierIR], to layer: inout CanvasLayer) {
        for modifier in modifiers {
            switch modifier.modifier {
            case .background:
                if let arg = modifier.arguments.first, case .literal(let colorStr) = arg.value {
                    if let color = parseSwiftUIColor(colorStr) {
                        layer.backgroundFill = FillConfig(fillType: .solid, color: color)
                    }
                }

            case .cornerRadius:
                if let arg = modifier.arguments.first, case .literal(let v) = arg.value, let radius = Double(v) {
                    var config = layer.borderConfig ?? BorderConfig()
                    config.cornerRadius = radius
                    layer.borderConfig = config
                }

            case .shadow:
                var radius: CGFloat = 0
                var x: CGFloat = 0
                var y: CGFloat = 0

                for arg in modifier.arguments {
                    if arg.label == "radius", case .literal(let v) = arg.value, let r = Double(v) {
                        radius = r
                    }
                    if arg.label == "x", case .literal(let v) = arg.value, let px = Double(v) {
                        x = px
                    }
                    if arg.label == "y", case .literal(let v) = arg.value, let py = Double(v) {
                        y = py
                    }
                }

                layer.shadowConfig = ShadowConfig(
                    color: CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.25),
                    radius: radius,
                    offset: CGPoint(x: x, y: y)
                )

            case .opacity:
                if let arg = modifier.arguments.first, case .literal(let v) = arg.value, let opacity = Double(v) {
                    layer.opacity = opacity
                }

            case .rotationEffect:
                if let arg = modifier.arguments.first, case .literal(let v) = arg.value {
                    // Parse ".degrees(X)"
                    if let range = v.range(of: #"(-?\d+)"#, options: .regularExpression),
                       let degrees = Double(v[range]) {
                        layer.rotation = degrees
                    }
                }

            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func viewTypeName(_ type: SwiftUIViewType) -> String {
        switch type {
        case .hStack: return "HStack"
        case .vStack: return "VStack"
        case .zStack: return "ZStack"
        case .text: return "Text"
        case .button: return "Button"
        case .image: return "Image"
        case .rectangle: return "Rectangle"
        case .roundedRectangle: return "RoundedRectangle"
        case .circle: return "Circle"
        default: return type.rawValue
        }
    }

    private func viewTypeToLayerType(_ type: SwiftUIViewType) -> LayerType {
        switch type {
        case .hStack, .vStack, .zStack, .scrollView, .list:
            return .container
        case .text:
            return .text
        case .image:
            return .image
        case .rectangle, .roundedRectangle, .circle, .ellipse, .capsule:
            return .shape
        default:
            return .element
        }
    }

    private func extractTextContent(_ content: TextContentIR) -> String {
        switch content {
        case .literal(let str):
            return str
        case .interpolation(let expr):
            return "{\(expr)}"
        case .concatenation(let parts):
            return parts.map { extractTextContent($0) }.joined()
        case .localizedKey(let key):
            return key
        }
    }

    private func parseSwiftUIColor(_ colorString: String) -> CanvasColor? {
        let lowercased = colorString.lowercased()

        if lowercased.contains("accentcolor") || lowercased.contains("blue") {
            return CanvasColor(red: 0, green: 0.48, blue: 1)
        }
        if lowercased.contains("black") {
            return CanvasColor(red: 0, green: 0, blue: 0)
        }
        if lowercased.contains("white") {
            return CanvasColor(red: 1, green: 1, blue: 1)
        }
        if lowercased.contains("red") {
            return CanvasColor(red: 1, green: 0.23, blue: 0.19)
        }
        if lowercased.contains("green") {
            return CanvasColor(red: 0.2, green: 0.78, blue: 0.35)
        }
        if lowercased.contains("yellow") {
            return CanvasColor(red: 1, green: 0.8, blue: 0)
        }

        // Try to parse Color(red:green:blue:)
        let pattern = #"red:\s*([\d.]+).*green:\s*([\d.]+).*blue:\s*([\d.]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: colorString, range: NSRange(colorString.startIndex..., in: colorString)) {
            if let rRange = Range(match.range(at: 1), in: colorString),
               let gRange = Range(match.range(at: 2), in: colorString),
               let bRange = Range(match.range(at: 3), in: colorString),
               let r = Double(colorString[rRange]),
               let g = Double(colorString[gRange]),
               let b = Double(colorString[bRange]) {
                return CanvasColor(red: r, green: g, blue: b)
            }
        }

        return nil
    }
}
