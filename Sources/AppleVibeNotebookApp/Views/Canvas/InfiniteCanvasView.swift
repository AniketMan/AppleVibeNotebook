import SwiftUI
import AppleVibeNotebook

// MARK: - Infinite Canvas View

/// The main canvas view with 60/120fps infinite pan/zoom, grid overlay, and layer rendering.
/// Follows Procreate's fluid gesture model for intuitive navigation.
struct InfiniteCanvasView: View {
    @Bindable var canvasState: CanvasState

    @State private var viewSize: CGSize = .zero
    @State private var magnifyGestureScale: CGFloat = 1.0
    @State private var lastDragValue: DragGesture.Value?
    @GestureState private var isPinching = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                canvasBackground

                // Canvas content
                Canvas { context, size in
                    drawGrid(context: context, size: size)
                    drawLayers(context: context, size: size)
                    drawSelectionOverlay(context: context, size: size)
                    drawSmartGuides(context: context, size: size)
                } symbols: {
                    ForEach(canvasState.document.visibleLayers) { layer in
                        CanvasLayerSymbol(layer: layer, canvasState: canvasState)
                            .tag(layer.id)
                    }
                }
                .gesture(combinedGesture)
                .onTapGesture(count: 2) { location in
                    handleDoubleTap(at: location)
                }
                .onTapGesture { location in
                    handleTap(at: location)
                }

                // Selection rectangle (when dragging to select)
                if canvasState.activeTool == .select && canvasState.isDragging && canvasState.selectedLayerIDs.isEmpty {
                    selectionRectangle
                }

                // Resize handles for selected layer
                if let selectedLayer = canvasState.singleSelectedLayer {
                    ResizeHandlesOverlay(
                        layer: selectedLayer,
                        viewport: canvasState.document.viewport,
                        onResize: handleResize
                    )
                }

                // Floating toolbar
                VStack {
                    Spacer()
                    CanvasToolbar(canvasState: canvasState)
                        .padding()
                }

