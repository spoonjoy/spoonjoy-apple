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

/// Runs the Live Activity buttons. AlarmKit owns the countdown and its Lock Screen and Dynamic Island presentation
/// (drawn by the widget extension), so this host forwards pause, resume and stop to the alarm. A timer keeps running when the user
/// leaves cook mode; only pressing stop or cancel ends it.
@available(iOS 26.0, *)
@MainActor
final class CookTimerAlarmHost {
    private let coordinator = CookTimerAlarmCoordinator(controller: AlarmKitCookTimerController())

    init() {
        SpoonjoyCookActivityBridge.handler = { [weak self] command in
            await self?.handle(command)
        }
    }

    private func handle(_ command: SpoonjoyCookActivityCommand) async {
        switch command {
        case .pause(let alarmID):
            try? coordinator.pause(alarmID: alarmID)
        case .resume(let alarmID):
            try? coordinator.resume(alarmID: alarmID)
        case .stop(let alarmID):
            try? coordinator.stop(alarmID: alarmID)
        case .nextStep(let recipeID):
            // Cook mode owns step state. After the user left it there is no session, so open the recipe in cook mode instead.
            if (try? await CookModeSessionCenter.shared.perform(.nextStep)) == nil {
                await UIApplication.shared.open(DeepLinkURLBuilder.url(for: .recipeDetail(id: recipeID, presentation: .cook)))
            }
        }
    }
}
#endif
