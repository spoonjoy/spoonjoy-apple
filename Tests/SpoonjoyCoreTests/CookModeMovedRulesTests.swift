import Foundation
import Testing
@testable import SpoonjoyCore

/// The cook-mode glue that moved out of CookModeView and CookModeSessionCenter so the app and Reins run one path.
@MainActor
@Suite("Cook mode rules moved into Core")
struct CookModeMovedRulesTests {
    private struct Refused: Error {}

    private static let recipe = CookSessionSnapshotTests.recipe(steps: CookSessionSnapshotTests.steps)
    private static let timed = recipe.steps[1]
    private static var timer: CookModeSystemTimerViewModel {
        CookModeSystemTimerViewModel(stepID: "s2", durationMinutes: 10, durationSeconds: 600)
    }

    private func model(step: String? = nil, checked: [String] = []) throws -> CookModeViewModel {
        var progress = CookModeProgress.starting(recipe: Self.recipe, startedAt: "t")
        if let step {
            progress = try progress.selectingStep(id: step, updatedAt: "t")
        }
        for id in checked {
            progress = try progress.togglingIngredient(id: id, checked: true, updatedAt: "t")
        }
        return CookModeViewModel(recipe: Self.recipe, progress: progress)
    }

    // MARK: Step timers

    @Test func startSetsOneAlarmAndRecordsItsEnd() async throws {
        let registry = CookStepTimerRegistry()
        var clock = CookTimerClock()
        var scheduled = 0
        let alarms = CookStepAlarms(schedule: { _, _, _ in scheduled += 1; return UUID() }, cancel: { _ in })
        let now = Date(timeIntervalSince1970: 1000)
        let first = try await CookStepTimers.start(Self.timer, recipe: Self.recipe, step: Self.timed, registry: registry, alarms: alarms, now: { now }) { $0(&clock) }
        let second = try await CookStepTimers.start(Self.timer, recipe: Self.recipe, step: Self.timed, registry: registry, alarms: alarms, now: { now }) { $0(&clock) }
        guard case .started(let id) = first else { Issue.record("not started"); return }
        #expect(second == .alreadyRunning(id))
        #expect(scheduled == 1)
        #expect(clock.records[id.uuidString]?.endsAt == now.addingTimeInterval(600))
        #expect(try CookStepTimers.cancel(recipe: Self.recipe, step: Self.timed, registry: registry, alarms: alarms))
        #expect(try !CookStepTimers.cancel(recipe: Self.recipe, step: Self.timed, registry: registry, alarms: alarms))
    }

    @Test func theJourneyStandInSetsAndForgetsAnAlarm() async throws {
        let alarms = CookStepAlarms.journeyStandIn
        let id = try await alarms.schedule(Self.timer, Self.recipe, Self.timed)
        try alarms.cancel(id)
    }

    @Test func autoStartStartsStillCheckedStepsAndReportsFailures() async {
        var started: [String] = []
        var failures: [String: String] = [:]
        let other = CookModeSystemTimerViewModel(stepID: "s1", durationMinutes: 1, durationSeconds: 60)
        await CookStepTimers.autoStart([Self.timer, other], steps: Self.recipe.steps, stillChecked: ["i1", "i2"], start: { timer in
            guard timer.stepID == "s2" else { throw CookModeSystemTimerSchedulingError.denied }
            started.append(timer.stepID)
            return .started(UUID())
        }, failed: { failures[$0] = $1 })
        #expect(started == ["s2"])
        #expect(failures == ["s1": "Allow system timers in Settings to set this timer."])
        #expect(CookStepTimers.autoStartDelay == .milliseconds(250))
    }

    @Test func ringTextAndLine() {
        #expect(CookTimerRingText.started(Self.timer) == "10 min timer started.")
        #expect(CookTimerRingText.cancelled(Self.timer) == "10 min timer cancelled.")
        #expect(CookTimerRingText.cancelFailed == "Could not cancel the system timer.")
        #expect(CookTimerRingText.startFailed(CookModeSystemTimerSchedulingError.denied, timer: Self.timer) == "Allow system timers in Settings to set this timer.")
        #expect(CookTimerRingLine.resolve(status: "s", error: "e", autoStartError: "a", alarmIsSet: false) == .status("s"))
        #expect(CookTimerRingLine.resolve(status: "s", error: nil, autoStartError: "a", alarmIsSet: true) == nil)
        #expect(CookTimerRingLine.resolve(status: nil, error: nil, autoStartError: "a", alarmIsSet: false) == .error("a"))
        #expect(CookTimerRingLine.resolve(status: nil, error: "e", autoStartError: nil, alarmIsSet: true) == .error("e"))
        #expect(CookTimerRingLine.resolve(status: nil, error: nil, autoStartError: nil, alarmIsSet: false) == nil)
    }

