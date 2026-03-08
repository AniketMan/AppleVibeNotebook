import Foundation
import AppleVibeNotebook

public protocol CanvasCommand: AnyObject {
    var description: String { get }
    func execute()
    func undo()
    func redo()
    func merge(with other: CanvasCommand) -> CanvasCommand?
}

@Observable
public final class CanvasUndoManager {
    public private(set) var undoStack: [CanvasCommand] = []
    public private(set) var redoStack: [CanvasCommand] = []
    public private(set) var isPerformingUndoRedo: Bool = false

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public var undoDescription: String? { undoStack.last?.description }
    public var redoDescription: String? { redoStack.last?.description }

    private let maxStackSize: Int
    private var lastCommandTime: Date?
    private let mergeInterval: TimeInterval = 0.5

    public init(maxStackSize: Int = 100) {
        self.maxStackSize = maxStackSize
    }

    public func execute(_ command: CanvasCommand) {
        let now = Date()

        if let lastTime = lastCommandTime,
           now.timeIntervalSince(lastTime) < mergeInterval,
           let lastCommand = undoStack.last,
           let mergedCommand = lastCommand.merge(with: command) {
            undoStack.removeLast()
            mergedCommand.execute()
            undoStack.append(mergedCommand)
        } else {
            command.execute()
            undoStack.append(command)
        }

        lastCommandTime = now

        redoStack.removeAll()

        while undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
    }

    public func undo() {
        guard let command = undoStack.popLast() else { return }

        isPerformingUndoRedo = true
        defer { isPerformingUndoRedo = false }

        command.undo()
        redoStack.append(command)
    }

    public func redo() {
        guard let command = redoStack.popLast() else { return }

        isPerformingUndoRedo = true
        defer { isPerformingUndoRedo = false }

        command.redo()
        undoStack.append(command)
    }

    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastCommandTime = nil
    }

    public func beginGrouping() -> CanvasCommandGroup {
        CanvasCommandGroup(undoManager: self)
    }
}

public final class CanvasCommandGroup {
    private weak var undoManager: CanvasUndoManager?
    private var commands: [CanvasCommand] = []
    private var description: String = "Multiple Changes"

    init(undoManager: CanvasUndoManager) {
        self.undoManager = undoManager
    }

    public func add(_ command: CanvasCommand) {
        commands.append(command)
    }

    public func setDescription(_ desc: String) {
        description = desc
    }

    public func commit() {
        guard !commands.isEmpty, let undoManager else { return }
        let group = GroupedCommand(commands: commands, description: description)
        undoManager.execute(group)
    }
}

public final class GroupedCommand: CanvasCommand {
    private let commands: [CanvasCommand]
    public let description: String

    init(commands: [CanvasCommand], description: String) {
        self.commands = commands
        self.description = description
    }

    public func execute() {
        for command in commands {
            command.execute()
        }
    }

    public func undo() {
        for command in commands.reversed() {
            command.undo()
        }
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        nil
    }
}

public final class AddLayerCommand: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let layer: CanvasLayer

    public var description: String { "Add \(layer.name)" }

    public init(document: CanvasDocumentHolder, layer: CanvasLayer) {
        self.document = document
        self.layer = layer
    }

    public func execute() {
        document?.addLayer(layer)
    }

    public func undo() {
        document?.removeLayer(id: layer.id)
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        nil
    }
}

public final class RemoveLayerCommand: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let layer: CanvasLayer
    private let originalIndex: Int

    public var description: String { "Delete \(layer.name)" }

    public init(document: CanvasDocumentHolder, layer: CanvasLayer, index: Int) {
        self.document = document
        self.layer = layer
        self.originalIndex = index
    }

    public func execute() {
        document?.removeLayer(id: layer.id)
    }

    public func undo() {
        document?.insertLayer(layer, at: originalIndex)
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        nil
    }
}

