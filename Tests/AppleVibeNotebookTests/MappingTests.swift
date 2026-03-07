import Testing
@testable import React2SwiftUI

@Suite("Layout Mapping Tests")
struct LayoutMappingTests {

    // MARK: - Flex Direction Tests

    @Test("Row flex direction maps to HStack")
    func testRowFlexDirectionMapsToHStack() {
        let result = LayoutMapping.stackType(for: .row, flexWrap: .nowrap)

        #expect(result.viewType == .hStack)
        #expect(result.tier == .direct)
    }

    @Test("Column flex direction maps to VStack")
    func testColumnFlexDirectionMapsToVStack() {
        let result = LayoutMapping.stackType(for: .column, flexWrap: .nowrap)

        #expect(result.viewType == .vStack)
        #expect(result.tier == .direct)
    }

    @Test("Row-reverse flex direction maps to HStack")
    func testRowReverseFlexDirectionMapsToHStack() {
        let result = LayoutMapping.stackType(for: .rowReverse, flexWrap: .nowrap)

        #expect(result.viewType == .hStack)
        #expect(result.tier == .direct)
    }

    @Test("Column-reverse flex direction maps to VStack")
    func testColumnReverseFlexDirectionMapsToVStack() {
        let result = LayoutMapping.stackType(for: .columnReverse, flexWrap: .nowrap)

        #expect(result.viewType == .vStack)
        #expect(result.tier == .direct)
    }

    // MARK: - Flex Wrap Tests

    @Test("Row with flex-wrap maps to LazyVGrid")
    func testRowWithFlexWrapMapsToLazyVGrid() {
        let result = LayoutMapping.stackType(for: .row, flexWrap: .wrap)

        #expect(result.viewType == .lazyVGrid)
        #expect(result.tier == .adapted)
    }

    @Test("Column with flex-wrap maps to LazyHGrid")
    func testColumnWithFlexWrapMapsToLazyHGrid() {
        let result = LayoutMapping.stackType(for: .column, flexWrap: .wrap)

        #expect(result.viewType == .lazyHGrid)
        #expect(result.tier == .adapted)
    }

    // MARK: - Justify Content Tests

    @Test("justify-content:center maps to center alignment with spacers")
    func testJustifyContentCenter() {
        let result = LayoutMapping.justifyContentMapping(.center, isHorizontal: true)

        #expect(result.alignment == .center)
        #expect(result.requiresSpacer == true)
        #expect(result.spacerPosition == .both)
        #expect(result.tier == .direct)
    }

    @Test("justify-content:flex-start maps to leading alignment")
    func testJustifyContentFlexStart() {
        let result = LayoutMapping.justifyContentMapping(.flexStart, isHorizontal: true)

        #expect(result.alignment == .leading)
        #expect(result.requiresSpacer == false)
        #expect(result.tier == .direct)
    }

    @Test("justify-content:space-between is adapted")
    func testJustifyContentSpaceBetween() {
        let result = LayoutMapping.justifyContentMapping(.spaceBetween, isHorizontal: true)

        #expect(result.spacerPosition == .between)
        #expect(result.tier == .adapted)
    }

    // MARK: - Align Items Tests

    @Test("align-items:center maps to center alignment")
    func testAlignItemsCenter() {
        let result = LayoutMapping.alignItemsMapping(.center, isHorizontal: true)

        #expect(result.alignment == .center)
        #expect(result.tier == .direct)
    }

    @Test("align-items:stretch requires frame modifier")
    func testAlignItemsStretch() {
        let result = LayoutMapping.alignItemsMapping(.stretch, isHorizontal: true)

        #expect(result.requiresFrameModifier == true)
        #expect(result.tier == .adapted)
    }

    // MARK: - Gap Tests

    @Test("CSS gap maps to spacing parameter")
    func testGapMapsToSpacing() {
        let gap = CSSLength(value: 16, unit: .px)
        let result = LayoutMapping.gapMapping(gap)

        #expect(result.spacing == 16)
        #expect(result.tier == .direct)
    }

    @Test("No gap uses default spacing")
    func testNoGapUsesDefault() {
        let result = LayoutMapping.gapMapping(nil)

        #expect(result.spacing == nil)
        #expect(result.tier == .direct)
    }

