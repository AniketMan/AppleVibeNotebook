import Foundation

// MARK: - Styling Mapping Dictionary

/// Deterministic mappings from CSS properties to SwiftUI view modifiers.
/// These mappings are derived from W3C CSS specifications and Apple SwiftUI documentation.
/// Reference: W3C CSS Level 3 specifications, Apple SwiftUI Documentation
public enum StylingMapping {

    // MARK: - Background

    /// Maps CSS background-color to SwiftUI .background modifier.
    public static func backgroundColorMapping(_ color: CSSColor) -> StylingMappingResult {
        let swiftColor = colorToSwiftUI(color)

        return StylingMappingResult(
            modifier: .background,
            code: ".background(\(swiftColor))",
            tier: .direct,
            explanation: "background-color maps directly to .background(Color)"
        )
    }

    /// Maps CSS background-image gradient to SwiftUI.
    public static func backgroundGradientMapping(_ gradient: String) -> StylingMappingResult {
        if gradient.contains("linear-gradient") {
            return StylingMappingResult(
                modifier: .background,
                code: ".background(LinearGradient(...))",
                tier: .adapted,
                explanation: "CSS linear-gradient maps to SwiftUI LinearGradient. " +
                            "Angle and color stops require manual conversion."
            )
        } else if gradient.contains("radial-gradient") {
            return StylingMappingResult(
                modifier: .background,
                code: ".background(RadialGradient(...))",
                tier: .adapted,
                explanation: "CSS radial-gradient maps to SwiftUI RadialGradient."
            )
        } else {
            return StylingMappingResult(
                modifier: .background,
                code: "// UNSUPPORTED: background-image",
                tier: .unsupported,
                explanation: "CSS background-image URL has no direct SwiftUI equivalent. " +
                            "Use AsyncImage in a ZStack overlay."
            )
        }
    }

    // MARK: - Color / Foreground

    /// Maps CSS color to SwiftUI .foregroundStyle modifier.
    public static func foregroundColorMapping(_ color: CSSColor) -> StylingMappingResult {
        let swiftColor = colorToSwiftUI(color)

        return StylingMappingResult(
            modifier: .foregroundStyle,
            code: ".foregroundStyle(\(swiftColor))",
            tier: .direct,
            explanation: "CSS color maps directly to .foregroundStyle(Color)"
        )
    }

    // MARK: - Typography

    /// Maps CSS font properties to SwiftUI font modifiers.
    public static func fontMapping(
        fontSize: CSSLength?,
        fontWeight: CSSFontWeight?,
        fontFamily: String?,
        fontStyle: String?
    ) -> TypographyMappingResult {
        var modifiers: [String] = []
        var tier: ConversionTier = .direct
        var explanations: [String] = []

        // Font size
        if let size = fontSize {
            let points = size.toPoints()

            // Check for semantic sizes
            let semanticFont = mapToSemanticFont(points: points)
            if let semantic = semanticFont {
                modifiers.append(".font(\(semantic))")
                explanations.append("font-size:\(size.value)\(size.unit.rawValue) maps to \(semantic)")
            } else {
                modifiers.append(".font(.system(size: \(points)))")
                explanations.append("font-size:\(size.value)\(size.unit.rawValue) maps to .system(size:)")
            }
        }

        // Font weight
        if let weight = fontWeight {
            let swiftWeight = mapFontWeight(weight)
            modifiers.append(".fontWeight(\(swiftWeight))")
            explanations.append("font-weight:\(weight.rawValue) maps to \(swiftWeight)")
        }

        // Font family
        if let family = fontFamily {
            let design = mapFontFamily(family)
            if design != nil {
                modifiers.append(".fontDesign(\(design!))")
                explanations.append("font-family maps to .fontDesign")
            } else {
                modifiers.append(".font(.custom(\"\(family)\", size: 17))")
                explanations.append("font-family:\(family) maps to .custom font")
                tier = .adapted
            }
        }

        // Font style (italic)
        if fontStyle == "italic" {
            modifiers.append(".italic()")
            explanations.append("font-style:italic maps to .italic()")
        }

        return TypographyMappingResult(
            modifiers: modifiers,
            tier: tier,
            explanation: explanations.joined(separator: "; ")
        )
    }

