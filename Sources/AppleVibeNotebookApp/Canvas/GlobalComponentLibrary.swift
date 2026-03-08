import Foundation
import SwiftUI
import AppleVibeNotebook

@Observable
@MainActor
public final class GlobalComponentLibrary {
    @MainActor public static let shared = GlobalComponentLibrary()

    public private(set) var userComponents: [SavedComponent] = []
    public private(set) var userPresets: [SavedPreset] = []
    public private(set) var userCompositions: [SavedComposition] = []

    private let fileManager = FileManager.default
    private var libraryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CanvasCode/ComponentLibrary", isDirectory: true)
    }

    private init() {
        ensureDirectoryExists()
        loadLibrary()
    }

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: libraryURL.appendingPathComponent("Components"), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: libraryURL.appendingPathComponent("Presets"), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: libraryURL.appendingPathComponent("Compositions"), withIntermediateDirectories: true)
    }

    public func saveAsComponent(
        layers: [CanvasLayer],
        name: String,
        category: String = "Custom",
        description: String = ""
    ) throws -> SavedComponent {
        let component = SavedComponent(
            id: UUID(),
            name: name,
            category: category,
            description: description,
            layers: layers,
            properties: extractConfigurableProperties(from: layers),
            createdAt: Date(),
            modifiedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(component)

        let fileURL = libraryURL
            .appendingPathComponent("Components")
            .appendingPathComponent("\(component.id.uuidString).json")

        try data.write(to: fileURL)

        userComponents.append(component)

        return component
    }

    public func saveAsPreset(
        baseComponentId: UUID,
        name: String,
        propertyValues: [String: PropertyValue]
    ) throws -> SavedPreset {
        let preset = SavedPreset(
            id: UUID(),
            name: name,
            baseComponentId: baseComponentId,
            propertyValues: propertyValues,
            createdAt: Date(),
            modifiedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(preset)

        let fileURL = libraryURL
            .appendingPathComponent("Presets")
            .appendingPathComponent("\(preset.id.uuidString).json")

        try data.write(to: fileURL)

        userPresets.append(preset)

        return preset
    }

    public func saveAsComposition(
        components: [CompositionChild],
        name: String,
        category: String = "Custom"
    ) throws -> SavedComposition {
        let composition = SavedComposition(
            id: UUID(),
            name: name,
            category: category,
            children: components,
            createdAt: Date(),
            modifiedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(composition)

        let fileURL = libraryURL
            .appendingPathComponent("Compositions")
            .appendingPathComponent("\(composition.id.uuidString).json")

        try data.write(to: fileURL)

        userCompositions.append(composition)

        return composition
    }

    public func deleteComponent(id: UUID) throws {
        let fileURL = libraryURL
            .appendingPathComponent("Components")
            .appendingPathComponent("\(id.uuidString).json")

        try fileManager.removeItem(at: fileURL)
        userComponents.removeAll { $0.id == id }
    }

    public func deletePreset(id: UUID) throws {
        let fileURL = libraryURL
            .appendingPathComponent("Presets")
            .appendingPathComponent("\(id.uuidString).json")

        try fileManager.removeItem(at: fileURL)
        userPresets.removeAll { $0.id == id }
    }

    public func deleteComposition(id: UUID) throws {
        let fileURL = libraryURL
            .appendingPathComponent("Compositions")
            .appendingPathComponent("\(id.uuidString).json")

        try fileManager.removeItem(at: fileURL)
        userCompositions.removeAll { $0.id == id }
    }

    public func instantiateComponent(_ component: SavedComponent, at position: CGPoint) -> [CanvasLayer] {
        component.layers.map { layer in
            var newLayer = layer
            newLayer.id = UUID()
            newLayer.frame.origin.x = position.x + layer.frame.origin.x
            newLayer.frame.origin.y = position.y + layer.frame.origin.y
            return newLayer
        }
    }

    public func instantiatePreset(_ preset: SavedPreset, at position: CGPoint) -> [CanvasLayer]? {
        guard let baseComponent = userComponents.first(where: { $0.id == preset.baseComponentId }) else {
            return nil
        }

        var layers = instantiateComponent(baseComponent, at: position)

        for (propertyName, value) in preset.propertyValues {
            applyPropertyValue(propertyName, value: value, to: &layers)
        }

        return layers
    }

    private func applyPropertyValue(_ name: String, value: PropertyValue, to layers: inout [CanvasLayer]) {
        for i in layers.indices {
            switch name {
            case "opacity":
                if case .number(let v) = value { layers[i].opacity = v }
            case "cornerRadius":
                if case .number(let v) = value {
                    var config = layers[i].borderConfig ?? BorderConfig()
                    config.cornerRadius = v
                    layers[i].borderConfig = config
                }
            case "rotation":
                if case .number(let v) = value { layers[i].rotation = v }
            default:
                break
            }
        }
    }

    private func loadLibrary() {
        loadComponents()
        loadPresets()
        loadCompositions()
    }

    private func loadComponents() {
        let componentsURL = libraryURL.appendingPathComponent("Components")
        guard let files = try? fileManager.contentsOfDirectory(at: componentsURL, includingPropertiesForKeys: nil) else { return }

        let decoder = JSONDecoder()
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let component = try? decoder.decode(SavedComponent.self, from: data) {
                userComponents.append(component)
            }
        }
    }

    private func loadPresets() {
        let presetsURL = libraryURL.appendingPathComponent("Presets")
        guard let files = try? fileManager.contentsOfDirectory(at: presetsURL, includingPropertiesForKeys: nil) else { return }

        let decoder = JSONDecoder()
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let preset = try? decoder.decode(SavedPreset.self, from: data) {
                userPresets.append(preset)
            }
        }
    }

    private func loadCompositions() {
        let compositionsURL = libraryURL.appendingPathComponent("Compositions")
        guard let files = try? fileManager.contentsOfDirectory(at: compositionsURL, includingPropertiesForKeys: nil) else { return }

        let decoder = JSONDecoder()
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let composition = try? decoder.decode(SavedComposition.self, from: data) {
                userCompositions.append(composition)
            }
        }
    }

    private func extractConfigurableProperties(from layers: [CanvasLayer]) -> [ConfigurableProperty] {
        var properties: [ConfigurableProperty] = []

        properties.append(ConfigurableProperty(
            key: "opacity",
            name: "Opacity",
            type: .slider(min: 0, max: 1),
            defaultValue: .number(1.0),
            group: "Appearance"
        ))

        properties.append(ConfigurableProperty(
            key: "cornerRadius",
            name: "Corner Radius",
            type: .slider(min: 0, max: 50),
            defaultValue: .number(0),
            group: "Shape"
        ))

        properties.append(ConfigurableProperty(
            key: "rotation",
            name: "Rotation",
            type: .slider(min: 0, max: 360),
            defaultValue: .number(0),
            group: "Transform"
        ))

        return properties
    }

    public func reload() {
        userComponents.removeAll()
        userPresets.removeAll()
        userCompositions.removeAll()
        loadLibrary()
    }
}

