import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Fold region choice")
struct FoldRegionChoiceTests {
    // The iPhone Duo inner screen held open flat and wide, under the status-bar strip: about 886 by 669 points.
    private let width = 886.0
    private let height = 669.0

    private func vertical(active: Bool, minX: Double = 455) -> ReportedFoldRegion {
        ReportedFoldRegion(minX: minX, minY: 0, width: 40, height: height, isActive: active)
    }

    private func horizontal(active: Bool) -> ReportedFoldRegion {
        ReportedFoldRegion(minX: 0, minY: 314, width: width, height: 40, isActive: active)
    }

    @Test("an inactive vertical fold still places the gutter, because the system marks the fold inactive when open flat")
    func inactiveVerticalFoldIsADivision() throws {
        let division = try #require(FoldRegionChoice.division(
            from: [vertical(active: false)], containerWidth: width, containerHeight: height
        ))
        #expect(division == SpreadDivision(minX: 455, width: 40))
        let layout = BookSpreadLayout.resolve(width: width, height: height, isRegularWidth: true, division: division)
        #expect(layout.source == .hardwareDivision)
        #expect(layout.gutter == SpreadColumn(minX: 455, width: 40))
    }

    @Test("an active vertical fold wins over an inactive one")
    func activeVerticalFoldWins() {
        let regions = [vertical(active: false, minX: 400), vertical(active: true, minX: 455)]
        #expect(FoldRegionChoice.division(from: regions, containerWidth: width, containerHeight: height)
            == SpreadDivision(minX: 455, width: 40))
    }

    @Test("a horizontal fold is never a division")
    func horizontalFoldIsNotADivision() {
        #expect(FoldRegionChoice.division(
            from: [horizontal(active: true), horizontal(active: false)], containerWidth: width, containerHeight: height
        ) == nil)
        #expect(FoldRegionChoice.division(from: [], containerWidth: width, containerHeight: height) == nil)
    }

    @Test("the tabletop band comes only from an active horizontal fold")
    func bandIsActiveOnly() {
        #expect(FoldRegionChoice.band(from: [horizontal(active: true)], containerWidth: width, containerHeight: height)
            == FoldBand(minY: 314, height: 40))
        // Held open tall and flat, the fold is inactive and must not split the screen like tabletop.
        #expect(FoldRegionChoice.band(from: [horizontal(active: false)], containerWidth: width, containerHeight: height) == nil)
        #expect(FoldRegionChoice.band(from: [vertical(active: true)], containerWidth: width, containerHeight: height) == nil)
    }
}

@Suite("Spread layout probe")
struct SpreadLayoutProbeTests {
    @Test("the probe line names the layout and where its gutter came from")
    func probeDescription() {
        #expect(BookSpreadLayout.singlePage.probeDescription == "single-page")
        #expect(
            BookSpreadLayout.resolve(width: 886, height: 669, isRegularWidth: true, division: SpreadDivision(minX: 455, width: 40))
                .probeDescription == "spread source=hardware-division leading=455.0 gutter=455.0+40.0 trailing=391.0"
        )
        #expect(
            BookSpreadLayout.resolve(width: 1000, height: 700, isRegularWidth: true).probeDescription
                == "spread source=screen-middle leading=500.0 gutter=500.0+0.0 trailing=500.0"
        )
    }
}
