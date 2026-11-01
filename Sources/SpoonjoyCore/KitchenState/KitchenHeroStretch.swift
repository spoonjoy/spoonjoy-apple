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

    /// Under Reduce Motion the photo stays still, so a pull opens a gap above it; the hero fills that gap with its
    /// own dark ground instead of the page's paper. Zero when the photo stretches to cover it.
    public static func stillPhotoFill(pull: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? max(0, pull) : 0
    }

    /// Whether the bar's top scroll edge effect shows. At rest, or pulled past the top, the photo meets the screen
    /// edge with nothing over it; once the page scrolls, the effect sits behind the bar buttons so the dish's title
    /// never runs bare under them. `scrollOffset` is the content offset plus the top inset.
    public static func showsTopEdgeEffect(scrollOffset: Double) -> Bool {
        scrollOffset > 1
    }

    /// The recipe hero's height: half the page on a short page (under 1.2 times `preferred`), and `preferred` from
    /// 1.6 times `preferred` up, rising in a straight line between at one point per point of page, so resizing a
    /// window or a split view never makes the photo jump or outrun the resize. On a closed foldable held sideways the
    /// recipe sheet and the offline status at its top then start on the first screen; a phone held upright keeps the
    /// full photo. A page not yet measured (`viewportHeight` 0) gets `preferred`.
    public static func heroHeight(preferred: Double, viewportHeight: Double) -> Double {
        let rampStart = preferred * 1.2
        let rampEnd = preferred * 1.6
        guard viewportHeight > 0, viewportHeight < rampEnd else {
            return preferred
        }
        guard viewportHeight > rampStart else {
            return viewportHeight / 2
        }
        let progress = (viewportHeight - rampStart) / (rampEnd - rampStart)
        return rampStart / 2 + progress * (preferred - rampStart / 2)
    }
}
