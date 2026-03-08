import SwiftUI
#if os(iOS)
import PencilKit
#endif
import AppleVibeNotebook

#if os(iOS)

@Observable @MainActor
public final class SketchToUIEngine {
    public var isProcessing: Bool = false
    public var recognizedShapes: [RecognizedShape] = []
    public var suggestedLayers: [CanvasLayer] = []
    public var confidenceThreshold: Double = 0.7

    private let shapeRecognizer = ShapeRecognizer()

    public init() {}

    public func processDrawing(_ drawing: PKDrawing) async -> [CanvasLayer] {
        isProcessing = true
        defer { isProcessing = false }

        recognizedShapes = await analyzeStrokes(drawing.strokes)
        suggestedLayers = convertToLayers(recognizedShapes)

        return suggestedLayers
    }

    private func analyzeStrokes(_ strokes: [PKStroke]) async -> [RecognizedShape] {
        var shapes: [RecognizedShape] = []

        for stroke in strokes {
            if let shape = shapeRecognizer.recognize(stroke) {
                if shape.confidence >= confidenceThreshold {
                    shapes.append(shape)
                }
            }
        }

        return mergeAdjacentShapes(shapes)
    }

    private func mergeAdjacentShapes(_ shapes: [RecognizedShape]) -> [RecognizedShape] {
        var merged = shapes
        var i = 0

        while i < merged.count {
            var j = i + 1
            while j < merged.count {
                if shouldMerge(merged[i], merged[j]) {
                    merged[i] = merge(merged[i], merged[j])
                    merged.remove(at: j)
                } else {
                    j += 1
                }
            }
            i += 1
        }

        return merged
    }

    private func shouldMerge(_ a: RecognizedShape, _ b: RecognizedShape) -> Bool {
        let aFrame = a.boundingRect
        let bFrame = b.boundingRect
        let expandedA = aFrame.insetBy(dx: -20, dy: -20)
        return expandedA.intersects(bFrame) && a.type == b.type
    }

    private func merge(_ a: RecognizedShape, _ b: RecognizedShape) -> RecognizedShape {
        let union = a.boundingRect.union(b.boundingRect)
        return RecognizedShape(
            id: a.id,
            type: a.type,
            boundingRect: union,
            confidence: (a.confidence + b.confidence) / 2,
            strokeIds: a.strokeIds + b.strokeIds
        )
    }

    private func convertToLayers(_ shapes: [RecognizedShape]) -> [CanvasLayer] {
        shapes.enumerated().map { index, shape in
            let frame = CanvasFrame(
                origin: CGPoint(x: shape.boundingRect.origin.x, y: shape.boundingRect.origin.y),
                size: CGSize(width: max(shape.boundingRect.width, 44), height: max(shape.boundingRect.height, 44))
            )

            var borderConfig: BorderConfig?
            var backgroundFill: FillConfig?
            var shadowConfig: ShadowConfig?
            var layerType = shape.type.layerType

            switch shape.type {
            case .rectangle, .roundedRectangle:
                borderConfig = BorderConfig(
                    color: CanvasColor(red: 0.8, green: 0.8, blue: 0.82, alpha: 1),
                    width: 1,
                    cornerRadius: shape.type == .roundedRectangle ? 12 : 0
                )
                backgroundFill = FillConfig(
                    fillType: .solid,
                    color: CanvasColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
                )

            case .circle, .oval:
                let radius = min(frame.size.width, frame.size.height) / 2
                borderConfig = BorderConfig(cornerRadius: radius)
                backgroundFill = FillConfig(
                    fillType: .solid,
                    color: CanvasColor(red: 0, green: 0.48, blue: 1, alpha: 1)
                )

            case .line:
                borderConfig = BorderConfig(
                    color: CanvasColor(red: 0, green: 0, blue: 0, alpha: 1),
                    width: 2
                )

            case .text:
                layerType = .text

            case .button:
                borderConfig = BorderConfig(cornerRadius: 10)
                backgroundFill = FillConfig(
                    fillType: .solid,
                    color: CanvasColor(red: 0, green: 0.48, blue: 1, alpha: 1)
                )

            case .textField:
                borderConfig = BorderConfig(
                    color: CanvasColor(red: 0.8, green: 0.8, blue: 0.82, alpha: 1),
                    width: 1,
                    cornerRadius: 8
                )
                backgroundFill = FillConfig(
                    fillType: .solid,
                    color: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1)
                )

            case .card:
                borderConfig = BorderConfig(cornerRadius: 16)
                backgroundFill = FillConfig(
                    fillType: .solid,
                    color: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1)
                )
                shadowConfig = ShadowConfig(
                    color: CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.1),
                    radius: 8,
                    offset: CGPoint(x: 0, y: 4)
                )

