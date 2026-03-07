import Foundation

// MARK: - React Parser

/// Parses React JSX/TSX AST and converts it to Intermediate Representation.
/// Uses the mapping dictionaries to determine SwiftUI equivalents.
public final class ReactParser: @unchecked Sendable {

    private let runtime: JavaScriptRuntime

    public enum ParserError: Error, LocalizedError {
        case parsingFailed(String)
        case invalidAST(String)
        case componentExtractionFailed(String)
        case unsupportedSyntax(String)

        public var errorDescription: String? {
            switch self {
            case .parsingFailed(let msg): return "Parsing failed: \(msg)"
            case .invalidAST(let msg): return "Invalid AST: \(msg)"
            case .componentExtractionFailed(let msg): return "Component extraction failed: \(msg)"
            case .unsupportedSyntax(let msg): return "Unsupported syntax: \(msg)"
            }
        }
    }

    public init(runtime: JavaScriptRuntime = .shared) {
        self.runtime = runtime
    }

    // MARK: - Public API

    /// Parses a single React file and returns parsed components.
    public func parseFile(
        source: String,
        filePath: String,
        isTypeScript: Bool = false
    ) throws -> ParsedSourceFile {
        let parseResult = try runtime.parseJSX(source, isTypeScript: isTypeScript)
        let extracted = try runtime.extractComponents(from: parseResult.ast)

        var components: [ParsedReactComponent] = []

        for compDict in extracted.components {
            let component = try parseComponent(compDict, filePath: filePath)
            components.append(component)
        }

        let imports = parseImports(extracted.imports)
        let exports = parseExports(extracted.exports)

        return ParsedSourceFile(
            path: filePath,
            components: components,
            imports: imports,
            exports: exports
        )
    }

    /// Converts a ParsedSourceFile to IR.
    public func convertToIR(
        parsedFile: ParsedSourceFile,
        cssStyles: [String: ComputedCSSStyle] = [:]
    ) throws -> SourceFileIR {
        var componentIRs: [ComponentIR] = []

        for component in parsedFile.components {
            let ir = try convertComponentToIR(component, cssStyles: cssStyles)
            componentIRs.append(ir)
        }

        let importIRs = parsedFile.imports.map { imp in
            ImportIR(
                originalModule: imp.source,
                swiftImport: mapImportToSwift(imp.source),
                isRequired: false
            )
        }

        let exportIRs = parsedFile.exports.map { exp in
            ExportIR(
                name: exp.name,
                isDefault: exp.isDefault,
                accessLevel: "public"
            )
        }

        return SourceFileIR(
            originalPath: parsedFile.path,
            components: componentIRs,
            imports: importIRs,
            exports: exportIRs
        )
    }

    // MARK: - Component Parsing

    private func parseComponent(_ dict: [String: Any], filePath: String) throws -> ParsedReactComponent {
        guard let name = dict["name"] as? String else {
            throw ParserError.invalidAST("Component missing name")
        }

        let loc = parseSourceLocation(dict["loc"], filePath: filePath)
        let params = parseParams(dict["params"] as? [[String: Any]] ?? [])
        let body = dict["body"] as? [String: Any]

        var hooks: [ParsedHook] = []
        var children: [ParsedJSXElement] = []

        if let bodyDict = body {
            hooks = try extractHooks(from: bodyDict)
            children = try parseJSXBody(bodyDict, filePath: filePath)
        }

        return ParsedReactComponent(
            name: name,
            isClassComponent: false,
            props: params,
            hooks: hooks,
            children: children,
            sourceLocation: loc
        )
    }

