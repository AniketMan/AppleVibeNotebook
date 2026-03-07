import Foundation

// MARK: - Layout Mapping Dictionary

/// Deterministic mappings from CSS Flexbox/Grid layouts to SwiftUI containers.
/// These mappings are derived from official W3C CSS specifications and Apple SwiftUI documentation.
/// Reference: W3C CSS Flexible Box Layout Module Level 1, Apple SwiftUI Documentation
public enum LayoutMapping {

    // MARK: - Flex Direction → Stack Type

    /// Maps CSS flex-direction to SwiftUI stack type.
    /// Source: W3C CSS Flexbox spec §5.1 "Flex Flow Direction"
    public static func stackType(
        for flexDirection: CSSFlexDirection?,
        flexWrap: CSSFlexWrap?
    ) -> LayoutMappingResult {
        let direction = flexDirection ?? .row
        let wrap = flexWrap ?? .nowrap

        switch (direction, wrap) {
        case (.row, .nowrap), (.rowReverse, .nowrap):
            return LayoutMappingResult(
                viewType: .hStack,
                tier: .direct,
                explanation: "display:flex with flex-direction:row maps directly to HStack"
            )

        case (.column, .nowrap), (.columnReverse, .nowrap):
            return LayoutMappingResult(
                viewType: .vStack,
                tier: .direct,
                explanation: "display:flex with flex-direction:column maps directly to VStack"
            )

        case (.row, .wrap), (.row, .wrapReverse),
             (.rowReverse, .wrap), (.rowReverse, .wrapReverse):
            return LayoutMappingResult(
                viewType: .lazyVGrid,
                tier: .adapted,
                explanation: "flex-wrap:wrap with row direction requires LazyVGrid with adaptive columns. " +
                            "SwiftUI has no direct flex-wrap equivalent; using adaptive grid layout."
            )

        case (.column, .wrap), (.column, .wrapReverse),
             (.columnReverse, .wrap), (.columnReverse, .wrapReverse):
            return LayoutMappingResult(
                viewType: .lazyHGrid,
                tier: .adapted,
                explanation: "flex-wrap:wrap with column direction requires LazyHGrid with adaptive rows. " +
                            "SwiftUI has no direct flex-wrap equivalent; using adaptive grid layout."
            )
        }
    }

    // MARK: - Alignment Mapping

    /// Maps CSS justify-content to SwiftUI alignment and spacing.
    /// Source: W3C CSS Flexbox spec §8.2 "Axis Alignment"
    public static func justifyContentMapping(
        _ justifyContent: CSSJustifyContent?,
        isHorizontal: Bool
    ) -> JustifyContentMappingResult {
        let justify = justifyContent ?? .flexStart

        switch justify {
        case .flexStart, .start:
            return JustifyContentMappingResult(
                alignment: isHorizontal ? .leading : .top,
                requiresSpacer: false,
                spacerPosition: nil,
                tier: .direct,
                explanation: "justify-content:flex-start maps to leading/top alignment"
            )

        case .flexEnd, .end:
            return JustifyContentMappingResult(
                alignment: isHorizontal ? .trailing : .bottom,
                requiresSpacer: true,
                spacerPosition: .before,
                tier: .direct,
                explanation: "justify-content:flex-end maps to Spacer() before content"
            )

        case .center:
            return JustifyContentMappingResult(
                alignment: .center,
                requiresSpacer: true,
                spacerPosition: .both,
                tier: .direct,
                explanation: "justify-content:center maps to Spacer() on both sides"
            )

        case .spaceBetween:
            return JustifyContentMappingResult(
                alignment: nil,
                requiresSpacer: true,
                spacerPosition: .between,
                tier: .adapted,
                explanation: "justify-content:space-between requires Spacer() between each child. " +
                            "This changes the content structure."
            )

        case .spaceAround:
            return JustifyContentMappingResult(
                alignment: nil,
                requiresSpacer: true,
                spacerPosition: .around,
                tier: .adapted,
                explanation: "justify-content:space-around requires calculated padding on each child. " +
                            "No direct SwiftUI equivalent."
            )

        case .spaceEvenly:
            return JustifyContentMappingResult(
                alignment: nil,
                requiresSpacer: true,
                spacerPosition: .evenly,
                tier: .adapted,
                explanation: "justify-content:space-evenly requires equal Spacer() distribution. " +
                            "No direct SwiftUI equivalent."
            )
        }
    }

