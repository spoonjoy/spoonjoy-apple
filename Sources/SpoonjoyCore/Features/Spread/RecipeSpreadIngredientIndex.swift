import Foundation

/// The ingredients one step gathers, shown on the left page of a recipe spread under a cookbook-style subhead.
public struct RecipeSpreadIngredientGroup: Identifiable, Equatable, Sendable {
    /// The step's ID, so a selected step finds its group directly.
    public let id: String
    public let stepNumber: Int
    public let title: String?
    /// Outputs of earlier steps this step uses, such as "Step 1: Brown the sausage".
    public let dependencies: [RecipeDetailStepDependency]
    public let ingredients: [RecipeDetailIngredientRow]

    public var stepLabel: String {
        "Step \(stepNumber)"
    }

    public var accessibilityHeading: String {
        guard let title else {
            return stepLabel
        }
        return "\(stepLabel), \(title)"
    }
}

/// The left page of a recipe spread: every ingredient, grouped under the step that uses it.
///
/// A step that gathers nothing (no ingredients and no earlier-step outputs) gets no group, so the page reads
/// like a printed cookbook's ingredient list rather than a list of every step.
public struct RecipeSpreadIngredientIndex: Equatable, Sendable {
    public let groups: [RecipeSpreadIngredientGroup]

    public init(stepSections: [RecipeDetailStepSection]) {
        groups = stepSections.compactMap { section in
            guard !section.ingredients.isEmpty || !section.dependencies.isEmpty else {
                return nil
            }
            return RecipeSpreadIngredientGroup(
                id: section.id,
                stepNumber: section.stepNumber,
                title: section.title.flatMap { $0.isEmpty ? nil : $0 },
                dependencies: section.dependencies,
                ingredients: section.ingredients
            )
        }
    }

    public var isEmpty: Bool {
        groups.isEmpty
    }

    /// The number of ingredient rows, not counting earlier-step outputs.
    public var ingredientCount: Int {
        groups.reduce(0) { $0 + $1.ingredients.count }
    }

    public func group(forStepID stepID: String) -> RecipeSpreadIngredientGroup? {
        groups.first { $0.id == stepID }
    }
}

/// Which step the reader is on in a recipe spread. Tapping a step selects it and highlights its ingredients on
/// the facing page; tapping it again clears the highlight.
public struct RecipeSpreadSelection: Equatable, Sendable {
    public private(set) var selectedStepID: String?

    public init(selectedStepID: String? = nil) {
        self.selectedStepID = selectedStepID
    }

    public mutating func toggle(stepID: String) {
        selectedStepID = selectedStepID == stepID ? nil : stepID
    }

    public mutating func clear() {
        selectedStepID = nil
    }

    public func isSelected(stepID: String) -> Bool {
        selectedStepID == stepID
    }

    /// The ingredient group to highlight and scroll to, or nil when the selected step gathers nothing.
    public func highlightedGroupID(in index: RecipeSpreadIngredientIndex) -> String? {
        guard let selectedStepID else {
            return nil
        }
        return index.group(forStepID: selectedStepID)?.id
    }

    public func isHighlighted(groupID: String, in index: RecipeSpreadIngredientIndex) -> Bool {
        highlightedGroupID(in: index) == groupID
    }
}
