import Foundation

/// The state of one running step timer, independent of ActivityKit so it can be tested without a device.
public struct CookModeTimerSession: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case running(endsAt: Date)
        case paused(remainingSeconds: Int)
        case finished
    }

    public let recipeID: String
    public let recipeTitle: String
    public let stepID: String
    public let stepNumber: Int
    public let stepTitle: String
    public let durationSeconds: Int
    public let phase: Phase

    public init(
        recipeID: String,
        recipeTitle: String,
        stepID: String,
        stepNumber: Int,
        stepTitle: String,
        durationSeconds: Int,
        phase: Phase
    ) {
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.stepID = stepID
        self.stepNumber = stepNumber
        self.stepTitle = stepTitle
        self.durationSeconds = durationSeconds
        self.phase = phase
    }

    public static func starting(
        recipe: Recipe,
        step: RecipeStep,
        durationSeconds: Int,
        now: Date
    ) -> CookModeTimerSession {
        CookModeTimerSession(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            stepID: step.id,
            stepNumber: step.stepNum,
            stepTitle: step.stepTitle ?? "Step \(step.stepNum)",
            durationSeconds: durationSeconds,
            phase: .running(endsAt: now.addingTimeInterval(TimeInterval(durationSeconds)))
        )
    }

    public var isPaused: Bool {
        if case .paused = phase {
            return true
        }
        return false
    }

    public func remainingSeconds(at now: Date) -> Int {
        switch phase {
        case .running(let endsAt):
            return max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
        case .paused(let remainingSeconds):
            return remainingSeconds
        case .finished:
            return 0
        }
    }

    /// Marks a running timer finished once its end time has passed.
    public func settled(at now: Date) -> CookModeTimerSession {
        guard case .running = phase, remainingSeconds(at: now) == 0 else {
            return self
        }
        return with(phase: .finished)
    }

    public func pausing(at now: Date) -> CookModeTimerSession {
        guard case .running = phase else {
            return self
        }
        let remaining = remainingSeconds(at: now)
        return with(phase: remaining == 0 ? .finished : .paused(remainingSeconds: remaining))
    }

    public func resuming(at now: Date) -> CookModeTimerSession {
        guard case .paused(let remainingSeconds) = phase else {
            return self
        }
        return with(phase: .running(endsAt: now.addingTimeInterval(TimeInterval(remainingSeconds))))
    }

    private func with(phase: Phase) -> CookModeTimerSession {
        CookModeTimerSession(
            recipeID: recipeID,
            recipeTitle: recipeTitle,
            stepID: stepID,
            stepNumber: stepNumber,
            stepTitle: stepTitle,
            durationSeconds: durationSeconds,
            phase: phase
        )
    }
}

/// What the Lock Screen and Dynamic Island show: the recipe, where cook mode is now, and the timer.
public struct CookModeLiveActivityContent: Equatable, Sendable {
    public let recipeTitle: String
    public let stepLabel: String
    public let stepTitle: String
    /// Set only when the timer belongs to a different step than the one cook mode is on.
    public let timerStepLabel: String?
    public let phase: CookModeTimerSession.Phase
    public let canAdvance: Bool

    public init(session: CookModeTimerSession, viewModel: CookModeViewModel) {
        recipeTitle = session.recipeTitle
        stepLabel = viewModel.stepProgressLabel
        if let activeStep = viewModel.activeStep {
            stepTitle = activeStep.stepTitle ?? "Step \(activeStep.stepNum)"
            timerStepLabel = activeStep.id == session.stepID ? nil : "Timing step \(session.stepNumber): \(session.stepTitle)"
            canAdvance = activeStep.id != viewModel.recipe.steps.last?.id
        } else {
            stepTitle = session.stepTitle
            timerStepLabel = nil
            canAdvance = false
        }
        phase = session.phase
    }
}
