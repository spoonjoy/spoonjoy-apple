import Foundation

/// How a page's masthead fades as it scrolls up under the navigation bar. The bar's scroll edge
/// frosts whatever passes beneath it, so a masthead that stayed opaque would show through as a
/// blurred ghost of its title behind the back button. Fading it over its first stretch of travel
/// means it is gone before it reaches the bar.
public enum MastheadScrollFade {
    /// The scroll distance, in points, over which the masthead goes from fully shown to hidden.
    public static let fadeDistance: Double = 72

    /// The masthead's opacity after the page has scrolled `scrolledDistance` points past its
    /// resting position: 1 at rest (and while overscrolling down), 0 once it has travelled
    /// `fadeDistance`, linear in between.
    public static func opacity(scrolledDistance: Double) -> Double {
        guard !scrolledDistance.isNaN, scrolledDistance > 0 else { return 1 }
        return max(0, 1 - scrolledDistance / fadeDistance)
    }
}
