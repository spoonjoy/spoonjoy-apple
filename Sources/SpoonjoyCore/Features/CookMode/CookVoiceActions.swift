import Foundation

/// What cook mode does with a command it heard. A heard command runs the same action as its button: a page turn is
/// the same turn Next and Back make, and the timer and check-all go through the session, the path Siri takes.
public enum CookVoiceAction: Equatable, Sendable {
    /// Turn the page, then show `notice`.
    case turn(forward: Bool, notice: String)
    /// Only show a line, such as "This is the last step."
    case notice(String)
    /// Read `text` aloud and show `notice`.
    case read(String, notice: String)
    /// Run a session command (`CookModeSessionResolver`) and show the line it returns.
    case session(CookModeSessionCommand)

    public static func resolve(_ command: CookVoiceCommand, viewModel: CookModeViewModel) -> CookVoiceAction {
        let steps = viewModel.recipe.steps
        let total = steps.count
        let index = viewModel.activeStep.flatMap { step in steps.firstIndex { $0.id == step.id } } ?? 0
        switch command {
        case .next:
            guard viewModel.progress.currentStepID != steps.last?.id else {
                return .notice(CookVoiceNoticeText.lastStep)
            }
            return .turn(forward: true, notice: CookVoiceNoticeText.turnedForward(to: index + 2, of: total))
        case .back:
            guard index > 0 else {
                return .notice(CookVoiceNoticeText.firstStep)
            }
            return .turn(forward: false, notice: CookVoiceNoticeText.turnedBack(to: index, of: total))
        case .repeatStep:
            return .read(CookModeSessionResolver.readout(for: viewModel), notice: CookVoiceNoticeText.reading(step: index + 1, of: total))
        case .startTimer:
            return .session(.startTimer)
        case .checkAll:
            return .session(.checkStep)
        }
    }

    /// The line a session command shows when it throws, such as a refused timer.
    public static func failureNotice(for error: Error) -> String {
        CookModeSystemTimerScheduler.message(for: error, fallback: CookVoiceNoticeText.actionFailed)
    }
}

/// How the voice line changes when the mic's state does.
public enum CookVoiceNoticeChange: Equatable, Sendable {
    /// Take the line down.
    case clear
    /// Leave the line as it is.
    case keep
    /// Show `text`; a line that `persists` stays until the state changes, and one that offers Settings has a button.
    case show(String, persists: Bool, offersSettings: Bool)

    public static func on(_ state: CookVoiceListenerState) -> CookVoiceNoticeChange {
        switch state {
        case .off:
            return .clear
        case .requestingPermission:
            return .keep
        case .listening:
            return .show(CookVoiceNoticeText.listening, persists: false, offersSettings: false)
        case .unavailable(let reason):
            let offersSettings = CookVoiceNoticeText.offersSettings(reason: reason)
            return .show(CookVoiceNoticeText.unavailable(reason: reason), persists: offersSettings, offersSettings: offersSettings)
        }
    }
}

extension CookModeSessionResolver {
    /// Runs a session command on one cook-mode screen: resolves it, applies the new progress when it changed, and
    /// starts the step's timer when the command asks, returning the line to show or speak.
    @MainActor
    public static func perform(
        _ command: CookModeSessionCommand,
        viewModel: CookModeViewModel,
        updatedAt: String,
        apply: @MainActor (CookModeProgress) -> Void,
        startTimer: @MainActor (CookModeSystemTimerViewModel) async throws -> CookStepTimerStartOutcome
    ) async throws -> String {
        let outcome = resolve(command, viewModel: viewModel, updatedAt: updatedAt)
        if outcome.progress != viewModel.progress {
            apply(outcome.progress)
        }
        if let timer = outcome.timerToStart {
            return try await startTimer(timer).message(startedMessage: outcome.message)
        }
        return outcome.message
    }
}
