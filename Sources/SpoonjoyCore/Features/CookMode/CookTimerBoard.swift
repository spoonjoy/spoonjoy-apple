import Foundation

/// One running step timer, as the timer board and the Live Activity show it.
public struct CookTimerEntry: Equatable, Hashable, Codable, Sendable, Identifiable {
    /// The step timer key from `CookStepTimerRegistry.stepKey(recipeID:stepID:)`.
    public let id: String
    public let stepNumber: Int
    public let label: String
    public let endsAt: Date
    public let isPaused: Bool
    /// The whole timer length, so a ring can show how far it has run. Zero when unknown.
    public let duration: TimeInterval
    /// The time left when the timer was paused. A paused timer's `endsAt` is stale, so readouts use this instead.
    public let pausedRemaining: TimeInterval?

    public init(
        id: String,
        stepNumber: Int,
        label: String,
        endsAt: Date,
        isPaused: Bool,
        duration: TimeInterval = 0,
        pausedRemaining: TimeInterval? = nil
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.label = label
        self.endsAt = endsAt
        self.isPaused = isPaused
        self.duration = duration
        self.pausedRemaining = pausedRemaining
    }
}

/// Several named running timers, soonest to end first.
public struct CookTimerBoard: Equatable, Sendable {
    public let ordered: [CookTimerEntry]

    public init(timers: [CookTimerEntry]) {
        ordered = timers.sorted {
            $0.endsAt != $1.endsAt ? $0.endsAt < $1.endsAt : $0.stepNumber < $1.stepNumber
        }
    }

    public var soonest: CookTimerEntry? {
        ordered.first
    }
}
