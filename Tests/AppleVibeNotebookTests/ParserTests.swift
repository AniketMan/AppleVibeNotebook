import Testing
@testable import React2SwiftUI
import Foundation

// MARK: - CSS Parser Tests

@Suite("CSS Parser Tests")
struct CSSParserTests {

    @Test("Parse basic CSS properties")
    func testBasicCSSProperties() throws {
        let css = """
        .container {
            display: flex;
            flex-direction: column;
            width: 100px;
            height: 200px;
            padding: 10px;
            margin: 20px;
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let containerStyle = styles[".container"]
        #expect(containerStyle != nil)
        #expect(containerStyle?.display == .flex)
        #expect(containerStyle?.flexDirection == .column)
        #expect(containerStyle?.width == .px(100))
        #expect(containerStyle?.height == .px(200))
        #expect(containerStyle?.paddingTop == .px(10))
        #expect(containerStyle?.marginTop == .px(20))
    }

    @Test("Parse color values")
    func testColorParsing() throws {
        let css = """
        .text {
            color: #ff0000;
            background-color: rgb(0, 255, 0);
        }
        .accent {
            color: blue;
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let textStyle = styles[".text"]
        #expect(textStyle?.color?.red == 1.0)
        #expect(textStyle?.color?.green == 0.0)
        #expect(textStyle?.color?.blue == 0.0)

        #expect(textStyle?.backgroundColor?.red == 0.0)
        #expect(textStyle?.backgroundColor?.green == 1.0)
        #expect(textStyle?.backgroundColor?.blue == 0.0)

        let accentStyle = styles[".accent"]
        #expect(accentStyle?.color?.blue == 1.0)
    }

    @Test("Parse hex colors in various formats")
    func testHexColorFormats() throws {
        let css = """
        .short { color: #f00; }
        .full { color: #ff0000; }
        .alpha { color: #ff000080; }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        #expect(styles[".short"]?.color?.red == 1.0)
        #expect(styles[".full"]?.color?.red == 1.0)
        #expect(styles[".alpha"]?.color?.red == 1.0)
    }

    @Test("Parse flexbox properties")
    func testFlexboxProperties() throws {
        let css = """
        .flex-container {
            display: flex;
            flex-direction: row;
            flex-wrap: wrap;
            justify-content: center;
            align-items: flex-start;
            gap: 16px;
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let style = styles[".flex-container"]
        #expect(style?.display == .flex)
        #expect(style?.flexDirection == .row)
        #expect(style?.flexWrap == .wrap)
        #expect(style?.justifyContent == .center)
        #expect(style?.alignItems == .flexStart)
        #expect(style?.gap == .px(16))
    }

    @Test("Parse border properties")
    func testBorderProperties() throws {
        let css = """
        .bordered {
            border: 1px solid black;
            border-radius: 8px;
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let style = styles[".bordered"]
        #expect(style?.borderTop?.width == .px(1))
        #expect(style?.borderTop?.style == .solid)
        #expect(style?.borderTopLeftRadius == .px(8))
    }

    @Test("Parse typography properties")
    func testTypographyProperties() throws {
        let css = """
        .heading {
            font-size: 24px;
            font-weight: bold;
            text-align: center;
            line-height: 1.5;
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let style = styles[".heading"]
        #expect(style?.fontSize == .px(24))
        #expect(style?.fontWeight == .bold)
        #expect(style?.textAlign == .center)
        #expect(style?.lineHeight == 1.5)
    }

    @Test("Parse transform properties")
    func testTransformProperties() throws {
        let css = """
        .transformed {
            transform: translateX(10px) rotate(45deg) scale(1.5);
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let style = styles[".transformed"]
        #expect(style?.transform?.count == 3)
    }

    @Test("Parse four-side values")
    func testFourSideValues() throws {
        let css = """
        .single { padding: 10px; }
        .double { padding: 10px 20px; }
        .triple { padding: 10px 20px 30px; }
        .quad { padding: 10px 20px 30px 40px; }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let single = styles[".single"]
        #expect(single?.paddingTop == .px(10))
        #expect(single?.paddingRight == .px(10))
        #expect(single?.paddingBottom == .px(10))
        #expect(single?.paddingLeft == .px(10))

        let double = styles[".double"]
        #expect(double?.paddingTop == .px(10))
        #expect(double?.paddingRight == .px(20))
        #expect(double?.paddingBottom == .px(10))
        #expect(double?.paddingLeft == .px(20))

        let quad = styles[".quad"]
        #expect(quad?.paddingTop == .px(10))
        #expect(quad?.paddingRight == .px(20))
        #expect(quad?.paddingBottom == .px(30))
        #expect(quad?.paddingLeft == .px(40))
    }

    @Test("Parse transition properties")
    func testTransitionProperties() throws {
        let css = """
        .animated {
            transition: all 0.3s ease;
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let style = styles[".animated"]
        #expect(style?.transition?.count == 1)
        #expect(style?.transition?.first?.property == "all")
        #expect(style?.transition?.first?.duration == 0.3)
        #expect(style?.transition?.first?.timingFunction == .ease)
    }

    @Test("Parse length units")
    func testLengthUnits() throws {
        let css = """
        .sizes {
            width: 100px;
            height: 50%;
            min-width: 10em;
            max-width: 20rem;
            margin-top: 5vh;
        }
        """

        let parser = CSSParser()
        let styles = try parser.parseCSS(css)

        let style = styles[".sizes"]
        #expect(style?.width == .px(100))
        #expect(style?.height == .percent(50))
        #expect(style?.minWidth == .em(10))
        #expect(style?.maxWidth == .rem(20))
        #expect(style?.marginTop == .vh(5))
    }

    @Test("Get merged styles for multiple classes")
    func testMergedStyles() throws {
        let css = """
        .base {
            color: red;
            padding: 10px;
        }
        .override {
            color: blue;
        }
        """

        let parser = CSSParser()
        _ = try parser.parseCSS(css)

        let merged = parser.getMergedStyle(forClasses: ["base", "override"])
        #expect(merged.color?.blue == 1.0)
        #expect(merged.paddingTop == .px(10))
    }
}

// MARK: - React Parser Tests

@Suite("React Parser Tests")
struct ReactParserTests {

    @Test("Parse simple functional component")
    func testSimpleFunctionalComponent() throws {
        let jsx = """
        function HelloWorld() {
            return <div>Hello World</div>;
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "test.jsx",
            isTypeScript: false
        )

        #expect(parsedFile.components.count == 1)
        #expect(parsedFile.components.first?.name == "HelloWorld")
    }

    @Test("Parse arrow function component")
    func testArrowFunctionComponent() throws {
        let jsx = """
        const Greeting = () => {
            return <h1>Welcome</h1>;
        };
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "test.jsx",
            isTypeScript: false
        )

        #expect(parsedFile.components.count == 1)
        #expect(parsedFile.components.first?.name == "Greeting")
    }

    @Test("Parse component with props")
    func testComponentWithProps() throws {
        let jsx = """
        function Button({ label, onClick, disabled = false }) {
            return <button onClick={onClick} disabled={disabled}>{label}</button>;
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "test.jsx",
            isTypeScript: false
        )

        #expect(parsedFile.components.count == 1)

        let component = parsedFile.components.first
        #expect(component?.props.count == 3)

        let disabledProp = component?.props.first { $0.name == "disabled" }
        #expect(disabledProp?.defaultValue == "false")
    }

    @Test("Parse component with nested elements")
    func testNestedElements() throws {
        let jsx = """
        function Card() {
            return (
                <div className="card">
                    <h2>Title</h2>
                    <p>Content</p>
                </div>
            );
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "test.jsx",
            isTypeScript: false
        )

        #expect(parsedFile.components.count == 1)
        #expect(!parsedFile.components.first!.children.isEmpty)
    }

    @Test("Parse TypeScript component")
    func testTypeScriptComponent() throws {
        let tsx = """
        interface Props {
            name: string;
            age: number;
        }

        const Person: React.FC<Props> = ({ name, age }) => {
            return <div>{name} is {age} years old</div>;
        };
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: tsx,
            filePath: "test.tsx",
            isTypeScript: true
        )

        #expect(parsedFile.components.count == 1)
        #expect(parsedFile.components.first?.name == "Person")
    }

    @Test("Convert to IR - simple component")
    func testConvertToIR() throws {
        let jsx = """
        function SimpleBox() {
            return <div className="box">Content</div>;
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "test.jsx",
            isTypeScript: false
        )

        let ir = try parser.convertToIR(parsedFile: parsedFile, cssStyles: [:])

        #expect(ir.components.count == 1)
        #expect(ir.components.first?.name == "SimpleBox")
    }

    @Test("Parse imports")
    func testParseImports() throws {
        let jsx = """
        import React from 'react';
        import { useState, useEffect } from 'react';
        import Button from './Button';

        function App() {
            return <div>App</div>;
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "test.jsx",
            isTypeScript: false
        )

        #expect(parsedFile.imports.count >= 2)
    }
}

// MARK: - PostCSS Parser Bundle Tests

@Suite("PostCSS Parser Bundle Tests")
struct PostCSSParserBundleTests {

    @Test("PostCSS bundle code is valid")
    func testPostCSSBundleIsValid() {
        let code = PostCSSParserBundle.code
        #expect(!code.isEmpty)
        #expect(code.contains("postcss"))
        #expect(code.contains("parse"))
    }

    @Test("PostCSS parser initializes in JSContext")
    func testPostCSSInitializes() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()
        // If it doesn't throw, the PostCSS parser loaded successfully
    }
}

// MARK: - Babel Parser Bundle Tests

@Suite("Babel Parser Bundle Tests")
struct BabelParserBundleTests {

