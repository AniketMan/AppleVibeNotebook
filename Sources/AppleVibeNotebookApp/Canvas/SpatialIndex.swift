import Foundation
import simd
import AppleVibeNotebook

public final class SpatialIndex<T: Identifiable> where T.ID == UUID {
    private var root: QuadTreeNode<T>?
    private var bounds: CGRect
    private var items: [UUID: (item: T, bounds: CGRect)] = [:]

    private let maxDepth: Int
    private let maxItemsPerNode: Int

    public init(
        bounds: CGRect = CGRect(x: -50000, y: -50000, width: 100000, height: 100000),
        maxDepth: Int = 10,
        maxItemsPerNode: Int = 8
    ) {
        self.bounds = bounds
        self.maxDepth = maxDepth
        self.maxItemsPerNode = maxItemsPerNode
        self.root = QuadTreeNode(bounds: bounds, depth: 0, maxDepth: maxDepth, maxItems: maxItemsPerNode)
    }

    public func insert(_ item: T, bounds itemBounds: CGRect) {
        items[item.id] = (item, itemBounds)
        root?.insert(item.id, bounds: itemBounds)
    }

    public func remove(_ id: UUID) {
        guard let entry = items.removeValue(forKey: id) else { return }
        root?.remove(id, bounds: entry.bounds)
    }

    public func update(_ item: T, newBounds: CGRect) {
        if let entry = items[item.id] {
            root?.remove(item.id, bounds: entry.bounds)
        }
        items[item.id] = (item, newBounds)
        root?.insert(item.id, bounds: newBounds)
    }

    public func query(rect: CGRect) -> [T] {
        guard let root else { return [] }
        let ids = root.query(rect: rect)
        return ids.compactMap { items[$0]?.item }
    }

    public func queryVisible(viewport: CGRect) -> [T] {
        query(rect: viewport)
    }

    public func queryPoint(_ point: CGPoint) -> [T] {
        query(rect: CGRect(origin: point, size: .zero).insetBy(dx: -1, dy: -1))
    }

    public func nearestNeighbor(to point: CGPoint, maxDistance: CGFloat = .infinity) -> T? {
        var nearest: (item: T, distance: CGFloat)?

        for (_, entry) in items {
            let center = CGPoint(x: entry.bounds.midX, y: entry.bounds.midY)
            let distance = hypot(center.x - point.x, center.y - point.y)

            if distance <= maxDistance {
                if nearest == nil || distance < nearest!.distance {
                    nearest = (entry.item, distance)
                }
            }
        }

        return nearest?.item
    }

    public func findIntersecting(with rect: CGRect) -> [T] {
        query(rect: rect).filter { item in
            guard let entry = items[item.id] else { return false }
            return entry.bounds.intersects(rect)
        }
    }

    public func findContaining(point: CGPoint) -> [T] {
        query(rect: CGRect(origin: point, size: .zero).insetBy(dx: -100, dy: -100))
            .filter { item in
                guard let entry = items[item.id] else { return false }
                return entry.bounds.contains(point)
            }
    }

    public func clear() {
        items.removeAll()
        root = QuadTreeNode(bounds: bounds, depth: 0, maxDepth: maxDepth, maxItems: maxItemsPerNode)
    }

    public func rebuild(with newItems: [(item: T, bounds: CGRect)]) {
        clear()
        for entry in newItems {
            insert(entry.item, bounds: entry.bounds)
        }
    }

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }
}

private final class QuadTreeNode<T: Identifiable> where T.ID == UUID {
    let bounds: CGRect
    let depth: Int
    let maxDepth: Int
    let maxItems: Int

    private var items: [(id: UUID, bounds: CGRect)] = []
    private var children: [QuadTreeNode<T>]?

    init(bounds: CGRect, depth: Int, maxDepth: Int, maxItems: Int) {
        self.bounds = bounds
        self.depth = depth
        self.maxDepth = maxDepth
        self.maxItems = maxItems
    }

    func insert(_ id: UUID, bounds itemBounds: CGRect) {
        guard bounds.intersects(itemBounds) else { return }

        if let children {
            for child in children {
                child.insert(id, bounds: itemBounds)
            }
            return
        }

        items.append((id, itemBounds))

        if items.count > maxItems && depth < maxDepth {
            subdivide()
        }
    }

    func remove(_ id: UUID, bounds itemBounds: CGRect) {
        if let children {
            for child in children {
                child.remove(id, bounds: itemBounds)
            }
            return
        }

        items.removeAll { $0.id == id }
    }

    func query(rect: CGRect) -> Set<UUID> {
        guard bounds.intersects(rect) else { return [] }

        var result = Set<UUID>()

        if let children {
            for child in children {
                result.formUnion(child.query(rect: rect))
            }
        } else {
            for item in items {
                if item.bounds.intersects(rect) {
                    result.insert(item.id)
                }
            }
        }

        return result
    }

