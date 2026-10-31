import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Launch replay of pending cook progress")
struct NativeLaunchPendingRecordsTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)

    private static func stamp(_ secondsAgo: TimeInterval) -> String {
        NativeLiveAppStoreClock.isoString(now.addingTimeInterval(-secondsAgo))
    }

    private static func progress(_ recipeID: String, step: String, secondsAgo: TimeInterval) throws -> CookModeProgress {
        try CookModeProgress(recipeID: recipeID, stepIDs: ["s1", "s2", "s3"], startedAt: stamp(3_600))
            .selectingStep(id: step, updatedAt: stamp(secondsAgo))
    }

    private static func replay(_ pending: [CookModeProgress], over current: [String: CookModeProgress] = [:]) -> [CookModeProgress] {
        NativeLaunchPendingRecords(cookProgress: pending).progressToReplay(over: current, at: now)
    }

    @Test("only the newest progress per recipe replays, whatever order it was recorded in")
    func newestPerRecipeWins() throws {
        let stepThree = try Self.progress("r1", step: "s3", secondsAgo: 60)
        let stepTwo = try Self.progress("r1", step: "s2", secondsAgo: 120)
        let other = try Self.progress("r2", step: "s2", secondsAgo: 90)
        let replayed = Self.replay([stepThree, other, stepTwo])
        #expect(replayed == [stepThree, other])
        #expect(Self.replay([stepTwo, stepThree]) == [stepThree])
    }

    @Test("progress older than what the kitchen already holds is not replayed")
    func olderThanCurrentIsSkipped() throws {
        let pending = try Self.progress("r1", step: "s2", secondsAgo: 300)
        let current = try Self.progress("r1", step: "s3", secondsAgo: 60)
        #expect(Self.replay([pending], over: ["r1": current]).isEmpty)
        // Progress the kitchen already holds is not newer, so a record left by a failed clear replays as a no-op.
        #expect(Self.replay([pending], over: ["r1": pending]) == [pending])
    }

    @Test("progress recorded more than a day ago is not replayed")
    func staleRecordsAreDropped() throws {
        let stale = try Self.progress("r1", step: "s2", secondsAgo: NativeLaunchPendingRecords.replayWindow + 1)
        let fresh = try Self.progress("r2", step: "s2", secondsAgo: NativeLaunchPendingRecords.replayWindow - 1)
        #expect(Self.replay([stale, fresh]) == [fresh])
    }

    // A record without a readable time cannot be aged, so a failed clear would replay it on every launch.
    @Test("progress without a readable time is not replayed")
    func untimedProgressIsDropped() throws {
        let first = CookModeProgress(recipeID: "r1", completedStepIDs: [], currentStepID: "s1")
        let second = CookModeProgress(recipeID: "r2", completedStepIDs: ["s1"], currentStepID: "s2")
        #expect(Self.replay([first, second]).isEmpty)
        let timed = try Self.progress("r2", step: "s3", secondsAgo: 60)
        #expect(Self.replay([first, timed, second]) == [timed])
    }

    @Test("a timed record beats an untimed one for the same recipe")
    func timedBeatsUntimed() throws {
        let untimed = CookModeProgress(recipeID: "r1", completedStepIDs: ["s1"], currentStepID: "s2")
        let timed = try Self.progress("r1", step: "s3", secondsAgo: 60)
        #expect(Self.replay([timed, untimed]) == [timed])
    }
}
