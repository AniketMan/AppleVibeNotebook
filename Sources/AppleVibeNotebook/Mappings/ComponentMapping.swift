import Foundation

// MARK: - Component Mapping Dictionary

/// Deterministic mappings from React/HTML elements to SwiftUI views.
/// These mappings are derived from WHATWG HTML Living Standard and Apple SwiftUI documentation.
/// Reference: WHATWG HTML spec, Apple SwiftUI Documentation
public enum ComponentMapping {

    // MARK: - HTML Element → SwiftUI View

    /// Maps an HTML element type to its SwiftUI equivalent.
    /// Source: WHATWG HTML Living Standard, Apple SwiftUI Documentation
    public static func viewType(
        for element: HTMLElementType,
        inputType: HTMLInputType? = nil,
        computedStyle: ComputedCSSStyle? = nil
    ) -> ComponentMappingResult {
        switch element {
        // MARK: Container Elements
        case .div:
            return mapDivElement(computedStyle: computedStyle)

        case .span:
            return ComponentMappingResult(
                viewType: .text,
                tier: .direct,
                explanation: "<span> maps to Text for inline text content"
            )

        case .main, .header, .footer, .nav, .aside, .section, .article:
            return mapDivElement(computedStyle: computedStyle, semanticNote: element.rawValue)

        case .figure:
            return ComponentMappingResult(
                viewType: .vStack,
                tier: .direct,
                explanation: "<figure> maps to VStack containing image and caption"
            )

        case .figcaption:
            return ComponentMappingResult(
                viewType: .text,
                tier: .direct,
                explanation: "<figcaption> maps to Text with caption styling"
            )

        // MARK: Text Content
        case .p:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.padding],
                tier: .direct,
                explanation: "<p> maps to Text with bottom padding for paragraph spacing"
            )

