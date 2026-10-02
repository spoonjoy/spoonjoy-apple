import Foundation
import SpoonjoyCore
import UIKit
#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct AlarmKitCookTimerController: CookTimerAlarmControlling {
    func pause(id: UUID) throws { try AlarmManager.shared.pause(id: id) }
    func resume(id: UUID) throws { try AlarmManager.shared.resume(id: id) }
    func cancel(id: UUID) throws { try AlarmManager.shared.cancel(id: id) }
}

/// Connects cook mode to the step alarm's system Live Activity. AlarmKit owns the countdown and its Lock Screen and Dynamic Island
/// presentation (drawn by the widget extension), so this host only forwards pause and resume to the alarm and cancels the timers
/// that cook mode started when the user leaves it.
@available(iOS 26.0, *)
@MainActor
final class CookTimerAlarmHost: CookModeTimerAlarmHosting {
    private let coordinator = CookTimerAlarmCoordinator(controller: AlarmKitCookTimerController())

    init() {
        SpoonjoyCookActivityBridge.handler = { [weak self] command in
            await self?.handle(command)
        }
    }

    func timerDidStart(alarmID: UUID) {
        coordinator.timerStarted(alarmID: alarmID)
    }

    func cookModeDidEnd() {
        coordinator.cookModeEnded()
    }

    private func handle(_ command: SpoonjoyCookActivityCommand) async {
        switch command {
        case .pause(let alarmID):
            try? coordinator.pause(alarmID: alarmID)
        case .resume(let alarmID):
            try? coordinator.resume(alarmID: alarmID)
        case .nextStep(let recipeID):
            // Cook mode owns step state. When it is not on screen, open the recipe in cook mode instead.
            if (try? await CookModeSessionCenter.shared.perform(.nextStep)) == nil {
                await UIApplication.shared.open(DeepLinkURLBuilder.url(for: .recipeDetail(id: recipeID, presentation: .cook)))
            }
        }
    }
}
#endif