    private func parseParams(_ params: [[String: Any]]) -> [ParsedProp] {
        var props: [ParsedProp] = []

        for param in params {
            let paramType = param["type"] as? String ?? "simple"

            if paramType == "destructured" {
                let properties = param["properties"] as? [[String: Any]] ?? []
                for prop in properties {
                    if let propName = prop["name"] as? String {
                        let defaultValue = prop["defaultValue"] as? String
                        props.append(ParsedProp(
                            name: propName,
                            type: nil,
                            defaultValue: defaultValue,
                            isRequired: defaultValue == nil,
                            isCallback: propName.hasPrefix("on")
                        ))
                    }
                }
            } else if let propName = param["name"] as? String {
                props.append(ParsedProp(
                    name: propName,
                    type: "props",
                    defaultValue: nil,
                    isRequired: true,
                    isCallback: false
                ))
            }
        }

        return props
    }

    private func extractHooks(from body: [String: Any]) throws -> [ParsedHook] {
        let hookArray = try runtime.extractHooks(from: body)
        var hooks: [ParsedHook] = []

        for hookDict in hookArray {
            if let hookName = hookDict["name"] as? String,
               let hookType = ReactHookType(rawValue: hookName) {

                var variableName: String?
                var setterName: String?
                var initialValue: String?
                var dependencies: [String]?

                if let args = hookDict["arguments"] as? [[String: Any]] {
                    if hookType == .useState && args.count >= 1 {
                        if let firstArg = args.first {
                            if let value = firstArg["value"] {
                                initialValue = "\(value)"
                            } else if let name = firstArg["name"] as? String {
                                initialValue = name
                            }
                        }
                    }

                    if (hookType == .useEffect || hookType == .useCallback || hookType == .useMemo) && args.count >= 2 {
                        if let depsArg = args.last, depsArg["type"] as? String == "array" {
                            if let elements = depsArg["elements"] as? [[String: Any]] {
                                dependencies = elements.compactMap { elem in
                                    if let name = elem["name"] as? String {
                                        return name
                                    }
                                    return nil
                                }
                            }
                        }
                    }
                }

                hooks.append(ParsedHook(
                    type: hookType,
                    variableName: variableName,
                    setterName: setterName,
                    initialValue: initialValue,
                    dependencies: dependencies,
                    effectBody: nil
                ))
            }
        }

        return hooks
    }

    private func parseJSXBody(_ body: [String: Any], filePath: String) throws -> [ParsedJSXElement] {
        guard let structured = try? runtime.jsxToStructure(body) else {
            return []
        }

        var elements: [ParsedJSXElement] = []

        if let element = try? parseJSXStructure(structured, filePath: filePath) {
            elements.append(element)
        }

        return elements
    }

    private func parseJSXStructure(_ structure: [String: Any], filePath: String) throws -> ParsedJSXElement {
        let type = structure["type"] as? String ?? ""
        let loc = parseSourceLocation(structure["loc"], filePath: filePath)

        switch type {
        case "element":
            let name = structure["name"] as? String ?? "div"
            let elementType = parseElementType(name)
            let attributes = parseJSXAttributes(structure["attributes"] as? [[String: Any]] ?? [])
            let children = try parseJSXChildren(structure["children"] as? [[String: Any]] ?? [], filePath: filePath)

            return ParsedJSXElement(
                elementType: elementType,
                attributes: attributes,
                children: children,
                computedStyle: ComputedCSSStyle(),
                sourceLocation: loc
            )

        case "fragment":
            let children = try parseJSXChildren(structure["children"] as? [[String: Any]] ?? [], filePath: filePath)
            return ParsedJSXElement(
                elementType: .fragment,
                attributes: [],
                children: children,
                computedStyle: ComputedCSSStyle(),
                sourceLocation: loc
            )

        case "conditional":
            let condition = structure["test"] as? String ?? "condition"
            let consequent = structure["consequent"] as? [String: Any]
            let alternate = structure["alternate"] as? [String: Any]

            var consequentElement: ParsedJSXElement?
            var alternateElement: ParsedJSXElement?

            if let consDict = consequent {
                consequentElement = try? parseJSXStructure(consDict, filePath: filePath)
            }
            if let altDict = alternate {
                alternateElement = try? parseJSXStructure(altDict, filePath: filePath)
            }

            return ParsedJSXElement(
                elementType: .html(.div),
                attributes: [],
                children: [.conditional(condition: condition, consequent: consequentElement, alternate: alternateElement)],
                computedStyle: ComputedCSSStyle(),
                sourceLocation: loc
            )

        case "logicalAnd":
            let condition = structure["condition"] as? String ?? "condition"
            let element = structure["element"] as? [String: Any]

            var childElement: ParsedJSXElement?
            if let elemDict = element {
                childElement = try? parseJSXStructure(elemDict, filePath: filePath)
            }

            return ParsedJSXElement(
                elementType: .html(.div),
                attributes: [],
                children: [.conditional(condition: condition, consequent: childElement, alternate: nil)],
                computedStyle: ComputedCSSStyle(),
                sourceLocation: loc
            )

        default:
            return ParsedJSXElement(
                elementType: .html(.div),
                attributes: [],
                children: [],
                computedStyle: ComputedCSSStyle(),
                sourceLocation: loc
            )
        }
    }

