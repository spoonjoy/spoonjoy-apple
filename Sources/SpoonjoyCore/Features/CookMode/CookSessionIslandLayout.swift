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
        /// The timer ring with no digits, because AlarmKit's own activity already shows the countdown.
        case ring
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

    public static func compact(for snapshot: CookSessionSnapshot, limitedWidth: Bool) -> Compact {
        guard !limitedWidth else {
            return Compact(leading: .ring, trailing: .none)
        }
        let trailing: Trailing
        if !snapshot.timers.isEmpty {
            trailing = .ring
        } else if snapshot.ingredientCount > 0 {
            trailing = .checkCount(checked: snapshot.checkedCount, total: snapshot.ingredientCount)
        } else {
            trailing = .steps(current: snapshot.stepNumber, total: snapshot.stepCount)
        }
        return Compact(leading: .stepLabel("Step \(snapshot.stepNumber)"), trailing: trailing)
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

    /// "Paused 3:12", or "Paused 1:02:05" past an hour.
    public static func pausedText(remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        guard hours > 0 else {
            return String(format: "Paused %d:%02d", minutes, seconds)
        }
        return String(format: "Paused %d:%02d:%02d", hours, minutes, seconds)
    }
}