public struct SavedComponent: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var category: String
    public var description: String
    public var layers: [CanvasLayer]
    public var properties: [ConfigurableProperty]
    public let createdAt: Date
    public var modifiedAt: Date

    public var thumbnail: String {
        switch layers.first?.layerType {
        case .shape: return "square.fill"
        case .text: return "textformat"
        case .image: return "photo"
        case .container: return "square.stack.fill"
        case .component: return "puzzlepiece.fill"
        default: return "square.on.square"
        }
    }
}

public struct SavedPreset: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public let baseComponentId: UUID
    public var propertyValues: [String: PropertyValue]
    public let createdAt: Date
    public var modifiedAt: Date
}

public struct SavedComposition: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var category: String
    public var children: [CompositionChild]
    public let createdAt: Date
    public var modifiedAt: Date
}

public struct CompositionChild: Codable, Sendable {
    public let componentId: UUID?
    public let presetId: UUID?
    public let compositionId: UUID?
    public var relativePosition: CGPoint
    public var propertyOverrides: [String: PropertyValue]

    public init(componentId: UUID, position: CGPoint, overrides: [String: PropertyValue] = [:]) {
        self.componentId = componentId
        self.presetId = nil
        self.compositionId = nil
        self.relativePosition = position
        self.propertyOverrides = overrides
    }

