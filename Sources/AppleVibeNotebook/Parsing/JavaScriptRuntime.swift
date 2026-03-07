import Foundation
import JavaScriptCore

// MARK: - JavaScript Runtime

/// A wrapper around JavaScriptCore for executing Babel and PostCSS.
/// Runs JavaScript parsers within the app's process without requiring Node.js.
public final class JavaScriptRuntime: @unchecked Sendable {

    /// Shared instance for performance (reuses JSContext).
    public static let shared = JavaScriptRuntime()

    private let context: JSContext
    private let lock = NSLock()
    private var isInitialized = false

    public enum RuntimeError: Error, LocalizedError {
        case contextCreationFailed
        case scriptExecutionFailed(String)
        case parserNotLoaded(String)
        case parseError(String)
        case invalidJSON(String)

        public var errorDescription: String? {
            switch self {
            case .contextCreationFailed:
                return "Failed to create JavaScript context"
            case .scriptExecutionFailed(let message):
                return "Script execution failed: \(message)"
            case .parserNotLoaded(let parser):
                return "Parser not loaded: \(parser)"
            case .parseError(let message):
                return "Parse error: \(message)"
            case .invalidJSON(let message):
                return "Invalid JSON: \(message)"
            }
        }
    }

    public init() {
        guard let ctx = JSContext() else {
            fatalError("Failed to create JSContext")
        }
        self.context = ctx
        setupErrorHandling()
    }

    private func setupErrorHandling() {
        context.exceptionHandler = { context, exception in
            if let exc = exception {
                print("[JSRuntime] Error: \(exc)")
            }
        }
    }

    // MARK: - Initialization

    /// Initializes the runtime with Babel and PostCSS parsers.
    public func initialize() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isInitialized else { return }

        try loadBabelParser()
        try loadPostCSSParser()
        try loadHelperFunctions()

