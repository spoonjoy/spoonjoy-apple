import Foundation

/// How far a foldable's hinge is open, as the system reports it.
///
/// Mirrors `UIHinge.Status` / SwiftUI's `DeviceHinge.Status` (iOS 27.1) so the layout decision stays testable without
/// the SDK. `unknown` covers every screen with no hinge and every OS or SDK that cannot say.
public enum HingePosture: Equatable, Sendable {
    case unknown
    case closed
    case partiallyOpen
    case fullyOpen
}

/// A horizontal band of the screen that content must stay out of: the fold of a foldable held tall.
///
/// Built with the iOS 27.1 SDK, the app reads the Reserved Region `.division` rect and converts it with
/// `FoldBand(frameMinY:...)`. A vertical fold (the screen held like a book) is a `SpreadDivision` instead.
public struct FoldBand: Equatable, Sendable {
    public let minY: Double
    public let height: Double

    public init(minY: Double, height: Double) {
        self.minY = minY
        self.height = height
    }

    public var maxY: Double {
        minY + height
    }

    /// Converts a division rect reported by the system into a horizontal band of the container.
    ///
    /// The rect is in the container's coordinates. It must be a horizontal fold: wider than it is tall, at least half
    /// as wide as the container and shorter than the container, otherwise this returns nil. A seamless fold reports a
    /// zero-height rect, which is still a fold. The band is clamped to the container's height.
    public init?(
        frameMinY: Double,
        frameHeight: Double,
        frameWidth: Double,
        containerWidth: Double,
        containerHeight: Double
    ) {
        guard frameHeight >= 0,
              frameHeight < containerHeight,
              frameWidth >= containerWidth / 2,
              frameWidth > frameHeight
        else {
            return nil
        }
        let minY = max(0, frameMinY)
        let maxY = min(containerHeight, frameMinY + frameHeight)
        guard maxY >= minY, minY > 0, maxY < containerHeight else {
            return nil
        }
        self.init(minY: minY, height: maxY - minY)
    }
}

/// A vertical slice of a tabletop layout: the half above the fold, the fold band, or the half below.
public struct TabletopRow: Equatable, Sendable {
    public let minY: Double
    public let height: Double

    public init(minY: Double, height: Double) {
        self.minY = minY
        self.height = height
    }

    public var maxY: Double {
        minY + height
    }
}

/// Whether cook mode on a tall screen splits at a horizontal fold, like a laptop standing on the counter: the step
/// above the fold, facing the cook, and the controls below it, flat on the counter.
///
/// The iPhone Duo's inner screen folds across the middle when it is held tall. Stood half-open on the counter it is a
/// tiny laptop; laid fully open the fold still creases across the middle of the page. Either way nothing should sit
/// on it. When the system reports where the fold is, the split follows it. When it reports only that the hinge is
/// half-open (no division rect), the split falls at the middle of the container, which is where the Duo folds.
public enum TabletopLayout: Equatable, Sendable {
    /// Where the fold came from.
    public enum FoldSource: Equatable, Sendable {
        case hardwareDivision
        case screenMiddle
    }

    case singlePage
    case split(top: TabletopRow, fold: TabletopRow, bottom: TabletopRow, source: FoldSource)

    /// The shortest either half may be. Below this the split would leave the step or the controls a sliver.
    public static let minimumHalfHeight: Double = 260
    /// Space kept clear on each side of the fold, so text and tap targets stay off the crease. A fold the system
    /// reports already includes its own margins, so it is only widened to this when it is narrower.
    public static let foldMargin: Double = 24

    /// Resolves the layout for a container.
    ///
    /// - Parameters:
    ///   - width: The width of the container, in points.
    ///   - height: The height of the container, in points.
    ///   - hinge: The hinge posture the system reports.
    ///   - band: The horizontal fold, if the system reported one, in the container's coordinates.
    public static func resolve(
        width: Double,
        height: Double,
        hinge: HingePosture,
        band: FoldBand? = nil
    ) -> TabletopLayout {
        // A wide screen is a book: the spread handles a vertical fold. A closed foldable is an ordinary phone.
        guard height > width, hinge != .closed else {
            return .singlePage
        }
        let foldMinY: Double
        let foldHeight: Double
        let source: FoldSource
        if let band {
            foldMinY = band.minY
            foldHeight = band.height
            source = .hardwareDivision
        } else if hinge == .partiallyOpen {
            foldMinY = height / 2
            foldHeight = 0
            source = .screenMiddle
        } else {
            return .singlePage
        }
        let padding = max(0, foldMargin - foldHeight / 2)
        let fold = TabletopRow(minY: max(0, foldMinY - padding), height: foldHeight + padding * 2)
        let top = TabletopRow(minY: 0, height: fold.minY)
        let bottom = TabletopRow(minY: fold.maxY, height: max(0, height - fold.maxY))
        guard top.height >= minimumHalfHeight, bottom.height >= minimumHalfHeight else {
            return .singlePage
        }
        return .split(top: top, fold: fold, bottom: bottom, source: source)
    }

    public var isSplit: Bool {
        if case .split = self {
            return true
        }
        return false
    }

    public var top: TabletopRow? {
        if case .split(let top, _, _, _) = self {
            return top
        }
        return nil
    }

    public var fold: TabletopRow? {
        if case .split(_, let fold, _, _) = self {
            return fold
        }
        return nil
    }

    public var bottom: TabletopRow? {
        if case .split(_, _, let bottom, _) = self {
            return bottom
        }
        return nil
    }

    public var source: FoldSource? {
        if case .split(_, _, _, let source) = self {
            return source
        }
        return nil
    }
}
