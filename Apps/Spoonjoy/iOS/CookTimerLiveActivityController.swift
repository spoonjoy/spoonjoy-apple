import ActivityKit
import Foundation
import OSLog
import SpoonjoyCore
import UIKit
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Runs the cook session Live Activity: it starts when cook mode opens, follows every step, check and timer change,
/// and ends when cook mode closes. Marking the last step done ends it after 15 minutes, so the finished dish stays
/// on the Lock Screen for a moment.
@MainActor
final class CookSessionLiveActivityController: CookSessionActivityObserving {
    static let finishedDismissalDelay: TimeInterval = 15 * 60

    private let logger = Logger(subsystem: "app.spoonjoy", category: "CookSessionLiveActivity")
    private var activity: Activity<SpoonjoyCookSessionAttributes>?
    private var lastSnapshot: CookSessionSnapshot?
    /// The recipe whose last step was marked done. Its activity is already on the way out, so later changes leave it.
    private var finishedRecipeID: String?

    init() {
        SpoonjoyCookSessionBridge.handler = { command in
            await Self.handle(command)
        }
        // A session activity left by a quit or crashed app has no cook mode behind it.
        Task {
            await Self.endAll()
        }
        CookModeSessionCenter.shared.activityObserver = self
    }

    func cookSessionChanged(_ snapshot: CookSessionSnapshot, deepLink: URL, finished: Bool) {
        if finishedRecipeID == snapshot.recipeID {
            return
        }
        if let activity, activity.attributes.recipeID != snapshot.recipeID {
            end(activity, snapshot: nil, dismissal: .immediate)
        }
        if finished {
            finishedRecipeID = snapshot.recipeID
            if let activity {
                end(activity, snapshot: snapshot, dismissal: .after(.now.addingTimeInterval(Self.finishedDismissalDelay)))
            }
            return
        }
        Task6Diag.log("changed step=\(snapshot.stepNumber) hasActivity=\(activity != nil)") // TASK6-DIAG
        guard let activity else {
            request(snapshot, deepLink: deepLink)
            return
        }
        guard snapshot != lastSnapshot else {
            return
        }
        lastSnapshot = snapshot
        let id = activity.id
        Task {
            await Self.update(id: id, content: ActivityContent(state: snapshot, staleDate: nil))
        }
    }

    func cookSessionEnded() {
        finishedRecipeID = nil
        if let activity {
            end(activity, snapshot: nil, dismissal: .immediate)
        }
    }