        isInitialized = true
    }

    private func loadBabelParser() throws {
        let babelParserCode = BabelParserBundle.code
        context.evaluateScript(babelParserCode)

        if context.exception != nil {
            throw RuntimeError.scriptExecutionFailed("Failed to load Babel parser")
        }
    }

    private func loadPostCSSParser() throws {
        let postCSSCode = PostCSSParserBundle.code
        context.evaluateScript(postCSSCode)

        if context.exception != nil {
            throw RuntimeError.scriptExecutionFailed("Failed to load PostCSS parser")
        }
    }

    private func loadHelperFunctions() throws {
        let helperCode = """
        // Helper to safely stringify with circular reference handling
        function safeStringify(obj) {
            const seen = new WeakSet();
            return JSON.stringify(obj, (key, value) => {
                if (typeof value === 'object' && value !== null) {
                    if (seen.has(value)) {
                        return '[Circular]';
                    }
                    seen.add(value);
                }
                // Handle BigInt
                if (typeof value === 'bigint') {
                    return value.toString();
                }
                return value;
            }, 2);
        }

        // Parse JSX/TSX with Babel
        function parseJSX(code, isTypeScript) {
            try {
                const plugins = ['jsx'];
                if (isTypeScript) {
                    plugins.push('typescript');
                }

                const ast = babelParser.parse(code, {
                    sourceType: 'module',
                    plugins: plugins,
                    errorRecovery: true
                });

                return safeStringify({
                    success: true,
                    ast: ast
                });
            } catch (error) {
                return safeStringify({
                    success: false,
                    error: error.message,
                    loc: error.loc
                });
            }
        }

        // Parse CSS with PostCSS
        function parseCSS(code) {
            try {
                const result = postcss.parse(code);
                return safeStringify({
                    success: true,
                    ast: result.toJSON()
                });
            } catch (error) {
                return safeStringify({
                    success: false,
                    error: error.message,
                    line: error.line,
                    column: error.column
                });
            }
        }

        // Extract component information from AST
        function extractComponents(ast) {
            const components = [];
            const imports = [];
            const exports = [];

            function visit(node, parent) {
                if (!node || typeof node !== 'object') return;

                // Track imports
                if (node.type === 'ImportDeclaration') {
                    imports.push({
                        source: node.source.value,
                        specifiers: (node.specifiers || []).map(s => ({
                            type: s.type,
                            local: s.local?.name,
                            imported: s.imported?.name
                        }))
                    });
                }

                // Track function components
                if (node.type === 'FunctionDeclaration' && node.id) {
                    const body = findJSXReturn(node.body);
                    if (body) {
                        components.push({
                            name: node.id.name,
                            type: 'function',
                            params: extractParams(node.params),
                            body: body,
                            loc: node.loc
                        });
                    }
                }

                // Track arrow function components
                if (node.type === 'VariableDeclaration') {
                    for (const decl of node.declarations || []) {
                        if (decl.init &&
                            (decl.init.type === 'ArrowFunctionExpression' ||
                             decl.init.type === 'FunctionExpression')) {
                            const body = findJSXReturn(decl.init.body);
                            if (body) {
                                components.push({
                                    name: decl.id.name,
                                    type: 'arrow',
                                    params: extractParams(decl.init.params),
                                    body: body,
                                    loc: decl.loc
                                });
                            }
                        }
                    }
                }

                // Track exports
                if (node.type === 'ExportDefaultDeclaration') {
                    if (node.declaration.type === 'Identifier') {
                        exports.push({ name: node.declaration.name, isDefault: true });
                    } else if (node.declaration.id) {
                        exports.push({ name: node.declaration.id.name, isDefault: true });
                    }
                }

                if (node.type === 'ExportNamedDeclaration') {
                    if (node.declaration && node.declaration.id) {
                        exports.push({ name: node.declaration.id.name, isDefault: false });
                    }
                    for (const spec of node.specifiers || []) {
                        exports.push({ name: spec.exported.name, isDefault: false });
                    }
                }

                // Recurse
                for (const key in node) {
                    if (key === 'loc' || key === 'range' || key === 'start' || key === 'end') continue;
                    const child = node[key];
                    if (Array.isArray(child)) {
                        child.forEach(c => visit(c, node));
                    } else if (child && typeof child === 'object') {
                        visit(child, node);
                    }
                }
            }

            function findJSXReturn(body) {
                if (!body) return null;

                // Direct JSX return (arrow function)
                if (body.type === 'JSXElement' || body.type === 'JSXFragment') {
                    return body;
                }

                // Block body - find return statement
                if (body.type === 'BlockStatement') {
                    for (const stmt of body.body || []) {
                        if (stmt.type === 'ReturnStatement' && stmt.argument) {
                            if (stmt.argument.type === 'JSXElement' ||
                                stmt.argument.type === 'JSXFragment' ||
                                stmt.argument.type === 'ConditionalExpression' ||
                                stmt.argument.type === 'LogicalExpression') {
                                return stmt.argument;
                            }
                        }
                    }
                }

                return null;
            }

            function extractParams(params) {
                if (!params) return [];
                return params.map(p => {
                    if (p.type === 'ObjectPattern') {
                        return {
                            type: 'destructured',
                            properties: (p.properties || []).map(prop => ({
                                name: prop.key?.name,
                                defaultValue: prop.value?.right ? nodeToString(prop.value.right) : null
                            }))
                        };
                    }
                    return {
                        type: 'simple',
                        name: p.name || p.argument?.name
                    };
                });
            }

            function nodeToString(node) {
                if (!node) return null;
                if (node.type === 'StringLiteral') return '"' + node.value + '"';
                if (node.type === 'NumericLiteral') return String(node.value);
                if (node.type === 'BooleanLiteral') return String(node.value);
                if (node.type === 'NullLiteral') return 'null';
                if (node.type === 'Identifier') return node.name;
                return null;
            }

            visit(ast.program, null);

            return safeStringify({
                components: components,
                imports: imports,
                exports: exports
            });
        }

        // Extract hooks from a component
        function extractHooks(componentBody) {
            const hooks = [];

            function visit(node) {
                if (!node || typeof node !== 'object') return;

                if (node.type === 'CallExpression' &&
                    node.callee &&
                    node.callee.type === 'Identifier' &&
                    node.callee.name.startsWith('use')) {

                    const hookName = node.callee.name;
                    const args = (node.arguments || []).map(extractArgument);

                    hooks.push({
                        name: hookName,
                        arguments: args,
                        loc: node.loc
                    });
                }

                for (const key in node) {
                    if (key === 'loc' || key === 'range') continue;
                    const child = node[key];
                    if (Array.isArray(child)) {
                        child.forEach(visit);
                    } else if (child && typeof child === 'object') {
                        visit(child);
                    }
                }
            }

            function extractArgument(arg) {
                if (!arg) return null;

                switch (arg.type) {
                    case 'StringLiteral':
                        return { type: 'string', value: arg.value };
                    case 'NumericLiteral':
                        return { type: 'number', value: arg.value };
                    case 'BooleanLiteral':
                        return { type: 'boolean', value: arg.value };
                    case 'ArrayExpression':
                        return { type: 'array', elements: arg.elements.map(extractArgument) };
                    case 'ArrowFunctionExpression':
                    case 'FunctionExpression':
                        return { type: 'function', body: '[function]' };
                    case 'Identifier':
                        return { type: 'identifier', name: arg.name };
                    default:
                        return { type: arg.type, raw: '[complex]' };
                }
            }

            visit(componentBody);
            return safeStringify(hooks);
        }

        // Convert JSX element to structured format
        function jsxToStructure(node) {
            if (!node) return null;

            switch (node.type) {
                case 'JSXElement':
                    return {
                        type: 'element',
                        name: getJSXName(node.openingElement.name),
                        attributes: (node.openingElement.attributes || []).map(attr => {
                            if (attr.type === 'JSXSpreadAttribute') {
                                return { type: 'spread', argument: nodeToCode(attr.argument) };
                            }
                            return {
                                type: 'attribute',
                                name: attr.name?.name,
                                value: extractJSXValue(attr.value)
                            };
                        }),
                        children: (node.children || [])
                            .map(jsxToStructure)
                            .filter(c => c !== null),
                        loc: node.loc
                    };

                case 'JSXFragment':
                    return {
                        type: 'fragment',
                        children: (node.children || [])
                            .map(jsxToStructure)
                            .filter(c => c !== null),
                        loc: node.loc
                    };

                case 'JSXText':
                    const text = node.value.trim();
                    if (!text) return null;
                    return { type: 'text', value: text };

                case 'JSXExpressionContainer':
                    if (node.expression.type === 'JSXEmptyExpression') return null;
                    return {
                        type: 'expression',
                        expression: nodeToCode(node.expression),
                        expressionType: node.expression.type
                    };

                case 'ConditionalExpression':
                    return {
                        type: 'conditional',
                        test: nodeToCode(node.test),
                        consequent: jsxToStructure(node.consequent),
                        alternate: jsxToStructure(node.alternate)
                    };

                case 'LogicalExpression':
                    if (node.operator === '&&') {
                        return {
                            type: 'logicalAnd',
                            condition: nodeToCode(node.left),
                            element: jsxToStructure(node.right)
                        };
                    }
                    return {
                        type: 'expression',
                        expression: nodeToCode(node),
                        expressionType: 'LogicalExpression'
                    };

                default:
                    return null;
            }
        }

        function getJSXName(nameNode) {
            if (nameNode.type === 'JSXIdentifier') return nameNode.name;
            if (nameNode.type === 'JSXMemberExpression') {
                return getJSXName(nameNode.object) + '.' + nameNode.property.name;
            }
            return 'Unknown';
        }

        function extractJSXValue(value) {
            if (!value) return { type: 'true' }; // Boolean attribute
            if (value.type === 'StringLiteral') return { type: 'string', value: value.value };
            if (value.type === 'JSXExpressionContainer') {
                return {
                    type: 'expression',
                    expression: nodeToCode(value.expression),
                    expressionType: value.expression.type
                };
            }
            return { type: 'unknown' };
        }

        function nodeToCode(node) {
            if (!node) return '';

            switch (node.type) {
                case 'Identifier':
                    return node.name;
                case 'StringLiteral':
                    return '"' + node.value + '"';
                case 'NumericLiteral':
                    return String(node.value);
                case 'BooleanLiteral':
                    return String(node.value);
                case 'NullLiteral':
                    return 'null';
                case 'MemberExpression':
                    return nodeToCode(node.object) + '.' + nodeToCode(node.property);
                case 'CallExpression':
                    return nodeToCode(node.callee) + '(...)';
                case 'ArrowFunctionExpression':
                    return '() => {...}';
                case 'BinaryExpression':
                case 'LogicalExpression':
                    return nodeToCode(node.left) + ' ' + node.operator + ' ' + nodeToCode(node.right);
                case 'UnaryExpression':
                    return node.operator + nodeToCode(node.argument);
                case 'ConditionalExpression':
                    return nodeToCode(node.test) + ' ? ... : ...';
                case 'TemplateLiteral':
                    return '`template`';
                default:
                    return '[' + node.type + ']';
            }
        }

        // Parse CSS and extract rules
        function extractCSSRules(cssAST) {
            const rules = [];

            function processNode(node) {
                if (node.type === 'rule') {
                    const declarations = {};
                    for (const decl of node.nodes || []) {
                        if (decl.type === 'decl') {
                            declarations[decl.prop] = decl.value;
                        }
                    }
                    rules.push({
                        selector: node.selector,
                        declarations: declarations,
                        source: node.source
                    });
                }

                if (node.type === 'atrule' && node.name === 'keyframes') {
                    const keyframes = [];
                    for (const kf of node.nodes || []) {
                        if (kf.type === 'rule') {
                            const props = {};
                            for (const decl of kf.nodes || []) {
                                if (decl.type === 'decl') {
                                    props[decl.prop] = decl.value;
                                }
                            }
                            keyframes.push({
                                selector: kf.selector,
                                properties: props
                            });
                        }
                    }
                    rules.push({
                        type: 'keyframes',
                        name: node.params,
                        keyframes: keyframes
                    });
                }

                if (node.type === 'atrule' && node.name === 'media') {
                    for (const child of node.nodes || []) {
                        processNode(child);
                    }
                }

                if (node.nodes) {
                    for (const child of node.nodes) {
                        processNode(child);
                    }
                }
            }

            processNode(cssAST);
            return safeStringify(rules);
        }
        """

        context.evaluateScript(helperCode)

        if context.exception != nil {
            throw RuntimeError.scriptExecutionFailed("Failed to load helper functions")
        }
    }

    // MARK: - Public Parsing API

    /// Parses JSX/TSX code and returns the AST as JSON.
    public func parseJSX(_ code: String, isTypeScript: Bool = false) throws -> JSXParseResult {
        try ensureInitialized()

        lock.lock()
        defer { lock.unlock() }

        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let script = "parseJSX(`\(escapedCode)`, \(isTypeScript))"

        guard let result = context.evaluateScript(script),
              let jsonString = result.toString() else {
            throw RuntimeError.parseError("Failed to get parse result")
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RuntimeError.invalidJSON(jsonString)
        }

        if let success = json["success"] as? Bool, !success {
            let errorMessage = json["error"] as? String ?? "Unknown parse error"
            throw RuntimeError.parseError(errorMessage)
        }

        guard let ast = json["ast"] as? [String: Any] else {
            throw RuntimeError.invalidJSON("Missing AST in result")
        }

        return JSXParseResult(ast: ast, rawJSON: jsonString)
    }

    /// Extracts component information from a parsed AST.
    public func extractComponents(from ast: [String: Any]) throws -> ExtractedComponents {
        lock.lock()
        defer { lock.unlock() }

        let astJSON = try JSONSerialization.data(withJSONObject: ast)
        let astString = String(data: astJSON, encoding: .utf8) ?? "{}"

        let escapedAST = astString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        let script = "extractComponents(JSON.parse(`\(escapedAST)`))"

        guard let result = context.evaluateScript(script),
              let jsonString = result.toString(),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RuntimeError.parseError("Failed to extract components")
        }

        return ExtractedComponents(
            components: json["components"] as? [[String: Any]] ?? [],
            imports: json["imports"] as? [[String: Any]] ?? [],
            exports: json["exports"] as? [[String: Any]] ?? []
        )
    }

    /// Converts a JSX element node to a structured format.
    public func jsxToStructure(_ node: [String: Any]) throws -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }

        let nodeJSON = try JSONSerialization.data(withJSONObject: node)
        let nodeString = String(data: nodeJSON, encoding: .utf8) ?? "{}"

        let escapedNode = nodeString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        let script = "safeStringify(jsxToStructure(JSON.parse(`\(escapedNode)`)))"

        guard let result = context.evaluateScript(script),
              let jsonString = result.toString(),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }

    /// Parses CSS code and returns the AST.
    public func parseCSS(_ code: String) throws -> CSSParseResult {
        try ensureInitialized()

        lock.lock()
        defer { lock.unlock() }

        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let script = "parseCSS(`\(escapedCode)`)"

        guard let result = context.evaluateScript(script),
              let jsonString = result.toString() else {
            throw RuntimeError.parseError("Failed to get CSS parse result")
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RuntimeError.invalidJSON(jsonString)
        }

        if let success = json["success"] as? Bool, !success {
            let errorMessage = json["error"] as? String ?? "Unknown CSS parse error"
            throw RuntimeError.parseError(errorMessage)
        }

        guard let ast = json["ast"] as? [String: Any] else {
            throw RuntimeError.invalidJSON("Missing CSS AST in result")
        }

        return CSSParseResult(ast: ast, rawJSON: jsonString)
    }

    /// Extracts CSS rules from a parsed CSS AST.
    public func extractCSSRules(from ast: [String: Any]) throws -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }

        let astJSON = try JSONSerialization.data(withJSONObject: ast)
        let astString = String(data: astJSON, encoding: .utf8) ?? "{}"

        let escapedAST = astString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        let script = "extractCSSRules(JSON.parse(`\(escapedAST)`))"

        guard let result = context.evaluateScript(script),
              let jsonString = result.toString(),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw RuntimeError.parseError("Failed to extract CSS rules")
        }

        return json
    }

    /// Extracts React hooks from a component body AST node.
    public func extractHooks(from body: [String: Any]) throws -> [[String: Any]] {
        try ensureInitialized()

        lock.lock()
        defer { lock.unlock() }

        let bodyJSON = try JSONSerialization.data(withJSONObject: body)
        let bodyString = String(data: bodyJSON, encoding: .utf8) ?? "{}"

        let escapedBody = bodyString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        let script = "extractHooks(JSON.parse(`\(escapedBody)`))"

        guard let result = context.evaluateScript(script),
              let jsonString = result.toString(),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return json
    }

    private func ensureInitialized() throws {
        lock.lock()
        let initialized = isInitialized
        lock.unlock()

        if !initialized {
            try initialize()
        }
    }
}

