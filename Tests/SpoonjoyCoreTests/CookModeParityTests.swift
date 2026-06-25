import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native cook mode parity")
struct CookModeParityTests {
    @Test("start and continue cook mode preserve active step route state")
    func startAndContinueCookModePreserveActiveStepRouteState() throws {
        let recipe = try cookModeParityRecipe()
        let started = CookModeProgress.starting(recipe: recipe, startedAt: "2026-06-25T12:00:00.000Z")

        #expect(started.recipeID == recipe.id)
        #expect(started.stepIDs == recipe.steps.map(\.id))
        #expect(started.currentStepID == "step_lemon_pasta_1")
        #expect(started.scaleFactor == 1)
        #expect(started.checkedIngredientIDs.isEmpty)
        #expect(started.checkedStepOutputUseIDs.isEmpty)

        let continued = try started.selectingStep(id: "step_lemon_pasta_2", updatedAt: "2026-06-25T12:02:00.000Z")
        let viewModel = CookModeViewModel(recipe: recipe, progress: continued)

        #expect(continued.activeStepIndex == 1)
        #expect(continued.currentStepID == "step_lemon_pasta_2")
        #expect(viewModel.activeStep?.id == "step_lemon_pasta_2")
        #expect(viewModel.stepProgressLabel == "Step 2 of 3")
        #expect(viewModel.progressAfterSelectingNext(updatedAt: "2026-06-25T12:03:00.000Z").currentStepID == "step_lemon_pasta_3")
        #expect(viewModel.progressAfterSelectingPrevious(updatedAt: "2026-06-25T12:04:00.000Z").currentStepID == "step_lemon_pasta_1")
    }

