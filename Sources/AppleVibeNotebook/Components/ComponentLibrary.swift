import Foundation
import CoreGraphics

// MARK: - Component Library

/// The library of reusable canvas components following the hierarchy:
/// Component → Preset → Composition → App
/// Like Procreate brush presets, but for UI components.
public struct ComponentLibrary: Codable, Sendable {
    public var components: [CanvasComponent]
    public var categories: [ComponentCategory]
    public var recentlyUsed: [UUID]
    public var favorites: [UUID]

    public init(
        components: [CanvasComponent] = CanvasComponent.builtInComponents,
        categories: [ComponentCategory] = ComponentCategory.defaultCategories,
        recentlyUsed: [UUID] = [],
        favorites: [UUID] = []
    ) {
        self.components = components
        self.categories = categories
        self.recentlyUsed = recentlyUsed
        self.favorites = favorites
    }

    // MARK: - Query Methods

    public func component(byID id: UUID) -> CanvasComponent? {
        components.first { $0.id == id }
    }

    public func components(inCategory categoryID: UUID) -> [CanvasComponent] {
        components.filter { $0.categoryID == categoryID }
    }

    public func search(query: String) -> [CanvasComponent] {
        let lowercased = query.lowercased()
        return components.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }

    public mutating func markAsUsed(_ componentID: UUID) {
        recentlyUsed.removeAll { $0 == componentID }
        recentlyUsed.insert(componentID, at: 0)
        if recentlyUsed.count > 20 {
            recentlyUsed.removeLast()
        }
    }

    public mutating func toggleFavorite(_ componentID: UUID) {
        if favorites.contains(componentID) {
            favorites.removeAll { $0 == componentID }
        } else {
            favorites.append(componentID)
        }
    }
}

// MARK: - Canvas Component

/// A reusable UI component definition that can be instantiated on the canvas.
/// Supports inheritance, presets, and configurable properties.
public struct CanvasComponent: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var description: String
    public var icon: String
    public var categoryID: UUID?
    public var tags: [String]

    // Visual definition
    public var baseLayer: CanvasLayer
    public var childLayers: [CanvasLayer]

    // Configurable properties (exposed in property inspector)
    public var properties: [ConfigurableProperty]

    // Inheritance
    public var parentID: UUID?        // Inherits from this component
    public var overriddenProperties: Set<String>  // Properties that override parent

    // Presets (variations of this component)
    public var presets: [ComponentPreset]

    // Platform targeting
    public var supportedPlatforms: Set<ComponentPlatform>

    // Code generation hints
    public var swiftUIViewName: String?
    public var reactComponentName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        icon: String = "square.fill",
        categoryID: UUID? = nil,
        tags: [String] = [],
        baseLayer: CanvasLayer,
        childLayers: [CanvasLayer] = [],
        properties: [ConfigurableProperty] = [],
        parentID: UUID? = nil,
        overriddenProperties: Set<String> = [],
        presets: [ComponentPreset] = [],
        supportedPlatforms: Set<ComponentPlatform> = [.iOS, .macOS, .web],
        swiftUIViewName: String? = nil,
        reactComponentName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.categoryID = categoryID
        self.tags = tags
        self.baseLayer = baseLayer
        self.childLayers = childLayers
        self.properties = properties
        self.parentID = parentID
        self.overriddenProperties = overriddenProperties
        self.presets = presets
        self.supportedPlatforms = supportedPlatforms
        self.swiftUIViewName = swiftUIViewName
        self.reactComponentName = reactComponentName
    }

    /// Creates a layer instance of this component
    public func instantiate(at position: CGPoint) -> [CanvasLayer] {
        var layers: [CanvasLayer] = []

        var instance = baseLayer
        instance.id = UUID()
        instance.frame.origin = position
        instance.componentID = self.id
        instance.layerType = .component
        instance.name = name
        layers.append(instance)

        for var child in childLayers {
            child.id = UUID()
            child.parentID = instance.id
            child.frame.origin.x += position.x
            child.frame.origin.y += position.y
            layers.append(child)
        }

        return layers
    }
}