    public init(presetId: UUID, position: CGPoint, overrides: [String: PropertyValue] = [:]) {
        self.componentId = nil
        self.presetId = presetId
        self.compositionId = nil
        self.relativePosition = position
        self.propertyOverrides = overrides
    }
}

public struct GlobalSaveAsComponentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let layers: [CanvasLayer]
    let onSave: (SavedComponent) -> Void

    @State private var name: String = ""
    @State private var category: String = "Custom"
    @State private var description: String = ""
    @State private var error: String?

    private let categories = ["Custom", "Buttons", "Cards", "Forms", "Navigation", "Layout", "Media", "Data Display"]

    public init(layers: [CanvasLayer], onSave: @escaping (SavedComponent) -> Void) {
        self.layers = layers
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Component Info") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Preview") {
                    HStack {
                        ForEach(layers.prefix(5)) { layer in
                            VStack {
                                Image(systemName: iconForLayerType(layer.layerType))
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text(layer.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }

                        if layers.count > 5 {
                            Text("+\(layers.count - 5) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Save as Component")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveComponent()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveComponent() {
        do {
            let component = try GlobalComponentLibrary.shared.saveAsComponent(
                layers: layers,
                name: name,
                category: category,
                description: description
            )
            onSave(component)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func iconForLayerType(_ type: LayerType) -> String {
        switch type {
        case .element: return "square"
        case .container: return "square.stack"
        case .component: return "puzzlepiece"
        case .group: return "folder"
        case .artboard: return "rectangle.portrait"
        case .mask: return "theatermasks"
        case .shape: return "square.on.circle"
        case .text: return "textformat"
        case .image: return "photo"
        }
    }
}

public struct LayerContextMenu: View {
    let layer: CanvasLayer
    let allSelectedLayers: [CanvasLayer]
    let onAction: (LayerContextAction) -> Void

    public enum LayerContextAction {
        case saveAsComponent
        case duplicate
        case delete
        case lock
        case unlock
        case hide
        case show
        case bringToFront
        case sendToBack
        case group
        case ungroup
        case copy
        case cut
        case paste
    }

    public init(layer: CanvasLayer, allSelectedLayers: [CanvasLayer], onAction: @escaping (LayerContextAction) -> Void) {
        self.layer = layer
        self.allSelectedLayers = allSelectedLayers
        self.onAction = onAction
    }

    public var body: some View {
        Group {
            Button {
                onAction(.saveAsComponent)
            } label: {
                Label("Save as Component", systemImage: "plus.square.on.square")
            }

            Divider()

            Button {
                onAction(.duplicate)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button {
                onAction(.copy)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                onAction(.cut)
            } label: {
                Label("Cut", systemImage: "scissors")
            }

            Divider()

            if allSelectedLayers.count > 1 {
                Button {
                    onAction(.group)
                } label: {
                    Label("Group", systemImage: "square.stack.3d.up")
                }
            }

            if layer.layerType == .group {
                Button {
                    onAction(.ungroup)
                } label: {
                    Label("Ungroup", systemImage: "square.stack.3d.down.right")
                }
            }

            Divider()

            Menu("Arrange") {
                Button {
                    onAction(.bringToFront)
                } label: {
                    Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled")
                }

                Button {
                    onAction(.sendToBack)
                } label: {
                    Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled")
                }
            }

            Divider()

            if layer.isLocked {
                Button {
                    onAction(.unlock)
                } label: {
                    Label("Unlock", systemImage: "lock.open")
                }
            } else {
                Button {
                    onAction(.lock)
                } label: {
                    Label("Lock", systemImage: "lock")
                }
            }

            if layer.isVisible {
                Button {
                    onAction(.hide)
                } label: {
                    Label("Hide", systemImage: "eye.slash")
                }
            } else {
                Button {
                    onAction(.show)
                } label: {
                    Label("Show", systemImage: "eye")
                }
            }

            Divider()

            Button(role: .destructive) {
                onAction(.delete)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
