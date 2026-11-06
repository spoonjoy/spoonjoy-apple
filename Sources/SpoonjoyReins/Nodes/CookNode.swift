import Combine
import Foundation
import OuroReins
import SpoonjoyCore

struct IngredientCheck: ReinsInput {
    let id: String
    let checked: Bool
}

struct CookSwipe: ReinsInput {
    /// `next` or `previous`.
    let direction: String
    /// Where the finger starts: an ingredient row's id, `ring`, or the page itself when nil.
    let from: String?
}

struct CookScale: ReinsInput {
    let factor: Double
}

/// What CookModeView keeps in `@State` and CookModeSessionCenter keeps for the app, for the cook-mode screen Reins shows:
/// the step timers (one alarm per step, `CookStepTimerRegistry`, with end dates on `CookTimerClock`), the mic
/// (`CookVoiceController` over the voice fixture), the voice line, each ring's line, the pager's touch and the cover
/// glance. Timers and their clock are kept in the kitchen folder, as the app keeps them in its defaults, so they survive
/// a relaunch; everything else is screen state and starts fresh.
@MainActor
final class SpoonjoyReinsCook {
    private unowned let shell: SpoonjoyReinsShell
    let registry: CookStepTimerRegistry
    private(set) var clock: CookTimerClock
    /// Each alarm set through the recording fixture, by step key, so a journey can see no step got two.
    private(set) var scheduledAlarms: [String] = []

    private(set) var voice: CookVoiceController?
    /// When the mic hears its next phrase (`SpoonjoyReinsShell.hearNextPhrase()`).
    let voicePacer = SpoonjoyReinsVoicePacer()
    private var voiceSubscription: AnyCancellable?
    private(set) var voiceNotice: (text: String, offersSettings: Bool)?
    /// The URLs cook mode asked the system to open (the mic's Settings button).
    private(set) var openedURLs: [String] = []
    /// The app left the foreground (Home) and has not come back.
    private(set) var inBackground = false
    /// An automatic start that failed, by step, as the ring shows it.
    private(set) var autoStartErrors: [String: String] = [:]
    /// Work cook mode started and hasn't finished: an auto-start's pause, a voice command's timer. `settle()` waits for it,
    /// so a journey checks what happened after it, not after a guess at how long it takes.
    private var pending: [Task<Void, Never>] = []

    /// Waits until every auto-start and voice command started so far has finished, however loaded the machine is.
    func settle() async {
        while !pending.isEmpty {
            let running = pending
            pending.removeAll()
            for task in running { await task.value }
        }
    }
    /// Each ring's own line, by step: the message from a tap on it or from Cancel.
    private(set) var ringStatus: [String: String] = [:]
    private(set) var ringError: [String: String] = [:]
    /// The pager's current touch (`CookPageTurnTapGuard`).
    private var touch = CookPageTouch()
    private(set) var showsCoverGlance = false

    init(shell: SpoonjoyReinsShell) {
        self.shell = shell
        let saved = Self.load(from: shell.kitchenDirectory)
        clock = saved.clock
        registry = CookStepTimerRegistry(persisted: saved.alarms)
        // The registry publishes before it stores, so the published value is the one to save.
        timersSubscription = registry.$alarmIDsByStep.dropFirst().sink { [weak self] alarms in
            MainActor.assumeIsolated { self?.save(alarms: alarms.mapValues(\.uuidString)) }
        }
    }

    private var timersSubscription: AnyCancellable?

    var display: SpoonjoyReinsDisplay { shell.fixtures.cook.display }
    private var now: Date { shell.fixtures.now() }