        case .h1:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .fontWeight],
                modifierValues: [".font": ".largeTitle", ".fontWeight": ".bold"],
                tier: .direct,
                explanation: "<h1> maps to Text with .largeTitle font"
            )

        case .h2:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .fontWeight],
                modifierValues: [".font": ".title", ".fontWeight": ".bold"],
                tier: .direct,
                explanation: "<h2> maps to Text with .title font"
            )

        case .h3:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .fontWeight],
                modifierValues: [".font": ".title2", ".fontWeight": ".semibold"],
                tier: .direct,
                explanation: "<h3> maps to Text with .title2 font"
            )

        case .h4:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .fontWeight],
                modifierValues: [".font": ".title3", ".fontWeight": ".semibold"],
                tier: .direct,
                explanation: "<h4> maps to Text with .title3 font"
            )

        case .h5:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .fontWeight],
                modifierValues: [".font": ".headline", ".fontWeight": ".medium"],
                tier: .direct,
                explanation: "<h5> maps to Text with .headline font"
            )

        case .h6:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .fontWeight],
                modifierValues: [".font": ".subheadline", ".fontWeight": ".medium"],
                tier: .direct,
                explanation: "<h6> maps to Text with .subheadline font"
            )

        case .blockquote:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.padding, .background, .italic],
                tier: .adapted,
                explanation: "<blockquote> maps to Text with padding and background. " +
                            "Styling approximated; consider using a custom BlockquoteView."
            )

        case .pre:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font],
                modifierValues: [".font": ".system(.body, design: .monospaced)"],
                tier: .direct,
                explanation: "<pre> maps to Text with monospaced font"
            )

        case .code:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .background, .cornerRadius],
                modifierValues: [".font": ".system(.body, design: .monospaced)"],
                tier: .direct,
                explanation: "<code> maps to Text with monospaced font and subtle background"
            )

        case .em:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.italic],
                tier: .direct,
                explanation: "<em> maps to Text with .italic() modifier"
            )

        case .strong:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.bold],
                tier: .direct,
                explanation: "<strong> maps to Text with .bold() modifier"
            )

        case .small:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font],
                modifierValues: [".font": ".caption"],
                tier: .direct,
                explanation: "<small> maps to Text with .caption font"
            )

        case .sub, .sup:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font, .baselineOffset],
                tier: .adapted,
                explanation: "<\(element.rawValue)> requires .baselineOffset and smaller font. " +
                            "SwiftUI doesn't have native sub/superscript."
            )

        case .mark:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.background],
                modifierValues: [".background": "Color.yellow.opacity(0.3)"],
                tier: .direct,
                explanation: "<mark> maps to Text with yellow background highlight"
            )

        case .del:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.strikethrough],
                tier: .direct,
                explanation: "<del> maps to Text with .strikethrough() modifier"
            )

        case .ins:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.underline],
                tier: .direct,
                explanation: "<ins> maps to Text with .underline() modifier"
            )

        case .abbr, .cite, .dfn, .kbd, .samp, .var, .time:
            return ComponentMappingResult(
                viewType: .text,
                tier: .direct,
                explanation: "<\(element.rawValue)> maps to Text. Semantic meaning preserved in comments."
            )

        case .br:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [],
                tier: .adapted,
                explanation: "<br> maps to newline character in Text. " +
                            "Adjacent text nodes should be combined with \\n."
            )

        case .hr:
            return ComponentMappingResult(
                viewType: .divider,
                tier: .direct,
                explanation: "<hr> maps directly to Divider()"
            )

        case .wbr:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .unsupported,
                explanation: "<wbr> (word break opportunity) has no SwiftUI equivalent. " +
                            "Text wrapping is handled automatically."
            )

        // MARK: Lists
        case .ul:
            return ComponentMappingResult(
                viewType: .vStack,
                tier: .direct,
                explanation: "<ul> maps to VStack. For dynamic lists, use List or ForEach."
            )

        case .ol:
            return ComponentMappingResult(
                viewType: .vStack,
                tier: .adapted,
                explanation: "<ol> maps to VStack. Numbering must be manually added to children. " +
                            "Consider using ForEach with index."
            )

        case .li:
            return ComponentMappingResult(
                viewType: .hStack,
                tier: .direct,
                explanation: "<li> maps to HStack with bullet/number + content"
            )

        case .dl:
            return ComponentMappingResult(
                viewType: .vStack,
                tier: .direct,
                explanation: "<dl> maps to VStack containing dt/dd pairs"
            )

        case .dt:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.fontWeight],
                modifierValues: [".fontWeight": ".semibold"],
                tier: .direct,
                explanation: "<dt> maps to Text with semibold font weight"
            )

        case .dd:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.padding],
                tier: .direct,
                explanation: "<dd> maps to Text with leading padding"
            )

        // MARK: Links & Media
        case .a:
            return ComponentMappingResult(
                viewType: .link,
                tier: .direct,
                explanation: "<a href> maps to Link for external URLs or NavigationLink for internal routes"
            )

        case .img:
            return ComponentMappingResult(
                viewType: .asyncImage,
                tier: .direct,
                explanation: "<img src> maps to AsyncImage(url:) for remote images or Image() for local"
            )

        case .picture:
            return ComponentMappingResult(
                viewType: .asyncImage,
                tier: .adapted,
                explanation: "<picture> responsive image maps to AsyncImage. " +
                            "Source selection logic must be implemented separately."
            )

        case .source:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .unsupported,
                explanation: "<source> is processed by parent <picture> or <video>. " +
                            "No standalone SwiftUI equivalent."
            )

        case .video:
            return ComponentMappingResult(
                viewType: .group,
                tier: .adapted,
                explanation: "<video> maps to VideoPlayer (AVKit). Requires import AVKit."
            )

        case .audio:
            return ComponentMappingResult(
                viewType: .group,
                tier: .adapted,
                explanation: "<audio> requires custom implementation with AVFoundation. " +
                            "No direct SwiftUI equivalent."
            )

        case .track, .embed, .object:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .unsupported,
                explanation: "<\(element.rawValue)> has no SwiftUI equivalent. Manual implementation required."
            )

        case .iframe:
            return ComponentMappingResult(
                viewType: .group,
                tier: .adapted,
                explanation: "<iframe> maps to WKWebView wrapped in UIViewRepresentable/NSViewRepresentable"
            )

        case .svg:
            return ComponentMappingResult(
                viewType: .image,
                tier: .adapted,
                explanation: "<svg> maps to Image for simple cases. Complex SVGs may need " +
                            "conversion to SwiftUI Shape or Path."
            )

        case .canvas:
            return ComponentMappingResult(
                viewType: .group,
                tier: .adapted,
                explanation: "<canvas> maps to SwiftUI Canvas view for drawing operations"
            )

        // MARK: Form Elements
        case .form:
            return ComponentMappingResult(
                viewType: .form,
                tier: .direct,
                explanation: "<form> maps to SwiftUI Form for structured input layouts"
            )

        case .input:
            return mapInputElement(inputType: inputType)

        case .textarea:
            return ComponentMappingResult(
                viewType: .textEditor,
                tier: .direct,
                explanation: "<textarea> maps directly to TextEditor(text:)"
            )

        case .button:
            return ComponentMappingResult(
                viewType: .button,
                tier: .direct,
                explanation: "<button> maps directly to Button(action:label:)"
            )

        case .select:
            return ComponentMappingResult(
                viewType: .picker,
                tier: .direct,
                explanation: "<select> maps to Picker with child <option> elements"
            )

        case .option:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.tag],
                tier: .direct,
                explanation: "<option> maps to Text within Picker, with .tag() modifier"
            )

        case .optgroup:
            return ComponentMappingResult(
                viewType: .section,
                tier: .adapted,
                explanation: "<optgroup> maps to Section within Picker. " +
                            "Requires menu-style Picker for proper display."
            )

        case .label:
            return ComponentMappingResult(
                viewType: .label,
                tier: .direct,
                explanation: "<label> maps to SwiftUI Label or HStack with Text + control"
            )

        case .fieldset:
            return ComponentMappingResult(
                viewType: .groupBox,
                tier: .direct,
                explanation: "<fieldset> maps to GroupBox for grouped form controls"
            )

        case .legend:
            return ComponentMappingResult(
                viewType: .text,
                tier: .direct,
                explanation: "<legend> maps to Text used as GroupBox label"
            )

        case .datalist:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .unsupported,
                explanation: "<datalist> autocomplete has no direct SwiftUI equivalent. " +
                            "Consider using searchable() modifier with suggestions."
            )

        case .output:
            return ComponentMappingResult(
                viewType: .text,
                tier: .direct,
                explanation: "<output> maps to Text displaying computed value"
            )

        case .progress:
            return ComponentMappingResult(
                viewType: .progressView,
                tier: .direct,
                explanation: "<progress> maps directly to ProgressView"
            )

        case .meter:
            return ComponentMappingResult(
                viewType: .gauge,
                tier: .direct,
                explanation: "<meter> maps to Gauge in SwiftUI"
            )

        // MARK: Table Elements
        case .table:
            return ComponentMappingResult(
                viewType: .grid,
                tier: .adapted,
                explanation: "<table> maps to Grid or Table (macOS). Complex tables may need " +
                            "LazyVGrid with manual column alignment."
            )

        case .thead, .tbody, .tfoot:
            return ComponentMappingResult(
                viewType: .group,
                tier: .direct,
                explanation: "<\(element.rawValue)> groups rows; maps to Group in SwiftUI Grid"
            )

        case .tr:
            return ComponentMappingResult(
                viewType: .gridRow,
                tier: .direct,
                explanation: "<tr> maps to GridRow in SwiftUI Grid"
            )

        case .th:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.fontWeight, .frame],
                modifierValues: [".fontWeight": ".semibold"],
                tier: .direct,
                explanation: "<th> maps to Text with bold styling in GridRow"
            )

        case .td:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.frame],
                tier: .direct,
                explanation: "<td> maps to Text (or content) in GridRow"
            )

        case .caption:
            return ComponentMappingResult(
                viewType: .text,
                modifiers: [.font],
                modifierValues: [".font": ".caption"],
                tier: .direct,
                explanation: "<caption> maps to Text positioned above/below Grid"
            )

        case .colgroup, .col:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .unsupported,
                explanation: "<\(element.rawValue)> column styling has no SwiftUI equivalent. " +
                            "Apply styles directly to cells."
            )

        // MARK: Interactive Elements
        case .details:
            return ComponentMappingResult(
                viewType: .disclosureGroup,
                tier: .direct,
                explanation: "<details> maps directly to DisclosureGroup"
            )

        case .summary:
            return ComponentMappingResult(
                viewType: .text,
                tier: .direct,
                explanation: "<summary> maps to label parameter of DisclosureGroup"
            )

        case .dialog:
            return ComponentMappingResult(
                viewType: .group,
                modifiers: [.sheet],
                tier: .direct,
                explanation: "<dialog> maps to content presented via .sheet() or .fullScreenCover()"
            )

        case .menu:
            return ComponentMappingResult(
                viewType: .menu,
                tier: .direct,
                explanation: "<menu> maps directly to SwiftUI Menu"
            )

        // MARK: Misc Elements
        case .address:
            return ComponentMappingResult(
                viewType: .vStack,
                modifiers: [.italic],
                tier: .direct,
                explanation: "<address> maps to VStack with italic text styling"
            )

        case .template, .slot, .noscript:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .unsupported,
                explanation: "<\(element.rawValue)> is a web-specific element with no SwiftUI equivalent"
            )
        }
    }

    // MARK: - Input Type Mapping

    private static func mapInputElement(inputType: HTMLInputType?) -> ComponentMappingResult {
        let type = inputType ?? .text

        switch type {
        case .text, .email, .tel, .url, .search:
            return ComponentMappingResult(
                viewType: .textField,
                modifiers: [.textContentType, .keyboardType],
                tier: .direct,
                explanation: "<input type=\"\(type.rawValue)\"> maps to TextField with appropriate keyboard"
            )

        case .password:
            return ComponentMappingResult(
                viewType: .secureField,
                tier: .direct,
                explanation: "<input type=\"password\"> maps directly to SecureField"
            )

        case .number:
            return ComponentMappingResult(
                viewType: .textField,
                modifiers: [.keyboardType],
                modifierValues: [".keyboardType": ".decimalPad"],
                tier: .direct,
                explanation: "<input type=\"number\"> maps to TextField with .decimalPad keyboard"
            )

        case .date:
            return ComponentMappingResult(
                viewType: .datePicker,
                modifierValues: ["displayedComponents": ".date"],
                tier: .direct,
                explanation: "<input type=\"date\"> maps to DatePicker with .date components"
            )

        case .time:
            return ComponentMappingResult(
                viewType: .datePicker,
                modifierValues: ["displayedComponents": ".hourAndMinute"],
                tier: .direct,
                explanation: "<input type=\"time\"> maps to DatePicker with .hourAndMinute components"
            )

        case .datetime:
            return ComponentMappingResult(
                viewType: .datePicker,
                tier: .direct,
                explanation: "<input type=\"datetime-local\"> maps to DatePicker"
            )

        case .month, .week:
            return ComponentMappingResult(
                viewType: .datePicker,
                tier: .adapted,
                explanation: "<input type=\"\(type.rawValue)\"> approximated with DatePicker. " +
                            "SwiftUI doesn't have month/week-only picker."
            )

        case .color:
            return ComponentMappingResult(
                viewType: .colorPicker,
                tier: .direct,
                explanation: "<input type=\"color\"> maps directly to ColorPicker"
            )

        case .file:
            return ComponentMappingResult(
                viewType: .button,
                tier: .adapted,
                explanation: "<input type=\"file\"> maps to Button that triggers " +
                            ".fileImporter() or document picker"
            )

        case .checkbox:
            return ComponentMappingResult(
                viewType: .toggle,
                tier: .direct,
                explanation: "<input type=\"checkbox\"> maps directly to Toggle"
            )

        case .radio:
            return ComponentMappingResult(
                viewType: .picker,
                tier: .adapted,
                explanation: "<input type=\"radio\"> group maps to Picker with .radioGroup style (macOS) " +
                            "or segmented style (iOS)"
            )

        case .range:
            return ComponentMappingResult(
                viewType: .slider,
                tier: .direct,
                explanation: "<input type=\"range\"> maps directly to Slider"
            )

        case .submit, .reset, .button:
            return ComponentMappingResult(
                viewType: .button,
                tier: .direct,
                explanation: "<input type=\"\(type.rawValue)\"> maps to Button"
            )

        case .hidden:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .direct,
                explanation: "<input type=\"hidden\"> has no visual representation; " +
                            "value stored in @State"
            )

        case .image:
            return ComponentMappingResult(
                viewType: .button,
                tier: .adapted,
                explanation: "<input type=\"image\"> maps to Button with Image label"
            )
        }
    }

    // MARK: - Div Element Mapping (Layout-Dependent)

    private static func mapDivElement(
        computedStyle: ComputedCSSStyle?,
        semanticNote: String? = nil
    ) -> ComponentMappingResult {
        guard let style = computedStyle else {
            return ComponentMappingResult(
                viewType: .vStack,
                tier: .direct,
                explanation: "<div> with no specific layout maps to VStack (block-level default)"
            )
        }

        let display = style.display ?? .block
        let semanticPrefix = semanticNote.map { "<\($0)> " } ?? "<div> "

        switch display {
        case .flex, .inlineFlex:
            let direction = style.flexDirection ?? .row
            let wrap = style.flexWrap ?? .nowrap
            let layoutResult = LayoutMapping.stackType(for: direction, flexWrap: wrap)

            return ComponentMappingResult(
                viewType: layoutResult.viewType,
                tier: layoutResult.tier,
                explanation: semanticPrefix + layoutResult.explanation
            )

        case .grid, .inlineGrid:
            let gridResult = LayoutMapping.gridMapping(style.gridTemplate)
            return ComponentMappingResult(
                viewType: gridResult.viewType,
                tier: gridResult.tier,
                explanation: semanticPrefix + gridResult.explanation
            )

        case .none:
            return ComponentMappingResult(
                viewType: .emptyView,
                tier: .direct,
                explanation: semanticPrefix + "with display:none maps to EmptyView or conditional render"
            )

        case .contents:
            return ComponentMappingResult(
                viewType: .group,
                tier: .direct,
                explanation: semanticPrefix + "with display:contents maps to Group (no visual box)"
            )

        case .block, .inline, .inlineBlock:
            return ComponentMappingResult(
                viewType: .vStack,
                tier: .direct,
                explanation: semanticPrefix + "with display:\(display.rawValue) maps to VStack"
            )
        }
    }

    // MARK: - Event Mapping

    /// Maps React event handlers to SwiftUI gesture/action patterns.
    public static func eventMapping(_ event: ReactEventType) -> EventMappingResult {
        switch event {
        case .onClick:
            return EventMappingResult(
                modifier: .onTapGesture,
                tier: .direct,
                explanation: "onClick maps to .onTapGesture or Button action"
            )

        case .onDoubleClick:
            return EventMappingResult(
                modifier: .onTapGesture,
                modifierParameters: "count: 2",
                tier: .direct,
                explanation: "onDoubleClick maps to .onTapGesture(count: 2)"
            )

        case .onMouseDown, .onMouseUp:
            return EventMappingResult(
                modifier: .gesture,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to DragGesture with .onChanged/.onEnded"
            )

        case .onMouseEnter, .onMouseOver:
            return EventMappingResult(
                modifier: .hoverEffect,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to .hoverEffect or custom hover handling (macOS/iPadOS)"
            )

        case .onMouseLeave, .onMouseOut:
            return EventMappingResult(
                modifier: .hoverEffect,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to .hoverEffect checking for false state"
            )

        case .onMouseMove:
            return EventMappingResult(
                modifier: .gesture,
                tier: .adapted,
                explanation: "onMouseMove maps to continuous gesture or hover tracking"
            )

        case .onContextMenu:
            return EventMappingResult(
                modifier: .contextMenu,
                tier: .direct,
                explanation: "onContextMenu maps directly to .contextMenu modifier"
            )

        case .onTouchStart, .onTouchEnd, .onTouchMove, .onTouchCancel:
            return EventMappingResult(
                modifier: .gesture,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to gesture modifiers (DragGesture, etc.)"
            )

        case .onKeyDown, .onKeyUp, .onKeyPress:
            return EventMappingResult(
                modifier: .onSubmit,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to .onSubmit or focused-based keyboard handling"
            )

        case .onFocus:
            return EventMappingResult(
                modifier: .focused,
                tier: .direct,
                explanation: "onFocus maps to .focused() with @FocusState binding"
            )

        case .onBlur:
            return EventMappingResult(
                modifier: .onChange,
                tier: .direct,
                explanation: "onBlur maps to .onChange(of: focusedField) checking for nil"
            )

        case .onFocusIn, .onFocusOut:
            return EventMappingResult(
                modifier: .focused,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to @FocusState with .onChange"
            )

        case .onChange:
            return EventMappingResult(
                modifier: .onChange,
                tier: .direct,
                explanation: "onChange maps to .onChange(of:) or Binding in TextField"
            )

        case .onInput:
            return EventMappingResult(
                modifier: .onChange,
                tier: .direct,
                explanation: "onInput maps to TextField's text binding or .onChange"
            )

        case .onSubmit:
            return EventMappingResult(
                modifier: .onSubmit,
                tier: .direct,
                explanation: "onSubmit maps directly to .onSubmit modifier"
            )

        case .onReset:
            return EventMappingResult(
                modifier: nil,
                tier: .adapted,
                explanation: "onReset requires manual state reset logic"
            )

        case .onInvalid:
            return EventMappingResult(
                modifier: nil,
                tier: .unsupported,
                explanation: "onInvalid has no SwiftUI equivalent. Use custom validation."
            )

        case .onScroll:
            return EventMappingResult(
                modifier: .scrollPosition,
                tier: .adapted,
                explanation: "onScroll maps to .scrollPosition with .onChange for tracking"
            )

        case .onWheel:
            return EventMappingResult(
                modifier: .gesture,
                tier: .adapted,
                explanation: "onWheel maps to MagnifyGesture or custom scroll handling"
            )

        case .onDrag, .onDragStart, .onDragEnd:
            return EventMappingResult(
                modifier: .draggable,
                tier: .direct,
                explanation: "\(event.rawValue) maps to .draggable modifier"
            )

        case .onDragEnter, .onDragLeave, .onDragOver, .onDrop:
            return EventMappingResult(
                modifier: .dropDestination,
                tier: .direct,
                explanation: "\(event.rawValue) maps to .dropDestination modifier"
            )

        case .onCopy, .onCut, .onPaste:
            return EventMappingResult(
                modifier: nil,
                tier: .adapted,
                explanation: "\(event.rawValue) requires UIPasteboard/NSPasteboard integration"
            )

        case .onAnimationStart, .onAnimationEnd, .onAnimationIteration:
            return EventMappingResult(
                modifier: .animation,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to withAnimation completion handlers"
            )

        case .onTransitionEnd:
            return EventMappingResult(
                modifier: .transition,
                tier: .adapted,
                explanation: "onTransitionEnd maps to .transaction or withAnimation completion"
            )

        case .onLoad:
            return EventMappingResult(
                modifier: .onAppear,
                tier: .direct,
                explanation: "onLoad maps to .onAppear or .task modifier"
            )

        case .onError:
            return EventMappingResult(
                modifier: nil,
                tier: .adapted,
                explanation: "onError maps to error handling in AsyncImage phase or .task"
            )

        case .onSelect:
            return EventMappingResult(
                modifier: .textSelection,
                tier: .direct,
                explanation: "onSelect maps to .textSelection modifier"
            )

        case .onPlay, .onPause, .onEnded, .onLoadedData, .onLoadedMetadata,
             .onTimeUpdate, .onVolumeChange, .onSeeking, .onSeeked, .onWaiting,
             .onPlaying, .onCanPlay, .onCanPlayThrough, .onDurationChange,
             .onProgress, .onRateChange, .onStalled, .onSuspend, .onEmptied, .onAbort:
            return EventMappingResult(
                modifier: nil,
                tier: .adapted,
                explanation: "\(event.rawValue) requires AVPlayer observation with Combine"
            )

        case .onPointerDown, .onPointerUp, .onPointerMove, .onPointerEnter,
             .onPointerLeave, .onPointerOver, .onPointerOut, .onPointerCancel,
             .onGotPointerCapture, .onLostPointerCapture:
            return EventMappingResult(
                modifier: .gesture,
                tier: .adapted,
                explanation: "\(event.rawValue) maps to unified gesture handling in SwiftUI"
            )
        }
    }
}

// MARK: - Mapping Result Types

public struct ComponentMappingResult: Sendable {
    public let viewType: SwiftUIViewType
    public let modifiers: [SwiftUIModifier]
    public let modifierValues: [String: String]
    public let tier: ConversionTier
    public let explanation: String

    public init(
        viewType: SwiftUIViewType,
        modifiers: [SwiftUIModifier] = [],
        modifierValues: [String: String] = [:],
        tier: ConversionTier,
        explanation: String
    ) {
        self.viewType = viewType
        self.modifiers = modifiers
        self.modifierValues = modifierValues
        self.tier = tier
        self.explanation = explanation
    }
}

public struct EventMappingResult: Sendable {
    public let modifier: SwiftUIModifier?
    public let modifierParameters: String?
    public let tier: ConversionTier
    public let explanation: String

    public init(
        modifier: SwiftUIModifier?,
        modifierParameters: String? = nil,
        tier: ConversionTier,
        explanation: String
    ) {
        self.modifier = modifier
        self.modifierParameters = modifierParameters
        self.tier = tier
        self.explanation = explanation
    }
}
