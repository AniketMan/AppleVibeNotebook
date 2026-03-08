import Foundation
import CoreGraphics

// MARK: - Configurable Property

/// A property that can be configured in the Property Inspector.
/// Like Procreate's brush settings, each property has a specific control type.
public struct ConfigurableProperty: Codable, Sendable, Identifiable {
    public let id: UUID
    public let key: String           // Unique identifier for code gen
    public var name: String          // Display name
    public var description: String
    public var type: PropertyType
    public var defaultValue: PropertyValue
    public var group: String?        // For grouping in inspector
    public var isAdvanced: Bool      // Show in "More Options"
    public var isRequired: Bool
    public var validation: PropertyValidation?

    public init(
        id: UUID = UUID(),
        key: String,
        name: String,
        description: String = "",
        type: PropertyType,
        defaultValue: PropertyValue,
        group: String? = nil,
        isAdvanced: Bool = false,
        isRequired: Bool = false,
        validation: PropertyValidation? = nil
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.description = description
        self.type = type
        self.defaultValue = defaultValue
        self.group = group
        self.isAdvanced = isAdvanced
        self.isRequired = isRequired
        self.validation = validation
    }
}

// MARK: - Property Type

/// The type of control to display for editing a property.
public enum PropertyType: Codable, Sendable {
    // Basic types
    case text
    case textArea
    case number
    case toggle

    // Range controls
    case slider(min: Double, max: Double)
    case stepper(min: Int, max: Int)

    // Selection controls
    case dropdown([String])
    case segmented([String])
    case radioGroup([String])

    // Visual controls
    case color
    case colorWithOpacity
    case gradient
    case image
    case icon

    // Layout controls
    case point          // CGPoint
    case size           // CGSize
    case rect           // CGRect
    case insets         // EdgeInsets
    case alignment      // Vertical/Horizontal alignment

    // Advanced controls
    case font
    case shadow
    case border
    case padding
    case cornerRadius
    case animation

    // Reference types
    case component      // Reference to another component
    case asset          // Reference to an asset (image, icon, etc.)
    case binding        // Data binding expression
    case action         // Action/callback reference

    // Custom
    case custom(String) // Custom editor identifier
}

// MARK: - Property Value

/// The value of a configurable property.
public enum PropertyValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case color(CanvasColor)
    case point(CGPoint)
    case size(CGSize)
    case rect(CGRect)
    case insets(EdgeInsetsValue)
    case gradient(GradientConfig)
    case font(FontValue)
    case shadow(ShadowConfig)
    case border(BorderConfig)
    case array([PropertyValue])
    case dictionary([String: PropertyValue])
    case null

    // MARK: - Convenience Accessors

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var colorValue: CanvasColor? {
        if case .color(let value) = self { return value }
        return nil
    }

    public var pointValue: CGPoint? {
        if case .point(let value) = self { return value }
        return nil
    }

    public var sizeValue: CGSize? {
        if case .size(let value) = self { return value }
        return nil
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "string":
            self = .string(try container.decode(String.self, forKey: .value))
        case "number":
            self = .number(try container.decode(Double.self, forKey: .value))
        case "bool":
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case "color":
            self = .color(try container.decode(CanvasColor.self, forKey: .value))
        case "point":
            self = .point(try container.decode(CGPoint.self, forKey: .value))
        case "size":
            self = .size(try container.decode(CGSize.self, forKey: .value))
        case "rect":
            self = .rect(try container.decode(CGRect.self, forKey: .value))
        case "insets":
            self = .insets(try container.decode(EdgeInsetsValue.self, forKey: .value))
        case "gradient":
            self = .gradient(try container.decode(GradientConfig.self, forKey: .value))
        case "font":
            self = .font(try container.decode(FontValue.self, forKey: .value))
        case "shadow":
            self = .shadow(try container.decode(ShadowConfig.self, forKey: .value))
        case "border":
            self = .border(try container.decode(BorderConfig.self, forKey: .value))
        case "array":
            self = .array(try container.decode([PropertyValue].self, forKey: .value))
        case "dictionary":
            self = .dictionary(try container.decode([String: PropertyValue].self, forKey: .value))
        case "null":
            self = .null
        default:
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case .number(let value):
            try container.encode("number", forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode("bool", forKey: .type)
            try container.encode(value, forKey: .value)
        case .color(let value):
            try container.encode("color", forKey: .type)
            try container.encode(value, forKey: .value)
        case .point(let value):
            try container.encode("point", forKey: .type)
            try container.encode(value, forKey: .value)
        case .size(let value):
            try container.encode("size", forKey: .type)
            try container.encode(value, forKey: .value)
        case .rect(let value):
            try container.encode("rect", forKey: .type)
            try container.encode(value, forKey: .value)
        case .insets(let value):
            try container.encode("insets", forKey: .type)
            try container.encode(value, forKey: .value)
        case .gradient(let value):
            try container.encode("gradient", forKey: .type)
            try container.encode(value, forKey: .value)
        case .font(let value):
            try container.encode("font", forKey: .type)
            try container.encode(value, forKey: .value)
        case .shadow(let value):
            try container.encode("shadow", forKey: .type)
            try container.encode(value, forKey: .value)
        case .border(let value):
            try container.encode("border", forKey: .type)
            try container.encode(value, forKey: .value)
        case .array(let value):
            try container.encode("array", forKey: .type)
            try container.encode(value, forKey: .value)
        case .dictionary(let value):
            try container.encode("dictionary", forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode("null", forKey: .type)
        }
    }
}

// MARK: - Property Validation

/// Validation rules for a property.
public struct PropertyValidation: Codable, Sendable {
    public var isRequired: Bool
    public var minLength: Int?
    public var maxLength: Int?
    public var minValue: Double?
    public var maxValue: Double?
    public var pattern: String?          // Regex pattern for strings
    public var customValidator: String?  // Name of custom validation function
    public var errorMessage: String?