    /// Maps CSS text-align to SwiftUI alignment.
    public static func textAlignMapping(_ align: CSSTextAlign) -> StylingMappingResult {
        switch align {
        case .left, .start:
            return StylingMappingResult(
                modifier: .multilineTextAlignment,
                code: ".multilineTextAlignment(.leading)",
                tier: .direct,
                explanation: "text-align:left maps to .multilineTextAlignment(.leading)"
            )
        case .center:
            return StylingMappingResult(
                modifier: .multilineTextAlignment,
                code: ".multilineTextAlignment(.center)",
                tier: .direct,
                explanation: "text-align:center maps directly"
            )
        case .right, .end:
            return StylingMappingResult(
                modifier: .multilineTextAlignment,
                code: ".multilineTextAlignment(.trailing)",
                tier: .direct,
                explanation: "text-align:right maps to .multilineTextAlignment(.trailing)"
            )
        case .justify:
            return StylingMappingResult(
                modifier: .multilineTextAlignment,
                code: ".multilineTextAlignment(.leading) // justify not supported",
                tier: .adapted,
                explanation: "text-align:justify has no SwiftUI equivalent. Using .leading."
            )
        }
    }

    /// Maps CSS text-decoration to SwiftUI modifiers.
    public static func textDecorationMapping(_ decoration: CSSTextDecoration) -> StylingMappingResult {
        switch decoration {
        case .none:
            return StylingMappingResult(
                modifier: nil,
                code: "",
                tier: .direct,
                explanation: "text-decoration:none is the default"
            )
        case .underline:
            return StylingMappingResult(
                modifier: .underline,
                code: ".underline()",
                tier: .direct,
                explanation: "text-decoration:underline maps directly to .underline()"
            )
        case .lineThrough:
            return StylingMappingResult(
                modifier: .strikethrough,
                code: ".strikethrough()",
                tier: .direct,
                explanation: "text-decoration:line-through maps to .strikethrough()"
            )
        case .overline:
            return StylingMappingResult(
                modifier: nil,
                code: "// UNSUPPORTED: text-decoration:overline",
                tier: .unsupported,
                explanation: "text-decoration:overline has no SwiftUI equivalent"
            )
        }
    }

    /// Maps CSS text-transform to SwiftUI .textCase.
    public static func textTransformMapping(_ transform: CSSTextTransform) -> StylingMappingResult {
        switch transform {
        case .none:
            return StylingMappingResult(
                modifier: nil,
                code: "",
                tier: .direct,
                explanation: "text-transform:none is the default"
            )
        case .uppercase:
            return StylingMappingResult(
                modifier: .textCase,
                code: ".textCase(.uppercase)",
                tier: .direct,
                explanation: "text-transform:uppercase maps to .textCase(.uppercase)"
            )
        case .lowercase:
            return StylingMappingResult(
                modifier: .textCase,
                code: ".textCase(.lowercase)",
                tier: .direct,
                explanation: "text-transform:lowercase maps to .textCase(.lowercase)"
            )
        case .capitalize:
            return StylingMappingResult(
                modifier: nil,
                code: "// Apply .capitalized to string",
                tier: .adapted,
                explanation: "text-transform:capitalize requires String.capitalized on the value"
            )
        }
    }

    /// Maps CSS letter-spacing to SwiftUI .kerning.
    public static func letterSpacingMapping(_ spacing: CSSLength) -> StylingMappingResult {
        let points = spacing.toPoints()

        return StylingMappingResult(
            modifier: .kerning,
            code: ".kerning(\(points))",
            tier: .direct,
            explanation: "letter-spacing maps directly to .kerning()"
        )
    }

