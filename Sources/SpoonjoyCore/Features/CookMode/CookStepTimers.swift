import Foundation

/// How a step's system alarm is set and cancelled: AlarmKit in the app, a stand-in on a journey's simulator
/// (`NativeJourneyAlarmFixture`) and in a headless journey.
@MainActor
public struct CookStepAlarms {
    /// Sets the alarm for a step and returns its ID.
    public let schedule: @MainActor (CookModeSystemTimerViewModel, Recipe, RecipeStep) async throws -> UUID
    /// Ends an alarm.
    public let cancel: @MainActor (UUID) throws -> Void

    public init(
        schedule: @escaping @MainActor (CookModeSystemTimerViewModel, Recipe, RecipeStep) async throws -> UUID,
        cancel: @escaping @MainActor (UUID) throws -> Void
    ) {
        self.schedule = schedule
        self.cancel = cancel
    }

    /// The stand-in a journey asks for: each start records a new alarm ID, and Cancel forgets it. The step's registry,
    /// its ring and Cancel run unchanged.
    public static var journeyStandIn: CookStepAlarms {
        CookStepAlarms(schedule: { _, _, _ in UUID() }, cancel: { _ in })
    }
}

/// Starting and cancelling a step's timer, as the ring, an automatic start, Siri and the Live Activity all do it: one
/// alarm per step (`CookStepTimerRegistry`), with its end date recorded on the timer clock.
public enum CookStepTimers {
    /// Sets the step's alarm unless one already runs for it, so a second tap or a Siri request never sets a second one.
    /// `updateClock` records the new alarm's end date, read from `now` once the alarm is set.
    @MainActor
    public static func start(
        _ timer: CookModeSystemTimerViewModel,
        recipe: Recipe,
        step: RecipeStep,
        registry: CookStepTimerRegistry,
        alarms: CookStepAlarms,
        now: () -> Date,
        updateClock: (_ change: (inout CookTimerClock) -> Void) -> Void
    ) async throws -> CookStepTimerStartOutcome {
        try await registry.start(step: CookStepTimerRegistry.stepKey(recipeID: recipe.id, stepID: step.id)) {
            let alarmID = try await alarms.schedule(timer, recipe, step)
            let startedAt = now()
            updateClock { $0.start(alarmID: alarmID, duration: TimeInterval(timer.durationSeconds), now: startedAt) }
            return alarmID
        }
    }

    /// Cancels the step's alarm. Returns false when the step has no timer.
    @MainActor
    @discardableResult
    public static func cancel(recipe: Recipe, step: RecipeStep, registry: CookStepTimerRegistry, alarms: CookStepAlarms) throws -> Bool {
        try registry.cancel(step: CookStepTimerRegistry.stepKey(recipeID: recipe.id, stepID: step.id), cancelAlarm: alarms.cancel)
    }

    /// The pause between the last check and an automatic start, so the ring sweeps in after the tick lands.
    public static let autoStartDelay: Duration = .milliseconds(250)

    /// The end of an automatic start, once the pause is over: each timer whose step is still fully checked starts
    /// through `start`, the path the ring uses, and a failure is reported with the message the step's ring shows.
    @MainActor
    public static func autoStart(
        _ timers: [CookModeSystemTimerViewModel],
        steps: [RecipeStep],
        stillChecked: Set<String>,
        start: @MainActor (CookModeSystemTimerViewModel) async throws -> CookStepTimerStartOutcome,
        failed: @MainActor (_ stepID: String, _ message: String) -> Void
    ) async {
        for timer in CookAutoTimerPolicy.timersStillToStart(timers, steps: steps, stillChecked: stillChecked) {
            do {
                _ = try await start(timer)
            } catch {
                failed(timer.stepID, CookAutoTimerPolicy.startFailureMessage(for: error, timer: timer))
            }
        }
    }
}

/// The words a step's timer ring shows under itself.
public enum CookTimerRingText {
    public static let cancelFailed = "Could not cancel the system timer."

    public static func started(_ timer: CookModeSystemTimerViewModel) -> String {
        "\(timer.durationLabel) timer started."
    }

    public static func cancelled(_ timer: CookModeSystemTimerViewModel) -> String {
        "\(timer.durationLabel) timer cancelled."
    }

    /// The message a failed tap on the ring shows.
    public static func startFailed(_ error: Error, timer: CookModeSystemTimerViewModel) -> String {
        CookModeSystemTimerScheduler.message(for: error, fallback: timer.systemUnavailableMessage)
    }
}

/// The one line under a step's timer ring, if any.
public enum CookTimerRingLine: Equatable, Sendable {
    case status(String)
    case error(String)

    /// While the step's alarm runs the ring is the status, so the message from setting it is not repeated, and an
    /// automatic start's failure no longer applies. Otherwise a status wins over an error.
    public static func resolve(status: String?, error: String?, autoStartError: String?, alarmIsSet: Bool) -> CookTimerRingLine? {
        if let status, !alarmIsSet {
            return .status(status)
        }
        if let error = error ?? (alarmIsSet ? nil : autoStartError) {
            return .error(error)
        }
        return nil
    }
}
