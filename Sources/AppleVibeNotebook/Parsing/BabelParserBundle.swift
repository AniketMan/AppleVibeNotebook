import Foundation

// MARK: - Babel Parser Bundle

/// Contains a minimal Babel parser implementation for JavaScriptCore.
/// This is a simplified parser that handles common JSX/TSX patterns.
/// In production, this would be the full @babel/parser bundle.
enum BabelParserBundle {

    /// The JavaScript code for the Babel parser.
    /// Note: In a real implementation, this would be the minified @babel/parser.
    /// For this implementation, we provide a simplified JSX tokenizer/parser.
    static let code = """
    var babelParser = (function() {
        'use strict';

        // Token types
        const tt = {
            eof: 'eof',
            string: 'string',
            num: 'num',
            name: 'name',
            jsxName: 'jsxName',
            jsxText: 'jsxText',
            jsxTagStart: 'jsxTagStart',
            jsxTagEnd: 'jsxTagEnd',
            braceL: '{',
            braceR: '}',
            parenL: '(',
            parenR: ')',
            bracketL: '[',
            bracketR: ']',
            semi: ';',
            comma: ',',
            colon: ':',
            dot: '.',
            eq: '=',
            arrow: '=>',
            spread: '...',
            slash: '/',
            lt: '<',
            gt: '>',
            _import: 'import',
            _export: 'export',
            _default: 'default',
            _from: 'from',
            _const: 'const',
            _let: 'let',
            _var: 'var',
            _function: 'function',
            _return: 'return',
            _if: 'if',
            _else: 'else',
            _true: 'true',
            _false: 'false',
            _null: 'null'
        };

        class Parser {
            constructor(input, options = {}) {
                this.input = input;
                this.pos = 0;
                this.line = 1;
                this.lineStart = 0;
                this.options = options;
                this.tokens = [];
            }

            parse() {
                const program = {
                    type: 'Program',
                    body: [],
                    sourceType: this.options.sourceType || 'module',
                    loc: { start: { line: 1, column: 0 }, end: { line: 1, column: 0 } }
                };

                while (this.pos < this.input.length) {
                    this.skipWhitespace();
                    if (this.pos >= this.input.length) break;

                    const stmt = this.parseStatement();
                    if (stmt) {
                        program.body.push(stmt);
                    }
                }

                program.loc.end = { line: this.line, column: this.pos - this.lineStart };
                return { program };
            }

            skipWhitespace() {
                while (this.pos < this.input.length) {
                    const ch = this.input[this.pos];
                    if (ch === ' ' || ch === '\\t' || ch === '\\r') {
                        this.pos++;
                    } else if (ch === '\\n') {
                        this.pos++;
                        this.line++;
                        this.lineStart = this.pos;
                    } else if (ch === '/' && this.input[this.pos + 1] === '/') {
                        // Single line comment
                        while (this.pos < this.input.length && this.input[this.pos] !== '\\n') {
                            this.pos++;
                        }
                    } else if (ch === '/' && this.input[this.pos + 1] === '*') {
                        // Multi line comment
                        this.pos += 2;
                        while (this.pos < this.input.length - 1) {
                            if (this.input[this.pos] === '*' && this.input[this.pos + 1] === '/') {
                                this.pos += 2;
                                break;
                            }
                            if (this.input[this.pos] === '\\n') {
                                this.line++;
                                this.lineStart = this.pos + 1;
                            }
                            this.pos++;
                        }
                    } else {
                        break;
                    }
                }
            }

            peek(offset = 0) {
                return this.input[this.pos + offset];
            }

            match(str) {
                return this.input.substr(this.pos, str.length) === str;
            }

            eat(str) {
                if (this.match(str)) {
                    this.pos += str.length;
                    return true;
                }
                return false;
            }

            readWord() {
                let word = '';
                while (this.pos < this.input.length) {
                    const ch = this.input[this.pos];
                    if (/[a-zA-Z0-9_$]/.test(ch)) {
                        word += ch;
                        this.pos++;
                    } else {
                        break;
                    }
                }
                return word;
            }

            readString(quote) {
                this.pos++; // skip opening quote
                let str = '';
                while (this.pos < this.input.length) {
                    const ch = this.input[this.pos];
                    if (ch === quote) {
                        this.pos++;
                        break;
                    }
                    if (ch === '\\\\') {
                        str += ch + this.input[this.pos + 1];
                        this.pos += 2;
                    } else {
                        str += ch;
                        this.pos++;
                    }
                }
                return str;
            }

            readNumber() {
                let num = '';
                while (this.pos < this.input.length) {
                    const ch = this.input[this.pos];
                    if (/[0-9.]/.test(ch)) {
                        num += ch;
                        this.pos++;
                    } else {
                        break;
                    }
                }
                return parseFloat(num);
            }

            loc() {
                return { line: this.line, column: this.pos - this.lineStart };
            }

            parseStatement() {
                this.skipWhitespace();
                const start = this.loc();

                if (this.match('import')) {
                    return this.parseImport(start);
                }
                if (this.match('export')) {
                    return this.parseExport(start);
                }
                if (this.match('const') || this.match('let') || this.match('var')) {
                    return this.parseVariableDeclaration(start);
                }
                if (this.match('function')) {
                    return this.parseFunctionDeclaration(start);
                }

                // Skip unknown statements
                while (this.pos < this.input.length && this.input[this.pos] !== ';' && this.input[this.pos] !== '\\n') {
                    this.pos++;
                }
                if (this.input[this.pos] === ';') this.pos++;

                return null;
            }

            parseImport(start) {
                this.pos += 6; // 'import'
                this.skipWhitespace();

                const specifiers = [];
                let source = '';

                // import X from 'y'
                // import { X } from 'y'
                // import * as X from 'y'
                // import 'y'

                if (this.peek() === '"' || this.peek() === "'") {
                    source = this.readString(this.peek());
                } else {
                    // Parse specifiers
                    if (this.peek() === '{') {
                        this.pos++;
                        this.skipWhitespace();
                        while (this.peek() !== '}') {
                            const imported = this.readWord();
                            this.skipWhitespace();
                            let local = imported;
                            if (this.match('as')) {
                                this.pos += 2;
                                this.skipWhitespace();
                                local = this.readWord();
                            }
                            specifiers.push({
                                type: 'ImportSpecifier',
                                imported: { type: 'Identifier', name: imported },
                                local: { type: 'Identifier', name: local }
                            });
                            this.skipWhitespace();
                            if (this.peek() === ',') this.pos++;
                            this.skipWhitespace();
                        }
                        this.pos++; // }
                    } else if (this.peek() === '*') {
                        this.pos++;
                        this.skipWhitespace();
                        this.pos += 2; // 'as'
                        this.skipWhitespace();
                        const local = this.readWord();
                        specifiers.push({
                            type: 'ImportNamespaceSpecifier',
                            local: { type: 'Identifier', name: local }
                        });
                    } else {
                        const local = this.readWord();
                        if (local) {
                            specifiers.push({
                                type: 'ImportDefaultSpecifier',
                                local: { type: 'Identifier', name: local }
                            });
                        }
                    }

                    this.skipWhitespace();
                    if (this.match('from')) {
                        this.pos += 4;
                        this.skipWhitespace();
                        if (this.peek() === '"' || this.peek() === "'") {
                            source = this.readString(this.peek());
                        }
                    }
                }

                this.skipWhitespace();
                if (this.peek() === ';') this.pos++;

                return {
                    type: 'ImportDeclaration',
                    specifiers: specifiers,
                    source: { type: 'StringLiteral', value: source },
                    loc: { start, end: this.loc() }
                };
            }

            parseExport(start) {
                this.pos += 6; // 'export'
                this.skipWhitespace();

                if (this.match('default')) {
                    this.pos += 7;
                    this.skipWhitespace();

                    let declaration;
                    if (this.match('function')) {
                        declaration = this.parseFunctionDeclaration(this.loc());
                    } else {
                        const name = this.readWord();
                        declaration = { type: 'Identifier', name };
                    }

                    this.skipWhitespace();
                    if (this.peek() === ';') this.pos++;

                    return {
                        type: 'ExportDefaultDeclaration',
                        declaration,
                        loc: { start, end: this.loc() }
                    };
                }

                let declaration;
                if (this.match('const') || this.match('let') || this.match('var')) {
                    declaration = this.parseVariableDeclaration(this.loc());
                } else if (this.match('function')) {
                    declaration = this.parseFunctionDeclaration(this.loc());
                }

                return {
                    type: 'ExportNamedDeclaration',
                    declaration,
                    specifiers: [],
                    loc: { start, end: this.loc() }
                };
            }

            parseVariableDeclaration(start) {
                const kind = this.readWord(); // const, let, var
                this.skipWhitespace();

                const declarations = [];

                while (true) {
                    this.skipWhitespace();
                    const id = this.parsePattern();
                    this.skipWhitespace();

                    let init = null;
                    if (this.peek() === '=') {
                        this.pos++;
                        this.skipWhitespace();
                        init = this.parseExpression();
                    }

                    declarations.push({
                        type: 'VariableDeclarator',
                        id,
                        init,
                        loc: { start, end: this.loc() }
                    });

                    this.skipWhitespace();
                    if (this.peek() === ',') {
                        this.pos++;
                    } else {
                        break;
                    }
                }

                if (this.peek() === ';') this.pos++;

                return {
                    type: 'VariableDeclaration',
                    kind,
                    declarations,
                    loc: { start, end: this.loc() }
                };
            }

            parsePattern() {
                if (this.peek() === '{') {
                    return this.parseObjectPattern();
                }
                const name = this.readWord();
                return { type: 'Identifier', name };
            }

            parseObjectPattern() {
                this.pos++; // {
                const properties = [];

                while (this.peek() !== '}') {
                    this.skipWhitespace();
                    const key = this.readWord();
                    this.skipWhitespace();

                    let value = { type: 'Identifier', name: key };

                    if (this.peek() === ':') {
                        this.pos++;
                        this.skipWhitespace();
                        value = this.parsePattern();
                    }

                    if (this.peek() === '=') {
                        this.pos++;
                        this.skipWhitespace();
                        const right = this.parseExpression();
                        value = {
                            type: 'AssignmentPattern',
                            left: value,
                            right
                        };
                    }

                    properties.push({
                        type: 'ObjectProperty',
                        key: { type: 'Identifier', name: key },
                        value,
                        shorthand: value.type === 'Identifier' && value.name === key
                    });

                    this.skipWhitespace();
                    if (this.peek() === ',') this.pos++;
                    this.skipWhitespace();
                }

                this.pos++; // }
                return { type: 'ObjectPattern', properties };
            }

            parseFunctionDeclaration(start) {
                this.pos += 8; // 'function'
                this.skipWhitespace();

                const id = { type: 'Identifier', name: this.readWord() };
                this.skipWhitespace();

                const params = this.parseParams();
                this.skipWhitespace();

                // Skip return type annotation if present (TypeScript)
                if (this.peek() === ':') {
                    while (this.pos < this.input.length && this.peek() !== '{') {
                        this.pos++;
                    }
                }

                const body = this.parseBlockStatement();

                return {
                    type: 'FunctionDeclaration',
                    id,
                    params,
                    body,
                    loc: { start, end: this.loc() }
                };
            }

            parseParams() {
                this.pos++; // (
                const params = [];

                while (this.peek() !== ')') {
                    this.skipWhitespace();
                    params.push(this.parsePattern());
                    this.skipWhitespace();

                    // Skip type annotation
                    if (this.peek() === ':') {
                        let depth = 0;
                        while (this.pos < this.input.length) {
                            const ch = this.peek();
                            if (ch === '<') depth++;
                            else if (ch === '>') depth--;
                            else if ((ch === ',' || ch === ')') && depth === 0) break;
                            this.pos++;
                        }
                    }

                    this.skipWhitespace();
                    if (this.peek() === ',') this.pos++;
                }

                this.pos++; // )
                return params;
            }

            parseBlockStatement() {
                this.skipWhitespace();
                if (this.peek() !== '{') return { type: 'BlockStatement', body: [] };

                this.pos++; // {
                const body = [];
                let depth = 1;

                while (depth > 0 && this.pos < this.input.length) {
                    this.skipWhitespace();

                    if (this.peek() === '{') {
                        depth++;
                        this.pos++;
                    } else if (this.peek() === '}') {
                        depth--;
                        if (depth === 0) {
                            this.pos++;
                            break;
                        }
                        this.pos++;
                    } else if (this.match('return')) {
                        body.push(this.parseReturnStatement());
                    } else {
                        this.pos++;
                    }
                }

                return { type: 'BlockStatement', body };
            }

            parseReturnStatement() {
                const start = this.loc();
                this.pos += 6; // 'return'
                this.skipWhitespace();

                const argument = this.parseExpression();

                return {
                    type: 'ReturnStatement',
                    argument,
                    loc: { start, end: this.loc() }
                };
            }

            parseExpression() {
                this.skipWhitespace();

                // JSX
                if (this.peek() === '<') {
                    return this.parseJSX();
                }

                // Parenthesized expression
                if (this.peek() === '(') {
                    this.pos++;
                    this.skipWhitespace();

                    // Check if it's arrow function params or grouping
                    const expr = this.parseExpression();
                    this.skipWhitespace();

                    if (this.peek() === ')') {
                        this.pos++;
                        this.skipWhitespace();

                        // Check for arrow
                        if (this.match('=>')) {
                            this.pos += 2;
                            this.skipWhitespace();
                            const body = this.parseExpression();
                            return {
                                type: 'ArrowFunctionExpression',
                                params: expr ? [expr] : [],
                                body
                            };
                        }
                    }

                    return expr;
                }

                // String literal
                if (this.peek() === '"' || this.peek() === "'") {
                    return {
                        type: 'StringLiteral',
                        value: this.readString(this.peek())
                    };
                }

                // Template literal
                if (this.peek() === '`') {
                    return this.parseTemplateLiteral();
                }

                // Number
                if (/[0-9]/.test(this.peek())) {
                    return { type: 'NumericLiteral', value: this.readNumber() };
                }

                // Array
                if (this.peek() === '[') {
                    return this.parseArrayExpression();
                }

                // Object
                if (this.peek() === '{') {
                    return this.parseObjectExpression();
                }

                // Identifier or keyword
                const word = this.readWord();
                if (word === 'true') return { type: 'BooleanLiteral', value: true };
                if (word === 'false') return { type: 'BooleanLiteral', value: false };
                if (word === 'null') return { type: 'NullLiteral' };

                if (word) {
                    let expr = { type: 'Identifier', name: word };

                    // Handle member expressions and calls
                    while (true) {
                        this.skipWhitespace();
                        if (this.peek() === '.') {
                            this.pos++;
                            const prop = this.readWord();
                            expr = {
                                type: 'MemberExpression',
                                object: expr,
                                property: { type: 'Identifier', name: prop }
                            };
                        } else if (this.peek() === '(') {
                            const args = this.parseCallArguments();
                            expr = {
                                type: 'CallExpression',
                                callee: expr,
                                arguments: args
                            };
                        } else {
                            break;
                        }
                    }

                    return expr;
                }

                return null;
            }

            parseJSX() {
                const start = this.loc();
                this.pos++; // <
                this.skipWhitespace();

                // Fragment <>
                if (this.peek() === '>') {
                    this.pos++;
                    return this.parseJSXFragment(start);
                }

                // Closing tag </
                if (this.peek() === '/') {
                    return null;
                }

                const name = this.parseJSXElementName();
                const attributes = [];

                // Parse attributes
                while (true) {
                    this.skipWhitespace();
                    if (this.peek() === '/' || this.peek() === '>') break;

                    if (this.peek() === '{') {
                        // Spread attribute
                        this.pos++;
                        this.skipWhitespace();
                        if (this.match('...')) {
                            this.pos += 3;
                            const argument = this.parseExpression();
                            attributes.push({
                                type: 'JSXSpreadAttribute',
                                argument
                            });
                        }
                        this.skipWhitespace();
                        if (this.peek() === '}') this.pos++;
                    } else {
                        const attrName = this.readJSXAttributeName();
                        if (!attrName) break;

                        this.skipWhitespace();
                        let value = null;

                        if (this.peek() === '=') {
                            this.pos++;
                            this.skipWhitespace();
                            value = this.parseJSXAttributeValue();
                        }

                        attributes.push({
                            type: 'JSXAttribute',
                            name: { type: 'JSXIdentifier', name: attrName },
                            value
                        });
                    }
                }

                // Self-closing tag
                if (this.match('/>')) {
                    this.pos += 2;
                    return {
                        type: 'JSXElement',
                        openingElement: {
                            type: 'JSXOpeningElement',
                            name: { type: 'JSXIdentifier', name },
                            attributes,
                            selfClosing: true
                        },
                        closingElement: null,
                        children: [],
                        loc: { start, end: this.loc() }
                    };
                }

                // Opening tag
                this.pos++; // >

                // Parse children
                const children = this.parseJSXChildren(name);

                return {
                    type: 'JSXElement',
                    openingElement: {
                        type: 'JSXOpeningElement',
                        name: { type: 'JSXIdentifier', name },
                        attributes,
                        selfClosing: false
                    },
                    closingElement: {
                        type: 'JSXClosingElement',
                        name: { type: 'JSXIdentifier', name }
                    },
                    children,
                    loc: { start, end: this.loc() }
                };
            }

            parseJSXFragment(start) {
                const children = this.parseJSXChildren('');
                return {
                    type: 'JSXFragment',
                    openingFragment: { type: 'JSXOpeningFragment' },
                    closingFragment: { type: 'JSXClosingFragment' },
                    children,
                    loc: { start, end: this.loc() }
                };
            }

            parseJSXElementName() {
                let name = this.readWord();
                while (this.peek() === '.') {
                    this.pos++;
                    name += '.' + this.readWord();
                }
                return name;
            }

            readJSXAttributeName() {
                let name = '';
                while (this.pos < this.input.length) {
                    const ch = this.input[this.pos];
                    if (/[a-zA-Z0-9_\\-:]/.test(ch)) {
                        name += ch;
                        this.pos++;
                    } else {
                        break;
                    }
                }
                return name;
            }

            parseJSXAttributeValue() {
                if (this.peek() === '"' || this.peek() === "'") {
                    return { type: 'StringLiteral', value: this.readString(this.peek()) };
                }
                if (this.peek() === '{') {
                    this.pos++;
                    this.skipWhitespace();
                    const expression = this.parseExpression();
                    this.skipWhitespace();
                    if (this.peek() === '}') this.pos++;
                    return { type: 'JSXExpressionContainer', expression };
                }
                return null;
            }

            parseJSXChildren(parentName) {
                const children = [];

                while (this.pos < this.input.length) {
                    // Check for closing tag
                    if (this.match('</')) {
                        this.pos += 2;
                        this.skipWhitespace();
                        const closingName = this.parseJSXElementName();
                        this.skipWhitespace();
                        if (this.peek() === '>') this.pos++;
                        break;
                    }

                    // Check for closing fragment
                    if (this.match('</>')) {
                        this.pos += 3;
                        break;
                    }

                    // Expression container
                    if (this.peek() === '{') {
                        this.pos++;
                        this.skipWhitespace();

                        if (this.peek() === '}') {
                            this.pos++;
                            continue;
                        }

                        const expression = this.parseExpression();
                        children.push({ type: 'JSXExpressionContainer', expression });

                        this.skipWhitespace();
                        if (this.peek() === '}') this.pos++;
                        continue;
                    }

                    // Child element
                    if (this.peek() === '<') {
                        const child = this.parseJSX();
                        if (child) children.push(child);
                        continue;
                    }

                    // Text content
                    let text = '';
                    while (this.pos < this.input.length) {
                        const ch = this.peek();
                        if (ch === '<' || ch === '{') break;
                        text += ch;
                        if (ch === '\\n') {
                            this.line++;
                            this.lineStart = this.pos + 1;
                        }
                        this.pos++;
                    }

                    if (text.trim()) {
                        children.push({ type: 'JSXText', value: text });
                    }
                }

                return children;
            }

            parseArrayExpression() {
                this.pos++; // [
                const elements = [];

                while (this.peek() !== ']') {
                    this.skipWhitespace();
                    if (this.peek() === ']') break;

                    elements.push(this.parseExpression());

                    this.skipWhitespace();
                    if (this.peek() === ',') this.pos++;
                }

                this.pos++; // ]
                return { type: 'ArrayExpression', elements };
            }

            parseObjectExpression() {
                this.pos++; // {
                const properties = [];

                while (this.peek() !== '}') {
                    this.skipWhitespace();
                    if (this.peek() === '}') break;

                    const key = this.readWord() || this.readString(this.peek());
                    this.skipWhitespace();

                    if (this.peek() === ':') {
                        this.pos++;
                        this.skipWhitespace();
                        const value = this.parseExpression();
                        properties.push({
                            type: 'ObjectProperty',
                            key: { type: 'Identifier', name: key },
                            value
                        });
                    } else {
                        properties.push({
                            type: 'ObjectProperty',
                            key: { type: 'Identifier', name: key },
                            value: { type: 'Identifier', name: key },
                            shorthand: true
                        });
                    }

                    this.skipWhitespace();
                    if (this.peek() === ',') this.pos++;
                }

                this.pos++; // }
                return { type: 'ObjectExpression', properties };
            }

            parseCallArguments() {
                this.pos++; // (
                const args = [];

                while (this.peek() !== ')') {
                    this.skipWhitespace();
                    if (this.peek() === ')') break;

                    args.push(this.parseExpression());

                    this.skipWhitespace();
                    if (this.peek() === ',') this.pos++;
                }

                this.pos++; // )
                return args;
            }

            parseTemplateLiteral() {
                this.pos++; // `
                let value = '';

                while (this.pos < this.input.length) {
                    const ch = this.peek();
                    if (ch === '`') {
                        this.pos++;
                        break;
                    }
                    if (ch === '\\\\') {
                        value += ch + this.input[this.pos + 1];
                        this.pos += 2;
                    } else {
                        value += ch;
                        this.pos++;
                    }
                }

                return { type: 'TemplateLiteral', quasis: [{ value: { raw: value, cooked: value } }] };
            }
        }

        return {
            parse: function(code, options) {
                const parser = new Parser(code, options);
                return parser.parse();
            }
        };
    })();
    """
}