    /// Maps CSS line-height to SwiftUI .lineSpacing.
    public static func lineHeightMapping(_ lineHeight: Double, fontSize: CSSLength?) -> StylingMappingResult {
        let baseFontSize = fontSize?.toPoints() ?? 17.0
        let spacing = (lineHeight * baseFontSize) - baseFontSize

        return StylingMappingResult(
            modifier: .lineSpacing,
            code: ".lineSpacing(\(max(0, spacing)))",
            tier: .adapted,
            explanation: "line-height as multiplier maps to .lineSpacing. " +
                        "Calculated as (lineHeight * fontSize) - fontSize."
        )
    }

    // MARK: - Sizing

    /// Maps CSS width/height to SwiftUI .frame modifier.
    public static func sizeMapping(
        width: CSSLength?,
        height: CSSLength?,
        minWidth: CSSLength?,
        maxWidth: CSSLength?,
        minHeight: CSSLength?,
        maxHeight: CSSLength?
    ) -> StylingMappingResult {
        var params: [String] = []
        var tier: ConversionTier = .direct

        if let w = width {
            if w.unit == .percent {
                params.append("maxWidth: .infinity")
                tier = .adapted
            } else {
                params.append("width: \(w.toPoints())")
            }
        }

        if let h = height {
            if h.unit == .percent {
                params.append("maxHeight: .infinity")
                tier = .adapted
            } else {
                params.append("height: \(h.toPoints())")
            }
        }

        if let mw = minWidth { params.append("minWidth: \(mw.toPoints())") }
        if let xw = maxWidth {
            if xw.unit == .percent && xw.value == 100 {
                params.append("maxWidth: .infinity")
            } else {
                params.append("maxWidth: \(xw.toPoints())")
            }
        }
        if let mh = minHeight { params.append("minHeight: \(mh.toPoints())") }
        if let xh = maxHeight {
            if xh.unit == .percent && xh.value == 100 {
                params.append("maxHeight: .infinity")
            } else {
                params.append("maxHeight: \(xh.toPoints())")
            }
        }

        if params.isEmpty {
            return StylingMappingResult(
                modifier: nil,
                code: "",
                tier: .direct,
                explanation: "No sizing specified"
            )
        }

        let code = ".frame(\(params.joined(separator: ", ")))"

        return StylingMappingResult(
            modifier: .frame,
            code: code,
            tier: tier,
            explanation: tier == .direct
                ? "CSS sizing maps to .frame modifier"
                : "Percentage widths/heights map to .infinity with parent constraints"
        )
    }

    // MARK: - Spacing (Padding/Margin)

    /// Maps CSS padding to SwiftUI .padding modifier.
    public static func paddingMapping(
        top: CSSLength?,
        right: CSSLength?,
        bottom: CSSLength?,
        left: CSSLength?
    ) -> StylingMappingResult {
        let t = top?.toPoints()
        let r = right?.toPoints()
        let b = bottom?.toPoints()
        let l = left?.toPoints()

        // Check for uniform padding
        if let t = t, t == r && r == b && b == l {
            return StylingMappingResult(
                modifier: .padding,
                code: ".padding(\(t))",
                tier: .direct,
                explanation: "Uniform padding maps to .padding(value)"
            )
        }

        // Check for symmetric padding
        if t == b && l == r {
            var parts: [String] = []
            if let v = t { parts.append(".padding(.vertical, \(v))") }
            if let h = l { parts.append(".padding(.horizontal, \(h))") }

            return StylingMappingResult(
                modifier: .padding,
                code: parts.joined(separator: "\n"),
                tier: .direct,
                explanation: "Symmetric padding maps to .padding(.vertical/horizontal)"
            )
        }

        // Individual edge padding
        var parts: [String] = []
        if let t = t { parts.append(".padding(.top, \(t))") }
        if let r = r { parts.append(".padding(.trailing, \(r))") }
        if let b = b { parts.append(".padding(.bottom, \(b))") }
        if let l = l { parts.append(".padding(.leading, \(l))") }

        return StylingMappingResult(
            modifier: .padding,
            code: parts.joined(separator: "\n"),
            tier: .direct,
            explanation: "Individual padding values map to .padding(.edge, value)"
        )
    }

