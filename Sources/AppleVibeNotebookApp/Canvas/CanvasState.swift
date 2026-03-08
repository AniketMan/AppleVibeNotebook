import SwiftUI
import AppleVibeNotebook

// MARK: - Canvas State

/// Observable state managing the canvas document, selection, and tool mode.
/// Acts as the single source of truth for all canvas interactions.
@Observable
final class CanvasState {
    // MARK: - Document State

    var document: CanvasDocument
    var isDirty: Bool = false
    var lastSavedAt: Date?

    // MARK: - Selection State

    var selectedLayerIDs: Set<UUID> = []
    var hoveredLayerID: UUID?
    var focusedLayerID: UUID?

    // MARK: - Tool State

    var activeTool: CanvasTool = .select
    var previousTool: CanvasTool?

    // MARK: - Viewport State

    var isPanning: Bool = false
    var isZooming: Bool = false
    var panStartPoint: CGPoint = .zero
    var zoomStartScale: CGFloat = 1.0

    // MARK: - Drag State

    var isDragging: Bool = false
    var dragStartPoint: CGPoint = .zero
    var dragCurrentPoint: CGPoint = .zero
    var draggedLayerOriginalFrames: [UUID: CanvasFrame] = [:]

    // MARK: - Resize State

    var isResizing: Bool = false
    var resizeHandle: ResizeHandle?
    var resizeStartFrame: CanvasFrame?

    // MARK: - Clipboard

    var clipboard: [CanvasLayer] = []

    // MARK: - History (for undo/redo)

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    private var undoStack: [CanvasAction] = []
    private var redoStack: [CanvasAction] = []
    private let maxUndoLevels = 50

    // MARK: - UI State

    var showLayerPanel: Bool = true
    var showPropertyInspector: Bool = true
    var showObjectLibrary: Bool = false
    var showGrid: Bool = true
    var showRulers: Bool = true
    var showSmartGuides: Bool = true

    // MARK: - Code Sync

    var isCodeSyncEnabled: Bool = true
    var generatedSwiftUICode: String = ""
    var generatedReactCode: String = ""
    var codeUpdatePending: Bool = false

    // MARK: - Initialization

    init(document: CanvasDocument = CanvasDocument()) {
        self.document = document
    }

    // MARK: - Selection Operations

    var selectedLayers: [CanvasLayer] {
        document.layers.filter { selectedLayerIDs.contains($0.id) }
    }

    var singleSelectedLayer: CanvasLayer? {
        guard selectedLayerIDs.count == 1,
              let id = selectedLayerIDs.first else { return nil }
        return document.layers.first { $0.id == id }
    }

    func selectLayer(_ id: UUID, additive: Bool = false) {
        if additive {
            if selectedLayerIDs.contains(id) {
                selectedLayerIDs.remove(id)
            } else {
                selectedLayerIDs.insert(id)
            }
        } else {
            selectedLayerIDs = [id]
        }
    }

    func selectLayers(_ ids: [UUID]) {
        selectedLayerIDs = Set(ids)
    }

    func selectAll() {
        selectedLayerIDs = Set(document.layers.map(\.id))
    }

    func deselectAll() {
        selectedLayerIDs.removeAll()
    }

    func selectLayersInRect(_ rect: CGRect) {
        let intersecting = document.layers.filter { layer in
            layer.frame.cgRect.intersects(rect)
        }
        selectedLayerIDs = Set(intersecting.map(\.id))
    }

    // MARK: - Layer Operations

    func addLayer(_ layer: CanvasLayer) {
        recordAction(.addLayer(layer))
        document.addLayer(layer)
        selectedLayerIDs = [layer.id]
        markDirty()
    }

    func deleteSelectedLayers() {
        guard !selectedLayerIDs.isEmpty else { return }
        let layersToDelete = selectedLayers
        recordAction(.deleteLayers(layersToDelete))

        for id in selectedLayerIDs {
            document.removeLayer(id: id)
        }
        selectedLayerIDs.removeAll()
        markDirty()
    }

    func duplicateSelectedLayers() {
        var newIDs: [UUID] = []
        for layer in selectedLayers {
            if let newID = document.duplicateLayer(id: layer.id) {
                newIDs.append(newID)
            }
        }
        selectedLayerIDs = Set(newIDs)
        markDirty()
    }

    func moveSelectedLayers(by delta: CGPoint) {
        for id in selectedLayerIDs {
            if let index = document.layers.firstIndex(where: { $0.id == id }) {
                document.layers[index].frame.origin.x += delta.x
                document.layers[index].frame.origin.y += delta.y
            }
        }
        markDirty()
    }

    func resizeSelectedLayer(to newFrame: CanvasFrame) {
        guard let id = selectedLayerIDs.first,
              let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        document.layers[index].frame = newFrame
        markDirty()
    }