    var alarms: CookStepAlarms {
        switch shell.fixtures.cook.alarms {
        case .recording:
            let standIn = CookStepAlarms.journeyStandIn
            return CookStepAlarms(schedule: { [unowned self] timer, recipe, step in
                let id = try await standIn.schedule(timer, recipe, step)
                scheduledAlarms.append(CookStepTimerRegistry.stepKey(recipeID: recipe.id, stepID: step.id))
                return id
            }, cancel: standIn.cancel)
        case .denied:
            return CookStepAlarms(schedule: { _, _, _ in
                try await CookModeSystemTimerScheduler.schedule(using: CookModeSystemTimerSchedulingClient(
                    authorizationState: { .denied },
                    requestAuthorization: { .denied },
                    schedule: {}
                ))
                return UUID()
            }, cancel: { _ in })
        }
    }

    // MARK: Opening and closing (CookModeView's onAppear and onDisappear)

    /// Cook mode appeared: it opens at the recipe page's scale, the mic starts off, and a foldable launched folded
    /// shut shows the cover glance.
    func opened(_ recipeID: String) {
        voice?.send(.cookModeClosed)
        let pacer = voicePacer
        let engine = CookVoiceFixtureEngine(fixture: shell.fixtures.cook.voice ?? .transcripts([]), pace: { await pacer.next() })
        let voice = CookVoiceController(engine: engine)
        voice.onCommand = { [unowned self] command in perform(voiceCommand: command, recipeID: recipeID) }
        voiceSubscription = voice.$state.dropFirst().removeDuplicates().sink { [unowned self] state in
            MainActor.assumeIsolated { voiceStateChanged(state) }
        }
        self.voice = voice
        voiceNotice = nil
        autoStartErrors = [:]
        ringStatus = [:]
        ringError = [:]
        showsCoverGlance = TabletopLayout.posture(hingeStatus: display.hinge, angleDegrees: nil) == .closedGlance
        guard let recipe = shell.content.recipe(id: recipeID) else {
            return
        }
        let progress = shell.cookProgress(for: recipe)
        let scale = shell.recipePageProgress.scaleFactor(recipeID: recipeID)
        let opened = progress.openingAtRecipePageScale(scale, updatedAt: shell.timestamp())
        if opened != progress {
            update(recipe, from: progress, to: opened)
        }
    }

    func closed(_ recipeID: String) {
        voice?.send(.cookModeClosed)
        voiceSubscription = nil
        voice = nil
    }

    // MARK: Progress (CookModeView.updateProgress)

    func model(_ recipe: Recipe) -> CookModeViewModel {
        CookModeViewModel(recipe: recipe, progress: shell.cookProgress(for: recipe))
    }

    /// Every change made on this screen comes through here, as in the view: the store records it, and checks that
    /// complete a step start its timer after the pause.
    func update(_ recipe: Recipe, from previous: CookModeProgress, to next: CookModeProgress) {
        shell.store.recordCookProgress(next)
        let timers = SpoonjoyShell.timersToAutoStart(recipe: recipe, from: previous, to: next, runningStepIDs: registry.runningStepIDs(forRecipe: recipe.id))
        guard !timers.isEmpty else {
            return
        }
        pending.append(Task { @MainActor [weak self] in
            try? await Task.sleep(for: CookStepTimers.autoStartDelay)
            guard let self, self.voice != nil else {
                return
            }
            await CookStepTimers.autoStart(
                timers,
                steps: recipe.steps,
                stillChecked: Set(self.shell.cookProgress(for: recipe).checkedIngredientIDs),
                start: { try await self.start($0, recipe: recipe) },
                failed: { self.autoStartErrors[$0] = $1 }
            )
        })
    }

    func update(_ recipe: Recipe, _ change: (CookModeViewModel) throws -> CookModeProgress) rethrows {
        let model = model(recipe)
        update(recipe, from: model.progress, to: try change(model))
    }

    // MARK: Timers

    func start(_ timer: CookModeSystemTimerViewModel, recipe: Recipe) async throws -> CookStepTimerStartOutcome {
        guard let step = recipe.steps.first(where: { $0.id == timer.stepID }) else {
            throw CookModeSessionError.notCooking
        }
        return try await CookStepTimers.start(timer, recipe: recipe, step: step, registry: registry, alarms: alarms, now: { shell.fixtures.now() }) { change in
            change(&clock)
            save(alarms: registry.alarmIDsByStep.mapValues(\.uuidString))
        }
    }