    // MARK: - Position Tests

    @Test("position:absolute requires ZStack")
    func testPositionAbsoluteRequiresZStack() {
        let top = CSSLength(value: 10, unit: .px)
        let left = CSSLength(value: 20, unit: .px)

        let result = LayoutMapping.positionMapping(.absolute, top: top, right: nil, bottom: nil, left: left)

        #expect(result.requiresZStack == true)
        #expect(result.tier == .adapted)
    }

    @Test("position:relative with offset maps to .offset")
    func testPositionRelativeWithOffset() {
        let left = CSSLength(value: 10, unit: .px)

        let result = LayoutMapping.positionMapping(.relative, top: nil, right: nil, bottom: nil, left: left)

        #expect(result.requiresZStack == false)
        #expect(result.offset?.x == 10)
        #expect(result.tier == .direct)
    }

    @Test("position:fixed is unsupported")
    func testPositionFixedIsUnsupported() {
        let result = LayoutMapping.positionMapping(.fixed, top: nil, right: nil, bottom: nil, left: nil)

        #expect(result.tier == .unsupported)
    }

    @Test("position:sticky is unsupported")
    func testPositionStickyIsUnsupported() {
        let result = LayoutMapping.positionMapping(.sticky, top: nil, right: nil, bottom: nil, left: nil)

        #expect(result.tier == .unsupported)
    }

    // MARK: - Overflow Tests

    @Test("overflow-y:scroll maps to ScrollView(.vertical)")
    func testOverflowYScrollMapsToVerticalScrollView() {
        let result = LayoutMapping.overflowMapping(overflowX: .visible, overflowY: .scroll)

        #expect(result.wrapInScrollView == true)
        #expect(result.scrollAxes.contains(.vertical))
        #expect(!result.scrollAxes.contains(.horizontal))
        #expect(result.tier == .direct)
    }

    @Test("overflow:hidden maps to clipped")
    func testOverflowHiddenMapsToClipped() {
        let result = LayoutMapping.overflowMapping(overflowX: .hidden, overflowY: .hidden)

        #expect(result.clipsContent == true)
        #expect(result.wrapInScrollView == false)
        #expect(result.tier == .direct)
    }

    // MARK: - Grid Tests

    @Test("Simple grid columns map to LazyVGrid")
    func testSimpleGridColumnsMapToLazyVGrid() {
        let template = CSSGridTemplate(
            columns: [.fr(1), .fr(1), .fr(1)],
            rows: [],
            columnGap: CSSLength(value: 8, unit: .px)
        )

        let result = LayoutMapping.gridMapping(template)

        #expect(result.viewType == .lazyVGrid)
        #expect(result.columns.count == 3)
        #expect(result.spacing == 8)
        #expect(result.tier == .direct)
    }

    @Test("Grid with repeat auto-fit maps to adaptive")
    func testGridWithRepeatAutoFitMapsToAdaptive() {
        let template = CSSGridTemplate(
            columns: [
                .repeatTrack(count: .autoFit, tracks: [.length(CSSLength(value: 200, unit: .px))])
            ]
        )

        let result = LayoutMapping.gridMapping(template)

        #expect(result.viewType == .lazyVGrid)
        if case .adaptive(let min) = result.columns.first {
            #expect(min == 200)
        } else {
            Issue.record("Expected adaptive column")
        }
    }
}

@Suite("Component Mapping Tests")
struct ComponentMappingTests {

    // MARK: - Basic HTML Elements

    @Test("div with flex row maps to HStack")
    func testDivWithFlexRowMapsToHStack() {
        var style = ComputedCSSStyle()
        style.display = .flex
        style.flexDirection = .row

        let result = ComponentMapping.viewType(for: .div, computedStyle: style)

        #expect(result.viewType == .hStack)
        #expect(result.tier == .direct)
    }

    @Test("button maps to Button")
    func testButtonMapsToButton() {
        let result = ComponentMapping.viewType(for: .button)

        #expect(result.viewType == .button)
        #expect(result.tier == .direct)
    }

    @Test("input type=text maps to TextField")
    func testInputTextMapsToTextField() {
        let result = ComponentMapping.viewType(for: .input, inputType: .text)

        #expect(result.viewType == .textField)
        #expect(result.tier == .direct)
    }