// MARK: - Parse Results

/// Result of parsing JSX/TSX code.
public struct JSXParseResult: @unchecked Sendable {
    public let ast: [String: Any]
    public let rawJSON: String

    public init(ast: [String: Any], rawJSON: String) {
        self.ast = ast
        self.rawJSON = rawJSON
    }
}

/// Result of parsing CSS code.
public struct CSSParseResult: @unchecked Sendable {
    public let ast: [String: Any]
    public let rawJSON: String

    public init(ast: [String: Any], rawJSON: String) {
        self.ast = ast
        self.rawJSON = rawJSON
    }
}

/// Extracted component information from AST.
public struct ExtractedComponents: @unchecked Sendable {
    public let components: [[String: Any]]
    public let imports: [[String: Any]]
    public let exports: [[String: Any]]

    public init(components: [[String: Any]], imports: [[String: Any]], exports: [[String: Any]]) {
        self.components = components
        self.imports = imports
        self.exports = exports
    }
}

// MARK: - Sendable Conformance for Dictionary

extension JSXParseResult {
    public static func == (lhs: JSXParseResult, rhs: JSXParseResult) -> Bool {
        lhs.rawJSON == rhs.rawJSON
    }
}

extension CSSParseResult {
    public static func == (lhs: CSSParseResult, rhs: CSSParseResult) -> Bool {
        lhs.rawJSON == rhs.rawJSON
    }
}
