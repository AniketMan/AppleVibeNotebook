import Foundation

// MARK: - Conversion Report

/// A complete report of all translation decisions made during React → SwiftUI conversion.
/// This report provides full transparency about what was changed and why.
public struct ConversionReport: Codable, Sendable {
    public let sourceProject: String
    public let generatedAt: Date
    public let summary: ConversionSummary
    public var entries: [ConversionEntry]

    public init(
        sourceProject: String,
        generatedAt: Date = Date(),
        summary: ConversionSummary,
        entries: [ConversionEntry] = []
    ) {
        self.sourceProject = sourceProject
        self.generatedAt = generatedAt
        self.summary = summary
        self.entries = entries
    }

    /// Adds a new entry to the report.
    public mutating func addEntry(_ entry: ConversionEntry) {
        entries.append(entry)
    }

    /// Filters entries by tier.
    public func entries(for tier: ConversionTier) -> [ConversionEntry] {
        entries.filter { $0.tier == tier }
    }

    /// Exports the report as Markdown.
    public func toMarkdown() -> String {
        var md = """
        # React2SwiftUI Conversion Report

        **Source Project:** \(sourceProject)
        **Generated:** \(ISO8601DateFormatter().string(from: generatedAt))

        ## Summary

        | Metric | Value |
        |--------|-------|
        | Total Conversions | \(summary.totalConversions) |
        | Direct Matches (✅) | \(summary.directMatches) (\(summary.directMatchPercentage)%) |
        | Adapted Matches (⚠️) | \(summary.adaptedMatches) (\(summary.adaptedMatchPercentage)%) |
        | Unsupported (❌) | \(summary.unsupportedCount) (\(summary.unsupportedPercentage)%) |

        ### Health Assessment

        \(healthAssessment())

        ---

        ## Detailed Entries

        """

        // Group by tier
        let directEntries = entries(for: .direct)
        let adaptedEntries = entries(for: .adapted)
        let unsupportedEntries = entries(for: .unsupported)

        if !unsupportedEntries.isEmpty {
            md += "### ❌ Unsupported (Requires Manual Review)\n\n"
            for entry in unsupportedEntries {
                md += formatEntry(entry)
            }
            md += "\n"
        }

        if !adaptedEntries.isEmpty {
            md += "### ⚠️ Adapted (Functionally Equivalent)\n\n"
            for entry in adaptedEntries {
                md += formatEntry(entry)
            }
            md += "\n"
        }

        if !directEntries.isEmpty {
            md += "### ✅ Direct Matches (1:1 Mapping)\n\n"
            md += "<details>\n<summary>Show \(directEntries.count) direct matches</summary>\n\n"
            for entry in directEntries {
                md += formatEntry(entry)
            }
            md += "</details>\n"
        }

        return md
    }

    private func healthAssessment() -> String {
        let healthScore = summary.directMatchPercentage + (summary.adaptedMatchPercentage * 0.7)

        if healthScore >= 95 {
            return "🟢 **Excellent** - Project is ready to compile with minimal review."
        } else if healthScore >= 80 {
            return "🟡 **Good** - Minor manual adjustments may be needed."
        } else if healthScore >= 60 {
            return "🟠 **Fair** - Significant manual work required for \(summary.unsupportedCount) unsupported patterns."
        } else {
            return "🔴 **Needs Work** - This project uses many patterns without SwiftUI equivalents. Review flagged items carefully."
        }
    }

    private func formatEntry(_ entry: ConversionEntry) -> String {
        let tierIcon = switch entry.tier {
        case .direct: "✅"
        case .adapted: "⚠️"
        case .unsupported: "❌"
        }

        return """
        #### \(tierIcon) \(entry.sourceFile):\(entry.sourceLine)

        **Original:**
        ```\(entry.sourceLanguage)
        \(entry.originalCode)
        ```

        **Generated:**
        ```swift
        \(entry.generatedCode)
        ```

        **Explanation:** \(entry.explanation)

        ---

        """
    }
}

// MARK: - Conversion Summary

/// Summary statistics for a conversion report.
public struct ConversionSummary: Codable, Sendable {
    public let totalConversions: Int
    public let directMatches: Int
    public let adaptedMatches: Int
    public let unsupportedCount: Int