    /// Maps CSS margin to SwiftUI (no direct equivalent).
    public static func marginMapping(
        top: CSSLength?,
        right: CSSLength?,
        bottom: CSSLength?,
        left: CSSLength?
    ) -> StylingMappingResult {
        let t = top?.toPoints() ?? 0
        let r = right?.toPoints() ?? 0
        let b = bottom?.toPoints() ?? 0
        let l = left?.toPoints() ?? 0

        if t == 0 && r == 0 && b == 0 && l == 0 {
            return StylingMappingResult(
                modifier: nil,
                code: "",
                tier: .direct,
                explanation: "No margin specified"
            )
        }

        // Check for auto centering
        if l == r && top == nil && bottom == nil {
            return StylingMappingResult(
                modifier: .frame,
                code: ".frame(maxWidth: .infinity, alignment: .center)",
                tier: .adapted,
                explanation: "margin:0 auto maps to centered frame with maxWidth"
            )
        }

        // Map to padding on parent or spacers
        var parts: [String] = []
        if t > 0 { parts.append(".padding(.top, \(t)) // margin-top on parent") }
        if r > 0 { parts.append(".padding(.trailing, \(r)) // margin-right on parent") }
        if b > 0 { parts.append(".padding(.bottom, \(b)) // margin-bottom on parent") }
        if l > 0 { parts.append(".padding(.leading, \(l)) // margin-left on parent") }

        return StylingMappingResult(
            modifier: .padding,
            code: parts.joined(separator: "\n"),
            tier: .adapted,
            explanation: "CSS margin has no SwiftUI equivalent. " +
                        "Apply as padding on parent container or use Spacer()."
        )
    }

    // MARK: - Border

    /// Maps CSS border to SwiftUI .overlay with stroke.
    public static func borderMapping(_ border: CSSBorder) -> StylingMappingResult {
        let color = colorToSwiftUI(border.color)
        let width = border.width.toPoints()

        switch border.style {
        case .none, .hidden:
            return StylingMappingResult(
                modifier: nil,
                code: "",
                tier: .direct,
                explanation: "border:none has no visual effect"
            )

        case .solid:
            return StylingMappingResult(
                modifier: .overlay,
                code: ".overlay(RoundedRectangle(cornerRadius: 0).stroke(\(color), lineWidth: \(width)))",
                tier: .direct,
                explanation: "border:solid maps to .overlay with stroke"
            )

        case .dashed:
            return StylingMappingResult(
                modifier: .overlay,
                code: ".overlay(RoundedRectangle(cornerRadius: 0).stroke(\(color), style: StrokeStyle(lineWidth: \(width), dash: [5, 3])))",
                tier: .direct,
                explanation: "border:dashed maps to stroke with dash pattern"
            )

        case .dotted:
            return StylingMappingResult(
                modifier: .overlay,
                code: ".overlay(RoundedRectangle(cornerRadius: 0).stroke(\(color), style: StrokeStyle(lineWidth: \(width), dash: [2, 2])))",
                tier: .direct,
                explanation: "border:dotted maps to stroke with small dash pattern"
            )

        case .double, .groove, .ridge, .inset, .outset:
            return StylingMappingResult(
                modifier: .overlay,
                code: "// border-style:\(border.style.rawValue) approximated as solid\n.overlay(RoundedRectangle(cornerRadius: 0).stroke(\(color), lineWidth: \(width)))",
                tier: .adapted,
                explanation: "border-style:\(border.style.rawValue) has no SwiftUI equivalent. Approximated as solid."
            )
        }
    }

