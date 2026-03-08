import Foundation

// MARK: - React Code Generator

/// Generates React JSX/TSX code from Intermediate Representation.
/// Mirrors SwiftSyntaxCodeGenerator but outputs React instead of SwiftUI.
public final class ReactCodeGenerator {

    public enum OutputFormat: Sendable {
        case jsx
        case tsx
    }

    public struct Options: Sendable {
        public let format: OutputFormat
        public let useTypeScript: Bool
        public let useTailwind: Bool
        public let useStyledComponents: Bool
        public let indentSize: Int
        public let componentStyle: ComponentStyle

        public enum ComponentStyle: Sendable {
            case functional       // const Component = () => {}
            case arrowFunction    // const Component: FC = () => {}
            case exportDefault    // export default function Component() {}
        }

        public init(
            format: OutputFormat = .tsx,
            useTypeScript: Bool = true,
            useTailwind: Bool = true,
            useStyledComponents: Bool = false,
            indentSize: Int = 2,
            componentStyle: ComponentStyle = .functional
        ) {
            self.format = format
            self.useTypeScript = useTypeScript
            self.useTailwind = useTailwind
            self.useStyledComponents = useStyledComponents
            self.indentSize = indentSize
            self.componentStyle = componentStyle
        }

        public static let `default` = Options()
    }

    private let options: Options
    private var indentLevel = 0

    public init(options: Options = .default) {
        self.options = options
    }

    // MARK: - Main Generation

    /// Generates React code files from an IR.
    public func generate(from ir: IntermediateRepresentation) -> [GeneratedReactFile] {
        var files: [GeneratedReactFile] = []

        for sourceFile in ir.sourceFiles {
            for component in sourceFile.components {
                let code = generateComponent(component)
                let ext = options.format == .tsx ? "tsx" : "jsx"
                let filename = "\(component.name).\(ext)"

                files.append(GeneratedReactFile(
                    path: filename,
                    content: code
                ))
            }
        }

        // Generate index file
        if !files.isEmpty {
            let indexContent = generateIndexFile(from: ir)
            let ext = options.format == .tsx ? "ts" : "js"
            files.append(GeneratedReactFile(path: "index.\(ext)", content: indexContent))
        }

        return files
    }

    /// Generates a single React component.
    public func generateComponent(_ component: ComponentIR) -> String {
        var output = ""

        // Imports
        output += generateImports(for: component)
        output += "\n"

        // Props interface (TypeScript)
        if options.useTypeScript {
            output += generatePropsInterface(for: component)
            output += "\n"
        }

        // Component
        output += generateComponentFunction(component)

        return output
    }

    // MARK: - Imports

    private func generateImports(for component: ComponentIR) -> String {
        var imports: [String] = []

        imports.append("import React from 'react';")

        if options.useTypeScript {
            imports.append("import type { FC } from 'react';")
        }

        if options.useStyledComponents {
            imports.append("import styled from 'styled-components';")
        }

        return imports.joined(separator: "\n")
    }

    // MARK: - Props Interface

    private func generatePropsInterface(for component: ComponentIR) -> String {
        var output = "interface \(component.name)Props {\n"

        for param in component.parameters {
            let tsType = swiftTypeToTypeScript(param.type)
            let optional = param.isOptional ? "?" : ""
            output += "  \(param.name)\(optional): \(tsType);\n"
        }

        // Add children prop for containers
        if hasChildren(component.viewHierarchy) {
            output += "  children?: React.ReactNode;\n"
        }

        output += "}\n"
        return output
    }

    // MARK: - Component Function

