import Foundation

// MARK: - CSS Display & Layout

public enum CSSDisplay: String, Codable, Sendable {
    case block
    case inline
    case inlineBlock = "inline-block"
    case flex
    case inlineFlex = "inline-flex"
    case grid
    case inlineGrid = "inline-grid"
    case none
    case contents
}

public enum CSSFlexDirection: String, Codable, Sendable {
    case row
    case rowReverse = "row-reverse"
    case column
    case columnReverse = "column-reverse"
}

public enum CSSFlexWrap: String, Codable, Sendable {
    case nowrap
    case wrap
    case wrapReverse = "wrap-reverse"
}

public enum CSSJustifyContent: String, Codable, Sendable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
    case spaceEvenly = "space-evenly"
    case start
    case end
}

public enum CSSAlignItems: String, Codable, Sendable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center
    case baseline
    case stretch
    case start
    case end
}

public enum CSSAlignContent: String, Codable, Sendable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
    case stretch
    case start
    case end
}

public enum CSSAlignSelf: String, Codable, Sendable {
    case auto
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center
    case baseline
    case stretch
}

// MARK: - CSS Position

public enum CSSPosition: String, Codable, Sendable {
    case `static`
    case relative
    case absolute
    case fixed
    case sticky
}

public enum CSSOverflow: String, Codable, Sendable {
    case visible
    case hidden
    case scroll
    case auto
    case clip
}

// MARK: - CSS Typography

public enum CSSFontWeight: String, Codable, Sendable {
    case normal
    case bold
    case bolder
    case lighter
    case w100 = "100"
    case w200 = "200"
    case w300 = "300"
    case w400 = "400"
    case w500 = "500"
    case w600 = "600"
    case w700 = "700"
    case w800 = "800"
    case w900 = "900"
}

public enum CSSTextAlign: String, Codable, Sendable {
    case left
    case right
    case center
    case justify
    case start
    case end
}

public enum CSSTextDecoration: String, Codable, Sendable {
    case none
    case underline
    case overline
    case lineThrough = "line-through"
}

public enum CSSTextTransform: String, Codable, Sendable {
    case none
    case capitalize
    case uppercase
    case lowercase
}

public enum CSSWhiteSpace: String, Codable, Sendable {
    case normal
    case nowrap
    case pre
    case preWrap = "pre-wrap"
    case preLine = "pre-line"
    case breakSpaces = "break-spaces"
}

// MARK: - CSS Border

public enum CSSBorderStyle: String, Codable, Sendable {
    case none
    case hidden
    case dotted
    case dashed
    case solid
    case double
    case groove
    case ridge
    case inset
    case outset
}

// MARK: - CSS Values

public struct CSSLength: Codable, Sendable, Equatable {
    public let value: Double
    public let unit: CSSLengthUnit

    public init(value: Double, unit: CSSLengthUnit) {
        self.value = value
        self.unit = unit
    }

    // Convenience static constructors for cleaner syntax
    public static func px(_ value: Double) -> CSSLength {
        CSSLength(value: value, unit: .px)
    }

    public static func percent(_ value: Double) -> CSSLength {
        CSSLength(value: value, unit: .percent)
    }

    public static func em(_ value: Double) -> CSSLength {
        CSSLength(value: value, unit: .em)
    }

    public static func rem(_ value: Double) -> CSSLength {
        CSSLength(value: value, unit: .rem)
    }

    public static func vh(_ value: Double) -> CSSLength {
        CSSLength(value: value, unit: .vh)
    }

    public static func vw(_ value: Double) -> CSSLength {
        CSSLength(value: value, unit: .vw)
    }

    public static func pt(_ value: Double) -> CSSLength {
        CSSLength(value: value, unit: .pt)
    }

    public func toPoints() -> Double {
        switch unit {
        case .px: return value
        case .pt: return value * 1.333333
        case .em, .rem: return value * 16.0
        case .percent: return value
        case .vw, .vh, .vmin, .vmax: return value
        case .ch: return value * 8.0
        case .ex: return value * 8.0
        case .cm: return value * 37.795275591
        case .mm: return value * 3.7795275591
        case .inch: return value * 96.0
        }
    }
}

public enum CSSLengthUnit: String, Codable, Sendable {
    case px
    case pt
    case em
    case rem
    case percent = "%"
    case vw
    case vh
    case vmin
    case vmax
    case ch
    case ex
    case cm
    case mm
    case inch = "in"
}

