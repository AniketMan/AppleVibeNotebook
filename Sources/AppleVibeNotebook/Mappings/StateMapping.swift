import Foundation

// MARK: - State & Lifecycle Mapping Dictionary

/// Deterministic mappings from React hooks to SwiftUI property wrappers and lifecycle modifiers.
/// These mappings are derived from React documentation and Apple SwiftUI documentation.
/// Reference: React Hooks API Reference, Apple SwiftUI Documentation
public enum StateMapping {

    // MARK: - React Hook → SwiftUI Property Wrapper

    /// Maps a React hook to its SwiftUI equivalent.
    public static func propertyWrapper(for hook: ReactHookType) -> HookMappingResult {
        switch hook {
        case .useState:
            return HookMappingResult(
                propertyWrapper: .state,
                additionalImports: [],
                tier: .direct,
                explanation: "useState maps directly to @State. " +
                            "const [value, setValue] = useState(initial) → @State private var value = initial"
            )

        case .useEffect:
            return HookMappingResult(
                propertyWrapper: nil,
                lifecycleModifier: .onAppear,
                additionalModifiers: [.onChange, .onDisappear],
                tier: .direct,
                explanation: "useEffect maps to lifecycle modifiers. " +
                            "Empty deps [] → .onAppear, " +
                            "with deps [x] → .onChange(of: x), " +
                            "cleanup → .onDisappear"
            )

        case .useContext:
            return HookMappingResult(
                propertyWrapper: .environmentObject,
                additionalImports: [],
                tier: .adapted,
                explanation: "useContext maps to @EnvironmentObject or @Environment. " +
                            "Requires creating an ObservableObject class from the context shape."
            )

        case .useReducer:
            return HookMappingResult(
                propertyWrapper: .state,
                additionalImports: [],
                tier: .adapted,
                explanation: "useReducer maps to @State with a separate reducer function. " +
                            "Consider using @Observable class for complex state."
            )

        case .useCallback:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .direct,
                explanation: "useCallback is unnecessary in SwiftUI. " +
                            "Swift closures are reference types; define as computed property or method."
            )

        case .useMemo:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .direct,
                explanation: "useMemo is unnecessary in SwiftUI. " +
                            "Use computed property; SwiftUI handles view identity efficiently."
            )

        case .useRef:
            return HookMappingResult(
                propertyWrapper: .focusState,
                tier: .adapted,
                explanation: "useRef for DOM refs maps to @FocusState for focus management, " +
                            "or regular class property for mutable values that don't trigger re-render."
            )