// MARK: - Component Preset

/// A preset variation of a component (like Procreate brush presets).
public struct ComponentPreset: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var description: String
    public var thumbnail: Data?
    public var propertyOverrides: [String: PropertyValue]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        thumbnail: Data? = nil,
        propertyOverrides: [String: PropertyValue] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.thumbnail = thumbnail
        self.propertyOverrides = propertyOverrides
    }
}

// MARK: - Component Composition

/// A composition of multiple components forming a complex UI pattern.
public struct ComponentComposition: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var description: String
    public var icon: String
    public var thumbnail: Data?

    // Components in this composition with their relative positions
    public var componentInstances: [ComponentInstance]

    // Layout constraints between components
    public var constraints: [LayoutConstraint]

    // Exposed properties (aggregated from child components)
    public var exposedProperties: [ExposedProperty]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        icon: String = "rectangle.3.group",
        thumbnail: Data? = nil,
        componentInstances: [ComponentInstance] = [],
        constraints: [LayoutConstraint] = [],
        exposedProperties: [ExposedProperty] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.thumbnail = thumbnail
        self.componentInstances = componentInstances
        self.constraints = constraints
        self.exposedProperties = exposedProperties
    }
}

// MARK: - Component Instance

/// An instance of a component within a composition
public struct ComponentInstance: Codable, Sendable, Identifiable {
    public let id: UUID
    public var componentID: UUID
    public var presetID: UUID?
    public var relativePosition: CGPoint
    public var propertyOverrides: [String: PropertyValue]

    public init(
        id: UUID = UUID(),
        componentID: UUID,
        presetID: UUID? = nil,
        relativePosition: CGPoint = .zero,
        propertyOverrides: [String: PropertyValue] = [:]
    ) {
        self.id = id
        self.componentID = componentID
        self.presetID = presetID
        self.relativePosition = relativePosition
        self.propertyOverrides = propertyOverrides
    }
}

// MARK: - Layout Constraint

/// A constraint between two component instances
public struct LayoutConstraint: Codable, Sendable, Identifiable {
    public let id: UUID
    public var sourceInstanceID: UUID
    public var sourceAnchor: AnchorPoint
    public var targetInstanceID: UUID
    public var targetAnchor: AnchorPoint
    public var offset: CGPoint

    public init(
        id: UUID = UUID(),
        sourceInstanceID: UUID,
        sourceAnchor: AnchorPoint,
        targetInstanceID: UUID,
        targetAnchor: AnchorPoint,
        offset: CGPoint = .zero
    ) {
        self.id = id
        self.sourceInstanceID = sourceInstanceID
        self.sourceAnchor = sourceAnchor
        self.targetInstanceID = targetInstanceID
        self.targetAnchor = targetAnchor
        self.offset = offset
    }
}

// MARK: - Exposed Property

/// A property exposed from a child component to the composition level
public struct ExposedProperty: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String                // Name at composition level
    public var instanceID: UUID            // Which component instance
    public var propertyKey: String         // Which property on that instance

    public init(
        id: UUID = UUID(),
        name: String,
        instanceID: UUID,
        propertyKey: String
    ) {
        self.id = id
        self.name = name
        self.instanceID = instanceID
        self.propertyKey = propertyKey
    }
}

// MARK: - Canvas App