public struct CSSColor: Codable, Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        switch hexSanitized.count {
        case 6:
            self.red = Double((rgb & 0xFF0000) >> 16) / 255.0
            self.green = Double((rgb & 0x00FF00) >> 8) / 255.0
            self.blue = Double(rgb & 0x0000FF) / 255.0
            self.alpha = 1.0
        case 8:
            self.red = Double((rgb & 0xFF000000) >> 24) / 255.0
            self.green = Double((rgb & 0x00FF0000) >> 16) / 255.0
            self.blue = Double((rgb & 0x0000FF00) >> 8) / 255.0
            self.alpha = Double(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }
    }

    public func toHex() -> String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

public struct CSSBoxShadow: Codable, Sendable, Equatable {
    public let offsetX: CSSLength
    public let offsetY: CSSLength
    public let blurRadius: CSSLength?
    public let spreadRadius: CSSLength?
    public let color: CSSColor
    public let inset: Bool

    public init(
        offsetX: CSSLength,
        offsetY: CSSLength,
        blurRadius: CSSLength? = nil,
        spreadRadius: CSSLength? = nil,
        color: CSSColor,
        inset: Bool = false
    ) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.blurRadius = blurRadius
        self.spreadRadius = spreadRadius
        self.color = color
        self.inset = inset
    }
}

public struct CSSBorder: Codable, Sendable, Equatable {
    public let width: CSSLength
    public let style: CSSBorderStyle
    public let color: CSSColor

    public init(width: CSSLength, style: CSSBorderStyle, color: CSSColor) {
        self.width = width
        self.style = style
        self.color = color
    }
}

// MARK: - CSS Transform

public enum CSSTransformFunction: Codable, Sendable, Equatable {
    case translate(x: CSSLength, y: CSSLength)
    case translateX(CSSLength)
    case translateY(CSSLength)
    case scale(x: Double, y: Double)
    case scaleX(Double)
    case scaleY(Double)
    case rotate(degrees: Double)
    case skew(x: Double, y: Double)
    case skewX(Double)
    case skewY(Double)
    case matrix(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double)
}

// MARK: - CSS Transition & Animation

public struct CSSTransition: Codable, Sendable, Equatable {
    public let property: String
    public let duration: Double
    public let timingFunction: CSSTimingFunction
    public let delay: Double

    public init(
        property: String,
        duration: Double,
        timingFunction: CSSTimingFunction = .ease,
        delay: Double = 0
    ) {
        self.property = property
        self.duration = duration
        self.timingFunction = timingFunction
        self.delay = delay
    }
}

public enum CSSTimingFunction: String, Codable, Sendable {
    case linear
    case ease
    case easeIn = "ease-in"
    case easeOut = "ease-out"
    case easeInOut = "ease-in-out"
    case stepStart = "step-start"
    case stepEnd = "step-end"
}

public struct CSSKeyframeAnimation: Codable, Sendable, Equatable {
    public let name: String
    public let duration: Double
    public let timingFunction: CSSTimingFunction
    public let delay: Double
    public let iterationCount: CSSAnimationIterationCount
    public let direction: CSSAnimationDirection
    public let fillMode: CSSAnimationFillMode
    public let keyframes: [CSSKeyframe]

    public init(
        name: String,
        duration: Double,
        timingFunction: CSSTimingFunction = .ease,
        delay: Double = 0,
        iterationCount: CSSAnimationIterationCount = .count(1),
        direction: CSSAnimationDirection = .normal,
        fillMode: CSSAnimationFillMode = .none,
        keyframes: [CSSKeyframe] = []
    ) {
        self.name = name
        self.duration = duration
        self.timingFunction = timingFunction
        self.delay = delay
        self.iterationCount = iterationCount
        self.direction = direction
        self.fillMode = fillMode
        self.keyframes = keyframes
    }
}

public enum CSSAnimationIterationCount: Codable, Sendable, Equatable {
    case infinite
    case count(Double)
}

public enum CSSAnimationDirection: String, Codable, Sendable {
    case normal
    case reverse
    case alternate
    case alternateReverse = "alternate-reverse"
}

public enum CSSAnimationFillMode: String, Codable, Sendable {
    case none
    case forwards
    case backwards
    case both
}

public struct CSSKeyframe: Codable, Sendable, Equatable {
    public let percentage: Double
    public let properties: [String: String]

