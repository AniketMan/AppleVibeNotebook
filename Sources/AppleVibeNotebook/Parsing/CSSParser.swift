import Foundation

// MARK: - CSS Parser

/// Parses CSS AST and converts it to ComputedCSSStyle objects.
/// Maps CSS selectors to their computed styles.
public final class CSSParser: @unchecked Sendable {

    private let runtime: JavaScriptRuntime
    private var styleCache: [String: ComputedCSSStyle] = [:]
    private let lock = NSLock()

    public enum ParserError: Error, LocalizedError {
        case parsingFailed(String)
        case invalidCSS(String)

        public var errorDescription: String? {
            switch self {
            case .parsingFailed(let msg): return "CSS parsing failed: \(msg)"
            case .invalidCSS(let msg): return "Invalid CSS: \(msg)"
            }
        }
    }

    public init(runtime: JavaScriptRuntime = .shared) {
        self.runtime = runtime
    }

    // MARK: - Public API

    /// Parses CSS code and returns a dictionary mapping selectors to computed styles.
    public func parseCSS(_ code: String) throws -> [String: ComputedCSSStyle] {
        let parseResult = try runtime.parseCSS(code)
        let rules = try runtime.extractCSSRules(from: parseResult.ast)

        var styles: [String: ComputedCSSStyle] = [:]
        var keyframes: [String: [CSSKeyframe]] = [:]

        for rule in rules {
            if let type = rule["type"] as? String, type == "keyframes" {
                let name = rule["name"] as? String ?? ""
                let kfs = rule["keyframes"] as? [[String: Any]] ?? []
                keyframes[name] = parseKeyframes(kfs)
            } else if let selector = rule["selector"] as? String {
                let declarations = rule["declarations"] as? [String: String] ?? [:]
                let computedStyle = computeStyle(from: declarations, keyframes: keyframes)
                styles[selector] = computedStyle
            }
        }

        lock.lock()
        defer { lock.unlock() }
        for (selector, style) in styles {
            styleCache[selector] = style
        }

        return styles
    }

    /// Parses CSS from a file URL.
    public func parseCSSFile(at url: URL) throws -> [String: ComputedCSSStyle] {
        let code = try String(contentsOf: url, encoding: .utf8)
        return try parseCSS(code)
    }