    /// A tap on the ring (`CookModeSystemTimer.scheduleTimer`).
    func tapRing(_ timer: CookModeSystemTimerViewModel, recipe: Recipe) async {
        guard tap() else { return }
        autoStartErrors[timer.stepID] = nil
        ringStatus[timer.stepID] = nil
        ringError[timer.stepID] = nil
        do {
            ringStatus[timer.stepID] = try await start(timer, recipe: recipe).message(startedMessage: CookTimerRingText.started(timer))
        } catch {
            ringError[timer.stepID] = CookTimerRingText.startFailed(error, timer: timer)
        }
    }

    /// The ring's Cancel (`CookModeSystemTimer.cancelTimer`).
    func cancelRing(_ timer: CookModeSystemTimerViewModel, recipe: Recipe, step: RecipeStep) {
        guard tap() else { return }
        ringStatus[timer.stepID] = nil
        ringError[timer.stepID] = nil
        do {
            try CookStepTimers.cancel(recipe: recipe, step: step, registry: registry, alarms: alarms)
            clock.retain(activeAlarmIDs: Set(registry.alarmIDsByStep.values))
            save(alarms: registry.alarmIDsByStep.mapValues(\.uuidString))
            ringStatus[timer.stepID] = CookTimerRingText.cancelled(timer)
        } catch {
            ringError[timer.stepID] = CookTimerRingText.cancelFailed
        }
    }

    func entry(recipe: Recipe, step: RecipeStep) -> CookTimerEntry? {
        let key = CookStepTimerRegistry.stepKey(recipeID: recipe.id, stepID: step.id)
        return clock.board(recipe: recipe, alarmIDsByStep: registry.alarmIDsByStep).ordered.first { $0.id == key }
    }

    // MARK: The pager's touch (CookPageTurnTapGuard)

    /// A tap is a new touch that never moves, at a spot of its own.
    private func tap() -> Bool {
        touch.moved(startX: 1, startY: 1, dx: 0, dy: 0)
        let allowed = touch.allowsTap(at: now)
        touch.ended(at: now)
        return allowed
    }

    /// A swipe across the page that starts on `from`. The page turns by `CookPageTurn`, and then the lift reaches the
    /// control under the finger, as it does in the app before the pager hears of it: `CookPageTouch` says the touch was
    /// a drag, so the row is not checked and the ring does not start.
    func swipe(_ recipe: Recipe, forward: Bool, from control: String?) async throws {
        let pageWidth = 320.0
        let dx = forward ? -pageWidth / 2 : pageWidth / 2
        touch.moved(startX: 200, startY: 400, dx: dx, dy: 0)
        let model = model(recipe)
        let index = model.activeStep.flatMap { step in recipe.steps.firstIndex { $0.id == step.id } } ?? 0
        let target = CookPageTurn.target(from: index, count: recipe.steps.count, dragFraction: dx / pageWidth, velocity: 0)
        if target != index {
            update(recipe, from: model.progress, to: (try? model.progress.selectingStep(id: recipe.steps[target].id, updatedAt: shell.timestamp())) ?? model.progress)
        }
        if let control, touch.allowsTap(at: now) {
            if control == "ring", let timer = model.systemTimer {
                touch.ended(at: now)
                await tapRing(timer, recipe: recipe)
                return
            }
            if let row = model.ingredientChecklistRows.first(where: { $0.id == control }) {
                try update(recipe) { try SpoonjoyShell.checkIngredient($0, id: row.id, checked: !row.isChecked, updatedAt: shell.timestamp()) }
            }
        }
        touch.ended(at: now)
    }

    // MARK: Voice (CookModeView's voice extension)