    public init(percentage: Double, properties: [String: String]) {
        self.percentage = percentage
        self.properties = properties
    }
}

// MARK: - CSS Grid

public struct CSSGridTemplate: Codable, Sendable, Equatable {
    public let columns: [CSSGridTrack]
    public let rows: [CSSGridTrack]
    public let columnGap: CSSLength?
    public let rowGap: CSSLength?

    public init(
        columns: [CSSGridTrack],
        rows: [CSSGridTrack] = [],
        columnGap: CSSLength? = nil,
        rowGap: CSSLength? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.columnGap = columnGap
        self.rowGap = rowGap
    }
}

public enum CSSGridTrack: Codable, Sendable, Equatable {
    case length(CSSLength)
    case fr(Double)
    case minmax(min: CSSGridTrackSize, max: CSSGridTrackSize)
    case fitContent(CSSLength)
    case auto
    case minContent
    case maxContent
    case repeatTrack(count: CSSGridRepeatCount, tracks: [CSSGridTrack])
}

public enum CSSGridTrackSize: Codable, Sendable, Equatable {
    case length(CSSLength)
    case fr(Double)
    case auto
    case minContent
    case maxContent
}

public enum CSSGridRepeatCount: Codable, Sendable, Equatable {
    case count(Int)
    case autoFill
    case autoFit
}

// MARK: - Computed CSS Style

public struct ComputedCSSStyle: Codable, Sendable {
    // Layout
    public var display: CSSDisplay?
    public var flexDirection: CSSFlexDirection?
    public var flexWrap: CSSFlexWrap?
    public var justifyContent: CSSJustifyContent?
    public var alignItems: CSSAlignItems?
    public var alignContent: CSSAlignContent?
    public var alignSelf: CSSAlignSelf?
    public var gap: CSSLength?
    public var rowGap: CSSLength?
    public var columnGap: CSSLength?
    public var flexGrow: Double?
    public var flexShrink: Double?
    public var flexBasis: CSSLength?
    public var order: Int?

    // Grid
    public var gridTemplate: CSSGridTemplate?
    public var gridColumn: String?
    public var gridRow: String?

    // Position
    public var position: CSSPosition?
    public var top: CSSLength?
    public var right: CSSLength?
    public var bottom: CSSLength?
    public var left: CSSLength?
    public var zIndex: Int?

    // Sizing
    public var width: CSSLength?
    public var height: CSSLength?
    public var minWidth: CSSLength?
    public var minHeight: CSSLength?
    public var maxWidth: CSSLength?
    public var maxHeight: CSSLength?

    // Spacing
    public var paddingTop: CSSLength?
    public var paddingRight: CSSLength?
    public var paddingBottom: CSSLength?
    public var paddingLeft: CSSLength?
    public var marginTop: CSSLength?
    public var marginRight: CSSLength?
    public var marginBottom: CSSLength?
    public var marginLeft: CSSLength?

    // Typography
    public var fontFamily: String?
    public var fontSize: CSSLength?
    public var fontWeight: CSSFontWeight?
    public var fontStyle: String?
    public var lineHeight: Double?
    public var letterSpacing: CSSLength?
    public var textAlign: CSSTextAlign?
    public var textDecoration: CSSTextDecoration?
    public var textTransform: CSSTextTransform?
    public var whiteSpace: CSSWhiteSpace?
    public var color: CSSColor?

    // Background
    public var backgroundColor: CSSColor?
    public var backgroundImage: String?

    // Border
    public var borderTop: CSSBorder?
    public var borderRight: CSSBorder?
    public var borderBottom: CSSBorder?
    public var borderLeft: CSSBorder?
    public var borderTopLeftRadius: CSSLength?
    public var borderTopRightRadius: CSSLength?
    public var borderBottomRightRadius: CSSLength?
    public var borderBottomLeftRadius: CSSLength?

    // Effects
    public var opacity: Double?
    public var boxShadow: [CSSBoxShadow]?
    public var transform: [CSSTransformFunction]?
    public var transition: [CSSTransition]?
    public var animation: CSSKeyframeAnimation?

    // Overflow
    public var overflowX: CSSOverflow?
    public var overflowY: CSSOverflow?

    // Misc
    public var cursor: String?
    public var visibility: String?
    public var pointerEvents: String?
    public var userSelect: String?

    public init() {}
}
