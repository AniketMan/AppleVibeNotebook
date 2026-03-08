import SwiftUI
import AppleVibeNotebook

// MARK: - Object Library View

/// A searchable component browser with drag-to-canvas functionality.
/// Like Procreate's brush library, organized by categories with search.
struct ObjectLibraryView: View {
    @Bindable var canvasState: CanvasState
    @State private var library = ComponentLibrary()
    @State private var searchQuery = ""
    @State private var selectedCategory: UUID?
    @State private var viewMode: LibraryViewMode = .grid

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Search
            searchBar

            // Category tabs
            categoryTabs

            Divider()

            // Component grid/list
            componentContent
        }
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Objects")
                .font(.headline)

            Spacer()

            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(LibraryViewMode.grid)
                Image(systemName: "list.bullet").tag(LibraryViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            Button {
                canvasState.showObjectLibrary = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search components...", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(white: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All category
                CategoryTab(
                    name: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                // Favorites
                CategoryTab(
                    name: "Favorites",
                    icon: "star.fill",
                    isSelected: false,
                    action: {}
                )

                // Recent
                CategoryTab(
                    name: "Recent",
                    icon: "clock",
                    isSelected: false,
                    action: {}
                )

                Divider()
                    .frame(height: 20)

                // Categories from library
                ForEach(library.categories.sorted(by: { $0.order < $1.order })) { category in
                    CategoryTab(
                        name: category.name,
                        icon: category.icon,
                        isSelected: selectedCategory == category.id,
                        action: { selectedCategory = category.id }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Component Content

    private var componentContent: some View {
        ScrollView {
            switch viewMode {
            case .grid:
                componentGrid
            case .list:
                componentList
            }
        }
    }

    private var componentGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 12)
        ], spacing: 12) {
            ForEach(filteredComponents) { component in
                ComponentGridItem(
                    component: component,
                    onTap: { insertComponent(component) },
                    onDrag: { createDragItem(for: component) }
                )
            }
        }
        .padding()
    }

    private var componentList: some View {
        LazyVStack(spacing: 4) {
            ForEach(filteredComponents) { component in
                ComponentListItem(
                    component: component,
                    onTap: { insertComponent(component) },
                    onDrag: { createDragItem(for: component) }
                )
            }
        }
        .padding()
    }

    // MARK: - Filtered Components

    private var filteredComponents: [CanvasComponent] {
        var components = library.components

        // Filter by category
        if let categoryID = selectedCategory {
            components = components.filter { $0.categoryID == categoryID }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            components = library.search(query: searchQuery)
        }

        return components
    }

    // MARK: - Actions

    private func insertComponent(_ component: CanvasComponent) {
        let centerPoint = CGPoint(
            x: canvasState.document.viewport.visibleRect.midX,
            y: canvasState.document.viewport.visibleRect.midY
        )
        let canvasPoint = canvasState.document.viewport.screenToCanvas(centerPoint)

        let layers = component.instantiate(at: canvasPoint)
        for layer in layers {
            canvasState.addLayer(layer)
        }

        // Mark as recently used
        library.markAsUsed(component.id)

        // Select the inserted layer
        if let firstLayer = layers.first {
            canvasState.selectLayer(firstLayer.id)
        }
    }

    private func createDragItem(for component: CanvasComponent) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = component.name
        return provider
    }
}

// MARK: - Library View Mode

enum LibraryViewMode: String, CaseIterable {
    case grid, list
}

// MARK: - Category Tab

struct CategoryTab: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Component Grid Item

struct ComponentGridItem: View {
    let component: CanvasComponent
    let onTap: () -> Void
    let onDrag: () -> NSItemProvider

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.25))

                Image(systemName: component.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 60, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovering ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            // Name
            Text(component.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundColor(.primary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? Color(white: 0.22) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture(perform: onTap)
        .onDrag(onDrag)
        .help(component.description)
    }
}

// MARK: - Component List Item

struct ComponentListItem: View {
    let component: CanvasComponent
    let onTap: () -> Void
    let onDrag: () -> NSItemProvider

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.25))

                Image(systemName: component.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 36, height: 36)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.system(size: 13, weight: .medium))

                if !component.description.isEmpty {
                    Text(component.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Insert button
            if isHovering {
                Button {
                    onTap()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color(white: 0.22) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture(perform: onTap)
        .onDrag(onDrag)
    }
}

// MARK: - Preset Selector

struct PresetSelector: View {
    let component: CanvasComponent
    @Binding var selectedPresetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Default preset
                    PresetThumbnail(
                        name: "Default",
                        isSelected: selectedPresetID == nil,
                        action: { selectedPresetID = nil }
                    )

                    // Component presets
                    ForEach(component.presets) { preset in
                        PresetThumbnail(
                            name: preset.name,
                            isSelected: selectedPresetID == preset.id,
                            action: { selectedPresetID = preset.id }
                        )
                    }
                }
            }
        }
    }
}

struct PresetThumbnail: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                Text(name)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save as Component Sheet

struct SaveAsComponentSheet: View {
    @Binding var isPresented: Bool
    let layers: [CanvasLayer]
    let onSave: (CanvasComponent) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var selectedCategoryID: UUID?
    @State private var tags: [String] = []
    @State private var tagInput = ""

    private let categories = ComponentCategory.defaultCategories

    var body: some View {
        NavigationStack {
            Form {
                Section("Component Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.icon)
                                .tag(category.id as UUID?)
                        }
                    }
                }

                Section("Tags") {
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .onSubmit {
                                addTag()
                            }
                        Button("Add") {
                            addTag()
                        }
                        .disabled(tagInput.isEmpty)
                    }

                    if !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(tag: tag) {
                                    tags.removeAll { $0 == tag }
                                }
                            }
                        }
                    }
                }

                Section("Preview") {
                    Text("\(layers.count) layer(s) selected")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Save as Component")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveComponent()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            tagInput = ""
        }
    }

    private func saveComponent() {
        guard let baseLayer = layers.first else { return }

        let component = CanvasComponent(
            name: name,
            description: description,
            icon: baseLayer.layerType.icon,
            categoryID: selectedCategoryID,
            tags: tags,
            baseLayer: baseLayer,
            childLayers: Array(layers.dropFirst())
        )

        onSave(component)
        isPresented = false
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 12))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.2))
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                sizes.append(size)

                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }

            size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    ObjectLibraryView(canvasState: CanvasState())
        .frame(height: 600)
}
