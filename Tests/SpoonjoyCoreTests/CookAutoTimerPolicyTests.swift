import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook auto-start timer policy")
struct CookAutoTimerPolicyTests {
    static func step(id: String = "s1", duration: Int?, ingredientIDs: [String]) -> RecipeStep {
        RecipeStep(
            id: id,
            stepNum: 1,
            stepTitle: nil,
            description: "Simmer.",
            duration: duration,
            ingredients: ingredientIDs.map { RecipeIngredient(id: $0, name: $0, quantity: 1, unit: nil) }
        )
    }

    @Test func startsWhenLastIngredientChecked() {
        let step = Self.step(duration: 3, ingredientIDs: ["a", "b"])
        #expect(CookAutoTimerPolicy.shouldAutoStart(step: step, checkedIngredientIDs: ["a", "b"], previouslyChecked: ["a"], runningStepIDs: []))
    }

    @Test func doesNotRestartOnUncheckRecheck() {
        let step = Self.step(duration: 3, ingredientIDs: ["a", "b"])
        #expect(!CookAutoTimerPolicy.shouldAutoStart(step: step, checkedIngredientIDs: ["a", "b"], previouslyChecked: ["a"], runningStepIDs: ["s1"]))
    }

    @Test func neverStartsWithoutDuration() {
        let none = Self.step(duration: nil, ingredientIDs: ["a"])
        let zero = Self.step(duration: 0, ingredientIDs: ["a"])
        #expect(!CookAutoTimerPolicy.shouldAutoStart(step: none, checkedIngredientIDs: ["a"], previouslyChecked: [], runningStepIDs: []))
        #expect(!CookAutoTimerPolicy.shouldAutoStart(step: zero, checkedIngredientIDs: ["a"], previouslyChecked: [], runningStepIDs: []))
    }

    @Test func neverStartsWithoutIngredients() {
        let step = Self.step(duration: 3, ingredientIDs: [])
        #expect(!CookAutoTimerPolicy.shouldAutoStart(step: step, checkedIngredientIDs: [], previouslyChecked: [], runningStepIDs: []))
    }

    @Test func doesNotStartWhenAlreadyAllChecked() {
        let step = Self.step(duration: 3, ingredientIDs: ["a", "b"])
        #expect(!CookAutoTimerPolicy.shouldAutoStart(step: step, checkedIngredientIDs: ["a", "b"], previouslyChecked: ["a", "b"], runningStepIDs: []))
    }

    @Test func doesNotStartWhileIngredientsRemain() {
        let step = Self.step(duration: 3, ingredientIDs: ["a", "b"])
        #expect(!CookAutoTimerPolicy.shouldAutoStart(step: step, checkedIngredientIDs: ["a"], previouslyChecked: [], runningStepIDs: []))
    }

    @Test func ignoresCheckedIdsFromOtherSteps() {
        let step = Self.step(duration: 3, ingredientIDs: ["a"])
        #expect(CookAutoTimerPolicy.shouldAutoStart(step: step, checkedIngredientIDs: ["a", "z"], previouslyChecked: ["z"], runningStepIDs: ["other"]))
    }
}