    /// Maps CSS align-items to SwiftUI stack alignment.
    /// Source: W3C CSS Flexbox spec §8.3 "Cross-axis Alignment"
    public static func alignItemsMapping(
        _ alignItems: CSSAlignItems?,
        isHorizontal: Bool
    ) -> AlignItemsMappingResult {
        let align = alignItems ?? .stretch

        switch align {
        case .flexStart, .start:
            return AlignItemsMappingResult(
                alignment: isHorizontal ? .top : .leading,
                tier: .direct,
                explanation: "align-items:flex-start maps to top/leading alignment"
            )

        case .flexEnd, .end:
            return AlignItemsMappingResult(
                alignment: isHorizontal ? .bottom : .trailing,
                tier: .direct,
                explanation: "align-items:flex-end maps to bottom/trailing alignment"
            )

        case .center:
            return AlignItemsMappingResult(
                alignment: .center,
                tier: .direct,
                explanation: "align-items:center maps directly to center alignment"
            )

        case .baseline:
            return AlignItemsMappingResult(
                alignment: isHorizontal ? .firstTextBaseline : .leading,
                tier: .adapted,
                explanation: "align-items:baseline maps to .firstTextBaseline on HStack. " +
                            "VStack baseline alignment requires manual adjustment."
            )

        case .stretch:
            return AlignItemsMappingResult(
                alignment: nil,
                requiresFrameModifier: true,
                tier: .adapted,
                explanation: "align-items:stretch requires .frame(maxWidth/Height: .infinity) on children. " +
                            "SwiftUI stacks don't stretch by default."
            )
        }
    }

    // MARK: - Gap Mapping

    /// Maps CSS gap to SwiftUI spacing parameter.
    /// Source: W3C CSS Box Alignment Module Level 3 §8 "Gaps Between Boxes"
    public static func gapMapping(_ gap: CSSLength?) -> GapMappingResult {
        guard let gap = gap else {
            return GapMappingResult(
                spacing: nil,
                tier: .direct,
                explanation: "No gap specified; using default SwiftUI stack spacing"
            )
        }

        let points = gap.toPoints()

        return GapMappingResult(
            spacing: points,
            tier: .direct,
            explanation: "gap:\(gap.value)\(gap.unit.rawValue) maps directly to spacing:\(points)"
        )
    }

    // MARK: - Position Mapping

    /// Maps CSS position to SwiftUI layout strategy.
    /// Source: W3C CSS Positioned Layout Module Level 3
    public static func positionMapping(
        _ position: CSSPosition?,
        top: CSSLength?,
        right: CSSLength?,
        bottom: CSSLength?,
        left: CSSLength?
    ) -> PositionMappingResult {
        let pos = position ?? .static

        switch pos {
        case .static:
            return PositionMappingResult(
                requiresZStack: false,
                offset: nil,
                tier: .direct,
                explanation: "position:static is default flow layout; no special handling needed"
            )

        case .relative:
            let offsetX = (left?.toPoints() ?? 0) - (right?.toPoints() ?? 0)
            let offsetY = (top?.toPoints() ?? 0) - (bottom?.toPoints() ?? 0)

            if offsetX == 0 && offsetY == 0 {
                return PositionMappingResult(
                    requiresZStack: false,
                    offset: nil,
                    tier: .direct,
                    explanation: "position:relative with no offset has no visual effect"
                )
            }

            return PositionMappingResult(
                requiresZStack: false,
                offset: (x: offsetX, y: offsetY),
                tier: .direct,
                explanation: "position:relative maps to .offset(x:\(offsetX), y:\(offsetY))"
            )

        case .absolute:
            let offsetX = left?.toPoints() ?? (right != nil ? -(right!.toPoints()) : 0)
            let offsetY = top?.toPoints() ?? (bottom != nil ? -(bottom!.toPoints()) : 0)

            return PositionMappingResult(
                requiresZStack: true,
                offset: (x: offsetX, y: offsetY),
                alignment: alignmentFromPositionValues(top: top, right: right, bottom: bottom, left: left),
                tier: .adapted,
                explanation: "position:absolute requires wrapping in ZStack. Child positioned with " +
                            ".offset(x:\(offsetX), y:\(offsetY)) or alignment."
            )

        case .fixed:
            return PositionMappingResult(
                requiresZStack: true,
                offset: nil,
                tier: .unsupported,
                explanation: "position:fixed has no SwiftUI equivalent. Consider using .overlay on " +
                            "the root view or a custom solution."
            )

        case .sticky:
            return PositionMappingResult(
                requiresZStack: false,
                offset: nil,
                tier: .unsupported,
                explanation: "position:sticky has no direct SwiftUI equivalent. Consider using " +
                            ".safeAreaInset or LazyVStack with pinnedViews for headers."
            )
        }
    }