        case .useImperativeHandle:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .unsupported,
                explanation: "useImperativeHandle has no SwiftUI equivalent. " +
                            "SwiftUI uses declarative patterns; consider @Binding or callback props."
            )

        case .useLayoutEffect:
            return HookMappingResult(
                propertyWrapper: nil,
                lifecycleModifier: .onAppear,
                tier: .adapted,
                explanation: "useLayoutEffect maps to .onAppear. " +
                            "SwiftUI doesn't distinguish layout timing; all effects run before display."
            )

        case .useDebugValue:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .unsupported,
                explanation: "useDebugValue has no SwiftUI equivalent. " +
                            "Use Xcode debugger or print statements for debugging."
            )

        case .useDeferredValue:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .adapted,
                explanation: "useDeferredValue maps to debounced @State updates. " +
                            "Use Combine's .debounce or Task.sleep for deferred updates."
            )

        case .useTransition:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .adapted,
                explanation: "useTransition maps to withAnimation with lower priority. " +
                            "Consider using .task with Task.yield() for interruptible work."
            )

        case .useId:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .direct,
                explanation: "useId maps to UUID().uuidString or stable identifiers. " +
                            "SwiftUI typically uses ForEach id parameter instead."
            )

        case .useSyncExternalStore:
            return HookMappingResult(
                propertyWrapper: .observedObject,
                additionalImports: ["Combine"],
                tier: .adapted,
                explanation: "useSyncExternalStore maps to @ObservedObject or @Observable. " +
                            "External stores should conform to ObservableObject."
            )

        case .useInsertionEffect:
            return HookMappingResult(
                propertyWrapper: nil,
                tier: .unsupported,
                explanation: "useInsertionEffect (CSS-in-JS injection) has no SwiftUI equivalent. " +
                            "SwiftUI styles are applied directly via modifiers."
            )

        case .useOptimistic:
            return HookMappingResult(
                propertyWrapper: .state,
                tier: .adapted,
                explanation: "useOptimistic maps to @State with optimistic update pattern. " +
                            "Update immediately, then reconcile on server response."
            )

        case .useFormStatus:
            return HookMappingResult(
                propertyWrapper: .environment,
                tier: .adapted,
                explanation: "useFormStatus maps to @Environment or custom form state. " +
                            "Create FormState observable and inject via environment."
            )

        case .useFormState:
            return HookMappingResult(
                propertyWrapper: .state,
                tier: .adapted,
                explanation: "useFormState maps to @State with action handler. " +
                            "SwiftUI forms use @State bindings and onSubmit."
            )

        case .useActionState:
            return HookMappingResult(
                propertyWrapper: .state,
                tier: .adapted,
                explanation: "useActionState maps to @State with async action pattern. " +
                            "Use .task or Button action with async closure."
            )

        case .use:
            return HookMappingResult(
                propertyWrapper: nil,
                lifecycleModifier: .task,
                tier: .direct,
                explanation: "use() for promises maps to .task modifier with async/await. " +
                            "SwiftUI supports native async data loading."
            )
        }
    }

    // MARK: - useEffect Dependency Analysis

    /// Analyzes useEffect dependencies to determine appropriate SwiftUI modifiers.
    public static func analyzeEffect(
        dependencies: [String]?,
        hasCleanup: Bool
    ) -> EffectAnalysisResult {
        guard let deps = dependencies else {
            return EffectAnalysisResult(
                modifiers: [.onChange],
                pattern: .everyRender,
                tier: .adapted,
                explanation: "useEffect with no dependency array runs on every render. " +
                            "This pattern is discouraged; consider adding dependencies."
            )
        }

        if deps.isEmpty {
            var modifiers: [SwiftUIModifier] = [.onAppear]
            if hasCleanup {
                modifiers.append(.onDisappear)
            }

            return EffectAnalysisResult(
                modifiers: modifiers,
                pattern: .mountOnly,
                tier: .direct,
                explanation: "useEffect([]) with empty deps runs on mount. " +
                            "Maps to .onAppear" + (hasCleanup ? " with cleanup in .onDisappear" : "")
            )
        }

        if deps.count == 1 {
            var modifiers: [SwiftUIModifier] = [.onChange]
            if hasCleanup {
                modifiers.append(.onDisappear)
            }

            return EffectAnalysisResult(
                modifiers: modifiers,
                pattern: .singleDependency(deps[0]),
                tier: .direct,
                explanation: "useEffect([\(deps[0])]) maps to .onChange(of: \(deps[0]))"
            )
        }

        return EffectAnalysisResult(
            modifiers: [.onChange, .task],
            pattern: .multipleDependencies(deps),
            tier: .adapted,
            explanation: "useEffect with multiple deps requires multiple .onChange modifiers " +
                        "or a combined state object. Consider using .task for async work."
        )
    }

    // MARK: - Props → SwiftUI Init Parameters

    /// Maps React props patterns to SwiftUI struct initialization.
    public static func propsMapping(_ props: [ParsedProp]) -> PropsMappingResult {
        var parameters: [SwiftUIParameter] = []
        var propertyWrappers: [PropertyWrapperUsage] = []

        for prop in props {
            if prop.isCallback {
                if prop.name.hasPrefix("on") {
                    parameters.append(SwiftUIParameter(
                        name: prop.name,
                        type: "() -> Void",
                        defaultValue: nil,
                        isOptional: !prop.isRequired
                    ))
                } else if prop.name.hasPrefix("set") || prop.name.contains("Change") {
                    propertyWrappers.append(PropertyWrapperUsage(
                        wrapper: .binding,
                        variableName: extractValueName(from: prop.name),
                        type: prop.type ?? "String"
                    ))
                }
            } else if prop.name == "children" {
                parameters.append(SwiftUIParameter(
                    name: "content",
                    type: "@ViewBuilder () -> Content",
                    defaultValue: nil,
                    isOptional: false,
                    isViewBuilder: true
                ))
            } else {
                let swiftType = mapJSTypeToSwift(prop.type)
                parameters.append(SwiftUIParameter(
                    name: prop.name,
                    type: swiftType,
                    defaultValue: prop.defaultValue,
                    isOptional: !prop.isRequired
                ))
            }
        }

        return PropsMappingResult(
            parameters: parameters,
            propertyWrappers: propertyWrappers,
            tier: .direct,
            explanation: "React props map to SwiftUI struct init parameters. " +
                        "Callback props become closures or @Binding."
        )
    }

    // MARK: - Conditional Rendering

    /// Maps React conditional rendering patterns to SwiftUI.
    public static func conditionalMapping(_ pattern: ConditionalPattern) -> ConditionalMappingResult {
        switch pattern {
        case .ternary(let condition):
            return ConditionalMappingResult(
                swiftPattern: "if \(condition) { TrueView() } else { FalseView() }",
                tier: .direct,
                explanation: "condition ? <A/> : <B/> maps to if-else in SwiftUI @ViewBuilder"
            )

        case .logicalAnd(let condition):
            return ConditionalMappingResult(
                swiftPattern: "if \(condition) { View() }",
                tier: .direct,
                explanation: "condition && <View/> maps to if statement in @ViewBuilder"
            )

        case .logicalOr(let condition):
            return ConditionalMappingResult(
                swiftPattern: "if !\(condition) { FallbackView() }",
                tier: .direct,
                explanation: "condition || <Fallback/> maps to if with negated condition"
            )

        case .nullishCoalescing(let value, let fallback):
            return ConditionalMappingResult(
                swiftPattern: "if let \(value) = \(value) { } else { \(fallback) }",
                tier: .direct,
                explanation: "value ?? fallback maps to if-let optional binding"
            )

        case .switchStatement(let expression, let cases):
            let swiftCases = cases.map { "case \($0): View()" }.joined(separator: "\n")
            return ConditionalMappingResult(
                swiftPattern: "switch \(expression) {\n\(swiftCases)\n}",
                tier: .direct,
                explanation: "switch statement maps directly to Swift switch in @ViewBuilder"
            )
        }
    }

    // MARK: - List Rendering

    /// Maps React .map() patterns to SwiftUI ForEach.
    public static func listMapping(
        arrayExpression: String,
        itemVariable: String,
        hasIndex: Bool,
        keyExpression: String?
    ) -> ListMappingResult {
        let idExpression: String
        let tier: ConversionTier
        let explanation: String

        if let key = keyExpression {
            if key == itemVariable || key == "\(itemVariable).id" {
                idExpression = "\\.id"
                tier = .direct
                explanation = "Array.map with key={item.id} maps to ForEach with id: \\.id"
            } else if key.contains("index") {
                idExpression = "\\.self"
                tier = .adapted
                explanation = "Array.map with index key maps to ForEach with enumerated(). " +
                            "Consider using stable IDs instead of indices."
            } else {
                idExpression = "\\.\(key)"
                tier = .direct
                explanation = "Array.map with key={\(key)} maps to ForEach with id: \\.\(key)"
            }
        } else {
            idExpression = "\\.self"
            tier = .adapted
            explanation = "Array.map without key prop. Using \\.self; items must be Hashable."
        }

        let forEachCode: String
        if hasIndex {
            forEachCode = """
            ForEach(Array(\(arrayExpression).enumerated()), id: \\.offset) { index, \(itemVariable) in
                // Content
            }
            """
        } else {
            forEachCode = """
            ForEach(\(arrayExpression), id: \(idExpression)) { \(itemVariable) in
                // Content
            }
            """
        }

        return ListMappingResult(
            swiftCode: forEachCode,
            idKeyPath: idExpression,
            requiresIdentifiable: idExpression == "\\.id",
            tier: tier,
            explanation: explanation
        )
    }

    // MARK: - Helper Functions

    private static func extractValueName(from setterName: String) -> String {
        if setterName.hasPrefix("set") {
            let withoutSet = String(setterName.dropFirst(3))
            return withoutSet.prefix(1).lowercased() + withoutSet.dropFirst()
        }
        if setterName.contains("Change") {
            return setterName.replacingOccurrences(of: "Change", with: "")
                           .replacingOccurrences(of: "on", with: "")
                           .lowercased()
        }
        return setterName
    }

    private static func mapJSTypeToSwift(_ jsType: String?) -> String {
        guard let type = jsType?.lowercased() else { return "Any" }

        switch type {
        case "string": return "String"
        case "number": return "Double"
        case "boolean", "bool": return "Bool"
        case "object": return "[String: Any]"
        case "array": return "[Any]"
        case "function": return "() -> Void"
        case "date": return "Date"
        case "undefined", "null": return "Any?"
        default:
            if type.hasSuffix("[]") {
                let elementType = String(type.dropLast(2))
                return "[\(mapJSTypeToSwift(elementType))]"
            }
            return type.prefix(1).uppercased() + type.dropFirst()
        }
    }
}