    private func generateComponentFunction(_ component: ComponentIR) -> String {
        let propsType = options.useTypeScript ? ": \(component.name)Props" : ""
        let returnType = options.useTypeScript ? ": JSX.Element" : ""

        var output = ""

        switch options.componentStyle {
        case .functional:
            output += "export const \(component.name) = ({ "
            output += component.parameters.map(\.name).joined(separator: ", ")
            output += " }\(propsType))\(returnType) => {\n"

        case .arrowFunction:
            output += "export const \(component.name): FC<\(component.name)Props> = ({ "
            output += component.parameters.map(\.name).joined(separator: ", ")
            output += " }) => {\n"

        case .exportDefault:
            output += "export default function \(component.name)({ "
            output += component.parameters.map(\.name).joined(separator: ", ")
            output += " }\(propsType))\(returnType) {\n"
        }

        indentLevel += 1

        // State declarations
        for state in component.stateProperties {
            output += indent() + generateStateDeclaration(state) + "\n"
        }

        if !component.stateProperties.isEmpty {
            output += "\n"
        }

        // Effects
        for effect in component.effects {
            output += indent() + generateEffect(effect) + "\n"
        }

        if !component.effects.isEmpty {
            output += "\n"
        }

        // Return statement
        output += indent() + "return (\n"
        indentLevel += 1
        output += generateJSX(from: component.viewHierarchy)
        indentLevel -= 1
        output += indent() + ");\n"

        indentLevel -= 1
        output += "};\n"

        return output
    }

    // MARK: - State Declaration

    private func generateStateDeclaration(_ state: StatePropertyIR) -> String {
        let tsType = options.useTypeScript ? "<\(swiftTypeToTypeScript(state.type))>" : ""
        return "const [\(state.name), set\(state.name.capitalized)] = useState\(tsType)(\(state.initialValue));"
    }

    // MARK: - Effect Generation

    private func generateEffect(_ effect: EffectIR) -> String {
        var output = "useEffect(() => {\n"
        indentLevel += 1
        output += indent() + effect.body + "\n"

        if effect.hasCleanup, let cleanup = effect.cleanupBody {
            output += indent() + "return () => {\n"
            indentLevel += 1
            output += indent() + cleanup + "\n"
            indentLevel -= 1
            output += indent() + "};\n"
        }

        indentLevel -= 1
        output += indent() + "}, [\(effect.dependencies.joined(separator: ", "))]);"

        return output
    }

    // MARK: - JSX Generation

    private func generateJSX(from node: ViewNodeIR) -> String {
        switch node {
        case .view(let viewIR):
            return generateViewJSX(viewIR)
        case .text(let textIR):
            return generateTextJSX(textIR)
        case .conditional(let conditionalIR):
            return generateConditionalJSX(conditionalIR)
        case .loop(let loopIR):
            return generateLoopJSX(loopIR)
        case .group(let children):
            return generateGroupJSX(children)
        case .empty:
            return indent() + "{null}\n"
        case .unsupported(let unsupported):
            return indent() + "{/* Unsupported: \(unsupported.reason) */}\n"
        }
    }

    private func generateViewJSX(_ view: ViewIR) -> String {
        let tag = swiftUIViewToReact(view.viewType)
        let className = generateClassName(from: view.modifiers)
        let style = generateInlineStyle(from: view.modifiers)

        var output = indent() + "<\(tag)"

        if options.useTailwind && !className.isEmpty {
            output += " className=\"\(className)\""
        }

        if !options.useTailwind && !style.isEmpty {
            output += " style={{ \(style) }}"
        }

        // Add props from init arguments
        for arg in view.initArguments {
            if let label = arg.label {
                output += " \(label)={\(valueToJSX(arg.value))}"
            }
        }

        if view.children.isEmpty {
            output += " />\n"
        } else {
            output += ">\n"
            indentLevel += 1
            for child in view.children {
                output += generateJSX(from: child)
            }
            indentLevel -= 1
            output += indent() + "</\(tag)>\n"
        }

        return output
    }

