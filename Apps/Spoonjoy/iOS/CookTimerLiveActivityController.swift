import ActivityKit
import Foundation
import SpoonjoyCore
#if canImport(AlarmKit)
import AlarmKit
#endif

/// ActivityKit's Activity is safe to use from any task, but its type does not say so.
@available(iOS 26.0, *)
private struct ActivityHandle: @unchecked Sendable {
    let activity: Activity<SpoonjoyCookTimerAttributes>

    func update(_ content: ActivityContent<SpoonjoyCookTimerAttributes.ContentState>) async {
        await activity.update(content)
    }

    func end(_ content: ActivityContent<SpoonjoyCookTimerAttributes.ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy) async {
        await activity.end(content, dismissalPolicy: dismissalPolicy)
    }
}

/// Shows the running step timer on the Lock Screen and in the Dynamic Island.
/// The countdown itself is drawn by the system from the end date, so the activity only updates when something changes.
@available(iOS 26.0, *)
@MainActor
final class CookTimerLiveActivityController: CookModeLiveActivityHosting {
    private var session: CookModeTimerSession?
    private var alarmID: UUID?
    private var activity: Activity<SpoonjoyCookTimerAttributes>?
    private var latestViewModel: CookModeViewModel?
    private var finishTask: Task<Void, Never>?

    init() {
        SpoonjoyCookActivityBridge.handler = { [weak self] command in
            await self?.handle(command)
        }
        endFinishedActivities()
    }

    func timerDidStart(_ session: CookModeTimerSession, viewModel: CookModeViewModel, deepLink: URL, alarmID: UUID?) {
        endCurrentActivity(dismissal: .immediate)
        self.session = session
        self.alarmID = alarmID
        latestViewModel = viewModel

        let attributes = SpoonjoyCookTimerAttributes(recipeID: session.recipeID, recipeTitle: session.recipeTitle, deepLink: deepLink)
        let content = ActivityContent(state: state(for: session, viewModel: viewModel), staleDate: nil)
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        scheduleFinish(for: session)
    }

    func cookModeDidChange(_ viewModel: CookModeViewModel) {
        latestViewModel = viewModel
        guard let session else {
            return
        }
        push(session, viewModel: viewModel)
    }

    func cookModeDidEnd() {
        latestViewModel = nil
        endCurrentActivity(dismissal: .immediate)
    }

    private func handle(_ command: SpoonjoyCookActivityCommand) async {
        switch command {
        case .toggleTimer:
            toggleTimer()
        case .nextStep:
            // Cook mode owns step state. When it is not on screen there is nothing safe to change,
            // and tapping the activity opens the recipe in cook mode instead.
            _ = try? await CookModeSessionCenter.shared.perform(.nextStep)
        }
    }

    private func toggleTimer() {
        guard let current = currentSession() else {
            return
        }
        let now = Date()
        let updated = current.isPaused ? current.resuming(at: now) : current.pausing(at: now)
        session = updated
        controlAlarm(paused: updated.isPaused)
        if let viewModel = latestViewModel {
            push(updated, viewModel: viewModel)
        } else {
            pushWithoutCookMode(updated)
        }
        scheduleFinish(for: updated)
    }

    /// The session in memory, or one rebuilt from the live activity when the app was relaunched to run a button.
    private func currentSession() -> CookModeTimerSession? {
        if let session {
            return session
        }
        guard let existing = Activity<SpoonjoyCookTimerAttributes>.activities.first else {
            return nil
        }
        activity = existing
        let state = existing.content.state
        let phase: CookModeTimerSession.Phase
        switch state.phase {
        case .running:
            phase = .running(endsAt: state.endDate)
        case .paused:
            phase = .paused(remainingSeconds: state.pausedRemainingSeconds)
        case .finished:
            phase = .finished
        }
        let rebuilt = CookModeTimerSession(
            recipeID: existing.attributes.recipeID,
            recipeTitle: existing.attributes.recipeTitle,
            stepID: state.timerStepID,
            stepNumber: state.timerStepNumber,
            stepTitle: state.timerStepTitle,
            durationSeconds: state.durationSeconds,
            phase: phase
        )
        session = rebuilt
        return rebuilt
    }

