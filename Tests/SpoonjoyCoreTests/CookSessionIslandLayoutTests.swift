import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook session Dynamic Island layout")
struct CookSessionIslandLayoutTests {
    static let t0 = Date(timeIntervalSince1970: 1_000)

    static func snapshot(step: Int = 2, of count: Int = 4, checked: Int = 1, ingredients: Int = 3, timers: [CookTimerEntry] = []) -> CookSessionSnapshot {
        CookSessionSnapshot(
            recipeID: "r1", recipeTitle: "Soup", stepNumber: step, stepCount: count,
            stepTitle: "Simmer", stepText: "Simmer gently.", nextStepTitle: "Serve",
            checkedCount: checked, ingredientCount: ingredients, timers: timers
        )
    }

    static func timer(endsIn: TimeInterval, duration: TimeInterval = 600, pausedRemaining: TimeInterval? = nil) -> CookTimerEntry {
        CookTimerEntry(
            id: "r1#s2", stepNumber: 2, label: "Simmer", endsAt: t0.addingTimeInterval(endsIn),
            isPaused: pausedRemaining != nil, duration: duration, pausedRemaining: pausedRemaining
        )
    }

    @Test func limitedWidthUsesLeadingRingOnlyAndLeavesTrailingEmpty() {
        let compact = CookSessionIslandLayout.compact(for: Self.snapshot(), limitedWidth: true)
        #expect(compact == CookSessionIslandLayout.Compact(leading: .ring, trailing: .none))
    }

    @Test func fullWidthShowsTheStepAndTheCheckCount() {
        let compact = CookSessionIslandLayout.compact(for: Self.snapshot(), limitedWidth: false)
        #expect(compact == CookSessionIslandLayout.Compact(leading: .stepLabel("Step 2"), trailing: .checkCount(checked: 1, total: 3)))
    }

    @Test func fullWidthWithATimerShowsTheRingInsteadOfTheCount() {
        let compact = CookSessionIslandLayout.compact(for: Self.snapshot(timers: [Self.timer(endsIn: 60)]), limitedWidth: false)
        #expect(compact == CookSessionIslandLayout.Compact(leading: .stepLabel("Step 2"), trailing: .ring))
    }

    @Test func fullWidthWithoutIngredientsCountsSteps() {
        let compact = CookSessionIslandLayout.compact(for: Self.snapshot(ingredients: 0), limitedWidth: false)
        #expect(compact.trailing == .steps(current: 2, total: 4))
    }

    @Test func ringFollowsTheSoonestRunningTimer() {
        let timer = Self.timer(endsIn: 300)
        let ring = CookSessionIslandLayout.ring(for: Self.snapshot(timers: [timer]))
        #expect(ring == .timer(start: Self.t0.addingTimeInterval(-300), end: Self.t0.addingTimeInterval(300)))
    }

    @Test func pausedTimerFreezesTheRing() {
        let ring = CookSessionIslandLayout.ring(for: Self.snapshot(timers: [Self.timer(endsIn: 0, duration: 600, pausedRemaining: 150)]))
        #expect(ring == .fixed(0.75))
    }

    @Test func pausedTimerWithoutARemainingTimeReadsAsDone() {
        let timer = CookTimerEntry(id: "k", stepNumber: 2, label: "Simmer", endsAt: Self.t0, isPaused: true, duration: 600)
        #expect(CookSessionIslandLayout.ring(for: Self.snapshot(timers: [timer])) == .fixed(1))
    }

    @Test func ringPrefersARunningTimerOverAPausedOneThatEndsSooner() {
        let paused = Self.timer(endsIn: 10, pausedRemaining: 100)
        let running = CookTimerEntry(id: "r1#s3", stepNumber: 3, label: "Rest", endsAt: Self.t0.addingTimeInterval(60), isPaused: false, duration: 60)
        #expect(CookSessionIslandLayout.ring(for: Self.snapshot(timers: [paused, running])) == .timer(start: Self.t0, end: Self.t0.addingTimeInterval(60)))
    }

    @Test func zeroLengthPausedTimerReadsAsFull() {
        let ring = CookSessionIslandLayout.ring(for: Self.snapshot(timers: [Self.timer(endsIn: 0, duration: 0, pausedRemaining: 0)]))
        #expect(ring == .fixed(1))
    }

    @Test func withoutTimersTheRingShowsStepProgress() {
        #expect(CookSessionIslandLayout.ring(for: Self.snapshot(step: 1, of: 4)) == .fixed(0.25))
        #expect(CookSessionIslandLayout.ring(for: Self.snapshot(step: 0, of: 0)) == .fixed(0))
    }

    @Test func ringNumberIsTheStep() {
        #expect(CookSessionIslandLayout.ringNumber(for: Self.snapshot(step: 3)) == "3")
        #expect(CookSessionIslandLayout.ringNumber(for: Self.snapshot(step: 0, of: 0)) == "")
    }

    @Test func accessibilityLabelNamesTheStepAndTimerState() {
        #expect(CookSessionIslandLayout.accessibilityLabel(for: Self.snapshot()) == "Step 2 of 4, Simmer")
        #expect(
            CookSessionIslandLayout.accessibilityLabel(for: Self.snapshot(timers: [Self.timer(endsIn: 60)]))
                == "Step 2 of 4, Simmer. Simmer timer running"
        )
        #expect(
            CookSessionIslandLayout.accessibilityLabel(for: Self.snapshot(timers: [Self.timer(endsIn: 0, pausedRemaining: 30)]))
                == "Step 2 of 4, Simmer. Simmer timer paused"
        )
        #expect(CookSessionIslandLayout.accessibilityLabel(for: Self.snapshot(step: 0, of: 0)) == "Cook mode")
    }

    @Test func clockTextIsTheTimeAloneForTightSpaces() {
        #expect(CookSessionIslandLayout.clockText(remaining: 2_520) == "42:00")
        #expect(CookSessionIslandLayout.clockText(remaining: 3_725) == "1:02:05")
        #expect(CookSessionIslandLayout.clockText(remaining: -1) == "0:00")
    }

    @Test func pausedTimerTextShowsMinutesAndSeconds() {
        #expect(CookSessionIslandLayout.pausedText(remaining: 192) == "Paused 3:12")
        #expect(CookSessionIslandLayout.pausedText(remaining: 3_725) == "Paused 1:02:05")
        #expect(CookSessionIslandLayout.pausedText(remaining: -4) == "Paused 0:00")
    }
}