                // Layer panel (Procreate-style on right side)
                HStack {
                    Spacer()
                    if canvasState.showLayerPanel {
                        LayerPanelView(canvasState: canvasState)
                            .frame(width: 250)
                            .transition(.move(edge: .trailing))
                    }
                }
            }
            .onAppear {
                viewSize = geometry.size
                canvasState.document.viewport.visibleRect = CGRect(origin: .zero, size: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
                canvasState.document.viewport.visibleRect = CGRect(origin: .zero, size: newSize)
            }
        }
        .background(Color(white: 0.15))
        .ignoresSafeArea()
    }

    // MARK: - Background

    private var canvasBackground: some View {
        Rectangle()
            .fill(Color(white: 0.12))
    }

    // MARK: - Selection Rectangle

    private var selectionRectangle: some View {
        let rect = selectionRect
        return Rectangle()
            .stroke(Color.accentColor, lineWidth: 1)
            .background(Color.accentColor.opacity(0.1))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private var selectionRect: CGRect {
        let minX = min(canvasState.dragStartPoint.x, canvasState.dragCurrentPoint.x)
        let minY = min(canvasState.dragStartPoint.y, canvasState.dragCurrentPoint.y)
        let width = abs(canvasState.dragCurrentPoint.x - canvasState.dragStartPoint.x)
        let height = abs(canvasState.dragCurrentPoint.y - canvasState.dragStartPoint.y)
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    // MARK: - Combined Gesture

    private var combinedGesture: some Gesture {
        SimultaneousGesture(dragGesture, magnifyGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                handleDrag(value: value)
            }
            .onEnded { value in
                handleDragEnd(value: value)
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($isPinching) { _, state, _ in
                state = true
            }
            .onChanged { value in
                handleMagnify(value: value.magnification)
            }
            .onEnded { value in
                handleMagnifyEnd(value: value.magnification)
            }
    }

    // MARK: - Gesture Handlers

    private func handleTap(at location: CGPoint) {
        switch canvasState.activeTool {
        case .select:
            if let layer = canvasState.hitTest(at: location) {
                #if os(macOS)
                let additive = NSEvent.modifierFlags.contains(.shift)
                #else
                let additive = false
                #endif
                canvasState.selectLayer(layer.id, additive: additive)
            } else {
                canvasState.deselectAll()
            }

        case .rectangle:
            createRectangle(at: location)

        case .ellipse:
            createEllipse(at: location)

        case .text:
            createText(at: location)

        case .artboard:
            createArtboard(at: location)

        default:
            break
        }
    }

    private func handleDoubleTap(at location: CGPoint) {
        // Zoom to 100% centered on tap location
        canvasState.zoom(to: 1.0, anchor: location)
    }

    private func handleDrag(value: DragGesture.Value) {
        let delta = CGPoint(
            x: value.translation.width - (lastDragValue?.translation.width ?? 0),
            y: value.translation.height - (lastDragValue?.translation.height ?? 0)
        )
        lastDragValue = value

        switch canvasState.activeTool {
        case .hand:
            canvasState.pan(by: delta)

        case .select:
            if !canvasState.isDragging {
                // Start dragging
                canvasState.isDragging = true
                canvasState.dragStartPoint = value.startLocation
                canvasState.dragCurrentPoint = value.location

                // Check if we're starting on a selected layer
                if let layer = canvasState.hitTest(at: value.startLocation) {
                    if !canvasState.selectedLayerIDs.contains(layer.id) {
                        canvasState.selectLayer(layer.id)
                    }
                    // Store original positions for all selected layers
                    for selectedLayer in canvasState.selectedLayers {
                        canvasState.draggedLayerOriginalFrames[selectedLayer.id] = selectedLayer.frame
                    }
                }
            } else {
                canvasState.dragCurrentPoint = value.location

                if !canvasState.selectedLayerIDs.isEmpty && !canvasState.draggedLayerOriginalFrames.isEmpty {
                    // Move selected layers
                    let scaledDelta = CGPoint(
                        x: delta.x / canvasState.document.viewport.scale,
                        y: delta.y / canvasState.document.viewport.scale
                    )
                    canvasState.moveSelectedLayers(by: scaledDelta)
                }
            }

        case .rectangle, .ellipse, .artboard:
            if !canvasState.isDragging {
                canvasState.isDragging = true
                canvasState.dragStartPoint = value.startLocation
            }
            canvasState.dragCurrentPoint = value.location

        default:
            break
        }
    }

    private func handleDragEnd(value: DragGesture.Value) {
        defer {
            canvasState.isDragging = false
            canvasState.dragStartPoint = .zero
            canvasState.dragCurrentPoint = .zero
            canvasState.draggedLayerOriginalFrames.removeAll()
            lastDragValue = nil
        }

        switch canvasState.activeTool {
        case .select:
            if canvasState.draggedLayerOriginalFrames.isEmpty {
                // Selection rectangle drag ended - select layers in rect
                canvasState.selectLayersInRect(selectionRect)
            }

        case .rectangle:
            createRectangle(from: canvasState.dragStartPoint, to: value.location)

        case .ellipse:
            createEllipse(from: canvasState.dragStartPoint, to: value.location)

        case .artboard:
            createArtboard(from: canvasState.dragStartPoint, to: value.location)

        default:
            break
        }
    }

    private func handleMagnify(value: CGFloat) {
        if !canvasState.isZooming {
            canvasState.isZooming = true
            canvasState.zoomStartScale = canvasState.document.viewport.scale
        }

        let newScale = canvasState.zoomStartScale * value
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        canvasState.zoom(to: newScale, anchor: center)
    }

    private func handleMagnifyEnd(value: CGFloat) {
        canvasState.isZooming = false
    }

    private func handleResize(handle: ResizeHandle, delta: CGPoint) {
        guard var layer = canvasState.singleSelectedLayer else { return }

        var frame = layer.frame
        let scaledDelta = CGPoint(
            x: delta.x / canvasState.document.viewport.scale,
            y: delta.y / canvasState.document.viewport.scale
        )

        switch handle {
        case .topLeft:
            frame.origin.x += scaledDelta.x
            frame.origin.y += scaledDelta.y
            frame.size.width -= scaledDelta.x
            frame.size.height -= scaledDelta.y
        case .topCenter:
            frame.origin.y += scaledDelta.y
            frame.size.height -= scaledDelta.y
        case .topRight:
            frame.origin.y += scaledDelta.y
            frame.size.width += scaledDelta.x
            frame.size.height -= scaledDelta.y
        case .centerLeft:
            frame.origin.x += scaledDelta.x
            frame.size.width -= scaledDelta.x
        case .centerRight:
            frame.size.width += scaledDelta.x
        case .bottomLeft:
            frame.origin.x += scaledDelta.x
            frame.size.width -= scaledDelta.x
            frame.size.height += scaledDelta.y
        case .bottomCenter:
            frame.size.height += scaledDelta.y
        case .bottomRight:
            frame.size.width += scaledDelta.x
            frame.size.height += scaledDelta.y
        }

        // Ensure minimum size
        frame.size.width = max(frame.size.width, 20)
        frame.size.height = max(frame.size.height, 20)

        canvasState.resizeSelectedLayer(to: frame)
    }

    // MARK: - Layer Creation

    private func createRectangle(at location: CGPoint) {
        let canvasPoint = canvasState.document.viewport.screenToCanvas(location)
        let snappedPoint = canvasState.document.grid.snap(canvasPoint)

        let layer = CanvasLayer(
            name: "Rectangle",
            frame: CanvasFrame(
                origin: CGPoint(x: snappedPoint.x - 50, y: snappedPoint.y - 50),
                size: CGSize(width: 100, height: 100)
            ),
            layerType: .shape,
            backgroundFill: FillConfig(fillType: .solid, color: .accent)
        )
        canvasState.addLayer(layer)
    }

    private func createRectangle(from start: CGPoint, to end: CGPoint) {
        let canvasStart = canvasState.document.viewport.screenToCanvas(start)
        let canvasEnd = canvasState.document.viewport.screenToCanvas(end)

        let minX = min(canvasStart.x, canvasEnd.x)
        let minY = min(canvasStart.y, canvasEnd.y)
        let width = abs(canvasEnd.x - canvasStart.x)
        let height = abs(canvasEnd.y - canvasStart.y)

        guard width > 10 && height > 10 else { return }

        let layer = CanvasLayer(
            name: "Rectangle",
            frame: CanvasFrame(
                origin: CGPoint(x: minX, y: minY),
                size: CGSize(width: width, height: height)
            ),
            layerType: .shape,
            backgroundFill: FillConfig(fillType: .solid, color: .accent)
        )
        canvasState.addLayer(layer)
    }

    private func createEllipse(at location: CGPoint) {
        let canvasPoint = canvasState.document.viewport.screenToCanvas(location)
        let snappedPoint = canvasState.document.grid.snap(canvasPoint)

        let layer = CanvasLayer(
            name: "Ellipse",
            frame: CanvasFrame(
                origin: CGPoint(x: snappedPoint.x - 50, y: snappedPoint.y - 50),
                size: CGSize(width: 100, height: 100)
            ),
            layerType: .shape,
            borderConfig: BorderConfig(cornerRadius: 50),
            backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0.5, green: 0.8, blue: 0.5))
        )
        canvasState.addLayer(layer)
    }

    private func createEllipse(from start: CGPoint, to end: CGPoint) {
        let canvasStart = canvasState.document.viewport.screenToCanvas(start)
        let canvasEnd = canvasState.document.viewport.screenToCanvas(end)

        let minX = min(canvasStart.x, canvasEnd.x)
        let minY = min(canvasStart.y, canvasEnd.y)
        let width = abs(canvasEnd.x - canvasStart.x)
        let height = abs(canvasEnd.y - canvasStart.y)

        guard width > 10 && height > 10 else { return }

        let layer = CanvasLayer(
            name: "Ellipse",
            frame: CanvasFrame(
                origin: CGPoint(x: minX, y: minY),
                size: CGSize(width: width, height: height)
            ),
            layerType: .shape,
            borderConfig: BorderConfig(cornerRadius: min(width, height) / 2),
            backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0.5, green: 0.8, blue: 0.5))
        )
        canvasState.addLayer(layer)
    }

    private func createText(at location: CGPoint) {
        let canvasPoint = canvasState.document.viewport.screenToCanvas(location)

        let layer = CanvasLayer(
            name: "Text",
            frame: CanvasFrame(
                origin: canvasPoint,
                size: CGSize(width: 200, height: 40)
            ),
            layerType: .text
        )
        canvasState.addLayer(layer)
    }

    private func createArtboard(at location: CGPoint) {
        let canvasPoint = canvasState.document.viewport.screenToCanvas(location)

        let preset = canvasState.document.metadata.devicePreset ?? .iPhone15
        let layer = CanvasLayer(
            name: "Artboard",
            frame: CanvasFrame(
                origin: canvasPoint,
                size: preset.size
            ),
            layerType: .artboard,
            backgroundFill: FillConfig(fillType: .solid, color: .white)
        )
        canvasState.addLayer(layer)
    }

    private func createArtboard(from start: CGPoint, to end: CGPoint) {
        let canvasStart = canvasState.document.viewport.screenToCanvas(start)
        let canvasEnd = canvasState.document.viewport.screenToCanvas(end)

        let minX = min(canvasStart.x, canvasEnd.x)
        let minY = min(canvasStart.y, canvasEnd.y)
        let width = abs(canvasEnd.x - canvasStart.x)
        let height = abs(canvasEnd.y - canvasStart.y)

        guard width > 50 && height > 50 else { return }

        let layer = CanvasLayer(
            name: "Artboard",
            frame: CanvasFrame(
                origin: CGPoint(x: minX, y: minY),
                size: CGSize(width: width, height: height)
            ),
            layerType: .artboard,
            backgroundFill: FillConfig(fillType: .solid, color: .white)
        )
        canvasState.addLayer(layer)
    }

    // MARK: - Canvas Drawing

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        guard canvasState.showGrid && canvasState.document.grid.isVisible else { return }

        let viewport = canvasState.document.viewport
        let grid = canvasState.document.grid

        let spacing = grid.spacing * viewport.scale
        guard spacing > 4 else { return } // Don't draw if too dense

        let gridColor = Color(
            red: grid.color.red,
            green: grid.color.green,
            blue: grid.color.blue,
            opacity: grid.color.alpha
        )

        // Calculate visible grid range
        let startX = ((-viewport.offset.x / spacing).rounded(.down)) * spacing + viewport.offset.x
        let startY = ((-viewport.offset.y / spacing).rounded(.down)) * spacing + viewport.offset.y

        var path = Path()

        // Vertical lines
        var x = startX
        while x < size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }

        // Horizontal lines
        var y = startY
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
    }

    private func drawLayers(context: GraphicsContext, size: CGSize) {
        let viewport = canvasState.document.viewport

        for layer in canvasState.document.visibleLayers {
            let screenFrame = layerScreenFrame(layer, viewport: viewport)

            // Skip if outside visible area
            guard screenFrame.intersects(CGRect(origin: .zero, size: size)) else { continue }

            // Draw layer background
            if let fill = layer.backgroundFill {
                let fillRect = CGRect(
                    x: screenFrame.origin.x,
                    y: screenFrame.origin.y,
                    width: screenFrame.size.width,
                    height: screenFrame.size.height
                )

                let cornerRadius = layer.borderConfig?.cornerRadius ?? 0
                let shape = RoundedRectangle(cornerRadius: cornerRadius * viewport.scale)
                let path = shape.path(in: fillRect)

                if fill.fillType == .solid, let color = fill.color {
                    context.fill(
                        path,
                        with: .color(Color(
                            red: color.red,
                            green: color.green,
                            blue: color.blue,
                            opacity: color.alpha * layer.opacity
                        ))
                    )
                }
            }

            // Draw border
            if let border = layer.borderConfig, border.width > 0 {
                let borderRect = CGRect(
                    x: screenFrame.origin.x,
                    y: screenFrame.origin.y,
                    width: screenFrame.size.width,
                    height: screenFrame.size.height
                )

                let shape = RoundedRectangle(cornerRadius: border.cornerRadius * viewport.scale)
                let path = shape.path(in: borderRect)

                context.stroke(
                    path,
                    with: .color(Color(
                        red: border.color.red,
                        green: border.color.green,
                        blue: border.color.blue,
                        opacity: border.color.alpha
                    )),
                    lineWidth: border.width * viewport.scale
                )
            }

            // Draw layer type indicator for artboards
            if layer.layerType == .artboard {
                let labelRect = CGRect(
                    x: screenFrame.origin.x,
                    y: screenFrame.origin.y - 20 * viewport.scale,
                    width: screenFrame.size.width,
                    height: 20 * viewport.scale
                )
                context.draw(
                    Text(layer.name).font(.system(size: 12 * viewport.scale)),
                    in: labelRect
                )
            }
        }
    }

    private func drawSelectionOverlay(context: GraphicsContext, size: CGSize) {
        let viewport = canvasState.document.viewport

        for layerID in canvasState.selectedLayerIDs {
            guard let layer = canvasState.document.layers.first(where: { $0.id == layerID }) else { continue }

            let screenFrame = layerScreenFrame(layer, viewport: viewport)

            // Selection border
            let selectionPath = Rectangle().path(in: CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.size.width,
                height: screenFrame.size.height
            ))

            context.stroke(selectionPath, with: .color(.accentColor), lineWidth: 2)
        }
    }

    private func drawSmartGuides(context: GraphicsContext, size: CGSize) {
        guard canvasState.showSmartGuides && canvasState.isDragging else { return }
        // Smart guides implementation would go here
    }

    private func layerScreenFrame(_ layer: CanvasLayer, viewport: CanvasViewport) -> CGRect {
        let screenOrigin = viewport.canvasToScreen(layer.frame.origin)
        let screenSize = CGSize(
            width: layer.frame.size.width * viewport.scale,
            height: layer.frame.size.height * viewport.scale
        )
        return CGRect(origin: screenOrigin, size: screenSize)
    }
}