    private func subdivide() {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        let x = bounds.origin.x
        let y = bounds.origin.y

        children = [
            QuadTreeNode(
                bounds: CGRect(x: x, y: y, width: halfWidth, height: halfHeight),
                depth: depth + 1, maxDepth: maxDepth, maxItems: maxItems
            ),
            QuadTreeNode(
                bounds: CGRect(x: x + halfWidth, y: y, width: halfWidth, height: halfHeight),
                depth: depth + 1, maxDepth: maxDepth, maxItems: maxItems
            ),
            QuadTreeNode(
                bounds: CGRect(x: x, y: y + halfHeight, width: halfWidth, height: halfHeight),
                depth: depth + 1, maxDepth: maxDepth, maxItems: maxItems
            ),
            QuadTreeNode(
                bounds: CGRect(x: x + halfWidth, y: y + halfHeight, width: halfWidth, height: halfHeight),
                depth: depth + 1, maxDepth: maxDepth, maxItems: maxItems
            )
        ]

        for item in items {
            for child in children! {
                child.insert(item.id, bounds: item.bounds)
            }
        }

        items.removeAll()
    }
}

public final class ViewportCuller {
    private var spatialIndex: SpatialIndex<CanvasLayer>
    private var cachedVisibleIds: Set<UUID> = []
    private var lastViewport: CGRect = .zero
    private var viewportPadding: CGFloat = 100

    public init() {
        self.spatialIndex = SpatialIndex()
    }

    public func rebuild(layers: [CanvasLayer]) {
        spatialIndex.rebuild(with: layers.map { layer in
            (item: layer, bounds: layer.frame.cgRect)
        })
    }

    public func updateLayer(_ layer: CanvasLayer) {
        spatialIndex.update(layer, newBounds: layer.frame.cgRect)
        invalidateCache()
    }

    public func addLayer(_ layer: CanvasLayer) {
        spatialIndex.insert(layer, bounds: layer.frame.cgRect)
        invalidateCache()
    }

    public func removeLayer(id: UUID) {
        spatialIndex.remove(id)
        cachedVisibleIds.remove(id)
    }

    public func visibleLayers(in viewport: CGRect, allLayers: [CanvasLayer]) -> [CanvasLayer] {
        let paddedViewport = viewport.insetBy(dx: -viewportPadding, dy: -viewportPadding)

        if paddedViewport == lastViewport {
            return allLayers.filter { cachedVisibleIds.contains($0.id) }
        }

        lastViewport = paddedViewport
        let visibleLayers = spatialIndex.queryVisible(viewport: paddedViewport)
        cachedVisibleIds = Set(visibleLayers.map(\.id))

        return visibleLayers
    }

    public func layersAt(point: CGPoint) -> [CanvasLayer] {
        spatialIndex.findContaining(point: point)
    }

    public func layersIntersecting(rect: CGRect) -> [CanvasLayer] {
        spatialIndex.findIntersecting(with: rect)
    }

    public func nearestLayer(to point: CGPoint, maxDistance: CGFloat = 50) -> CanvasLayer? {
        spatialIndex.nearestNeighbor(to: point, maxDistance: maxDistance)
    }

    public func invalidateCache() {
        lastViewport = .zero
        cachedVisibleIds.removeAll()
    }

    public var totalLayerCount: Int { spatialIndex.count }
}

public final class RenderOptimizer {
    private var tileCache: [TileKey: CGImage] = [:]
    private let tileSize: CGSize = CGSize(width: 512, height: 512)
    private let maxCacheSize: Int = 100
    private var accessOrder: [TileKey] = []

    public init() {}

    public func getTile(at position: CGPoint, zoom: CGFloat) -> CGImage? {
        let key = tileKey(for: position, zoom: zoom)

        if let cached = tileCache[key] {
            updateAccessOrder(key)
            return cached
        }

        return nil
    }

    public func cacheTile(_ image: CGImage, at position: CGPoint, zoom: CGFloat) {
        let key = tileKey(for: position, zoom: zoom)

        tileCache[key] = image
        updateAccessOrder(key)

        while tileCache.count > maxCacheSize {
            if let oldest = accessOrder.first {
                tileCache.removeValue(forKey: oldest)
                accessOrder.removeFirst()
            }
        }
    }

    public func invalidateTiles(intersecting rect: CGRect, zoom: CGFloat) {
        let keysToRemove = tileCache.keys.filter { key in
            let tileRect = tileRect(for: key)
            return tileRect.intersects(rect) && abs(key.zoom - zoom) < 0.01
        }

        for key in keysToRemove {
            tileCache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }

    public func clearCache() {
        tileCache.removeAll()
        accessOrder.removeAll()
    }

    private func tileKey(for position: CGPoint, zoom: CGFloat) -> TileKey {
        let tileX = Int(floor(position.x / tileSize.width))
        let tileY = Int(floor(position.y / tileSize.height))
        return TileKey(x: tileX, y: tileY, zoom: zoom)
    }

    private func tileRect(for key: TileKey) -> CGRect {
        CGRect(
            x: CGFloat(key.x) * tileSize.width,
            y: CGFloat(key.y) * tileSize.height,
            width: tileSize.width,
            height: tileSize.height
        )
    }

    private func updateAccessOrder(_ key: TileKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
}

private struct TileKey: Hashable {
    let x: Int
    let y: Int
    let zoom: CGFloat

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(Int(zoom * 1000))
    }

    static func == (lhs: TileKey, rhs: TileKey) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && abs(lhs.zoom - rhs.zoom) < 0.001
    }
}