    private func generateTextJSX(_ text: TextIR) -> String {
        let content = textContentToString(text.content)
        let className = generateClassName(from: text.modifiers)
        let style = generateInlineStyle(from: text.modifiers)

        var output = indent() + "<span"

        if options.useTailwind && !className.isEmpty {
            output += " className=\"\(className)\""
        }

        if !options.useTailwind && !style.isEmpty {
            output += " style={{ \(style) }}"
        }

        output += ">\(content)</span>\n"
        return output
    }

    private func generateConditionalJSX(_ conditional: ConditionalIR) -> String {
        var output = indent() + "{\(conditional.condition) ? (\n"
        indentLevel += 1
        output += generateJSX(from: conditional.trueBranch)
        indentLevel -= 1
        output += indent() + ") : (\n"
        indentLevel += 1
        if let falseBranch = conditional.falseBranch {
            output += generateJSX(from: falseBranch)
        } else {
            output += indent() + "null\n"
        }
        indentLevel -= 1
        output += indent() + ")}\n"
        return output
    }

    private func generateLoopJSX(_ loop: LoopIR) -> String {
        var output = indent() + "{\(loop.arrayExpression).map((\(loop.itemVariable)) => (\n"
        indentLevel += 1
        output += generateJSX(from: loop.body)
        indentLevel -= 1
        output += indent() + "))}\n"
        return output
    }

    private func generateGroupJSX(_ children: [ViewNodeIR]) -> String {
        var output = indent() + "<>\n"
        indentLevel += 1
        for child in children {
            output += generateJSX(from: child)
        }
        indentLevel -= 1
        output += indent() + "</>\n"
        return output
    }

    // MARK: - Style Generation

    private func generateClassName(from modifiers: [ModifierIR]) -> String {
        var classes: [String] = []

        for modifier in modifiers {
            switch modifier.modifier {
            case .frame:
                if let width = modifier.arguments.first(where: { $0.label == "width" }),
                   case .literal(let w) = width.value {
                    classes.append("w-[\(w)px]")
                }
                if let height = modifier.arguments.first(where: { $0.label == "height" }),
                   case .literal(let h) = height.value {
                    classes.append("h-[\(h)px]")
                }

            case .padding:
                classes.append("p-4")

            case .background:
                if let bg = modifier.arguments.first,
                   case .literal(let color) = bg.value {
                    classes.append(colorToTailwind(color, prefix: "bg"))
                }

            case .cornerRadius:
                if let radius = modifier.arguments.first,
                   case .literal(let r) = radius.value {
                    classes.append("rounded-[\(r)px]")
                }

            case .shadow:
                classes.append("shadow-lg")

            case .opacity:
                if let op = modifier.arguments.first,
                   case .literal(let o) = op.value,
                   let opacity = Double(o) {
                    classes.append("opacity-\(Int(opacity * 100))")
                }

            default:
                break
            }
        }

        return classes.joined(separator: " ")
    }

    private func generateInlineStyle(from modifiers: [ModifierIR]) -> String {
        var styles: [String] = []

        for modifier in modifiers {
            switch modifier.modifier {
            case .frame:
                if let width = modifier.arguments.first(where: { $0.label == "width" }),
                   case .literal(let w) = width.value {
                    styles.append("width: \(w)")
                }
                if let height = modifier.arguments.first(where: { $0.label == "height" }),
                   case .literal(let h) = height.value {
                    styles.append("height: \(h)")
                }

            case .padding:
                styles.append("padding: 16px")

            case .background:
                if let bg = modifier.arguments.first,
                   case .literal(let color) = bg.value {
                    styles.append("backgroundColor: '\(colorToCSSHex(color))'")
                }

            case .cornerRadius:
                if let radius = modifier.arguments.first,
                   case .literal(let r) = radius.value {
                    styles.append("borderRadius: \(r)")
                }

            default:
                break
            }
        }

        return styles.joined(separator: ", ")
    }

    // MARK: - Index File

