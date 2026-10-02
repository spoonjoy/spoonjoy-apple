import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook mode live activity and voice commands")
struct CookModeLiveActivityTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let stamp = "2026-10-02T12:00:00.000Z"

    @Test("starting a timer runs until the step duration has passed")
    func startingRunsUntilDurationPasses() throws {
        let recipe = try fixtureRecipe()
        let session = CookModeTimerSession.starting(recipe: recipe, step: recipe.steps[1], durationSeconds: 300, now: start)

        #expect(session.recipeTitle == recipe.title)
        #expect(session.stepNumber == 2)
        #expect(session.stepTitle == "Sear")
        #expect(session.phase == .running(endsAt: start.addingTimeInterval(300)))
        #expect(session.remainingSeconds(at: start.addingTimeInterval(100.2)) == 200)
        #expect(!session.isPaused)
    }

    @Test("an untitled step falls back to its number")
    func untitledStepFallsBackToItsNumber() throws {
        let recipe = try fixtureRecipe()
        let session = CookModeTimerSession.starting(recipe: recipe, step: recipe.steps[2], durationSeconds: 60, now: start)
        #expect(session.stepTitle == "Step 3")
    }

    @Test("pausing freezes the remaining time and resuming moves the end date")
    func pauseAndResume() throws {
        let recipe = try fixtureRecipe()
        let running = CookModeTimerSession.starting(recipe: recipe, step: recipe.steps[1], durationSeconds: 300, now: start)

        let paused = running.pausing(at: start.addingTimeInterval(120))
        #expect(paused.phase == .paused(remainingSeconds: 180))
        #expect(paused.isPaused)
        #expect(paused.remainingSeconds(at: start.addingTimeInterval(9_999)) == 180)
        #expect(paused.pausing(at: start.addingTimeInterval(130)) == paused)

        let resumeTime = start.addingTimeInterval(500)
        let resumed = paused.resuming(at: resumeTime)
        #expect(resumed.phase == .running(endsAt: resumeTime.addingTimeInterval(180)))
        #expect(resumed.resuming(at: resumeTime) == resumed)
    }

    @Test("pausing after the end time finishes the timer instead")
    func pausingAfterEndFinishes() throws {
        let recipe = try fixtureRecipe()
        let running = CookModeTimerSession.starting(recipe: recipe, step: recipe.steps[1], durationSeconds: 300, now: start)
        let late = running.pausing(at: start.addingTimeInterval(301))
        #expect(late.phase == .finished)
        #expect(late.remainingSeconds(at: start) == 0)
    }

    @Test("settling finishes only elapsed running timers")
    func settling() throws {
        let recipe = try fixtureRecipe()
        let running = CookModeTimerSession.starting(recipe: recipe, step: recipe.steps[1], durationSeconds: 300, now: start)

        #expect(running.settled(at: start.addingTimeInterval(10)) == running)
        #expect(running.settled(at: start.addingTimeInterval(300)).phase == .finished)
        let paused = running.pausing(at: start.addingTimeInterval(10))
        #expect(paused.settled(at: start.addingTimeInterval(9_999)) == paused)
    }

    @Test("activity content follows the current step and flags a timer on another step")
    func contentFollowsCurrentStep() throws {
        let recipe = try fixtureRecipe()
        let session = CookModeTimerSession.starting(recipe: recipe, step: recipe.steps[1], durationSeconds: 300, now: start)
        let progress = CookModeProgress.starting(recipe: recipe, startedAt: stamp)

        let first = CookModeLiveActivityContent(session: session, viewModel: CookModeViewModel(recipe: recipe, progress: progress))
        #expect(first.recipeTitle == recipe.title)
        #expect(first.stepLabel == "Step 1 of 3")
        #expect(first.stepTitle == "Chop")
        #expect(first.timerStepLabel == "Timing step 2: Sear")
        #expect(first.canAdvance)

        let second = try progress.selectingStep(id: recipe.steps[1].id, updatedAt: stamp)
        let onTimerStep = CookModeLiveActivityContent(session: session, viewModel: CookModeViewModel(recipe: recipe, progress: second))
        #expect(onTimerStep.timerStepLabel == nil)
        #expect(onTimerStep.phase == session.phase)

        let third = try progress.selectingStep(id: recipe.steps[2].id, updatedAt: stamp)
        let last = CookModeLiveActivityContent(session: session, viewModel: CookModeViewModel(recipe: recipe, progress: third))
        #expect(last.stepTitle == "Step 3")
        #expect(!last.canAdvance)
    }

    @Test("activity content for a recipe with no steps keeps the timer step")
    func contentWithoutSteps() throws {
        let recipe = try fixtureRecipe()
        let session = CookModeTimerSession.starting(recipe: recipe, step: recipe.steps[1], durationSeconds: 300, now: start)
        let empty = try fixtureRecipe(steps: [])
        let content = CookModeLiveActivityContent(
            session: session,
            viewModel: CookModeViewModel(recipe: empty, progress: CookModeProgress.starting(recipe: empty, startedAt: stamp))
        )
        #expect(content.stepTitle == "Sear")
        #expect(content.timerStepLabel == nil)
        #expect(!content.canAdvance)
    }

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

    @Test("a recipe without steps reports that plainly")
    func emptyRecipe() throws {
        let empty = try fixtureRecipe(steps: [])
        let viewModel = CookModeViewModel(recipe: empty, progress: CookModeProgress.starting(recipe: empty, startedAt: stamp))
        for command in [CookModeSessionCommand.nextStep, .previousStep, .startTimer, .readStep] {
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
