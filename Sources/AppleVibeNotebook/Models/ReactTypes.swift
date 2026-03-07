import Foundation

// MARK: - React/HTML Element Types

/// Represents HTML elements that can be parsed from React JSX.
public enum HTMLElementType: String, CaseIterable, Codable, Sendable {
    // Document Structure
    case div
    case span
    case main
    case header
    case footer
    case nav
    case aside
    case section
    case article
    case figure
    case figcaption

    // Text Content
    case p
    case h1, h2, h3, h4, h5, h6
    case blockquote
    case pre
    case code
    case em
    case strong
    case small
    case sub
    case sup
    case mark
    case del
    case ins
    case abbr
    case time
    case cite
    case dfn
    case kbd
    case samp
    case `var`
    case br
    case hr
    case wbr

    // Lists
    case ul
    case ol
    case li
    case dl
    case dt
    case dd

    // Links & Media
    case a
    case img
    case picture
    case source
    case video
    case audio
    case track
    case iframe
    case embed
    case object
    case svg
    case canvas

    // Forms
    case form
    case input
    case textarea
    case button
    case select
    case option
    case optgroup
    case label
    case fieldset
    case legend
    case datalist
    case output
    case progress
    case meter

    // Tables
    case table
    case thead
    case tbody
    case tfoot
    case tr
    case th
    case td
    case caption
    case colgroup
    case col

    // Interactive
    case details
    case summary
    case dialog
    case menu

    // Misc
    case address
    case template
    case slot
    case noscript
}

// MARK: - HTML Input Types

public enum HTMLInputType: String, Codable, Sendable {
    case text
    case password
    case email
    case number
    case tel
    case url
    case search
    case date
    case time
    case datetime = "datetime-local"
    case month
    case week
    case color
    case file
    case hidden
    case checkbox
    case radio
    case range
    case submit
    case reset
    case button
    case image
}

// MARK: - React Hook Types

/// Represents React hooks that can be detected in component parsing.
public enum ReactHookType: String, CaseIterable, Codable, Sendable {
    case useState
    case useEffect
    case useContext
    case useReducer
    case useCallback
    case useMemo
    case useRef
    case useImperativeHandle
    case useLayoutEffect
    case useDebugValue
    case useDeferredValue
    case useTransition
    case useId
    case useSyncExternalStore
    case useInsertionEffect
    case useOptimistic
    case useFormStatus
    case useFormState
    case useActionState
    case use
}

// MARK: - React Event Types

/// Represents React event handler prop names.
public enum ReactEventType: String, CaseIterable, Codable, Sendable {
    // Mouse Events
    case onClick
    case onDoubleClick
    case onMouseDown
    case onMouseUp
    case onMouseMove
    case onMouseEnter
    case onMouseLeave
    case onMouseOver
    case onMouseOut
    case onContextMenu

    // Touch Events
    case onTouchStart
    case onTouchEnd
    case onTouchMove
    case onTouchCancel

    // Keyboard Events
    case onKeyDown
    case onKeyUp
    case onKeyPress

    // Focus Events
    case onFocus
    case onBlur
    case onFocusIn
    case onFocusOut

    // Form Events
    case onChange
    case onInput
    case onSubmit
    case onReset
    case onInvalid

    // Clipboard Events
    case onCopy
    case onCut
    case onPaste

    // Drag Events
    case onDrag
    case onDragStart
    case onDragEnd
    case onDragEnter
    case onDragLeave
    case onDragOver
    case onDrop

    // Scroll Events
    case onScroll
    case onWheel

    // Animation Events
    case onAnimationStart
    case onAnimationEnd
    case onAnimationIteration

    // Transition Events
    case onTransitionEnd

    // Media Events
    case onPlay
    case onPause
    case onEnded
    case onLoadedData
    case onLoadedMetadata
    case onTimeUpdate
    case onVolumeChange
    case onSeeking
    case onSeeked
    case onWaiting
    case onPlaying
    case onCanPlay
    case onCanPlayThrough
    case onDurationChange
    case onProgress
    case onRateChange
    case onStalled
    case onSuspend
    case onEmptied
    case onAbort
    case onError

    // Image Events
    case onLoad

    // Selection Events
    case onSelect