    private func parseElementType(_ name: String) -> JSXElementType {
        let lowercased = name.lowercased()

        if let htmlType = HTMLElementType(rawValue: lowercased) {
            return .html(htmlType)
        }

        if name.first?.isUppercase == true {
            return .reactComponent(name)
        }

        return .html(.div)
    }

    private func parseJSXAttributes(_ attrs: [[String: Any]]) -> [ParsedJSXAttribute] {
        var result: [ParsedJSXAttribute] = []

        for attr in attrs {
            let attrType = attr["type"] as? String ?? ""

            if attrType == "spread" {
                let argument = attr["argument"] as? String ?? "props"
                result.append(ParsedJSXAttribute(
                    name: "...",
                    value: .spreadProps(argument)
                ))
            } else if let name = attr["name"] as? String {
                let valueDict = attr["value"] as? [String: Any] ?? [:]
                let value = parseJSXAttributeValue(valueDict, attributeName: name)
                result.append(ParsedJSXAttribute(name: name, value: value))
            }
        }

        return result
    }

    private func parseJSXAttributeValue(_ valueDict: [String: Any], attributeName: String) -> JSXAttributeValue {
        let type = valueDict["type"] as? String ?? "true"

        switch type {
        case "true":
            return .boolean(true)
        case "string":
            return .string(valueDict["value"] as? String ?? "")
        case "expression":
            let expr = valueDict["expression"] as? String ?? ""
            if attributeName.hasPrefix("on") {
                return .eventHandler(expr)
            }
            return .expression(expr)
        default:
            return .null
        }
    }

    private func parseJSXChildren(_ children: [[String: Any]], filePath: String) throws -> [ParsedJSXChild] {
        var result: [ParsedJSXChild] = []

        for child in children {
            let type = child["type"] as? String ?? ""

            switch type {
            case "element", "fragment":
                if let element = try? parseJSXStructure(child, filePath: filePath) {
                    result.append(.element(element))
                }

            case "text":
                if let text = child["value"] as? String, !text.isEmpty {
                    result.append(.text(text))
                }

            case "expression":
                let expr = child["expression"] as? String ?? ""
                let exprType = child["expressionType"] as? String ?? ""

                if exprType == "CallExpression" && expr.contains(".map") {
                    result.append(.expression(expr))
                } else {
                    result.append(.expression(expr))
                }

            case "conditional":
                let test = child["test"] as? String ?? "condition"
                let consequent = child["consequent"] as? [String: Any]
                let alternate = child["alternate"] as? [String: Any]

                var consequentElement: ParsedJSXElement?
                var alternateElement: ParsedJSXElement?

                if let consDict = consequent {
                    consequentElement = try? parseJSXStructure(consDict, filePath: filePath)
                }
                if let altDict = alternate {
                    alternateElement = try? parseJSXStructure(altDict, filePath: filePath)
                }

                result.append(.conditional(
                    condition: test,
                    consequent: consequentElement,
                    alternate: alternateElement
                ))

            case "logicalAnd":
                let condition = child["condition"] as? String ?? "condition"
                let element = child["element"] as? [String: Any]

                var childElement: ParsedJSXElement?
                if let elemDict = element {
                    childElement = try? parseJSXStructure(elemDict, filePath: filePath)
                }

                result.append(.conditional(
                    condition: condition,
                    consequent: childElement,
                    alternate: nil
                ))

            default:
                break
            }
        }

        return result
    }

