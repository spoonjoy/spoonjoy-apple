import Combine
import Foundation
import SpoonjoyCore

enum CookModeSessionError: Error, Equatable {
    case notCooking
}

/// Shows the open cook session outside the app. On iOS this is the session Live Activity.
@MainActor
protocol CookSessionActivityObserving: AnyObject {
    /// The step, checklist or timers changed. `finished` is true once the last step is marked done.
    func cookSessionChanged(_ snapshot: CookSessionSnapshot, deepLink: URL, finished: Bool)
    /// Cook mode closed.
    func cookSessionEnded()
}

/// Lets Siri, Shortcuts and the Live Activity drive cook mode. Each window's cook-mode screen registers while it is
/// on screen; Siri, the Live Activity and the session activity follow the one the cook used last
/// (`CookSessionRegistry`), and every command goes through the same view model methods the buttons use. A screen's
/// own voice commands and automatic timer starts go through its own registration.
@MainActor
final class CookModeSessionCenter {
    struct Registration {
        let viewModel: () -> CookModeViewModel
        let apply: (CookModeProgress) -> Void
        /// Returns the outcome, so a second start for a step that already has a timer says so instead of setting another.
        let startTimer: @MainActor (CookModeSystemTimerViewModel) async throws -> CookStepTimerStartOutcome
        /// An auto-start that failed, with the message the step's ring shows.
        var timerStartFailed: @MainActor (_ stepID: String, _ message: String) -> Void = { _, _ in }
        /// Turns the mic back on when this screen replaced one that had it on (a fold, a rotation, a resize).
        var resumeVoice: @MainActor () -> Void = {}
        /// Turns the mic off because another window's mic came on: one live mic at a time.
        var stopVoice: @MainActor () -> Void = {}
    }

    static let shared = CookModeSessionCenter()

    private static let stepTimersDefaultsKey = "cookMode.stepTimerAlarms"
    private static let timerClockDefaultsKey = "cookMode.stepTimerClock"

    /// The system alarm per step. It outlives cook mode because a step timer keeps running after the cook leaves.
    let stepTimers = CookStepTimerRegistry(
        persisted: UserDefaults.standard.dictionary(forKey: CookModeSessionCenter.stepTimersDefaultsKey) as? [String: String] ?? [:],
        persist: { UserDefaults.standard.set($0, forKey: CookModeSessionCenter.stepTimersDefaultsKey) }
    )

    /// Journeys run on a simulator that refuses AlarmKit, so they ask for a stand-in alarm (DEBUG builds only).
    static var usesJourneyAlarmFixture: Bool {
#if DEBUG
        NativeJourneyAlarmFixture.isRequested(environment: ProcessInfo.processInfo.environment)
#else
        false
#endif
    }

    /// Each running alarm's end date, length and pause state, which the registry does not keep. It outlives cook
    /// mode with the alarms, so a reopened session still shows how long each timer has left.
    private(set) var timerClock: CookTimerClock = {
        guard let data = UserDefaults.standard.data(forKey: CookModeSessionCenter.timerClockDefaultsKey),
              let clock = try? JSONDecoder().decode(CookTimerClock.self, from: data) else {
            return CookTimerClock()
        }
        return clock
    }()

    weak var activityObserver: CookSessionActivityObserving? {
        didSet { publishSession() }
    }

    private var stepTimersSubscription: AnyCancellable?

    private var screens = CookSessionRegistry<Registration>()

    /// The registration Siri, the Live Activity and the session activity act on: the screen the cook used last.
    var registration: Registration? {
        screens.ownerEntry
    }

    private init() {
        // The registry publishes before it stores, so the published value is the one to draw.
        stepTimersSubscription = stepTimers.$alarmIDsByStep
            .dropFirst()
            .sink { [weak self] alarmIDsByStep in
                MainActor.assumeIsolated {
                    self?.publishSession(alarmIDsByStep: alarmIDsByStep)
                }
            }
    }

    var isCooking: Bool {
        registration != nil
    }

    /// `token` names the cook-mode screen. Registering makes it the screen the session follows.
    func register(token: UUID, isActive: Bool, _ registration: Registration) {
        let recipeID = registration.viewModel().recipe.id
        let registered = screens.register(token, recipeID: recipeID, entry: registration, at: Date().timeIntervalSinceReferenceDate, isActive: isActive)
        publishSession()
        if registered.resumesVoice {
            registration.resumeVoice()
        }
    }

    /// The cook used this screen: its progress changed here, or it was spoken to. The session follows it.
    func use(token: UUID) {
        if screens.use(token) {
            publishSession()
        }
    }

    /// How long to let every window report its new scene phase before deciding whether one came forward alone.
    static let sceneSettleDelay: Duration = .milliseconds(300)