    // Pointer Events
    case onPointerDown
    case onPointerUp
    case onPointerMove
    case onPointerEnter
    case onPointerLeave
    case onPointerOver
    case onPointerOut
    case onPointerCancel
    case onGotPointerCapture
    case onLostPointerCapture
}

// MARK: - Parsed React Component

/// Represents a parsed React component from the AST.
public struct ParsedReactComponent: Codable, Sendable {
    public let name: String
    public let isClassComponent: Bool
    public let props: [ParsedProp]
    public let hooks: [ParsedHook]
    public let children: [ParsedJSXElement]
    public let sourceLocation: SourceLocation

    public init(
        name: String,
        isClassComponent: Bool = false,
        props: [ParsedProp] = [],
        hooks: [ParsedHook] = [],
        children: [ParsedJSXElement] = [],
        sourceLocation: SourceLocation
    ) {
        self.name = name
        self.isClassComponent = isClassComponent
        self.props = props
        self.hooks = hooks
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Represents a parsed prop definition.
public struct ParsedProp: Codable, Sendable {
    public let name: String
    public let type: String?
    public let defaultValue: String?
    public let isRequired: Bool
    public let isCallback: Bool

    public init(
        name: String,
        type: String? = nil,
        defaultValue: String? = nil,
        isRequired: Bool = false,
        isCallback: Bool = false
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.isRequired = isRequired
        self.isCallback = isCallback
    }
}

/// Represents a parsed React hook usage.
public struct ParsedHook: Codable, Sendable {
    public let type: ReactHookType
    public let variableName: String?
    public let setterName: String?
    public let initialValue: String?
    public let dependencies: [String]?
    public let effectBody: String?

    public init(
        type: ReactHookType,
        variableName: String? = nil,
        setterName: String? = nil,
        initialValue: String? = nil,
        dependencies: [String]? = nil,
        effectBody: String? = nil
    ) {
        self.type = type
        self.variableName = variableName
        self.setterName = setterName
        self.initialValue = initialValue
        self.dependencies = dependencies
        self.effectBody = effectBody
    }
}

/// Represents a parsed JSX element.
public struct ParsedJSXElement: Codable, Sendable {
    public let elementType: JSXElementType
    public let attributes: [ParsedJSXAttribute]
    public let children: [ParsedJSXChild]
    public let computedStyle: ComputedCSSStyle
    public let sourceLocation: SourceLocation

    public init(
        elementType: JSXElementType,
        attributes: [ParsedJSXAttribute] = [],
        children: [ParsedJSXChild] = [],
        computedStyle: ComputedCSSStyle = ComputedCSSStyle(),
        sourceLocation: SourceLocation
    ) {
        self.elementType = elementType
        self.attributes = attributes
        self.children = children
        self.computedStyle = computedStyle
        self.sourceLocation = sourceLocation
    }
}

/// Represents the type of a JSX element.
public enum JSXElementType: Codable, Sendable, Equatable {
    case html(HTMLElementType)
    case reactComponent(String)
    case fragment
}

/// Represents a parsed JSX attribute.
public struct ParsedJSXAttribute: Codable, Sendable {
    public let name: String
    public let value: JSXAttributeValue

    public init(name: String, value: JSXAttributeValue) {
        self.name = name
        self.value = value
    }
}

/// Represents the value of a JSX attribute.
public enum JSXAttributeValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case expression(String)
    case eventHandler(String)
    case spreadProps(String)
    case null
}

/// Represents a child of a JSX element.
public enum ParsedJSXChild: Codable, Sendable {
    case element(ParsedJSXElement)
    case text(String)
    case expression(String)
    case conditional(condition: String, consequent: ParsedJSXElement?, alternate: ParsedJSXElement?)
    case map(iteratorVariable: String, arrayExpression: String, body: ParsedJSXElement)
}

/// Source location for mapping back to original code.
public struct SourceLocation: Codable, Sendable, Equatable {
    public let filePath: String
    public let startLine: Int
    public let startColumn: Int
    public let endLine: Int
    public let endColumn: Int

    public init(
        filePath: String,
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int
    ) {
        self.filePath = filePath
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = endLine
        self.endColumn = endColumn
    }
}
