import Foundation
import SwiftUI
import AppleVibeNotebook

// MARK: - Simulation Engine

/// Converts IR/Canvas into a runnable SwiftUI view hierarchy.
/// Powers the live preview with interactive simulation.
@Observable @MainActor
final class SimulationEngine {

    // MARK: - State

    var isRunning: Bool = false
    var currentScreen: UUID?
    var simulationState: SimulationState = SimulationState()
    var interactionHistory: [InteractionEvent] = []

    // MARK: - Configuration

    var targetDevice: DevicePreset = .iPhone15
    var colorScheme: ColorScheme = .light
    var dynamicTypeSize: DynamicTypeSize = .large
    var reduceMotion: Bool = false
    var increaseContrast: Bool = false

    // MARK: - Runtime

    private var stateBindings: [String: Any] = [:]
    private var actionHandlers: [String: () -> Void] = [:]

    // MARK: - Lifecycle

    func start(with document: CanvasDocument) {
        isRunning = true
        simulationState = SimulationState()
        interactionHistory.removeAll()

        // Initialize state from document
        initializeState(from: document)
    }

    func stop() {
        isRunning = false
    }

    func reset() {
        simulationState = SimulationState()
        interactionHistory.removeAll()
        stateBindings.removeAll()
    }

    // MARK: - State Management

    private func initializeState(from document: CanvasDocument) {
        // Initialize default state values for components
        for layer in document.layers {
            if layer.layerType == .element {
                // Set up default state for interactive elements
                stateBindings["\(layer.id)_isPressed"] = false
                stateBindings["\(layer.id)_isHovered"] = false
            }
        }
    }

    func getValue<T>(for key: String, default defaultValue: T) -> T {
        stateBindings[key] as? T ?? defaultValue
    }

    func setValue<T>(_ value: T, for key: String) {
        stateBindings[key] = value

        // Record state change
        interactionHistory.append(InteractionEvent(
            timestamp: Date(),
            type: .stateChange,
            details: "\(key) = \(value)"
        ))
    }

    // MARK: - View Building

    /// Builds a runnable SwiftUI view from canvas document.
    @ViewBuilder
    func buildView(from document: CanvasDocument) -> some View {
        let sortedLayers = document.visibleLayers

        ZStack {
            // Background
            #if os(iOS)
            Rectangle()
                .fill(Color(.systemBackground))
            #else
            Rectangle()
                .fill(Color.white)
            #endif

            // Layers
            ForEach(sortedLayers) { [self] layer in
                self.buildLayerView(layer, in: document)
            }
        }
        .frame(width: targetDevice.size.width, height: targetDevice.size.height)
        .preferredColorScheme(colorScheme)
        .dynamicTypeSize(dynamicTypeSize)
    }

    @ViewBuilder
    private func buildLayerView(_ layer: CanvasLayer, in document: CanvasDocument) -> some View {
        let screenOrigin = layer.frame.origin
        let screenSize = layer.frame.size

        Group {
            switch layer.layerType {
            case .text:
                buildTextView(layer)

            case .shape:
                buildShapeView(layer)

            case .image:
                buildImageView(layer)

            case .element:
                buildElementView(layer)

            case .container, .group:
                buildContainerView(layer, children: childLayers(of: layer, in: document))

            case .artboard:
                buildArtboardView(layer, children: childLayers(of: layer, in: document))

            case .component:
                buildComponentView(layer)

            default:
                EmptyView()
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .position(x: screenOrigin.x + screenSize.width / 2, y: screenOrigin.y + screenSize.height / 2)
        .opacity(layer.opacity)
        .rotationEffect(.degrees(layer.rotation))
    }

    private func childLayers(of parent: CanvasLayer, in document: CanvasDocument) -> [CanvasLayer] {
        document.layers.filter { $0.parentID == parent.id }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func buildTextView(_ layer: CanvasLayer) -> some View {
        Text(layer.name)
            .font(.system(size: 17))
            .foregroundColor(textColor(for: layer))
    }

    @ViewBuilder
    private func buildShapeView(_ layer: CanvasLayer) -> some View {
        let cornerRadius = layer.borderConfig?.cornerRadius ?? 0

        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fillColor(for: layer))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor(for: layer), lineWidth: layer.borderConfig?.width ?? 0)
            )
            .shadow(
                color: shadowColor(for: layer),
                radius: layer.shadowConfig?.radius ?? 0,
                x: layer.shadowConfig?.offset.x ?? 0,
                y: layer.shadowConfig?.offset.y ?? 0
            )
    }