    private func voiceStateChanged(_ state: CookVoiceListenerState) {
        switch CookVoiceNoticeChange.on(state) {
        case .clear:
            voiceNotice = nil
        case .keep:
            break
        case .show(let text, _, let offersSettings):
            showVoiceNotice(text, offersSettings: offersSettings)
        }
    }

    private func showVoiceNotice(_ text: String, offersSettings: Bool = false) {
        voiceNotice = (text, offersSettings)
        voice?.announced(text, spokenAloud: false)
    }

    func perform(voiceCommand command: CookVoiceCommand, recipeID: String) {
        guard let recipe = shell.content.recipe(id: recipeID) else {
            return
        }
        let model = model(recipe)
        switch CookVoiceAction.resolve(command, viewModel: model) {
        case .turn(let forward, let notice):
            update(recipe) { SpoonjoyShell.turnCookPage($0, forward: forward, updatedAt: shell.timestamp()) }
            showVoiceNotice(notice)
        case .notice(let notice):
            showVoiceNotice(notice)
        case .read(let text, let notice):
            voice?.read(text)
            showVoiceNotice(notice)
        case .session(let sessionCommand):
            pending.append(Task { @MainActor in
                do {
                    showVoiceNotice(try await CookModeSessionResolver.perform(
                        sessionCommand,
                        viewModel: model,
                        updatedAt: shell.timestamp(),
                        apply: { self.update(recipe, from: model.progress, to: $0) },
                        startTimer: { try await self.start($0, recipe: recipe) }
                    ))
                } catch {
                    showVoiceNotice(CookVoiceAction.failureNotice(for: error))
                }
            })
        }
    }

    func toggleMic() {
        voice?.toggle()
    }

    func openSettings() {
        openedURLs.append("app-settings:")
    }

    /// Home: the scene goes to the background, which turns the mic off.
    func leaveApp() {
        inBackground = true
        voice?.send(.sceneBackground)
    }

    func returnToApp() {
        inBackground = false
        voice?.send(.sceneActive)
    }

    func showStep() {
        showsCoverGlance = false
    }

    // MARK: Saved timers

    private struct Saved: Codable {
        var alarms: [String: String] = [:]
        var clock = CookTimerClock()
    }

    private static func file(in directory: URL?) -> URL? {
        directory?.appendingPathComponent("native-cook-timers.json")
    }

    private static func load(from directory: URL?) -> Saved {
        guard let url = file(in: directory), let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Saved.self, from: data) else {
            return Saved()
        }
        return saved
    }

    private func save(alarms: [String: String]) {
        guard let url = Self.file(in: shell.kitchenDirectory) else {
            return
        }
        try? JSONEncoder().encode(Saved(alarms: alarms, clock: clock)).write(to: url, options: .atomic)
    }
}

enum CookModeSessionError: Error {
    case notCooking
}

extension SpoonjoyReinsShell {
    /// CookModeView's `advance()` and `previous()`: SpoonjoyShell's page turn, through the view's `updateProgress`.
    func turn(_ recipe: Recipe, forward: Bool) {
        cook.update(recipe) { SpoonjoyShell.turnCookPage($0, forward: forward, updatedAt: timestamp()) }
    }

    /// An ingredient row's checkbox binding: a tap, which `CookPageTouch` lets through.
    func check(_ recipe: Recipe, ingredient id: String, checked: Bool) throws {
        try cook.update(recipe) { try SpoonjoyShell.checkIngredient($0, id: id, checked: checked, updatedAt: timestamp()) }
    }