    private func generateIndexFile(from ir: IntermediateRepresentation) -> String {
        var exports: [String] = []

        for sourceFile in ir.sourceFiles {
            for component in sourceFile.components {
                exports.append("export { \(component.name) } from './\(component.name)';")
            }
        }

        return exports.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func indent() -> String {
        String(repeating: " ", count: indentLevel * options.indentSize)
    }

    private func swiftTypeToTypeScript(_ swiftType: String) -> String {
        switch swiftType.lowercased() {
        case "string": return "string"
        case "int", "double", "float", "cgfloat": return "number"
        case "bool": return "boolean"
        case "void", "()": return "void"
        case _ where swiftType.hasPrefix("["): return "any[]"
        case _ where swiftType.hasPrefix("Optional<"):
            let inner = swiftType.dropFirst(9).dropLast()
            return "\(swiftTypeToTypeScript(String(inner))) | undefined"
        default: return "any"
        }
    }

    private func swiftUIViewToReact(_ viewType: SwiftUIViewType) -> String {
        switch viewType {
        case .hStack: return "div"
        case .vStack: return "div"
        case .zStack: return "div"
        case .text: return "span"
        case .button: return "button"
        case .image: return "img"
        case .rectangle, .roundedRectangle: return "div"
        case .circle: return "div"
        case .spacer: return "div"
        case .divider: return "hr"
        case .scrollView: return "div"
        case .list: return "ul"
        case .navigationStack, .navigationSplitView: return "nav"
        case .tabView: return "div"
        case .toggle: return "input"
        case .slider: return "input"
        case .textField: return "input"
        case .textEditor: return "textarea"
        case .picker: return "select"
        case .stepper: return "input"
        case .datePicker: return "input"
        case .colorPicker: return "input"
        case .progressView: return "progress"
        case .label: return "label"
        case .link: return "a"
        case .menu: return "div"
        default: return "div"
        }
    }

    private func valueToJSX(_ value: ValueIR) -> String {
        switch value {
        case .literal(let str):
            // Remove Swift-specific formatting
            var cleaned = str
            cleaned = cleaned.replacingOccurrences(of: "\"", with: "'")
            return cleaned
        case .binding(let name):
            return name
        case .expression(let expr):
            return expr
        case .closure(let body):
            return "() => { \(body) }"
        }
    }

    private func textContentToString(_ content: TextContentIR) -> String {
        switch content {
        case .literal(let str):
            return str
        case .interpolation(let expr):
            return "{\(expr)}"
        case .concatenation(let parts):
            return parts.map { textContentToString($0) }.joined()
        case .localizedKey(let key):
            return "{\(key)}"
        }
    }

    private func colorToTailwind(_ swiftColor: String, prefix: String) -> String {
        if swiftColor.contains("accentColor") {
            return "\(prefix)-blue-500"
        }
        if swiftColor.contains("black") {
            return "\(prefix)-black"
        }
        if swiftColor.contains("white") {
            return "\(prefix)-white"
        }
        return "\(prefix)-gray-500"
    }

    private func colorToCSSHex(_ swiftColor: String) -> String {
        if swiftColor.contains("accentColor") {
            return "#007AFF"
        }
        if swiftColor.contains("black") {
            return "#000000"
        }
        if swiftColor.contains("white") {
            return "#FFFFFF"
        }
        return "#888888"
    }

    private func toCamelCase(_ name: String) -> String {
        var result = name.prefix(1).lowercased() + name.dropFirst()
        result = result.replacingOccurrences(of: "View", with: "")
        return result
    }

    private func hasChildren(_ node: ViewNodeIR) -> Bool {
        switch node {
        case .view(let viewIR):
            return !viewIR.children.isEmpty
        case .group(let children):
            return !children.isEmpty
        default:
            return false
        }
    }
}

// MARK: - Generated React File

public struct GeneratedReactFile: Sendable {
    public let path: String
    public let content: String

    public init(path: String, content: String) {
        self.path = path
        self.content = content
    }
}