    /// Maps CSS border-radius to SwiftUI .clipShape or .cornerRadius.
    public static func borderRadiusMapping(
        topLeft: CSSLength?,
        topRight: CSSLength?,
        bottomRight: CSSLength?,
        bottomLeft: CSSLength?
    ) -> StylingMappingResult {
        let tl = topLeft?.toPoints()
        let tr = topRight?.toPoints()
        let br = bottomRight?.toPoints()
        let bl = bottomLeft?.toPoints()

        // Check for uniform radius
        if let tl = tl, tl == tr && tr == br && br == bl {
            if tl >= 9999 {
                return StylingMappingResult(
                    modifier: .clipShape,
                    code: ".clipShape(Circle())",
                    tier: .direct,
                    explanation: "border-radius:50%/9999px maps to .clipShape(Circle())"
                )
            }
            return StylingMappingResult(
                modifier: .clipShape,
                code: ".clipShape(RoundedRectangle(cornerRadius: \(tl)))",
                tier: .direct,
                explanation: "Uniform border-radius maps to RoundedRectangle"
            )
        }

        // Non-uniform radius
        return StylingMappingResult(
            modifier: .clipShape,
            code: ".clipShape(UnevenRoundedRectangle(topLeadingRadius: \(tl ?? 0), bottomLeadingRadius: \(bl ?? 0), bottomTrailingRadius: \(br ?? 0), topTrailingRadius: \(tr ?? 0)))",
            tier: .direct,
            explanation: "Non-uniform border-radius maps to UnevenRoundedRectangle"
        )
    }

    // MARK: - Effects

    /// Maps CSS opacity to SwiftUI .opacity modifier.
    public static func opacityMapping(_ opacity: Double) -> StylingMappingResult {
        return StylingMappingResult(
            modifier: .opacity,
            code: ".opacity(\(opacity))",
            tier: .direct,
            explanation: "CSS opacity maps directly to .opacity()"
        )
    }

    /// Maps CSS box-shadow to SwiftUI .shadow modifier.
    public static func shadowMapping(_ shadow: CSSBoxShadow) -> StylingMappingResult {
        if shadow.inset {
            return StylingMappingResult(
                modifier: nil,
                code: "// UNSUPPORTED: inset box-shadow",
                tier: .unsupported,
                explanation: "CSS inset box-shadow has no SwiftUI equivalent. " +
                            "Consider using inner overlay with gradient."
            )
        }

        let color = colorToSwiftUI(shadow.color)
        let radius = shadow.blurRadius?.toPoints() ?? 0
        let x = shadow.offsetX.toPoints()
        let y = shadow.offsetY.toPoints()

        return StylingMappingResult(
            modifier: .shadow,
            code: ".shadow(color: \(color), radius: \(radius / 2), x: \(x), y: \(y))",
            tier: .direct,
            explanation: "box-shadow maps to .shadow(). Note: blur radius divided by 2 for similar visual."
        )
    }

    // MARK: - Transform

    /// Maps CSS transform to SwiftUI transform modifiers.
    public static func transformMapping(_ transforms: [CSSTransformFunction]) -> TransformMappingResult {
        var modifiers: [String] = []
        var tier: ConversionTier = .direct

        for transform in transforms {
            switch transform {
            case .translate(let x, let y):
                modifiers.append(".offset(x: \(x.toPoints()), y: \(y.toPoints()))")

            case .translateX(let x):
                modifiers.append(".offset(x: \(x.toPoints()))")

            case .translateY(let y):
                modifiers.append(".offset(y: \(y.toPoints()))")

            case .scale(let x, let y):
                if x == y {
                    modifiers.append(".scaleEffect(\(x))")
                } else {
                    modifiers.append(".scaleEffect(x: \(x), y: \(y))")
                }

            case .scaleX(let x):
                modifiers.append(".scaleEffect(x: \(x), y: 1)")

            case .scaleY(let y):
                modifiers.append(".scaleEffect(x: 1, y: \(y))")

            case .rotate(let degrees):
                modifiers.append(".rotationEffect(.degrees(\(degrees)))")

            case .skew(let x, let y):
                tier = .adapted
                modifiers.append("// ADAPTED: skew(\(x), \(y)) - no direct equivalent")
                modifiers.append(".transformEffect(CGAffineTransform(a: 1, b: tan(\(y) * .pi / 180), c: tan(\(x) * .pi / 180), d: 1, tx: 0, ty: 0))")

            case .skewX(let x):
                tier = .adapted
                modifiers.append(".transformEffect(CGAffineTransform(a: 1, b: 0, c: tan(\(x) * .pi / 180), d: 1, tx: 0, ty: 0))")

            case .skewY(let y):
                tier = .adapted
                modifiers.append(".transformEffect(CGAffineTransform(a: 1, b: tan(\(y) * .pi / 180), c: 0, d: 1, tx: 0, ty: 0))")

            case .matrix(let a, let b, let c, let d, let tx, let ty):
                tier = .adapted
                modifiers.append(".transformEffect(CGAffineTransform(a: \(a), b: \(b), c: \(c), d: \(d), tx: \(tx), ty: \(ty)))")
            }
        }

        return TransformMappingResult(
            modifiers: modifiers,
            tier: tier,
            explanation: tier == .direct
                ? "CSS transform maps to SwiftUI transform modifiers"
                : "Some CSS transforms require CGAffineTransform"
        )
    }

