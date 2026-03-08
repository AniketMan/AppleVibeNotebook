import SwiftUI
import AppleVibeNotebook

// MARK: - Canvas Toolbar

/// Floating toolbar with tools, zoom controls, and quick actions.
/// Adapts to platform: docked on Mac, floating on iPad, minimal on iPhone.
struct CanvasToolbar: View {
    @Bindable var canvasState: CanvasState

    @State private var showZoomMenu = false
    @State private var showViewOptions = false

    var body: some View {
        HStack(spacing: 0) {
            // Tool section
            toolSection

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            // Zoom section
            zoomSection

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            // Action section
            actionSection

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            // View options
            viewOptionsSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }

    // MARK: - Tool Section

    private var toolSection: some View {
        HStack(spacing: 4) {
            ForEach(CanvasTool.allCases) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: canvasState.activeTool == tool,
                    action: { canvasState.setTool(tool) }
                )
            }
        }
    }

    // MARK: - Zoom Section

    private var zoomSection: some View {
        HStack(spacing: 8) {
            Button {
                canvasState.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(ToolbarButtonStyle())
            .keyboardShortcut("-", modifiers: .command)

            Button {
                showZoomMenu.toggle()
            } label: {
                Text(canvasState.document.viewport.zoomPercentage)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(minWidth: 50)
            }
            .buttonStyle(ToolbarButtonStyle())
            .popover(isPresented: $showZoomMenu) {
                zoomMenu
            }

            Button {
                canvasState.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(ToolbarButtonStyle())
            .keyboardShortcut("=", modifiers: .command)
        }
    }

    private var zoomMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([25, 50, 100, 150, 200, 400], id: \.self) { percentage in
                Button {
                    let newScale = CGFloat(percentage) / 100.0
                    canvasState.zoom(
                        to: newScale,
                        anchor: CGPoint(
                            x: canvasState.document.viewport.visibleRect.midX,
                            y: canvasState.document.viewport.visibleRect.midY
                        )
                    )
                    showZoomMenu = false
                } label: {
                    HStack {
                        Text("\(percentage)%")
                        Spacer()
                        if Int(canvasState.document.viewport.scale * 100) == percentage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if percentage == 100 {
                    Divider()
                }
            }

            Divider()

            Button {
                canvasState.zoomToFit()
                showZoomMenu = false
            } label: {
                HStack {
                    Text("Zoom to Fit")
                    Spacer()
                    Text("⌘0")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Button {
                canvasState.zoomTo100()
                showZoomMenu = false
            } label: {
                HStack {
                    Text("Zoom to 100%")
                    Spacer()
                    Text("⌘1")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 180)
        .padding(.vertical, 8)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        HStack(spacing: 4) {
            Button {
                canvasState.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(!canvasState.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button {
                canvasState.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(!canvasState.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
    }

    // MARK: - View Options Section

    private var viewOptionsSection: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    canvasState.showGrid.toggle()
                }
            } label: {
                Image(systemName: "grid")
            }
            .buttonStyle(ToolbarButtonStyle(isActive: canvasState.showGrid))

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    canvasState.showSmartGuides.toggle()
                }
            } label: {
                Image(systemName: "ruler")
            }
            .buttonStyle(ToolbarButtonStyle(isActive: canvasState.showSmartGuides))

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    canvasState.showLayerPanel.toggle()
                }
            } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(ToolbarButtonStyle(isActive: canvasState.showLayerPanel))

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    canvasState.showObjectLibrary.toggle()
                }
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .buttonStyle(ToolbarButtonStyle(isActive: canvasState.showObjectLibrary))
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: CanvasTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.icon)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(ToolbarButtonStyle(isActive: isSelected))
        .help(tool.rawValue)
        .if(tool.shortcut != nil) { view in
            view.keyboardShortcut(tool.shortcut!, modifiers: [])
        }
    }
}

// MARK: - Toolbar Button Style

struct ToolbarButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(isActive ? .white : .primary)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor(configuration: configuration))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if isActive {
            return Color.accentColor
        } else if configuration.isPressed {
            return Color.primary.opacity(0.1)
        }
        return Color.clear
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Contextual Toolbar

/// Context-sensitive toolbar that appears above selected layers
struct ContextualToolbar: View {
    @Bindable var canvasState: CanvasState