    func cookNode(_ recipe: Recipe) -> ReinsNode {
        let model = cook.model(recipe)
        let index = model.activeStep.flatMap { step in recipe.steps.firstIndex { $0.id == step.id } } ?? 0
        let isLastStep = index == recipe.steps.count - 1
        if cook.inBackground {
            return ReinsNode("cook", state: ["recipe": .string(recipe.id), "app": "background"], actions: [
                ReinsAction("returnToApp", "Open Spoonjoy again") { [unowned self] in self.cook.returnToApp() },
            ])
        }
        var actions: [ReinsAction] = []
        if index < recipe.steps.count - 1 {
            actions.append(ReinsAction("nextStep", "Turn to the next step") { [unowned self] in self.turn(recipe, forward: true) })
        }
        if index > 0 {
            actions.append(ReinsAction("previousStep", "Turn back a step") { [unowned self] in self.turn(recipe, forward: false) })
        }
        let rows = model.ingredientChecklistRows
        if !rows.isEmpty {
            actions.append(ReinsAction("checkIngredient", "Check or uncheck an ingredient on this step", input: IngredientCheck.self) { [unowned self] in
                try self.check(recipe, ingredient: $0.id, checked: $0.checked)
            }.narrowed(.object(properties: ["id": .oneOf(rows.map(\.id)), "checked": .boolean], required: ["id", "checked"])))
        }
        let swipeStarts = rows.map(\.id) + (model.systemTimer == nil ? [] : ["ring"])
        var swipeInput: [String: ReinsSchema] = ["direction": .oneOf(["next", "previous"])]
        if !swipeStarts.isEmpty {
            swipeInput["from"] = .oneOf(swipeStarts)
        }
        actions.append(ReinsAction("swipe", "Swipe the page to turn it, starting on a row, the ring or the page", input: CookSwipe.self) { [unowned self] in
            try await self.cook.swipe(recipe, forward: $0.direction == "next", from: $0.from)
        }.narrowed(.object(properties: swipeInput, required: ["direction"])))
        actions.append(ReinsAction("markStepDone", "Mark the current step done") { [unowned self] in
            guard let step = model.activeStep else { return }
            self.cook.update(recipe) { (try? $0.progress.markingStepCompleted(step.id, updatedAt: self.timestamp())) ?? $0.progress }
        })
        actions.append(ReinsAction("setScale", "Scale the recipe from the More menu", input: CookScale.self) { [unowned self] in
            let factor = $0.factor
            self.cook.update(recipe) { $0.progress.settingScaleFactor(factor, updatedAt: self.timestamp()) }
        })
        actions.append(ReinsAction("toggleMic", "Turn the hands-free mic on or off") { [unowned self] in self.cook.toggleMic() })
        if cook.voiceNotice?.offersSettings == true {
            actions.append(ReinsAction("openVoiceSettings", "Open Settings to allow the microphone") { [unowned self] in self.cook.openSettings() })
        }
        actions.append(ReinsAction("leaveApp", "Go to the Home Screen") { [unowned self] in self.cook.leaveApp() })
        if cook.showsCoverGlance {
            actions.append(ReinsAction("showStep", "Show the whole step") { [unowned self] in self.cook.showStep() })
        }
        var ring: ReinsValue = .null
        if let timer = model.systemTimer, let step = model.activeStep {
            let entry = cook.entry(recipe: recipe, step: step)
            let running = cook.registry.alarmID(forStep: CookStepTimerRegistry.stepKey(recipeID: recipe.id, stepID: step.id)) != nil
            if running {
                actions.append(ReinsAction("cancelTimer", "Cancel the step's timer") { [unowned self] in self.cook.cancelRing(timer, recipe: recipe, step: step) })
            } else {
                actions.append(ReinsAction("startTimer", "Tap the ring to start the step's timer") { [unowned self] in await self.cook.tapRing(timer, recipe: recipe) })
            }
            var line: ReinsValue = .null
            switch CookTimerRingLine.resolve(status: cook.ringStatus[step.id], error: cook.ringError[step.id], autoStartError: cook.autoStartErrors[step.id], alarmIsSet: running) {
            case .status(let text): line = ["status": .string(text)]
            case .error(let text): line = ["error": .string(text)]
            case nil: break
            }
            ring = [
                "duration": .string(timer.durationLabel),
                "running": .bool(running),
                "cancel": .bool(running),
                "endsAt": entry.map { .string(ISO8601DateFormatter().string(from: $0.endsAt)) } ?? .null,
                "secondsLeft": entry.map { .number(max(0, $0.endsAt.timeIntervalSince(fixtures.now()).rounded())) } ?? .null,
                "line": line,
            ]
        }
        let voiceState = cook.voice?.state ?? .off
        return ReinsNode("cook", state: [
            "recipe": .string(recipe.id),
            "title": .string(recipe.title),
            "step": .string(model.stepProgressLabel),
            "stepTitle": model.activeStep?.stepTitle.map(ReinsValue.string) ?? .null,
            "stepText": model.activeStep.map { .string($0.description) } ?? .null,
            "page": .string(model.currentPageProgressLabel),
            "ingredients": .array(rows.map { ["id": .string($0.id), "title": .string($0.title), "quantity": .string($0.quantityText), "checked": .bool($0.isChecked)] }),
            "timer": model.systemTimer.map { .string($0.durationLabel) } ?? .null,
            "ring": ring,
            "runningTimers": .number(Double(cook.registry.runningStepIDs(forRecipe: recipe.id).count)),
            "more": ["Scale", "Add to list"],
            "scale": .number(model.progress.scaleFactor),
            "mic": ["label": .string(CookVoiceNoticeText.micLabel(for: voiceState, preparing: cook.voice?.isPreparing ?? false)), "listening": .bool(voiceState.isMicLive)],
            "voiceNotice": cook.voiceNotice.map { ["text": .string($0.text), "settings": .bool($0.offersSettings)] } ?? .null,
            "layout": cookLayout(isLastStep: isLastStep),
        ], actions: actions)
    }