    @Test("input type=password maps to SecureField")
    func testInputPasswordMapsToSecureField() {
        let result = ComponentMapping.viewType(for: .input, inputType: .password)

        #expect(result.viewType == .secureField)
        #expect(result.tier == .direct)
    }

    @Test("input type=checkbox maps to Toggle")
    func testInputCheckboxMapsToToggle() {
        let result = ComponentMapping.viewType(for: .input, inputType: .checkbox)

        #expect(result.viewType == .toggle)
        #expect(result.tier == .direct)
    }

    @Test("input type=date maps to DatePicker")
    func testInputDateMapsToDatePicker() {
        let result = ComponentMapping.viewType(for: .input, inputType: .date)

        #expect(result.viewType == .datePicker)
        #expect(result.tier == .direct)
    }

    @Test("select maps to Picker")
    func testSelectMapsToPicker() {
        let result = ComponentMapping.viewType(for: .select)

        #expect(result.viewType == .picker)
        #expect(result.tier == .direct)
    }

    @Test("textarea maps to TextEditor")
    func testTextareaMapsToTextEditor() {
        let result = ComponentMapping.viewType(for: .textarea)

        #expect(result.viewType == .textEditor)
        #expect(result.tier == .direct)
    }

    // MARK: - Text Elements

    @Test("h1 maps to Text with largeTitle")
    func testH1MapsToTextWithLargeTitle() {
        let result = ComponentMapping.viewType(for: .h1)

        #expect(result.viewType == .text)
        #expect(result.modifiers.contains(.font))
        #expect(result.modifierValues[".font"] == ".largeTitle")
        #expect(result.tier == .direct)
    }

    @Test("p maps to Text with padding")
    func testPMapsToTextWithPadding() {
        let result = ComponentMapping.viewType(for: .p)

        #expect(result.viewType == .text)
        #expect(result.modifiers.contains(.padding))
        #expect(result.tier == .direct)
    }

    @Test("strong maps to Text with bold")
    func testStrongMapsToTextWithBold() {
        let result = ComponentMapping.viewType(for: .strong)

        #expect(result.viewType == .text)
        #expect(result.modifiers.contains(.bold))
        #expect(result.tier == .direct)
    }

    // MARK: - Media Elements

    @Test("img maps to AsyncImage")
    func testImgMapsToAsyncImage() {
        let result = ComponentMapping.viewType(for: .img)

        #expect(result.viewType == .asyncImage)
        #expect(result.tier == .direct)
    }

    @Test("a maps to Link")
    func testAMapsToLink() {
        let result = ComponentMapping.viewType(for: .a)

        #expect(result.viewType == .link)
        #expect(result.tier == .direct)
    }

    // MARK: - Table Elements

    @Test("table maps to Grid")
    func testTableMapsToGrid() {
        let result = ComponentMapping.viewType(for: .table)

        #expect(result.viewType == .grid)
        #expect(result.tier == .adapted)
    }

    @Test("details maps to DisclosureGroup")
    func testDetailsMapsToDisclosureGroup() {
        let result = ComponentMapping.viewType(for: .details)

        #expect(result.viewType == .disclosureGroup)
        #expect(result.tier == .direct)
    }

    // MARK: - Event Mapping Tests

    @Test("onClick maps to onTapGesture")
    func testOnClickMapsToOnTapGesture() {
        let result = ComponentMapping.eventMapping(.onClick)

        #expect(result.modifier == .onTapGesture)
        #expect(result.tier == .direct)
    }

    @Test("onDoubleClick maps to onTapGesture with count 2")
    func testOnDoubleClickMapsToOnTapGestureCount2() {
        let result = ComponentMapping.eventMapping(.onDoubleClick)

        #expect(result.modifier == .onTapGesture)
        #expect(result.modifierParameters == "count: 2")
        #expect(result.tier == .direct)
    }

    @Test("onSubmit maps directly")
    func testOnSubmitMapsDirect() {
        let result = ComponentMapping.eventMapping(.onSubmit)

        #expect(result.modifier == .onSubmit)
        #expect(result.tier == .direct)
    }
}

@Suite("State Mapping Tests")
struct StateMappingTests {

    // MARK: - Hook Mapping Tests