// MARK: - Canvas Layer Symbol

struct CanvasLayerSymbol: View {
    let layer: CanvasLayer
    let canvasState: CanvasState

    var body: some View {
        EmptyView()
    }
}

// MARK: - Resize Handles Overlay

struct ResizeHandlesOverlay: View {
    let layer: CanvasLayer
    let viewport: CanvasViewport
    let onResize: (ResizeHandle, CGPoint) -> Void

    @State private var dragStartPoint: CGPoint = .zero

    private let handleSize: CGFloat = 8

    var body: some View {
        let screenFrame = CGRect(
            origin: viewport.canvasToScreen(layer.frame.origin),
            size: CGSize(
                width: layer.frame.size.width * viewport.scale,
                height: layer.frame.size.height * viewport.scale
            )
        )

        ZStack {
            ForEach(ResizeHandle.allCases, id: \.rawValue) { handle in
                ResizeHandleView(handle: handle, screenFrame: screenFrame, handleSize: handleSize)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                onResize(handle, CGPoint(
                                    x: value.translation.width,
                                    y: value.translation.height
                                ))
                            }
                    )
            }
        }
    }
}

struct ResizeHandleView: View {
    let handle: ResizeHandle
    let screenFrame: CGRect
    let handleSize: CGFloat

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
            .position(handlePosition)
    }

    private var handlePosition: CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: screenFrame.minX, y: screenFrame.minY)
        case .topCenter: return CGPoint(x: screenFrame.midX, y: screenFrame.minY)
        case .topRight: return CGPoint(x: screenFrame.maxX, y: screenFrame.minY)
        case .centerLeft: return CGPoint(x: screenFrame.minX, y: screenFrame.midY)
        case .centerRight: return CGPoint(x: screenFrame.maxX, y: screenFrame.midY)
        case .bottomLeft: return CGPoint(x: screenFrame.minX, y: screenFrame.maxY)
        case .bottomCenter: return CGPoint(x: screenFrame.midX, y: screenFrame.maxY)
        case .bottomRight: return CGPoint(x: screenFrame.maxX, y: screenFrame.maxY)
        }
    }
}

