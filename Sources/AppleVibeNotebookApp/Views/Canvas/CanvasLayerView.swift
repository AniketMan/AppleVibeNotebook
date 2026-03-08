import SwiftUI
import AppleVibeNotebook

// MARK: - Canvas Layer View

/// Individual layer rendering with selection handles, transforms, and visual styling.
/// Handles rotation, opacity, blend modes, and visual feedback during interactions.
struct CanvasLayerView: View {
    let layer: CanvasLayer
    let isSelected: Bool
    let viewport: CanvasViewport

    var body: some View {
        layerContent
            .frame(
                width: layer.frame.size.width * viewport.scale,
                height: layer.frame.size.height * viewport.scale
            )
            .rotationEffect(.degrees(layer.rotation))
            .opacity(layer.opacity)
            .position(screenPosition)
            .overlay {
                if isSelected {
                    selectionOverlay
                }
            }
    }

    // MARK: - Layer Content

    @ViewBuilder
    private var layerContent: some View {
        switch layer.layerType {
        case .shape:
            shapeContent
        case .text:
            textContent
        case .image:
            imageContent
        case .artboard:
            artboardContent
        case .container:
            containerContent
        case .component:
            componentContent
        case .group:
            groupContent
        case .mask:
            maskContent
        case .element:
            elementContent
        }
    }

    // MARK: - Shape Content

    @ViewBuilder
    private var shapeContent: some View {
        let cornerRadius = layer.borderConfig?.cornerRadius ?? 0

        ZStack {
            // Background fill
            if let fill = layer.backgroundFill {
                switch fill.fillType {
                case .solid:
                    if let color = fill.color {
                        RoundedRectangle(cornerRadius: cornerRadius * viewport.scale)
                            .fill(color.swiftUIColor)
                    }
                case .gradient:
                    if let gradient = fill.gradient {
                        RoundedRectangle(cornerRadius: cornerRadius * viewport.scale)
                            .fill(gradient.swiftUIGradient)
                    }
                case .image:
                    // Image fill would be implemented here
                    RoundedRectangle(cornerRadius: cornerRadius * viewport.scale)
                        .fill(Color.gray)
                case .none:
                    EmptyView()
                }
            }

            // Border
            if let border = layer.borderConfig, border.width > 0 {
                RoundedRectangle(cornerRadius: cornerRadius * viewport.scale)
                    .strokeBorder(border.color.swiftUIColor, lineWidth: border.width * viewport.scale)
            }
        }
        .shadow(
            color: layer.shadowConfig?.color.swiftUIColor ?? .clear,
            radius: (layer.shadowConfig?.radius ?? 0) * viewport.scale,
            x: (layer.shadowConfig?.offset.x ?? 0) * viewport.scale,
            y: (layer.shadowConfig?.offset.y ?? 0) * viewport.scale
        )
    }

    // MARK: - Text Content

    @ViewBuilder
    private var textContent: some View {
        VStack {
            Text(layer.name)
                .font(.system(size: 16 * viewport.scale))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(4 * viewport.scale)
    }

    // MARK: - Image Content

    @ViewBuilder
    private var imageContent: some View {
        ZStack {
            // Placeholder for image
            Rectangle()
                .fill(Color.gray.opacity(0.3))

            Image(systemName: "photo")
                .font(.system(size: 30 * viewport.scale))
                .foregroundColor(.gray)
        }
        .clipShape(RoundedRectangle(cornerRadius: (layer.borderConfig?.cornerRadius ?? 0) * viewport.scale))
    }

    // MARK: - Artboard Content

    @ViewBuilder
    private var artboardContent: some View {
        VStack(spacing: 0) {
            // Artboard label
            HStack {
                Text(layer.name)
                    .font(.system(size: 12 * viewport.scale, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8 * viewport.scale)
            .padding(.vertical, 4 * viewport.scale)
            .background(Color(white: 0.95))
            .offset(y: -24 * viewport.scale)

            // Artboard surface
            Rectangle()
                .fill(layer.backgroundFill?.color?.swiftUIColor ?? .white)
                .shadow(color: .black.opacity(0.1), radius: 10 * viewport.scale)
        }
    }

    // MARK: - Container Content

    @ViewBuilder
    private var containerContent: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundColor(.blue.opacity(0.5))
                )

            VStack {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 20 * viewport.scale))
                    .foregroundColor(.blue.opacity(0.5))
                Text(layer.name)
                    .font(.system(size: 10 * viewport.scale))
                    .foregroundColor(.blue.opacity(0.5))
            }
        }
    }

    // MARK: - Component Content

    @ViewBuilder
    private var componentContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8 * viewport.scale)
                .fill(layer.backgroundFill?.color?.swiftUIColor ?? Color.purple.opacity(0.1))

            RoundedRectangle(cornerRadius: 8 * viewport.scale)
                .strokeBorder(Color.purple, lineWidth: 2 * viewport.scale)

            VStack(spacing: 4 * viewport.scale) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 24 * viewport.scale))
                    .foregroundColor(.purple)
                Text(layer.name)
                    .font(.system(size: 12 * viewport.scale, weight: .medium))
                    .foregroundColor(.purple)
            }
        }
    }

    // MARK: - Group Content

    @ViewBuilder
    private var groupContent: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .foregroundColor(.orange.opacity(0.5))
                )

            Image(systemName: "folder.fill")
                .font(.system(size: 20 * viewport.scale))
                .foregroundColor(.orange.opacity(0.5))
        }
    }

    // MARK: - Mask Content

    @ViewBuilder
    private var maskContent: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.5))

            Image(systemName: "theatermasks")
                .font(.system(size: 20 * viewport.scale))
                .foregroundColor(.white)
        }
    }

    // MARK: - Element Content

    @ViewBuilder
    private var elementContent: some View {
        ZStack {
            if let fill = layer.backgroundFill, let color = fill.color {
                RoundedRectangle(cornerRadius: (layer.borderConfig?.cornerRadius ?? 4) * viewport.scale)
                    .fill(color.swiftUIColor)
            } else {
                RoundedRectangle(cornerRadius: 4 * viewport.scale)
                    .fill(Color.blue.opacity(0.2))
            }

            if let border = layer.borderConfig {
                RoundedRectangle(cornerRadius: border.cornerRadius * viewport.scale)
                    .strokeBorder(border.color.swiftUIColor, lineWidth: border.width * viewport.scale)
            }
        }
    }

    // MARK: - Selection Overlay

    private var selectionOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Selection border
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)

                // Corner handles
                ForEach(SelectionHandle.corners, id: \.self) { handle in
                    handle.view
                        .position(handle.position(in: geometry.size))
                }

                // Edge handles
                ForEach(SelectionHandle.edges, id: \.self) { handle in
                    handle.view
                        .position(handle.position(in: geometry.size))
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var screenPosition: CGPoint {
        let screenOrigin = viewport.canvasToScreen(layer.frame.origin)
        return CGPoint(
            x: screenOrigin.x + (layer.frame.size.width * viewport.scale) / 2,
            y: screenOrigin.y + (layer.frame.size.height * viewport.scale) / 2
        )
    }
}

