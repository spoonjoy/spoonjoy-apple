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

    @Test func fullWidthWithATimerStillShowsTheCheckCount() {
        // AlarmKit's own activity shows the countdown, so the session keeps its check count beside a running timer.
        let compact = CookSessionIslandLayout.compact(for: Self.snapshot(timers: [Self.timer(endsIn: 60)]), limitedWidth: false)
        #expect(compact == CookSessionIslandLayout.Compact(leading: .stepLabel("Step 2"), trailing: .checkCount(checked: 1, total: 3)))
        let noIngredients = CookSessionIslandLayout.compact(for: Self.snapshot(ingredients: 0, timers: [Self.timer(endsIn: 60)]), limitedWidth: false)
        #expect(noIngredients.trailing == .steps(current: 2, total: 4))
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

    @Test func readoutCountsDownARunningTimerUntilItEnds() {
        let timer = Self.timer(endsIn: 60)
        #expect(CookSessionIslandLayout.readout(for: timer, now: Self.t0) == .countdown(end: Self.t0.addingTimeInterval(60)))
        #expect(CookSessionIslandLayout.readout(for: timer, now: Self.t0.addingTimeInterval(59)) == .countdown(end: Self.t0.addingTimeInterval(60)))
    }

    @Test func readoutSaysDoneOnceARunningTimerHasEnded() {
        let timer = Self.timer(endsIn: 60)
        #expect(CookSessionIslandLayout.readout(for: timer, now: Self.t0.addingTimeInterval(60)) == .done)
        #expect(CookSessionIslandLayout.readout(for: timer, now: Self.t0.addingTimeInterval(600)) == .done)
    }

    @Test func readoutHoldsAPausedTimer() {
        let paused = Self.timer(endsIn: -100, pausedRemaining: 192)
        #expect(CookSessionIslandLayout.readout(for: paused, now: Self.t0) == .paused(remaining: 192))
        let pausedWithoutTime = CookTimerEntry(id: "k", stepNumber: 2, label: "Simmer", endsAt: Self.t0, isPaused: true, duration: 600)
        #expect(CookSessionIslandLayout.readout(for: pausedWithoutTime, now: Self.t0) == .paused(remaining: 0))
    }

    @Test func doneTextIsShort() {
        #expect(CookSessionIslandLayout.doneText == "Done")
    }

    @Test func timerAccessibilityLabelNamesTheTimerAndLeavesTheTimeToTheValue() {
        #expect(CookSessionIslandLayout.timerAccessibilityLabel(for: Self.timer(endsIn: 60)) == "Simmer timer")
    }

    @Test func staleDateIsTheSoonestRunningTimersEnd() {
        let later = CookTimerEntry(id: "r1#s3", stepNumber: 3, label: "Rest", endsAt: Self.t0.addingTimeInterval(300), isPaused: false, duration: 300)
        let sooner = Self.timer(endsIn: 60)
        let paused = Self.timer(endsIn: 5, pausedRemaining: 5)
        #expect(CookSessionIslandLayout.staleDate(for: Self.snapshot(timers: [later, paused, sooner])) == Self.t0.addingTimeInterval(60))
        #expect(CookSessionIslandLayout.staleDate(for: Self.snapshot(timers: [paused])) == nil)
        #expect(CookSessionIslandLayout.staleDate(for: Self.snapshot()) == nil)
    }

    @Test func launchCleanupEndsOnlyActivitiesLeftFromBeforeLaunch() {
        #expect(CookSessionIslandLayout.staleActivityIDs(launchIDs: ["a", "b"], current: nil) == ["a", "b"])
        #expect(CookSessionIslandLayout.staleActivityIDs(launchIDs: ["a", "b"], current: "b") == ["a"])
        #expect(CookSessionIslandLayout.staleActivityIDs(launchIDs: [], current: "c").isEmpty)
    }

    // MARK: - iPhone Duo fixes

    @Test func limitedWidthRingsFitTheNarrowIsland() {
        // The Duo's island is a narrow vertical pill; a 28 pt ring overflowed it.
        #expect(CookSessionIslandLayout.compactRingDiameter(limitedWidth: true) == 22)
        #expect(CookSessionIslandLayout.minimalRingDiameter(limitedWidth: true) == 22)
        #expect(CookSessionIslandLayout.minimalRingDiameter(limitedWidth: false) == 24)
        #expect(CookSessionIslandLayout.compactRingDiameter(limitedWidth: false) == 28)
        let ringWithInset = CookSessionIslandLayout.compactRingDiameter(limitedWidth: true)
            + 2 * CookSessionIslandLayout.limitedWidthRingInset
        #expect(ringWithInset <= CookSessionIslandLayout.limitedWidthCompactRegionWidth)
    }

    @Test func hiddenTimersReadAsACountWithSingularAndPlural() {
        #expect(CookSessionIslandLayout.hiddenTimersText(hidden: -1) == nil)
        #expect(CookSessionIslandLayout.hiddenTimersText(hidden: 0) == nil)
        #expect(CookSessionIslandLayout.hiddenTimersText(hidden: 2) == "+2")
        #expect(CookSessionIslandLayout.hiddenTimersAccessibilityLabel(hidden: 0) == nil)
        #expect(CookSessionIslandLayout.hiddenTimersAccessibilityLabel(hidden: 1) == "1 more timer")
        #expect(CookSessionIslandLayout.hiddenTimersAccessibilityLabel(hidden: 2) == "2 more timers")
    }

    @Test func fourAndFiveTimersCountPastTheCap() {
        let three = [Self.named("a", endsIn: 60), Self.named("b", endsIn: 120), Self.named("c", endsIn: 180)]
        for total in [4, 5] {
            let snapshot = CookSessionSnapshot(
                recipeID: "r1", recipeTitle: "Soup", stepNumber: 1, stepCount: 2, stepTitle: "Simmer", stepText: "",
                nextStepTitle: nil, checkedCount: 0, ingredientCount: 0, timers: three, timerCount: total
            )
            let count = CookSessionIslandLayout.totalTimerCount(in: snapshot)
            #expect(count == total)
            // The island shows one chip, so it counts every other timer in the session.
            #expect(CookSessionIslandLayout.hiddenTimersText(hidden: count - 1) == "+\(total - 1)")
            #expect(CookSessionIslandLayout.hiddenTimersAccessibilityLabel(hidden: count - 1) == "\(total - 1) more timers")
            // The Lock Screen shows the three it was sent, so it counts the ones past the cap.
            #expect(CookSessionIslandLayout.hiddenTimersText(hidden: count - three.count) == "+\(total - 3)")
        }
        // A count lower than the timers sent can't hide them.
        let stale = CookSessionSnapshot(
            recipeID: "r1", recipeTitle: "Soup", stepNumber: 1, stepCount: 2, stepTitle: "Simmer", stepText: "",
            nextStepTitle: nil, checkedCount: 0, ingredientCount: 0, timers: three, timerCount: 1
        )
        #expect(CookSessionIslandLayout.totalTimerCount(in: stale) == 3)
    }

    @Test func threeTimersAtStandardSizesTakeTheLockScreenStepText() {
        #expect(!CookSessionIslandLayout.lockScreenTimersTakeStepText(timerCount: 2, accessibilitySize: false))
        #expect(CookSessionIslandLayout.lockScreenTimersTakeStepText(timerCount: 3, accessibilitySize: false))
        #expect(!CookSessionIslandLayout.lockScreenTimersTakeStepText(timerCount: 3, accessibilitySize: true))
    }

    static func named(_ id: String, endsIn: TimeInterval, pausedRemaining: TimeInterval? = nil) -> CookTimerEntry {
        CookTimerEntry(
            id: id, stepNumber: 1, label: id, endsAt: t0.addingTimeInterval(endsIn),
            isPaused: pausedRemaining != nil, duration: 7_200, pausedRemaining: pausedRemaining
        )
    }

    @Test func timersSortRunningByEndTimeThenPausedByTimeLeft() {
        // A paused timer's endsAt is stale, so "pausedLong" ending first must not put it ahead of the running ones.
        let timers = [
            Self.named("simmer", endsIn: 7_140),
            Self.named("pausedLong", endsIn: 10, pausedRemaining: 900),
            Self.named("roast", endsIn: 1_500),
            Self.named("pausedShort", endsIn: 20, pausedRemaining: 60),
            Self.named("rest", endsIn: 480),
            // Paused with no time left recorded counts as none left.
            CookTimerEntry(id: "pausedUnknown", stepNumber: 1, label: "pausedUnknown", endsAt: Self.t0, isPaused: true),
        ]
        #expect(CookSessionIslandLayout.timersBySoonest(timers).map(\.id) == ["rest", "roast", "simmer", "pausedUnknown", "pausedShort", "pausedLong"])
        #expect(CookSessionIslandLayout.timersBySoonest(timers.reversed()).map(\.id) == ["rest", "roast", "simmer", "pausedUnknown", "pausedShort", "pausedLong"])
    }

    @Test func theRingAndIslandFollowTheSoonestTimerWhateverTheOrder() {
        let snapshot = Self.snapshot(timers: [
            Self.named("simmer", endsIn: 7_140),
            Self.named("roast", endsIn: 1_500),
            Self.named("rest", endsIn: 480),
        ])
        #expect(CookSessionIslandLayout.featuredTimer(in: snapshot)?.id == "rest")
        #expect(CookSessionIslandLayout.ring(for: snapshot) == .timer(start: Self.t0.addingTimeInterval(480 - 7_200), end: Self.t0.addingTimeInterval(480)))
        let allPaused = Self.snapshot(timers: [Self.named("long", endsIn: 0, pausedRemaining: 900), Self.named("short", endsIn: 0, pausedRemaining: 60)])
        #expect(CookSessionIslandLayout.featuredTimer(in: allPaused)?.id == "short")
    }

    @Test func expandedTrailingKeepsTheStepCountBesideTimers() {
        let none = Self.snapshot()
        let some = Self.snapshot(timers: [Self.timer(endsIn: 60)])
        #expect(CookSessionIslandLayout.expandedStepCount(for: none) == "2 of 4")
        #expect(CookSessionIslandLayout.expandedStepCount(for: some) == "2 of 4")
    }

    @Test func timerRowsKeepUpToTwoChipsPerRowWhenWrapped() {
        let timers = (1...3).map { index in
            CookTimerEntry(id: "k\(index)", stepNumber: index, label: "Step \(index)", endsAt: Self.t0, isPaused: false)
        }
        #expect(CookSessionIslandLayout.wrappedTimerRows(timers).map { $0.map(\.id) } == [["k1", "k2"], ["k3"]])
        #expect(CookSessionIslandLayout.wrappedTimerRows(Array(timers.prefix(2))).map { $0.map(\.id) } == [["k1", "k2"]])
        #expect(CookSessionIslandLayout.wrappedTimerRows(Array(timers.prefix(1))).map { $0.map(\.id) } == [["k1"]])
        #expect(CookSessionIslandLayout.wrappedTimerRows([]).isEmpty)
    }
}
