import Foundation

// MARK: - Inheritance Resolver

/// Resolves property inheritance between components.
/// Components can inherit from parent components, with the ability to override specific properties.
/// Like CSS cascade, child overrides take precedence over parent values.
public final class InheritanceResolver: @unchecked Sendable {
    private let library: ComponentLibrary
    private var cache: [UUID: ResolvedComponent] = [:]
    private let lock = NSLock()

    public init(library: ComponentLibrary) {
        self.library = library
    }

    // MARK: - Resolution

    /// Resolves all properties for a component, including inherited values.
    public func resolve(componentID: UUID) -> ResolvedComponent? {
        lock.lock()
        defer { lock.unlock() }

        // Check cache first
        if let cached = cache[componentID] {
            return cached
        }

        guard let component = library.component(byID: componentID) else {
            return nil
        }

        let resolved = resolveComponent(component)
        cache[componentID] = resolved
        return resolved
    }

    /// Resolves a component with property overrides applied.
    public func resolve(componentID: UUID, withOverrides overrides: [String: PropertyValue]) -> ResolvedComponent? {
        guard var resolved = resolve(componentID: componentID) else {
            return nil
        }

        // Apply overrides
        for (key, value) in overrides {
            resolved.propertyValues[key] = value
        }

        return resolved
    }

    /// Resolves a component instance (component + preset + instance overrides).
    public func resolve(instance: ComponentInstance) -> ResolvedComponent? {
        guard var resolved = resolve(componentID: instance.componentID) else {
            return nil
        }

        // Apply preset overrides
        if let presetID = instance.presetID,
           let component = library.component(byID: instance.componentID),
           let preset = component.presets.first(where: { $0.id == presetID }) {
            for (key, value) in preset.propertyOverrides {
                resolved.propertyValues[key] = value
            }
        }

        // Apply instance overrides
        for (key, value) in instance.propertyOverrides {
            resolved.propertyValues[key] = value
        }

        return resolved
    }

    // MARK: - Private Resolution

    private func resolveComponent(_ component: CanvasComponent) -> ResolvedComponent {
        var propertyValues: [String: PropertyValue] = [:]
        var inheritedFrom: [String: UUID] = [:]
        var overrideStatus: [String: OverrideStatus] = [:]

        // Start with inherited properties from parent chain
        var ancestorChain: [CanvasComponent] = []
        var currentID = component.parentID

        while let parentID = currentID,
              let parent = library.component(byID: parentID) {
            ancestorChain.insert(parent, at: 0)
            currentID = parent.parentID
        }

        // Apply properties from ancestors (oldest to newest)
        for ancestor in ancestorChain {
            for property in ancestor.properties {
                propertyValues[property.key] = property.defaultValue
                inheritedFrom[property.key] = ancestor.id
                overrideStatus[property.key] = .inherited
            }
        }

        // Apply own properties (override any inherited)
        for property in component.properties {
            let wasInherited = propertyValues[property.key] != nil
            propertyValues[property.key] = property.defaultValue

            if wasInherited {
                if component.overriddenProperties.contains(property.key) {
                    overrideStatus[property.key] = .overridden
                } else {
                    overrideStatus[property.key] = .inherited
                    inheritedFrom[property.key] = component.parentID
                }
            } else {
                overrideStatus[property.key] = .own
            }
        }

        return ResolvedComponent(
            componentID: component.id,
            propertyValues: propertyValues,
            inheritedFrom: inheritedFrom,
            overrideStatus: overrideStatus,
            ancestorChain: ancestorChain.map(\.id)
        )
    }

    // MARK: - Cache Management

    /// Invalidates cache for a component and all its descendants.
    public func invalidate(componentID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        // Remove from cache
        cache.removeValue(forKey: componentID)

        // Find and invalidate descendants
        for component in library.components {
            if component.parentID == componentID {
                cache.removeValue(forKey: component.id)
            }
        }
    }

    /// Clears the entire cache.
    public func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    // MARK: - Inheritance Queries

    /// Returns the ancestor chain for a component (from root to immediate parent).
    public func ancestorChain(for componentID: UUID) -> [UUID] {
        var chain: [UUID] = []
        var currentID = componentID

        while let component = library.component(byID: currentID),
              let parentID = component.parentID {
            chain.insert(parentID, at: 0)
            currentID = parentID
        }

        return chain
    }

    /// Returns all descendants of a component.
    public func descendants(of componentID: UUID) -> [UUID] {
        var result: [UUID] = []

        for component in library.components {
            if component.parentID == componentID {
                result.append(component.id)
                result.append(contentsOf: descendants(of: component.id))
            }
        }

        return result
    }

    /// Checks if one component inherits from another.
    public func doesInherit(componentID: UUID, from ancestorID: UUID) -> Bool {
        var currentID = componentID

        while let component = library.component(byID: currentID),
              let parentID = component.parentID {
            if parentID == ancestorID {
                return true
            }
            currentID = parentID
        }

        return false
    }

    // MARK: - Override Analysis

    /// Analyzes which properties would change if a parent property is updated.
    public func analyzeImpact(
        changingProperty key: String,
        in componentID: UUID
    ) -> PropertyImpactAnalysis {
        var affectedComponents: [UUID] = []
        var blockedByOverrides: [UUID] = []

        let allDescendants = descendants(of: componentID)

        for descendantID in allDescendants {
            guard let component = library.component(byID: descendantID) else { continue }

            if component.overriddenProperties.contains(key) {
                blockedByOverrides.append(descendantID)
            } else {
                affectedComponents.append(descendantID)
            }
        }

        return PropertyImpactAnalysis(
            propertyKey: key,
            sourceComponentID: componentID,
            affectedComponents: affectedComponents,
            blockedByOverrides: blockedByOverrides
        )
    }