public final class LODManager {
    public enum DetailLevel: Int, Comparable {
        case minimal = 0
        case low = 1
        case medium = 2
        case high = 3
        case full = 4

        public static func < (lhs: DetailLevel, rhs: DetailLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private let zoomThresholds: [CGFloat: DetailLevel] = [
        0.1: .minimal,
        0.25: .low,
        0.5: .medium,
        1.0: .high,
        2.0: .full
    ]

    public init() {}

    public func detailLevel(for zoom: CGFloat) -> DetailLevel {
        for (threshold, level) in zoomThresholds.sorted(by: { $0.key < $1.key }) {
            if zoom <= threshold {
                return level
            }
        }
        return .full
    }

    public func shouldRenderText(at zoom: CGFloat) -> Bool {
        detailLevel(for: zoom) >= .medium
    }

    public func shouldRenderShadows(at zoom: CGFloat) -> Bool {
        detailLevel(for: zoom) >= .high
    }

    public func shouldRenderImages(at zoom: CGFloat) -> Bool {
        detailLevel(for: zoom) >= .low
    }

    public func shouldRenderBorders(at zoom: CGFloat) -> Bool {
        detailLevel(for: zoom) >= .medium
    }

    public func imageQuality(for zoom: CGFloat) -> CGFloat {
        switch detailLevel(for: zoom) {
        case .minimal: return 0.1
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .full: return 1.0
        }
    }

    public func strokeWidth(original: CGFloat, zoom: CGFloat) -> CGFloat {
        let level = detailLevel(for: zoom)
        switch level {
        case .minimal, .low:
            return max(1, original * 0.5)
        case .medium:
            return original
        case .high, .full:
            return original
        }
    }
}

public struct PerformanceMetrics {
    public var frameTime: TimeInterval = 0
    public var fps: Double = 0
    public var visibleLayerCount: Int = 0
    public var totalLayerCount: Int = 0
    public var renderTime: TimeInterval = 0
    public var cullingTime: TimeInterval = 0
    public var memoryUsage: UInt64 = 0

    public var isHealthy: Bool {
        fps >= 55 && frameTime < 0.02
    }

    public var performanceLevel: PerformanceLevel {
        if fps >= 55 { return .excellent }
        if fps >= 45 { return .good }
        if fps >= 30 { return .acceptable }
        return .poor
    }

    public enum PerformanceLevel {
        case excellent, good, acceptable, poor

        public var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .acceptable: return "orange"
            case .poor: return "red"
            }
        }
    }
}

@Observable
public final class PerformanceMonitor {
    public private(set) var currentMetrics = PerformanceMetrics()
    public private(set) var metricsHistory: [PerformanceMetrics] = []

    private var frameStartTime: CFTimeInterval = 0
    private var frameTimes: [TimeInterval] = []
    private let maxHistorySize = 60
    private let frameTimeWindow = 30

    public init() {}

    public func beginFrame() {
        frameStartTime = CACurrentMediaTime()
    }

    public func endFrame(visibleLayers: Int, totalLayers: Int) {
        let frameTime = CACurrentMediaTime() - frameStartTime
        frameTimes.append(frameTime)

        if frameTimes.count > frameTimeWindow {
            frameTimes.removeFirst()
        }

        let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)

        currentMetrics.frameTime = avgFrameTime
        currentMetrics.fps = avgFrameTime > 0 ? 1.0 / avgFrameTime : 0
        currentMetrics.visibleLayerCount = visibleLayers
        currentMetrics.totalLayerCount = totalLayers
        currentMetrics.memoryUsage = getMemoryUsage()

        metricsHistory.append(currentMetrics)
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
    }

    public func recordRenderTime(_ time: TimeInterval) {
        currentMetrics.renderTime = time
    }

    public func recordCullingTime(_ time: TimeInterval) {
        currentMetrics.cullingTime = time
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    public func reset() {
        currentMetrics = PerformanceMetrics()
        metricsHistory.removeAll()
        frameTimes.removeAll()
    }
}

import SwiftUI

public struct PerformanceOverlayView: View {
    @Bindable var monitor: PerformanceMonitor

    public init(monitor: PerformanceMonitor) {
        self.monitor = monitor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(colorForPerformance)
                    .frame(width: 8, height: 8)

                Text(String(format: "%.1f FPS", monitor.currentMetrics.fps))
                    .font(.caption.monospacedDigit())
            }

            Text("\(monitor.currentMetrics.visibleLayerCount)/\(monitor.currentMetrics.totalLayerCount) visible")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(ByteCountFormatter.string(fromByteCount: Int64(monitor.currentMetrics.memoryUsage), countStyle: .memory))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var colorForPerformance: Color {
        switch monitor.currentMetrics.performanceLevel {
        case .excellent: return .green
        case .good: return .blue
        case .acceptable: return .orange
        case .poor: return .red
        }
    }
}
