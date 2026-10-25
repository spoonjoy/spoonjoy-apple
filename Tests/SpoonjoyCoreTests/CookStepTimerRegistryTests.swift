import Foundation
import Testing
@testable import SpoonjoyCore

@MainActor
@Suite("Cook step timer registry")
struct CookStepTimerRegistryTests {
    private struct Failure: Error {}
    private let step = CookStepTimerRegistry.stepKey(recipeID: "recipe-1", stepID: "step-2")
    private let otherStep = CookStepTimerRegistry.stepKey(recipeID: "recipe-1", stepID: "step-3")

    @Test("a step key names the recipe and the step")
    func stepKeyNamesRecipeAndStep() {
        #expect(step == "recipe-1#step-2")
    }

    @Test("starting a step's timer keeps its alarm ID and saves it")
    func startKeepsAlarmID() async throws {
        let alarm = UUID()
        var saved: [[String: String]] = []
        let registry = CookStepTimerRegistry(persist: { saved.append($0) })

        let outcome = try await registry.start(step: step) { alarm }

        #expect(outcome == .started(alarm))
        #expect(registry.alarmID(forStep: step) == alarm)
        #expect(saved == [[step: alarm.uuidString]])
    }

    @Test("starting again while the step's timer runs sets no second alarm")
    func secondStartIsRefused() async throws {
        let alarm = UUID()
        let registry = CookStepTimerRegistry()
        var scheduled = 0
        _ = try await registry.start(step: step) { scheduled += 1; return alarm }

        let again = try await registry.start(step: step) { scheduled += 1; return UUID() }

        #expect(again == .alreadyRunning(alarm))
        #expect(scheduled == 1)
        #expect(again.message(startedMessage: "set") == CookStepTimerStartOutcome.alreadyRunningMessage)
        #expect(CookStepTimerStartOutcome.started(alarm).message(startedMessage: "set") == "set")
    }

    @Test("a second request while the first is still setting the alarm is ignored")
    func concurrentStartIsIgnored() async throws {
        let alarm = UUID()
        let registry = CookStepTimerRegistry()
        var inner: CookStepTimerStartOutcome?

        let outer = try await registry.start(step: step) {
            inner = try await registry.start(step: step) { UUID() }
            return alarm
        }

        #expect(inner == .alreadyStarting)
        #expect(outer == .started(alarm))
        #expect(CookStepTimerStartOutcome.alreadyStarting.message(startedMessage: "set") == CookStepTimerStartOutcome.alreadyRunningMessage)
    }

    @Test("a failed start leaves the step free to try again")
    func failedStartFreesStep() async throws {
        let registry = CookStepTimerRegistry()

        await #expect(throws: Failure.self) {
            _ = try await registry.start(step: step) { throw Failure() }
        }
        #expect(registry.alarmID(forStep: step) == nil)

        let alarm = UUID()
        #expect(try await registry.start(step: step) { alarm } == .started(alarm))
    }

    @Test("each step has its own timer")
    func stepsAreIndependent() async throws {
        let first = UUID()
        let second = UUID()
        let registry = CookStepTimerRegistry()

        _ = try await registry.start(step: step) { first }
        let other = try await registry.start(step: otherStep) { second }

        #expect(other == .started(second))
        #expect(registry.alarmIDsByStep == [step: first, otherStep: second])
        #expect(registry.runningStepKeys == [step, otherStep])
    }

    @Test("cancel ends the step's alarm and frees the step")
    func cancelEndsAlarm() async throws {
        let alarm = UUID()
        var saved: [[String: String]] = []
        let registry = CookStepTimerRegistry(persist: { saved.append($0) })
        _ = try await registry.start(step: step) { alarm }
        var cancelled: [UUID] = []

        let didCancel = try registry.cancel(step: step) { cancelled.append($0) }

        #expect(didCancel)
        #expect(cancelled == [alarm])
        #expect(registry.alarmID(forStep: step) == nil)
        #expect(saved.last == [:])
    }

    @Test("cancel on a step with no timer does nothing")
    func cancelWithoutTimer() throws {
        let registry = CookStepTimerRegistry()
        var cancelled: [UUID] = []

        #expect(try registry.cancel(step: step) { cancelled.append($0) } == false)
        #expect(cancelled.isEmpty)
    }

    @Test("a refused cancel keeps the alarm so the cook can try again")
    func refusedCancelKeepsAlarm() async throws {
        let alarm = UUID()
        let registry = CookStepTimerRegistry()
        _ = try await registry.start(step: step) { alarm }

        #expect(throws: Failure.self) { try registry.cancel(step: step) { _ in throw Failure() } }
        #expect(registry.alarmID(forStep: step) == alarm)
    }

    @Test("an alarm stopped from the Live Activity frees its step")
    func forgetFreesStep() async throws {
        let alarm = UUID()
        let kept = UUID()
        let registry = CookStepTimerRegistry()
        _ = try await registry.start(step: step) { alarm }
        _ = try await registry.start(step: otherStep) { kept }

        registry.forget(alarmID: alarm)

        #expect(registry.alarmIDsByStep == [otherStep: kept])
    }

    @Test("alarms the system no longer has are dropped, and an unchanged map is not saved again")
    func reconcileDropsEndedAlarms() async throws {
        let ended = UUID()
        let running = UUID()
        var saves = 0
        let registry = CookStepTimerRegistry(persist: { _ in saves += 1 })
        _ = try await registry.start(step: step) { ended }
        _ = try await registry.start(step: otherStep) { running }

        registry.reconcile(activeAlarmIDs: [running])
        #expect(registry.alarmIDsByStep == [otherStep: running])
        #expect(saves == 3)

        registry.reconcile(activeAlarmIDs: [running])
        #expect(saves == 3)
    }

    @Test("saved timers come back after a relaunch, skipping unreadable IDs")
    func restoresPersistedTimers() {
        let alarm = UUID()
        let registry = CookStepTimerRegistry(persisted: [step: alarm.uuidString, otherStep: "not-a-uuid"])

        #expect(registry.alarmIDsByStep == [step: alarm])
    }
}

@Suite("Journey alarm fixture")
struct NativeJourneyAlarmFixtureTests {
    @Test("the launch environment key turns the stand-in alarm on")
    func environmentKey() {
        #expect(NativeJourneyAlarmFixture.isRequested(environment: [NativeJourneyAlarmFixture.environmentKey: " TRUE "]))
        #expect(NativeJourneyAlarmFixture.isRequested(environment: [NativeJourneyAlarmFixture.environmentKey: "yes"]))
        #expect(NativeJourneyAlarmFixture.isRequested(environment: [NativeJourneyAlarmFixture.environmentKey: "1"]))
        #expect(!NativeJourneyAlarmFixture.isRequested(environment: [NativeJourneyAlarmFixture.environmentKey: "0"]))
        #expect(!NativeJourneyAlarmFixture.isRequested(environment: [:]))
    }
}