    private func push(_ session: CookModeTimerSession, viewModel: CookModeViewModel) {
        update(state(for: session, viewModel: viewModel))
    }

    private func pushWithoutCookMode(_ session: CookModeTimerSession) {
        guard var state = activity?.content.state else {
            return
        }
        state = apply(session, to: state)
        update(state)
    }

    private func update(_ state: SpoonjoyCookTimerAttributes.ContentState) {
        guard let activity else {
            return
        }
        let staleDate: Date? = state.phase == .running ? state.endDate : nil
        let handle = ActivityHandle(activity: activity)
        let content = ActivityContent(state: state, staleDate: staleDate)
        Task {
            await handle.update(content)
        }
    }

    private func state(for session: CookModeTimerSession, viewModel: CookModeViewModel) -> SpoonjoyCookTimerAttributes.ContentState {
        let content = CookModeLiveActivityContent(session: session, viewModel: viewModel)
        return apply(
            session,
            to: SpoonjoyCookTimerAttributes.ContentState(
                phase: .running,
                startDate: Date(),
                endDate: Date(),
                pausedRemainingSeconds: 0,
                stepLabel: content.stepLabel,
                stepTitle: content.stepTitle,
                timerStepLabel: content.timerStepLabel,
                canAdvance: content.canAdvance,
                timerStepID: session.stepID,
                timerStepNumber: session.stepNumber,
                timerStepTitle: session.stepTitle,
                durationSeconds: session.durationSeconds
            )
        )
    }

    private func apply(_ session: CookModeTimerSession, to base: SpoonjoyCookTimerAttributes.ContentState) -> SpoonjoyCookTimerAttributes.ContentState {
        var state = base
        switch session.phase {
        case .running(let endsAt):
            state.phase = .running
            state.endDate = endsAt
            state.startDate = endsAt.addingTimeInterval(-TimeInterval(session.remainingSeconds(at: Date())))
            state.pausedRemainingSeconds = 0
        case .paused(let remainingSeconds):
            state.phase = .paused
            state.pausedRemainingSeconds = remainingSeconds
        case .finished:
            state.phase = .finished
            state.pausedRemainingSeconds = 0
        }
        return state
    }

    /// Ends the activity when the timer runs out, even if the app is in the foreground and nobody touches it.
    private func scheduleFinish(for session: CookModeTimerSession) {
        finishTask?.cancel()
        finishTask = nil
        guard case .running(let endsAt) = session.phase else {
            return
        }
        finishTask = Task { [weak self] in
            let delay = max(0, endsAt.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else {
                return
            }
            self?.finish()
        }
    }

    private func finish() {
        guard let current = session?.settled(at: Date()), current.phase == .finished else {
            return
        }
        session = current
        guard let activity else {
            return
        }
        var state = activity.content.state
        state.phase = .finished
        state.pausedRemainingSeconds = 0
        let content = ActivityContent(state: state, staleDate: nil)
        self.activity = nil
        self.session = nil
        let handle = ActivityHandle(activity: activity)
        Task {
            await handle.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60)))
        }
    }

    private func endCurrentActivity(dismissal: ActivityUIDismissalPolicy) {
        finishTask?.cancel()
        finishTask = nil
        session = nil
        alarmID = nil
        let handles = Activity<SpoonjoyCookTimerAttributes>.activities.map(ActivityHandle.init)
        activity = nil
        Task {
            for handle in handles {
                await handle.end(nil, dismissalPolicy: dismissal)
            }
        }
    }

    /// An activity whose timer already ran out (for example while the app was suspended) should not linger.
    private func endFinishedActivities() {
        for activity in Activity<SpoonjoyCookTimerAttributes>.activities {
            let state = activity.content.state
            if state.phase == .running, state.endDate <= Date() {
                let handle = ActivityHandle(activity: activity)
                Task { await handle.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }

    private func controlAlarm(paused: Bool) {
#if canImport(AlarmKit)
        guard #available(iOS 26.1, *), let alarmID else {
            return
        }
        try? paused ? AlarmManager.shared.pause(id: alarmID) : AlarmManager.shared.resume(id: alarmID)
#endif
    }
}
