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

    static func timer(_ stepID: String) -> CookModeSystemTimerViewModel {
        CookModeSystemTimerViewModel(stepID: stepID, durationMinutes: 3, durationSeconds: 180)
    }

    @MainActor @Test func startsEachTimerWhoseStepIsStillChecked() async {
        let steps = [Self.step(id: "s1", duration: 3, ingredientIDs: ["a"]), Self.step(id: "s2", duration: 3, ingredientIDs: ["b"])]
        var started: [String] = []
        var failures: [String: String] = [:]
        await CookAutoTimerPolicy.startTimers(
            [Self.timer("s1"), Self.timer("s2")],
            steps: steps,
            stillChecked: ["a"],
            start: { timer in
                started.append(timer.stepID)
                return .started(UUID())
            },
            failed: { failures[$0] = $1 }
        )
        #expect(started == ["s1"])
        #expect(failures.isEmpty)
    }

    @MainActor @Test func reportsAFailedStartWithTheRingsMessage() async {
        let steps = [Self.step(id: "s1", duration: 3, ingredientIDs: ["a"]), Self.step(id: "s2", duration: 3, ingredientIDs: ["b"])]
        var started: [String] = []
        var failures: [String: String] = [:]
        await CookAutoTimerPolicy.startTimers(
            [Self.timer("s1"), Self.timer("s2")],
            steps: steps,
            stillChecked: ["a", "b"],
            start: { timer in
                if timer.stepID == "s1" {
                    throw CookModeSystemTimerSchedulingError.denied
                }
                started.append(timer.stepID)
                return .started(UUID())
            },
            failed: { failures[$0] = $1 }
        )
        #expect(failures == ["s1": "Allow system timers in Settings to set this timer."])
        #expect(started == ["s2"])
    }

    @MainActor @Test func skipsATimerWhoseStepIsGone() async {
        var started: [String] = []
        await CookAutoTimerPolicy.startTimers(
            [Self.timer("gone")],
            steps: [],
            stillChecked: ["a"],
            start: { timer in
                started.append(timer.stepID)
                return .started(UUID())
            },
            failed: { _, _ in }
        )
        #expect(started.isEmpty)
    }
}
