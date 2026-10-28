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

    /// The timers an auto-start chose that should still start once the pause after the check is over. A timer whose
    /// step lost a check during the pause, or is no longer in the recipe, is dropped.
    public static func timersStillToStart(
        _ timers: [CookModeSystemTimerViewModel],
        steps: [RecipeStep],
        stillChecked: Set<String>
    ) -> [CookModeSystemTimerViewModel] {
        timers.filter { timer in
            guard let step = steps.first(where: { $0.id == timer.stepID }) else {
                return false
            }
            return Set(step.ingredients.map(\.id)).isSubset(of: stillChecked)
        }
    }

    /// What the step's ring says when an auto-start fails: the same message as a failed tap on the ring, so the cook is
    /// never left with no timer and no reason.
    public static func startFailureMessage(for error: Error, timer: CookModeSystemTimerViewModel) -> String {
        CookModeSystemTimerScheduler.message(for: error, fallback: timer.systemUnavailableMessage)
    }
}
