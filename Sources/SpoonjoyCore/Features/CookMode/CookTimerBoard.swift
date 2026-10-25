import Foundation

/// One running step timer, as the timer board and the Live Activity show it.
public struct CookTimerEntry: Equatable, Hashable, Codable, Sendable, Identifiable {
    /// The step timer key from `CookStepTimerRegistry.stepKey(recipeID:stepID:)`.
    public let id: String
    public let stepNumber: Int
    public let label: String
    public let endsAt: Date
    public let isPaused: Bool

    public init(id: String, stepNumber: Int, label: String, endsAt: Date, isPaused: Bool) {
        self.id = id
        self.stepNumber = stepNumber
        self.label = label
        self.endsAt = endsAt
        self.isPaused = isPaused
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