// MARK: - Animation Mapping

/// Deterministic mappings from CSS animations/transitions to SwiftUI animation modifiers.
public enum AnimationMapping {

    // MARK: - CSS Timing Function → SwiftUI Animation

    /// Maps CSS timing functions to SwiftUI animation curves.
    public static func animationCurve(
        from timing: CSSTimingFunction,
        duration: Double
    ) -> AnimationCurveMappingResult {
        switch timing {
        case .linear:
            return AnimationCurveMappingResult(
                animation: ".linear(duration: \(duration))",
                tier: .direct,
                explanation: "CSS linear maps directly to SwiftUI .linear"
            )

        case .ease:
            return AnimationCurveMappingResult(
                animation: ".easeInOut(duration: \(duration))",
                tier: .direct,
                explanation: "CSS ease maps to SwiftUI .easeInOut (similar curve)"
            )

        case .easeIn:
            return AnimationCurveMappingResult(
                animation: ".easeIn(duration: \(duration))",
                tier: .direct,
                explanation: "CSS ease-in maps directly to SwiftUI .easeIn"
            )

        case .easeOut:
            return AnimationCurveMappingResult(
                animation: ".easeOut(duration: \(duration))",
                tier: .direct,
                explanation: "CSS ease-out maps directly to SwiftUI .easeOut"
            )

        case .easeInOut:
            return AnimationCurveMappingResult(
                animation: ".easeInOut(duration: \(duration))",
                tier: .direct,
                explanation: "CSS ease-in-out maps directly to SwiftUI .easeInOut"
            )

        case .stepStart:
            return AnimationCurveMappingResult(
                animation: ".linear(duration: 0)",
                tier: .adapted,
                explanation: "CSS step-start has no direct SwiftUI equivalent. " +
                            "Using instant transition."
            )

        case .stepEnd:
            return AnimationCurveMappingResult(
                animation: ".linear(duration: \(duration))",
                tier: .adapted,
                explanation: "CSS step-end has no direct SwiftUI equivalent. " +
                            "Consider using discrete state changes."
            )
        }
    }