    // MARK: - Cursor / Interaction

    /// Maps CSS cursor to SwiftUI interaction patterns.
    public static func cursorMapping(_ cursor: String) -> StylingMappingResult {
        switch cursor.lowercased() {
        case "pointer":
            return StylingMappingResult(
                modifier: .onTapGesture,
                code: "// cursor:pointer indicates clickable - wrap in Button or add .onTapGesture",
                tier: .adapted,
                explanation: "cursor:pointer suggests making element tappable"
            )

        case "not-allowed", "disabled":
            return StylingMappingResult(
                modifier: .disabled,
                code: ".disabled(true)",
                tier: .direct,
                explanation: "cursor:not-allowed maps to .disabled(true)"
            )

        case "grab", "grabbing":
            return StylingMappingResult(
                modifier: .draggable,
                code: ".draggable(...)",
                tier: .adapted,
                explanation: "cursor:grab suggests draggable behavior"
            )

        case "text":
            return StylingMappingResult(
                modifier: .textSelection,
                code: ".textSelection(.enabled)",
                tier: .direct,
                explanation: "cursor:text maps to .textSelection(.enabled)"
            )

        default:
            return StylingMappingResult(
                modifier: nil,
                code: "// cursor:\(cursor) - no SwiftUI equivalent",
                tier: .unsupported,
                explanation: "CSS cursor:\(cursor) has no SwiftUI equivalent. " +
                            "iOS/iPadOS doesn't show traditional cursors."
            )
        }
    }

    // MARK: - Visibility

    /// Maps CSS visibility to SwiftUI.
    public static func visibilityMapping(_ visibility: String) -> StylingMappingResult {
        switch visibility.lowercased() {
        case "visible":
            return StylingMappingResult(
                modifier: nil,
                code: "",
                tier: .direct,
                explanation: "visibility:visible is the default"
            )

        case "hidden":
            return StylingMappingResult(
                modifier: .hidden,
                code: ".hidden()",
                tier: .direct,
                explanation: "visibility:hidden maps to .hidden() - preserves layout space"
            )

        case "collapse":
            return StylingMappingResult(
                modifier: nil,
                code: "// Conditional rendering: if !collapsed { View() }",
                tier: .adapted,
                explanation: "visibility:collapse removes layout space. " +
                            "Use conditional rendering in SwiftUI."
            )

        default:
            return StylingMappingResult(
                modifier: nil,
                code: "",
                tier: .direct,
                explanation: "Unknown visibility value"
            )
        }
    }

    // MARK: - Z-Index

    /// Maps CSS z-index to SwiftUI .zIndex modifier.
    public static func zIndexMapping(_ zIndex: Int) -> StylingMappingResult {
        return StylingMappingResult(
            modifier: .zIndex,
            code: ".zIndex(\(zIndex))",
            tier: .direct,
            explanation: "CSS z-index maps directly to .zIndex() within ZStack"
        )
    }

    // MARK: - Filters