    public var directMatchPercentage: Double {
        guard totalConversions > 0 else { return 0 }
        return Double(directMatches) / Double(totalConversions) * 100
    }

    public var adaptedMatchPercentage: Double {
        guard totalConversions > 0 else { return 0 }
        return Double(adaptedMatches) / Double(totalConversions) * 100
    }

    public var unsupportedPercentage: Double {
        guard totalConversions > 0 else { return 0 }
        return Double(unsupportedCount) / Double(totalConversions) * 100
    }

    public init(
        totalConversions: Int,
        directMatches: Int,
        adaptedMatches: Int,
        unsupportedCount: Int
    ) {
        self.totalConversions = totalConversions
        self.directMatches = directMatches
        self.adaptedMatches = adaptedMatches
        self.unsupportedCount = unsupportedCount
    }

    /// Creates a summary from a list of entries.
    public static func from(entries: [ConversionEntry]) -> ConversionSummary {
        let direct = entries.filter { $0.tier == .direct }.count
        let adapted = entries.filter { $0.tier == .adapted }.count
        let unsupported = entries.filter { $0.tier == .unsupported }.count

        return ConversionSummary(
            totalConversions: entries.count,
            directMatches: direct,
            adaptedMatches: adapted,
            unsupportedCount: unsupported
        )
    }
}

// MARK: - Conversion Entry

/// A single translation decision in the conversion report.
public struct ConversionEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let sourceFile: String
    public let sourceLine: Int
    public let sourceColumn: Int
    public let sourceLanguage: String
    public let originalCode: String
    public let generatedCode: String
    public let tier: ConversionTier
    public let explanation: String
    public let category: ConversionCategory
    public let suggestedFix: String?

    public init(
        id: UUID = UUID(),
        sourceFile: String,
        sourceLine: Int,
        sourceColumn: Int = 0,
        sourceLanguage: String = "jsx",
        originalCode: String,
        generatedCode: String,
        tier: ConversionTier,
        explanation: String,
        category: ConversionCategory,
        suggestedFix: String? = nil
    ) {
        self.id = id
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
        self.sourceColumn = sourceColumn
        self.sourceLanguage = sourceLanguage
        self.originalCode = originalCode
        self.generatedCode = generatedCode
        self.tier = tier
        self.explanation = explanation
        self.category = category
        self.suggestedFix = suggestedFix
    }
}

// MARK: - Conversion Category

/// Categories of conversion for filtering and organization.
public enum ConversionCategory: String, Codable, Sendable, CaseIterable {
    case layout = "Layout"
    case component = "Component"
    case styling = "Styling"
    case state = "State Management"
    case lifecycle = "Lifecycle"
    case animation = "Animation"
    case event = "Event Handling"
    case navigation = "Navigation"
    case accessibility = "Accessibility"
    case other = "Other"
}

// MARK: - Report Builder

/// Builder for constructing conversion reports incrementally.
public final class ConversionReportBuilder: @unchecked Sendable {
    private var entries: [ConversionEntry] = []
    private let sourceProject: String
    private let lock = NSLock()

    public init(sourceProject: String) {
        self.sourceProject = sourceProject
    }

    /// Records a layout conversion.
    public func recordLayout(
        sourceFile: String,
        sourceLine: Int,
        original: String,
        generated: String,
        result: LayoutMappingResult
    ) {
        addEntry(ConversionEntry(
            sourceFile: sourceFile,
            sourceLine: sourceLine,
            originalCode: original,
            generatedCode: generated,
            tier: result.tier,
            explanation: result.explanation,
            category: .layout
        ))
    }

    /// Records a component conversion.
    public func recordComponent(
        sourceFile: String,
        sourceLine: Int,
        original: String,
        generated: String,
        result: ComponentMappingResult
    ) {
        addEntry(ConversionEntry(
            sourceFile: sourceFile,
            sourceLine: sourceLine,
            originalCode: original,
            generatedCode: generated,
            tier: result.tier,
            explanation: result.explanation,
            category: .component
        ))
    }

    /// Records a styling conversion.
    public func recordStyling(
        sourceFile: String,
        sourceLine: Int,
        original: String,
        generated: String,
        result: StylingMappingResult
    ) {
        addEntry(ConversionEntry(
            sourceFile: sourceFile,
            sourceLine: sourceLine,
            sourceLanguage: "css",
            originalCode: original,
            generatedCode: generated,
            tier: result.tier,
            explanation: result.explanation,
            category: .styling
        ))
    }