    // MARK: - Import/Export Parsing

    private func parseImports(_ imports: [[String: Any]]) -> [ParsedImport] {
        return imports.compactMap { imp in
            guard let source = imp["source"] as? String else { return nil }
            let specifiers = imp["specifiers"] as? [[String: Any]] ?? []

            var importedNames: [String] = []
            var defaultImport: String?

            for spec in specifiers {
                let specType = spec["type"] as? String ?? ""
                let localName = spec["local"] as? String

                if specType == "ImportDefaultSpecifier" {
                    defaultImport = localName
                } else if let name = localName {
                    importedNames.append(name)
                }
            }

            return ParsedImport(
                source: source,
                importedNames: importedNames,
                defaultImport: defaultImport
            )
        }
    }

    private func parseExports(_ exports: [[String: Any]]) -> [ParsedExport] {
        return exports.compactMap { exp in
            guard let name = exp["name"] as? String else { return nil }
            let isDefault = exp["isDefault"] as? Bool ?? false
            return ParsedExport(name: name, isDefault: isDefault)
        }
    }

    // MARK: - IR Conversion

    private func convertComponentToIR(
        _ component: ParsedReactComponent,
        cssStyles: [String: ComputedCSSStyle]
    ) throws -> ComponentIR {
        let parameters = component.props.map { prop in
            ParameterIR(
                name: prop.name,
                type: inferSwiftType(for: prop),
                defaultValue: prop.defaultValue,
                isBinding: prop.isCallback,
                isViewBuilder: false,
                isOptional: !prop.isRequired,
                documentation: nil
            )
        }

        let stateProperties = component.hooks.compactMap { hook -> StatePropertyIR? in
            let mapping = StateMapping.propertyWrapper(for: hook.type)
            guard let wrapper = mapping.propertyWrapper else { return nil }

            return StatePropertyIR(
                name: hook.variableName ?? "value",
                type: "Any",
                initialValue: hook.initialValue ?? "nil",
                wrapper: wrapper,
                isPrivate: true
            )
        }

        let effects = component.hooks.compactMap { hook -> EffectIR? in
            guard hook.type == .useEffect || hook.type == .useLayoutEffect else { return nil }

            let analysis = StateMapping.analyzeEffect(
                dependencies: hook.dependencies,
                hasCleanup: false
            )

            let effectModifier = analysis.modifiers.first ?? .onAppear

            return EffectIR(
                modifier: effectModifier,
                dependencies: hook.dependencies ?? [],
                body: hook.effectBody ?? "// Effect body",
                hasCleanup: false,
                cleanupBody: nil
            )
        }

        let viewHierarchy: ViewNodeIR
        if component.children.isEmpty {
            viewHierarchy = .empty
        } else if component.children.count == 1 {
            viewHierarchy = try convertJSXElementToIR(component.children[0], cssStyles: cssStyles)
        } else {
            let childNodes = try component.children.map { try convertJSXElementToIR($0, cssStyles: cssStyles) }
            viewHierarchy = .group(childNodes)
        }

        return ComponentIR(
            name: component.name,
            isDefault: false,
            sourceLocation: component.sourceLocation,
            parameters: parameters,
            stateProperties: stateProperties,
            effects: effects,
            viewHierarchy: viewHierarchy,
            genericParameters: []
        )
    }

