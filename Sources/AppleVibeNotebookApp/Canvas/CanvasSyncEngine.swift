import Foundation
import Combine
import AppleVibeNotebook

// MARK: - Canvas Sync Engine

/// Manages real-time bidirectional synchronization between canvas and code.
/// Debounces updates at 16ms for 60fps responsiveness.
@Observable @MainActor
final class CanvasSyncEngine {

    // MARK: - State

    var isEnabled: Bool = true
    var isSyncing: Bool = false
    var lastSyncTime: Date?
    var syncError: String?

    // Generated code output
    var swiftUICode: String = ""
    var reactCode: String = ""

    // MARK: - Configuration

    var debounceInterval: TimeInterval = 0.016  // 16ms = 60fps
    var autoSync: Bool = true

    // MARK: - Private

    private var syncTask: Task<Void, Never>?
    private var pendingDocument: CanvasDocument?
    private var lastDocumentHash: Int = 0

    private let canvasToIRCompiler = CanvasToIRCompiler()
    private let swiftUICodeGenerator = SwiftSyntaxCodeGenerator()
    private let reactCodeGenerator = ReactCodeGenerator()
    private let codeToCanvasCompiler = CodeToCanvasCompiler()

    // MARK: - Initialization

    init() {}

    // MARK: - Canvas → Code Sync

    /// Schedules a sync from canvas to code.
    func scheduleSync(from document: CanvasDocument) {
        guard isEnabled else { return }

        // Check if document actually changed
        let newHash = document.hashValue
        guard newHash != lastDocumentHash else { return }
        lastDocumentHash = newHash

        pendingDocument = document

        // Cancel existing task
        syncTask?.cancel()

        // Schedule debounced sync
        syncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await performCanvasToCodeSync()
        }
    }

    /// Immediately syncs canvas to code.
    func syncNow(from document: CanvasDocument) async {
        pendingDocument = document
        await performCanvasToCodeSync()
    }

    @MainActor
    private func performCanvasToCodeSync() async {
        guard let document = pendingDocument else { return }

        isSyncing = true
        syncError = nil

        do {
            // Compile canvas to IR
            let ir = canvasToIRCompiler.compile(document)

            // Generate SwiftUI code
            let swiftUIFiles = swiftUICodeGenerator.generate(from: ir)
            swiftUICode = swiftUIFiles.map(\.content).joined(separator: "\n\n// MARK: - \n\n")

            // Generate React code
            let reactFiles = reactCodeGenerator.generate(from: ir)
            reactCode = reactFiles.map(\.content).joined(separator: "\n\n// --- \n\n")

            lastSyncTime = Date()
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    // MARK: - Code → Canvas Sync

    /// Syncs code changes back to the canvas.
    func syncCodeToCanvas(swiftUICode: String, into document: inout CanvasDocument) async throws {
        guard isEnabled else { return }

        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        // Parse SwiftUI code to IR
        // Note: This would require a Swift parser - for now, we'll use a simplified approach
        // In a full implementation, you'd use SwiftSyntax to parse the code

        // For demonstration, we'll just mark the sync time
        lastSyncTime = Date()
    }

    /// Syncs React code changes back to the canvas.
    func syncReactCodeToCanvas(reactCode: String, into document: inout CanvasDocument) async throws {
        guard isEnabled else { return }

        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        // Parse React code to IR
        // This would use the existing ReactParser

        lastSyncTime = Date()
    }

    // MARK: - Incremental Sync

    /// Performs an incremental sync for a single layer change.
    func syncLayerChange(_ layer: CanvasLayer, in document: CanvasDocument) {
        guard isEnabled && autoSync else { return }

        // For single layer changes, we can do targeted code updates
        // This is more efficient than full document sync

        Task { @MainActor in
            // Find the component containing this layer
            if let componentID = layer.componentID {
                // Generate code only for this component
                // This would be implemented with incremental code generation
            }

            // Fall back to full sync for now
            scheduleSync(from: document)
        }
    }

    // MARK: - Conflict Resolution

    enum SyncDirection {
        case canvasToCode
        case codeToCanvas
    }

    /// Resolves conflicts when both canvas and code have been edited.
    func resolveConflict(
        canvasDocument: CanvasDocument,
        codeContent: String,
        preferredDirection: SyncDirection
    ) async -> CanvasDocument {
        switch preferredDirection {
        case .canvasToCode:
            // Canvas wins - regenerate code from canvas
            await syncNow(from: canvasDocument)
            return canvasDocument

        case .codeToCanvas:
            // Code wins - regenerate canvas from code
            var document = canvasDocument
            try? await syncCodeToCanvas(swiftUICode: codeContent, into: &document)
            return document
        }
    }

    // MARK: - Utilities

    /// Clears all generated code.
    func clearGeneratedCode() {
        swiftUICode = ""
        reactCode = ""
        lastSyncTime = nil
    }

    /// Stops any pending sync operations.
    func cancelPendingSync() {
        syncTask?.cancel()
        syncTask = nil
        pendingDocument = nil
    }
}

// MARK: - Document Hashable

extension CanvasDocument: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(layers.count)
        for layer in layers {
            hasher.combine(layer.id)
            hasher.combine(layer.frame.origin.x)
            hasher.combine(layer.frame.origin.y)
            hasher.combine(layer.frame.size.width)
            hasher.combine(layer.frame.size.height)
        }
    }

    public static func == (lhs: CanvasDocument, rhs: CanvasDocument) -> Bool {
        lhs.id == rhs.id && lhs.layers.count == rhs.layers.count
    }
}

// MARK: - Code Diff Tracker

/// Tracks changes between code versions for targeted updates.
struct CodeDiffTracker {
    struct Change {
        let componentName: String
        let oldCode: String
        let newCode: String
        let changeType: ChangeType
    }

    enum ChangeType {
        case added
        case modified
        case removed
    }

    /// Computes the diff between two code strings.
    func computeDiff(oldCode: String, newCode: String) -> [Change] {
        // Simple line-based diff
        // In a full implementation, use a proper diff algorithm
        var changes: [Change] = []

        let oldLines = Set(oldCode.components(separatedBy: .newlines))
        let newLines = Set(newCode.components(separatedBy: .newlines))

        let added = newLines.subtracting(oldLines)
        let removed = oldLines.subtracting(newLines)

        for line in added {
            if line.contains("struct") || line.contains("func") {
                changes.append(Change(
                    componentName: extractComponentName(from: line) ?? "Unknown",
                    oldCode: "",
                    newCode: line,
                    changeType: .added
                ))
            }
        }

        for line in removed {
            if line.contains("struct") || line.contains("func") {
                changes.append(Change(
                    componentName: extractComponentName(from: line) ?? "Unknown",
                    oldCode: line,
                    newCode: "",
                    changeType: .removed
                ))
            }
        }

        return changes
    }

    private func extractComponentName(from line: String) -> String? {
        let pattern = #"(struct|class|func)\s+(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return String(line[range])
    }
}