public final class MoveLayerCommand: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let layerId: UUID
    private let fromFrame: CanvasFrame
    private var toFrame: CanvasFrame

    public var description: String { "Move Layer" }

    public init(document: CanvasDocumentHolder, layerId: UUID, fromFrame: CanvasFrame, toFrame: CanvasFrame) {
        self.document = document
        self.layerId = layerId
        self.fromFrame = fromFrame
        self.toFrame = toFrame
    }

    public func execute() {
        document?.updateLayerFrame(id: layerId, frame: toFrame)
    }

    public func undo() {
        document?.updateLayerFrame(id: layerId, frame: fromFrame)
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        guard let moveCommand = other as? MoveLayerCommand,
              moveCommand.layerId == layerId else {
            return nil
        }

        return MoveLayerCommand(
            document: document!,
            layerId: layerId,
            fromFrame: fromFrame,
            toFrame: moveCommand.toFrame
        )
    }
}

public final class ResizeLayerCommand: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let layerId: UUID
    private let fromFrame: CanvasFrame
    private var toFrame: CanvasFrame

    public var description: String { "Resize Layer" }

    public init(document: CanvasDocumentHolder, layerId: UUID, fromFrame: CanvasFrame, toFrame: CanvasFrame) {
        self.document = document
        self.layerId = layerId
        self.fromFrame = fromFrame
        self.toFrame = toFrame
    }

    public func execute() {
        document?.updateLayerFrame(id: layerId, frame: toFrame)
    }

    public func undo() {
        document?.updateLayerFrame(id: layerId, frame: fromFrame)
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        guard let resizeCommand = other as? ResizeLayerCommand,
              resizeCommand.layerId == layerId else {
            return nil
        }

        return ResizeLayerCommand(
            document: document!,
            layerId: layerId,
            fromFrame: fromFrame,
            toFrame: resizeCommand.toFrame
        )
    }
}

public final class UpdateLayerPropertyCommand<T: Equatable>: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let layerId: UUID
    private let keyPath: WritableKeyPath<CanvasLayer, T>
    private let oldValue: T
    private var newValue: T
    private let propertyName: String

    public var description: String { "Change \(propertyName)" }

    public init(
        document: CanvasDocumentHolder,
        layerId: UUID,
        keyPath: WritableKeyPath<CanvasLayer, T>,
        oldValue: T,
        newValue: T,
        propertyName: String
    ) {
        self.document = document
        self.layerId = layerId
        self.keyPath = keyPath
        self.oldValue = oldValue
        self.newValue = newValue
        self.propertyName = propertyName
    }

    public func execute() {
        document?.updateLayerProperty(id: layerId, keyPath: keyPath, value: newValue)
    }

    public func undo() {
        document?.updateLayerProperty(id: layerId, keyPath: keyPath, value: oldValue)
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        guard let updateCommand = other as? UpdateLayerPropertyCommand<T>,
              updateCommand.layerId == layerId,
              updateCommand.keyPath == keyPath else {
            return nil
        }

        return UpdateLayerPropertyCommand(
            document: document!,
            layerId: layerId,
            keyPath: keyPath,
            oldValue: oldValue,
            newValue: updateCommand.newValue,
            propertyName: propertyName
        )
    }
}

public final class ReorderLayersCommand: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let oldOrder: [UUID]
    private let newOrder: [UUID]

    public var description: String { "Reorder Layers" }

    public init(document: CanvasDocumentHolder, oldOrder: [UUID], newOrder: [UUID]) {
        self.document = document
        self.oldOrder = oldOrder
        self.newOrder = newOrder
    }

    public func execute() {
        document?.reorderLayers(newOrder)
    }

    public func undo() {
        document?.reorderLayers(oldOrder)
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        guard let reorderCommand = other as? ReorderLayersCommand else { return nil }

        return ReorderLayersCommand(
            document: document!,
            oldOrder: oldOrder,
            newOrder: reorderCommand.newOrder
        )
    }
}

public final class GroupLayersCommand: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let layerIds: Set<UUID>
    private let groupId: UUID
    private let groupName: String
    private var originalParents: [UUID: UUID?] = [:]

    public var description: String { "Group Layers" }

    public init(document: CanvasDocumentHolder, layerIds: Set<UUID>, groupName: String = "Group") {
        self.document = document
        self.layerIds = layerIds
        self.groupId = UUID()
        self.groupName = groupName
    }

    public func execute() {
        originalParents = document?.captureParentState(for: layerIds) ?? [:]
        document?.groupLayers(layerIds, into: groupId, named: groupName)
    }

    public func undo() {
        document?.ungroupLayers(groupId: groupId, restoring: originalParents)
    }

    public func redo() {
        document?.groupLayers(layerIds, into: groupId, named: groupName)
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        nil
    }
}

