import Foundation
import Testing
@testable import SpoonjoyCore

private final class RecordingAlarmController: CookTimerAlarmControlling {
    struct Failure: Error {}
    var calls: [String] = []
    var failingCancels: Set<UUID> = []

    func pause(id: UUID) throws { calls.append("pause \(id)") }
    func resume(id: UUID) throws { calls.append("resume \(id)") }
    func cancel(id: UUID) throws {
        calls.append("cancel \(id)")
        if failingCancels.contains(id) { throw Failure() }
    }
}

@Suite("Cook timer alarm coordinator")
struct CookTimerAlarmCoordinatorTests {
    private let first = UUID()
    private let second = UUID()

    @Test("pause and resume reach the system alarm")
    func pauseAndResumeReachTheAlarm() throws {
        let controller = RecordingAlarmController()
        let coordinator = CookTimerAlarmCoordinator(controller: controller)

        try coordinator.pause(alarmID: first)
        try coordinator.resume(alarmID: first)

        #expect(controller.calls == ["pause \(first)", "resume \(first)"])
    }

    @Test("leaving cook mode cancels the timer")
    func leavingCancelsTheTimer() {
        let controller = RecordingAlarmController()
        let coordinator = CookTimerAlarmCoordinator(controller: controller)
        coordinator.timerStarted(alarmID: first)

        #expect(coordinator.cookModeEnded() == 1)
        #expect(controller.calls == ["cancel \(first)"])
        #expect(coordinator.activeAlarmIDs.isEmpty)
        #expect(coordinator.cookModeEnded() == 0)
    }

    @Test("a second timer does not orphan the first")
    func secondTimerKeepsTheFirst() {
        let controller = RecordingAlarmController()
        let coordinator = CookTimerAlarmCoordinator(controller: controller)
        coordinator.timerStarted(alarmID: first)
        coordinator.timerStarted(alarmID: second)
        coordinator.timerStarted(alarmID: second)

        #expect(coordinator.activeAlarmIDs == [first, second])
        #expect(coordinator.cookModeEnded() == 2)
        #expect(controller.calls == ["cancel \(first)", "cancel \(second)"])
    }

    @Test("an alarm the system already finished does not stop the others from cancelling")
    func finishedAlarmIsIgnored() {
        let controller = RecordingAlarmController()
        controller.failingCancels = [first]
        let coordinator = CookTimerAlarmCoordinator(controller: controller)
        coordinator.timerStarted(alarmID: first)
        coordinator.timerStarted(alarmID: second)

        #expect(coordinator.cookModeEnded() == 1)
        #expect(controller.calls == ["cancel \(first)", "cancel \(second)"])
    }
}

@Suite("Cook timer live activity wiring")
struct CookTimerLiveActivityWiringTests {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("switching recipes re-registers the cook-mode session so commands act on the new recipe")
    func recipeSwitchReregisters() throws {
        let view = try source("Apps/Spoonjoy/Shared/Views/CookModeView.swift")
        let onChange = try #require(view.range(of: ".onChange(of: recipe.cookModeIdentityKey) { _, _ in"))
        let body = view[onChange.upperBound...].prefix(160)
        #expect(body.contains("registerCookModeSession()"))
    }

    @Test("the step alarm is the only timer activity and its metadata is shared with the widget")
    func alarmKitIsTheSingleSource() throws {
        let view = try source("Apps/Spoonjoy/Shared/Views/CookModeView.swift")
        let widget = try source("Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookTimerLiveActivity.swift")
        let shared = try source("Apps/Spoonjoy/LiveActivity/Shared/SpoonjoyCookTimerActivity.swift")
        let host = try source("Apps/Spoonjoy/iOS/CookTimerLiveActivityController.swift")

        #expect(!view.contains("struct SpoonjoyCookTimerMetadata"))
        #expect(shared.contains("struct SpoonjoyCookTimerMetadata: AlarmMetadata"))
        #expect(widget.contains("ActivityConfiguration(for: AlarmAttributes<SpoonjoyCookTimerMetadata>.self)"))
        #expect(!(host + widget + shared).contains("Activity.request"))
    }

    @Test("the next step button opens the app so it works when cook mode is not on screen")
    func nextStepOpensApp() throws {
        let shared = try source("Apps/Spoonjoy/LiveActivity/Shared/SpoonjoyCookTimerActivity.swift")
        let intent = try #require(shared.range(of: "struct NextCookActivityStepIntent"))
        #expect(shared[intent.upperBound...].prefix(200).contains("openAppWhenRun = true"))
    }

    @Test("the widget reports the app's marketing version")
    func widgetUsesMarketingVersion() throws {
        let plist = try source("Apps/Spoonjoy/LiveActivity/Widget/Info.plist")
        #expect(plist.contains("<string>$(MARKETING_VERSION)</string>"))
    }
}