    // MARK: - CSS Transition → SwiftUI .animation

    /// Maps CSS transition to SwiftUI animation modifier.
    public static func transitionMapping(_ transition: CSSTransition) -> TransitionMappingResult {
        let animationResult = animationCurve(from: transition.timingFunction, duration: transition.duration)

        let propertyMapping = mapCSSPropertyToAnimatable(transition.property)

        if transition.property == "all" {
            return TransitionMappingResult(
                modifier: ".animation(\(animationResult.animation))",
                animatableProperty: nil,
                tier: .direct,
                explanation: "transition: all maps to .animation() applied to the view"
            )
        }

        guard let animatable = propertyMapping else {
            return TransitionMappingResult(
                modifier: nil,
                animatableProperty: nil,
                tier: .unsupported,
                explanation: "CSS property '\(transition.property)' is not animatable in SwiftUI"
            )
        }

        return TransitionMappingResult(
            modifier: ".animation(\(animationResult.animation), value: \(animatable.stateVariable))",
            animatableProperty: animatable,
            tier: propertyMapping != nil ? .direct : .adapted,
            explanation: "transition: \(transition.property) maps to .animation with value binding"
        )
    }

    // MARK: - CSS @keyframes → SwiftUI KeyframeAnimator

    /// Maps CSS keyframe animation to SwiftUI KeyframeAnimator.
    public static func keyframeMapping(_ animation: CSSKeyframeAnimation) -> KeyframeMappingResult {
        var keyframeTracks: [KeyframeTrack] = []
        var hasUnsupportedProperties = false

        let sortedKeyframes = animation.keyframes.sorted { $0.percentage < $1.percentage }

        for keyframe in sortedKeyframes {
            for (property, value) in keyframe.properties {
                if let track = mapKeyframeProperty(property: property, value: value, at: keyframe.percentage) {
                    if let existingIndex = keyframeTracks.firstIndex(where: { $0.property == property }) {
                        keyframeTracks[existingIndex].values.append(track.values[0])
                    } else {
                        keyframeTracks.append(track)
                    }
                } else {
                    hasUnsupportedProperties = true
                }
            }
        }

        let tier: ConversionTier = hasUnsupportedProperties ? .adapted : .direct

        return KeyframeMappingResult(
            tracks: keyframeTracks,
            duration: animation.duration,
            repeatCount: animation.iterationCount,
            tier: tier,
            explanation: hasUnsupportedProperties
                ? "Some @keyframes properties have no SwiftUI equivalent. " +
                  "Partial animation converted."
                : "@keyframes animation maps to KeyframeAnimator"
        )
    }

