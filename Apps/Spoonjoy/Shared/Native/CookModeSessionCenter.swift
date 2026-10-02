import Foundation
import SpoonjoyCore

/// Receives step-timer changes from cook mode so a platform host can keep the system alarm in step with the screen.
@MainActor
protocol CookModeTimerAlarmHosting: AnyObject {
    func timerDidStart(alarmID: UUID)
    func cookModeDidEnd()
}

enum CookModeSessionError: Error, Equatable {
    case notCooking
}

/// Lets Siri, Shortcuts and the Live Activity drive the cook-mode screen that is open right now.
/// Cook mode registers while it is on screen, and every command goes through the same view model methods the buttons use.
@MainActor
final class CookModeSessionCenter {
    struct Registration {
        let viewModel: () -> CookModeViewModel
        let apply: (CookModeProgress) -> Void
        let startTimer: (CookModeSystemTimerViewModel) async throws -> Void
    }

    static let shared = CookModeSessionCenter()

    var timerHost: (any CookModeTimerAlarmHosting)?
    private(set) var registration: Registration?

    var isCooking: Bool {
        registration != nil
    }

    func register(_ registration: Registration) {
        self.registration = registration
    }

    func unregister() {
        registration = nil
        timerHost?.cookModeDidEnd()
    }

    /// The step on screen, for the annotated on-screen entity.
    func onScreenStep() -> CookModeOnScreenStep? {
        registration?.viewModel().onScreenStep
    }

    func perform(_ command: CookModeSessionCommand, updatedAt: String = ISO8601DateFormatter().string(from: Date())) async throws -> String {
        guard let registration else {
            throw CookModeSessionError.notCooking
        }

        let outcome = CookModeSessionResolver.resolve(command, viewModel: registration.viewModel(), updatedAt: updatedAt)
        if outcome.progress != registration.viewModel().progress {
            registration.apply(outcome.progress)
        }
        if let timer = outcome.timerToStart {
            try await registration.startTimer(timer)
        }
        return outcome.message
    }
}

struct CookModeOnScreenStep: Equatable {
    let recipeID: String
    let recipeTitle: String
    let stepID: String
    let stepNumber: Int
    let stepTitle: String

    var entityID: String {
        "\(recipeID)#\(stepID)"
    }
}

extension CookModeViewModel {
    var onScreenStep: CookModeOnScreenStep? {
        guard let step = activeStep else {
            return nil
        }
        return CookModeOnScreenStep(recipeID: recipe.id, recipeTitle: recipe.title, stepID: step.id, stepNumber: step.stepNum, stepTitle: step.stepTitle ?? "Step \(step.stepNum)")
    }
}
