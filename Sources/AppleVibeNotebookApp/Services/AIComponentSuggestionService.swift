import Foundation
import AppleVibeNotebook

// MARK: - AI Component Suggestion Service

/// Provides context-aware component suggestions based on canvas state.
/// Shows inline suggestion chips in property inspector and quick actions.
@Observable
final class AIComponentSuggestionService {

    // MARK: - State

    var suggestions: [ComponentSuggestion] = []
    var isLoading: Bool = false
    var lastUpdateTime: Date?

    // MARK: - Configuration

    var isEnabled: Bool = true
    var maxSuggestions: Int = 5
    var contextWindow: Int = 3  // Number of nearby layers to consider

    // MARK: - Generation

    /// Generates suggestions based on current canvas context.
    func generateSuggestions(for canvasState: CanvasState) async {
        guard isEnabled else { return }

        isLoading = true
        defer { isLoading = false }

        var newSuggestions: [ComponentSuggestion] = []

        // Analyze selected layer
        if let selectedLayer = canvasState.singleSelectedLayer {
            newSuggestions.append(contentsOf: suggestionsForLayer(selectedLayer))
        }

        // Analyze multiple selection
        if canvasState.selectedLayerIDs.count > 1 {
            newSuggestions.append(contentsOf: suggestionsForMultipleSelection(canvasState.selectedLayers))
        }

        // Analyze overall canvas
        newSuggestions.append(contentsOf: suggestionsForCanvas(canvasState.document))

        // Deduplicate and limit
        suggestions = Array(newSuggestions.uniqued().prefix(maxSuggestions))
        lastUpdateTime = Date()
    }

    // MARK: - Layer-Based Suggestions

    private func suggestionsForLayer(_ layer: CanvasLayer) -> [ComponentSuggestion] {
        var suggestions: [ComponentSuggestion] = []

        // Based on layer type
        switch layer.layerType {
        case .shape:
            if layer.shadowConfig == nil {
                suggestions.append(ComponentSuggestion(
                    type: .addModifier,
                    title: "Add Shadow",
                    description: "Add a subtle shadow to create depth",
                    icon: "shadow",
                    action: .addShadow
                ))
            }

            if layer.borderConfig?.cornerRadius == 0 || layer.borderConfig == nil {
                suggestions.append(ComponentSuggestion(
                    type: .addModifier,
                    title: "Round Corners",
                    description: "Add rounded corners for a modern look",
                    icon: "rectangle.roundedtop",
                    action: .roundCorners(12)
                ))
            }

        case .text:
            suggestions.append(ComponentSuggestion(
                type: .convert,
                title: "Convert to Label",
                description: "Create a reusable label component",
                icon: "tag",
                action: .convertToComponent("Label")
            ))

        case .container:
            suggestions.append(ComponentSuggestion(
                type: .insertChild,
                title: "Add Button",
                description: "Insert a button into this container",
                icon: "button.horizontal",
                action: .insertComponent("Button")
            ))

            suggestions.append(ComponentSuggestion(
                type: .insertChild,
                title: "Add Text",
                description: "Insert text into this container",
                icon: "textformat",
                action: .insertComponent("Text")
            ))

        case .element:
            if layer.name.lowercased().contains("button") {
                suggestions.append(ComponentSuggestion(
                    type: .style,
                    title: "Make Primary",
                    description: "Apply primary button styling",
                    icon: "star.fill",
                    action: .applyStyle("primary")
                ))

                suggestions.append(ComponentSuggestion(
                    type: .style,
                    title: "Make Secondary",
                    description: "Apply secondary button styling",
                    icon: "star",
                    action: .applyStyle("secondary")
                ))
            }

        case .artboard:
            suggestions.append(ComponentSuggestion(
                type: .layout,
                title: "Add Navigation Bar",
                description: "Insert a navigation bar at the top",
                icon: "rectangle.topthird.inset.filled",
                action: .insertComponent("NavigationBar")
            ))

            suggestions.append(ComponentSuggestion(
                type: .layout,
                title: "Add Tab Bar",
                description: "Insert a tab bar at the bottom",
                icon: "rectangle.bottomthird.inset.filled",
                action: .insertComponent("TabBar")
            ))

        default:
            break
        }

        // Size-based suggestions
        let aspectRatio = layer.frame.size.width / layer.frame.size.height
        if abs(aspectRatio - 1.0) < 0.1 {
            suggestions.append(ComponentSuggestion(
                type: .convert,
                title: "Make Circle",
                description: "Convert to a perfect circle",
                icon: "circle",
                action: .makeCircle
            ))
        }

        // Color suggestions
        if let fill = layer.backgroundFill, fill.fillType == .solid {
            suggestions.append(ComponentSuggestion(
                type: .style,
                title: "Add Gradient",
                description: "Convert solid fill to gradient",
                icon: "paintbrush.fill",
                action: .addGradient
            ))
        }

        return suggestions
    }