    @ViewBuilder
    private func buildImageView(_ layer: CanvasLayer) -> some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: layer.borderConfig?.cornerRadius ?? 0))
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func buildElementView(_ layer: CanvasLayer) -> some View {
        let isPressed = getValue(for: "\(layer.id)_isPressed", default: false)

        Button { [self] in
            self.recordInteraction(.tap, on: layer)
        } label: {
            RoundedRectangle(cornerRadius: layer.borderConfig?.cornerRadius ?? 8)
                .fill(fillColor(for: layer))
                .overlay(
                    Text(layer.name)
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .semibold))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }

    @ViewBuilder
    private func buildContainerView(_ layer: CanvasLayer, children: [CanvasLayer]) -> some View {
        ZStack {
            // Container background
            if layer.backgroundFill != nil {
                RoundedRectangle(cornerRadius: layer.borderConfig?.cornerRadius ?? 0)
                    .fill(fillColor(for: layer))
            }

            // Children would be rendered here
            // In a full implementation, we'd recursively build child views
        }
    }

    @ViewBuilder
    private func buildArtboardView(_ layer: CanvasLayer, children: [CanvasLayer]) -> some View {
        ZStack {
            Rectangle()
                .fill(fillColor(for: layer))
        }
    }

    @ViewBuilder
    private func buildComponentView(_ layer: CanvasLayer) -> some View {
        // Component instances would render their template
        RoundedRectangle(cornerRadius: layer.borderConfig?.cornerRadius ?? 8)
            .fill(fillColor(for: layer))
            .overlay(
                VStack {
                    Image(systemName: "puzzlepiece.extension")
                        .foregroundColor(.white.opacity(0.5))
                    Text(layer.name)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            )
    }

    // MARK: - Color Helpers

    private func fillColor(for layer: CanvasLayer) -> Color {
        guard let fill = layer.backgroundFill, let canvasColor = fill.color else {
            return .clear
        }
        return Color(red: canvasColor.red, green: canvasColor.green, blue: canvasColor.blue, opacity: canvasColor.alpha)
    }

    private func borderColor(for layer: CanvasLayer) -> Color {
        guard let border = layer.borderConfig else {
            return .clear
        }
        return Color(red: border.color.red, green: border.color.green, blue: border.color.blue, opacity: border.color.alpha)
    }

    private func shadowColor(for layer: CanvasLayer) -> Color {
        guard let shadow = layer.shadowConfig else {
            return .clear
        }
        return Color(red: shadow.color.red, green: shadow.color.green, blue: shadow.color.blue, opacity: shadow.color.alpha)
    }

    private func textColor(for layer: CanvasLayer) -> Color {
        // Could extract from layer properties
        return colorScheme == .dark ? .white : .primary
    }

    // MARK: - Interaction Recording

    private func recordInteraction(_ type: InteractionType, on layer: CanvasLayer) {
        let event = InteractionEvent(
            timestamp: Date(),
            type: type,
            layerID: layer.id,
            layerName: layer.name,
            details: nil
        )
        interactionHistory.append(event)
    }
}

// MARK: - Simulation State

struct SimulationState {
    var navigationStack: [UUID] = []
    var presentedSheet: UUID?
    var alerts: [AlertState] = []
    var toasts: [ToastState] = []

    struct AlertState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    struct ToastState: Identifiable {
        let id = UUID()
        let message: String
        let duration: TimeInterval
    }
}

// MARK: - Interaction Event

struct InteractionEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: InteractionType
    var layerID: UUID?
    var layerName: String?
    var details: String?
}

enum InteractionType: String {
    case tap
    case longPress
    case swipe
    case scroll
    case drag
    case stateChange
    case navigation
}

// MARK: - Simulation Environment View

struct SimulationEnvironmentView: View {
    @Bindable var engine: SimulationEngine
    let document: CanvasDocument

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            simulationToolbar

            Divider()

            HStack(spacing: 0) {
                // Device preview
                devicePreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Interaction log
                interactionLog
                    .frame(width: 250)
            }
        }
    }

    private var simulationToolbar: some View {
        HStack {
            // Play/Stop
            Button {
                if engine.isRunning {
                    engine.stop()
                } else {
                    engine.start(with: document)
                }
            } label: {
                Image(systemName: engine.isRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.bordered)

            Button {
                engine.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            Divider()
                .frame(height: 20)

            // Device picker
            Picker("Device", selection: $engine.targetDevice) {
                ForEach(DevicePreset.allCases, id: \.self) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .frame(width: 150)

            // Color scheme
            Picker("Appearance", selection: $engine.colorScheme) {
                Image(systemName: "sun.max").tag(ColorScheme.light)
                Image(systemName: "moon").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)

            Spacer()

            // Status
            if engine.isRunning {
                Label("Running", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
            }
        }
        .padding()
    }

    private var devicePreview: some View {
        ZStack {
            Color(white: 0.15)

            engine.buildView(from: document)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .shadow(radius: 20)
        }
        .padding()
    }

    private var interactionLog: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Interactions")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(engine.interactionHistory.reversed()) { event in
                        InteractionLogRow(event: event)
                    }
                }
                .padding()
            }
        }
        .background(Color(white: 0.12))
    }
}

struct InteractionLogRow: View {
    let event: InteractionEvent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForType(event.type))
                .foregroundColor(colorForType(event.type))
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))

                if let name = event.layerName {
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(event.timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func iconForType(_ type: InteractionType) -> String {
        switch type {
        case .tap: return "hand.tap"
        case .longPress: return "hand.tap.fill"
        case .swipe: return "hand.draw"
        case .scroll: return "scroll"
        case .drag: return "arrow.up.and.down.and.arrow.left.and.right"
        case .stateChange: return "arrow.triangle.2.circlepath"
        case .navigation: return "arrow.right"
        }
    }

    private func colorForType(_ type: InteractionType) -> Color {
        switch type {
        case .tap, .longPress: return .blue
        case .swipe, .scroll: return .green
        case .drag: return .orange
        case .stateChange: return .purple
        case .navigation: return .teal
        }
    }
}