    /// Maps CSS filter to SwiftUI modifiers.
    public static func filterMapping(_ filter: String) -> FilterMappingResult {
        var modifiers: [String] = []
        var tier: ConversionTier = .direct
        var unsupportedFilters: [String] = []

        // Parse filter functions
        let filterFunctions = parseFilterFunctions(filter)

        for (name, value) in filterFunctions {
            switch name {
            case "blur":
                if let radius = parseLength(value) {
                    modifiers.append(".blur(radius: \(radius))")
                }

            case "brightness":
                if let amount = parseNumber(value) {
                    modifiers.append(".brightness(\(amount - 1))")
                }

            case "contrast":
                if let amount = parseNumber(value) {
                    modifiers.append(".contrast(\(amount))")
                }

            case "grayscale":
                if let amount = parseNumber(value) {
                    modifiers.append(".grayscale(\(amount))")
                }

            case "saturate":
                if let amount = parseNumber(value) {
                    modifiers.append(".saturation(\(amount))")
                }

            case "hue-rotate":
                if let degrees = parseDegrees(value) {
                    modifiers.append(".hueRotation(.degrees(\(degrees)))")
                }

            case "invert":
                if let amount = parseNumber(value), amount > 0 {
                    modifiers.append(".colorInvert()")
                    if amount != 1 {
                        tier = .adapted
                    }
                }

            case "opacity":
                if let amount = parseNumber(value) {
                    modifiers.append(".opacity(\(amount))")
                }

            case "sepia":
                tier = .unsupported
                unsupportedFilters.append("sepia")

            case "drop-shadow":
                tier = .adapted
                modifiers.append("// Use .shadow() for drop-shadow")

            default:
                tier = .unsupported
                unsupportedFilters.append(name)
            }
        }

        return FilterMappingResult(
            modifiers: modifiers,
            unsupportedFilters: unsupportedFilters,
            tier: tier,
            explanation: unsupportedFilters.isEmpty
                ? "CSS filter maps to SwiftUI image modifiers"
                : "Some filters have no SwiftUI equivalent: \(unsupportedFilters.joined(separator: ", "))"
        )
    }

    // MARK: - Unsupported CSS Properties

    /// Returns mapping result for CSS properties with no SwiftUI equivalent.
    public static func unsupportedPropertyMapping(_ property: String) -> StylingMappingResult {
        let knownUnsupported: [String: String] = [
            "content": "CSS content property (::before/::after) has no SwiftUI equivalent. Use ZStack with overlay views.",
            "float": "CSS float is a legacy layout. SwiftUI uses HStack/VStack alignment instead.",
            "clear": "CSS clear works with float. Use proper Stack alignment in SwiftUI.",
            "clip-path": "CSS clip-path is partially supported. Use .clipShape() with Path for simple shapes.",
            "mask-image": "CSS mask-image maps to .mask() modifier with another view.",
            "mix-blend-mode": "CSS mix-blend-mode maps to .blendMode() modifier.",
            "backdrop-filter": "CSS backdrop-filter maps to .background(.ultraThinMaterial) or similar.",
            "writing-mode": "CSS writing-mode has no SwiftUI equivalent for vertical text.",
            "text-shadow": "CSS text-shadow has no direct equivalent. Use ZStack with offset Text.",
            "word-spacing": "CSS word-spacing has no SwiftUI equivalent.",
            "text-indent": "CSS text-indent has no SwiftUI equivalent. Add spaces or use padding.",
            "columns": "CSS multi-column layout has no SwiftUI equivalent. Use LazyVGrid.",
            "object-fit": "CSS object-fit maps to .aspectRatio with contentMode parameter.",
            "object-position": "CSS object-position maps to .frame(alignment:) on image container.",
            "resize": "CSS resize has no SwiftUI equivalent on iOS. Consider using draggable handles.",
            "scroll-snap": "CSS scroll-snap maps to .scrollTargetBehavior(.paging) or .viewAligned.",
            "scroll-behavior": "CSS scroll-behavior:smooth maps to withAnimation around scroll position changes.",
        ]

        if let explanation = knownUnsupported[property] {
            return StylingMappingResult(
                modifier: nil,
                code: "// UNSUPPORTED: \(property)",
                tier: .unsupported,
                explanation: explanation
            )
        }

        return StylingMappingResult(
            modifier: nil,
            code: "// UNSUPPORTED: \(property)",
            tier: .unsupported,
            explanation: "CSS property '\(property)' has no known SwiftUI equivalent."
        )
    }