    func updateLayer(id: UUID, update: (inout CanvasLayer) -> Void) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let oldLayer = document.layers[index]
        update(&document.layers[index])
        recordAction(.updateLayer(old: oldLayer, new: document.layers[index]))
        markDirty()
    }

    func bringToFront() {
        guard let maxZ = document.layers.map(\.zIndex).max() else { return }
        var newZ = maxZ
        for id in selectedLayerIDs {
            if let index = document.layers.firstIndex(where: { $0.id == id }) {
                newZ += 1
                document.layers[index].zIndex = newZ
            }
        }
        markDirty()
    }

    func sendToBack() {
        guard let minZ = document.layers.map(\.zIndex).min() else { return }
        var newZ = minZ
        for id in selectedLayerIDs.reversed() {
            if let index = document.layers.firstIndex(where: { $0.id == id }) {
                newZ -= 1
                document.layers[index].zIndex = newZ
            }
        }
        markDirty()
    }

    func groupSelectedLayers() {
        guard selectedLayerIDs.count > 1 else { return }
        if let mergedID = document.mergeLayers(ids: Array(selectedLayerIDs)) {
            selectedLayerIDs = [mergedID]
        }
        markDirty()
    }

    // MARK: - Viewport Operations

    func pan(by delta: CGPoint) {
        document.viewport.offset.x += delta.x
        document.viewport.offset.y += delta.y
    }

    func zoom(to scale: CGFloat, anchor: CGPoint) {
        let clampedScale = scale.clamped(to: document.viewport.minScale...document.viewport.maxScale)
        let scaleDelta = clampedScale / document.viewport.scale

        // Adjust offset to zoom towards anchor point
        document.viewport.offset.x = anchor.x - (anchor.x - document.viewport.offset.x) * scaleDelta
        document.viewport.offset.y = anchor.y - (anchor.y - document.viewport.offset.y) * scaleDelta
        document.viewport.scale = clampedScale
    }

    func zoomIn() {
        let newScale = document.viewport.scale * 1.25
        zoom(to: newScale, anchor: CGPoint(x: document.viewport.visibleRect.midX, y: document.viewport.visibleRect.midY))
    }

    func zoomOut() {
        let newScale = document.viewport.scale / 1.25
        zoom(to: newScale, anchor: CGPoint(x: document.viewport.visibleRect.midX, y: document.viewport.visibleRect.midY))
    }

    func zoomToFit() {
        guard !document.layers.isEmpty else { return }

        let allFrames = document.layers.map(\.frame.cgRect)
        let boundingBox = allFrames.reduce(allFrames[0]) { $0.union($1) }
        document.viewport.zoomToFit(boundingBox)
    }

    func zoomTo100() {
        document.viewport.scale = 1.0
    }

    func resetViewport() {
        document.viewport = CanvasViewport()
    }

    // MARK: - Tool Operations

    func setTool(_ tool: CanvasTool) {
        previousTool = activeTool
        activeTool = tool
    }

    func toggleTool(_ tool: CanvasTool) {
        if activeTool == tool, let previous = previousTool {
            activeTool = previous
        } else {
            setTool(tool)
        }
    }

    // MARK: - Hit Testing

    func hitTest(at point: CGPoint) -> CanvasLayer? {
        let canvasPoint = document.viewport.screenToCanvas(point)

        // Test from top to bottom (highest z-index first)
        for layer in document.sortedLayers.reversed() {
            guard layer.isVisible && !layer.isLocked else { continue }
            if layer.frame.contains(canvasPoint) {
                return layer
            }
        }
        return nil
    }

    func hitTestResizeHandle(at point: CGPoint) -> ResizeHandle? {
        guard let layer = singleSelectedLayer else { return nil }
        let canvasPoint = document.viewport.screenToCanvas(point)

        let handleSize: CGFloat = 8 / document.viewport.scale
        let frame = layer.frame

        let handles: [(ResizeHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: frame.minX, y: frame.minY)),
            (.topCenter, CGPoint(x: frame.midX, y: frame.minY)),
            (.topRight, CGPoint(x: frame.maxX, y: frame.minY)),
            (.centerLeft, CGPoint(x: frame.minX, y: frame.midY)),
            (.centerRight, CGPoint(x: frame.maxX, y: frame.midY)),
            (.bottomLeft, CGPoint(x: frame.minX, y: frame.maxY)),
            (.bottomCenter, CGPoint(x: frame.midX, y: frame.maxY)),
            (.bottomRight, CGPoint(x: frame.maxX, y: frame.maxY)),
        ]

        for (handle, position) in handles {
            let handleRect = CGRect(
                x: position.x - handleSize / 2,
                y: position.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            if handleRect.contains(canvasPoint) {
                return handle
            }
        }
        return nil
    }

    // MARK: - Clipboard Operations

    func cut() {
        copy()
        deleteSelectedLayers()
    }

    func copy() {
        clipboard = selectedLayers
    }

    func paste() {
        var newIDs: [UUID] = []
        for layer in clipboard {
            var newLayer = layer
            newLayer.id = UUID()
            newLayer.frame.origin.x += 20
            newLayer.frame.origin.y += 20
            document.addLayer(newLayer)
            newIDs.append(newLayer.id)
        }
        selectedLayerIDs = Set(newIDs)
        markDirty()
    }

    // MARK: - Undo/Redo

    private func recordAction(_ action: CanvasAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        action.undo(on: &document)
        redoStack.append(action)
        markDirty()
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        action.redo(on: &document)
        undoStack.append(action)
        markDirty()
    }

    // MARK: - Dirty State

    private func markDirty() {
        isDirty = true
        document.metadata.modifiedAt = Date()

        if isCodeSyncEnabled {
            codeUpdatePending = true
        }
    }

    func markClean() {
        isDirty = false
        lastSavedAt = Date()
    }
}