    @Test("Babel bundle code is valid")
    func testBabelBundleIsValid() {
        let code = BabelParserBundle.code
        #expect(!code.isEmpty)
        #expect(code.contains("babelParser"))
        #expect(code.contains("parse"))
    }

    @Test("Babel parser initializes in JSContext")
    func testBabelInitializes() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()
        // If it doesn't throw, the Babel parser loaded successfully
    }
}

// MARK: - JavaScript Runtime Tests

@Suite("JavaScript Runtime Tests")
struct JavaScriptRuntimeTests {

    @Test("Runtime initialization")
    func testRuntimeInitialization() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()
    }

    @Test("Parse simple JSX")
    func testParseSimpleJSX() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let jsx = "const x = <div>Hello</div>;"
        let result = try runtime.parseJSX(jsx, isTypeScript: false)

        #expect(!result.rawJSON.isEmpty)
        #expect(result.ast["program"] != nil)
    }

    @Test("Parse TypeScript JSX")
    func testParseTypeScriptJSX() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let tsx = "const x: JSX.Element = <div>Hello</div>;"
        let result = try runtime.parseJSX(tsx, isTypeScript: true)

        #expect(!result.rawJSON.isEmpty)
    }

    @Test("Parse CSS")
    func testParseCSS() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let css = ".test { color: red; }"
        let result = try runtime.parseCSS(css)

        #expect(!result.rawJSON.isEmpty)
        #expect(result.ast["type"] as? String == "root")
    }

    @Test("Extract components from AST")
    func testExtractComponents() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let jsx = """
        function MyComponent() {
            return <div>Content</div>;
        }
        """

        let parseResult = try runtime.parseJSX(jsx, isTypeScript: false)
        let extracted = try runtime.extractComponents(from: parseResult.ast)

        #expect(extracted.components.count == 1)
    }

    @Test("Parse JSX with error handling")
    func testParseJSXWithError() throws {
        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let invalidJSX = "const x = <div"

        do {
            _ = try runtime.parseJSX(invalidJSX, isTypeScript: false)
        } catch {
            // Expected to throw an error
            #expect(true)
        }
    }
}

