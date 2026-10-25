import Foundation

/// Step paging math for the cook-mode pager.
public enum CookPageTurn {
    static let commitFraction = 0.33
    static let commitVelocity = 600.0

    /// The page to settle on. A drag left (negative) moves forward. The turn commits at a third of the page or a fast
    /// flick, and the result stays inside `0..<count`.
    public static func target(from index: Int, count: Int, dragFraction: Double, velocity: Double) -> Int {
        let last = max(count - 1, 0)
        let current = min(max(index, 0), last)
        guard abs(dragFraction) >= commitFraction || abs(velocity) >= commitVelocity else {
            return current
        }
        let direction = abs(dragFraction) >= commitFraction ? dragFraction : velocity
        let step = direction < 0 ? 1 : -1
        return min(max(current + step, 0), last)
    }

    /// Resistance when dragging past the first or last page: grows with the offset but never reaches `limit`.
    public static func rubberBand(offset: Double, limit: Double) -> Double {
        guard limit > 0, offset != 0 else {
            return 0
        }
        let magnitude = limit * (1 - 1 / (abs(offset) / limit * 0.55 + 1))
        return offset < 0 ? -magnitude : magnitude
    }
}
