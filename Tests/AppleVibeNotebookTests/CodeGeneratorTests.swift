import Testing
@testable import React2SwiftUI

@Suite("Code Generator Tests")
struct CodeGeneratorTests {

    let generator = SwiftSyntaxCodeGenerator()

    // MARK: - Basic View Generation

    @Test("Empty view generates EmptyView()")
    func testEmptyViewGeneratesEmptyView() {
        let code = generator.generateViewCode(from: .empty)

        #expect(code.contains("EmptyView()"))
    }

    @Test("Simple VStack generates correct code")
    func testSimpleVStackGeneratesCorrectCode() {
        let view = ViewIR(
            viewType: .vStack,
            initArguments: [],
            modifiers: [],
            children: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .view(view))

        #expect(code.contains("VStack()"))
    }

    @Test("VStack with spacing generates correct init argument")
    func testVStackWithSpacingGeneratesCorrectInitArgument() {
        let view = ViewIR(
            viewType: .vStack,
            initArguments: [
                InitArgumentIR(label: "spacing", value: .literal("16"))
            ],
            modifiers: [],
            children: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .view(view))

        #expect(code.contains("VStack(spacing: 16)"))
    }

    @Test("HStack with children generates trailing closure")
    func testHStackWithChildrenGeneratesTrailingClosure() {
        let textChild = ViewNodeIR.text(TextIR(
            content: .literal("Hello"),
            modifiers: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 2, startColumn: 0, endLine: 2, endColumn: 10)
        ))

        let view = ViewIR(
            viewType: .hStack,
            initArguments: [],
            modifiers: [],
            children: [textChild],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 3, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .view(view))

