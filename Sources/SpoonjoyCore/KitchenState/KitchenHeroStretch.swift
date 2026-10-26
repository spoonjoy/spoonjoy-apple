import Foundation

/// The Kitchen hero's pull-to-stretch: pulling the page down past its top grows the photo from its top edge,
/// so it always reaches the screen's top. Reduce Motion keeps the photo still.
public enum KitchenHeroStretch {
    /// How far past its top the page is pulled, in points; zero while it scrolls normally.
    public static func pull(contentOffsetY: Double, topInset: Double) -> Double {
        max(0, -(contentOffsetY + topInset))
    }

    /// The photo's scale, anchored at the top, so a hero `heroHeight` tall grows by exactly `pull`.
    public static func scale(pull: Double, heroHeight: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion, heroHeight > 0 else {
            return 1
        }
        return 1 + max(0, pull) / heroHeight
    }
}
