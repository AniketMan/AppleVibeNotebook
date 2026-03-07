import Foundation

// MARK: - Intermediate Representation (JSON IR)

/// The Intermediate Representation is the central data structure that bridges
/// the parsing layer and the code generation layer. It captures all information
/// needed to generate SwiftUI code from a React component.
public struct IntermediateRepresentation: Codable, Sendable {
    public let version: String
    public let sourceFiles: [SourceFileIR]
    public let globalStyles: GlobalStylesIR
    public let metadata: ConversionMetadata

    public init(
        version: String = "1.0.0",
        sourceFiles: [SourceFileIR] = [],
        globalStyles: GlobalStylesIR = GlobalStylesIR(),
        metadata: ConversionMetadata
    ) {
        self.version = version
        self.sourceFiles = sourceFiles
        self.globalStyles = globalStyles
        self.metadata = metadata
    }
}

// MARK: - Source File IR

/// Represents a single React source file in the IR.
public struct SourceFileIR: Codable, Sendable, Identifiable {
    public let id: UUID
    public let originalPath: String
    public let components: [ComponentIR]
    public let imports: [ImportIR]
    public let exports: [ExportIR]

    public init(
        id: UUID = UUID(),
        originalPath: String,
        components: [ComponentIR] = [],
        imports: [ImportIR] = [],
        exports: [ExportIR] = []
    ) {
        self.id = id
        self.originalPath = originalPath
        self.components = components
        self.imports = imports
        self.exports = exports
    }
}

// MARK: - Component IR

/// Represents a React component in the IR, ready for SwiftUI code generation.
public struct ComponentIR: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let isDefault: Bool
    public let sourceLocation: SourceLocation

    // Props → SwiftUI init parameters
    public let parameters: [ParameterIR]

    // State → @State properties
    public let stateProperties: [StatePropertyIR]

    // Effects → Lifecycle modifiers
    public let effects: [EffectIR]

    // View hierarchy
    public let viewHierarchy: ViewNodeIR

    // Generic type parameters (for @ViewBuilder content)
    public let genericParameters: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        sourceLocation: SourceLocation,
        parameters: [ParameterIR] = [],
        stateProperties: [StatePropertyIR] = [],
        effects: [EffectIR] = [],
        viewHierarchy: ViewNodeIR,
        genericParameters: [String] = []
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.sourceLocation = sourceLocation
        self.parameters = parameters
        self.stateProperties = stateProperties
        self.effects = effects
        self.viewHierarchy = viewHierarchy
        self.genericParameters = genericParameters
    }
}

// MARK: - Parameter IR

/// Represents a SwiftUI struct init parameter.
public struct ParameterIR: Codable, Sendable {
    public let name: String
    public let type: String
    public let defaultValue: String?
    public let isBinding: Bool
    public let isViewBuilder: Bool
    public let isOptional: Bool
    public let documentation: String?

    public init(
        name: String,
        type: String,
        defaultValue: String? = nil,
        isBinding: Bool = false,
        isViewBuilder: Bool = false,
        isOptional: Bool = false,
        documentation: String? = nil
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.isBinding = isBinding
        self.isViewBuilder = isViewBuilder
        self.isOptional = isOptional
        self.documentation = documentation
    }
}

// MARK: - State Property IR

/// Represents a @State property in SwiftUI.
public struct StatePropertyIR: Codable, Sendable {
    public let name: String
    public let type: String
    public let initialValue: String
    public let wrapper: SwiftUIPropertyWrapper
    public let isPrivate: Bool

    public init(
        name: String,
        type: String,
        initialValue: String,
        wrapper: SwiftUIPropertyWrapper = .state,
        isPrivate: Bool = true
    ) {
        self.name = name
        self.type = type
        self.initialValue = initialValue
        self.wrapper = wrapper
        self.isPrivate = isPrivate
    }
}

// MARK: - Effect IR

/// Represents a lifecycle effect (onAppear, onChange, etc.).
public struct EffectIR: Codable, Sendable {
    public let modifier: SwiftUIModifier
    public let dependencies: [String]
    public let body: String
    public let hasCleanup: Bool
    public let cleanupBody: String?

    public init(
        modifier: SwiftUIModifier,
        dependencies: [String] = [],
        body: String,
        hasCleanup: Bool = false,
        cleanupBody: String? = nil
    ) {
        self.modifier = modifier
        self.dependencies = dependencies
        self.body = body
        self.hasCleanup = hasCleanup
        self.cleanupBody = cleanupBody
    }
}

// MARK: - View Node IR

/// Represents a node in the SwiftUI view hierarchy.
public indirect enum ViewNodeIR: Codable, Sendable {
    case view(ViewIR)
    case text(TextIR)
    case conditional(ConditionalIR)
    case loop(LoopIR)
    case group([ViewNodeIR])
    case empty
    case unsupported(UnsupportedIR)
}