            case .image:
                layerType = .image
                backgroundFill = FillConfig(
                    fillType: .solid,
                    color: CanvasColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1)
                )

            case .container:
                layerType = .container
                borderConfig = BorderConfig(
                    color: CanvasColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1),
                    width: 1
                )

            case .unknown:
                break
            }

            return CanvasLayer(
                id: UUID(),
                name: "\(shape.type.componentName) \(index + 1)",
                frame: frame,
                zIndex: index,
                layerType: layerType,
                shadowConfig: shadowConfig,
                borderConfig: borderConfig,
                backgroundFill: backgroundFill
            )
        }
    }
}

public struct RecognizedShape: Identifiable {
    public let id: UUID
    public let type: ShapeType
    public let boundingRect: CGRect
    public let confidence: Double
    public let strokeIds: [UUID]

    public init(
        id: UUID = UUID(),
        type: ShapeType,
        boundingRect: CGRect,
        confidence: Double,
        strokeIds: [UUID] = []
    ) {
        self.id = id
        self.type = type
        self.boundingRect = boundingRect
        self.confidence = confidence
        self.strokeIds = strokeIds
    }
}

public enum ShapeType {
    case rectangle
    case roundedRectangle
    case circle
    case oval
    case line
    case text
    case button
    case textField
    case card
    case image
    case container
    case unknown

    var componentName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .roundedRectangle: return "RoundedRect"
        case .circle: return "Circle"
        case .oval: return "Oval"
        case .line: return "Line"
        case .text: return "Text"
        case .button: return "Button"
        case .textField: return "TextField"
        case .card: return "Card"
        case .image: return "Image"
        case .container: return "Container"
        case .unknown: return "Shape"
        }
    }

    var layerType: LayerType {
        switch self {
        case .text: return .text
        case .image: return .image
        case .container, .card: return .container
        default: return .shape
        }
    }
}

final class ShapeRecognizer {
    func recognize(_ stroke: PKStroke) -> RecognizedShape? {
        let path = stroke.path
        guard path.count >= 2 else { return nil }

        let bounds = stroke.renderBounds
        let aspectRatio = bounds.width / bounds.height

        if isClosedShape(path) {
            if isRoughlyCircular(path, bounds: bounds) {
                return RecognizedShape(
                    type: abs(aspectRatio - 1) < 0.2 ? .circle : .oval,
                    boundingRect: bounds,
                    confidence: 0.85,
                    strokeIds: [UUID()]
                )
            }

            if isRoughlyRectangular(path, bounds: bounds) {
                let hasRoundedCorners = detectRoundedCorners(path)
                return RecognizedShape(
                    type: hasRoundedCorners ? .roundedRectangle : .rectangle,
                    boundingRect: bounds,
                    confidence: 0.8,
                    strokeIds: [UUID()]
                )
            }
        } else {
            if isLine(path) {
                return RecognizedShape(
                    type: .line,
                    boundingRect: bounds,
                    confidence: 0.9,
                    strokeIds: [UUID()]
                )
            }
        }

        if looksLikeTextfield(bounds: bounds) {
            return RecognizedShape(
                type: .textField,
                boundingRect: bounds,
                confidence: 0.7,
                strokeIds: [UUID()]
            )
        }

        if looksLikeButton(bounds: bounds) {
            return RecognizedShape(
                type: .button,
                boundingRect: bounds,
                confidence: 0.7,
                strokeIds: [UUID()]
            )
        }

        return RecognizedShape(
            type: .unknown,
            boundingRect: bounds,
            confidence: 0.5,
            strokeIds: [UUID()]
        )
    }