    @Test("useState maps to @State")
    func testUseStateMapsToState() {
        let result = StateMapping.propertyWrapper(for: .useState)

        #expect(result.propertyWrapper == .state)
        #expect(result.tier == .direct)
    }

    @Test("useEffect maps to lifecycle modifiers")
    func testUseEffectMapsToLifecycleModifiers() {
        let result = StateMapping.propertyWrapper(for: .useEffect)

        #expect(result.lifecycleModifier == .onAppear)
        #expect(result.additionalModifiers.contains(.onChange))
        #expect(result.tier == .direct)
    }

    @Test("useContext maps to @EnvironmentObject")
    func testUseContextMapsToEnvironmentObject() {
        let result = StateMapping.propertyWrapper(for: .useContext)

        #expect(result.propertyWrapper == .environmentObject)
        #expect(result.tier == .adapted)
    }

    @Test("useRef maps to @FocusState")
    func testUseRefMapsToFocusState() {
        let result = StateMapping.propertyWrapper(for: .useRef)

        #expect(result.propertyWrapper == .focusState)
        #expect(result.tier == .adapted)
    }

    @Test("useMemo is unnecessary in SwiftUI")
    func testUseMemoIsUnnecessary() {
        let result = StateMapping.propertyWrapper(for: .useMemo)

        #expect(result.propertyWrapper == nil)
        #expect(result.tier == .direct)
    }

    @Test("useCallback is unnecessary in SwiftUI")
    func testUseCallbackIsUnnecessary() {
        let result = StateMapping.propertyWrapper(for: .useCallback)

        #expect(result.propertyWrapper == nil)
        #expect(result.tier == .direct)
    }

    // MARK: - Effect Analysis Tests

    @Test("Empty deps array maps to onAppear")
    func testEmptyDepsArrayMapsToOnAppear() {
        let result = StateMapping.analyzeEffect(dependencies: [], hasCleanup: false)

        #expect(result.pattern == .mountOnly)
        #expect(result.modifiers.contains(.onAppear))
        #expect(result.tier == .direct)
    }

    @Test("Empty deps with cleanup includes onDisappear")
    func testEmptyDepsWithCleanupIncludesOnDisappear() {
        let result = StateMapping.analyzeEffect(dependencies: [], hasCleanup: true)

        #expect(result.modifiers.contains(.onAppear))
        #expect(result.modifiers.contains(.onDisappear))
    }

    @Test("Single dependency maps to onChange")
    func testSingleDependencyMapsToOnChange() {
        let result = StateMapping.analyzeEffect(dependencies: ["count"], hasCleanup: false)

        if case .singleDependency(let dep) = result.pattern {
            #expect(dep == "count")
        } else {
            Issue.record("Expected single dependency pattern")
        }
        #expect(result.modifiers.contains(.onChange))
        #expect(result.tier == .direct)
    }

    // MARK: - Animation Mapping Tests

    @Test("CSS ease timing maps to easeInOut")
    func testCSSEaseTimingMapsToEaseInOut() {
        let result = AnimationMapping.animationCurve(from: .ease, duration: 0.3)

        #expect(result.animation.contains("easeInOut"))
        #expect(result.animation.contains("0.3"))
        #expect(result.tier == .direct)
    }

    @Test("CSS linear timing maps to linear")
    func testCSSLinearTimingMapsToLinear() {
        let result = AnimationMapping.animationCurve(from: .linear, duration: 0.5)

        #expect(result.animation.contains("linear"))
        #expect(result.tier == .direct)
    }
}

@Suite("Styling Mapping Tests")
struct StylingMappingTests {

    // MARK: - Background Tests

    @Test("Background color maps to .background")
    func testBackgroundColorMapsToBackground() {
        let color = CSSColor(red: 1, green: 0, blue: 0)
        let result = StylingMapping.backgroundColorMapping(color)

        #expect(result.modifier == .background)
        #expect(result.tier == .direct)
    }

    // MARK: - Typography Tests

    @Test("Font size maps to .font")
    func testFontSizeMapsToFont() {
        let size = CSSLength(value: 16, unit: .px)
        let result = StylingMapping.fontMapping(fontSize: size, fontWeight: nil, fontFamily: nil, fontStyle: nil)

        #expect(!result.modifiers.isEmpty)
        #expect(result.modifiers.first?.contains(".font") == true)
        #expect(result.tier == .direct)
    }