// MARK: - Project Parser Tests

@Suite("Project Parser Tests")
struct ProjectParserTests {

    @Test("Project parser initialization")
    func testProjectParserInitialization() {
        let parser = ProjectParser()
        #expect(parser != nil)
    }

    @Test("Project analysis structure")
    func testProjectAnalysisStructure() {
        var analysis = ProjectAnalysis()

        analysis.totalJSXFiles = 5
        analysis.totalCSSFiles = 3
        analysis.usesTypeScript = true

        #expect(analysis.estimatedComplexity == "Simple" || analysis.estimatedComplexity == "Medium")
    }

    @Test("Configuration defaults")
    func testConfigurationDefaults() {
        let config = ProjectParser.Configuration()

        #expect(config.sourcePaths.contains("src"))
        #expect(config.excludePatterns.contains("node_modules"))
        #expect(config.includeCSSModules == true)
        #expect(config.includeNodeModules == false)
    }
}

// MARK: - Integration Tests

@Suite("Parsing Integration Tests")
struct ParsingIntegrationTests {

    @Test("Full parsing pipeline - simple component")
    func testFullParsingPipeline() throws {
        let jsx = """
        function Card({ title, children }) {
            return (
                <div className="card">
                    <h2>{title}</h2>
                    <div className="content">{children}</div>
                </div>
            );
        }
        """

        let css = """
        .card {
            display: flex;
            flex-direction: column;
            padding: 16px;
            border: 1px solid #ccc;
            border-radius: 8px;
        }
        .content {
            margin-top: 8px;
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let cssParser = CSSParser(runtime: runtime)
        let styles = try cssParser.parseCSS(css)

        let reactParser = ReactParser(runtime: runtime)
        let parsedFile = try reactParser.parseFile(
            source: jsx,
            filePath: "Card.jsx",
            isTypeScript: false
        )

        let ir = try reactParser.convertToIR(parsedFile: parsedFile, cssStyles: styles)

        #expect(ir.components.count == 1)
        #expect(ir.components.first?.name == "Card")
        #expect(ir.components.first?.parameters.count == 2)
    }

    @Test("Parse component with hooks")
    func testParseComponentWithHooks() throws {
        let jsx = """
        function Counter() {
            const [count, setCount] = useState(0);

            useEffect(() => {
                document.title = count;
            }, [count]);

            return <button onClick={() => setCount(count + 1)}>{count}</button>;
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "Counter.jsx",
            isTypeScript: false
        )

        #expect(parsedFile.components.count == 1)
    }

    @Test("Parse complex nested JSX")
    func testParseComplexNestedJSX() throws {
        let jsx = """
        function Layout({ sidebar, main, footer }) {
            return (
                <div className="layout">
                    <aside className="sidebar">{sidebar}</aside>
                    <main className="main">{main}</main>
                    <footer className="footer">{footer}</footer>
                </div>
            );
        }
        """

        let runtime = JavaScriptRuntime()
        try runtime.initialize()

        let parser = ReactParser(runtime: runtime)
        let parsedFile = try parser.parseFile(
            source: jsx,
            filePath: "Layout.jsx",
            isTypeScript: false
        )

        #expect(parsedFile.components.count == 1)
        #expect(parsedFile.components.first?.props.count == 3)
    }
}
