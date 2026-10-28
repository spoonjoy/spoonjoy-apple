import Foundation

/// What each Dynamic Island region of the cook session shows. Plain Foundation, because the widget extension
/// compiles this file to draw the island.
public enum CookSessionIslandLayout {
    public enum Leading: Equatable, Sendable {
        /// The timer ring with the step number inside.
        case ring
        case stepLabel(String)
    }

    public enum Trailing: Equatable, Sendable {
        /// Limited-width islands (iPhone Duo) leave trailing empty, as the HIG asks.
        case none
        case checkCount(checked: Int, total: Int)
        case steps(current: Int, total: Int)
    }

    public struct Compact: Equatable, Sendable {
        public let leading: Leading
        public let trailing: Trailing

        public init(leading: Leading, trailing: Trailing) {
            self.leading = leading
            self.trailing = trailing
        }
    }

    public enum Ring: Equatable, Sendable {
        /// A live countdown the system animates between the two dates.
        case timer(start: Date, end: Date)
        /// A still fraction from 0 to 1.
        case fixed(Double)
    }

    /// What a timer's time slot shows.
    public enum Readout: Equatable, Sendable {
        /// A live countdown the system advances to `end`.
        case countdown(end: Date)
        case paused(remaining: TimeInterval)
        /// The countdown reached zero before the next update.
        case done
    }

    public static let doneText = "Done"

    public static func readout(for timer: CookTimerEntry, now: Date) -> Readout {
        if timer.isPaused {
            return .paused(remaining: timer.pausedRemaining ?? 0)
        }
        return timer.endsAt > now ? .countdown(end: timer.endsAt) : .done
    }

    /// The timer's name. Its time goes in the accessibility value, so VoiceOver reads both.
    public static func timerAccessibilityLabel(for timer: CookTimerEntry) -> String {
        "\(timer.label) timer"
    }

    /// When the soonest running timer ends. The activity is marked stale then, so a redraw shows the ended timer as Done
    /// instead of 0:00.
    public static func staleDate(for snapshot: CookSessionSnapshot) -> Date? {
        snapshot.timers.filter { !$0.isPaused }.map(\.endsAt).min()
    }

    /// The session activities to end at launch: those left by an earlier process, never the one this process started.
    public static func staleActivityIDs(launchIDs: [String], current: String?) -> [String] {
        launchIDs.filter { $0 != current }
    }

    public static func compact(for snapshot: CookSessionSnapshot, limitedWidth: Bool) -> Compact {
        guard !limitedWidth else {
            return Compact(leading: .ring, trailing: .none)
        }
        // A running timer does not take this slot: AlarmKit's own activity already shows its countdown.
        let trailing: Trailing
        if snapshot.ingredientCount > 0 {
            trailing = .checkCount(checked: snapshot.checkedCount, total: snapshot.ingredientCount)
        } else {
            trailing = .steps(current: snapshot.stepNumber, total: snapshot.stepCount)
        }
        return Compact(leading: .stepLabel("Step \(snapshot.stepNumber)"), trailing: trailing)
    }

    /// On the iPhone Duo the island is a vertical pill 37 pt across, and the compact region inside it is about this
    /// wide, measured on the iOS 27.1 simulator (not yet on a real Duo). A 28 pt ring reached the pill's sides there.
    public static let limitedWidthCompactRegionWidth: Double = 26
    /// Clear space kept between the ring and the region's edge.
    public static let limitedWidthRingInset: Double = 2

    public static func compactRingDiameter(limitedWidth: Bool) -> Double {
        limitedWidth ? limitedWidthCompactRegionWidth - 2 * limitedWidthRingInset : 28
    }

    public static func minimalRingDiameter(limitedWidth: Bool) -> Double {
        limitedWidth ? compactRingDiameter(limitedWidth: true) : 24
    }

    /// The expanded island keeps the step count beside the timers, so a running timer never hides where you are.
    public static func expandedStepCount(for snapshot: CookSessionSnapshot) -> String {
        "\(snapshot.stepNumber) of \(snapshot.stepCount)"
    }

    /// Timers wrapped two to a row, for when one row would cut the step names short.
    public static func wrappedTimerRows(_ timers: [CookTimerEntry]) -> [[CookTimerEntry]] {
        stride(from: 0, to: timers.count, by: 2).map { Array(timers[$0..<min($0 + 2, timers.count)]) }
    }

    /// Beside the soonest timer when the island has room for only one: how many more run, or nil when it is the only one.
    public static func moreTimersText(count: Int) -> String? {
        count > 1 ? "+\(count - 1)" : nil
    }

    /// The timer the ring follows: the soonest running one, else the soonest paused one.
    public static func featuredTimer(in snapshot: CookSessionSnapshot) -> CookTimerEntry? {
        snapshot.timers.first { !$0.isPaused } ?? snapshot.timers.first
    }

    public static func ring(for snapshot: CookSessionSnapshot) -> Ring {
        guard let timer = featuredTimer(in: snapshot) else {
            return .fixed(snapshot.stepCount > 0 ? Double(snapshot.stepNumber) / Double(snapshot.stepCount) : 0)
        }
        guard timer.isPaused else {
            return .timer(start: timer.endsAt.addingTimeInterval(-timer.duration), end: timer.endsAt)
        }
        guard timer.duration > 0 else {
            return .fixed(1)
        }
        return .fixed(1 - (timer.pausedRemaining ?? 0) / timer.duration)
    }

    public static func ringNumber(for snapshot: CookSessionSnapshot) -> String {
        snapshot.stepNumber > 0 ? "\(snapshot.stepNumber)" : ""
    }

    public static func accessibilityLabel(for snapshot: CookSessionSnapshot) -> String {
        guard snapshot.stepNumber > 0 else {
            return "Cook mode"
        }
        let step = "Step \(snapshot.stepNumber) of \(snapshot.stepCount), \(snapshot.stepTitle)"
        guard let timer = featuredTimer(in: snapshot) else {
            return step
        }
        return "\(step). \(timer.label) timer \(timer.isPaused ? "paused" : "running")"
    }

    /// "3:12", or "1:02:05" past an hour.
    public static func clockText(remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        guard hours > 0 else {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    /// "Paused 3:12", or "Paused 1:02:05" past an hour.
    public static func pausedText(remaining: TimeInterval) -> String {
        "Paused \(clockText(remaining: remaining))"
    }
}