    // MARK: - Helper Functions

    private static func colorToSwiftUI(_ color: CSSColor) -> String {
        if color.alpha < 1.0 {
            return "Color(red: \(color.red), green: \(color.green), blue: \(color.blue)).opacity(\(color.alpha))"
        }
        return "Color(red: \(color.red), green: \(color.green), blue: \(color.blue))"
    }

    private static func mapToSemanticFont(points: Double) -> String? {
        switch points {
        case 34...: return ".largeTitle"
        case 28..<34: return ".title"
        case 22..<28: return ".title2"
        case 20..<22: return ".title3"
        case 17..<20: return ".headline"
        case 15..<17: return ".body"
        case 13..<15: return ".callout"
        case 12..<13: return ".footnote"
        case 11..<12: return ".caption"
        case ..<11: return ".caption2"
        default: return nil
        }
    }

    private static func mapFontWeight(_ weight: CSSFontWeight) -> String {
        switch weight {
        case .normal, .w400: return ".regular"
        case .bold, .w700: return ".bold"
        case .bolder: return ".heavy"
        case .lighter: return ".light"
        case .w100: return ".ultraLight"
        case .w200: return ".thin"
        case .w300: return ".light"
        case .w500: return ".medium"
        case .w600: return ".semibold"
        case .w800: return ".heavy"
        case .w900: return ".black"
        }
    }

    private static func mapFontFamily(_ family: String) -> String? {
        let lowercased = family.lowercased()

        if lowercased.contains("mono") || lowercased.contains("courier") || lowercased.contains("consolas") {
            return ".monospaced"
        }
        if lowercased.contains("serif") && !lowercased.contains("sans") {
            return ".serif"
        }
        if lowercased.contains("rounded") {
            return ".rounded"
        }
        if lowercased.contains("system-ui") || lowercased.contains("sans-serif") {
            return ".default"
        }

        return nil
    }

    private static func parseFilterFunctions(_ filter: String) -> [(String, String)] {
        var results: [(String, String)] = []
        let pattern = #"(\w+(?:-\w+)?)\(([^)]+)\)"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return results }
        let range = NSRange(filter.startIndex..., in: filter)

        regex.enumerateMatches(in: filter, range: range) { match, _, _ in
            guard let match = match,
                  let nameRange = Range(match.range(at: 1), in: filter),
                  let valueRange = Range(match.range(at: 2), in: filter) else { return }

            let name = String(filter[nameRange])
            let value = String(filter[valueRange])
            results.append((name, value))
        }

        return results
    }

    private static func parseLength(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("px") {
            return Double(trimmed.dropLast(2))
        }
        return Double(trimmed)
    }

    private static func parseNumber(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("%") {
            if let percent = Double(trimmed.dropLast(1)) {
                return percent / 100
            }
        }
        return Double(trimmed)
    }

    private static func parseDegrees(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("deg") {
            return Double(trimmed.dropLast(3))
        }
        return Double(trimmed)
    }
}

// MARK: - Mapping Result Types

public struct StylingMappingResult: Sendable {
    public let modifier: SwiftUIModifier?
    public let code: String
    public let tier: ConversionTier
    public let explanation: String
}

public struct TypographyMappingResult: Sendable {
    public let modifiers: [String]
    public let tier: ConversionTier
    public let explanation: String
}

public struct TransformMappingResult: Sendable {
    public let modifiers: [String]
    public let tier: ConversionTier
    public let explanation: String
}

public struct FilterMappingResult: Sendable {
    public let modifiers: [String]
    public let unsupportedFilters: [String]
    public let tier: ConversionTier
    public let explanation: String
}