    /// Records a state/hook conversion.
    public func recordState(
        sourceFile: String,
        sourceLine: Int,
        original: String,
        generated: String,
        result: HookMappingResult
    ) {
        addEntry(ConversionEntry(
            sourceFile: sourceFile,
            sourceLine: sourceLine,
            originalCode: original,
            generatedCode: generated,
            tier: result.tier,
            explanation: result.explanation,
            category: .state
        ))
    }

    /// Records an animation conversion.
    public func recordAnimation(
        sourceFile: String,
        sourceLine: Int,
        original: String,
        generated: String,
        tier: ConversionTier,
        explanation: String
    ) {
        addEntry(ConversionEntry(
            sourceFile: sourceFile,
            sourceLine: sourceLine,
            originalCode: original,
            generatedCode: generated,
            tier: tier,
            explanation: explanation,
            category: .animation
        ))
    }

    /// Records an event handler conversion.
    public func recordEvent(
        sourceFile: String,
        sourceLine: Int,
        original: String,
        generated: String,
        result: EventMappingResult
    ) {
        addEntry(ConversionEntry(
            sourceFile: sourceFile,
            sourceLine: sourceLine,
            originalCode: original,
            generatedCode: generated,
            tier: result.tier,
            explanation: result.explanation,
            category: .event
        ))
    }

    /// Records an unsupported pattern.
    public func recordUnsupported(
        sourceFile: String,
        sourceLine: Int,
        original: String,
        category: ConversionCategory,
        explanation: String,
        suggestedFix: String? = nil
    ) {
        addEntry(ConversionEntry(
            sourceFile: sourceFile,
            sourceLine: sourceLine,
            originalCode: original,
            generatedCode: "// UNSUPPORTED: See explanation",
            tier: .unsupported,
            explanation: explanation,
            category: category,
            suggestedFix: suggestedFix
        ))
    }

    /// Builds the final report.
    public func build() -> ConversionReport {
        lock.lock()
        defer { lock.unlock() }

        let summary = ConversionSummary.from(entries: entries)
        return ConversionReport(
            sourceProject: sourceProject,
            generatedAt: Date(),
            summary: summary,
            entries: entries
        )
    }

    private func addEntry(_ entry: ConversionEntry) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
    }
}

// MARK: - User Correction Dictionary

/// Stores user corrections for learning and persistence.
public struct UserCorrectionDictionary: Codable, Sendable {
    public var corrections: [UserCorrection]
    public let lastUpdated: Date

    public init(corrections: [UserCorrection] = [], lastUpdated: Date = Date()) {
        self.corrections = corrections
        self.lastUpdated = lastUpdated
    }

    /// Finds a user correction matching the given input pattern.
    public func findCorrection(for inputPattern: InputPattern) -> UserCorrection? {
        corrections.first { $0.inputPattern == inputPattern }
    }

    /// Adds or updates a user correction.
    public mutating func addCorrection(_ correction: UserCorrection) {
        if let index = corrections.firstIndex(where: { $0.inputPattern == correction.inputPattern }) {
            corrections[index] = correction
        } else {
            corrections.append(correction)
        }
    }
}

/// A single user correction that overrides the default mapping.
public struct UserCorrection: Codable, Sendable, Identifiable {
    public let id: UUID
    public let inputPattern: InputPattern
    public let userOutput: String
    public let createdAt: Date
    public let appliedCount: Int

    public init(
        id: UUID = UUID(),
        inputPattern: InputPattern,
        userOutput: String,
        createdAt: Date = Date(),
        appliedCount: Int = 1
    ) {
        self.id = id
        self.inputPattern = inputPattern
        self.userOutput = userOutput
        self.createdAt = createdAt
        self.appliedCount = appliedCount
    }
}

/// Represents the input pattern that was corrected.
public struct InputPattern: Codable, Sendable, Equatable {
    public let category: ConversionCategory
    public let originalCode: String
    public let normalizedCode: String

    public init(category: ConversionCategory, originalCode: String) {
        self.category = category
        self.originalCode = originalCode
        self.normalizedCode = Self.normalize(originalCode)
    }

    private static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}