    // MARK: Voice

    @Test func voiceCommandsResolveToTheButtonsActions() throws {
        let first = try model()
        #expect(CookVoiceAction.resolve(.next, viewModel: first) == .turn(forward: true, notice: "On to step 2 of 3"))
        #expect(CookVoiceAction.resolve(.back, viewModel: first) == .notice("This is the first step."))
        #expect(CookVoiceAction.resolve(.repeatStep, viewModel: first) == .read(CookModeSessionResolver.readout(for: first), notice: "Reading step 1 of 3"))
        #expect(CookVoiceAction.resolve(.startTimer, viewModel: first) == .session(.startTimer))
        #expect(CookVoiceAction.resolve(.checkAll, viewModel: first) == .session(.checkStep))
        let last = try model(step: "s3")
        #expect(CookVoiceAction.resolve(.next, viewModel: last) == .notice("This is the last step."))
        #expect(CookVoiceAction.resolve(.back, viewModel: last) == .turn(forward: false, notice: "Back to step 2 of 3"))
        #expect(CookVoiceAction.failureNotice(for: Refused()) == "Could not set the system timer.")
        #expect(CookVoiceAction.failureNotice(for: CookModeSystemTimerSchedulingError.unsupportedPlatform) == CookVoiceNoticeText.actionFailed)
    }

    @Test func voiceOnARecipeWithNoStepsStaysPut() {
        let empty = CookSessionSnapshotTests.recipe(steps: [])
        let model = CookModeViewModel(recipe: empty, progress: .starting(recipe: empty, startedAt: "t"))
        #expect(CookVoiceAction.resolve(.back, viewModel: model) == .notice("This is the first step."))
    }

    /// Progress saved against an older version of the recipe can lack a step the recipe now has; its timer still
    /// starts, read off the progress as it stands.
    @Test func autoStartReadsProgressThatLacksTheStep() throws {
        let older = CookSessionSnapshotTests.recipe(steps: [
            RecipeStep(id: "s1", stepNum: 1, stepTitle: "Chop", description: "Chop onions.", duration: nil,
                       ingredients: [RecipeIngredient(id: "i2", name: "Stock", quantity: 1, unit: "l")]),
        ])
        let start = CookModeProgress.starting(recipe: older, startedAt: "t")
        let checked = try start.togglingIngredient(id: "i2", checked: true, updatedAt: "t")
        let timers = SpoonjoyShell.timersToAutoStart(recipe: Self.recipe, from: start, to: checked, runningStepIDs: [])
        #expect(timers.count <= 1)
    }

    @Test func voiceNoticeFollowsTheMic() {
        #expect(CookVoiceNoticeChange.on(.off) == .clear)
        #expect(CookVoiceNoticeChange.on(.requestingPermission) == .keep)
        #expect(CookVoiceNoticeChange.on(.listening) == .show(CookVoiceNoticeText.listening, persists: false, offersSettings: false))
        #expect(CookVoiceNoticeChange.on(.unavailable(reason: "permission")) == .show("Voice needs the microphone. Allow it in Settings.", persists: true, offersSettings: true))
        #expect(CookVoiceNoticeChange.on(.unavailable(reason: "audio")) == .show("Voice couldn't start. Tap the mic to try again.", persists: false, offersSettings: false))
    }

    @Test func sessionPerformAppliesAndStartsTheTimer() async throws {
        var applied: [CookModeProgress] = []
        let timed = try model(step: "s2")
        let message = try await CookModeSessionResolver.perform(.startTimer, viewModel: timed, updatedAt: "t", apply: { applied.append($0) }, startTimer: { _ in .alreadyRunning(UUID()) })
        #expect(message == CookStepTimerStartOutcome.alreadyRunningMessage)
        #expect(applied.isEmpty)
        let checked = try await CookModeSessionResolver.perform(.checkStep, viewModel: timed, updatedAt: "t", apply: { applied.append($0) }, startTimer: { _ in throw Refused() })
        #expect(checked == "Checked everything for step 2.")
        #expect(applied.last?.checkedIngredientIDs == ["i2"])
    }

