import Foundation

/// The end date and pause state of each running step timer, keyed by AlarmKit alarm id.
///
/// `CookStepTimerRegistry` only knows which step owns which alarm. The Live Activity also needs when each timer ends
/// and how long it was, and a paused alarm's countdown no longer has an end date, so the app records them here.
public struct CookTimerClock: Codable, Equatable, Sendable {
    public struct Record: Codable, Equatable, Sendable {
        public let duration: TimeInterval
        public let endsAt: Date
        public let pausedRemaining: TimeInterval?

        public init(duration: TimeInterval, endsAt: Date, pausedRemaining: TimeInterval?) {
            self.duration = duration
            self.endsAt = endsAt
            self.pausedRemaining = pausedRemaining
        }
    }

    public private(set) var records: [String: Record]

    public init(records: [String: Record] = [:]) {
        self.records = records
    }

    public mutating func start(alarmID: UUID, duration: TimeInterval, now: Date) {
        records[alarmID.uuidString] = Record(duration: duration, endsAt: now.addingTimeInterval(duration), pausedRemaining: nil)
    }

    public mutating func pause(alarmID: UUID, now: Date) {
        guard let record = records[alarmID.uuidString], record.pausedRemaining == nil else {
            return
        }
        let remaining = max(0, record.endsAt.timeIntervalSince(now))
        records[alarmID.uuidString] = Record(duration: record.duration, endsAt: record.endsAt, pausedRemaining: remaining)
    }

    public mutating func resume(alarmID: UUID, now: Date) {
        guard let record = records[alarmID.uuidString], let remaining = record.pausedRemaining else {
            return
        }
        records[alarmID.uuidString] = Record(duration: record.duration, endsAt: now.addingTimeInterval(remaining), pausedRemaining: nil)
    }

    /// Drops records for alarms that AlarmKit no longer has.
    public mutating func retain(activeAlarmIDs: Set<UUID>) {
        let keep = Set(activeAlarmIDs.map(\.uuidString))
        records = records.filter { keep.contains($0.key) }
    }

    /// The timers running for one recipe's steps. A step whose alarm has no record is left out, because without an
    /// end date there is nothing honest to count down.
    public func board(recipe: Recipe, alarmIDsByStep: [String: UUID]) -> CookTimerBoard {
        let entries = recipe.steps.enumerated().compactMap { index, step -> CookTimerEntry? in
            let key = CookStepTimerRegistry.stepKey(recipeID: recipe.id, stepID: step.id)
            guard let alarmID = alarmIDsByStep[key], let record = records[alarmID.uuidString] else {
                return nil
            }
            return CookTimerEntry(
                id: key,
                stepNumber: index + 1,
                label: step.stepTitle ?? "Step \(index + 1)",
                endsAt: record.endsAt,
                isPaused: record.pausedRemaining != nil,
                duration: record.duration,
                pausedRemaining: record.pausedRemaining
            )
        }
        return CookTimerBoard(timers: entries)
    }
}