    // MARK: - Framer Motion → SwiftUI

    /// Maps Framer Motion animate prop to SwiftUI state-driven animation.
    public static func framerMotionMapping(
        animate: [String: String],
        initial: [String: String]?,
        transition: [String: String]?
    ) -> FramerMotionMappingResult {
        var stateProperties: [StateAnimationProperty] = []
        var modifiers: [String] = []

        for (property, value) in animate {
            switch property.lowercased() {
            case "x":
                stateProperties.append(StateAnimationProperty(
                    name: "offsetX",
                    type: "CGFloat",
                    initialValue: initial?["x"] ?? "0",
                    animatedValue: value
                ))
                modifiers.append(".offset(x: offsetX)")

            case "y":
                stateProperties.append(StateAnimationProperty(
                    name: "offsetY",
                    type: "CGFloat",
                    initialValue: initial?["y"] ?? "0",
                    animatedValue: value
                ))
                modifiers.append(".offset(y: offsetY)")

            case "scale", "scalex", "scaley":
                let name = property.lowercased() == "scale" ? "scale" : property
                stateProperties.append(StateAnimationProperty(
                    name: name,
                    type: "CGFloat",
                    initialValue: initial?[property] ?? "1",
                    animatedValue: value
                ))
                modifiers.append(".scaleEffect(\(name))")

            case "rotate", "rotation":
                stateProperties.append(StateAnimationProperty(
                    name: "rotation",
                    type: "Double",
                    initialValue: initial?[property] ?? "0",
                    animatedValue: value
                ))
                modifiers.append(".rotationEffect(.degrees(rotation))")

            case "opacity":
                stateProperties.append(StateAnimationProperty(
                    name: "opacity",
                    type: "Double",
                    initialValue: initial?["opacity"] ?? "1",
                    animatedValue: value
                ))
                modifiers.append(".opacity(opacity)")

            default:
                break
            }
        }

        let animationType = parseFramerTransition(transition)

        return FramerMotionMappingResult(
            stateProperties: stateProperties,
            modifiers: modifiers,
            animation: animationType,
            tier: .adapted,
            explanation: "Framer Motion animate maps to @State properties with .animation modifier. " +
                        "Trigger animation in .onAppear or on state change."
        )
    }