    private func isClosedShape(_ path: PKStrokePath) -> Bool {
        guard let first = path.first, let last = path.last else { return false }
        let distance = hypot(first.location.x - last.location.x, first.location.y - last.location.y)
        return distance < 30
    }

    private func isRoughlyCircular(_ path: PKStrokePath, bounds: CGRect) -> Bool {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let expectedRadius = min(bounds.width, bounds.height) / 2

        var deviationSum: CGFloat = 0
        for point in path {
            let distance = hypot(point.location.x - center.x, point.location.y - center.y)
            deviationSum += abs(distance - expectedRadius)
        }

        let avgDeviation = deviationSum / CGFloat(path.count)
        return avgDeviation < expectedRadius * 0.3
    }

    private func isRoughlyRectangular(_ path: PKStrokePath, bounds: CGRect) -> Bool {
        var edgePoints = 0
        let tolerance: CGFloat = 15

        for point in path {
            let loc = point.location
            let nearLeft = abs(loc.x - bounds.minX) < tolerance
            let nearRight = abs(loc.x - bounds.maxX) < tolerance
            let nearTop = abs(loc.y - bounds.minY) < tolerance
            let nearBottom = abs(loc.y - bounds.maxY) < tolerance

            if nearLeft || nearRight || nearTop || nearBottom {
                edgePoints += 1
            }
        }

        return CGFloat(edgePoints) / CGFloat(path.count) > 0.6
    }

    private func detectRoundedCorners(_ path: PKStrokePath) -> Bool {
        return true
    }

    private func isLine(_ path: PKStrokePath) -> Bool {
        guard let first = path.first, let last = path.last else { return false }

        let lineLength = hypot(last.location.x - first.location.x, last.location.y - first.location.y)

        var maxDeviation: CGFloat = 0
        for point in path {
            let deviation = pointToLineDistance(
                point: point.location,
                lineStart: first.location,
                lineEnd: last.location
            )
            maxDeviation = max(maxDeviation, deviation)
        }

        return maxDeviation < lineLength * 0.1
    }

    private func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y

        let length = hypot(dx, dy)
        guard length > 0 else { return hypot(point.x - lineStart.x, point.y - lineStart.y) }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (length * length)))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy

        return hypot(point.x - projX, point.y - projY)
    }

    private func looksLikeTextfield(bounds: CGRect) -> Bool {
        let aspectRatio = bounds.width / bounds.height
        return aspectRatio > 3 && bounds.height > 30 && bounds.height < 60
    }

    private func looksLikeButton(bounds: CGRect) -> Bool {
        let aspectRatio = bounds.width / bounds.height
        return aspectRatio > 1.5 && aspectRatio < 5 && bounds.height > 35 && bounds.height < 80
    }
}

public struct iPadCanvasView: View {
    @Bindable var canvasState: CanvasState
    @State private var sketchEngine = SketchToUIEngine()
    @State private var pkDrawing = PKDrawing()
    @State private var isSketchMode = false
    @State private var showSketchOverlay = false
    @State private var pendingLayers: [CanvasLayer] = []
    @State private var showConfirmation = false
    @State private var pencilInteraction: UIPencilInteraction?
    @State private var toolPickerVisible = false

    init(canvasState: CanvasState) {
        self.canvasState = canvasState
    }

    public var body: some View {
        ZStack {
            if isSketchMode {
                sketchCanvasView
            } else {
                InfiniteCanvasView(canvasState: canvasState)
            }

            VStack {
                topToolbar
                Spacer()
                if isSketchMode {
                    sketchModeControls
                }
            }

            if showConfirmation && !pendingLayers.isEmpty {
                layerConfirmationOverlay
            }
        }
    }