    var body: some View {
        Group {
            if !canvasState.selectedLayerIDs.isEmpty {
                HStack(spacing: 4) {
                    // Alignment buttons
                    Group {
                        Button {
                            alignLayers(.leading)
                        } label: {
                            Image(systemName: "align.horizontal.left")
                        }

                        Button {
                            alignLayers(.center)
                        } label: {
                            Image(systemName: "align.horizontal.center")
                        }

                        Button {
                            alignLayers(.trailing)
                        } label: {
                            Image(systemName: "align.horizontal.right")
                        }
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    .disabled(canvasState.selectedLayerIDs.count < 2)

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 4)

                    // Z-order buttons
                    Button {
                        canvasState.bringToFront()
                    } label: {
                        Image(systemName: "square.3.layers.3d.top.filled")
                    }
                    .buttonStyle(ToolbarButtonStyle())

                    Button {
                        canvasState.sendToBack()
                    } label: {
                        Image(systemName: "square.3.layers.3d.bottom.filled")
                    }
                    .buttonStyle(ToolbarButtonStyle())

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 4)

                    // Group/Ungroup
                    Button {
                        canvasState.groupSelectedLayers()
                    } label: {
                        Image(systemName: "rectangle.3.group")
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    .disabled(canvasState.selectedLayerIDs.count < 2)

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 4)

                    // Duplicate
                    Button {
                        canvasState.duplicateSelectedLayers()
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    .keyboardShortcut("d", modifiers: .command)

                    // Delete
                    Button {
                        canvasState.deleteSelectedLayers()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    .keyboardShortcut(.delete, modifiers: [])
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
            }
        }
    }

    private func alignLayers(_ alignment: HorizontalAlignment) {
        guard canvasState.selectedLayerIDs.count > 1 else { return }

        let selectedLayers = canvasState.selectedLayers
        guard let referenceLayer = selectedLayers.first else { return }

        for layerID in canvasState.selectedLayerIDs {
            canvasState.updateLayer(id: layerID) { layer in
                switch alignment {
                case .leading:
                    layer.frame.origin.x = referenceLayer.frame.origin.x
                case .center:
                    layer.frame.origin.x = referenceLayer.frame.midX - layer.frame.size.width / 2
                case .trailing:
                    layer.frame.origin.x = referenceLayer.frame.maxX - layer.frame.size.width
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Quick Insert Menu

struct QuickInsertMenu: View {
    @Bindable var canvasState: CanvasState
    let insertPosition: CGPoint
    let onDismiss: () -> Void

    private let items: [(String, String, LayerType)] = [
        ("Rectangle", "rectangle.fill", .shape),
        ("Ellipse", "circle.fill", .shape),
        ("Text", "textformat", .text),
        ("Image", "photo.fill", .image),
        ("Button", "button.horizontal.fill", .element),
        ("Stack", "square.stack.fill", .container),
        ("Artboard", "rectangle.on.rectangle", .artboard),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.0) { name, icon, layerType in
                Button {
                    insertLayer(name: name, type: layerType)
                    onDismiss()
                } label: {
                    HStack {
                        Image(systemName: icon)
                            .frame(width: 24)
                        Text(name)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
        }
        .frame(width: 160)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func insertLayer(name: String, type: LayerType) {
        let canvasPoint = canvasState.document.viewport.screenToCanvas(insertPosition)

        var layer = CanvasLayer(
            name: name,
            frame: CanvasFrame(
                origin: CGPoint(x: canvasPoint.x - 50, y: canvasPoint.y - 50),
                size: CGSize(width: 100, height: 100)
            ),
            layerType: type
        )

        // Add default styling based on type
        switch type {
        case .shape:
            layer.backgroundFill = FillConfig(fillType: .solid, color: .accent)
            layer.borderConfig = BorderConfig(cornerRadius: name == "Ellipse" ? 50 : 8)
        case .element:
            layer.backgroundFill = FillConfig(fillType: .solid, color: .accent)
            layer.borderConfig = BorderConfig(cornerRadius: 8)
        case .artboard:
            layer.backgroundFill = FillConfig(fillType: .solid, color: .white)
            layer.frame.size = DevicePreset.iPhone15.size
        default:
            break
        }

        canvasState.addLayer(layer)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        CanvasToolbar(canvasState: CanvasState())
            .padding()
    }
    .frame(width: 800, height: 200)
    .background(Color(white: 0.15))
}
