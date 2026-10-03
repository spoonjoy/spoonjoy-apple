import Foundation

/// Hands-free commands for the recipe that is open in cook mode (Siri, Shortcuts and the Live Activity).
public enum CookModeSessionCommand: Equatable, Sendable {
    case nextStep
    case previousStep
    case startTimer
    case readStep
}

public struct CookModeSessionOutcome: Equatable {
    public let progress: CookModeProgress
    /// The sentence Siri speaks or shows.
    public let message: String
    /// Set when the command asks the app to start the current step's timer.
    public let timerToStart: CookModeSystemTimerViewModel?
}

public enum CookModeSessionResolver {
    public static func resolve(
        _ command: CookModeSessionCommand,
        viewModel: CookModeViewModel,
        updatedAt: String
    ) -> CookModeSessionOutcome {
        guard viewModel.activeStep != nil else {
            return CookModeSessionOutcome(progress: viewModel.progress, message: "This recipe has no steps.", timerToStart: nil)
        }

        switch command {
        case .nextStep:
            let next = viewModel.progressAfterSelectingNext(updatedAt: updatedAt)
            guard next != viewModel.progress else {
                return CookModeSessionOutcome(progress: next, message: "You are on the last step. \(readout(for: viewModel))", timerToStart: nil)
            }
            return CookModeSessionOutcome(progress: next, message: readout(for: CookModeViewModel(recipe: viewModel.recipe, progress: next)), timerToStart: nil)
        case .previousStep:
            let previous = viewModel.progressAfterSelectingPrevious(updatedAt: updatedAt)
            guard previous != viewModel.progress else {
                return CookModeSessionOutcome(progress: previous, message: "You are on the first step. \(readout(for: viewModel))", timerToStart: nil)
            }
            return CookModeSessionOutcome(progress: previous, message: readout(for: CookModeViewModel(recipe: viewModel.recipe, progress: previous)), timerToStart: nil)
        case .startTimer:
            guard let timer = viewModel.systemTimer else {
                return CookModeSessionOutcome(progress: viewModel.progress, message: "This step has no timer.", timerToStart: nil)
            }
            return CookModeSessionOutcome(progress: viewModel.progress, message: "Starting a \(timer.durationLabel) timer.", timerToStart: timer)
        case .readStep:
            return CookModeSessionOutcome(progress: viewModel.progress, message: readout(for: viewModel), timerToStart: nil)
        }
    }

    /// "Step 2 of 5, Sear the steaks. <instructions> This step takes 5 min."
    public static func readout(for viewModel: CookModeViewModel) -> String {
        guard let step = viewModel.activeStep else {
            return "This recipe has no steps."
        }
        let title = step.stepTitle.map { ", \($0)" } ?? ""
        var parts = ["\(viewModel.stepProgressLabel)\(title)."]
        parts.append(step.description)
        if let timer = viewModel.systemTimer {
            parts.append("This step takes \(timer.durationLabel).")
        }
        return parts.joined(separator: " ")
    }
}
