import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook timer board")
struct CookTimerBoardTests {
    static func entry(_ id: String, step: Int, ends: TimeInterval, paused: Bool = false) -> CookTimerEntry {
        CookTimerEntry(id: id, stepNumber: step, label: "Step \(step)", endsAt: Date(timeIntervalSince1970: ends), isPaused: paused)
    }

    @Test func boardOrdersBySoonestEnd() {
        let board = CookTimerBoard(timers: [
            Self.entry("c", step: 3, ends: 300),
            Self.entry("a", step: 1, ends: 100),
            Self.entry("b", step: 2, ends: 200),
        ])
        #expect(board.ordered.map(\.id) == ["a", "b", "c"])
        #expect(board.soonest?.id == "a")
    }

    @Test func emptyBoardHasNoSoonest() {
        #expect(CookTimerBoard(timers: []).soonest == nil)
        #expect(CookTimerBoard(timers: []).ordered.isEmpty)
    }

    @Test func pausedTimersFollowRunningOnesByTimeLeft() {
        // Paused timers keep the endsAt from before the pause, which slides into the past.
        let board = CookTimerBoard(timers: [
            CookTimerEntry(id: "p2", stepNumber: 2, label: "p2", endsAt: Date(timeIntervalSince1970: 1), isPaused: true, pausedRemaining: 90),
            Self.entry("r", step: 5, ends: 500),
            CookTimerEntry(id: "p1", stepNumber: 1, label: "p1", endsAt: Date(timeIntervalSince1970: 2), isPaused: true, pausedRemaining: 30),
            CookTimerEntry(id: "p3", stepNumber: 3, label: "p3", endsAt: Date(timeIntervalSince1970: 3), isPaused: true, pausedRemaining: 90),
        ])
        #expect(board.ordered.map(\.id) == ["r", "p1", "p2", "p3"])
        #expect(board.soonest?.id == "r")
    }

    @Test func tiesKeepStepOrder() {
        let board = CookTimerBoard(timers: [
            Self.entry("b", step: 2, ends: 100),
            Self.entry("a", step: 1, ends: 100),
        ])
        #expect(board.ordered.map(\.id) == ["a", "b"])
    }
}
