import Foundation

/// A vertical band of the screen that content must stay out of, such as the fold of a foldable iPhone.
///
/// Today nothing supplies one: the hinge APIs need the iOS 27.1 SDK. When they arrive, the app reads the
/// Reserved Region `.division` rect, converts it to the spread's coordinate space and passes it here. Until then
/// the spread splits the screen down the middle, which is where the fold of the iPhone Duo sits.
public struct SpreadDivision: Equatable, Sendable {
    public let minX: Double
    public let width: Double

    public init(minX: Double, width: Double) {
        self.minX = minX
        self.width = width
    }

    public var maxX: Double {
        minX + width
    }
}

/// A horizontal slice of the spread: a page or the gutter between pages.
public struct SpreadColumn: Equatable, Sendable {
    public let minX: Double
    public let width: Double

    public init(minX: Double, width: Double) {
        self.minX = minX
        self.width = width
    }

    public var maxX: Double {
        minX + width
    }
}

/// Which page of an open spread.
public enum SpreadPageSide: Equatable, Sendable {
    case leading
    case trailing
}

/// Margins for one page, named by direction and by their relation to the gutter.
public struct SpreadPageInsets: Equatable, Sendable {
    public let leading: Double
    public let trailing: Double
    /// The margin on the side away from the gutter.
    public let outer: Double
    /// The margin on the gutter side.
    public let inner: Double
}

/// Whether a regular-width screen reads as one page or opens into a two-page spread, like a cookbook laid flat.
public enum BookSpreadLayout: Equatable, Sendable {
    /// Where the gutter between the two pages came from.
    public enum GutterSource: Equatable, Sendable {
        /// The middle of the screen. This is where the fold of the iPhone Duo sits.
        case screenMiddle
        /// A division the system reported, such as the fold of a foldable.
        case hardwareDivision
    }

    case singlePage
    case spread(leading: SpreadColumn, gutter: SpreadColumn, trailing: SpreadColumn, source: GutterSource)

    /// The narrowest landscape screen that opens into a spread without a hardware division.
    public static let minimumSpreadWidth: Double = 900
    /// The narrowest a page may be. Below this a division cannot open a spread.
    public static let minimumPageWidth: Double = 360
    /// The margin on the side of a page away from the gutter.
    public static let outerMargin: Double = 28
    /// The margin on the gutter side. Wider than the outer margin so tap targets stay clear of the fold.
    public static let innerMargin: Double = 40

    /// Resolves the layout for a container.
    ///
    /// - Parameters:
    ///   - width: The width of the container that holds the spread, in points.
    ///   - height: The height of that container, in points.
    ///   - isRegularWidth: Whether the horizontal size class is regular. Compact width is always one page.
    ///   - division: The fold, if the system reported one, in the container's coordinates. This is the seam for
    ///     the fold-aware pass: pass the Reserved Region `.division` rect here once the iOS 27.1 SDK ships.
    public static func resolve(
        width: Double,
        height: Double,
        isRegularWidth: Bool,
        division: SpreadDivision? = nil
    ) -> BookSpreadLayout {
        guard isRegularWidth else {
            return .singlePage
        }
        if let division {
            let leading = SpreadColumn(minX: 0, width: division.minX)
            let trailing = SpreadColumn(minX: division.maxX, width: width - division.maxX)
            guard leading.width >= minimumPageWidth, trailing.width >= minimumPageWidth else {
                return .singlePage
            }
            return .spread(
                leading: leading,
                gutter: SpreadColumn(minX: division.minX, width: division.width),
                trailing: trailing,
                source: .hardwareDivision
            )
        }
        guard width >= minimumSpreadWidth, width > height else {
            return .singlePage
        }
        let middle = width / 2
        return .spread(
            leading: SpreadColumn(minX: 0, width: middle),
            gutter: SpreadColumn(minX: middle, width: 0),
            trailing: SpreadColumn(minX: middle, width: width - middle),
            source: .screenMiddle
        )
    }

    /// The margins for one page of a spread.
    public static func pageInsets(for side: SpreadPageSide) -> SpreadPageInsets {
        switch side {
        case .leading:
            SpreadPageInsets(leading: outerMargin, trailing: innerMargin, outer: outerMargin, inner: innerMargin)
        case .trailing:
            SpreadPageInsets(leading: innerMargin, trailing: outerMargin, outer: outerMargin, inner: innerMargin)
        }
    }

    /// Whether the library sidebar should step aside so an open recipe can use the whole screen and put its
    /// gutter on the fold. Only a recipe opened for reading does this; cook mode already hides the sidebar.
    public static func hidesLibrarySidebar(route: AppRoute, windowLayout: BookSpreadLayout) -> Bool {
        guard windowLayout.isSpread, case .recipeDetail(_, .detail) = route else {
            return false
        }
        return true
    }

    public var isSpread: Bool {
        if case .spread = self {
            return true
        }
        return false
    }

    public var leadingPage: SpreadColumn? {
        if case .spread(let leading, _, _, _) = self {
            return leading
        }
        return nil
    }

    public var gutter: SpreadColumn? {
        if case .spread(_, let gutter, _, _) = self {
            return gutter
        }
        return nil
    }

    public var trailingPage: SpreadColumn? {
        if case .spread(_, _, let trailing, _) = self {
            return trailing
        }
        return nil
    }

    public var source: GutterSource? {
        if case .spread(_, _, _, let source) = self {
            return source
        }
        return nil
    }
}