    // MARK: - Multi-Selection Suggestions

    private func suggestionsForMultipleSelection(_ layers: [CanvasLayer]) -> [ComponentSuggestion] {
        var suggestions: [ComponentSuggestion] = []

        // Group suggestion
        suggestions.append(ComponentSuggestion(
            type: .organize,
            title: "Group Layers",
            description: "Combine \(layers.count) layers into a group",
            icon: "folder",
            action: .group
        ))

        // Alignment suggestions
        suggestions.append(ComponentSuggestion(
            type: .layout,
            title: "Align Horizontally",
            description: "Align all layers horizontally",
            icon: "align.horizontal.center",
            action: .alignHorizontal
        ))

        suggestions.append(ComponentSuggestion(
            type: .layout,
            title: "Align Vertically",
            description: "Align all layers vertically",
            icon: "align.vertical.center",
            action: .alignVertical
        ))

        // Distribution suggestions
        suggestions.append(ComponentSuggestion(
            type: .layout,
            title: "Distribute Evenly",
            description: "Space layers evenly",
            icon: "distribute.horizontal.center",
            action: .distributeEvenly
        ))

        // Create component from selection
        suggestions.append(ComponentSuggestion(
            type: .convert,
            title: "Save as Component",
            description: "Create a reusable component",
            icon: "puzzlepiece.extension",
            action: .saveAsComponent
        ))

        // Create stack from selection
        let isHorizontallyAligned = areHorizontallyAligned(layers)
        let isVerticallyAligned = areVerticallyAligned(layers)

        if isHorizontallyAligned {
            suggestions.append(ComponentSuggestion(
                type: .convert,
                title: "Convert to HStack",
                description: "Wrap in horizontal stack",
                icon: "square.split.1x2",
                action: .wrapInHStack
            ))
        }

        if isVerticallyAligned {
            suggestions.append(ComponentSuggestion(
                type: .convert,
                title: "Convert to VStack",
                description: "Wrap in vertical stack",
                icon: "square.split.2x1",
                action: .wrapInVStack
            ))
        }

        return suggestions
    }

    // MARK: - Canvas-Wide Suggestions

    private func suggestionsForCanvas(_ document: CanvasDocument) -> [ComponentSuggestion] {
        var suggestions: [ComponentSuggestion] = []

        // Empty canvas suggestions
        if document.layers.isEmpty {
            suggestions.append(ComponentSuggestion(
                type: .insertChild,
                title: "Add Artboard",
                description: "Start with an iPhone 15 artboard",
                icon: "rectangle.on.rectangle",
                action: .insertArtboard(.iPhone15)
            ))

            suggestions.append(ComponentSuggestion(
                type: .ai,
                title: "Generate with AI",
                description: "Describe what you want to build",
                icon: "sparkles",
                action: .openAIPrompt
            ))
        }

        // Check for missing common elements
        let hasNavBar = document.layers.contains { $0.name.contains("Navigation") }
        let hasTabBar = document.layers.contains { $0.name.contains("Tab") }

        if !document.layers.isEmpty && !hasNavBar {
            suggestions.append(ComponentSuggestion(
                type: .layout,
                title: "Add Navigation",
                description: "Add navigation bar to your design",
                icon: "rectangle.topthird.inset.filled",
                action: .insertComponent("NavigationBar"),
                priority: .low
            ))
        }

        if !document.layers.isEmpty && !hasTabBar && document.layers.count > 3 {
            suggestions.append(ComponentSuggestion(
                type: .layout,
                title: "Add Tab Bar",
                description: "Add bottom navigation",
                icon: "rectangle.bottomthird.inset.filled",
                action: .insertComponent("TabBar"),
                priority: .low
            ))
        }

        // Accessibility suggestions
        let textLayers = document.layers.filter { $0.layerType == .text }
        for textLayer in textLayers {
            if textLayer.frame.size.height < 20 {
                suggestions.append(ComponentSuggestion(
                    type: .accessibility,
                    title: "Small Text Warning",
                    description: "\(textLayer.name) may be too small",
                    icon: "exclamationmark.triangle",
                    action: .resizeText(textLayer.id),
                    priority: .high
                ))
            }
        }

        return suggestions
    }

