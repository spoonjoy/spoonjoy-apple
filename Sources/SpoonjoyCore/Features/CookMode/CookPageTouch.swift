import Foundation

/// One touch on the cook pager. A control on a page moves with the finger during a page turn, so the touch that turned
/// the page would also tap the ring, a check or Cancel when it lifts. Each control asks this first: once the finger has
/// moved past the tap slop in any direction, the touch is a drag (a page turn or a scroll) and lifting it is not a tap.
///
/// SwiftUI gives a quick tap to the control before the pager sees the new touch begin, so a drag cannot wait for the
/// next touch to clear it. Instead a drag stops counting a short grace after its finger lifts.
public struct CookPageTouch: Equatable, Sendable {
    /// How far a finger may wander and still tap, in points. It matches the 10 pt UIKit allows a tap before a scroll
    /// view claims the touch, and is below the pager's 16 pt minimum drag, so every page turn counts as a drag.
    public static let tapSlop: Double = 10
    /// How long after a drag lifts its own lift may still reach a control. On the iPhone Duo simulator the control's
    /// action arrived 18–79 ms before the pager heard of the lift, so the drag is still under way when it asks; the
    /// grace covers the order flipping on a busy main thread. Only a tap within it of a swipe's lift is dropped.
    public static let liftGrace: TimeInterval = 0.25

    private var startX: Double?
    private var startY: Double?
    private var isDrag = false
    private var liftedAt: Date?

    public init() {}

    /// Called with each drag update for the touch. The start location tells a new touch apart.
    public mutating func moved(startX: Double, startY: Double, dx: Double, dy: Double) {
        if startX != self.startX || startY != self.startY {
            self.startX = startX
            self.startY = startY
            isDrag = false
        }
        liftedAt = nil
        if (dx * dx + dy * dy).squareRoot() > Self.tapSlop {
            isDrag = true
        }
    }

    /// The finger lifted, or the system took the touch (a scroll view claiming it).
    public mutating func ended(at date: Date) {
        liftedAt = date
    }

    public func allowsTap(at date: Date) -> Bool {
        guard isDrag else {
            return true
        }
        guard let liftedAt else {
            return false
        }
        return date.timeIntervalSince(liftedAt) > Self.liftGrace
    }
}