/// A complete app built from compositions and components
public struct CanvasApp: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var version: String
    public var icon: Data?

    // Screens/pages in the app
    public var screens: [AppScreen]

    // Navigation flow
    public var navigationFlow: [NavigationLink]

    // Global design tokens
    public var designTokens: DesignTokens

    // Target platforms
    public var targetPlatforms: Set<ComponentPlatform>

    public init(
        id: UUID = UUID(),
        name: String = "My App",
        bundleIdentifier: String = "com.example.myapp",
        version: String = "1.0.0",
        icon: Data? = nil,
        screens: [AppScreen] = [],
        navigationFlow: [NavigationLink] = [],
        designTokens: DesignTokens = DesignTokens(),
        targetPlatforms: Set<ComponentPlatform> = [.iOS]
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.icon = icon
        self.screens = screens
        self.navigationFlow = navigationFlow
        self.designTokens = designTokens
        self.targetPlatforms = targetPlatforms
    }
}

// MARK: - App Screen

/// A screen/page in the app
public struct AppScreen: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var canvasDocumentID: UUID     // Links to a CanvasDocument
    public var isEntryPoint: Bool
    public var navigationBarStyle: NavigationBarStyle

    public init(
        id: UUID = UUID(),
        name: String,
        canvasDocumentID: UUID,
        isEntryPoint: Bool = false,
        navigationBarStyle: NavigationBarStyle = .automatic
    ) {
        self.id = id
        self.name = name
        self.canvasDocumentID = canvasDocumentID
        self.isEntryPoint = isEntryPoint
        self.navigationBarStyle = navigationBarStyle
    }
}

public enum NavigationBarStyle: String, Codable, Sendable {
    case automatic, large, inline, hidden
}

// MARK: - Navigation Link

/// A navigation link between screens
public struct NavigationLink: Codable, Sendable, Identifiable {
    public let id: UUID
    public var sourceScreenID: UUID
    public var sourceLayerID: UUID        // The layer that triggers navigation
    public var destinationScreenID: UUID
    public var transitionStyle: TransitionStyle

    public init(
        id: UUID = UUID(),
        sourceScreenID: UUID,
        sourceLayerID: UUID,
        destinationScreenID: UUID,
        transitionStyle: TransitionStyle = .push
    ) {
        self.id = id
        self.sourceScreenID = sourceScreenID
        self.sourceLayerID = sourceLayerID
        self.destinationScreenID = destinationScreenID
        self.transitionStyle = transitionStyle
    }
}

public enum TransitionStyle: String, Codable, Sendable, CaseIterable {
    case push, present, sheet, fullScreenCover, replace