    @Test("scale ingredient checkoff and step output checkoff match web cook mode")
    func scaleIngredientCheckoffAndStepOutputCheckoffMatchWebCookMode() throws {
        let recipe = try cookModeParityRecipe()
        let progress = try CookModeProgress
            .starting(recipe: recipe, startedAt: "2026-06-25T12:00:00.000Z")
            .selectingStep(id: "step_lemon_pasta_2", updatedAt: "2026-06-25T12:01:00.000Z")
            .settingScaleFactor(2.5, updatedAt: "2026-06-25T12:02:00.000Z")
            .togglingIngredient(id: "ingredient_lemon_pasta_garlic", checked: true, updatedAt: "2026-06-25T12:03:00.000Z")
            .togglingStepOutputUse(id: "use_step_lemon_pasta_1", checked: true, updatedAt: "2026-06-25T12:04:00.000Z")

        let viewModel = CookModeViewModel(recipe: recipe, progress: progress)

        #expect(progress.scaleFactor == 2.5)
        #expect(progress.checkedIngredientIDs == ["ingredient_lemon_pasta_garlic"])
        #expect(progress.checkedStepOutputUseIDs == ["use_step_lemon_pasta_1"])
        #expect(viewModel.recipeProgressLabel == "2 of 4 checked")
        #expect(viewModel.ingredientChecklistRows.map(\.id) == [
            "ingredient_lemon_pasta_lemon",
            "ingredient_lemon_pasta_oil",
            "ingredient_lemon_pasta_garlic"
        ])
        #expect(viewModel.ingredientChecklistRows.map(\.quantityText) == ["2 ½ each", "5 tbsp", "5 clove"])
        #expect(viewModel.ingredientChecklistRows.last?.isChecked == true)
        #expect(viewModel.stepOutputChecklistRows.map(\.title) == ["Step 1: Boil Pasta"])
        #expect(viewModel.stepOutputChecklistRows.first?.isChecked == true)

        #expect(try cookModeErrorDescription {
            _ = try progress.togglingIngredient(id: "ingredient_not_in_recipe", checked: true, updatedAt: "2026-06-25T12:05:00.000Z")
        } == "Cook mode ingredient ingredient_not_in_recipe was not found.")
        #expect(try cookModeErrorDescription {
            _ = try progress.togglingStepOutputUse(id: "use_missing", checked: true, updatedAt: "2026-06-25T12:05:00.000Z")
        } == "Cook mode step output use use_missing was not found.")
    }

    @Test("duration timers exist only for duration bearing steps")
    func durationTimersExistOnlyForDurationBearingSteps() throws {
        let recipe = try cookModeParityRecipe()
        let started = CookModeProgress.starting(recipe: recipe, startedAt: "2026-06-25T12:00:00.000Z")
        let timer = try #require(CookModeViewModel(recipe: recipe, progress: started).timer)

        #expect(timer.stepID == "step_lemon_pasta_1")
        #expect(timer.durationSeconds == 600)
        #expect(timer.remainingSeconds == 600)
        #expect(timer.formattedRemainingTime == "10:00")
        #expect(!timer.isRunning)
        #expect(timer.startButtonTitle == "Start timer")
        #expect(timer.pauseButtonTitle == "Pause timer")
        #expect(timer.resetButtonTitle == "Reset timer")

        let secondStepProgress = try started.selectingStep(id: "step_lemon_pasta_2", updatedAt: "2026-06-25T12:15:00.000Z")
        let secondStepTimer = try #require(CookModeViewModel(recipe: recipe, progress: secondStepProgress).timer)
        #expect(secondStepTimer.stepID == "step_lemon_pasta_2")
        #expect(secondStepTimer.durationSeconds == 300)
        #expect(secondStepTimer.formattedRemainingTime == "05:00")

        let noTimerStep = recipe.replacingStepDuration(stepID: "step_lemon_pasta_3", duration: nil)
        let noTimerProgress = try secondStepProgress.selectingStep(id: "step_lemon_pasta_3", updatedAt: "2026-06-25T12:16:00.000Z")
        #expect(CookModeViewModel(recipe: noTimerStep, progress: noTimerProgress).timer == nil)
    }

    @Test("offline app snapshot restores exact cook mode progress")
    func offlineAppSnapshotRestoresExactCookModeProgress() throws {
        try withTemporaryDirectory { directory in
            let recipe = try cookModeParityRecipe()
            let fileURL = directory.appendingPathComponent("native-state.json")
            let store = NativeAppStateStore(fileURL: fileURL)
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: "2026-06-25T12:00:00.000Z"
            )
            let progress = try CookModeProgress
                .starting(recipe: recipe, startedAt: "2026-06-25T12:00:00.000Z")
                .selectingStep(id: "step_lemon_pasta_2", updatedAt: "2026-06-25T12:01:00.000Z")
                .settingScaleFactor(0.25, updatedAt: "2026-06-25T12:02:00.000Z")
                .togglingIngredient(id: "ingredient_lemon_pasta_lemon", checked: true, updatedAt: "2026-06-25T12:03:00.000Z")
                .togglingStepOutputUse(id: "use_step_lemon_pasta_1", checked: true, updatedAt: "2026-06-25T12:04:00.000Z")

            let saved = fallback
                .updatingCookProgress(progress, savedAt: "2026-06-25T12:05:00.000Z")
                .recordingOpenedRoute(.recipeDetail(id: recipe.id, presentation: .cook), savedAt: "2026-06-25T12:05:00.000Z")
            try store.save(saved)

            let restored = try store.loadOrCreate(fallback: fallback).value
            let restoredProgress = try #require(restored.cookProgress(for: recipe.id))

            #expect(restoredProgress == progress)
            #expect(restored.lastOpenedRoute == "recipe-cook:recipe_lemon_pantry_pasta")
            #expect(try CookModeProgress.restore(from: progress.snapshot()) == progress)
        }
    }

    @Test("Siri and deep links open or continue cook mode in the correct place")
    func siriAndDeepLinksOpenOrContinueCookModeInCorrectPlace() throws {
        let resolver = NativeIntentActionResolver()
        let start = try resolver.startCookMode(recipeID: "recipe_lemon_pantry_pasta")
        let continueCooking = try resolver.continueCookMode(recipeID: " recipe_lemon_pantry_pasta ")
        let expectedRoute = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook)

        #expect(start.route == expectedRoute)
        #expect(start.url == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta/cook"))
        #expect(continueCooking.route == expectedRoute)
        #expect(continueCooking.url == start.url)
        #expect(DeepLinkRouter.spoonjoy.route(for: try #require(URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta/cook"))) == expectedRoute)
        #expect(DeepLinkRouter.spoonjoy.route(for: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta?mode=cook"))) == expectedRoute)
        #expect(DeepLinkRouter.spoonjoy.route(for: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta#cook"))) == expectedRoute)
    }

    private func cookModeParityRecipe() throws -> Recipe {
        let base = try #require(RecipeFixtureCatalog.decodeFromBundle().recipe(id: "recipe_lemon_pantry_pasta"))
        let first = try #require(base.steps.first)
        let second = try #require(base.steps.dropFirst().first)
        let third = try #require(base.steps.dropFirst(2).first)
        let secondWithDependency = RecipeStep(
            id: second.id,
            stepNum: second.stepNum,
            stepTitle: second.stepTitle,
            description: second.description,
            duration: second.duration,
            ingredients: second.ingredients,
            usingSteps: [
                RecipeStepOutputUse(
                    id: "use_step_lemon_pasta_1",
                    inputStepNum: second.stepNum,
                    outputStepNum: first.stepNum,
                    outputOfStep: RecipeStepOutputReference(stepNum: first.stepNum, stepTitle: first.stepTitle)
                )
            ]
        )

        return Recipe(
            id: base.id,
            title: base.title,
            description: base.description,
            servings: base.servings,
            chef: base.chef,
            coverImageURL: base.coverImageURL,
            coverProvenanceLabel: base.coverProvenanceLabel,
            coverSourceType: base.coverSourceType,
            coverVariant: base.coverVariant,
            href: base.href,
            canonicalURL: base.canonicalURL,
            attribution: base.attribution,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
            steps: [first, secondWithDependency, third],
            cookbooks: base.cookbooks,
            recentSpoons: base.recentSpoons
        )
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-cook-mode-parity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}

private func cookModeErrorDescription(_ operation: () throws -> Void) throws -> String? {
    do {
        try operation()
        return nil
    } catch let error as KitchenStateError {
        return error.description
    }
}

private extension Recipe {
    func replacingStepDuration(stepID: String, duration: Int?) -> Recipe {
        Recipe(
            id: id,
            title: title,
            description: description,
            servings: servings,
            chef: chef,
            coverImageURL: coverImageURL,
            coverProvenanceLabel: coverProvenanceLabel,
            coverSourceType: coverSourceType,
            coverVariant: coverVariant,
            href: href,
            canonicalURL: canonicalURL,
            attribution: attribution,
            createdAt: createdAt,
            updatedAt: updatedAt,
            steps: steps.map { step in
                guard step.id == stepID else {
                    return step
                }
                return RecipeStep(
                    id: step.id,
                    stepNum: step.stepNum,
                    stepTitle: step.stepTitle,
                    description: step.description,
                    duration: duration,
                    ingredients: step.ingredients,
                    usingSteps: step.usingSteps
                )
            },
            cookbooks: cookbooks,
            recentSpoons: recentSpoons
        )
    }
}