    // MARK: - Helper Functions

    private static func mapCSSPropertyToAnimatable(_ property: String) -> AnimatableProperty? {
        let mapping: [String: AnimatableProperty] = [
            "opacity": AnimatableProperty(cssProperty: "opacity", swiftUIModifier: ".opacity", stateVariable: "opacity", type: "Double"),
            "transform": AnimatableProperty(cssProperty: "transform", swiftUIModifier: ".offset/.scaleEffect/.rotationEffect", stateVariable: "transform", type: "CGAffineTransform"),
            "background-color": AnimatableProperty(cssProperty: "background-color", swiftUIModifier: ".background", stateVariable: "backgroundColor", type: "Color"),
            "color": AnimatableProperty(cssProperty: "color", swiftUIModifier: ".foregroundStyle", stateVariable: "foregroundColor", type: "Color"),
            "width": AnimatableProperty(cssProperty: "width", swiftUIModifier: ".frame(width:)", stateVariable: "width", type: "CGFloat"),
            "height": AnimatableProperty(cssProperty: "height", swiftUIModifier: ".frame(height:)", stateVariable: "height", type: "CGFloat"),
            "border-radius": AnimatableProperty(cssProperty: "border-radius", swiftUIModifier: ".clipShape", stateVariable: "cornerRadius", type: "CGFloat"),
            "padding": AnimatableProperty(cssProperty: "padding", swiftUIModifier: ".padding", stateVariable: "padding", type: "CGFloat"),
            "margin": AnimatableProperty(cssProperty: "margin", swiftUIModifier: ".padding (on parent)", stateVariable: "margin", type: "CGFloat"),
            "box-shadow": AnimatableProperty(cssProperty: "box-shadow", swiftUIModifier: ".shadow", stateVariable: "shadowRadius", type: "CGFloat"),
        ]

        return mapping[property.lowercased()]
    }

    private static func mapKeyframeProperty(
        property: String,
        value: String,
        at percentage: Double
    ) -> KeyframeTrack? {
        guard let animatable = mapCSSPropertyToAnimatable(property) else { return nil }

        return KeyframeTrack(
            property: property,
            values: [KeyframeValue(percentage: percentage, value: value)]
        )
    }

    private static func parseFramerTransition(_ transition: [String: String]?) -> String {
        guard let t = transition else { return ".spring()" }

        if let type = t["type"] {
            switch type.lowercased() {
            case "spring":
                let stiffness = t["stiffness"] ?? "100"
                let damping = t["damping"] ?? "10"
                return ".spring(response: 0.5, dampingFraction: \(Double(damping) ?? 10 / 100))"
            case "tween":
                let duration = t["duration"] ?? "0.3"
                let ease = t["ease"] ?? "easeInOut"
                return ".\(ease)(duration: \(duration))"
            case "inertia":
                return ".interactiveSpring()"
            default:
                return ".default"
            }
        }

        if let duration = t["duration"] {
            return ".easeInOut(duration: \(duration))"
        }

        return ".spring()"
    }
}