    private func convertJSXElementToIR(
        _ element: ParsedJSXElement,
        cssStyles: [String: ComputedCSSStyle]
    ) throws -> ViewNodeIR {
        switch element.elementType {
        case .html(let htmlType):
            let inputType = extractInputType(from: element.attributes)
            let mapping = ComponentMapping.viewType(
                for: htmlType,
                inputType: inputType,
                computedStyle: element.computedStyle
            )

            if mapping.tier == .unsupported {
                return .unsupported(UnsupportedIR(
                    originalCode: "<\(htmlType.rawValue)>",
                    reason: "No SwiftUI equivalent",
                    suggestedApproach: "Use a custom view",
                    sourceLocation: element.sourceLocation
                ))
            }

            let modifiers = try buildModifiers(from: element)
            let children = try convertChildren(element.children, cssStyles: cssStyles)

            let view = ViewIR(
                viewType: mapping.viewType,
                initArguments: buildInitArguments(for: mapping.viewType, from: element),
                modifiers: modifiers,
                children: children,
                sourceLocation: element.sourceLocation,
                conversionTier: mapping.tier
            )

            return .view(view)

        case .reactComponent(_):
            let view = ViewIR(
                viewType: .group,
                initArguments: buildCustomComponentArguments(from: element),
                modifiers: try buildModifiers(from: element),
                children: try convertChildren(element.children, cssStyles: cssStyles),
                sourceLocation: element.sourceLocation,
                conversionTier: .direct
            )
            return .view(view)

        case .fragment:
            let children = try convertChildren(element.children, cssStyles: cssStyles)
            return .group(children)
        }
    }

    private func convertChildren(
        _ children: [ParsedJSXChild],
        cssStyles: [String: ComputedCSSStyle]
    ) throws -> [ViewNodeIR] {
        var result: [ViewNodeIR] = []

        for child in children {
            switch child {
            case .element(let element):
                result.append(try convertJSXElementToIR(element, cssStyles: cssStyles))

            case .text(let text):
                result.append(.text(TextIR(
                    content: .literal(text),
                    modifiers: [],
                    sourceLocation: SourceLocation(filePath: "", startLine: 0, startColumn: 0, endLine: 0, endColumn: 0)
                )))

            case .expression(let expr):
                result.append(.text(TextIR(
                    content: .interpolation(expr),
                    modifiers: [],
                    sourceLocation: SourceLocation(filePath: "", startLine: 0, startColumn: 0, endLine: 0, endColumn: 0)
                )))

            case .conditional(let condition, let consequent, let alternate):
                let trueNode: ViewNodeIR = consequent.flatMap { try? convertJSXElementToIR($0, cssStyles: cssStyles) } ?? .empty
                let falseNode: ViewNodeIR? = alternate.flatMap { try? convertJSXElementToIR($0, cssStyles: cssStyles) }

                result.append(.conditional(ConditionalIR(
                    condition: condition,
                    trueBranch: trueNode,
                    falseBranch: falseNode
                )))

            case .map(let iterator, let array, let body):
                let bodyNode = try convertJSXElementToIR(body, cssStyles: cssStyles)
                result.append(.loop(LoopIR(
                    arrayExpression: array,
                    itemVariable: iterator,
                    idKeyPath: "\\.self",
                    body: bodyNode
                )))
            }
        }

        return result
    }

    // MARK: - Helper Methods

    private func parseSourceLocation(_ loc: Any?, filePath: String) -> SourceLocation {
        guard let locDict = loc as? [String: Any],
              let start = locDict["start"] as? [String: Any],
              let end = locDict["end"] as? [String: Any] else {
            return SourceLocation(filePath: filePath, startLine: 1, startColumn: 1, endLine: 1, endColumn: 1)
        }

        return SourceLocation(
            filePath: filePath,
            startLine: start["line"] as? Int ?? 1,
            startColumn: start["column"] as? Int ?? 1,
            endLine: end["line"] as? Int ?? 1,
            endColumn: end["column"] as? Int ?? 1
        )
    }

