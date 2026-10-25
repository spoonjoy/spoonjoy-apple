import Foundation

/// Decides when checking off ingredients starts a step's timer by itself.
public enum CookAutoTimerPolicy {
    /// True only on the check that completes the step's ingredients, for a step with a duration and at least one
    /// ingredient, when no timer for the step runs. Unchecking and rechecking never starts a second timer.
    public static func shouldAutoStart(
        step: RecipeStep,
        checkedIngredientIDs: Set<String>,
        previouslyChecked: Set<String>,
        runningStepIDs: Set<String>
    ) -> Bool {
        guard let duration = step.duration, duration > 0, !step.ingredients.isEmpty else {
            return false
        }
        guard !runningStepIDs.contains(step.id) else {
            return false
        }
        let needed = Set(step.ingredients.map(\.id))
        return needed.isSubset(of: checkedIngredientIDs) && !needed.isSubset(of: previouslyChecked)
    }
}
