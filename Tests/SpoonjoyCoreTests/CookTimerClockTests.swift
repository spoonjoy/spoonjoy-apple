import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook timer clock")
struct CookTimerClockTests {
    static let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    static let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    static let t0 = Date(timeIntervalSince1970: 1_000)

    static var recipe: Recipe {
        CookSessionSnapshotTests.recipe(steps: CookSessionSnapshotTests.steps)
    }

    @Test func startRecordsTheEndDate() {
        var clock = CookTimerClock()
        clock.start(alarmID: Self.a, duration: 600, now: Self.t0)
        let record = clock.records[Self.a.uuidString]
        #expect(record == CookTimerClock.Record(duration: 600, endsAt: Self.t0.addingTimeInterval(600), pausedRemaining: nil))
    }

    @Test func pauseFreezesTheRemainingTimeAndResumeMovesTheEnd() {
        var clock = CookTimerClock()
        clock.start(alarmID: Self.a, duration: 600, now: Self.t0)
        clock.pause(alarmID: Self.a, now: Self.t0.addingTimeInterval(100))
        #expect(clock.records[Self.a.uuidString]?.pausedRemaining == 500)

        // A second pause keeps the first remaining time.
        clock.pause(alarmID: Self.a, now: Self.t0.addingTimeInterval(300))
        #expect(clock.records[Self.a.uuidString]?.pausedRemaining == 500)

        clock.resume(alarmID: Self.a, now: Self.t0.addingTimeInterval(1_000))
        let resumed = clock.records[Self.a.uuidString]
        #expect(resumed?.pausedRemaining == nil)
        #expect(resumed?.endsAt == Self.t0.addingTimeInterval(1_500))
        #expect(resumed?.duration == 600)
    }

    @Test func pauseAfterTheEndKeepsNoNegativeTime() {
        var clock = CookTimerClock()
        clock.start(alarmID: Self.a, duration: 60, now: Self.t0)
        clock.pause(alarmID: Self.a, now: Self.t0.addingTimeInterval(120))
        #expect(clock.records[Self.a.uuidString]?.pausedRemaining == 0)
    }

    @Test func resumeOfARunningTimerAndUnknownAlarmsAreIgnored() {
        var clock = CookTimerClock()
        clock.start(alarmID: Self.a, duration: 600, now: Self.t0)
        let before = clock
        clock.resume(alarmID: Self.a, now: Self.t0.addingTimeInterval(50))
        clock.pause(alarmID: Self.b, now: Self.t0)
        clock.resume(alarmID: Self.b, now: Self.t0)
        #expect(clock == before)
    }

    @Test func retainDropsEndedAlarms() {
        var clock = CookTimerClock()
        clock.start(alarmID: Self.a, duration: 600, now: Self.t0)
        clock.start(alarmID: Self.b, duration: 60, now: Self.t0)
        clock.retain(activeAlarmIDs: [Self.b])
        #expect(Set(clock.records.keys) == [Self.b.uuidString])
    }

    @Test func boardJoinsTheRegistryWithTheClockForOneRecipe() {
        var clock = CookTimerClock()
        clock.start(alarmID: Self.a, duration: 600, now: Self.t0)
        clock.start(alarmID: Self.b, duration: 300, now: Self.t0)
        clock.pause(alarmID: Self.b, now: Self.t0.addingTimeInterval(60))
        let other = UUID()
        clock.start(alarmID: other, duration: 60, now: Self.t0)
        let board = clock.board(recipe: Self.recipe, alarmIDsByStep: [
            "r1#s2": Self.a,
            "r1#s1": Self.b,
            "r2#s1": other,
            // A step whose alarm the clock never saw has no end date, so it is left out.
            "r1#s3": UUID(),
        ])
        // The running timer comes first; the paused one follows by time left, whatever its stale end date.
        #expect(board.ordered == [
            CookTimerEntry(id: "r1#s2", stepNumber: 2, label: "Step 2", endsAt: Self.t0.addingTimeInterval(600), isPaused: false, duration: 600, pausedRemaining: nil),
            CookTimerEntry(id: "r1#s1", stepNumber: 1, label: "Chop", endsAt: Self.t0.addingTimeInterval(300), isPaused: true, duration: 300, pausedRemaining: 240),
        ])
    }

    @Test func clockRoundTripsCodable() throws {
        var clock = CookTimerClock()
        clock.start(alarmID: Self.a, duration: 600, now: Self.t0)
        clock.pause(alarmID: Self.a, now: Self.t0.addingTimeInterval(10))
        let data = try JSONEncoder().encode(clock)
        #expect(try JSONDecoder().decode(CookTimerClock.self, from: data) == clock)
        #expect(CookTimerClock(records: clock.records) == clock)
    }
}
