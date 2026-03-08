import SwiftUI
import AppleVibeNotebook

// MARK: - Property Inspector View

/// Dynamic property editor with sliders, color pickers, toggles, and more.
/// Like Xcode's Attributes Inspector but optimized for visual design.
struct PropertyInspectorView: View {
    @Bindable var canvasState: CanvasState

    @State private var expandedSections: Set<String> = ["Transform", "Appearance", "Layout"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if let layer = canvasState.singleSelectedLayer {
                // Single layer selected
                ScrollView {
                    LazyVStack(spacing: 0) {
                        layerInfoSection(layer)
                        transformSection(layer)
                        appearanceSection(layer)
                        borderSection(layer)
                        shadowSection(layer)

                        // Component-specific properties
                        if layer.componentID != nil {
                            componentPropertiesSection(layer)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else if canvasState.selectedLayerIDs.count > 1 {
                // Multiple layers selected
                multipleSelectionView
            } else {
                // No selection
                noSelectionView
            }
        }
        .frame(width: 280)
        .background(Color(white: 0.15))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Inspector")
                .font(.headline)

            Spacer()

            if canvasState.singleSelectedLayer != nil {
                Menu {
                    Button("Copy Style") {}
                    Button("Paste Style") {}
                    Divider()
                    Button("Reset to Default") {}
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: - Layer Info Section

    private func layerInfoSection(_ layer: CanvasLayer) -> some View {
        InspectorSection(title: "Layer", icon: "square.on.square", isExpanded: binding(for: "Layer")) {
            VStack(spacing: 12) {
                // Name
                PropertyRow(label: "Name") {
                    TextField("Layer Name", text: bindingForLayerName(layer))
                        .textFieldStyle(.roundedBorder)
                }

                // Type (read-only)
                PropertyRow(label: "Type") {
                    HStack {
                        Image(systemName: layer.layerType.icon)
                            .foregroundColor(.secondary)
                        Text(layer.layerType.rawValue.capitalized)
                            .foregroundColor(.secondary)
                    }
                }

                // Visibility & Lock
                HStack {
                    Toggle("Visible", isOn: bindingForVisibility(layer))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    Text("Visible")
                        .font(.system(size: 12))

                    Spacer()

                    Toggle("Locked", isOn: bindingForLock(layer))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    Text("Locked")
                        .font(.system(size: 12))
                }
            }
        }
    }

    // MARK: - Transform Section

    private func transformSection(_ layer: CanvasLayer) -> some View {
        InspectorSection(title: "Transform", icon: "arrow.up.left.and.arrow.down.right", isExpanded: binding(for: "Transform")) {
            VStack(spacing: 12) {
                // Position
                HStack(spacing: 8) {
                    PropertyField(label: "X", value: bindingForX(layer))
                    PropertyField(label: "Y", value: bindingForY(layer))
                }

                // Size
                HStack(spacing: 8) {
                    PropertyField(label: "W", value: bindingForWidth(layer))
                    PropertyField(label: "H", value: bindingForHeight(layer))
                }

                // Rotation
                PropertyRow(label: "Rotation") {
                    HStack {
                        Slider(value: bindingForRotation(layer), in: -180...180)
                        Text("\(Int(layer.rotation))°")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 40)
                    }
                }
            }
        }
    }

    // MARK: - Appearance Section

    private func appearanceSection(_ layer: CanvasLayer) -> some View {
        InspectorSection(title: "Appearance", icon: "paintbrush", isExpanded: binding(for: "Appearance")) {
            VStack(spacing: 12) {
                // Opacity
                PropertyRow(label: "Opacity") {
                    HStack {
                        Slider(value: bindingForOpacity(layer), in: 0...1)
                        Text("\(Int(layer.opacity * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 40)
                    }
                }

                // Blend Mode
                PropertyRow(label: "Blend") {
                    Picker("Blend Mode", selection: bindingForBlendMode(layer)) {
                        ForEach(BlendMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .labelsHidden()
                }

                // Fill Color
                if layer.backgroundFill != nil {
                    PropertyRow(label: "Fill") {
                        ColorPicker("", selection: bindingForFillColor(layer), supportsOpacity: true)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Border Section

    private func borderSection(_ layer: CanvasLayer) -> some View {
        InspectorSection(title: "Border", icon: "square", isExpanded: binding(for: "Border")) {
            VStack(spacing: 12) {
                // Border Width
                PropertyRow(label: "Width") {
                    HStack {
                        Slider(value: bindingForBorderWidth(layer), in: 0...10)
                        Text("\(Int(layer.borderConfig?.width ?? 0))")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 30)
                    }
                }

                // Border Color
                PropertyRow(label: "Color") {
                    ColorPicker("", selection: bindingForBorderColor(layer), supportsOpacity: true)
                        .labelsHidden()
                }

                // Corner Radius
                PropertyRow(label: "Radius") {
                    HStack {
                        Slider(value: bindingForCornerRadius(layer), in: 0...50)
                        Text("\(Int(layer.borderConfig?.cornerRadius ?? 0))")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 30)
                    }
                }
            }
        }
    }

    // MARK: - Shadow Section

    private func shadowSection(_ layer: CanvasLayer) -> some View {
        InspectorSection(title: "Shadow", icon: "shadow", isExpanded: binding(for: "Shadow")) {
            VStack(spacing: 12) {
                // Shadow Radius
                PropertyRow(label: "Blur") {
                    HStack {
                        Slider(value: bindingForShadowRadius(layer), in: 0...50)
                        Text("\(Int(layer.shadowConfig?.radius ?? 0))")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 30)
                    }
                }

                // Shadow Color
                PropertyRow(label: "Color") {
                    ColorPicker("", selection: bindingForShadowColor(layer), supportsOpacity: true)
                        .labelsHidden()
                }

                // Shadow Offset
                HStack(spacing: 8) {
                    PropertyField(label: "X", value: bindingForShadowX(layer))
                    PropertyField(label: "Y", value: bindingForShadowY(layer))
                }
            }
        }
    }

    // MARK: - Component Properties Section

    private func componentPropertiesSection(_ layer: CanvasLayer) -> some View {
        InspectorSection(title: "Component", icon: "puzzlepiece.extension", isExpanded: binding(for: "Component")) {
            Text("Component properties coming soon")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Multiple Selection View

    private var multipleSelectionView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("\(canvasState.selectedLayerIDs.count) Layers Selected")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Select a single layer to edit its properties")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - No Selection View

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Selection")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Select a layer on the canvas to edit its properties")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Bindings

    private func binding(for section: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    private func bindingForLayerName(_ layer: CanvasLayer) -> Binding<String> {
        Binding(
            get: { layer.name },
            set: { newName in
                canvasState.updateLayer(id: layer.id) { $0.name = newName }
            }
        )
    }

    private func bindingForVisibility(_ layer: CanvasLayer) -> Binding<Bool> {
        Binding(
            get: { layer.isVisible },
            set: { isVisible in
                canvasState.updateLayer(id: layer.id) { $0.isVisible = isVisible }
            }
        )
    }

    private func bindingForLock(_ layer: CanvasLayer) -> Binding<Bool> {
        Binding(
            get: { layer.isLocked },
            set: { isLocked in
                canvasState.updateLayer(id: layer.id) { $0.isLocked = isLocked }
            }
        )
    }

    private func bindingForX(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { layer.frame.origin.x },
            set: { x in
                canvasState.updateLayer(id: layer.id) { $0.frame.origin.x = x }
            }
        )
    }

    private func bindingForY(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { layer.frame.origin.y },
            set: { y in
                canvasState.updateLayer(id: layer.id) { $0.frame.origin.y = y }
            }
        )
    }

    private func bindingForWidth(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { layer.frame.size.width },
            set: { width in
                canvasState.updateLayer(id: layer.id) { $0.frame.size.width = max(1, width) }
            }
        )
    }

    private func bindingForHeight(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { layer.frame.size.height },
            set: { height in
                canvasState.updateLayer(id: layer.id) { $0.frame.size.height = max(1, height) }
            }
        )
    }

    private func bindingForRotation(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { layer.rotation },
            set: { rotation in
                canvasState.updateLayer(id: layer.id) { $0.rotation = rotation }
            }
        )
    }

    private func bindingForOpacity(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { layer.opacity },
            set: { opacity in
                canvasState.updateLayer(id: layer.id) { $0.opacity = opacity }
            }
        )
    }

    private func bindingForBlendMode(_ layer: CanvasLayer) -> Binding<AppleVibeNotebook.BlendMode> {
        Binding(
            get: { layer.blendMode },
            set: { blendMode in
                canvasState.updateLayer(id: layer.id) { $0.blendMode = blendMode }
            }
        )
    }

    private func bindingForFillColor(_ layer: CanvasLayer) -> Binding<Color> {
        Binding(
            get: {
                if let color = layer.backgroundFill?.color {
                    return Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
                }
                return .clear
            },
            set: { color in
                canvasState.updateLayer(id: layer.id) { layer in
                    let components = color.cgColor?.components ?? [0, 0, 0, 0]
                    let canvasColor = CanvasColor(
                        red: components[0],
                        green: components.count > 1 ? components[1] : components[0],
                        blue: components.count > 2 ? components[2] : components[0],
                        alpha: components.count > 3 ? components[3] : 1
                    )
                    layer.backgroundFill = FillConfig(fillType: .solid, color: canvasColor)
                }
            }
        )
    }

    private func bindingForBorderWidth(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { Double(layer.borderConfig?.width ?? 0) },
            set: { width in
                canvasState.updateLayer(id: layer.id) { layer in
                    var config = layer.borderConfig ?? BorderConfig()
                    config.width = width
                    layer.borderConfig = config
                }
            }
        )
    }

    private func bindingForBorderColor(_ layer: CanvasLayer) -> Binding<Color> {
        Binding(
            get: {
                if let color = layer.borderConfig?.color {
                    return Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
                }
                return .black
            },
            set: { color in
                canvasState.updateLayer(id: layer.id) { layer in
                    var config = layer.borderConfig ?? BorderConfig()
                    let components = color.cgColor?.components ?? [0, 0, 0, 1]
                    config.color = CanvasColor(
                        red: components[0],
                        green: components.count > 1 ? components[1] : components[0],
                        blue: components.count > 2 ? components[2] : components[0],
                        alpha: components.count > 3 ? components[3] : 1
                    )
                    layer.borderConfig = config
                }
            }
        )
    }

    private func bindingForCornerRadius(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { Double(layer.borderConfig?.cornerRadius ?? 0) },
            set: { radius in
                canvasState.updateLayer(id: layer.id) { layer in
                    var config = layer.borderConfig ?? BorderConfig()
                    config.cornerRadius = radius
                    layer.borderConfig = config
                }
            }
        )
    }

    private func bindingForShadowRadius(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { Double(layer.shadowConfig?.radius ?? 0) },
            set: { radius in
                canvasState.updateLayer(id: layer.id) { layer in
                    var config = layer.shadowConfig ?? ShadowConfig()
                    config.radius = radius
                    layer.shadowConfig = config
                }
            }
        )
    }

    private func bindingForShadowColor(_ layer: CanvasLayer) -> Binding<Color> {
        Binding(
            get: {
                if let color = layer.shadowConfig?.color {
                    return Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
                }
                return Color.black.opacity(0.25)
            },
            set: { color in
                canvasState.updateLayer(id: layer.id) { layer in
                    var config = layer.shadowConfig ?? ShadowConfig()
                    let components = color.cgColor?.components ?? [0, 0, 0, 0.25]
                    config.color = CanvasColor(
                        red: components[0],
                        green: components.count > 1 ? components[1] : components[0],
                        blue: components.count > 2 ? components[2] : components[0],
                        alpha: components.count > 3 ? components[3] : 0.25
                    )
                    layer.shadowConfig = config
                }
            }
        )
    }

    private func bindingForShadowX(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { Double(layer.shadowConfig?.offset.x ?? 0) },
            set: { x in
                canvasState.updateLayer(id: layer.id) { layer in
                    var config = layer.shadowConfig ?? ShadowConfig()
                    config.offset.x = x
                    layer.shadowConfig = config
                }
            }
        )
    }

    private func bindingForShadowY(_ layer: CanvasLayer) -> Binding<Double> {
        Binding(
            get: { Double(layer.shadowConfig?.offset.y ?? 0) },
            set: { y in
                canvasState.updateLayer(id: layer.id) { layer in
                    var config = layer.shadowConfig ?? ShadowConfig()
                    config.offset.y = y
                    layer.shadowConfig = config
                }
            }
        )
    }
}

// MARK: - Inspector Section

struct InspectorSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    Text(title)
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content
            if isExpanded {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider()
                .padding(.leading, 16)
        }
    }
}

// MARK: - Property Row

struct PropertyRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            content()
        }
    }
}

// MARK: - Property Field

struct PropertyField: View {
    let label: String
    @Binding var value: Double

    @State private var textValue = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            TextField("", text: $textValue)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .focused($isFocused)
                .onAppear {
                    textValue = String(format: "%.0f", value)
                }
                .onChange(of: value) { _, newValue in
                    if !isFocused {
                        textValue = String(format: "%.0f", newValue)
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused, let number = Double(textValue) {
                        value = number
                    }
                }
                .onSubmit {
                    if let number = Double(textValue) {
                        value = number
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    let state = CanvasState()
    state.addLayer(CanvasLayer(
        name: "Test Layer",
        frame: CanvasFrame(origin: CGPoint(x: 100, y: 100), size: CGSize(width: 200, height: 150)),
        layerType: .shape,
        borderConfig: BorderConfig(cornerRadius: 12),
        backgroundFill: FillConfig(fillType: .solid, color: .accent)
    ))

    return PropertyInspectorView(canvasState: state)
        .frame(height: 800)
}
