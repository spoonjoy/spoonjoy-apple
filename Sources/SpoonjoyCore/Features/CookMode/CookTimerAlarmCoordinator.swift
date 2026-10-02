import Foundation

/// The system alarm operations the Live Activity buttons need, so the forwarding can be tested without AlarmKit.
public protocol CookTimerAlarmControlling {
    func pause(id: UUID) throws
    func resume(id: UUID) throws
    func cancel(id: UUID) throws
}

/// Forwards Live Activity button taps to the step alarm. A step timer is a kitchen timer, so leaving cook mode never touches it;
/// only an explicit stop cancels it.
public final class CookTimerAlarmCoordinator {
    private let controller: any CookTimerAlarmControlling

    public init(controller: any CookTimerAlarmControlling) {
        self.controller = controller
    }

    public func pause(alarmID: UUID) throws {
        try controller.pause(id: alarmID)
    }

    public func resume(alarmID: UUID) throws {
        try controller.resume(id: alarmID)
    }

    public func stop(alarmID: UUID) throws {
        try controller.cancel(id: alarmID)
    }
}