    @Test func theVoiceFixtureHearsItsTranscriptsInTurn() async throws {
        let gate = CookVoiceMuteGate()
        let denied = CookVoiceFixtureEngine(fixture: .denied)
        #expect(await denied.prepare { _ in } == .denied)
        let quiet = try await denied.start(gate: gate, heard: { _ in Issue.record("denied heard") }, failed: { _ in })
        quiet.stop()

        let engine = CookVoiceFixtureEngine(fixture: .transcripts(["next", "back"]), spacing: .milliseconds(10))
        #expect(await engine.prepare { _ in } == .ready)
        var heard: [String] = []
        let session = try await engine.start(gate: gate, heard: { heard.append($0) }, failed: { _ in })
        engine.speak("x", gate: gate)
        engine.stopSpeaking()
        for _ in 0..<200 where heard.count < 2 {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(heard == ["next", "back"])
        session.stop()

        let stopped = CookVoiceFixtureEngine(fixture: .transcripts(["next"]), spacing: .milliseconds(50))
        let cancelled = try await stopped.start(gate: gate, heard: { _ in Issue.record("heard after stop") }, failed: { _ in })
        cancelled.stop()
        try await Task.sleep(for: .milliseconds(100))
    }

    // MARK: Controls on a foldable

    @Test func controlsKeepToTheirPages() {
        #expect(CookModeControlPlan.forward(isLastStep: false) == .next)
        #expect(CookModeControlPlan.forward(isLastStep: true) == .finish)
        let spread = CookModeControlPlan.spread(isLastStep: true)
        #expect(spread.leadingPage == [.back, .close])
        #expect(spread.trailingPage == [.markDone, .finish])
        let stacked = CookModeControlPlan.tabletop(isLastStep: false, accessibilityText: true)
        #expect(stacked.stacked == [.next, .markDone, .back])
        #expect(!stacked.usesDock)
        #expect(CookModeControlPlan.tabletop(isLastStep: true, accessibilityText: false).stacked == [.finish])
        #expect(CookModeControlPlan.tabletop(isLastStep: false, accessibilityText: false).stacked.isEmpty)
        #expect(CookModeControlPlan.tabletop(isLastStep: false, accessibilityText: false).usesDock)
        #expect(CookModeControl.allCases.count == 5)
    }

    // MARK: Recipe page

    @Test func recipePageChecksSinkClearAndRestore() {
        var checks = RecipePageChecks()
        #expect(!checks.hasProgress)
        checks.toggleIngredient("i1")
        checks.toggleDependency("d1")
        #expect(checks.hasProgress)
        #expect(checks.snapshot(updatedAt: "t").checkedIngredientIDs == ["i1"])
        checks.toggleIngredient("i1")
        checks.toggleDependency("d1")
        #expect(checks == .cleared)
        #expect(RecipePageChecks(scaleFactor: 2).hasProgress)
        #expect(RecipePageChecks(checkedStepDependencyIDs: ["d"]).hasProgress)

        let saved = RecipePageProgressSnapshot(scaleFactor: 2, checkedIngredientIDs: ["i1", "gone"], checkedStepDependencyIDs: ["d1", "old"], updatedAt: "t")
        let restored = RecipePageChecks(restoring: saved, validIngredientIDs: ["i1"], validDependencyIDs: ["d1"])
        #expect(restored == RecipePageChecks(scaleFactor: 2, checkedIngredientIDs: ["i1"], checkedStepDependencyIDs: ["d1"]))
        #expect(RecipePageChecks(restoring: nil, validIngredientIDs: [], validDependencyIDs: []) == .cleared)
    }

    @Test func theRecipePageStoreRunsOverAnyStorage() {
        var storage: [String: Data] = [:]
        let store = RecipePageProgressStore(read: { storage[$0] }, write: { storage[$1] = $0 })
        store.save(RecipePageChecks(checkedIngredientIDs: ["i1"]).snapshot(updatedAt: "t"), recipeID: "r1")
        #expect(store.snapshot(recipeID: "r1")?.checkedIngredientIDs == ["i1"])
        #expect(storage.keys.contains(RecipePageProgressStore.key(recipeID: "r1")))
    }
}
