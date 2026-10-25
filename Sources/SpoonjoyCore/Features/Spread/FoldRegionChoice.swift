import Foundation

/// One `.division` Reserved Region as UIKit reported it, in the measuring view's coordinates.
public struct ReportedFoldRegion: Equatable, Sendable {
    public let minX: Double
    public let minY: Double
    public let width: Double
    public let height: Double
    public let isActive: Bool

    public init(minX: Double, minY: Double, width: Double, height: Double, isActive: Bool) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
        self.isActive = isActive
    }
}

/// Picks the fold to lay out around from the regions UIKit reports, queried with `.includeInactive`.
///
/// iOS marks the iPhone Duo's fold inactive when the screen is open flat, and a plain query leaves inactive regions
/// out. A vertical fold still marks where the two pages of a spread meet, so the division accepts an inactive region,
/// preferring an active one. The tabletop band takes only an active region: flat and tall, the screen is one page.
public enum FoldRegionChoice {
    public static func division(
        from regions: [ReportedFoldRegion],
        containerWidth: Double,
        containerHeight: Double
    ) -> SpreadDivision? {
        let ordered = regions.filter(\.isActive) + regions.filter { !$0.isActive }
        return ordered.lazy.compactMap { region in
            SpreadDivision(
                frameMinX: region.minX,
                frameWidth: region.width,
                frameHeight: region.height,
                containerWidth: containerWidth,
                containerHeight: containerHeight
            )
        }.first
    }

    public static func band(
        from regions: [ReportedFoldRegion],
        containerWidth: Double,
        containerHeight: Double
    ) -> FoldBand? {
        regions.lazy.filter(\.isActive).compactMap { region in
            FoldBand(
                frameMinY: region.minY,
                frameHeight: region.height,
                frameWidth: region.width,
                containerWidth: containerWidth,
                containerHeight: containerHeight
            )
        }.first
    }
}