        #expect(code.contains("HStack {"))
        #expect(code.contains("Text(\"Hello\")"))
        #expect(code.contains("}"))
    }

    // MARK: - Text Generation

    @Test("Text with literal content generates correctly")
    func testTextWithLiteralContentGeneratesCorrectly() {
        let text = TextIR(
            content: .literal("Hello World"),
            modifiers: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .text(text))

        #expect(code.contains("Text(\"Hello World\")"))
    }

    @Test("Text with interpolation generates correctly")
    func testTextWithInterpolationGeneratesCorrectly() {
        let text = TextIR(
            content: .interpolation("userName"),
            modifiers: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .text(text))

        #expect(code.contains("Text(\"\\(userName)\")"))
    }

    @Test("Text with localized key generates LocalizedStringKey")
    func testTextWithLocalizedKeyGeneratesLocalizedStringKey() {
        let text = TextIR(
            content: .localizedKey("greeting_key"),
            modifiers: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .text(text))

        #expect(code.contains("LocalizedStringKey(\"greeting_key\")"))
    }

    @Test("Text with modifiers generates modifier chain")
    func testTextWithModifiersGeneratesModifierChain() {
        let text = TextIR(
            content: .literal("Bold Text"),
            modifiers: [
                ModifierIR(modifier: .bold, arguments: []),
                ModifierIR(modifier: .foregroundStyle, arguments: [
                    InitArgumentIR(label: nil, value: .literal(".red"))
                ])
            ],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .text(text))

        #expect(code.contains("Text(\"Bold Text\")"))
        #expect(code.contains(".bold()"))
        #expect(code.contains(".foregroundStyle(.red)"))
    }

    // MARK: - Conditional Generation

    @Test("Conditional with true branch only generates if statement")
    func testConditionalWithTrueBranchOnlyGeneratesIfStatement() {
        let conditional = ConditionalIR(
            condition: "isVisible",
            trueBranch: .text(TextIR(
                content: .literal("Visible"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 2, startColumn: 0, endLine: 2, endColumn: 10)
            )),
            falseBranch: nil
        )

        let code = generator.generateViewCode(from: .conditional(conditional))

        #expect(code.contains("if isVisible {"))
        #expect(code.contains("Text(\"Visible\")"))
        #expect(code.contains("}"))
        #expect(!code.contains("else"))
    }

    @Test("Conditional with both branches generates if-else")
    func testConditionalWithBothBranchesGeneratesIfElse() {
        let conditional = ConditionalIR(
            condition: "isLoading",
            trueBranch: .text(TextIR(
                content: .literal("Loading..."),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 2, startColumn: 0, endLine: 2, endColumn: 10)
            )),
            falseBranch: .text(TextIR(
                content: .literal("Loaded"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 3, startColumn: 0, endLine: 3, endColumn: 10)
            ))
        )

        let code = generator.generateViewCode(from: .conditional(conditional))

        #expect(code.contains("if isLoading {"))
        #expect(code.contains("Text(\"Loading...\")"))
        #expect(code.contains("} else {"))
        #expect(code.contains("Text(\"Loaded\")"))
    }

    // MARK: - Loop Generation

    @Test("ForEach loop generates correctly")
    func testForEachLoopGeneratesCorrectly() {
        let loop = LoopIR(
            arrayExpression: "items",
            itemVariable: "item",
            idKeyPath: "\\.id",
            body: .text(TextIR(
                content: .interpolation("item.name"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 2, startColumn: 0, endLine: 2, endColumn: 10)
            ))
        )

        let code = generator.generateViewCode(from: .loop(loop))

        #expect(code.contains("ForEach(items, id: \\.id) { item in"))
        #expect(code.contains("Text(\"\\(item.name)\")"))
        #expect(code.contains("}"))
    }

    @Test("ForEach with self id generates correctly")
    func testForEachWithSelfIdGeneratesCorrectly() {
        let loop = LoopIR(
            arrayExpression: "names",
            itemVariable: "name",
            idKeyPath: "\\.self",
            body: .text(TextIR(
                content: .interpolation("name"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 2, startColumn: 0, endLine: 2, endColumn: 10)
            ))
        )

        let code = generator.generateViewCode(from: .loop(loop))

        #expect(code.contains("ForEach(names, id: \\.self) { name in"))
    }

    // MARK: - Group Generation

    @Test("Empty group generates EmptyView")
    func testEmptyGroupGeneratesEmptyView() {
        let code = generator.generateViewCode(from: .group([]))

        #expect(code.contains("EmptyView()"))
    }

    @Test("Single child group unwraps to child")
    func testSingleChildGroupUnwrapsToChild() {
        let child = ViewNodeIR.text(TextIR(
            content: .literal("Single"),
            modifiers: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        ))

        let code = generator.generateViewCode(from: .group([child]))

        #expect(code.contains("Text(\"Single\")"))
        #expect(!code.contains("Group"))
    }

    @Test("Multiple children group generates Group")
    func testMultipleChildrenGroupGeneratesGroup() {
        let children: [ViewNodeIR] = [
            .text(TextIR(
                content: .literal("First"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
            )),
            .text(TextIR(
                content: .literal("Second"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 2, startColumn: 0, endLine: 2, endColumn: 10)
            ))
        ]

        let code = generator.generateViewCode(from: .group(children))

        #expect(code.contains("Group {"))
        #expect(code.contains("Text(\"First\")"))
        #expect(code.contains("Text(\"Second\")"))
    }

    // MARK: - Unsupported Generation

    @Test("Unsupported generates comment and EmptyView")
    func testUnsupportedGeneratesCommentAndEmptyView() {
        let unsupported = UnsupportedIR(
            originalCode: "::before { content: 'icon' }",
            reason: "CSS pseudo-elements not supported",
            suggestedApproach: "Use ZStack with overlay",
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .unsupported(unsupported))

        #expect(code.contains("// UNSUPPORTED:"))
        #expect(code.contains("CSS pseudo-elements"))
        #expect(code.contains("// Original:"))
        #expect(code.contains("// Suggestion: Use ZStack"))
        #expect(code.contains("EmptyView()"))
    }

    // MARK: - Modifier Generation

    @Test("Modifier with no arguments generates empty parens")
    func testModifierWithNoArgumentsGeneratesEmptyParens() {
        let view = ViewIR(
            viewType: .text,
            initArguments: [],
            modifiers: [
                ModifierIR(modifier: .bold, arguments: [])
            ],
            children: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .view(view))

        #expect(code.contains(".bold()"))
    }

    @Test("Modifier with labeled argument generates correctly")
    func testModifierWithLabeledArgumentGeneratesCorrectly() {
        let view = ViewIR(
            viewType: .rectangle,
            initArguments: [],
            modifiers: [
                ModifierIR(modifier: .frame, arguments: [
                    InitArgumentIR(label: "width", value: .literal("100")),
                    InitArgumentIR(label: "height", value: .literal("50"))
                ])
            ],
            children: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .view(view))

        #expect(code.contains(".frame(width: 100, height: 50)"))
    }

    @Test("Modifier with raw code uses raw code directly")
    func testModifierWithRawCodeUsesRawCodeDirectly() {
        let view = ViewIR(
            viewType: .vStack,
            initArguments: [],
            modifiers: [
                ModifierIR(modifier: .background, arguments: [], rawCode: ".background(LinearGradient(colors: [.red, .blue], startPoint: .top, endPoint: .bottom))")
            ],
            children: [],
            sourceLocation: SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        )

        let code = generator.generateViewCode(from: .view(view))

        #expect(code.contains(".background(LinearGradient"))
    }

    // MARK: - Component Generation

    @Test("Simple component generates struct with body")
    func testSimpleComponentGeneratesStructWithBody() {
        let component = ComponentIR(
            name: "MyButton",
            sourceLocation: SourceLocation(filePath: "MyButton.tsx", startLine: 1, startColumn: 0, endLine: 20, endColumn: 0),
            parameters: [],
            stateProperties: [],
            effects: [],
            viewHierarchy: .text(TextIR(
                content: .literal("Click Me"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "MyButton.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 20)
            ))
        )

        let code = generator.generate(component: component)

        #expect(code.contains("public struct MyButton: View"))
        #expect(code.contains("public var body: some View"))
        #expect(code.contains("Text(\"Click Me\")"))
    }

    @Test("Component with @State generates state property")
    func testComponentWithStateGeneratesStateProperty() {
        let component = ComponentIR(
            name: "Counter",
            sourceLocation: SourceLocation(filePath: "Counter.tsx", startLine: 1, startColumn: 0, endLine: 20, endColumn: 0),
            parameters: [],
            stateProperties: [
                StatePropertyIR(name: "count", type: "Int", initialValue: "0")
            ],
            effects: [],
            viewHierarchy: .text(TextIR(
                content: .interpolation("count"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "Counter.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 20)
            ))
        )

        let code = generator.generate(component: component)

        #expect(code.contains("@State"))
        #expect(code.contains("private"))
        #expect(code.contains("var count: Int = 0"))
    }

    @Test("Component with parameters generates properties")
    func testComponentWithParametersGeneratesProperties() {
        let component = ComponentIR(
            name: "Greeting",
            sourceLocation: SourceLocation(filePath: "Greeting.tsx", startLine: 1, startColumn: 0, endLine: 20, endColumn: 0),
            parameters: [
                ParameterIR(name: "name", type: "String"),
                ParameterIR(name: "showIcon", type: "Bool", defaultValue: "true")
            ],
            stateProperties: [],
            effects: [],
            viewHierarchy: .text(TextIR(
                content: .interpolation("name"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "Greeting.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 20)
            ))
        )

        let code = generator.generate(component: component)

        #expect(code.contains("let name: String"))
        #expect(code.contains("let showIcon: Bool = true"))
    }

    @Test("Component with @Binding generates binding property and init")
    func testComponentWithBindingGeneratesBindingPropertyAndInit() {
        let component = ComponentIR(
            name: "Toggle",
            sourceLocation: SourceLocation(filePath: "Toggle.tsx", startLine: 1, startColumn: 0, endLine: 20, endColumn: 0),
            parameters: [
                ParameterIR(name: "isOn", type: "Bool", isBinding: true)
            ],
            stateProperties: [],
            effects: [],
            viewHierarchy: .view(ViewIR(
                viewType: .toggle,
                initArguments: [
                    InitArgumentIR(label: "isOn", value: .binding("isOn"))
                ],
                modifiers: [],
                children: [],
                sourceLocation: SourceLocation(filePath: "Toggle.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 20)
            ))
        )

        let code = generator.generate(component: component)

        #expect(code.contains("@Binding var isOn: Bool"))
        #expect(code.contains("public init("))
        #expect(code.contains("isOn: Binding<Bool>"))
        #expect(code.contains("self._isOn = isOn"))
    }

    @Test("Component with @ViewBuilder generates closure property")
    func testComponentWithViewBuilderGeneratesClosureProperty() {
        let component = ComponentIR(
            name: "Card",
            sourceLocation: SourceLocation(filePath: "Card.tsx", startLine: 1, startColumn: 0, endLine: 20, endColumn: 0),
            parameters: [
                ParameterIR(name: "content", type: "Content", isViewBuilder: true)
            ],
            stateProperties: [],
            effects: [],
            viewHierarchy: .view(ViewIR(
                viewType: .vStack,
                initArguments: [],
                modifiers: [],
                children: [],
                sourceLocation: SourceLocation(filePath: "Card.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 20)
            )),
            genericParameters: ["Content"]
        )

        let code = generator.generate(component: component)

        #expect(code.contains("struct Card<Content: View>: View"))
        #expect(code.contains("@ViewBuilder let content: () -> Content"))
        #expect(code.contains("@ViewBuilder content: @escaping () -> Content"))
    }

    @Test("Component with effects generates lifecycle modifiers")
    func testComponentWithEffectsGeneratesLifecycleModifiers() {
        let component = ComponentIR(
            name: "DataLoader",
            sourceLocation: SourceLocation(filePath: "DataLoader.tsx", startLine: 1, startColumn: 0, endLine: 20, endColumn: 0),
            parameters: [],
            stateProperties: [
                StatePropertyIR(name: "data", type: "String", initialValue: "\"\"")
            ],
            effects: [
                EffectIR(modifier: .onAppear, dependencies: [], body: "loadData()")
            ],
            viewHierarchy: .text(TextIR(
                content: .interpolation("data"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "DataLoader.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 20)
            ))
        )

        let code = generator.generate(component: component)

        #expect(code.contains(".onAppear {"))
        #expect(code.contains("loadData()"))
    }

    // MARK: - Full IR Generation

    @Test("Full IR generates multiple files")
    func testFullIRGeneratesMultipleFiles() {
        let component = ComponentIR(
            name: "App",
            sourceLocation: SourceLocation(filePath: "App.tsx", startLine: 1, startColumn: 0, endLine: 20, endColumn: 0),
            parameters: [],
            stateProperties: [],
            effects: [],
            viewHierarchy: .text(TextIR(
                content: .literal("Hello"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "App.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 20)
            ))
        )

        let sourceFile = SourceFileIR(
            originalPath: "App.tsx",
            components: [component],
            imports: [],
            exports: []
        )

        let globalStyles = GlobalStylesIR(
            colors: ["primary": CSSColor(red: 0, green: 0, blue: 1)],
            fonts: [:],
            spacing: ["small": 8, "medium": 16],
            cornerRadii: ["default": 8],
            shadows: [:]
        )

        let ir = IntermediateRepresentation(
            sourceFiles: [sourceFile],
            globalStyles: globalStyles,
            metadata: ConversionMetadata(
                sourceProjectName: "TestProject",
                sourceProjectPath: "/test"
            )
        )

        let files = generator.generate(from: ir)

        #expect(files.count == 2)

        let appFile = files.first { $0.path == "App.swift" }
        #expect(appFile != nil)
        #expect(appFile?.content.contains("struct App: View") == true)

        let tokensFile = files.first { $0.path == "DesignTokens.swift" }
        #expect(tokensFile != nil)
        #expect(tokensFile?.content.contains("extension Color") == true)
        #expect(tokensFile?.content.contains("static let primary") == true)
        #expect(tokensFile?.content.contains("enum Spacing") == true)
    }

    // MARK: - Design Tokens Generation

    @Test("Design tokens generates Color extension")
    func testDesignTokensGeneratesColorExtension() {
        let sourceFile = SourceFileIR(originalPath: "App.tsx", components: [], imports: [], exports: [])

        let globalStyles = GlobalStylesIR(
            colors: [
                "primary": CSSColor(red: 0.2, green: 0.4, blue: 0.8),
                "accent": CSSColor(red: 1, green: 0.5, blue: 0, alpha: 0.9)
            ],
            fonts: [:],
            spacing: [:],
            cornerRadii: [:],
            shadows: [:]
        )

        let ir = IntermediateRepresentation(
            sourceFiles: [sourceFile],
            globalStyles: globalStyles,
            metadata: ConversionMetadata(sourceProjectName: "Test", sourceProjectPath: "/test")
        )

        let files = generator.generate(from: ir)
        let tokensFile = files.first { $0.path == "DesignTokens.swift" }

        #expect(tokensFile != nil)
        #expect(tokensFile?.content.contains("extension Color") == true)
        #expect(tokensFile?.content.contains("static let primary") == true)
        #expect(tokensFile?.content.contains("static let accent") == true)
        #expect(tokensFile?.content.contains("opacity: 0.9") == true)
    }

    @Test("Design tokens generates Font extension")
    func testDesignTokensGeneratesFontExtension() {
        let sourceFile = SourceFileIR(originalPath: "App.tsx", components: [], imports: [], exports: [])

        let globalStyles = GlobalStylesIR(
            colors: [:],
            fonts: [
                "heading": FontDefinitionIR(family: nil, size: 24, weight: ".bold", design: nil),
                "body": FontDefinitionIR(family: nil, size: 16, weight: nil, design: ".rounded")
            ],
            spacing: [:],
            cornerRadii: [:],
            shadows: [:]
        )

        let ir = IntermediateRepresentation(
            sourceFiles: [sourceFile],
            globalStyles: globalStyles,
            metadata: ConversionMetadata(sourceProjectName: "Test", sourceProjectPath: "/test")
        )

        let files = generator.generate(from: ir)
        let tokensFile = files.first { $0.path == "DesignTokens.swift" }

        #expect(tokensFile != nil)
        #expect(tokensFile?.content.contains("extension Font") == true)
        #expect(tokensFile?.content.contains("static let heading") == true)
        #expect(tokensFile?.content.contains("weight: .bold") == true)
        #expect(tokensFile?.content.contains("design: .rounded") == true)
    }

    // MARK: - Preview Provider Generation

    @Test("Preview provider is generated when enabled")
    func testPreviewProviderIsGeneratedWhenEnabled() {
        let config = SwiftSyntaxCodeGenerator.Configuration(generatePreviewProvider: true)
        let generator = SwiftSyntaxCodeGenerator(configuration: config)

        let component = ComponentIR(
            name: "Button",
            sourceLocation: SourceLocation(filePath: "Button.tsx", startLine: 1, startColumn: 0, endLine: 10, endColumn: 0),
            parameters: [],
            stateProperties: [],
            effects: [],
            viewHierarchy: .text(TextIR(
                content: .literal("Click"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "Button.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 10)
            ))
        )

        let sourceFile = SourceFileIR(originalPath: "Button.tsx", components: [component], imports: [], exports: [])
        let ir = IntermediateRepresentation(
            sourceFiles: [sourceFile],
            globalStyles: GlobalStylesIR(),
            metadata: ConversionMetadata(sourceProjectName: "Test", sourceProjectPath: "/test")
        )

        let files = generator.generate(from: ir)
        let buttonFile = files.first { $0.path == "Button.swift" }

        #expect(buttonFile != nil)
        #expect(buttonFile?.content.contains("Button_Previews: PreviewProvider") == true)
        #expect(buttonFile?.content.contains("static var previews: some View") == true)
    }

    @Test("Preview provider is not generated when disabled")
    func testPreviewProviderIsNotGeneratedWhenDisabled() {
        let config = SwiftSyntaxCodeGenerator.Configuration(generatePreviewProvider: false)
        let generator = SwiftSyntaxCodeGenerator(configuration: config)

        let component = ComponentIR(
            name: "Button",
            sourceLocation: SourceLocation(filePath: "Button.tsx", startLine: 1, startColumn: 0, endLine: 10, endColumn: 0),
            parameters: [],
            stateProperties: [],
            effects: [],
            viewHierarchy: .text(TextIR(
                content: .literal("Click"),
                modifiers: [],
                sourceLocation: SourceLocation(filePath: "Button.tsx", startLine: 5, startColumn: 0, endLine: 5, endColumn: 10)
            ))
        )

        let sourceFile = SourceFileIR(originalPath: "Button.tsx", components: [component], imports: [], exports: [])
        let ir = IntermediateRepresentation(
            sourceFiles: [sourceFile],
            globalStyles: GlobalStylesIR(),
            metadata: ConversionMetadata(sourceProjectName: "Test", sourceProjectPath: "/test")
        )

        let files = generator.generate(from: ir)
        let buttonFile = files.first { $0.path == "Button.swift" }

        #expect(buttonFile != nil)
        #expect(buttonFile?.content.contains("PreviewProvider") == false)
    }

    // MARK: - Access Level Configuration

    @Test("Public access level generates public keyword")
    func testPublicAccessLevelGeneratesPublicKeyword() {
        let config = SwiftSyntaxCodeGenerator.Configuration(accessLevel: .public)
        let generator = SwiftSyntaxCodeGenerator(configuration: config)

        let component = ComponentIR(
            name: "Widget",
            sourceLocation: SourceLocation(filePath: "Widget.tsx", startLine: 1, startColumn: 0, endLine: 10, endColumn: 0),
            parameters: [],
            stateProperties: [],
            effects: [],
            viewHierarchy: .empty
        )

        let code = generator.generate(component: component)

        #expect(code.contains("public struct Widget"))
        #expect(code.contains("public var body"))
    }

    @Test("Internal access level generates internal keyword")
    func testInternalAccessLevelGeneratesInternalKeyword() {
        let config = SwiftSyntaxCodeGenerator.Configuration(accessLevel: .internal)
        let generator = SwiftSyntaxCodeGenerator(configuration: config)

        let component = ComponentIR(
            name: "Widget",
            sourceLocation: SourceLocation(filePath: "Widget.tsx", startLine: 1, startColumn: 0, endLine: 10, endColumn: 0),
            parameters: [],
            stateProperties: [],
            effects: [],
            viewHierarchy: .empty
        )

        let code = generator.generate(component: component)

        #expect(code.contains("internal struct Widget"))
        #expect(code.contains("internal var body"))
    }
}
