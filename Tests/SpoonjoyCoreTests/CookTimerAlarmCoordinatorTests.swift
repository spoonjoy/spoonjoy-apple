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

    @Test("pause and resume reach the system alarm")
    func pauseAndResumeReachTheAlarm() throws {
        let controller = RecordingAlarmController()
        let coordinator = CookTimerAlarmCoordinator(controller: controller)

        try coordinator.pause(alarmID: first)
        try coordinator.resume(alarmID: first)

        #expect(controller.calls == ["pause \(first)", "resume \(first)"])
    }

    @Test("an explicit stop cancels the alarm and nothing else does")
    func explicitStopCancels() throws {
        let controller = RecordingAlarmController()
        let coordinator = CookTimerAlarmCoordinator(controller: controller)

        try coordinator.pause(alarmID: first)
        #expect(!controller.calls.contains { $0.hasPrefix("cancel") })

        try coordinator.stop(alarmID: first)
        #expect(controller.calls.last == "cancel \(first)")
    }

    @Test("a stop for an alarm the system already finished reports the failure")
    func stopReportsFailure() {
        let controller = RecordingAlarmController()
        controller.failingCancels = [first]
        let coordinator = CookTimerAlarmCoordinator(controller: controller)

        #expect(throws: RecordingAlarmController.Failure.self) { try coordinator.stop(alarmID: first) }
    }
}

@Suite("Cook timer live activity wiring")
struct CookTimerLiveActivityWiringTests {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("leaving cook mode keeps the timer running and Next step reopens the recipe")
    func leavingKeepsTheTimer() throws {
        let center = try source("Apps/Spoonjoy/Shared/Native/CookModeSessionCenter.swift")
        let unregister = try #require(center.range(of: "func unregister() {"))
        let body = center[unregister.upperBound...].prefix(80)
        #expect(!body.contains("cancel") && !body.contains("End") && !body.contains("host"))

        let host = try source("Apps/Spoonjoy/iOS/CookTimerLiveActivityController.swift")
        #expect(!host.contains("cookModeEnded"))
        #expect(host.contains("UIApplication.shared.open(DeepLinkURLBuilder.url(for: .recipeDetail(id: recipeID, presentation: .cook)))"))
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