    @Test("Font weight bold maps to .fontWeight(.bold)")
    func testFontWeightBoldMapsToBold() {
        let result = StylingMapping.fontMapping(fontSize: nil, fontWeight: .bold, fontFamily: nil, fontStyle: nil)

        #expect(result.modifiers.contains { $0.contains(".fontWeight(.bold)") })
    }

    @Test("text-decoration:underline maps to .underline")
    func testTextDecorationUnderlineMapsToUnderline() {
        let result = StylingMapping.textDecorationMapping(.underline)

        #expect(result.modifier == .underline)
        #expect(result.code.contains(".underline()"))
        #expect(result.tier == .direct)
    }

    @Test("text-transform:uppercase maps to .textCase")
    func testTextTransformUppercaseMapsToTextCase() {
        let result = StylingMapping.textTransformMapping(.uppercase)

        #expect(result.modifier == .textCase)
        #expect(result.code.contains(".uppercase"))
        #expect(result.tier == .direct)
    }

    // MARK: - Sizing Tests

    @Test("Width and height map to .frame")
    func testWidthAndHeightMapToFrame() {
        let width = CSSLength(value: 100, unit: .px)
        let height = CSSLength(value: 50, unit: .px)

        let result = StylingMapping.sizeMapping(
            width: width, height: height,
            minWidth: nil, maxWidth: nil,
            minHeight: nil, maxHeight: nil
        )

        #expect(result.modifier == .frame)
        #expect(result.code.contains("width: 100"))
        #expect(result.code.contains("height: 50"))
        #expect(result.tier == .direct)
    }

    @Test("Percentage width maps to .infinity")
    func testPercentageWidthMapsToInfinity() {
        let width = CSSLength(value: 100, unit: .percent)

        let result = StylingMapping.sizeMapping(
            width: width, height: nil,
            minWidth: nil, maxWidth: nil,
            minHeight: nil, maxHeight: nil
        )

        #expect(result.code.contains("maxWidth: .infinity"))
        #expect(result.tier == .adapted)
    }

    // MARK: - Spacing Tests

    @Test("Uniform padding maps to .padding(value)")
    func testUniformPaddingMapsToPaddingValue() {
        let padding = CSSLength(value: 16, unit: .px)

        let result = StylingMapping.paddingMapping(
            top: padding, right: padding, bottom: padding, left: padding
        )

        #expect(result.code.contains(".padding(16"))
        #expect(result.tier == .direct)
    }

    @Test("Margin is adapted to padding on parent")
    func testMarginIsAdaptedToPaddingOnParent() {
        let margin = CSSLength(value: 8, unit: .px)

        let result = StylingMapping.marginMapping(
            top: margin, right: nil, bottom: nil, left: nil
        )

        #expect(result.tier == .adapted)
        #expect(result.code.contains("margin"))
    }

    // MARK: - Border Tests

    @Test("Solid border maps to overlay with stroke")
    func testSolidBorderMapsToOverlayWithStroke() {
        let border = CSSBorder(
            width: CSSLength(value: 1, unit: .px),
            style: .solid,
            color: CSSColor(red: 0, green: 0, blue: 0)
        )

        let result = StylingMapping.borderMapping(border)

        #expect(result.modifier == .overlay)
        #expect(result.code.contains(".stroke"))
        #expect(result.tier == .direct)
    }

    @Test("Uniform border-radius maps to RoundedRectangle")
    func testUniformBorderRadiusMapsToRoundedRectangle() {
        let radius = CSSLength(value: 8, unit: .px)

        let result = StylingMapping.borderRadiusMapping(
            topLeft: radius, topRight: radius,
            bottomRight: radius, bottomLeft: radius
        )

        #expect(result.code.contains("RoundedRectangle"))
        #expect(result.code.contains("cornerRadius: 8"))
        #expect(result.tier == .direct)
    }

    @Test("Large border-radius maps to Circle")
    func testLargeBorderRadiusMapsToCircle() {
        let radius = CSSLength(value: 9999, unit: .px)

        let result = StylingMapping.borderRadiusMapping(
            topLeft: radius, topRight: radius,
            bottomRight: radius, bottomLeft: radius
        )

        #expect(result.code.contains("Circle()"))
        #expect(result.tier == .direct)
    }