    public init(
        isRequired: Bool = false,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil,
        pattern: String? = nil,
        customValidator: String? = nil,
        errorMessage: String? = nil
    ) {
        self.isRequired = isRequired
        self.minLength = minLength
        self.maxLength = maxLength
        self.minValue = minValue
        self.maxValue = maxValue
        self.pattern = pattern
        self.customValidator = customValidator
        self.errorMessage = errorMessage
    }

    public func validate(_ value: PropertyValue) -> ValidationResult {
        switch value {
        case .string(let str):
            if isRequired && str.isEmpty {
                return .invalid(errorMessage ?? "This field is required")
            }
            if let min = minLength, str.count < min {
                return .invalid(errorMessage ?? "Minimum \(min) characters required")
            }
            if let max = maxLength, str.count > max {
                return .invalid(errorMessage ?? "Maximum \(max) characters allowed")
            }
            if let pattern = pattern {
                let regex = try? NSRegularExpression(pattern: pattern)
                let range = NSRange(str.startIndex..., in: str)
                if regex?.firstMatch(in: str, range: range) == nil {
                    return .invalid(errorMessage ?? "Invalid format")
                }
            }

        case .number(let num):
            if let min = minValue, num < min {
                return .invalid(errorMessage ?? "Minimum value is \(min)")
            }
            if let max = maxValue, num > max {
                return .invalid(errorMessage ?? "Maximum value is \(max)")
            }

        case .null:
            if isRequired {
                return .invalid(errorMessage ?? "This field is required")
            }

        default:
            break
        }

        return .valid
    }
}

public enum ValidationResult: Sendable {
    case valid
    case invalid(String)
    case warning(String)

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

// MARK: - Supporting Types

public struct EdgeInsetsValue: Codable, Sendable, Equatable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(all: CGFloat) {
        self.top = all
        self.leading = all
        self.bottom = all
        self.trailing = all
    }

    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.top = vertical
        self.leading = horizontal
        self.bottom = vertical
        self.trailing = horizontal
    }
}

public struct FontValue: Codable, Sendable, Equatable {
    public var family: String
    public var size: CGFloat
    public var weight: FontWeight
    public var isItalic: Bool
    public var design: FontDesign

    public init(
        family: String = "System",
        size: CGFloat = 17,
        weight: FontWeight = .regular,
        isItalic: Bool = false,
        design: FontDesign = .default
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.isItalic = isItalic
        self.design = design
    }
}

public enum FontDesign: String, Codable, Sendable, CaseIterable {
    case `default`, rounded, serif, monospaced
}

// MARK: - Property Group

/// A group of related properties for organization in the inspector.
public struct PropertyGroup: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var icon: String?
    public var isExpanded: Bool
    public var properties: [ConfigurableProperty]

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String? = nil,
        isExpanded: Bool = true,
        properties: [ConfigurableProperty] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isExpanded = isExpanded
        self.properties = properties
    }
}

// MARK: - Common Property Groups

extension PropertyGroup {
    public static func layout() -> PropertyGroup {
        PropertyGroup(
            name: "Layout",
            icon: "square.grid.2x2",
            properties: [
                ConfigurableProperty(key: "width", name: "Width", type: .number, defaultValue: .number(100)),
                ConfigurableProperty(key: "height", name: "Height", type: .number, defaultValue: .number(100)),
                ConfigurableProperty(key: "padding", name: "Padding", type: .padding, defaultValue: .insets(EdgeInsetsValue())),
            ]
        )
    }

    public static func appearance() -> PropertyGroup {
        PropertyGroup(
            name: "Appearance",
            icon: "paintbrush",
            properties: [
                ConfigurableProperty(key: "backgroundColor", name: "Background", type: .colorWithOpacity, defaultValue: .color(.white)),
                ConfigurableProperty(key: "opacity", name: "Opacity", type: .slider(min: 0, max: 1), defaultValue: .number(1)),
                ConfigurableProperty(key: "cornerRadius", name: "Corner Radius", type: .cornerRadius, defaultValue: .number(0)),
            ]
        )
    }

    public static func border() -> PropertyGroup {
        PropertyGroup(
            name: "Border",
            icon: "square",
            properties: [
                ConfigurableProperty(key: "borderWidth", name: "Width", type: .slider(min: 0, max: 10), defaultValue: .number(0)),
                ConfigurableProperty(key: "borderColor", name: "Color", type: .color, defaultValue: .color(.black)),
            ]
        )
    }

    public static func shadow() -> PropertyGroup {
        PropertyGroup(
            name: "Shadow",
            icon: "shadow",
            properties: [
                ConfigurableProperty(key: "shadowRadius", name: "Radius", type: .slider(min: 0, max: 50), defaultValue: .number(0)),
                ConfigurableProperty(key: "shadowColor", name: "Color", type: .colorWithOpacity, defaultValue: .color(CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.25))),
                ConfigurableProperty(key: "shadowOffset", name: "Offset", type: .point, defaultValue: .point(CGPoint(x: 0, y: 4))),
            ]
        )
    }

    public static func typography() -> PropertyGroup {
        PropertyGroup(
            name: "Typography",
            icon: "textformat",
            properties: [
                ConfigurableProperty(key: "font", name: "Font", type: .font, defaultValue: .font(FontValue())),
                ConfigurableProperty(key: "textColor", name: "Color", type: .color, defaultValue: .color(.black)),
                ConfigurableProperty(key: "textAlignment", name: "Alignment", type: .segmented(["Leading", "Center", "Trailing"]), defaultValue: .string("Leading")),
            ]
        )
    }
}