/// Represents a SwiftUI view with modifiers.
public struct ViewIR: Codable, Sendable, Identifiable {
    public let id: UUID
    public let viewType: SwiftUIViewType
    public let initArguments: [InitArgumentIR]
    public let modifiers: [ModifierIR]
    public let children: [ViewNodeIR]
    public let sourceLocation: SourceLocation
    public let conversionTier: ConversionTier

    public init(
        id: UUID = UUID(),
        viewType: SwiftUIViewType,
        initArguments: [InitArgumentIR] = [],
        modifiers: [ModifierIR] = [],
        children: [ViewNodeIR] = [],
        sourceLocation: SourceLocation,
        conversionTier: ConversionTier = .direct
    ) {
        self.id = id
        self.viewType = viewType
        self.initArguments = initArguments
        self.modifiers = modifiers
        self.children = children
        self.sourceLocation = sourceLocation
        self.conversionTier = conversionTier
    }
}

/// Represents a Text view with attributed text.
public struct TextIR: Codable, Sendable {
    public let content: TextContentIR
    public let modifiers: [ModifierIR]
    public let sourceLocation: SourceLocation

    public init(
        content: TextContentIR,
        modifiers: [ModifierIR] = [],
        sourceLocation: SourceLocation
    ) {
        self.content = content
        self.modifiers = modifiers
        self.sourceLocation = sourceLocation
    }
}

/// Represents text content, which may be static or dynamic.
public enum TextContentIR: Codable, Sendable {
    case literal(String)
    case interpolation(String)
    case concatenation([TextContentIR])
    case localizedKey(String)
}

/// Represents an init argument for a view.
public struct InitArgumentIR: Codable, Sendable {
    public let label: String?
    public let value: ValueIR

    public init(label: String? = nil, value: ValueIR) {
        self.label = label
        self.value = value
    }
}

/// Represents a value (literal, binding, or expression).
public enum ValueIR: Codable, Sendable {
    case literal(String)
    case binding(String)
    case expression(String)
    case closure(String)
}

/// Represents a SwiftUI modifier applied to a view.
public struct ModifierIR: Codable, Sendable {
    public let modifier: SwiftUIModifier
    public let arguments: [InitArgumentIR]
    public let rawCode: String?

    public init(
        modifier: SwiftUIModifier,
        arguments: [InitArgumentIR] = [],
        rawCode: String? = nil
    ) {
        self.modifier = modifier
        self.arguments = arguments
        self.rawCode = rawCode
    }
}

/// Represents conditional rendering (if/else).
public struct ConditionalIR: Codable, Sendable {
    public let condition: String
    public let trueBranch: ViewNodeIR
    public let falseBranch: ViewNodeIR?

    public init(
        condition: String,
        trueBranch: ViewNodeIR,
        falseBranch: ViewNodeIR? = nil
    ) {
        self.condition = condition
        self.trueBranch = trueBranch
        self.falseBranch = falseBranch
    }
}

/// Represents a ForEach loop.
public struct LoopIR: Codable, Sendable {
    public let arrayExpression: String
    public let itemVariable: String
    public let idKeyPath: String
    public let body: ViewNodeIR

    public init(
        arrayExpression: String,
        itemVariable: String,
        idKeyPath: String = "\\.self",
        body: ViewNodeIR
    ) {
        self.arrayExpression = arrayExpression
        self.itemVariable = itemVariable
        self.idKeyPath = idKeyPath
        self.body = body
    }
}

/// Represents an unsupported element preserved as comment.
public struct UnsupportedIR: Codable, Sendable {
    public let originalCode: String
    public let reason: String
    public let suggestedApproach: String?
    public let sourceLocation: SourceLocation

    public init(
        originalCode: String,
        reason: String,
        suggestedApproach: String? = nil,
        sourceLocation: SourceLocation
    ) {
        self.originalCode = originalCode
        self.reason = reason
        self.suggestedApproach = suggestedApproach
        self.sourceLocation = sourceLocation
    }
}

// MARK: - Import/Export IR

/// Represents an import statement mapping.
public struct ImportIR: Codable, Sendable {
    public let originalModule: String
    public let swiftImport: String?
    public let isRequired: Bool

    public init(
        originalModule: String,
        swiftImport: String?,
        isRequired: Bool = false
    ) {
        self.originalModule = originalModule
        self.swiftImport = swiftImport
        self.isRequired = isRequired
    }
}

/// Represents an export from the module.
public struct ExportIR: Codable, Sendable {
    public let name: String
    public let isDefault: Bool
    public let accessLevel: String