    /// Gets the computed style for a class name.
    public func getStyle(forClass className: String) -> ComputedCSSStyle? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = styleCache[".\(className)"] {
            return cached
        }
        return styleCache[className]
    }

    /// Gets the computed style for multiple class names (merged).
    public func getMergedStyle(forClasses classNames: [String]) -> ComputedCSSStyle {
        var merged = ComputedCSSStyle()

        for className in classNames {
            if let style = getStyle(forClass: className) {
                merged = mergeStyles(merged, style)
            }
        }

        return merged
    }

    // MARK: - Style Computation

    private func computeStyle(
        from declarations: [String: String],
        keyframes: [String: [CSSKeyframe]]
    ) -> ComputedCSSStyle {
        var style = ComputedCSSStyle()

        for (property, value) in declarations {
            applyProperty(property, value: value, to: &style, keyframes: keyframes)
        }

        return style
    }

    private func applyProperty(
        _ property: String,
        value: String,
        to style: inout ComputedCSSStyle,
        keyframes: [String: [CSSKeyframe]]
    ) {
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)

        switch property {
        // Layout
        case "display":
            style.display = CSSDisplay(rawValue: trimmedValue)

        case "flex-direction":
            style.flexDirection = CSSFlexDirection(rawValue: trimmedValue)

        case "flex-wrap":
            style.flexWrap = CSSFlexWrap(rawValue: trimmedValue)

        case "justify-content":
            style.justifyContent = CSSJustifyContent(rawValue: trimmedValue)

        case "align-items":
            style.alignItems = CSSAlignItems(rawValue: trimmedValue)

        case "align-content":
            style.alignContent = CSSAlignContent(rawValue: trimmedValue)

        case "align-self":
            style.alignSelf = CSSAlignSelf(rawValue: trimmedValue)

        case "gap":
            let length = parseLength(trimmedValue)
            style.gap = length
            style.rowGap = length
            style.columnGap = length

        case "row-gap":
            style.rowGap = parseLength(trimmedValue)

        case "column-gap":
            style.columnGap = parseLength(trimmedValue)

        case "flex-grow":
            style.flexGrow = Double(trimmedValue)

        case "flex-shrink":
            style.flexShrink = Double(trimmedValue)

        case "flex-basis":
            style.flexBasis = parseLength(trimmedValue)

        case "order":
            style.order = Int(trimmedValue)

        case "flex":
            let parts = trimmedValue.split(separator: " ")
            if parts.count >= 1 {
                style.flexGrow = Double(parts[0])
            }
            if parts.count >= 2 {
                style.flexShrink = Double(parts[1])
            }
            if parts.count >= 3 {
                style.flexBasis = parseLength(String(parts[2]))
            }

        // Position
        case "position":
            style.position = CSSPosition(rawValue: trimmedValue)

        case "top":
            style.top = parseLength(trimmedValue)

        case "right":
            style.right = parseLength(trimmedValue)

        case "bottom":
            style.bottom = parseLength(trimmedValue)

        case "left":
            style.left = parseLength(trimmedValue)

        case "z-index":
            style.zIndex = Int(trimmedValue)

        // Sizing
        case "width":
            style.width = parseLength(trimmedValue)

        case "height":
            style.height = parseLength(trimmedValue)

        case "min-width":
            style.minWidth = parseLength(trimmedValue)

        case "min-height":
            style.minHeight = parseLength(trimmedValue)

        case "max-width":
            style.maxWidth = parseLength(trimmedValue)

        case "max-height":
            style.maxHeight = parseLength(trimmedValue)

        // Padding
        case "padding":
            let lengths = parseFourSideValues(trimmedValue)
            style.paddingTop = lengths.top
            style.paddingRight = lengths.right
            style.paddingBottom = lengths.bottom
            style.paddingLeft = lengths.left

        case "padding-top":
            style.paddingTop = parseLength(trimmedValue)

        case "padding-right":
            style.paddingRight = parseLength(trimmedValue)

        case "padding-bottom":
            style.paddingBottom = parseLength(trimmedValue)

        case "padding-left":
            style.paddingLeft = parseLength(trimmedValue)

        // Margin
        case "margin":
            let lengths = parseFourSideValues(trimmedValue)
            style.marginTop = lengths.top
            style.marginRight = lengths.right
            style.marginBottom = lengths.bottom
            style.marginLeft = lengths.left

        case "margin-top":
            style.marginTop = parseLength(trimmedValue)

        case "margin-right":
            style.marginRight = parseLength(trimmedValue)

        case "margin-bottom":
            style.marginBottom = parseLength(trimmedValue)

        case "margin-left":
            style.marginLeft = parseLength(trimmedValue)

        // Typography
        case "font-family":
            style.fontFamily = trimmedValue.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "")

        case "font-size":
            style.fontSize = parseLength(trimmedValue)

        case "font-weight":
            style.fontWeight = CSSFontWeight(rawValue: trimmedValue)

        case "font-style":
            style.fontStyle = trimmedValue

        case "line-height":
            if let number = Double(trimmedValue) {
                style.lineHeight = number
            } else if let length = parseLength(trimmedValue), length.unit == .px {
                style.lineHeight = length.value / 16.0
            }

        case "letter-spacing":
            style.letterSpacing = parseLength(trimmedValue)

        case "text-align":
            style.textAlign = CSSTextAlign(rawValue: trimmedValue)

        case "text-decoration":
            style.textDecoration = CSSTextDecoration(rawValue: trimmedValue)

        case "text-transform":
            style.textTransform = CSSTextTransform(rawValue: trimmedValue)

        case "white-space":
            style.whiteSpace = CSSWhiteSpace(rawValue: trimmedValue)

        case "color":
            style.color = parseColor(trimmedValue)

        // Background
        case "background-color":
            style.backgroundColor = parseColor(trimmedValue)

        case "background":
            if let color = parseColor(trimmedValue) {
                style.backgroundColor = color
            } else {
                style.backgroundImage = trimmedValue
            }

        case "background-image":
            style.backgroundImage = trimmedValue

        // Border
        case "border":
            let border = parseBorder(trimmedValue)
            style.borderTop = border
            style.borderRight = border
            style.borderBottom = border
            style.borderLeft = border

        case "border-top":
            style.borderTop = parseBorder(trimmedValue)

        case "border-right":
            style.borderRight = parseBorder(trimmedValue)

        case "border-bottom":
            style.borderBottom = parseBorder(trimmedValue)

        case "border-left":
            style.borderLeft = parseBorder(trimmedValue)

        case "border-radius":
            let radii = parseFourSideValues(trimmedValue)
            style.borderTopLeftRadius = radii.top
            style.borderTopRightRadius = radii.right
            style.borderBottomRightRadius = radii.bottom
            style.borderBottomLeftRadius = radii.left

        case "border-top-left-radius":
            style.borderTopLeftRadius = parseLength(trimmedValue)

        case "border-top-right-radius":
            style.borderTopRightRadius = parseLength(trimmedValue)

        case "border-bottom-right-radius":
            style.borderBottomRightRadius = parseLength(trimmedValue)

        case "border-bottom-left-radius":
            style.borderBottomLeftRadius = parseLength(trimmedValue)

        // Effects
        case "opacity":
            style.opacity = Double(trimmedValue)

        case "box-shadow":
            style.boxShadow = parseBoxShadows(trimmedValue)

        case "transform":
            style.transform = parseTransform(trimmedValue)

        case "transition":
            style.transition = parseTransitions(trimmedValue)

        case "animation":
            style.animation = parseAnimation(trimmedValue, keyframes: keyframes)

        // Overflow
        case "overflow":
            let overflow = CSSOverflow(rawValue: trimmedValue)
            style.overflowX = overflow
            style.overflowY = overflow

        case "overflow-x":
            style.overflowX = CSSOverflow(rawValue: trimmedValue)

        case "overflow-y":
            style.overflowY = CSSOverflow(rawValue: trimmedValue)

        // Misc
        case "cursor":
            style.cursor = trimmedValue

        case "visibility":
            style.visibility = trimmedValue

        case "pointer-events":
            style.pointerEvents = trimmedValue

        case "user-select":
            style.userSelect = trimmedValue

        // Grid (basic support)
        case "grid-template-columns":
            let columns = parseGridTracks(trimmedValue)
            if style.gridTemplate == nil {
                style.gridTemplate = CSSGridTemplate(columns: columns)
            }

        default:
            break
        }
    }

    // MARK: - Value Parsers

    private func parseLength(_ value: String) -> CSSLength? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed == "auto" || trimmed == "0" {
            return CSSLength(value: 0, unit: .px)
        }

        let numericPattern = "^(-?[0-9]*\\.?[0-9]+)(px|em|rem|%|vh|vw|vmin|vmax|pt|ch)?$"
        guard let regex = try? NSRegularExpression(pattern: numericPattern, options: []),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }

        guard let numberRange = Range(match.range(at: 1), in: trimmed),
              let number = Double(trimmed[numberRange]) else {
            return nil
        }

        var unitStr = "px"
        if let unitRange = Range(match.range(at: 2), in: trimmed) {
            unitStr = String(trimmed[unitRange])
        }

        let unit: CSSLengthUnit
        switch unitStr {
        case "px": unit = .px
        case "em": unit = .em
        case "rem": unit = .rem
        case "%": unit = .percent
        case "vh": unit = .vh
        case "vw": unit = .vw
        case "vmin": unit = .vmin
        case "vmax": unit = .vmax
        case "pt": unit = .pt
        case "ch": unit = .ch
        default: unit = .px
        }

        return CSSLength(value: number, unit: unit)
    }

    private func parseFourSideValues(_ value: String) -> (top: CSSLength?, right: CSSLength?, bottom: CSSLength?, left: CSSLength?) {
        let parts = value.split(separator: " ").map { String($0) }

        switch parts.count {
        case 1:
            let v = parseLength(parts[0])
            return (v, v, v, v)
        case 2:
            let tb = parseLength(parts[0])
            let lr = parseLength(parts[1])
            return (tb, lr, tb, lr)
        case 3:
            let t = parseLength(parts[0])
            let lr = parseLength(parts[1])
            let b = parseLength(parts[2])
            return (t, lr, b, lr)
        case 4:
            return (parseLength(parts[0]), parseLength(parts[1]), parseLength(parts[2]), parseLength(parts[3]))
        default:
            return (nil, nil, nil, nil)
        }
    }

    private func parseColor(_ value: String) -> CSSColor? {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()

        if trimmed == "transparent" {
            return CSSColor(red: 0, green: 0, blue: 0, alpha: 0)
        }

        if let namedColor = namedColors[trimmed] {
            return namedColor
        }

        if trimmed.hasPrefix("#") {
            return parseHexColor(trimmed)
        }

        if trimmed.hasPrefix("rgb") {
            return parseRGBColor(trimmed)
        }

        if trimmed.hasPrefix("hsl") {
            return parseHSLColor(trimmed)
        }

        return nil
    }

    private func parseHexColor(_ hex: String) -> CSSColor? {
        var hexString = hex.trimmingCharacters(in: .whitespaces)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        var r: Double = 0, g: Double = 0, b: Double = 0, a: Double = 1

        switch hexString.count {
        case 3:
            let chars = Array(hexString)
            r = Double(Int(String(chars[0]) + String(chars[0]), radix: 16) ?? 0) / 255
            g = Double(Int(String(chars[1]) + String(chars[1]), radix: 16) ?? 0) / 255
            b = Double(Int(String(chars[2]) + String(chars[2]), radix: 16) ?? 0) / 255

        case 4:
            let chars = Array(hexString)
            r = Double(Int(String(chars[0]) + String(chars[0]), radix: 16) ?? 0) / 255
            g = Double(Int(String(chars[1]) + String(chars[1]), radix: 16) ?? 0) / 255
            b = Double(Int(String(chars[2]) + String(chars[2]), radix: 16) ?? 0) / 255
            a = Double(Int(String(chars[3]) + String(chars[3]), radix: 16) ?? 0) / 255

        case 6:
            r = Double(Int(hexString.prefix(2), radix: 16) ?? 0) / 255
            g = Double(Int(hexString.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255
            b = Double(Int(hexString.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255

        case 8:
            r = Double(Int(hexString.prefix(2), radix: 16) ?? 0) / 255
            g = Double(Int(hexString.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255
            b = Double(Int(hexString.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255
            a = Double(Int(hexString.dropFirst(6).prefix(2), radix: 16) ?? 0) / 255

        default:
            return nil
        }

        return CSSColor(red: r, green: g, blue: b, alpha: a)
    }

    private func parseRGBColor(_ value: String) -> CSSColor? {
        let pattern = "rgba?\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*(?:,\\s*([0-9.]+))?\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: value, options: [], range: NSRange(value.startIndex..., in: value)) else {
            return nil
        }

        func extract(_ index: Int) -> Double? {
            guard let range = Range(match.range(at: index), in: value) else { return nil }
            return Double(value[range])
        }

        guard let r = extract(1), let g = extract(2), let b = extract(3) else { return nil }
        let a = extract(4) ?? 1

        return CSSColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    private func parseHSLColor(_ value: String) -> CSSColor? {
        let pattern = "hsla?\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)%\\s*,\\s*([0-9.]+)%\\s*(?:,\\s*([0-9.]+))?\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: value, options: [], range: NSRange(value.startIndex..., in: value)) else {
            return nil
        }

        func extract(_ index: Int) -> Double? {
            guard let range = Range(match.range(at: index), in: value) else { return nil }
            return Double(value[range])
        }

        guard let h = extract(1), let s = extract(2), let l = extract(3) else { return nil }
        let a = extract(4) ?? 1

        let rgb = hslToRGB(h: h, s: s / 100, l: l / 100)
        return CSSColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: a)
    }

    private func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        if s == 0 {
            return (l, l, l)
        }

        let hue = h / 360
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        func hueToRGB(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1/6 { return p + (q - p) * 6 * t }
            if t < 1/2 { return q }
            if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
            return p
        }

        return (
            hueToRGB(p, q, hue + 1/3),
            hueToRGB(p, q, hue),
            hueToRGB(p, q, hue - 1/3)
        )
    }

    private func parseBorder(_ value: String) -> CSSBorder? {
        let parts = value.split(separator: " ").map { String($0) }
        guard !parts.isEmpty else { return nil }

        var width: CSSLength?
        var style: CSSBorderStyle?
        var color: CSSColor?

        for part in parts {
            if let w = parseLength(part) {
                width = w
            } else if let s = CSSBorderStyle(rawValue: part) {
                style = s
            } else if let c = parseColor(part) {
                color = c
            }
        }

        return CSSBorder(
            width: width ?? CSSLength(value: 1, unit: .px),
            style: style ?? .solid,
            color: color ?? CSSColor(red: 0, green: 0, blue: 0, alpha: 1)
        )
    }

    private func parseBoxShadows(_ value: String) -> [CSSBoxShadow] {
        var shadows: [CSSBoxShadow] = []
        let shadowStrings = value.components(separatedBy: ",")

        for shadowStr in shadowStrings {
            let trimmed = shadowStr.trimmingCharacters(in: .whitespaces)
            if let shadow = parseBoxShadow(trimmed) {
                shadows.append(shadow)
            }
        }

        return shadows
    }

    private func parseBoxShadow(_ value: String) -> CSSBoxShadow? {
        var inset = false
        var parts = value.split(separator: " ").map { String($0) }

        if let idx = parts.firstIndex(of: "inset") {
            inset = true
            parts.remove(at: idx)
        }

        var lengths: [CSSLength] = []
        var color: CSSColor?

        for part in parts {
            if let length = parseLength(part) {
                lengths.append(length)
            } else if let c = parseColor(part) {
                color = c
            }
        }

        guard lengths.count >= 2 else { return nil }

        let zeroLength = CSSLength(value: 0, unit: .px)

        return CSSBoxShadow(
            offsetX: lengths[0],
            offsetY: lengths[1],
            blurRadius: lengths.count > 2 ? lengths[2] : zeroLength,
            spreadRadius: lengths.count > 3 ? lengths[3] : zeroLength,
            color: color ?? CSSColor(red: 0, green: 0, blue: 0, alpha: 0.5),
            inset: inset
        )
    }

    private func parseTransform(_ value: String) -> [CSSTransformFunction] {
        var transforms: [CSSTransformFunction] = []

        let pattern = "(\\w+)\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return transforms
        }

        let matches = regex.matches(in: value, options: [], range: NSRange(value.startIndex..., in: value))
        let zeroLength = CSSLength(value: 0, unit: .px)

        for match in matches {
            guard let funcRange = Range(match.range(at: 1), in: value),
                  let argsRange = Range(match.range(at: 2), in: value) else { continue }

            let funcName = String(value[funcRange])
            let argsStr = String(value[argsRange])
            let args = argsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            switch funcName {
            case "translateX":
                if let x = parseLength(args[0]) {
                    transforms.append(.translateX(x))
                }
            case "translateY":
                if let y = parseLength(args[0]) {
                    transforms.append(.translateY(y))
                }
            case "translate":
                if args.count >= 2, let x = parseLength(args[0]), let y = parseLength(args[1]) {
                    transforms.append(.translate(x: x, y: y))
                } else if let x = parseLength(args[0]) {
                    transforms.append(.translate(x: x, y: zeroLength))
                }
            case "scale":
                if args.count >= 2, let x = Double(args[0]), let y = Double(args[1]) {
                    transforms.append(.scale(x: x, y: y))
                } else if let s = Double(args[0]) {
                    transforms.append(.scale(x: s, y: s))
                }
            case "scaleX":
                if let s = Double(args[0]) {
                    transforms.append(.scaleX(s))
                }
            case "scaleY":
                if let s = Double(args[0]) {
                    transforms.append(.scaleY(s))
                }
            case "rotate":
                if let angle = parseDegrees(args[0]) {
                    transforms.append(.rotate(degrees: angle))
                }
            case "skew":
                if args.count >= 2, let x = parseDegrees(args[0]), let y = parseDegrees(args[1]) {
                    transforms.append(.skew(x: x, y: y))
                } else if let x = parseDegrees(args[0]) {
                    transforms.append(.skew(x: x, y: 0))
                }
            case "skewX":
                if let angle = parseDegrees(args[0]) {
                    transforms.append(.skewX(angle))
                }
            case "skewY":
                if let angle = parseDegrees(args[0]) {
                    transforms.append(.skewY(angle))
                }
            default:
                break
            }
        }

        return transforms
    }

    private func parseDegrees(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.hasSuffix("deg") {
            return Double(trimmed.dropLast(3))
        } else if trimmed.hasSuffix("rad") {
            if let num = Double(trimmed.dropLast(3)) {
                return num * 180 / .pi
            }
        } else if trimmed.hasSuffix("turn") {
            if let num = Double(trimmed.dropLast(4)) {
                return num * 360
            }
        } else if let num = Double(trimmed) {
            return num
        }

        return nil
    }

    private func parseTransitions(_ value: String) -> [CSSTransition] {
        var transitions: [CSSTransition] = []
        let transitionStrings = value.components(separatedBy: ",")

        for transStr in transitionStrings {
            let parts = transStr.trimmingCharacters(in: .whitespaces).split(separator: " ").map { String($0) }
            guard !parts.isEmpty else { continue }

            var property = "all"
            var duration: Double = 0
            var delay: Double = 0
            var timing = CSSTimingFunction.ease

            for part in parts {
                if let d = parseTime(part) {
                    if duration == 0 {
                        duration = d
                    } else {
                        delay = d
                    }
                } else if let t = CSSTimingFunction(rawValue: part) {
                    timing = t
                } else if part.contains("cubic-bezier") {
                    timing = .ease
                } else {
                    property = part
                }
            }

            transitions.append(CSSTransition(
                property: property,
                duration: duration,
                timingFunction: timing,
                delay: delay
            ))
        }

        return transitions
    }

    private func parseTime(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.hasSuffix("ms") {
            return Double(trimmed.dropLast(2)).map { $0 / 1000 }
        } else if trimmed.hasSuffix("s") {
            return Double(trimmed.dropLast(1))
        }

        return Double(trimmed)
    }

    private func parseAnimation(_ value: String, keyframes: [String: [CSSKeyframe]]) -> CSSKeyframeAnimation? {
        let parts = value.split(separator: " ").map { String($0) }
        guard !parts.isEmpty else { return nil }

        var name: String?
        var duration: Double = 0
        var delay: Double = 0
        var timing = CSSTimingFunction.ease
        var iterations: CSSAnimationIterationCount = .count(1)
        var direction = CSSAnimationDirection.normal
        var fillMode = CSSAnimationFillMode.none

        for part in parts {
            if let d = parseTime(part) {
                if duration == 0 {
                    duration = d
                } else {
                    delay = d
                }
            } else if let t = CSSTimingFunction(rawValue: part) {
                timing = t
            } else if part == "infinite" {
                iterations = .infinite
            } else if let count = Double(part) {
                iterations = .count(count)
            } else if let d = CSSAnimationDirection(rawValue: part) {
                direction = d
            } else if let f = CSSAnimationFillMode(rawValue: part) {
                fillMode = f
            } else {
                name = part
            }
        }

        guard let animName = name else { return nil }

        return CSSKeyframeAnimation(
            name: animName,
            duration: duration,
            timingFunction: timing,
            delay: delay,
            iterationCount: iterations,
            direction: direction,
            fillMode: fillMode,
            keyframes: keyframes[animName] ?? []
        )
    }

    private func parseKeyframes(_ keyframes: [[String: Any]]) -> [CSSKeyframe] {
        var result: [CSSKeyframe] = []

        for kf in keyframes {
            let selector = kf["selector"] as? String ?? ""
            let properties = kf["properties"] as? [String: String] ?? [:]

            var percentage: Double = 0
            if selector == "from" {
                percentage = 0
            } else if selector == "to" {
                percentage = 100
            } else if let p = Double(selector.replacingOccurrences(of: "%", with: "")) {
                percentage = p
            }

            result.append(CSSKeyframe(percentage: percentage, properties: properties))
        }

        return result.sorted { $0.percentage < $1.percentage }
    }

    private func parseGridTracks(_ value: String) -> [CSSGridTrack] {
        var tracks: [CSSGridTrack] = []
        let parts = value.split(separator: " ").map { String($0) }

        for part in parts {
            if part == "auto" {
                tracks.append(.auto)
            } else if part == "min-content" {
                tracks.append(.minContent)
            } else if part == "max-content" {
                tracks.append(.maxContent)
            } else if part.hasSuffix("fr"), let num = Double(part.dropLast(2)) {
                tracks.append(.fr(num))
            } else if let length = parseLength(part) {
                tracks.append(.length(length))
            }
        }

        return tracks
    }

    // MARK: - Style Merging

    private func mergeStyles(_ base: ComputedCSSStyle, _ override: ComputedCSSStyle) -> ComputedCSSStyle {
        var merged = base

        if let v = override.display { merged.display = v }
        if let v = override.flexDirection { merged.flexDirection = v }
        if let v = override.flexWrap { merged.flexWrap = v }
        if let v = override.justifyContent { merged.justifyContent = v }
        if let v = override.alignItems { merged.alignItems = v }
        if let v = override.alignContent { merged.alignContent = v }
        if let v = override.alignSelf { merged.alignSelf = v }
        if let v = override.gap { merged.gap = v }
        if let v = override.rowGap { merged.rowGap = v }
        if let v = override.columnGap { merged.columnGap = v }
        if let v = override.flexGrow { merged.flexGrow = v }
        if let v = override.flexShrink { merged.flexShrink = v }
        if let v = override.flexBasis { merged.flexBasis = v }
        if let v = override.order { merged.order = v }
        if let v = override.gridTemplate { merged.gridTemplate = v }
        if let v = override.gridColumn { merged.gridColumn = v }
        if let v = override.gridRow { merged.gridRow = v }
        if let v = override.position { merged.position = v }
        if let v = override.top { merged.top = v }
        if let v = override.right { merged.right = v }
        if let v = override.bottom { merged.bottom = v }
        if let v = override.left { merged.left = v }
        if let v = override.zIndex { merged.zIndex = v }
        if let v = override.width { merged.width = v }
        if let v = override.height { merged.height = v }
        if let v = override.minWidth { merged.minWidth = v }
        if let v = override.minHeight { merged.minHeight = v }
        if let v = override.maxWidth { merged.maxWidth = v }
        if let v = override.maxHeight { merged.maxHeight = v }
        if let v = override.paddingTop { merged.paddingTop = v }
        if let v = override.paddingRight { merged.paddingRight = v }
        if let v = override.paddingBottom { merged.paddingBottom = v }
        if let v = override.paddingLeft { merged.paddingLeft = v }
        if let v = override.marginTop { merged.marginTop = v }
        if let v = override.marginRight { merged.marginRight = v }
        if let v = override.marginBottom { merged.marginBottom = v }
        if let v = override.marginLeft { merged.marginLeft = v }
        if let v = override.fontFamily { merged.fontFamily = v }
        if let v = override.fontSize { merged.fontSize = v }
        if let v = override.fontWeight { merged.fontWeight = v }
        if let v = override.fontStyle { merged.fontStyle = v }
        if let v = override.lineHeight { merged.lineHeight = v }
        if let v = override.letterSpacing { merged.letterSpacing = v }
        if let v = override.textAlign { merged.textAlign = v }
        if let v = override.textDecoration { merged.textDecoration = v }
        if let v = override.textTransform { merged.textTransform = v }
        if let v = override.whiteSpace { merged.whiteSpace = v }
        if let v = override.color { merged.color = v }
        if let v = override.backgroundColor { merged.backgroundColor = v }
        if let v = override.backgroundImage { merged.backgroundImage = v }
        if let v = override.borderTop { merged.borderTop = v }
        if let v = override.borderRight { merged.borderRight = v }
        if let v = override.borderBottom { merged.borderBottom = v }
        if let v = override.borderLeft { merged.borderLeft = v }
        if let v = override.borderTopLeftRadius { merged.borderTopLeftRadius = v }
        if let v = override.borderTopRightRadius { merged.borderTopRightRadius = v }
        if let v = override.borderBottomRightRadius { merged.borderBottomRightRadius = v }
        if let v = override.borderBottomLeftRadius { merged.borderBottomLeftRadius = v }
        if let v = override.opacity { merged.opacity = v }
        if let v = override.boxShadow { merged.boxShadow = v }
        if let v = override.transform { merged.transform = v }
        if let v = override.transition { merged.transition = v }
        if let v = override.animation { merged.animation = v }
        if let v = override.overflowX { merged.overflowX = v }
        if let v = override.overflowY { merged.overflowY = v }
        if let v = override.cursor { merged.cursor = v }
        if let v = override.visibility { merged.visibility = v }
        if let v = override.pointerEvents { merged.pointerEvents = v }
        if let v = override.userSelect { merged.userSelect = v }

        return merged
    }

    // MARK: - Named Colors

    private let namedColors: [String: CSSColor] = [
        "black": CSSColor(red: 0, green: 0, blue: 0, alpha: 1),
        "white": CSSColor(red: 1, green: 1, blue: 1, alpha: 1),
        "red": CSSColor(red: 1, green: 0, blue: 0, alpha: 1),
        "green": CSSColor(red: 0, green: 0.5, blue: 0, alpha: 1),
        "blue": CSSColor(red: 0, green: 0, blue: 1, alpha: 1),
        "yellow": CSSColor(red: 1, green: 1, blue: 0, alpha: 1),
        "cyan": CSSColor(red: 0, green: 1, blue: 1, alpha: 1),
        "magenta": CSSColor(red: 1, green: 0, blue: 1, alpha: 1),
        "gray": CSSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
        "grey": CSSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
        "silver": CSSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1),
        "maroon": CSSColor(red: 0.5, green: 0, blue: 0, alpha: 1),
        "olive": CSSColor(red: 0.5, green: 0.5, blue: 0, alpha: 1),
        "lime": CSSColor(red: 0, green: 1, blue: 0, alpha: 1),
        "aqua": CSSColor(red: 0, green: 1, blue: 1, alpha: 1),
        "teal": CSSColor(red: 0, green: 0.5, blue: 0.5, alpha: 1),
        "navy": CSSColor(red: 0, green: 0, blue: 0.5, alpha: 1),
        "fuchsia": CSSColor(red: 1, green: 0, blue: 1, alpha: 1),
        "purple": CSSColor(red: 0.5, green: 0, blue: 0.5, alpha: 1),
        "orange": CSSColor(red: 1, green: 0.65, blue: 0, alpha: 1),
        "pink": CSSColor(red: 1, green: 0.75, blue: 0.8, alpha: 1),
        "brown": CSSColor(red: 0.65, green: 0.16, blue: 0.16, alpha: 1),
        "coral": CSSColor(red: 1, green: 0.5, blue: 0.31, alpha: 1),
        "gold": CSSColor(red: 1, green: 0.84, blue: 0, alpha: 1),
        "indigo": CSSColor(red: 0.29, green: 0, blue: 0.51, alpha: 1),
        "ivory": CSSColor(red: 1, green: 1, blue: 0.94, alpha: 1),
        "khaki": CSSColor(red: 0.94, green: 0.9, blue: 0.55, alpha: 1),
        "lavender": CSSColor(red: 0.9, green: 0.9, blue: 0.98, alpha: 1),
        "lightblue": CSSColor(red: 0.68, green: 0.85, blue: 0.9, alpha: 1),
        "lightgray": CSSColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1),
        "lightgreen": CSSColor(red: 0.56, green: 0.93, blue: 0.56, alpha: 1),
        "lightyellow": CSSColor(red: 1, green: 1, blue: 0.88, alpha: 1),
        "darkblue": CSSColor(red: 0, green: 0, blue: 0.55, alpha: 1),
        "darkgray": CSSColor(red: 0.66, green: 0.66, blue: 0.66, alpha: 1),
        "darkgreen": CSSColor(red: 0, green: 0.39, blue: 0, alpha: 1),
        "darkred": CSSColor(red: 0.55, green: 0, blue: 0, alpha: 1),
        "crimson": CSSColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 1),
        "salmon": CSSColor(red: 0.98, green: 0.5, blue: 0.45, alpha: 1),
        "tomato": CSSColor(red: 1, green: 0.39, blue: 0.28, alpha: 1),
        "turquoise": CSSColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1),
        "violet": CSSColor(red: 0.93, green: 0.51, blue: 0.93, alpha: 1),
        "wheat": CSSColor(red: 0.96, green: 0.87, blue: 0.7, alpha: 1)
    ]
}