    // MARK: - Helpers

    private func areHorizontallyAligned(_ layers: [CanvasLayer]) -> Bool {
        guard layers.count > 1 else { return false }
        let sortedByX = layers.sorted { $0.frame.origin.x < $1.frame.origin.x }

        let yPositions = layers.map { $0.frame.midY }
        let avgY = yPositions.reduce(0, +) / CGFloat(yPositions.count)

        return yPositions.allSatisfy { abs($0 - avgY) < 30 }
    }

    private func areVerticallyAligned(_ layers: [CanvasLayer]) -> Bool {
        guard layers.count > 1 else { return false }

        let xPositions = layers.map { $0.frame.midX }
        let avgX = xPositions.reduce(0, +) / CGFloat(xPositions.count)

        return xPositions.allSatisfy { abs($0 - avgX) < 30 }
    }
}

// MARK: - Component Suggestion

struct ComponentSuggestion: Identifiable, Hashable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let icon: String
    let action: SuggestionAction
    var priority: SuggestionPriority = .medium

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(type)
    }

    static func == (lhs: ComponentSuggestion, rhs: ComponentSuggestion) -> Bool {
        lhs.title == rhs.title && lhs.type == rhs.type
    }
}

enum SuggestionType: String, CaseIterable {
    case addModifier = "Modifier"
    case style = "Style"
    case layout = "Layout"
    case convert = "Convert"
    case insertChild = "Insert"
    case organize = "Organize"
    case accessibility = "Accessibility"
    case ai = "AI"

    var color: String {
        switch self {
        case .addModifier: return "blue"
        case .style: return "purple"
        case .layout: return "green"
        case .convert: return "orange"
        case .insertChild: return "teal"
        case .organize: return "indigo"
        case .accessibility: return "yellow"
        case .ai: return "pink"
        }
    }
}

enum SuggestionAction: Hashable {
    // Modifiers
    case addShadow
    case roundCorners(CGFloat)
    case addGradient
    case makeCircle

    // Style
    case applyStyle(String)

    // Layout
    case alignHorizontal
    case alignVertical
    case distributeEvenly

    // Convert
    case convertToComponent(String)
    case wrapInHStack
    case wrapInVStack
    case saveAsComponent
    case group

    // Insert
    case insertComponent(String)
    case insertArtboard(DevicePreset)

    // AI
    case openAIPrompt

    // Accessibility
    case resizeText(UUID)
}

enum SuggestionPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: SuggestionPriority, rhs: SuggestionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Array Extension for Uniquing

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Suggestion Chip View

import SwiftUI

struct SuggestionChipView: View {
    let suggestion: ComponentSuggestion
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 12))

                Text(suggestion.title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(chipColor.opacity(isHovering ? 0.3 : 0.15))
            )
            .foregroundColor(chipColor)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(suggestion.description)
    }

    private var chipColor: Color {
        switch suggestion.type {
        case .addModifier: return .blue
        case .style: return .purple
        case .layout: return .green
        case .convert: return .orange
        case .insertChild: return .teal
        case .organize: return .indigo
        case .accessibility: return .yellow
        case .ai: return .pink
        }
    }
}

// MARK: - Suggestions Panel View

struct SuggestionsPanelView: View {
    let suggestions: [ComponentSuggestion]
    let onSuggestionTap: (ComponentSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Suggestions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            FlowLayout(spacing: 6) {
                ForEach(suggestions) { suggestion in
                    SuggestionChipView(suggestion: suggestion) {
                        onSuggestionTap(suggestion)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SuggestionsPanelView(
            suggestions: [
                ComponentSuggestion(
                    type: .addModifier,
                    title: "Add Shadow",
                    description: "Add a subtle shadow",
                    icon: "shadow",
                    action: .addShadow
                ),
                ComponentSuggestion(
                    type: .style,
                    title: "Round Corners",
                    description: "Add rounded corners",
                    icon: "rectangle.roundedtop",
                    action: .roundCorners(12)
                ),
                ComponentSuggestion(
                    type: .convert,
                    title: "Make Component",
                    description: "Save as reusable component",
                    icon: "puzzlepiece.extension",
                    action: .saveAsComponent
                ),
            ],
            onSuggestionTap: { _ in }
        )
    }
    .padding()
    .frame(width: 300)
    .background(Color(white: 0.12))
}