    @Test("Non-uniform border-radius maps to UnevenRoundedRectangle")
    func testNonUniformBorderRadiusMapsToUneven() {
        let result = StylingMapping.borderRadiusMapping(
            topLeft: CSSLength(value: 8, unit: .px),
            topRight: CSSLength(value: 0, unit: .px),
            bottomRight: CSSLength(value: 8, unit: .px),
            bottomLeft: CSSLength(value: 0, unit: .px)
        )

        #expect(result.code.contains("UnevenRoundedRectangle"))
        #expect(result.tier == .direct)
    }

    // MARK: - Effects Tests

    @Test("Opacity maps directly")
    func testOpacityMapsDirect() {
        let result = StylingMapping.opacityMapping(0.5)

        #expect(result.modifier == .opacity)
        #expect(result.code.contains(".opacity(0.5)"))
        #expect(result.tier == .direct)
    }

    @Test("Box shadow maps to .shadow")
    func testBoxShadowMapsToShadow() {
        let shadow = CSSBoxShadow(
            offsetX: CSSLength(value: 2, unit: .px),
            offsetY: CSSLength(value: 4, unit: .px),
            blurRadius: CSSLength(value: 8, unit: .px),
            color: CSSColor(red: 0, green: 0, blue: 0, alpha: 0.25)
        )

        let result = StylingMapping.shadowMapping(shadow)

        #expect(result.modifier == .shadow)
        #expect(result.code.contains(".shadow"))
        #expect(result.tier == .direct)
    }

    @Test("Inset box shadow is unsupported")
    func testInsetBoxShadowIsUnsupported() {
        let shadow = CSSBoxShadow(
            offsetX: CSSLength(value: 0, unit: .px),
            offsetY: CSSLength(value: 0, unit: .px),
            blurRadius: CSSLength(value: 4, unit: .px),
            color: CSSColor(red: 0, green: 0, blue: 0),
            inset: true
        )

        let result = StylingMapping.shadowMapping(shadow)

        #expect(result.tier == .unsupported)
    }

    // MARK: - Transform Tests

    @Test("Translate maps to .offset")
    func testTranslateMapsToOffset() {
        let transforms: [CSSTransformFunction] = [
            .translate(x: CSSLength(value: 10, unit: .px), y: CSSLength(value: 20, unit: .px))
        ]

        let result = StylingMapping.transformMapping(transforms)

        #expect(result.modifiers.first?.contains(".offset") == true)
        #expect(result.tier == .direct)
    }

    @Test("Rotate maps to .rotationEffect")
    func testRotateMapsToRotationEffect() {
        let transforms: [CSSTransformFunction] = [.rotate(degrees: 45)]

        let result = StylingMapping.transformMapping(transforms)

        #expect(result.modifiers.first?.contains(".rotationEffect") == true)
        #expect(result.tier == .direct)
    }

    @Test("Scale maps to .scaleEffect")
    func testScaleMapsToScaleEffect() {
        let transforms: [CSSTransformFunction] = [.scale(x: 2, y: 2)]

        let result = StylingMapping.transformMapping(transforms)

        #expect(result.modifiers.first?.contains(".scaleEffect(2)") == true)
        #expect(result.tier == .direct)
    }

    @Test("Skew is adapted with CGAffineTransform")
    func testSkewIsAdapted() {
        let transforms: [CSSTransformFunction] = [.skew(x: 10, y: 0)]

        let result = StylingMapping.transformMapping(transforms)

        #expect(result.tier == .adapted)
        #expect(result.modifiers.contains { $0.contains("CGAffineTransform") })
    }

    // MARK: - Z-Index Tests

    @Test("z-index maps to .zIndex")
    func testZIndexMapsToZIndex() {
        let result = StylingMapping.zIndexMapping(10)

        #expect(result.modifier == .zIndex)
        #expect(result.code.contains(".zIndex(10)"))
        #expect(result.tier == .direct)
    }

    // MARK: - Visibility Tests

    @Test("visibility:hidden maps to .hidden")
    func testVisibilityHiddenMapsToHidden() {
        let result = StylingMapping.visibilityMapping("hidden")

        #expect(result.modifier == .hidden)
        #expect(result.tier == .direct)
    }
}