// MARK: - Selection Handle

enum SelectionHandle: String, CaseIterable {
    case topLeft, topCenter, topRight
    case centerLeft, centerRight
    case bottomLeft, bottomCenter, bottomRight

    static var corners: [SelectionHandle] {
        [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }

    static var edges: [SelectionHandle] {
        [.topCenter, .centerLeft, .centerRight, .bottomCenter]
    }

    func position(in size: CGSize) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: 0, y: 0)
        case .topCenter: return CGPoint(x: size.width / 2, y: 0)
        case .topRight: return CGPoint(x: size.width, y: 0)
        case .centerLeft: return CGPoint(x: 0, y: size.height / 2)
        case .centerRight: return CGPoint(x: size.width, y: size.height / 2)
        case .bottomLeft: return CGPoint(x: 0, y: size.height)
        case .bottomCenter: return CGPoint(x: size.width / 2, y: size.height)
        case .bottomRight: return CGPoint(x: size.width, y: size.height)
        }
    }

    var view: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
            Circle()
                .stroke(Color.accentColor, lineWidth: 1.5)
                .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Color Extensions

extension CanvasColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension GradientConfig {
    var swiftUIGradient: LinearGradient {
        LinearGradient(
            colors: colors.map(\.swiftUIColor),
            startPoint: UnitPoint(x: startPoint.x, y: startPoint.y),
            endPoint: UnitPoint(x: endPoint.x, y: endPoint.y)
        )
    }
}

// MARK: - Layer Interaction State

struct LayerInteractionState {
    var isDragging: Bool = false
    var isResizing: Bool = false
    var isRotating: Bool = false
    var activeHandle: SelectionHandle?
    var dragStartPosition: CGPoint = .zero
    var originalFrame: CanvasFrame?
}

// MARK: - Layer Transform View Modifier

struct LayerTransformModifier: ViewModifier {
    let layer: CanvasLayer
    let viewport: CanvasViewport
    @Binding var interactionState: LayerInteractionState
    let onFrameChange: (CanvasFrame) -> Void

    func body(content: Content) -> some View {
        content
            .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !interactionState.isDragging {
                    interactionState.isDragging = true
                    interactionState.dragStartPosition = layer.frame.origin
                    interactionState.originalFrame = layer.frame
                }

                var newFrame = layer.frame
                newFrame.origin = CGPoint(
                    x: interactionState.dragStartPosition.x + value.translation.width / viewport.scale,
                    y: interactionState.dragStartPosition.y + value.translation.height / viewport.scale
                )
                onFrameChange(newFrame)
            }
            .onEnded { _ in
                interactionState.isDragging = false
            }
    }
}

// MARK: - Preview

#Preview {
    let layer = CanvasLayer(
        name: "Preview Shape",
        frame: CanvasFrame(origin: CGPoint(x: 50, y: 50), size: CGSize(width: 200, height: 150)),
        layerType: .shape,
        borderConfig: BorderConfig(cornerRadius: 12),
        backgroundFill: FillConfig(fillType: .solid, color: .accent)
    )

    return CanvasLayerView(
        layer: layer,
        isSelected: true,
        viewport: CanvasViewport()
    )
    .frame(width: 400, height: 400)
    .background(Color(white: 0.15))
}
