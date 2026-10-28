import Testing
@testable import SpoonjoyCore

@Suite("Kitchen counter cook")
struct KitchenCounterCookTests {
    private func cook(_ recipeID: String, steps: Int, at updatedAt: String) -> CookModeProgress {
        CookModeProgress(recipeID: recipeID, stepIDs: (1...steps).map { "\(recipeID)-s\($0)" }, startedAt: "2026-10-25T08:00:00Z")
            .settingScaleFactor(1, updatedAt: updatedAt)
    }

    @Test("the hero resumes the active step of an unfinished cook")
    func resumesActiveStep() throws {
        let progress = try cook("pasta", steps: 4, at: "2026-10-25T09:00:00Z")
            .markingStepCompleted("pasta-s1", updatedAt: "2026-10-25T09:01:00Z")
            .selectingStep(id: "pasta-s2", updatedAt: "2026-10-25T09:02:00Z")
        let counter = KitchenCounterCook.resolve(recipeIDs: ["pasta"]) { $0 == "pasta" ? progress : nil }

        #expect(counter == KitchenCounterCook(recipeID: "pasta", stepNumber: 2, stepCount: 4))
        #expect(counter?.label == "On the counter · step 2 of 4")
        #expect(KitchenCounterCook.idleLabel == "On the counter")
    }

    @Test("the most recently touched unfinished cook wins, and a tie keeps the first recipe")
    func latestCookWins() {
        let byRecipe = [
            "soup": cook("soup", steps: 2, at: "2026-10-25T09:00:00Z"),
            "bread": cook("bread", steps: 3, at: "2026-10-25T10:00:00Z"),
            "salad": cook("salad", steps: 3, at: "2026-10-25T10:00:00Z")
        ]
        let counter = KitchenCounterCook.resolve(recipeIDs: ["soup", "bread", "salad"]) { byRecipe[$0] }

        #expect(counter == KitchenCounterCook(recipeID: "bread", stepNumber: 1, stepCount: 3))
    }

    @Test("finished cooks, cooks with no steps and recipes never cooked leave the counter empty")
    func nothingToResume() throws {
        let finished = try cook("pie", steps: 1, at: "2026-10-25T09:00:00Z")
            .markingStepCompleted("pie-s1", updatedAt: "2026-10-25T09:05:00Z")
        let empty = CookModeProgress(recipeID: "toast", stepIDs: [], startedAt: "2026-10-25T09:00:00Z")
        let byRecipe = ["pie": finished, "toast": empty]

        #expect(KitchenCounterCook.resolve(recipeIDs: ["pie", "toast", "never"]) { byRecipe[$0] } == nil)
        #expect(KitchenCounterCook.resolve(recipeIDs: []) { _ in nil } == nil)
    }
}