// MARK: - Mapping Result Types

public struct HookMappingResult: Sendable {
    public let propertyWrapper: SwiftUIPropertyWrapper?
    public let lifecycleModifier: SwiftUIModifier?
    public let additionalModifiers: [SwiftUIModifier]
    public let additionalImports: [String]
    public let tier: ConversionTier
    public let explanation: String

    public init(
        propertyWrapper: SwiftUIPropertyWrapper?,
        lifecycleModifier: SwiftUIModifier? = nil,
        additionalModifiers: [SwiftUIModifier] = [],
        additionalImports: [String] = [],
        tier: ConversionTier,
        explanation: String
    ) {
        self.propertyWrapper = propertyWrapper
        self.lifecycleModifier = lifecycleModifier
        self.additionalModifiers = additionalModifiers
        self.additionalImports = additionalImports
        self.tier = tier
        self.explanation = explanation
    }
}

public struct EffectAnalysisResult: Sendable {
    public let modifiers: [SwiftUIModifier]
    public let pattern: EffectPattern
    public let tier: ConversionTier
    public let explanation: String
}

public enum EffectPattern: Sendable, Equatable {
    case mountOnly
    case singleDependency(String)
    case multipleDependencies([String])
    case everyRender
}

public struct PropsMappingResult: Sendable {
    public let parameters: [SwiftUIParameter]
    public let propertyWrappers: [PropertyWrapperUsage]
    public let tier: ConversionTier
    public let explanation: String
}

public struct SwiftUIParameter: Sendable {
    public let name: String
    public let type: String
    public let defaultValue: String?
    public let isOptional: Bool
    public let isViewBuilder: Bool

    public init(
        name: String,
        type: String,
        defaultValue: String?,
        isOptional: Bool,
        isViewBuilder: Bool = false
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.isOptional = isOptional
        self.isViewBuilder = isViewBuilder
    }
}

public struct PropertyWrapperUsage: Sendable {
    public let wrapper: SwiftUIPropertyWrapper
    public let variableName: String
    public let type: String
}

public enum ConditionalPattern: Sendable {
    case ternary(condition: String)
    case logicalAnd(condition: String)
    case logicalOr(condition: String)
    case nullishCoalescing(value: String, fallback: String)
    case switchStatement(expression: String, cases: [String])
}

public struct ConditionalMappingResult: Sendable {
    public let swiftPattern: String
    public let tier: ConversionTier
    public let explanation: String
}

public struct ListMappingResult: Sendable {
    public let swiftCode: String
    public let idKeyPath: String
    public let requiresIdentifiable: Bool
    public let tier: ConversionTier
    public let explanation: String
}

public struct AnimationCurveMappingResult: Sendable {
    public let animation: String
    public let tier: ConversionTier
    public let explanation: String
}

public struct TransitionMappingResult: Sendable {
    public let modifier: String?
    public let animatableProperty: AnimatableProperty?
    public let tier: ConversionTier
    public let explanation: String
}

public struct AnimatableProperty: Sendable {
    public let cssProperty: String
    public let swiftUIModifier: String
    public let stateVariable: String
    public let type: String
}

public struct KeyframeMappingResult: Sendable {
    public let tracks: [KeyframeTrack]
    public let duration: Double
    public let repeatCount: CSSAnimationIterationCount
    public let tier: ConversionTier
    public let explanation: String
}

public struct KeyframeTrack: Sendable {
    public let property: String
    public var values: [KeyframeValue]
}

public struct KeyframeValue: Sendable {
    public let percentage: Double
    public let value: String
}

public struct FramerMotionMappingResult: Sendable {
    public let stateProperties: [StateAnimationProperty]
    public let modifiers: [String]
    public let animation: String
    public let tier: ConversionTier
    public let explanation: String
}

public struct StateAnimationProperty: Sendable {
    public let name: String
    public let type: String
    public let initialValue: String
    public let animatedValue: String
}