    /// Suggests which properties should be overridden to achieve a design goal.
    public func suggestOverrides(
        for componentID: UUID,
        targetValues: [String: PropertyValue]
    ) -> [OverrideSuggestion] {
        guard let resolved = resolve(componentID: componentID) else {
            return []
        }

        var suggestions: [OverrideSuggestion] = []

        for (key, targetValue) in targetValues {
            guard let currentValue = resolved.propertyValues[key],
                  currentValue != targetValue else {
                continue
            }

            let source = resolved.inheritedFrom[key]
            let status = resolved.overrideStatus[key] ?? .own

            suggestions.append(OverrideSuggestion(
                propertyKey: key,
                currentValue: currentValue,
                suggestedValue: targetValue,
                inheritedFrom: source,
                currentStatus: status,
                impact: analyzeImpact(changingProperty: key, in: componentID)
            ))
        }

        return suggestions
    }
}

// MARK: - Resolved Component

/// A component with all its properties fully resolved (including inheritance).
public struct ResolvedComponent: Sendable {
    public let componentID: UUID
    public var propertyValues: [String: PropertyValue]
    public let inheritedFrom: [String: UUID]      // Which ancestor each property came from
    public let overrideStatus: [String: OverrideStatus]
    public let ancestorChain: [UUID]              // From root to immediate parent

    public init(
        componentID: UUID,
        propertyValues: [String: PropertyValue],
        inheritedFrom: [String: UUID],
        overrideStatus: [String: OverrideStatus],
        ancestorChain: [UUID]
    ) {
        self.componentID = componentID
        self.propertyValues = propertyValues
        self.inheritedFrom = inheritedFrom
        self.overrideStatus = overrideStatus
        self.ancestorChain = ancestorChain
    }

    public func value(for key: String) -> PropertyValue? {
        propertyValues[key]
    }

    public func isInherited(_ key: String) -> Bool {
        overrideStatus[key] == .inherited
    }

    public func isOverridden(_ key: String) -> Bool {
        overrideStatus[key] == .overridden
    }
}

// MARK: - Override Status

public enum OverrideStatus: String, Codable, Sendable {
    case own        // Defined on this component, not inherited
    case inherited  // Inherited from parent, not overridden
    case overridden // Was inherited, now overridden
}

// MARK: - Impact Analysis

public struct PropertyImpactAnalysis: Sendable {
    public let propertyKey: String
    public let sourceComponentID: UUID
    public let affectedComponents: [UUID]     // Will inherit the change
    public let blockedByOverrides: [UUID]     // Have their own overrides

    public var totalAffected: Int {
        affectedComponents.count
    }

    public var totalBlocked: Int {
        blockedByOverrides.count
    }
}

// MARK: - Override Suggestion

public struct OverrideSuggestion: Sendable {
    public let propertyKey: String
    public let currentValue: PropertyValue
    public let suggestedValue: PropertyValue
    public let inheritedFrom: UUID?
    public let currentStatus: OverrideStatus
    public let impact: PropertyImpactAnalysis
}

// MARK: - Inheritance Conflict

/// Represents a conflict when multiple inheritance paths define the same property.
public struct InheritanceConflict: Sendable {
    public let propertyKey: String
    public let conflictingValues: [(componentID: UUID, value: PropertyValue)]
    public let resolvedValue: PropertyValue    // The winning value
    public let resolution: ConflictResolution
}

public enum ConflictResolution: Sendable {
    case lastWins       // Most recent ancestor wins
    case firstWins      // Oldest ancestor wins
    case explicit       // Explicitly overridden
}

// MARK: - Inheritance Validator

/// Validates inheritance relationships for cycles and other issues.
public struct InheritanceValidator {
    private let library: ComponentLibrary

    public init(library: ComponentLibrary) {
        self.library = library
    }

    /// Validates that there are no cycles in the inheritance graph.
    public func validateNoCycles() -> [InheritanceCycleError] {
        var errors: [InheritanceCycleError] = []

        for component in library.components {
            var visited: Set<UUID> = []
            var current = component.id

            while let comp = library.component(byID: current),
                  let parentID = comp.parentID {
                if visited.contains(parentID) {
                    errors.append(InheritanceCycleError(
                        componentID: component.id,
                        cycleParticipants: Array(visited) + [parentID]
                    ))
                    break
                }
                visited.insert(current)
                current = parentID
            }
        }

        return errors
    }

    /// Validates that all parent references are valid.
    public func validateParentReferences() -> [MissingParentError] {
        var errors: [MissingParentError] = []

        for component in library.components {
            if let parentID = component.parentID,
               library.component(byID: parentID) == nil {
                errors.append(MissingParentError(
                    componentID: component.id,
                    missingParentID: parentID
                ))
            }
        }

        return errors
    }
}

public struct InheritanceCycleError: Error, Sendable {
    public let componentID: UUID
    public let cycleParticipants: [UUID]
}

public struct MissingParentError: Error, Sendable {
    public let componentID: UUID
    public let missingParentID: UUID
}