public final class UngroupLayersCommand: CanvasCommand {
    private weak var document: CanvasDocumentHolder?
    private let groupId: UUID
    private var groupLayer: CanvasLayer?
    private var childIds: [UUID] = []

    public var description: String { "Ungroup Layers" }

    public init(document: CanvasDocumentHolder, groupId: UUID) {
        self.document = document
        self.groupId = groupId
    }

    public func execute() {
        groupLayer = document?.getLayer(id: groupId)
        childIds = document?.getChildIds(of: groupId) ?? []
        document?.ungroupLayers(groupId: groupId, restoring: [:])
    }

    public func undo() {
        if let group = groupLayer {
            document?.restoreGroup(group, childIds: childIds)
        }
    }

    public func redo() {
        execute()
    }

    public func merge(with other: CanvasCommand) -> CanvasCommand? {
        nil
    }
}

public protocol CanvasDocumentHolder: AnyObject {
    func addLayer(_ layer: CanvasLayer)
    func removeLayer(id: UUID)
    func insertLayer(_ layer: CanvasLayer, at index: Int)
    func updateLayerFrame(id: UUID, frame: CanvasFrame)
    func updateLayerProperty<T>(id: UUID, keyPath: WritableKeyPath<CanvasLayer, T>, value: T)
    func reorderLayers(_ order: [UUID])
    func groupLayers(_ ids: Set<UUID>, into groupId: UUID, named name: String)
    func ungroupLayers(groupId: UUID, restoring parentState: [UUID: UUID?])
    func captureParentState(for ids: Set<UUID>) -> [UUID: UUID?]
    func getLayer(id: UUID) -> CanvasLayer?
    func getChildIds(of parentId: UUID) -> [UUID]
    func restoreGroup(_ group: CanvasLayer, childIds: [UUID])
}

import SwiftUI

public struct UndoRedoToolbar: View {
    @Bindable var undoManager: CanvasUndoManager

    public init(undoManager: CanvasUndoManager) {
        self.undoManager = undoManager
    }

    public var body: some View {
        HStack(spacing: 16) {
            Button {
                undoManager.undo()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)

                    if let desc = undoManager.undoDescription {
                        Text(desc)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
            .disabled(!undoManager.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button {
                undoManager.redo()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.title2)

                    if let desc = undoManager.redoDescription {
                        Text(desc)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
            .disabled(!undoManager.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

public struct UndoHistoryView: View {
    @Bindable var undoManager: CanvasUndoManager
    @State private var showHistory = false

    public init(undoManager: CanvasUndoManager) {
        self.undoManager = undoManager
    }

    public var body: some View {
        Button {
            showHistory.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                Text("\(undoManager.undoStack.count)")
                    .font(.caption.monospacedDigit())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary)
            .clipShape(Capsule())
        }
        .popover(isPresented: $showHistory) {
            historyList
                .frame(width: 250, height: 300)
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.headline)
                .padding()

            Divider()

            if undoManager.undoStack.isEmpty && undoManager.redoStack.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Your actions will appear here")
                )
            } else {
                List {
                    if !undoManager.redoStack.isEmpty {
                        Section("Redo") {
                            ForEach(Array(undoManager.redoStack.enumerated().reversed()), id: \.offset) { _, command in
                                historyRow(command: command, isFuture: true)
                            }
                        }
                    }

                    Section("Undo") {
                        ForEach(Array(undoManager.undoStack.enumerated().reversed()), id: \.offset) { index, command in
                            historyRow(command: command, isFuture: false)
                                .onTapGesture {
                                    undoToIndex(index)
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func historyRow(command: CanvasCommand, isFuture: Bool) -> some View {
        HStack {
            Image(systemName: isFuture ? "arrow.uturn.forward" : "arrow.uturn.backward")
                .foregroundColor(isFuture ? .blue : .secondary)

            Text(command.description)
                .foregroundColor(isFuture ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func undoToIndex(_ targetIndex: Int) {
        let stepsBack = undoManager.undoStack.count - 1 - targetIndex
        for _ in 0..<stepsBack {
            undoManager.undo()
        }
        showHistory = false
    }
}
