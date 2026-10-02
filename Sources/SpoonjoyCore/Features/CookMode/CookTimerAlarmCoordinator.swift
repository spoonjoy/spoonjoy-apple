import Foundation

/// The system alarm operations cook mode needs, so the bookkeeping can be tested without AlarmKit.
public protocol CookTimerAlarmControlling {
    func pause(id: UUID) throws
    func resume(id: UUID) throws
    func cancel(id: UUID) throws
}

/// Tracks the step timers started during one cook-mode visit so that pause and resume reach the system alarm,
/// and so that leaving cook mode cancels every timer it started, including earlier ones that a later timer would otherwise orphan.
public final class CookTimerAlarmCoordinator {
    private let controller: any CookTimerAlarmControlling
    public private(set) var activeAlarmIDs: [UUID] = []

    public init(controller: any CookTimerAlarmControlling) {
        self.controller = controller
    }

    public func timerStarted(alarmID: UUID) {
        if !activeAlarmIDs.contains(alarmID) {
            activeAlarmIDs.append(alarmID)
        }
    }

    public func pause(alarmID: UUID) throws {
        try controller.pause(id: alarmID)
    }

    public func resume(alarmID: UUID) throws {
        try controller.resume(id: alarmID)
    }

    /// Cancels every timer this visit started. An alarm the system already finished is ignored.
    @discardableResult
    public func cookModeEnded() -> Int {
        let cancelled = activeAlarmIDs.filter { (try? controller.cancel(id: $0)) != nil }.count
        activeAlarmIDs.removeAll()
        return cancelled
    }
}
