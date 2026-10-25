import Foundation

/// A spring in the design system's vocabulary, in the iOS `response` / `dampingFraction` terms SwiftUI uses.
public struct KitchenSpring: Equatable, Sendable {
    public let response: Double
    public let dampingFraction: Double

    public init(response: Double, dampingFraction: Double) {
        self.response = response
        self.dampingFraction = dampingFraction
    }

    /// Small state changes: a toggle, a chip, a check.
    public static let snappy = KitchenSpring(response: 0.32, dampingFraction: 0.86)
    /// The tab lens and glass controls merging and splitting.
    public static let glide = KitchenSpring(response: 0.42, dampingFraction: 0.82)
    /// Turning a cook step like a page.
    public static let pageTurn = KitchenSpring(response: 0.5, dampingFraction: 0.88)
    /// A cover zooming into its recipe.
    public static let zoom = KitchenSpring(response: 0.45, dampingFraction: 0.9)
    /// The playful bounce on a checked ingredient.
    public static let bounce = KitchenSpring(response: 0.35, dampingFraction: 0.6)
}

/// How a change should move: on its spring, or, with Reduce Motion on, as a short crossfade with no movement.
public enum KitchenMotionStep: Equatable, Sendable {
    case spring(KitchenSpring)
    case crossfade(duration: Double)
}

public enum KitchenMotion {
    /// The crossfade length every spring falls back to under Reduce Motion.
    public static let reducedMotionCrossfadeDuration = 0.2

    /// The one Reduce Motion rule: springs, zooms, page turns and slides become a short crossfade. Callers animate with
    /// the resolved step and, when it is a crossfade, swap any spatial transition for opacity.
    public static func step(_ spring: KitchenSpring, reduceMotion: Bool) -> KitchenMotionStep {
        reduceMotion ? .crossfade(duration: reducedMotionCrossfadeDuration) : .spring(spring)
    }

    /// Whether movement must be replaced by a crossfade.
    public static func crossfades(reduceMotion: Bool) -> Bool {
        reduceMotion
    }
}