// MARK: - Canvas Tool

enum CanvasTool: String, CaseIterable, Identifiable {
    case select = "Select"
    case hand = "Hand"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case text = "Text"
    case image = "Image"
    case component = "Component"
    case artboard = "Artboard"
    case pencil = "Pencil"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .hand: return "hand.raised"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .image: return "photo"
        case .component: return "puzzlepiece.extension"
        case .artboard: return "rectangle.on.rectangle"
        case .pencil: return "pencil"
        }
    }

    var shortcut: KeyEquivalent? {
        switch self {
        case .select: return "v"
        case .hand: return "h"
        case .rectangle: return "r"
        case .ellipse: return "o"
        case .text: return "t"
        case .image: return "i"
        case .component: return "c"
        case .artboard: return "a"
        case .pencil: return "p"
        }
    }
}

// MARK: - Resize Handle

enum ResizeHandle: String, CaseIterable {
    case topLeft, topCenter, topRight
    case centerLeft, centerRight
    case bottomLeft, bottomCenter, bottomRight

    var cursor: String {
        switch self {
        case .topLeft, .bottomRight: return "arrow.up.left.and.arrow.down.right"
        case .topRight, .bottomLeft: return "arrow.up.right.and.arrow.down.left"
        case .topCenter, .bottomCenter: return "arrow.up.and.arrow.down"
        case .centerLeft, .centerRight: return "arrow.left.and.arrow.right"
        }
    }
}

// MARK: - Canvas Action (for Undo/Redo)

enum CanvasAction {
    case addLayer(CanvasLayer)
    case deleteLayers([CanvasLayer])
    case updateLayer(old: CanvasLayer, new: CanvasLayer)
    case moveLayers(ids: [UUID], delta: CGPoint)
    case resizeLayer(id: UUID, oldFrame: CanvasFrame, newFrame: CanvasFrame)
    case reorderLayer(id: UUID, oldIndex: Int, newIndex: Int)

    func undo(on document: inout CanvasDocument) {
        switch self {
        case .addLayer(let layer):
            document.removeLayer(id: layer.id)

        case .deleteLayers(let layers):
            for layer in layers {
                document.layers.append(layer)
            }

        case .updateLayer(let old, _):
            if let index = document.layers.firstIndex(where: { $0.id == old.id }) {
                document.layers[index] = old
            }

        case .moveLayers(let ids, let delta):
            for id in ids {
                if let index = document.layers.firstIndex(where: { $0.id == id }) {
                    document.layers[index].frame.origin.x -= delta.x
                    document.layers[index].frame.origin.y -= delta.y
                }
            }

        case .resizeLayer(let id, let oldFrame, _):
            if let index = document.layers.firstIndex(where: { $0.id == id }) {
                document.layers[index].frame = oldFrame
            }

        case .reorderLayer(let id, let oldIndex, _):
            if let index = document.layers.firstIndex(where: { $0.id == id }) {
                document.layers[index].zIndex = oldIndex
            }
        }
    }

    func redo(on document: inout CanvasDocument) {
        switch self {
        case .addLayer(let layer):
            document.layers.append(layer)

        case .deleteLayers(let layers):
            for layer in layers {
                document.removeLayer(id: layer.id)
            }

        case .updateLayer(_, let new):
            if let index = document.layers.firstIndex(where: { $0.id == new.id }) {
                document.layers[index] = new
            }

        case .moveLayers(let ids, let delta):
            for id in ids {
                if let index = document.layers.firstIndex(where: { $0.id == id }) {
                    document.layers[index].frame.origin.x += delta.x
                    document.layers[index].frame.origin.y += delta.y
                }
            }

        case .resizeLayer(let id, _, let newFrame):
            if let index = document.layers.firstIndex(where: { $0.id == id }) {
                document.layers[index].frame = newFrame
            }

        case .reorderLayer(let id, _, let newIndex):
            if let index = document.layers.firstIndex(where: { $0.id == id }) {
                document.layers[index].zIndex = newIndex
            }
        }
    }
}

// MARK: - Comparable Extension

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
