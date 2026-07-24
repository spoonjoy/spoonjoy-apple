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

    @Test("view model covers empty progress navigation bounds and quantity format edges")
    func viewModelCoversEmptyProgressNavigationBoundsAndQuantityFormatEdges() throws {
        let recipe = try cookModeParityRecipe()
        let noCurrentProgress = CookModeProgress(recipeID: recipe.id, stepIDs: [], startedAt: "2026-06-25T12:00:00.000Z")
        let noCurrentViewModel = CookModeViewModel(recipe: recipe, progress: noCurrentProgress)

        #expect(noCurrentViewModel.activeStep?.id == "step_lemon_pasta_1")

        let staleCurrentProgress = CookModeProgress(
            recipeID: recipe.id,
            completedStepIDs: [],
            currentStepID: "legacy_step"
        )
        #expect(CookModeViewModel(recipe: recipe, progress: staleCurrentProgress).activeStep?.id == "step_lemon_pasta_1")

        let emptyRecipe = recipe.replacingSteps([])
        let emptyViewModel = CookModeViewModel(recipe: emptyRecipe, progress: noCurrentProgress)
        #expect(emptyViewModel.activeStep == nil)
        #expect(emptyViewModel.stepProgressLabel == "No steps")
        #expect(emptyViewModel.currentPageProgressLabel == "0 of 0 checked")
        #expect(emptyViewModel.recipeCheckoffFraction == 0)
        #expect(emptyViewModel.ingredientChecklistRows.isEmpty)
        #expect(emptyViewModel.stepOutputChecklistRows.isEmpty)

        let started = CookModeProgress.starting(recipe: recipe, startedAt: "2026-06-25T12:00:00.000Z")
        #expect(CookModeViewModel(recipe: recipe, progress: started).progressAfterSelectingPrevious(updatedAt: "2026-06-25T12:01:00.000Z") == started)
        #expect(try cookModeErrorDescription {
            _ = try started.selectingStep(id: "step_missing", updatedAt: "2026-06-25T12:01:00.000Z")
        } == "Cook mode step step_missing was not found.")
        #expect(started.settingScaleFactor(.infinity, updatedAt: "2026-06-25T12:02:00.000Z").scaleFactor == 1)

        let lastStepID = try #require(recipe.steps.last?.id)
        let lastProgress = try started.selectingStep(id: lastStepID, updatedAt: "2026-06-25T12:03:00.000Z")
        #expect(CookModeViewModel(recipe: recipe, progress: lastProgress).progressAfterSelectingNext(updatedAt: "2026-06-25T12:04:00.000Z") == lastProgress)
        let staleNextProgress = CookModeProgress(
            recipeID: recipe.id,
            completedStepIDs: [],
            currentStepID: "step_lemon_pasta_1"
        )
        #expect(CookModeViewModel(recipe: recipe, progress: staleNextProgress).progressAfterSelectingNext(updatedAt: "2026-06-25T12:04:30.000Z") == staleNextProgress)
        let stalePreviousProgress = CookModeProgress(
            recipeID: recipe.id,
            completedStepIDs: [],
            currentStepID: "step_lemon_pasta_2"
        )
        #expect(CookModeViewModel(recipe: recipe, progress: stalePreviousProgress).progressAfterSelectingPrevious(updatedAt: "2026-06-25T12:04:45.000Z") == stalePreviousProgress)

        let edgeRecipe = recipe.replacingSteps([
            RecipeStep(
                id: "step_quantity_edges",
                stepNum: 1,
                stepTitle: "Format quantities",
                description: "Cover native cook mode quantity labels.",
                duration: nil,
                ingredients: [
                    RecipeIngredient(id: "ingredient_half", name: "salt", quantity: 0.5, unit: nil),
                    RecipeIngredient(id: "ingredient_decimal", name: "rice", quantity: 1.2, unit: "cup"),
                    RecipeIngredient(id: "ingredient_infinite", name: "stock", quantity: .infinity, unit: "cup"),
                    RecipeIngredient(id: "ingredient_negative", name: "adjustment", quantity: -0.25, unit: "tsp")
                ],
                usingSteps: [
                    RecipeStepOutputUse(
                        id: "use_untitled_output",
                        inputStepNum: 1,
                        outputStepNum: 99,
                        outputOfStep: RecipeStepOutputReference(stepNum: 99, stepTitle: nil)
                    )
                ]
            )
        ])
        let edgeProgress = CookModeProgress.starting(recipe: edgeRecipe, startedAt: "2026-06-25T12:05:00.000Z")
        let edgeViewModel = CookModeViewModel(recipe: edgeRecipe, progress: edgeProgress)
        #expect(edgeViewModel.ingredientChecklistRows.map(\.quantityText) == ["½", "1.2 cup", "1 cup", "-¼ tsp"])
        #expect(edgeViewModel.stepOutputChecklistRows.map(\.title) == ["Step 99"])
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
        #expect(viewModel.recipeProgressLabel == "2 of 7 checked")
        #expect(viewModel.recipeCheckoffFraction == 2.0 / 7.0)
        #expect(viewModel.completionFraction == 0)
        #expect(viewModel.currentPageProgressLabel == "2 of 4 checked")
        #expect(viewModel.ingredientChecklistRows.map(\.id) == [
            "ingredient_lemon_pasta_lemon",
            "ingredient_lemon_pasta_oil",
            "ingredient_lemon_pasta_garlic"
        ])
        #expect(viewModel.ingredientChecklistRows.map(\.quantityText) == ["2 ½ each", "5 tbsp", "5 clove"])
        #expect(viewModel.ingredientChecklistRows.last?.isChecked == true)
        #expect(viewModel.stepOutputChecklistRows.map(\.title) == ["Step 1: Boil Pasta"])
        #expect(viewModel.stepOutputChecklistRows.first?.isChecked == true)

        let unchecked = try progress
            .togglingIngredient(id: "ingredient_lemon_pasta_garlic", checked: false, updatedAt: "2026-06-25T12:05:00.000Z")
            .togglingStepOutputUse(id: "use_step_lemon_pasta_1", checked: false, updatedAt: "2026-06-25T12:06:00.000Z")
        let uncheckedViewModel = CookModeViewModel(recipe: recipe, progress: unchecked)

        #expect(unchecked.checkedIngredientIDs.isEmpty)
        #expect(unchecked.checkedStepOutputUseIDs.isEmpty)
        #expect(uncheckedViewModel.recipeProgressLabel == "0 of 7 checked")
        #expect(uncheckedViewModel.recipeCheckoffFraction == 0)
        #expect(uncheckedViewModel.currentPageProgressLabel == "0 of 4 checked")
        #expect(uncheckedViewModel.ingredientChecklistRows.map(\.id) == [
            "ingredient_lemon_pasta_garlic",
            "ingredient_lemon_pasta_lemon",
            "ingredient_lemon_pasta_oil"
        ])
        #expect(uncheckedViewModel.stepOutputChecklistRows.first?.isChecked == false)
        #expect(try CookModeProgress.restore(from: unchecked.snapshot(), recipe: recipe) == unchecked)
        #expect(try viewModel.progressAfterTogglingIngredient(
            id: "ingredient_lemon_pasta_lemon",
            checked: true,
            updatedAt: "2026-06-25T12:07:00.000Z"
        ).checkedIngredientIDs == ["ingredient_lemon_pasta_garlic", "ingredient_lemon_pasta_lemon"])
        #expect(try viewModel.progressAfterTogglingStepOutputUse(
            id: "use_step_lemon_pasta_1",
            checked: false,
            updatedAt: "2026-06-25T12:08:00.000Z"
        ).checkedStepOutputUseIDs.isEmpty)

        #expect(try cookModeErrorDescription {
            _ = try progress.togglingIngredient(id: "ingredient_not_in_recipe", checked: true, updatedAt: "2026-06-25T12:05:00.000Z")
        } == "Cook mode ingredient ingredient_not_in_recipe was not found.")
        #expect(try cookModeErrorDescription {
            _ = try progress.togglingStepOutputUse(id: "use_missing", checked: true, updatedAt: "2026-06-25T12:05:00.000Z")
        } == "Cook mode step output use use_missing was not found.")
    }

    @Test("checked step ingredients keep stable active then completed ordering")
    func checkedStepIngredientsKeepStableActiveThenCompletedOrdering() throws {
        let recipe = try cookModeParityRecipe()
        let progress = try CookModeProgress
            .starting(recipe: recipe, startedAt: "2026-06-25T12:00:00.000Z")
            .selectingStep(id: "step_lemon_pasta_2", updatedAt: "2026-06-25T12:01:00.000Z")
            .togglingIngredient(id: "ingredient_lemon_pasta_lemon", checked: true, updatedAt: "2026-06-25T12:02:00.000Z")
            .togglingIngredient(id: "ingredient_lemon_pasta_garlic", checked: true, updatedAt: "2026-06-25T12:03:00.000Z")

        let rows = CookModeViewModel(recipe: recipe, progress: progress).ingredientChecklistRows
        #expect(rows.map(\.id) == [
            "ingredient_lemon_pasta_oil",
            "ingredient_lemon_pasta_lemon",
            "ingredient_lemon_pasta_garlic"
        ])
        #expect(rows.map(\.isChecked) == [false, true, true])

        let unchecked = try progress.togglingIngredient(
            id: "ingredient_lemon_pasta_lemon",
            checked: false,
            updatedAt: "2026-06-25T12:04:00.000Z"
        )
        let uncheckedRows = CookModeViewModel(recipe: recipe, progress: unchecked).ingredientChecklistRows
        #expect(uncheckedRows.map(\.id) == [
            "ingredient_lemon_pasta_lemon",
            "ingredient_lemon_pasta_oil",
            "ingredient_lemon_pasta_garlic"
        ])
        #expect(uncheckedRows.map(\.isChecked) == [false, false, true])
    }

    @Test("duration cues hand timed steps to the native system timer")
    func durationCuesHandTimedStepsToTheNativeSystemTimer() throws {
        let recipe = try cookModeParityRecipe()
        let started = CookModeProgress.starting(recipe: recipe, startedAt: "2026-06-25T12:00:00.000Z")
        let timer = try #require(CookModeViewModel(recipe: recipe, progress: started).systemTimer)

        #expect(timer.stepID == "step_lemon_pasta_1")
        #expect(timer.durationMinutes == 10)
        #expect(timer.durationSeconds == 600)
        #expect(timer.durationLabel == "10 min")
        #expect(timer.startButtonTitle == "Set 10 min timer")
        #expect(timer.systemUnavailableMessage == "Timer unavailable.")

        let secondStepProgress = try started.selectingStep(id: "step_lemon_pasta_2", updatedAt: "2026-06-25T12:15:00.000Z")
        let secondStepTimer = try #require(CookModeViewModel(recipe: recipe, progress: secondStepProgress).systemTimer)
        #expect(secondStepTimer.stepID == "step_lemon_pasta_2")
        #expect(secondStepTimer.durationMinutes == 5)
        #expect(secondStepTimer.durationSeconds == 300)
        #expect(secondStepTimer.durationLabel == "5 min")

        let noTimerStep = recipe.replacingStepDuration(stepID: "step_lemon_pasta_3", duration: nil)
        let noTimerProgress = try secondStepProgress.selectingStep(id: "step_lemon_pasta_3", updatedAt: "2026-06-25T12:16:00.000Z")
        #expect(CookModeViewModel(recipe: noTimerStep, progress: noTimerProgress).systemTimer == nil)

        let zeroTimerRecipe = recipe.replacingStepDuration(stepID: "step_lemon_pasta_3", duration: 0)
        #expect(CookModeViewModel(recipe: zeroTimerRecipe, progress: noTimerProgress).systemTimer == nil)
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
            #expect(try CookModeProgress.restore(from: progress.snapshot(), recipe: recipe) == progress)

            let staleRestored = try CookModeProgress.restore(
                from: staleCookModeProgressSnapshot(scaleFactor: 51.236, activeStepIndex: 99),
                recipe: recipe
            )
            #expect(staleRestored.currentStepID == "step_lemon_pasta_3")
            #expect(staleRestored.scaleFactor == 50)
            #expect(staleRestored.checkedIngredientIDs == ["ingredient_lemon_pasta_lemon"])
            #expect(staleRestored.checkedStepOutputUseIDs == ["use_step_lemon_pasta_1"])

            let lowScaleRestored = try CookModeProgress.restore(
                from: staleCookModeProgressSnapshot(scaleFactor: 0.01, activeStepIndex: -4),
                recipe: recipe
            )
            #expect(lowScaleRestored.currentStepID == "step_lemon_pasta_1")
            #expect(lowScaleRestored.scaleFactor == 0.25)

            let roundedScaleRestored = try CookModeProgress.restore(
                from: staleCookModeProgressSnapshot(scaleFactor: 1.236, activeStepIndex: 1),
                recipe: recipe
            )
            #expect(roundedScaleRestored.scaleFactor == 1.24)

            let wrongShapeScaleRestored = try CookModeProgress.restore(
                from: wrongShapeScaleCookModeProgressSnapshot(),
                recipe: recipe
            )
            #expect(wrongShapeScaleRestored.scaleFactor == 1)

            let minimalLegacy = try CookModeProgress.restore(from: minimalLegacyCookModeProgressSnapshot())
            #expect(minimalLegacy.stepIDs.isEmpty)
            #expect(minimalLegacy.activeStepIndex == 0)
            #expect(minimalLegacy.completedStepIDs.isEmpty)
            #expect(minimalLegacy.startedAt == "")
            #expect(minimalLegacy.updatedAt == "")

            let missingCurrentStep = try CookModeProgress.restore(
                from: missingCurrentStepCookModeProgressSnapshot(),
                recipe: recipe
            )
            #expect(missingCurrentStep.currentStepID == "step_lemon_pasta_1")
        }
    }

    @Test("legacy cook progress rehydrates against a full recipe after placeholder restore")
    func legacyCookProgressRehydratesAgainstFullRecipeAfterPlaceholderRestore() throws {
        let recipe = try cookModeParityRecipe()
        let legacyProgress = CookModeProgress(
            recipeID: recipe.id,
            completedStepIDs: ["step_lemon_pasta_1"],
            currentStepID: "step_lemon_pasta_2"
        )

        let rehydrated = try CookModeProgress.restore(from: legacyProgress.snapshot(), recipe: recipe)
        let toggled = try rehydrated
            .togglingIngredient(
                id: "ingredient_lemon_pasta_garlic",
                checked: true,
                updatedAt: "2026-06-25T12:10:00.000Z"
            )
            .togglingStepOutputUse(
                id: "use_step_lemon_pasta_1",
                checked: true,
                updatedAt: "2026-06-25T12:11:00.000Z"
            )

        #expect(rehydrated.currentStepID == "step_lemon_pasta_2")
        #expect(rehydrated.completedStepIDs == ["step_lemon_pasta_1"])
        #expect(rehydrated.ingredientIDs.contains("ingredient_lemon_pasta_garlic"))
        #expect(rehydrated.stepOutputUseIDs == ["use_step_lemon_pasta_1"])
        #expect(toggled.checkedIngredientIDs == ["ingredient_lemon_pasta_garlic"])
        #expect(toggled.checkedStepOutputUseIDs == ["use_step_lemon_pasta_1"])
        #expect(CookModeViewModel(recipe: recipe, progress: toggled).currentPageProgressLabel == "2 of 4 checked")
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

    private func staleCookModeProgressSnapshot(scaleFactor: Double, activeStepIndex: Int) -> Data {
        Data(
            """
            {
              "recipeID": "recipe_lemon_pantry_pasta",
              "stepIDs": ["step_lemon_pasta_1", "step_lemon_pasta_2", "step_lemon_pasta_3"],
              "activeStepIndex": \(activeStepIndex),
              "completedStepIDs": ["step_lemon_pasta_1", "stale_step"],
              "scaleFactor": \(scaleFactor),
              "checkedIngredientIDs": ["ingredient_lemon_pasta_lemon", "ingredient_stale"],
              "checkedStepOutputUseIDs": ["use_step_lemon_pasta_1", "use_stale"],
              "startedAt": "2026-06-25T12:00:00.000Z",
              "updatedAt": "2026-06-25T12:05:00.000Z"
            }
            """.utf8
        )
    }

    private func wrongShapeScaleCookModeProgressSnapshot() -> Data {
        Data(
            """
            {
              "recipeID": "recipe_lemon_pantry_pasta",
              "stepIDs": ["step_lemon_pasta_1", "step_lemon_pasta_2", "step_lemon_pasta_3"],
              "activeStepIndex": 1,
              "completedStepIDs": [],
              "scaleFactor": "not-a-number",
              "checkedIngredientIDs": [],
              "checkedStepOutputUseIDs": [],
              "startedAt": "2026-06-25T12:00:00.000Z",
              "updatedAt": "2026-06-25T12:05:00.000Z"
            }
            """.utf8
        )
    }

    private func minimalLegacyCookModeProgressSnapshot() -> Data {
        Data(
            """
            {
              "recipeID": "recipe_legacy_minimal"
            }
            """.utf8
        )
    }

    private func missingCurrentStepCookModeProgressSnapshot() -> Data {
        Data(
            """
            {
              "recipeID": "recipe_lemon_pantry_pasta",
              "stepIDs": ["legacy_step"],
              "activeStepIndex": 0,
              "completedStepIDs": [],
              "scaleFactor": "1.5",
              "checkedIngredientIDs": [],
              "checkedStepOutputUseIDs": [],
              "startedAt": "2026-06-25T12:00:00.000Z",
              "updatedAt": "2026-06-25T12:05:00.000Z"
            }
            """.utf8
        )
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
    func replacingSteps(_ replacementSteps: [RecipeStep]) -> Recipe {
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
            steps: replacementSteps,
            cookbooks: cookbooks,
            recentSpoons: recentSpoons
        )
    }

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