    private func request(_ snapshot: CookSessionSnapshot, deepLink: URL) {
        guard Task6Diag.timed("areActivitiesEnabled", { ActivityAuthorizationInfo().areActivitiesEnabled }) else { // TASK6-DIAG
            logger.info("Live Activities are off, so the cook session stays in the app")
            return
        }
        Task6Diag.log("request step=\(snapshot.stepNumber)") // TASK6-DIAG
        do {
            activity = try Activity.request(
                attributes: SpoonjoyCookSessionAttributes(recipeID: snapshot.recipeID, deepLink: deepLink.absoluteString),
                content: ActivityContent(state: snapshot, staleDate: nil),
                pushType: nil
            )
            lastSnapshot = snapshot
            Task6Diag.log("request done activity=\(activity?.id ?? "nil")") // TASK6-DIAG
        } catch {
            Task6Diag.log("request failed \(error)") // TASK6-DIAG
            logger.error("Could not start the cook session Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func end(_ ending: Activity<SpoonjoyCookSessionAttributes>, snapshot: CookSessionSnapshot?, dismissal: ActivityUIDismissalPolicy) {
        activity = nil
        lastSnapshot = nil
        let id = ending.id
        let content = snapshot.map { ActivityContent(state: $0, staleDate: nil) }
        Task {
            await Self.end(id: id, content: content, dismissal: dismissal)
        }
    }

    // Activity is not Sendable, so these look it up by id off the main actor instead of sending it there.
    private nonisolated static func update(id: String, content: ActivityContent<CookSessionSnapshot>) async {
        await Activity<SpoonjoyCookSessionAttributes>.activities.first { $0.id == id }?.update(content)
    }

    private nonisolated static func end(id: String, content: ActivityContent<CookSessionSnapshot>?, dismissal: ActivityUIDismissalPolicy) async {
        await Activity<SpoonjoyCookSessionAttributes>.activities.first { $0.id == id }?.end(content, dismissalPolicy: dismissal)
    }

    private nonisolated static func endAll() async {
        for activity in Activity<SpoonjoyCookSessionAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Check and Next work in the background while cook mode is open. Without it they open cook mode at the recipe.
    private static func handle(_ command: SpoonjoyCookSessionCommand) async -> Bool {
        let center = CookModeSessionCenter.shared
        switch command {
        case .checkStep(let recipeID):
            guard center.registration?.viewModel().recipe.id == recipeID else {
                return false
            }
            return (try? await center.perform(.checkStep)) != nil
        case .nextStep(let recipeID):
            guard center.registration?.viewModel().recipe.id == recipeID else {
                return false
            }
            return (try? await center.perform(.nextStep)) != nil
        case .open(let recipeID):
            return await UIApplication.shared.open(DeepLinkURLBuilder.url(for: .recipeDetail(id: recipeID, presentation: .cook)))
        }
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct AlarmKitCookTimerController: CookTimerAlarmControlling {
    func pause(id: UUID) throws { try AlarmManager.shared.pause(id: id) }
    func resume(id: UUID) throws { try AlarmManager.shared.resume(id: id) }
    func cancel(id: UUID) throws { try AlarmManager.shared.cancel(id: id) }
}

/// Runs the Live Activity buttons. AlarmKit owns the countdown and its Lock Screen and Dynamic Island presentation
/// (drawn by the widget extension), so this host forwards pause, resume and cancel to the alarm. A timer keeps running when the user
/// leaves cook mode; only pressing Stop or Cancel ends it.
@available(iOS 26.0, *)
@MainActor
final class CookTimerAlarmHost {
    private let coordinator = CookTimerAlarmCoordinator(controller: AlarmKitCookTimerController())

    private var alarmUpdatesTask: Task<Void, Never>?

    init() {
        SpoonjoyCookActivityBridge.handler = { [weak self] command in
            await self?.handle(command)
        }
        // A timer can end without cook mode: it rings and is dismissed, or the cook stops it from the Lock Screen.
        // Following the system's alarm list frees those steps, so each step can be timed again.
        // A journey's stand-in alarm is not in the system's list, so following that list would drop it at once.
        guard !CookModeSessionCenter.usesJourneyAlarmFixture else {
            return
        }
        if let alarms = try? AlarmManager.shared.alarms {
            Self.reconcile(alarms)
        }
        alarmUpdatesTask = Task { @MainActor in
            for await alarms in AlarmManager.shared.alarmUpdates {
                Self.reconcile(alarms)
            }
        }
    }

    private static func reconcile(_ alarms: [Alarm]) {
        let active = Set(alarms.map(\.id))
        let center = CookModeSessionCenter.shared
        center.stepTimers.reconcile(activeAlarmIDs: active)
        center.updateTimerClock { $0.retain(activeAlarmIDs: active) }
    }

    private func handle(_ command: SpoonjoyCookActivityCommand) async {
        let center = CookModeSessionCenter.shared
        switch command {
        case .pause(let alarmID):
            if (try? coordinator.pause(alarmID: alarmID)) != nil {
                center.updateTimerClock { $0.pause(alarmID: alarmID, now: Date()) }
            }
        case .resume(let alarmID):
            if (try? coordinator.resume(alarmID: alarmID)) != nil {
                center.updateTimerClock { $0.resume(alarmID: alarmID, now: Date()) }
            }
        case .stop(let alarmID):
            try? coordinator.stop(alarmID: alarmID)
            center.stepTimers.forget(alarmID: alarmID)
            center.updateTimerClock { $0.retain(activeAlarmIDs: Set(center.stepTimers.alarmIDsByStep.values)) }
        case .nextStep(let recipeID):
            // Cook mode owns step state. After the user left it there is no session, so open the recipe in cook mode instead.
            if (try? await CookModeSessionCenter.shared.perform(.nextStep)) == nil {
                await UIApplication.shared.open(DeepLinkURLBuilder.url(for: .recipeDetail(id: recipeID, presentation: .cook)))
            }
        }
    }
}
#endif