// MARK: - Layer Panel View (Procreate-style)

struct LayerPanelView: View {
    @Bindable var canvasState: CanvasState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
                Button {
                    canvasState.showLayerPanel = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.2))

            // Layer list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(canvasState.document.sortedLayers.reversed()) { layer in
                        LayerRowView(
                            layer: layer,
                            isSelected: canvasState.selectedLayerIDs.contains(layer.id),
                            onSelect: { canvasState.selectLayer(layer.id) },
                            onToggleVisibility: {
                                canvasState.updateLayer(id: layer.id) { $0.isVisible.toggle() }
                            },
                            onToggleLock: {
                                canvasState.updateLayer(id: layer.id) { $0.isLocked.toggle() }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            // Footer actions
            HStack {
                Button {
                    let newLayer = CanvasLayer(
                        name: "New Layer",
                        frame: CanvasFrame(origin: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 100)),
                        layerType: .shape,
                        backgroundFill: FillConfig(fillType: .solid, color: .accent)
                    )
                    canvasState.addLayer(newLayer)
                } label: {
                    Image(systemName: "plus")
                }

                Spacer()

                Button {
                    canvasState.groupSelectedLayers()
                } label: {
                    Image(systemName: "folder")
                }
                .disabled(canvasState.selectedLayerIDs.count < 2)

                Button {
                    canvasState.deleteSelectedLayers()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(canvasState.selectedLayerIDs.isEmpty)
            }
            .padding()
            .background(Color(white: 0.2))
        }
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
        .padding()
    }
}

struct LayerRowView: View {
    let layer: CanvasLayer
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onToggleLock: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 4)
                .fill(thumbnailColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: layer.layerType.icon)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 14))
                )

            // Name
            Text(layer.name)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            // Visibility toggle
            Button {
                onToggleVisibility()
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)

            // Lock toggle
            Button {
                onToggleLock()
            } label: {
                Image(systemName: layer.isLocked ? "lock" : "lock.open")
                    .foregroundColor(layer.isLocked ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            onSelect()
        }
    }

    private var thumbnailColor: Color {
        if let fill = layer.backgroundFill, let color = fill.color {
            return Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
        }
        return Color(white: 0.3)
    }
}