    // MARK: - Overflow Mapping

    /// Maps CSS overflow to SwiftUI ScrollView.
    /// Source: W3C CSS Overflow Module Level 3
    public static func overflowMapping(
        overflowX: CSSOverflow?,
        overflowY: CSSOverflow?
    ) -> OverflowMappingResult {
        let x = overflowX ?? .visible
        let y = overflowY ?? .visible

        switch (x, y) {
        case (.visible, .visible):
            return OverflowMappingResult(
                wrapInScrollView: false,
                scrollAxes: [],
                clipsContent: false,
                tier: .direct,
                explanation: "overflow:visible is default; no ScrollView needed"
            )

        case (.scroll, .visible), (.auto, .visible):
            return OverflowMappingResult(
                wrapInScrollView: true,
                scrollAxes: [.horizontal],
                clipsContent: false,
                tier: .direct,
                explanation: "overflow-x:scroll maps to ScrollView(.horizontal)"
            )

        case (.visible, .scroll), (.visible, .auto):
            return OverflowMappingResult(
                wrapInScrollView: true,
                scrollAxes: [.vertical],
                clipsContent: false,
                tier: .direct,
                explanation: "overflow-y:scroll maps to ScrollView(.vertical)"
            )

        case (.scroll, .scroll), (.auto, .auto), (.scroll, .auto), (.auto, .scroll):
            return OverflowMappingResult(
                wrapInScrollView: true,
                scrollAxes: [.horizontal, .vertical],
                clipsContent: false,
                tier: .direct,
                explanation: "overflow:scroll on both axes maps to ScrollView([.horizontal, .vertical])"
            )

        case (.hidden, _), (_, .hidden):
            return OverflowMappingResult(
                wrapInScrollView: false,
                scrollAxes: [],
                clipsContent: true,
                tier: .direct,
                explanation: "overflow:hidden maps to .clipped() modifier"
            )

        case (.clip, _), (_, .clip):
            return OverflowMappingResult(
                wrapInScrollView: false,
                scrollAxes: [],
                clipsContent: true,
                tier: .direct,
                explanation: "overflow:clip maps to .clipped() modifier"
            )
        }
    }

    // MARK: - CSS Grid Mapping

    /// Maps CSS Grid to SwiftUI Grid/LazyVGrid.
    /// Source: W3C CSS Grid Layout Module Level 2
    public static func gridMapping(_ gridTemplate: CSSGridTemplate?) -> GridMappingResult {
        guard let template = gridTemplate else {
            return GridMappingResult(
                viewType: .lazyVGrid,
                columns: [],
                tier: .adapted,
                explanation: "No grid-template-columns specified; defaulting to single column LazyVGrid"
            )
        }

        var columns: [GridColumnDefinition] = []
        var hasComplexTrack = false

        for track in template.columns {
            switch track {
            case .fr(let fraction):
                columns.append(.flexible(minimum: 0, weight: fraction))

            case .length(let length):
                columns.append(.fixed(length.toPoints()))

            case .auto:
                columns.append(.adaptive(minimum: 80))

            case .minContent, .maxContent:
                columns.append(.flexible(minimum: 0, weight: 1))
                hasComplexTrack = true

            case .repeatTrack(let count, let tracks):
                switch count {
                case .count(let n):
                    for _ in 0..<n {
                        for innerTrack in tracks {
                            if case .fr(let f) = innerTrack {
                                columns.append(.flexible(minimum: 0, weight: f))
                            } else if case .length(let l) = innerTrack {
                                columns.append(.fixed(l.toPoints()))
                            }
                        }
                    }
                case .autoFill, .autoFit:
                    if let firstTrack = tracks.first, case .length(let l) = firstTrack {
                        columns.append(.adaptive(minimum: l.toPoints()))
                    } else {
                        columns.append(.adaptive(minimum: 80))
                    }
                }

            case .minmax, .fitContent:
                hasComplexTrack = true
                columns.append(.flexible(minimum: 0, weight: 1))
            }
        }

        let tier: ConversionTier = hasComplexTrack ? .adapted : .direct
        let explanation = hasComplexTrack
            ? "CSS Grid with minmax/min-content/max-content approximated with flexible columns. " +
              "SwiftUI Grid has different sizing behavior."
            : "CSS Grid columns map to LazyVGrid with GridItem columns"

        return GridMappingResult(
            viewType: .lazyVGrid,
            columns: columns,
            spacing: template.columnGap?.toPoints(),
            tier: tier,
            explanation: explanation
        )
    }

    // MARK: - Helper Functions

