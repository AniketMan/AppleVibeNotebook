import Foundation

// MARK: - PostCSS Parser Bundle

/// Contains a minimal PostCSS-like parser implementation for JavaScriptCore.
/// This is a simplified parser that handles common CSS patterns.
/// In production, this would be the full postcss bundle.
enum PostCSSParserBundle {

    /// The JavaScript code for the PostCSS-like parser.
    /// This creates a `postcss` global object with a `parse` method.
    static let code: String = """
    // Minimal PostCSS-like CSS Parser for JavaScriptCore
    // Handles standard CSS selectors, properties, @rules, and keyframes

    var postcss = (function() {
        'use strict';

        // Token types
        const TOKEN_TYPES = {
            WHITESPACE: 'whitespace',
            COMMENT: 'comment',
            SELECTOR: 'selector',
            OPEN_BRACE: 'openBrace',
            CLOSE_BRACE: 'closeBrace',
            PROPERTY: 'property',
            VALUE: 'value',
            COLON: 'colon',
            SEMICOLON: 'semicolon',
            AT_RULE: 'atRule',
            STRING: 'string'
        };

        class Tokenizer {
            constructor(css) {
                this.css = css;
                this.pos = 0;
                this.line = 1;
                this.column = 1;
            }

            peek(offset = 0) {
                return this.css[this.pos + offset];
            }

            advance() {
                const ch = this.css[this.pos];
                this.pos++;
                if (ch === '\\n') {
                    this.line++;
                    this.column = 1;
                } else {
                    this.column++;
                }
                return ch;
            }

            skipWhitespace() {
                while (this.pos < this.css.length && /\\s/.test(this.peek())) {
                    this.advance();
                }
            }

            skipComment() {
                if (this.peek() === '/' && this.peek(1) === '*') {
                    this.advance(); // /
                    this.advance(); // *
                    while (this.pos < this.css.length) {
                        if (this.peek() === '*' && this.peek(1) === '/') {
                            this.advance(); // *
                            this.advance(); // /
                            return true;
                        }
                        this.advance();
                    }
                }
                return false;
            }

            readString(quote) {
                let value = '';
                this.advance(); // opening quote
                while (this.pos < this.css.length) {
                    const ch = this.peek();
                    if (ch === quote) {
                        this.advance(); // closing quote
                        break;
                    }
                    if (ch === '\\\\') {
                        this.advance();
                        if (this.pos < this.css.length) {
                            value += this.advance();
                        }
                    } else {
                        value += this.advance();
                    }
                }
                return value;
            }

            readUntil(stopChars) {
                let value = '';
                while (this.pos < this.css.length) {
                    const ch = this.peek();
                    if (stopChars.includes(ch)) {
                        break;
                    }
                    if (ch === '"' || ch === "'") {
                        value += ch;
                        value += this.readString(ch);
                        value += ch;
                    } else {
                        value += this.advance();
                    }
                }
                return value;
            }
        }

        class Node {
            constructor(type) {
                this.type = type;
                this.source = { start: { line: 1, column: 1 } };
            }

            toJSON() {
                return { ...this };
            }
        }

        class Root extends Node {
            constructor() {
                super('root');
                this.nodes = [];
            }
        }

        class Rule extends Node {
            constructor(selector) {
                super('rule');
                this.selector = selector;
                this.nodes = [];
            }
        }

        class Declaration extends Node {
            constructor(prop, value) {
                super('decl');
                this.prop = prop;
                this.value = value;
            }
        }

        class AtRule extends Node {
            constructor(name, params) {
                super('atrule');
                this.name = name;
                this.params = params;
                this.nodes = [];
            }
        }

        class Comment extends Node {
            constructor(text) {
                super('comment');
                this.text = text;
            }
        }

        class Parser {
            constructor(css) {
                this.tokenizer = new Tokenizer(css);
                this.root = new Root();
            }

            parse() {
                this.parseNodes(this.root);
                return this.root;
            }

            parseNodes(parent) {
                const t = this.tokenizer;

                while (t.pos < t.css.length) {
                    t.skipWhitespace();

                    if (t.pos >= t.css.length) break;

                    // Skip comments
                    if (t.skipComment()) {
                        continue;
                    }

                    const ch = t.peek();

                    // Close brace - end of current block
                    if (ch === '}') {
                        t.advance();
                        break;
                    }

                    // At-rule
                    if (ch === '@') {
                        const atRule = this.parseAtRule();
                        if (atRule) {
                            parent.nodes.push(atRule);
                        }
                        continue;
                    }

                    // Otherwise, it's a rule or declaration
                    const selector = t.readUntil(['{', '}', ';']).trim();

                    if (t.peek() === '{') {
                        // It's a rule with selector
                        t.advance(); // {
                        const rule = new Rule(selector);
                        rule.source = { start: { line: t.line, column: t.column } };
                        this.parseDeclarations(rule);
                        parent.nodes.push(rule);
                    } else if (t.peek() === ';') {
                        // It's a declaration at root level (rare but valid)
                        t.advance(); // ;
                    }
                }
            }

            parseDeclarations(rule) {
                const t = this.tokenizer;

                while (t.pos < t.css.length) {
                    t.skipWhitespace();

                    if (t.pos >= t.css.length) break;

                    // Skip comments
                    if (t.skipComment()) {
                        continue;
                    }

                    const ch = t.peek();

                    // End of rule
                    if (ch === '}') {
                        t.advance();
                        break;
                    }

                    // Nested rule (like in SCSS or @keyframes)
                    if (ch === '@') {
                        const atRule = this.parseAtRule();
                        if (atRule) {
                            rule.nodes.push(atRule);
                        }
                        continue;
                    }

                    // Read property name
                    const prop = t.readUntil([':', '{', '}']).trim();

                    if (t.peek() === ':') {
                        t.advance(); // :
                        t.skipWhitespace();

                        // Read value
                        const value = t.readUntil([';', '}']).trim();

                        if (prop && value) {
                            const decl = new Declaration(prop, value);
                            decl.source = { start: { line: t.line, column: t.column } };
                            rule.nodes.push(decl);
                        }

                        if (t.peek() === ';') {
                            t.advance();
                        }
                    } else if (t.peek() === '{') {
                        // Nested rule (like in @keyframes: 0%, 100%, from, to)
                        t.advance(); // {
                        const nestedRule = new Rule(prop);
                        nestedRule.source = { start: { line: t.line, column: t.column } };
                        this.parseDeclarations(nestedRule);
                        rule.nodes.push(nestedRule);
                    }
                }
            }

            parseAtRule() {
                const t = this.tokenizer;
                t.advance(); // @

                // Read at-rule name
                let name = '';
                while (t.pos < t.css.length && /[a-zA-Z-]/.test(t.peek())) {
                    name += t.advance();
                }

                t.skipWhitespace();

                // Read params until { or ;
                const params = t.readUntil(['{', ';']).trim();

                const atRule = new AtRule(name, params);
                atRule.source = { start: { line: t.line, column: t.column } };

                if (t.peek() === '{') {
                    t.advance(); // {
                    this.parseAtRuleBody(atRule);
                } else if (t.peek() === ';') {
                    t.advance(); // ;
                }

                return atRule;
            }

            parseAtRuleBody(atRule) {
                const t = this.tokenizer;

                // For @keyframes, @media, etc. - parse nested rules
                while (t.pos < t.css.length) {
                    t.skipWhitespace();

                    if (t.pos >= t.css.length) break;

                    // Skip comments
                    if (t.skipComment()) {
                        continue;
                    }

                    const ch = t.peek();

                    if (ch === '}') {
                        t.advance();
                        break;
                    }

                    // Nested at-rule
                    if (ch === '@') {
                        const nested = this.parseAtRule();
                        if (nested) {
                            atRule.nodes.push(nested);
                        }
                        continue;
                    }

                    // Read selector/keyframe stop
                    const selector = t.readUntil(['{', '}']).trim();

                    if (t.peek() === '{') {
                        t.advance(); // {
                        const rule = new Rule(selector);
                        rule.source = { start: { line: t.line, column: t.column } };
                        this.parseDeclarations(rule);
                        atRule.nodes.push(rule);
                    }
                }
            }
        }

        return {
            parse: function(css, options) {
                const parser = new Parser(css);
                return parser.parse();
            }
        };
    })();
    """
}