    private var topToolbar: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isSketchMode.toggle()
                    if isSketchMode {
                        pkDrawing = PKDrawing()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSketchMode ? "square.on.square" : "pencil.tip")
                    Text(isSketchMode ? "Canvas" : "Sketch")
                }
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSketchMode ? Color.orange : Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }

            Spacer()

            if isSketchMode {
                Button {
                    pkDrawing = PKDrawing()
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Button {
                    Task {
                        await convertSketchToUI()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if sketchEngine.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text("Convert to UI")
                    }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(pkDrawing.strokes.isEmpty || sketchEngine.isProcessing)
            }
        }
        .padding()
    }

    private var sketchCanvasView: some View {
        PencilCanvasView(drawing: $pkDrawing, toolPickerVisible: $toolPickerVisible)
            .background(Color(.systemBackground))
            .overlay {
                if !sketchEngine.recognizedShapes.isEmpty {
                    ForEach(sketchEngine.recognizedShapes) { shape in
                        ShapeOverlayView(shape: shape)
                    }
                }
            }
    }

    private var sketchModeControls: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Draw shapes to create UI components")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Rectangles → Containers | Circles → Icons | Lines → Dividers")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(pkDrawing.strokes.count) strokes")
                    .font(.subheadline.monospacedDigit())
                Text("Apple Pencil ready")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var layerConfirmationOverlay: some View {
        VStack(spacing: 20) {
            Text("Detected \(pendingLayers.count) Components")
                .font(.title2.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(pendingLayers) { layer in
                        LayerPreviewCard(layer: layer)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 150)

            HStack(spacing: 16) {
                Button("Cancel") {
                    pendingLayers = []
                    showConfirmation = false
                }
                .buttonStyle(.bordered)

                Button("Add to Canvas") {
                    for layer in pendingLayers {
                        canvasState.addLayer(layer)
                    }
                    pendingLayers = []
                    showConfirmation = false
                    isSketchMode = false
                    pkDrawing = PKDrawing()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .padding()
    }

    private func convertSketchToUI() async {
        let layers = await sketchEngine.processDrawing(pkDrawing)

        await MainActor.run {
            pendingLayers = layers
            showConfirmation = true
        }
    }
}

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var toolPickerVisible: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .pencilOnly
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .systemBackground
        canvasView.isOpaque = true

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(toolPickerVisible, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        context.coordinator.toolPicker = toolPicker

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        if canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }

        context.coordinator.toolPicker?.setVisible(toolPickerVisible, forFirstResponder: canvasView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView
        var toolPicker: PKToolPicker?

        init(_ parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

struct ShapeOverlayView: View {
    let shape: RecognizedShape

    var body: some View {
        RoundedRectangle(cornerRadius: shape.type == .roundedRectangle ? 12 : 4)
            .stroke(colorForShape(shape.type), lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: shape.type == .roundedRectangle ? 12 : 4)
                    .fill(colorForShape(shape.type).opacity(0.1))
            )
            .frame(width: shape.boundingRect.width, height: shape.boundingRect.height)
            .position(
                x: shape.boundingRect.midX,
                y: shape.boundingRect.midY
            )
            .overlay(alignment: .topLeading) {
                Text(shape.type.componentName)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForShape(shape.type))
                    .clipShape(Capsule())
                    .offset(x: shape.boundingRect.minX, y: shape.boundingRect.minY - 20)
            }
    }

    private func colorForShape(_ type: ShapeType) -> Color {
        switch type {
        case .rectangle, .roundedRectangle: return .blue
        case .circle, .oval: return .green
        case .line: return .gray
        case .text: return .purple
        case .button: return .orange
        case .textField: return .teal
        case .card: return .indigo
        case .image: return .pink
        case .container: return .cyan
        case .unknown: return .secondary
        }
    }
}

struct LayerPreviewCard: View {
    let layer: CanvasLayer

    private var cornerRadius: CGFloat {
        layer.borderConfig?.cornerRadius ?? 0
    }

    private var fillColor: Color {
        layer.backgroundFill?.color?.swiftUIColor ?? Color.gray.opacity(0.3)
    }

    private var strokeColor: CanvasColor? {
        layer.borderConfig?.color
    }

    private var strokeWidth: CGFloat {
        layer.borderConfig?.width ?? 1
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
                    .frame(width: 80, height: 60)

                if let stroke = strokeColor {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(stroke.swiftUIColor, lineWidth: strokeWidth)
                        .frame(width: 80, height: 60)
                }
            }

            Text(layer.name)
                .font(.caption)
                .foregroundColor(.primary)

            Text(layer.layerType.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
#endif
