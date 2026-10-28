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

/// Lets Siri, Shortcuts and the Live Activity drive the cook-mode screen that is open right now.
/// Cook mode registers while it is on screen, and every command goes through the same view model methods the buttons use.
@MainActor
final class CookModeSessionCenter {
    struct Registration {
        let viewModel: () -> CookModeViewModel
        let apply: (CookModeProgress) -> Void
        /// Returns the outcome, so a second start for a step that already has a timer says so instead of setting another.
        let startTimer: @MainActor (CookModeSystemTimerViewModel) async throws -> CookStepTimerStartOutcome
        /// An auto-start that failed, with the message the step's ring shows.
        var timerStartFailed: @MainActor (_ stepID: String, _ message: String) -> Void = { _, _ in }
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

    private(set) var registration: Registration?

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

    func register(_ registration: Registration) {
        self.registration = registration
        publishSession()
    }

    /// Leaving cook mode stops the commands and ends the session activity. A running step timer belongs to the
    /// system alarm and keeps going, with its own alarm activity.
    func unregister() {
        registration = nil
        activityObserver?.cookSessionEnded()
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
    func checksChanged(from previous: CookModeProgress, to next: CookModeProgress) {
        guard let registration, previous.checkedIngredientIDs != next.checkedIngredientIDs else {
            return
        }
        let recipe = registration.viewModel().recipe
        let checked = Set(next.checkedIngredientIDs)
        let previouslyChecked = Set(previous.checkedIngredientIDs)
        let running = stepTimers.runningStepIDs(forRecipe: recipe.id)
        let timers = recipe.steps.compactMap { step -> CookModeSystemTimerViewModel? in
            guard CookAutoTimerPolicy.shouldAutoStart(
                step: step,
                checkedIngredientIDs: checked,
                previouslyChecked: previouslyChecked,
                runningStepIDs: running
            ) else {
                return nil
            }
            return CookModeViewModel(
                recipe: recipe,
                progress: (try? next.selectingStep(id: step.id, updatedAt: next.updatedAt)) ?? next
            ).systemTimer
        }
        guard !timers.isEmpty else {
            return
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.autoStartDelay)
            // An uncheck during the pause, or leaving cook mode, calls the start off.
            guard let current = self?.registration else {
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

    func perform(_ command: CookModeSessionCommand, updatedAt: String = ISO8601DateFormatter().string(from: Date())) async throws -> String {
        guard let registration else {
            throw CookModeSessionError.notCooking
        }

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
