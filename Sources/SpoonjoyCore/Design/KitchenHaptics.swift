import Foundation
import OuroHX

/// The moments in cooking that get a haptic, so every surface plays the same feedback for the same moment.
public enum KitchenHapticMoment: CaseIterable, Sendable {
    case ingredientChecked
    case stepTurned
    case timerStarted
    case timerFinished
    case cookFinished
    case listItemChecked
    case destructiveConfirm
    /// The recipe page's Serves stepper moved a serving (or a step of scale).
    case servingsStepped

    /// The OuroHX moment this plays. Every moment but a step turn is OuroHX's moment of the same meaning, which feels
    /// exactly as Spoonjoy's did; a step turn keeps Spoonjoy's own (see `OuroHapticMoment.spoonjoyStepTurned`).
    public var ouroMoment: OuroHapticMoment {
        switch self {
        case .ingredientChecked, .listItemChecked: .checked
        case .servingsStepped: .stepped
        case .stepTurned: .spoonjoyStepTurned
        case .timerStarted: .started
        case .timerFinished, .cookFinished: .finished
        case .destructiveConfirm: .warned
        }
    }
}

extension OuroHapticMoment {
    /// Spoonjoy's step turn: a light impact at full strength. OuroHX's `.turned` is light at 0.7, which would feel
    /// softer, so cook mode keeps its own.
    public static let spoonjoyStepTurned = OuroHapticMoment(name: "stepTurned", feedback: .impact(weight: .light, intensity: 1))
}
