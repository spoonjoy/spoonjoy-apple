import Combine
import Foundation

/// What happened when cook mode, Siri or Shortcuts asked to start a step's timer.
public enum CookStepTimerStartOutcome: Equatable, Sendable {
    public static let alreadyRunningMessage = "A timer is already running for this step."

    /// A new system alarm now runs for the step.
    case started(UUID)
    /// The step already has a system alarm, so no second one was set.
    case alreadyRunning(UUID)
    /// Another request for the step is still setting its alarm, so this one was ignored.
    case alreadyStarting

    /// The sentence the app shows, or Siri speaks, for this outcome.
    public func message(startedMessage: String) -> String {
        switch self {
        case .started:
            return startedMessage
        case .alreadyRunning, .alreadyStarting:
            return Self.alreadyRunningMessage
        }
    }
}

/// Remembers the system alarm that runs for each cook step, so a step has at most one timer and that timer can be cancelled.
/// AlarmKit owns the countdown; this registry only keeps the alarm ID per step. Steps are keyed by recipe and step, because a
/// timer keeps running after the cook leaves cook mode and must still be found when they come back.
@MainActor
public final class CookStepTimerRegistry: ObservableObject {
    @Published public private(set) var alarmIDsByStep: [String: UUID]
    private var startingSteps: Set<String> = []
    private let persist: ([String: String]) -> Void

    /// - Parameters:
    ///   - persisted: The value last handed to `persist`, so timers survive an app relaunch.
    ///   - persist: Saves the step-to-alarm map whenever it changes.
    public init(persisted: [String: String] = [:], persist: @escaping ([String: String]) -> Void = { _ in }) {
        alarmIDsByStep = persisted.compactMapValues(UUID.init(uuidString:))
        self.persist = persist
    }

    nonisolated public static func stepKey(recipeID: String, stepID: String) -> String {
        "\(recipeID)#\(stepID)"
    }

    /// The step keys that have a timer running, for `CookTimerBoard` and the auto-start policy.
    public var runningStepKeys: Set<String> {
        Set(alarmIDsByStep.keys)
    }

    /// The bare step ids with a timer running for one recipe, ready for `CookAutoTimerPolicy`.
    public func runningStepIDs(forRecipe recipeID: String) -> Set<String> {
        let prefix = Self.stepKey(recipeID: recipeID, stepID: "")
        return Set(alarmIDsByStep.keys.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) })
    }

    public func alarmID(forStep step: String) -> UUID? {
        alarmIDsByStep[step]
    }

    /// Starts the step's timer unless one already runs or is being set. `schedule` sets the system alarm and returns its ID.
    public func start(step: String, schedule: () async throws -> UUID) async throws -> CookStepTimerStartOutcome {
        if let running = alarmIDsByStep[step] {
            return .alreadyRunning(running)
        }
        guard startingSteps.insert(step).inserted else {
            return .alreadyStarting
        }
        defer { startingSteps.remove(step) }

        let alarmID = try await schedule()
        update { $0[step] = alarmID }
        return .started(alarmID)
    }

    /// Cancels the step's alarm. Returns false when the step has no timer. If the system refuses, the step keeps its alarm
    /// so the cook can try again, and the system's next alarm list clears it if the alarm had already ended.
    @discardableResult
    public func cancel(step: String, cancelAlarm: (UUID) throws -> Void) throws -> Bool {
        guard let alarmID = alarmIDsByStep[step] else {
            return false
        }
        try cancelAlarm(alarmID)
        forget(alarmID: alarmID)
        return true
    }

    /// Drops an alarm that ended outside cook mode, for example from the Live Activity.
    public func forget(alarmID: UUID) {
        update { map in
            map = map.filter { $0.value != alarmID }
        }
    }

    /// Keeps only the alarms the system still has, so a finished or dismissed timer frees its step.
    public func reconcile(activeAlarmIDs: Set<UUID>) {
        update { map in
            map = map.filter { activeAlarmIDs.contains($0.value) }
        }
    }

    private func update(_ change: (inout [String: UUID]) -> Void) {
        var next = alarmIDsByStep
        change(&next)
        guard next != alarmIDsByStep else {
            return
        }
        alarmIDsByStep = next
        persist(next.mapValues(\.uuidString))
    }
}
