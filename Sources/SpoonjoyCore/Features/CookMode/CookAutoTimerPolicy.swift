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

    /// Starts the timers an auto-start chose, once the pause after the check is over. A timer whose step lost a check
    /// during the pause, or is no longer in the recipe, is skipped. A start that fails is reported with the message
    /// the ring shows for the same failure, so the cook is never left with no timer and no reason.
    @MainActor
    public static func startTimers(
        _ timers: [CookModeSystemTimerViewModel],
        steps: [RecipeStep],
        stillChecked: Set<String>,
        start: @MainActor (CookModeSystemTimerViewModel) async throws -> CookStepTimerStartOutcome,
        failed: (_ stepID: String, _ message: String) -> Void
    ) async {
        for timer in timers {
            guard
                let step = steps.first(where: { $0.id == timer.stepID }),
                Set(step.ingredients.map(\.id)).isSubset(of: stillChecked)
            else {
                continue
            }
            do {
                _ = try await start(timer)
            } catch {
                failed(timer.stepID, CookModeSystemTimerScheduler.message(for: error, fallback: timer.systemUnavailableMessage))
            }
        }
    }
}