    /// Where cook mode puts the step and its controls on this screen, from the same rules the view lays out with:
    /// `TabletopLayout` and `BookSpreadLayout` pick the surface, and `CookModeControlPlan` puts the controls.
    private func cookLayout(isLastStep: Bool) -> ReinsValue {
        let display = cook.display
        func row(_ row: TabletopRow?) -> ReinsValue {
            row.map { ["minY": .number($0.minY), "height": .number($0.height)] } ?? .null
        }
        func names(_ controls: [CookModeControl]) -> ReinsValue {
            .array(controls.map { .string($0.rawValue) })
        }
        if cook.showsCoverGlance {
            return ["surface": "coverGlance", "controls": names([CookModeControlPlan.forward(isLastStep: isLastStep)]), "showStep": true]
        }
        let tabletop = TabletopLayout.resolve(width: display.width, height: display.height, hinge: display.hinge)
        if tabletop.isSplit {
            let plan = CookModeControlPlan.tabletop(isLastStep: isLastStep, accessibilityText: display.accessibilityText)
            return [
                "surface": "tabletop",
                "top": row(tabletop.top), "fold": row(tabletop.fold), "bottom": row(tabletop.bottom),
                "stepHalf": ["step", "ring"],
                "controlsHalf": .array(["checklist"] + (plan.usesDock ? ["dock"] : []) + plan.stacked.map { .string($0.rawValue) }),
            ]
        }
        if display.isRegularWidth {
            let spread = BookSpreadLayout.resolve(width: display.width, height: display.height, isRegularWidth: true)
            if let leading = spread.leadingPage, let trailing = spread.trailingPage {
                let plan = CookModeControlPlan.spread(isLastStep: isLastStep)
                return [
                    "surface": "spread",
                    "leadingPage": ["minX": .number(leading.minX), "maxX": .number(leading.maxX), "controls": names(plan.leadingPage)],
                    "trailingPage": ["minX": .number(trailing.minX), "maxX": .number(trailing.maxX), "controls": names(plan.trailingPage)],
                    "turn": display.reduceMotion ? "crossfade" : "curl",
                ]
            }
            return ["surface": "pager", "dock": true]
        }
        return ["surface": "pager", "dock": false, "turn": display.reduceMotion ? "crossfade" : "slide"]
    }
}