    /// The screen's window became active. It takes the session only if it is the one cook window active once the
    /// phases settle: in Split View both windows come back together after unlocking, Control Center or an alert.
    func sceneBecameActive(token: UUID) {
        screens.sceneActive(token, true)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.sceneSettleDelay)
            guard let self, self.screens.claimIfOnlyActive(token) else {
                return
            }
            self.publishSession()
        }
    }

    func sceneLeftActive(token: UUID) {
        screens.sceneActive(token, false)
    }

    /// This screen's mic came on, so every other window's mic goes off.
    func voiceTurnedOn(token: UUID) {
        for other in screens.entries(except: token) {
            other.stopVoice()
        }
    }

    /// Leaving cook mode. When another window is still cooking, the session passes to it; when none is, the session
    /// activity ends. A running step timer belongs to the system alarm and keeps going, with its own alarm activity.
    /// A screen rebuilt mid-cook gets the session's place and the mic back, whichever of the two screens SwiftUI shows
    /// first; while the owner's replacement may still appear, the activity waits instead of switching recipes.
    func unregister(token: UUID, voiceOn: Bool) {
        let left = screens.unregister(token, voiceOn: voiceOn, at: Date().timeIntervalSinceReferenceDate)
        left.resumeVoiceIn?.resumeVoice()
        if left.sessionEnded {
            activityObserver?.cookSessionEnded()
        } else if left.awaitsReplacement {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(CookSessionRegistry<Registration>.rebuildWindow))
                self?.publishSession()
            }
        } else if left.ownerChanged {
            publishSession()
        }
    }

    func updateTimerClock(_ change: (inout CookTimerClock) -> Void) {
        var clock = timerClock
        change(&clock)
        guard clock != timerClock else {
            return
        }
        timerClock = clock
        if let data = try? JSONEncoder().encode(clock) {
            UserDefaults.standard.set(data, forKey: Self.timerClockDefaultsKey)
        }
        publishSession()
    }

    /// Sends the open session to the activity observer. `progress` is passed when it may not have reached the view
    /// yet, such as a Live Activity button handled in the background.
    func publishSession(progress: CookModeProgress? = nil, alarmIDsByStep: [String: UUID]? = nil) {
        guard let activityObserver, let registration else {
            return
        }
        let viewModel = registration.viewModel()
        let recipe = viewModel.recipe
        let current = progress ?? viewModel.progress
        let board = timerClock.board(recipe: recipe, alarmIDsByStep: alarmIDsByStep ?? stepTimers.alarmIDsByStep)
        activityObserver.cookSessionChanged(
            CookSessionSnapshot.make(recipe: recipe, progress: current, board: board),
            deepLink: DeepLinkURLBuilder.url(for: .recipeDetail(id: recipe.id, presentation: .cook)),
            finished: CookSessionSnapshot.isFinished(recipe: recipe, progress: current)
        )
    }

    /// A pause between the last check and the timer starting, so the ring sweeps in after the tick lands.
    static let autoStartDelay: Duration = .milliseconds(250)

    /// Called on every change to the open session's checks. When a check completes a step's ingredients and the step
    /// has a duration and no running timer (`CookAutoTimerPolicy`), the step's timer starts through the same path the
    /// ring uses, so it is still one alarm per step. Progress that arrives from another device does not come here.
    func checksChanged(token: UUID, from previous: CookModeProgress, to next: CookModeProgress) {
        guard let registration = screens.entry(for: token), previous.checkedIngredientIDs != next.checkedIngredientIDs else {
            return
        }
        let recipe = registration.viewModel().recipe
        let timers = SpoonjoyShell.timersToAutoStart(
            recipe: recipe,
            from: previous,
            to: next,
            runningStepIDs: stepTimers.runningStepIDs(forRecipe: recipe.id)
        )
        guard !timers.isEmpty else {
            return
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.autoStartDelay)
            // An uncheck during the pause, or leaving cook mode, calls the start off.
            guard let current = self?.screens.entry(for: token) else {
                return
            }
            let stillChecked = Set(current.viewModel().progress.checkedIngredientIDs)
            for timer in CookAutoTimerPolicy.timersStillToStart(timers, steps: recipe.steps, stillChecked: stillChecked) {
                do {
                    _ = try await current.startTimer(timer)
                } catch {
                    current.timerStartFailed(timer.stepID, CookAutoTimerPolicy.startFailureMessage(for: error, timer: timer))
                }
            }
        }
    }

    /// The step on screen, for the annotated on-screen entity.
    func onScreenStep() -> CookModeOnScreenStep? {
        registration?.viewModel().onScreenStep
    }

    /// Siri, Shortcuts and the Live Activity: the screen the cook used last.
    func perform(_ command: CookModeSessionCommand, updatedAt: String = ISO8601DateFormatter().string(from: Date())) async throws -> String {
        guard let registration else {
            throw CookModeSessionError.notCooking
        }
        return try await perform(command, on: registration, updatedAt: updatedAt)
    }

    /// A screen's own voice commands act on that screen's recipe, whichever window owns the session.
    func perform(_ command: CookModeSessionCommand, token: UUID) async throws -> String {
        guard let registration = screens.entry(for: token) else {
            throw CookModeSessionError.notCooking
        }
        // Speaking to this window is using it, so the session follows it.
        use(token: token)
        return try await perform(command, on: registration, updatedAt: ISO8601DateFormatter().string(from: Date()))
    }

    private func perform(_ command: CookModeSessionCommand, on registration: Registration, updatedAt: String) async throws -> String {
        let outcome = CookModeSessionResolver.resolve(command, viewModel: registration.viewModel(), updatedAt: updatedAt)
        if outcome.progress != registration.viewModel().progress {
            registration.apply(outcome.progress)
            publishSession(progress: outcome.progress)
        }
        if let timer = outcome.timerToStart {
            return try await registration.startTimer(timer).message(startedMessage: outcome.message)
        }
        return outcome.message
    }
}

struct CookModeOnScreenStep: Equatable {
    let recipeID: String
    let recipeTitle: String
    let stepID: String
    let stepNumber: Int
    let stepTitle: String

    var entityID: String {
        "\(recipeID)#\(stepID)"
    }
}

extension CookModeViewModel {
    var onScreenStep: CookModeOnScreenStep? {
        guard let step = activeStep else {
            return nil
        }
        return CookModeOnScreenStep(recipeID: recipe.id, recipeTitle: recipe.title, stepID: step.id, stepNumber: step.stepNum, stepTitle: step.stepTitle ?? "Step \(step.stepNum)")
    }
}
