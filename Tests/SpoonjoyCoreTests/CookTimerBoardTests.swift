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

    @Test func tiesKeepStepOrder() {
        let board = CookTimerBoard(timers: [
            Self.entry("b", step: 2, ends: 100),
            Self.entry("a", step: 1, ends: 100),
        ])
        #expect(board.ordered.map(\.id) == ["a", "b"])
    }
}
