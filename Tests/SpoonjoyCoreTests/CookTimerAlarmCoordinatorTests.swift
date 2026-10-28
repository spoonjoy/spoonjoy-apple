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

    @Test("the spread cook layout starts the same alarm-backed timer as the single page")
    func spreadLayoutUsesTheSameTimer() throws {
        let view = try source("Apps/Spoonjoy/Shared/Views/CookModeView.swift")
        let spread = try #require(view.range(of: "private var cookSpreadStepPage"))
        let body = view[spread.upperBound...].prefix(2_500)
        #expect(body.contains("try await scheduleSystemTimer(timer, step: currentStep)"))
    }

    @Test("leaving cook mode keeps the timer running and Next step reopens the recipe")
    func leavingKeepsTheTimer() throws {
        let center = try source("Apps/Spoonjoy/Shared/Native/CookModeSessionCenter.swift")
        let unregister = try #require(center.range(of: "func unregister() {"))
        let body = center[unregister.upperBound...].prefix(80)
        // Only the session activity ends; the step alarms keep running.
        #expect(!body.contains("cancel") && !body.contains("stepTimers") && !body.contains("host"))
        #expect(body.contains("activityObserver?.cookSessionEnded()"))

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
        #expect(!(widget + shared).contains("Activity.request"))
        // The app requests only the cook session activity; each timer's countdown stays AlarmKit's.
        #expect(host.components(separatedBy: "Activity.request").count == 2)
        #expect(host.contains("private var activity: Activity<SpoonjoyCookSessionAttributes>?"))
    }

    @Test("every timer start goes through the per-step registry, so a step never gets a second alarm")
    func startsGoThroughTheRegistry() throws {
        let view = try source("Apps/Spoonjoy/Shared/Views/CookModeView.swift")
        let center = try source("Apps/Spoonjoy/Shared/Native/CookModeSessionCenter.swift")

        #expect(view.contains("try await CookModeSessionCenter.shared.stepTimers.start(step: stepTimerKey(step))"))
        #expect(view.contains("return try await scheduleSystemTimer(timer, step: step)"))
        #expect(center.contains("return try await registration.startTimer(timer).message(startedMessage: outcome.message)"))
        #expect(center.contains("let stepTimers = CookStepTimerRegistry("))
    }

    @Test("cook mode swaps the start button for Cancel while the step's alarm runs")
    func cookModeOffersCancel() throws {
        let view = try source("Apps/Spoonjoy/Shared/Views/CookModeView.swift")

        #expect(view.contains("if stepTimers.alarmID(forStep: stepKey) != nil {"))
        #expect(view.contains(".accessibilityIdentifier(\"cookMode.timer.cancel\")"))
        #expect(view.contains(".accessibilityIdentifier(\"cook.timer.ring\")"))
        #expect(view.contains("try AlarmManager.shared.cancel(id: alarmID)"))
    }

    @Test("the Live Activity offers Cancel while counting down or paused, and ended alarms free their step")
    func liveActivityOffersCancel() throws {
        let widget = try source("Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookTimerLiveActivity.swift")
        let host = try source("Apps/Spoonjoy/iOS/CookTimerLiveActivityController.swift")

        let controls = try #require(widget.range(of: "private var showsCancel: Bool {"))
        #expect(widget[controls.upperBound...].prefix(160).contains("case .countdown, .paused:\n            return true"))
        #expect(widget.contains(".accessibilityIdentifier(\"cookTimer.liveActivity.cancel\")"))
        #expect(host.contains("for await alarms in AlarmManager.shared.alarmUpdates"))
        #expect(host.contains("center.stepTimers.forget(alarmID: alarmID)"))
    }

    @Test("the next step button opens the app so it works when cook mode is not on screen")
    func nextStepOpensApp() throws {
        let shared = try source("Apps/Spoonjoy/LiveActivity/Shared/SpoonjoyCookTimerActivity.swift")
        let intent = try #require(shared.range(of: "struct NextCookActivityStepIntent"))
        #expect(shared[intent.upperBound...].prefix(200).contains("openAppWhenRun = true"))
    }

    @Test("a launch ends only the session activities an earlier process left, never the one cook mode just started")
    func launchCleanupSparesTheNewActivity() throws {
        let host = try source("Apps/Spoonjoy/iOS/CookTimerLiveActivityController.swift")
        let initializer = try #require(host.range(of: "final class CookSessionLiveActivityController"))
        let body = host[initializer.upperBound...].prefix(1_400)
        // The ids are read before cook mode can request, so the later cleanup cannot reach a new activity.
        let read = try #require(body.range(of: "let launchIDs = Activity<SpoonjoyCookSessionAttributes>.activities.map(\\.id)"))
        let task = try #require(body.range(of: "Task {"))
        #expect(read.upperBound <= task.lowerBound)
        #expect(body.contains("CookSessionIslandLayout.staleActivityIDs(launchIDs: launchIDs, current: self?.activity?.id)"))
        #expect(!host.contains("endAll"))
    }

    @Test("the session activity goes stale when its soonest timer ends, so the ended timer is redrawn")
    func sessionActivityGoesStaleAtTheTimersEnd() throws {
        let host = try source("Apps/Spoonjoy/iOS/CookTimerLiveActivityController.swift")
        let session = try #require(host.range(of: "final class CookSessionLiveActivityController"))
        let body = host[session.upperBound...]
        #expect(body.components(separatedBy: "staleDate: CookSessionIslandLayout.staleDate(for: snapshot)").count == 3)
        #expect(!body.prefix(6_000).contains("staleDate: nil"))
    }

    @Test("VoiceOver hears each session timer's name and its countdown, paused time or Done")
    func sessionTimersReadTheirTime() throws {
        let widget = try source("Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookSessionLiveActivity.swift")
        let readout = try #require(widget.range(of: "private struct CookSessionTimerReadout: View {"))
        let body = widget[readout.upperBound...].prefix(600)
        #expect(body.contains(".accessibilityLabel(CookSessionIslandLayout.timerAccessibilityLabel(for: timer))"))
        #expect(body.contains(".accessibilityValue(accessibilityValue(readout))"))
        #expect(body.contains(".accessibilityIdentifier(\"cookSession.liveActivity.timer\")"))
        // An explicit label on a parent would replace the time again.
        #expect(!widget.contains(".accessibilityLabel(\"\\(timer.label) timer\")"))
    }

    @Test("a timer chip reserves the width of its whole length, so an hour-long countdown is never cut")
    func timerChipFitsHours() throws {
        let widget = try source("Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookSessionLiveActivity.swift")
        let chip = try #require(widget.range(of: "private struct CookSessionTimerChip: View {"))
        let body = widget[chip.upperBound...].prefix(1_400)
        // A countdown is only as wide as its current string, so a chip sized to its content cut "2:14:23" to "2:14:…".
        #expect(body.contains("Text(CookSessionIslandLayout.clockText(remaining: max(timer.duration, timer.pausedRemaining ?? 0)))"))
        // A system countdown takes all the width it is offered, so it sits over the reserved width, never beside it.
        #expect(body.contains(".hidden()"))
        #expect(body.contains(".overlay(alignment: .trailing) {\n                    CookSessionTimerReadout(timer: timer)"))
    }

    @Test("the expanded island names every timer and keeps the step count")
    func expandedIslandNamesTimers() throws {
        let widget = try source("Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookSessionLiveActivity.swift")
        let trailing = try #require(widget.range(of: "private struct CookSessionExpandedTrailing: View {"))
        #expect(widget[trailing.upperBound...].prefix(500).contains("CookSessionIslandLayout.expandedStepCount(for: snapshot)"))
        let body = try #require(widget.range(of: "private struct CookSessionExpandedBody: View {"))
        #expect(widget[body.upperBound...].prefix(600).contains("CookSessionTimerRow(timers: snapshot.timers)"))
    }

    @Test("timer chips wrap two to a row when one row would cut the names")
    func timerChipsWrap() throws {
        let widget = try source("Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookSessionLiveActivity.swift")
        let row = try #require(widget.range(of: "private struct CookSessionTimerRow: View {"))
        let body = widget[row.upperBound...].prefix(1_200)
        #expect(body.contains("ViewThatFits(in: .horizontal)"))
        #expect(body.contains("CookSessionIslandLayout.wrappedTimerRows(timers)"))
        #expect(body.contains(".fixedSize()"))
    }

    @Test("limited-width island rings take their size from the island layout")
    func limitedWidthRingSizes() throws {
        let widget = try source("Apps/Spoonjoy/LiveActivity/Widget/SpoonjoyCookSessionLiveActivity.swift")
        #expect(widget.contains("diameter: CookSessionIslandLayout.compactRingDiameter(limitedWidth: limited)"))
        #expect(widget.contains("diameter: CookSessionIslandLayout.minimalRingDiameter(limitedWidth: limited)"))
        #expect(!widget.contains("diameter: 28)"))
    }

    @Test("the widget reports the app's marketing version")
    func widgetUsesMarketingVersion() throws {
        let plist = try source("Apps/Spoonjoy/LiveActivity/Widget/Info.plist")
        #expect(plist.contains("<string>$(MARKETING_VERSION)</string>"))
    }
}