    public init(name: String, isDefault: Bool = false, accessLevel: String = "public") {
        self.name = name
        self.isDefault = isDefault
        self.accessLevel = accessLevel
    }
}

// MARK: - Global Styles IR

/// Represents global CSS that maps to SwiftUI color/style assets.
public struct GlobalStylesIR: Codable, Sendable {
    public var colors: [String: CSSColor]
    public var fonts: [String: FontDefinitionIR]
    public var spacing: [String: Double]
    public var cornerRadii: [String: Double]
    public var shadows: [String: CSSBoxShadow]

    public init(
        colors: [String: CSSColor] = [:],
        fonts: [String: FontDefinitionIR] = [:],
        spacing: [String: Double] = [:],
        cornerRadii: [String: Double] = [:],
        shadows: [String: CSSBoxShadow] = [:]
    ) {
        self.colors = colors
        self.fonts = fonts
        self.spacing = spacing
        self.cornerRadii = cornerRadii
        self.shadows = shadows
    }
}

/// Represents a font definition for code generation.
public struct FontDefinitionIR: Codable, Sendable {
    public let family: String?
    public let size: Double
    public let weight: String?
    public let design: String?

    public init(
        family: String? = nil,
        size: Double,
        weight: String? = nil,
        design: String? = nil
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.design = design
    }
}

// MARK: - Conversion Metadata

/// Metadata about the conversion process.
public struct ConversionMetadata: Codable, Sendable {
    public let sourceProjectName: String
    public let sourceProjectPath: String
    public let conversionTimestamp: Date
    public let react2SwiftUIVersion: String
    public let targetPlatforms: [String]
    public let minimumSwiftVersion: String
    public let sourceStatistics: SourceStatistics

    public init(
        sourceProjectName: String,
        sourceProjectPath: String,
        conversionTimestamp: Date = Date(),
        react2SwiftUIVersion: String = "1.0.0",
        targetPlatforms: [String] = ["iOS", "macOS"],
        minimumSwiftVersion: String = "6.0",
        sourceStatistics: SourceStatistics = SourceStatistics()
    ) {
        self.sourceProjectName = sourceProjectName
        self.sourceProjectPath = sourceProjectPath
        self.conversionTimestamp = conversionTimestamp
        self.react2SwiftUIVersion = react2SwiftUIVersion
        self.targetPlatforms = targetPlatforms
        self.minimumSwiftVersion = minimumSwiftVersion
        self.sourceStatistics = sourceStatistics
    }
}

/// Statistics about the source project.
public struct SourceStatistics: Codable, Sendable {
    public var totalFiles: Int
    public var totalComponents: Int
    public var totalLinesOfCode: Int
    public var cssFiles: Int
    public var typeScriptUsed: Bool

    public init(
        totalFiles: Int = 0,
        totalComponents: Int = 0,
        totalLinesOfCode: Int = 0,
        cssFiles: Int = 0,
        typeScriptUsed: Bool = false
    ) {
        self.totalFiles = totalFiles
        self.totalComponents = totalComponents
        self.totalLinesOfCode = totalLinesOfCode
        self.cssFiles = cssFiles
        self.typeScriptUsed = typeScriptUsed
    }
}

// MARK: - IR Builder

/// Builder for constructing the Intermediate Representation.
public final class IRBuilder: @unchecked Sendable {
    private var sourceFiles: [SourceFileIR] = []
    private var globalStyles = GlobalStylesIR()
    private let metadata: ConversionMetadata
    private let lock = NSLock()

    public init(projectName: String, projectPath: String) {
        self.metadata = ConversionMetadata(
            sourceProjectName: projectName,
            sourceProjectPath: projectPath
        )
    }

    /// Adds a source file to the IR.
    public func addSourceFile(_ file: SourceFileIR) {
        lock.lock()
        defer { lock.unlock() }
        sourceFiles.append(file)
    }

    /// Adds a global color definition.
    public func addColor(name: String, color: CSSColor) {
        lock.lock()
        defer { lock.unlock() }
        globalStyles.colors[name] = color
    }

    /// Adds a global font definition.
    public func addFont(name: String, font: FontDefinitionIR) {
        lock.lock()
        defer { lock.unlock() }
        globalStyles.fonts[name] = font
    }

    /// Adds a global spacing value.
    public func addSpacing(name: String, value: Double) {
        lock.lock()
        defer { lock.unlock() }
        globalStyles.spacing[name] = value
    }

    /// Builds the final IR.
    public func build() -> IntermediateRepresentation {
        lock.lock()
        defer { lock.unlock() }

        return IntermediateRepresentation(
            sourceFiles: sourceFiles,
            globalStyles: globalStyles,
            metadata: metadata
        )
    }
}