    public var icon: String {
        switch self {
        case .push: return "arrow.right"
        case .present: return "arrow.up"
        case .sheet: return "rectangle.bottomhalf.filled"
        case .fullScreenCover: return "rectangle.fill"
        case .replace: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Design Tokens

/// Global design tokens for consistency
public struct DesignTokens: Codable, Sendable {
    public var colors: [String: CanvasColor]
    public var fonts: [String: FontToken]
    public var spacing: [String: CGFloat]
    public var cornerRadius: [String: CGFloat]
    public var shadows: [String: ShadowConfig]

    public init(
        colors: [String: CanvasColor] = [:],
        fonts: [String: FontToken] = [:],
        spacing: [String: CGFloat] = [:],
        cornerRadius: [String: CGFloat] = [:],
        shadows: [String: ShadowConfig] = [:]
    ) {
        self.colors = colors
        self.fonts = fonts
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.shadows = shadows
    }

    public static let `default` = DesignTokens(
        colors: [
            "primary": CanvasColor(red: 0, green: 0.48, blue: 1),
            "secondary": CanvasColor(red: 0.55, green: 0.55, blue: 0.58),
            "background": CanvasColor(red: 1, green: 1, blue: 1),
            "text": CanvasColor(red: 0, green: 0, blue: 0),
            "success": CanvasColor(red: 0.2, green: 0.78, blue: 0.35),
            "warning": CanvasColor(red: 1, green: 0.8, blue: 0),
            "error": CanvasColor(red: 1, green: 0.23, blue: 0.19),
        ],
        spacing: [
            "xs": 4,
            "sm": 8,
            "md": 16,
            "lg": 24,
            "xl": 32,
        ],
        cornerRadius: [
            "none": 0,
            "sm": 4,
            "md": 8,
            "lg": 16,
            "full": 9999,
        ]
    )
}

// MARK: - Font Token

public struct FontToken: Codable, Sendable {
    public var family: String
    public var size: CGFloat
    public var weight: FontWeight
    public var lineHeight: CGFloat?
    public var letterSpacing: CGFloat?

    public init(
        family: String = "System",
        size: CGFloat = 16,
        weight: FontWeight = .regular,
        lineHeight: CGFloat? = nil,
        letterSpacing: CGFloat? = nil
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
    }
}

public enum FontWeight: String, Codable, Sendable, CaseIterable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}

// MARK: - Component Platform

public enum ComponentPlatform: String, Codable, Sendable, CaseIterable {
    case iOS, macOS, watchOS, tvOS, visionOS, web, android

    public var icon: String {
        switch self {
        case .iOS: return "iphone"
        case .macOS: return "desktopcomputer"
        case .watchOS: return "applewatch"
        case .tvOS: return "appletv"
        case .visionOS: return "visionpro"
        case .web: return "globe"
        case .android: return "phone"
        }
    }
}

// MARK: - Component Category

public struct ComponentCategory: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var order: Int

    public init(id: UUID = UUID(), name: String, icon: String, order: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.order = order
    }

    public static let defaultCategories: [ComponentCategory] = [
        ComponentCategory(id: UUID(), name: "Layout", icon: "square.grid.2x2", order: 0),
        ComponentCategory(id: UUID(), name: "Controls", icon: "slider.horizontal.3", order: 1),
        ComponentCategory(id: UUID(), name: "Text", icon: "textformat", order: 2),
        ComponentCategory(id: UUID(), name: "Media", icon: "photo", order: 3),
        ComponentCategory(id: UUID(), name: "Navigation", icon: "arrow.left.arrow.right", order: 4),
        ComponentCategory(id: UUID(), name: "Data Entry", icon: "keyboard", order: 5),
        ComponentCategory(id: UUID(), name: "Feedback", icon: "bell", order: 6),
        ComponentCategory(id: UUID(), name: "Custom", icon: "star", order: 7),
    ]
}

// MARK: - Built-in Components

extension CanvasComponent {
    public static let builtInComponents: [CanvasComponent] = [
        // Button
        CanvasComponent(
            name: "Button",
            description: "A tappable button with customizable label and style",
            icon: "button.horizontal.fill",
            tags: ["button", "tap", "action", "control"],
            baseLayer: CanvasLayer(
                name: "Button",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 120, height: 44)),
                layerType: .element,
                borderConfig: BorderConfig(cornerRadius: 10),
                backgroundFill: FillConfig(fillType: .solid, color: .accent)
            ),
            properties: [
                ConfigurableProperty(key: "title", name: "Title", type: .text, defaultValue: .string("Button")),
                ConfigurableProperty(key: "cornerRadius", name: "Corner Radius", type: .slider(min: 0, max: 22), defaultValue: .number(10)),
                ConfigurableProperty(key: "fillColor", name: "Fill Color", type: .color, defaultValue: .color(CanvasColor.accent)),
            ],
            swiftUIViewName: "Button",
            reactComponentName: "Button"
        ),