    private func inferSwiftType(for prop: ParsedProp) -> String {
        if prop.isCallback { return "(() -> Void)" }
        if let type = prop.type {
            switch type {
            case "string": return "String"
            case "number": return "Double"
            case "boolean": return "Bool"
            case "array": return "[Any]"
            case "object": return "[String: Any]"
            default: return "Any"
            }
        }
        return "Any"
    }

    private func extractInputType(from attributes: [ParsedJSXAttribute]) -> HTMLInputType? {
        for attr in attributes {
            if attr.name == "type" {
                switch attr.value {
                case .string(let value):
                    return HTMLInputType(rawValue: value)
                default:
                    break
                }
            }
        }
        return nil
    }

    private func buildModifiers(from element: ParsedJSXElement) throws -> [ModifierIR] {
        var modifiers: [ModifierIR] = []

        for attr in element.attributes {
            if let eventType = ReactEventType(rawValue: attr.name) {
                let mapping = ComponentMapping.eventMapping(eventType)
                if let modifier = mapping.modifier {
                    switch attr.value {
                    case .eventHandler(let handler):
                        modifiers.append(ModifierIR(
                            modifier: modifier,
                            arguments: [],
                            rawCode: "{ \(handler) }"
                        ))
                    default:
                        break
                    }
                }
            }
        }

        return modifiers
    }

    private func buildInitArguments(for viewType: SwiftUIViewType, from element: ParsedJSXElement) -> [InitArgumentIR] {
        var args: [InitArgumentIR] = []

        switch viewType {
        case .image, .asyncImage:
            if let src = element.attributes.first(where: { $0.name == "src" }) {
                switch src.value {
                case .string(let url):
                    args.append(InitArgumentIR(label: nil, value: .literal("\"\(url)\"")))
                case .expression(let expr):
                    args.append(InitArgumentIR(label: nil, value: .expression(expr)))
                default:
                    break
                }
            }

        case .link:
            if let href = element.attributes.first(where: { $0.name == "href" }) {
                switch href.value {
                case .string(let url):
                    args.append(InitArgumentIR(label: "destination", value: .literal("URL(string: \"\(url)\")!")))
                case .expression(let expr):
                    args.append(InitArgumentIR(label: "destination", value: .expression(expr)))
                default:
                    break
                }
            }

        case .button:
            if let onClick = element.attributes.first(where: { $0.name == "onClick" }) {
                switch onClick.value {
                case .eventHandler(let handler):
                    args.append(InitArgumentIR(label: "action", value: .closure(handler)))
                default:
                    break
                }
            }

        default:
            break
        }

        return args
    }

    private func buildCustomComponentArguments(from element: ParsedJSXElement) -> [InitArgumentIR] {
        var args: [InitArgumentIR] = []

        for attr in element.attributes {
            guard attr.name != "key" && attr.name != "ref" else { continue }

            let value: ValueIR
            switch attr.value {
            case .string(let str):
                value = .literal("\"\(str)\"")
            case .number(let num):
                value = .literal(String(num))
            case .boolean(let bool):
                value = .literal(String(bool))
            case .expression(let expr):
                value = .expression(expr)
            case .eventHandler(let handler):
                value = .closure(handler)
            case .spreadProps, .null:
                continue
            }

            args.append(InitArgumentIR(label: attr.name, value: value))
        }

        return args
    }

    private func mapImportToSwift(_ source: String) -> String? {
        let mappings: [String: String] = [
            "react": nil,
            "react-dom": nil,
            "@/components": nil,
            "framer-motion": "SwiftUI",
            "react-spring": "SwiftUI"
        ].compactMapValues { $0 }

        return mappings[source]
    }
}

// MARK: - Supporting Types

public struct ParsedSourceFile: Sendable {
    public let path: String
    public let components: [ParsedReactComponent]
    public let imports: [ParsedImport]
    public let exports: [ParsedExport]
}

public struct ParsedImport: Sendable {
    public let source: String
    public let importedNames: [String]
    public let defaultImport: String?
}

public struct ParsedExport: Sendable {
    public let name: String
    public let isDefault: Bool
}
