import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook mode voice commands")
struct CookModeSessionCommandTests {
    private let stamp = "2026-10-02T12:00:00.000Z"

    @Test("next and previous move one step and read it aloud")
    func nextAndPrevious() throws {
        let recipe = try fixtureRecipe()
        let first = CookModeViewModel(recipe: recipe, progress: CookModeProgress.starting(recipe: recipe, startedAt: stamp))

        let next = CookModeSessionResolver.resolve(.nextStep, viewModel: first, updatedAt: stamp)
        #expect(next.progress.currentStepID == recipe.steps[1].id)
        #expect(next.message == "Step 2 of 3, Sear. Sear the steaks. This step takes 5 min.")
        #expect(next.timerToStart == nil)

        let second = CookModeViewModel(recipe: recipe, progress: next.progress)
        let previous = CookModeSessionResolver.resolve(.previousStep, viewModel: second, updatedAt: stamp)
        #expect(previous.progress.currentStepID == recipe.steps[0].id)
        #expect(previous.message == "Step 1 of 3, Chop. Chop the shallots.")
    }

    @Test("next on the last step and previous on the first step stay put")
    func boundsStayPut() throws {
        let recipe = try fixtureRecipe()
        let start = CookModeViewModel(recipe: recipe, progress: CookModeProgress.starting(recipe: recipe, startedAt: stamp))
        let atFirst = CookModeSessionResolver.resolve(.previousStep, viewModel: start, updatedAt: stamp)
        #expect(atFirst.progress == start.progress)
        #expect(atFirst.message == "You are on the first step. Step 1 of 3, Chop. Chop the shallots.")

        let lastProgress = try start.progress.selectingStep(id: recipe.steps[2].id, updatedAt: stamp)
        let atLast = CookModeSessionResolver.resolve(.nextStep, viewModel: CookModeViewModel(recipe: recipe, progress: lastProgress), updatedAt: stamp)
        #expect(atLast.progress == lastProgress)
        #expect(atLast.message == "You are on the last step. Step 3 of 3. Plate it.")
    }

    @Test("start timer needs a timed step and read step never changes progress")
    func startTimerAndRead() throws {
        let recipe = try fixtureRecipe()
        let first = CookModeViewModel(recipe: recipe, progress: CookModeProgress.starting(recipe: recipe, startedAt: stamp))
        let untimed = CookModeSessionResolver.resolve(.startTimer, viewModel: first, updatedAt: stamp)
        #expect(untimed.message == "This step has no timer.")
        #expect(untimed.timerToStart == nil)

        let secondProgress = try first.progress.selectingStep(id: recipe.steps[1].id, updatedAt: stamp)
        let second = CookModeViewModel(recipe: recipe, progress: secondProgress)
        let timed = CookModeSessionResolver.resolve(.startTimer, viewModel: second, updatedAt: stamp)
        #expect(timed.timerToStart?.durationSeconds == 300)
        #expect(timed.message == "Starting a 5 min timer.")

        let read = CookModeSessionResolver.resolve(.readStep, viewModel: second, updatedAt: stamp)
        #expect(read.progress == secondProgress)
        #expect(read.message == CookModeSessionResolver.readout(for: second))
    }

    @Test("check marks every ingredient and earlier-step output on the step, once")
    func checkStep() throws {
        let use = RecipeStepOutputUse(id: "u1", inputStepNum: 2, outputStepNum: 1, outputOfStep: RecipeStepOutputReference(stepNum: 1, stepTitle: "Chop"))
        let recipe = try fixtureRecipe(steps: [
            RecipeStep(id: "s1", stepNum: 1, stepTitle: "Chop", description: "Chop.", duration: nil,
                       ingredients: [RecipeIngredient(id: "i1", name: "Onion", quantity: 1, unit: nil)]),
            RecipeStep(id: "s2", stepNum: 2, stepTitle: "Sear", description: "Sear.", duration: 5,
                       ingredients: [
                           RecipeIngredient(id: "i2", name: "Steak", quantity: 1, unit: nil),
                           RecipeIngredient(id: "i3", name: "Salt", quantity: 1, unit: "tsp"),
                       ],
                       usingSteps: [use]),
        ])
        let start = CookModeProgress.starting(recipe: recipe, startedAt: stamp)
        let second = try start.selectingStep(id: "s2", updatedAt: stamp).togglingIngredient(id: "i3", checked: true, updatedAt: stamp)
        let outcome = CookModeSessionResolver.resolve(.checkStep, viewModel: CookModeViewModel(recipe: recipe, progress: second), updatedAt: stamp)
        #expect(Set(outcome.progress.checkedIngredientIDs) == ["i2", "i3"])
        #expect(outcome.progress.checkedStepOutputUseIDs == ["u1"])
        #expect(outcome.progress.currentStepID == "s2")
        #expect(outcome.message == "Checked everything for step 2.")
        #expect(outcome.timerToStart == nil)

        let again = CookModeSessionResolver.resolve(.checkStep, viewModel: CookModeViewModel(recipe: recipe, progress: outcome.progress), updatedAt: stamp)
        #expect(again.progress == outcome.progress)
        #expect(again.message == "Step 2 is already checked.")

        let bare = try fixtureRecipe()
        let nothing = CookModeSessionResolver.resolve(
            .checkStep,
            viewModel: CookModeViewModel(recipe: bare, progress: CookModeProgress.starting(recipe: bare, startedAt: stamp)),
            updatedAt: stamp
        )
        #expect(nothing.message == "Step 1 has nothing to check.")

        // Progress restored from an older build may not list the step's ids; check leaves it as it is.
        let unlisted = CookModeProgress(recipeID: recipe.id, stepIDs: ["s1", "s2"], startedAt: stamp)
        let stale = CookModeSessionResolver.resolve(
            .checkStep,
            viewModel: CookModeViewModel(recipe: recipe, progress: try unlisted.selectingStep(id: "s2", updatedAt: stamp)),
            updatedAt: stamp
        )
        #expect(stale.progress.checkedIngredientIDs.isEmpty)
        #expect(stale.progress.checkedStepOutputUseIDs.isEmpty)
    }

    @Test("a recipe without steps reports that plainly")
    func emptyRecipe() throws {
        let empty = try fixtureRecipe(steps: [])
        let viewModel = CookModeViewModel(recipe: empty, progress: CookModeProgress.starting(recipe: empty, startedAt: stamp))
        for command in [CookModeSessionCommand.nextStep, .previousStep, .startTimer, .readStep, .checkStep] {
            let outcome = CookModeSessionResolver.resolve(command, viewModel: viewModel, updatedAt: stamp)
            #expect(outcome.message == "This recipe has no steps.")
            #expect(outcome.timerToStart == nil)
        }
        #expect(CookModeSessionResolver.readout(for: viewModel) == "This recipe has no steps.")
    }

    private func fixtureRecipe(steps: [RecipeStep]? = nil) throws -> Recipe {
        let base = try #require(RecipeFixtureCatalog.decodeFromBundle().recipe(id: "recipe_lemon_pantry_pasta"))
        let chosen = steps ?? [
            RecipeStep(id: "s1", stepNum: 1, stepTitle: "Chop", description: "Chop the shallots.", duration: nil, ingredients: []),
            RecipeStep(id: "s2", stepNum: 2, stepTitle: "Sear", description: "Sear the steaks.", duration: 5, ingredients: []),
            RecipeStep(id: "s3", stepNum: 3, stepTitle: nil, description: "Plate it.", duration: nil, ingredients: [])
        ]
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
            steps: chosen,
            cookbooks: base.cookbooks,
            recentSpoons: base.recentSpoons
        )
    }
}
