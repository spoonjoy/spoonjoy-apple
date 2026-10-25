import Foundation

/// The kinds of feedback the kitchen plays; the app maps each to a SwiftUI `SensoryFeedback`.
public enum KitchenHapticKind: Equatable, Sendable {
    case selection
    case impactLight
    case impactMedium
    case success
    case warning
}

/// The moments in cooking that get a haptic, so every surface plays the same feedback for the same moment.
public enum KitchenHapticMoment: CaseIterable, Sendable {
    case ingredientChecked
    case stepTurned
    case timerStarted
    case timerFinished
    case cookFinished
    case listItemChecked
    case destructiveConfirm

    public var feedback: KitchenHapticKind {
        switch self {
        case .ingredientChecked, .listItemChecked: .selection
        case .stepTurned: .impactLight
        case .timerStarted: .impactMedium
        case .timerFinished, .cookFinished: .success
        case .destructiveConfirm: .warning
        }
    }
}