@Suite("Conversion Report Tests")
struct ConversionReportTests {

    @Test("Summary calculates percentages correctly")
    func testSummaryCalculatesPercentages() {
        let summary = ConversionSummary(
            totalConversions: 100,
            directMatches: 80,
            adaptedMatches: 15,
            unsupportedCount: 5
        )

        #expect(summary.directMatchPercentage == 80.0)
        #expect(summary.adaptedMatchPercentage == 15.0)
        #expect(summary.unsupportedPercentage == 5.0)
    }

    @Test("Summary from entries counts tiers correctly")
    func testSummaryFromEntriesCountsTiers() {
        let location = SourceLocation(filePath: "test.tsx", startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)

        let entries: [ConversionEntry] = [
            ConversionEntry(sourceFile: "test.tsx", sourceLine: 1, originalCode: "<div>", generatedCode: "VStack", tier: .direct, explanation: "test", category: .layout),
            ConversionEntry(sourceFile: "test.tsx", sourceLine: 2, originalCode: "margin", generatedCode: "padding", tier: .adapted, explanation: "test", category: .styling),
            ConversionEntry(sourceFile: "test.tsx", sourceLine: 3, originalCode: "::before", generatedCode: "//", tier: .unsupported, explanation: "test", category: .styling),
        ]

        let summary = ConversionSummary.from(entries: entries)

        #expect(summary.totalConversions == 3)
        #expect(summary.directMatches == 1)
        #expect(summary.adaptedMatches == 1)
        #expect(summary.unsupportedCount == 1)
    }

    @Test("Report filters entries by tier")
    func testReportFiltersEntriesByTier() {
        let summary = ConversionSummary(totalConversions: 2, directMatches: 1, adaptedMatches: 1, unsupportedCount: 0)

        var report = ConversionReport(sourceProject: "test", summary: summary)

        report.addEntry(ConversionEntry(sourceFile: "test.tsx", sourceLine: 1, originalCode: "<div>", generatedCode: "VStack", tier: .direct, explanation: "test", category: .layout))
        report.addEntry(ConversionEntry(sourceFile: "test.tsx", sourceLine: 2, originalCode: "margin", generatedCode: "padding", tier: .adapted, explanation: "test", category: .styling))

        let directEntries = report.entries(for: .direct)
        let adaptedEntries = report.entries(for: .adapted)

        #expect(directEntries.count == 1)
        #expect(adaptedEntries.count == 1)
    }

    @Test("Report exports to Markdown")
    func testReportExportsToMarkdown() {
        let summary = ConversionSummary(totalConversions: 1, directMatches: 1, adaptedMatches: 0, unsupportedCount: 0)

        var report = ConversionReport(sourceProject: "TestProject", summary: summary)
        report.addEntry(ConversionEntry(sourceFile: "test.tsx", sourceLine: 1, originalCode: "<div>", generatedCode: "VStack", tier: .direct, explanation: "test", category: .layout))

        let markdown = report.toMarkdown()

        #expect(markdown.contains("# React2SwiftUI Conversion Report"))
        #expect(markdown.contains("TestProject"))
        #expect(markdown.contains("Direct Matches"))
    }
}

@Suite("CSS Types Tests")
struct CSSTypesTests {

    @Test("CSSColor parses hex correctly")
    func testCSSColorParsesHex() {
        let color = CSSColor(hex: "#FF0000")

        #expect(color != nil)
        #expect(color?.red == 1.0)
        #expect(color?.green == 0.0)
        #expect(color?.blue == 0.0)
    }

    @Test("CSSColor generates hex correctly")
    func testCSSColorGeneratesHex() {
        let color = CSSColor(red: 1, green: 0, blue: 0)

        #expect(color.toHex() == "#FF0000")
    }

    @Test("CSSLength converts px to points")
    func testCSSLengthConvertsPxToPoints() {
        let length = CSSLength(value: 16, unit: .px)

        #expect(length.toPoints() == 16)
    }

    @Test("CSSLength converts rem to points")
    func testCSSLengthConvertsRemToPoints() {
        let length = CSSLength(value: 1, unit: .rem)

        #expect(length.toPoints() == 16)
    }
}