    private static func alignmentFromPositionValues(
        top: CSSLength?,
        right: CSSLength?,
        bottom: CSSLength?,
        left: CSSLength?
    ) -> SwiftUIAlignment {
        let hasTop = top != nil
        let hasBottom = bottom != nil
        let hasLeft = left != nil
        let hasRight = right != nil

        switch (hasTop, hasBottom, hasLeft, hasRight) {
        case (true, false, true, false): return .topLeading
        case (true, false, false, true): return .topTrailing
        case (true, false, _, _): return .top
        case (false, true, true, false): return .bottomLeading
        case (false, true, false, true): return .bottomTrailing
        case (false, true, _, _): return .bottom
        case (_, _, true, false): return .leading
        case (_, _, false, true): return .trailing
        default: return .center
        }
    }
}

// MARK: - Mapping Result Types

public struct LayoutMappingResult: Sendable {
    public let viewType: SwiftUIViewType
    public let tier: ConversionTier
    public let explanation: String
}

public struct JustifyContentMappingResult: Sendable {
    public let alignment: SwiftUIAlignment?
    public let requiresSpacer: Bool
    public let spacerPosition: SpacerPosition?
    public let tier: ConversionTier
    public let explanation: String

    public init(
        alignment: SwiftUIAlignment?,
        requiresSpacer: Bool = false,
        spacerPosition: SpacerPosition? = nil,
        tier: ConversionTier,
        explanation: String
    ) {
        self.alignment = alignment
        self.requiresSpacer = requiresSpacer
        self.spacerPosition = spacerPosition
        self.tier = tier
        self.explanation = explanation
    }
}

public enum SpacerPosition: Sendable {
    case before
    case after
    case both
    case between
    case around
    case evenly
}

public struct AlignItemsMappingResult: Sendable {
    public let alignment: SwiftUIAlignment?
    public let requiresFrameModifier: Bool
    public let tier: ConversionTier
    public let explanation: String

    public init(
        alignment: SwiftUIAlignment?,
        requiresFrameModifier: Bool = false,
        tier: ConversionTier,
        explanation: String
    ) {
        self.alignment = alignment
        self.requiresFrameModifier = requiresFrameModifier
        self.tier = tier
        self.explanation = explanation
    }
}

public struct GapMappingResult: Sendable {
    public let spacing: Double?
    public let tier: ConversionTier
    public let explanation: String
}

public struct PositionMappingResult: Sendable {
    public let requiresZStack: Bool
    public let offset: (x: Double, y: Double)?
    public let alignment: SwiftUIAlignment?
    public let tier: ConversionTier
    public let explanation: String

    public init(
        requiresZStack: Bool,
        offset: (x: Double, y: Double)?,
        alignment: SwiftUIAlignment? = nil,
        tier: ConversionTier,
        explanation: String
    ) {
        self.requiresZStack = requiresZStack
        self.offset = offset
        self.alignment = alignment
        self.tier = tier
        self.explanation = explanation
    }
}

public struct OverflowMappingResult: Sendable {
    public let wrapInScrollView: Bool
    public let scrollAxes: Set<ScrollAxis>
    public let clipsContent: Bool
    public let tier: ConversionTier
    public let explanation: String
}

public enum ScrollAxis: Sendable {
    case horizontal
    case vertical
}

public struct GridMappingResult: Sendable {
    public let viewType: SwiftUIViewType
    public let columns: [GridColumnDefinition]
    public let spacing: Double?
    public let tier: ConversionTier
    public let explanation: String

    public init(
        viewType: SwiftUIViewType,
        columns: [GridColumnDefinition],
        spacing: Double? = nil,
        tier: ConversionTier,
        explanation: String
    ) {
        self.viewType = viewType
        self.columns = columns
        self.spacing = spacing
        self.tier = tier
        self.explanation = explanation
    }
}

public enum GridColumnDefinition: Sendable {
    case fixed(Double)
    case flexible(minimum: Double, weight: Double)
    case adaptive(minimum: Double)
}

// MARK: - SwiftUI Alignment

public enum SwiftUIAlignment: String, Sendable {
    case center
    case leading
    case trailing
    case top
    case bottom
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case firstTextBaseline
    case lastTextBaseline
}

// MARK: - Conversion Tier

/// Represents the quality/confidence of a conversion mapping.
public enum ConversionTier: String, Codable, Sendable {
    /// 1:1 deterministic mapping exists. Lossless conversion.
    case direct

    /// No direct equivalent, but a functionally similar SwiftUI pattern was applied.
    case adapted

    /// Cannot be represented in SwiftUI. Original code preserved as comment.
    case unsupported
}