        // Text
        CanvasComponent(
            name: "Text",
            description: "A text label with customizable font and styling",
            icon: "textformat",
            tags: ["text", "label", "typography"],
            baseLayer: CanvasLayer(
                name: "Text",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 200, height: 24)),
                layerType: .text
            ),
            properties: [
                ConfigurableProperty(key: "text", name: "Text", type: .text, defaultValue: .string("Hello, World!")),
                ConfigurableProperty(key: "fontSize", name: "Font Size", type: .slider(min: 8, max: 72), defaultValue: .number(17)),
                ConfigurableProperty(key: "fontWeight", name: "Font Weight", type: .segmented(["Light", "Regular", "Medium", "Bold"]), defaultValue: .string("Regular")),
                ConfigurableProperty(key: "textColor", name: "Color", type: .color, defaultValue: .color(CanvasColor.black)),
            ],
            swiftUIViewName: "Text",
            reactComponentName: "Text"
        ),

        // Image
        CanvasComponent(
            name: "Image",
            description: "An image view with aspect ratio and styling options",
            icon: "photo",
            tags: ["image", "photo", "picture", "media"],
            baseLayer: CanvasLayer(
                name: "Image",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 200, height: 200)),
                layerType: .image,
                borderConfig: BorderConfig(cornerRadius: 8)
            ),
            properties: [
                ConfigurableProperty(key: "cornerRadius", name: "Corner Radius", type: .slider(min: 0, max: 100), defaultValue: .number(8)),
                ConfigurableProperty(key: "contentMode", name: "Content Mode", type: .segmented(["Fill", "Fit"]), defaultValue: .string("Fill")),
            ],
            swiftUIViewName: "Image",
            reactComponentName: "Image"
        ),

        // Card
        CanvasComponent(
            name: "Card",
            description: "A card container with shadow and corner radius",
            icon: "rectangle.on.rectangle",
            tags: ["card", "container", "surface"],
            baseLayer: CanvasLayer(
                name: "Card",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 300, height: 200)),
                layerType: .container,
                shadowConfig: ShadowConfig(color: CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.1), radius: 10, offset: CGPoint(x: 0, y: 4)),
                borderConfig: BorderConfig(cornerRadius: 16),
                backgroundFill: FillConfig(fillType: .solid, color: .white)
            ),
            properties: [
                ConfigurableProperty(key: "cornerRadius", name: "Corner Radius", type: .slider(min: 0, max: 32), defaultValue: .number(16)),
                ConfigurableProperty(key: "shadowRadius", name: "Shadow Radius", type: .slider(min: 0, max: 30), defaultValue: .number(10)),
                ConfigurableProperty(key: "backgroundColor", name: "Background", type: .color, defaultValue: .color(.white)),
            ],
            swiftUIViewName: "Card",
            reactComponentName: "Card"
        ),

        // Input Field
        CanvasComponent(
            name: "TextField",
            description: "A text input field",
            icon: "rectangle.and.pencil.and.ellipsis",
            tags: ["input", "text", "field", "form"],
            baseLayer: CanvasLayer(
                name: "TextField",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 280, height: 44)),
                layerType: .element,
                borderConfig: BorderConfig(color: CanvasColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1), width: 1, cornerRadius: 8),
                backgroundFill: FillConfig(fillType: .solid, color: .white)
            ),
            properties: [
                ConfigurableProperty(key: "placeholder", name: "Placeholder", type: .text, defaultValue: .string("Enter text...")),
                ConfigurableProperty(key: "cornerRadius", name: "Corner Radius", type: .slider(min: 0, max: 22), defaultValue: .number(8)),
            ],
            swiftUIViewName: "TextField",
            reactComponentName: "Input"
        ),

        // Toggle/Switch
        CanvasComponent(
            name: "Toggle",
            description: "An on/off toggle switch",
            icon: "switch.2",
            tags: ["toggle", "switch", "boolean", "control"],
            baseLayer: CanvasLayer(
                name: "Toggle",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 51, height: 31)),
                layerType: .element,
                borderConfig: BorderConfig(cornerRadius: 15.5),
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0.2, green: 0.78, blue: 0.35))
            ),
            properties: [
                ConfigurableProperty(key: "isOn", name: "Is On", type: .toggle, defaultValue: .bool(true)),
                ConfigurableProperty(key: "tintColor", name: "Tint Color", type: .color, defaultValue: .color(CanvasColor(red: 0.2, green: 0.78, blue: 0.35))),
            ],
            swiftUIViewName: "Toggle",
            reactComponentName: "Switch"
        ),

        // Slider
        CanvasComponent(
            name: "Slider",
            description: "A slider for selecting a value from a range",
            icon: "slider.horizontal.3",
            tags: ["slider", "range", "control"],
            baseLayer: CanvasLayer(
                name: "Slider",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 200, height: 28)),
                layerType: .element,
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0.9, green: 0.9, blue: 0.9))
            ),
            properties: [
                ConfigurableProperty(key: "value", name: "Value", type: .slider(min: 0, max: 1), defaultValue: .number(0.5)),
                ConfigurableProperty(key: "tintColor", name: "Tint Color", type: .color, defaultValue: .color(.accent)),
            ],
            swiftUIViewName: "Slider",
            reactComponentName: "Slider"
        ),

        // Stack (HStack)
        CanvasComponent(
            name: "HStack",
            description: "A horizontal stack layout container",
            icon: "square.split.1x2",
            tags: ["stack", "horizontal", "layout", "container"],
            baseLayer: CanvasLayer(
                name: "HStack",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 300, height: 100)),
                layerType: .container
            ),
            properties: [
                ConfigurableProperty(key: "spacing", name: "Spacing", type: .slider(min: 0, max: 40), defaultValue: .number(8)),
                ConfigurableProperty(key: "alignment", name: "Alignment", type: .segmented(["Top", "Center", "Bottom"]), defaultValue: .string("Center")),
            ],
            swiftUIViewName: "HStack",
            reactComponentName: "Flex"
        ),

        // Stack (VStack)
        CanvasComponent(
            name: "VStack",
            description: "A vertical stack layout container",
            icon: "square.split.2x1",
            tags: ["stack", "vertical", "layout", "container"],
            baseLayer: CanvasLayer(
                name: "VStack",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 200, height: 300)),
                layerType: .container
            ),
            properties: [
                ConfigurableProperty(key: "spacing", name: "Spacing", type: .slider(min: 0, max: 40), defaultValue: .number(8)),
                ConfigurableProperty(key: "alignment", name: "Alignment", type: .segmented(["Leading", "Center", "Trailing"]), defaultValue: .string("Center")),
            ],
            swiftUIViewName: "VStack",
            reactComponentName: "Flex"
        ),

        // Navigation Bar
        CanvasComponent(
            name: "NavigationBar",
            description: "A navigation bar with title and actions",
            icon: "rectangle.topthird.inset.filled",
            tags: ["navigation", "bar", "header"],
            baseLayer: CanvasLayer(
                name: "NavigationBar",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 393, height: 96)),
                layerType: .element,
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0.97, green: 0.97, blue: 0.97))
            ),
            properties: [
                ConfigurableProperty(key: "title", name: "Title", type: .text, defaultValue: .string("Title")),
                ConfigurableProperty(key: "displayMode", name: "Display Mode", type: .segmented(["Large", "Inline"]), defaultValue: .string("Large")),
            ],
            swiftUIViewName: "NavigationStack",
            reactComponentName: "NavBar"
        ),

        // Tab Bar
        CanvasComponent(
            name: "TabBar",
            description: "A tab bar for bottom navigation",
            icon: "rectangle.bottomthird.inset.filled",
            tags: ["tab", "bar", "navigation", "bottom"],
            baseLayer: CanvasLayer(
                name: "TabBar",
                frame: CanvasFrame(origin: .zero, size: CGSize(width: 393, height: 83)),
                layerType: .element,
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0.97, green: 0.97, blue: 0.97))
            ),
            properties: [
                ConfigurableProperty(key: "tabCount", name: "Tab Count", type: .stepper(min: 2, max: 5), defaultValue: .number(4)),
            ],
            swiftUIViewName: "TabView",
            reactComponentName: "TabBar"
        ),
    ]
}
