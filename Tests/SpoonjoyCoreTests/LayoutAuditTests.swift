import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Layout audit")
struct LayoutAuditTests {
    private let screen = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)

    private func control(
        _ index: Int,
        _ frame: LayoutAuditRect,
        ancestors: [Int] = [],
        viewport: LayoutAuditRect? = nil,
        viewportIndex: Int? = nil,
        scroll: LayoutAuditScrollMetrics? = nil,
        isDockItem: Bool = false
    ) -> LayoutAuditElement {
        LayoutAuditElement(index: index, ancestors: ancestors, role: .interactive, type: "button", identifier: "control.\(index)", label: "Control \(index)", frame: frame, viewport: viewport, viewportIndex: viewportIndex, scroll: scroll, container: nil, isDockItem: isDockItem)
    }

    /// A scroll view's metrics: `content` is its content size, `offset` its content offset and the insets its
    /// adjusted content inset, all in points.
    private func metrics(
        _ frame: LayoutAuditRect,
        content: (width: Double, height: Double),
        offset: (x: Double, y: Double) = (0, 0),
        insets: (top: Double, left: Double, bottom: Double, right: Double) = (0, 0, 0, 0)
    ) -> LayoutAuditScrollMetrics {
        LayoutAuditScrollMetrics(
            frame: frame,
            contentWidth: content.width, contentHeight: content.height,
            offsetX: offset.x, offsetY: offset.y,
            insetTop: insets.top, insetLeft: insets.left, insetBottom: insets.bottom, insetRight: insets.right
        )
    }

    @Test("a control scrolling under the floating dock is not an overlap; one outside a scroll view is")
    func controlsScrollUnderTheDock() {
        let page = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)
        let dock = control(1, LayoutAuditRect(x: 20, y: 720, width: 80, height: 54), isDockItem: true)
        // The Pro Max Kitchen's "See all" runs 26.4 pt under the dock.
        let seeAll = control(2, LayoutAuditRect(x: 20, y: 747.6, width: 150, height: 60), viewport: page, viewportIndex: 0)
        #expect(LayoutAudit.audit([dock, seeAll], screen: screen).noOverlap)
        #expect(LayoutAudit.audit([seeAll, dock], screen: screen).noOverlap)

        // Deeper than the limit, the control is buried under the dock rather than passing beneath its edge.
        let buried = control(6, LayoutAuditRect(x: 20, y: 730, width: 150, height: 60), viewport: page, viewportIndex: 0)
        #expect(LayoutAudit.dockUnderlapLimit == 32)
        let buriedReport = LayoutAudit.audit([dock, buried], screen: screen)
        #expect(!buriedReport.noOverlap)
        #expect(buriedReport.overlaps.first?.intersection.height == 44)

        // A scroll view that stops above the dock does not run under it, and a fixed control never scrolls clear.
        let shortPage = LayoutAuditRect(x: 0, y: 0, width: 400, height: 760)
        let clipped = control(3, LayoutAuditRect(x: 20, y: 700, width: 150, height: 40), viewport: shortPage, viewportIndex: 0)
        let tallDock = control(5, LayoutAuditRect(x: 20, y: 690, width: 80, height: 90), isDockItem: true)
        #expect(!LayoutAudit.audit([tallDock, clipped], screen: screen).noOverlap)
        let fixed = control(4, LayoutAuditRect(x: 20, y: 740, width: 150, height: 60))
        #expect(!LayoutAudit.audit([dock, fixed], screen: screen).noOverlap)
    }

    // The Pro Max Recipes catalog lead at AX5 is 659 pt tall and runs off the bottom of the screen, 54 pt under the
    // dock. Scrolling carries it out from under the dock, as it does for any control cut by the scroll view's edge.
    @Test("a control that scrolling reveals past the screen edge passes under the dock at any depth")
    func partlyScrolledControlPassesUnderTheDock() {
        let page = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)
        let dock = control(1, LayoutAuditRect(x: 25, y: 721, width: 89, height: 54), isDockItem: true)
        let lead = control(2, LayoutAuditRect(x: 20, y: 300, width: 360, height: 659), viewport: page, viewportIndex: 0)
        let nextRow = control(3, LayoutAuditRect(x: 20, y: 980, width: 360, height: 80), viewport: page, viewportIndex: 0)
        let report = LayoutAudit.audit([dock, lead, nextRow], screen: screen)
        #expect(report.noOverlap)
        #expect(report.skippedPartiallyScrolledCount == 1)

        // As the last row, with nothing beyond the edge, the dock at that edge scrolls it clear when the page
        // reserves room under the dock past its last row: 959 + 120 - 800 = 279 pt left, 238 pt needed to clear the dock.
        let reserved = metrics(page, content: (400, 959), insets: (0, 0, 120, 0))
        let leadWithReserve = control(2, lead.frame, viewport: page, viewportIndex: 0, scroll: reserved)
        let lastRow = LayoutAudit.audit([dock, leadWithReserve], screen: screen)
        #expect(lastRow.noOverlap)
        #expect(lastRow.controlsOnScreen)
        #expect(lastRow.skippedPartiallyScrolledCount == 1)

        // Without the scroll view's metrics nothing shows it can scroll the row clear, so it is clipped and buried.
        let unmeasured = LayoutAudit.audit([dock, lead], screen: screen)
        #expect(!unmeasured.noOverlap)
        #expect(unmeasured.clippedControls.map(\.control.identifier) == ["control.2"])
    }

    // The Pro Max Recipes list at AX5 holds two rows; the second runs off the bottom of the screen under the dock with
    // nothing past it. Only the cut edge that faces the dock earns the exemption.
    @Test("the last control cut at the dock's edge is scrolled; one buried under the dock or cut elsewhere is not")
    func lastControlCutAtTheDocksEdgeIsScrolled() {
        let page = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)
        let dock = control(1, LayoutAuditRect(x: 25, y: 721, width: 89, height: 54), isDockItem: true)
        // The row ends at 1000 and the dock starts at 721, so the page must scroll 279 pt more to carry the row clear.
        let reserved = metrics(page, content: (400, 1000), insets: (0, 0, 79, 0))
        let lastRow = control(2, LayoutAuditRect(x: 20, y: 600, width: 360, height: 400), viewport: page, viewportIndex: 0, scroll: reserved)
        let passing = LayoutAudit.audit([dock, lastRow], screen: screen)
        #expect(passing.noOverlap)
        #expect(passing.controlsOnScreen)

        // A page with no room past its last row (200 pt left, 279 needed) leaves the row under the dock.
        let noReserve = metrics(page, content: (400, 1000))
        let stuck = control(2, lastRow.frame, viewport: page, viewportIndex: 0, scroll: noReserve)
        let stuckReport = LayoutAudit.audit([dock, stuck], screen: screen)
        #expect(!stuckReport.noOverlap)
        #expect(stuckReport.clippedControls.map(\.control.identifier) == ["control.2"])

        // A horizontal pager whose frame holds the dock does not scroll the row up at all.
        let pager = metrics(page, content: (1200, 800))
        #expect(pager.axis == .horizontal)
        let paged = control(2, lastRow.frame, viewport: page, viewportIndex: 0, scroll: pager)
        let pagedReport = LayoutAudit.audit([dock, paged], screen: screen)
        #expect(!pagedReport.noOverlap)
        #expect(pagedReport.clippedControls.map(\.control.identifier) == ["control.2"])

        // Scrolled partway already, only the extent left below counts: 1079 - 100 - 800 = 179 pt, short of 279.
        let scrolledDown = metrics(page, content: (400, 1000), offset: (0, 100), insets: (0, 0, 79, 0))
        let late = control(2, lastRow.frame, viewport: page, viewportIndex: 0, scroll: scrolledDown)
        #expect(!LayoutAudit.audit([dock, late], screen: screen).controlsOnScreen)

        // Real content under the dock that does not reach the scroll view's edge has no scrolling to excuse it.
        let buried = control(3, LayoutAuditRect(x: 20, y: 700, width: 360, height: 80), viewport: page, viewportIndex: 0)
        let buriedReport = LayoutAudit.audit([dock, buried], screen: screen)
        #expect(!buriedReport.noOverlap)
        #expect(buriedReport.controlsOnScreen)

        // Outside a scroll view, a control running off the screen under the dock is clipped and overlaps it.
        let fixed = control(4, LayoutAuditRect(x: 20, y: 600, width: 360, height: 400))
        let fixedReport = LayoutAudit.audit([dock, fixed], screen: screen)
        #expect(!fixedReport.noOverlap)
        #expect(fixedReport.clippedControls.map(\.control.identifier) == ["control.4"])

        // A scroll view that stops above the dock does not hold it, so its last control is clipped.
        let shortPage = LayoutAuditRect(x: 0, y: 0, width: 400, height: 700)
        let shortRow = control(5, LayoutAuditRect(x: 20, y: 600, width: 360, height: 400), viewport: shortPage, viewportIndex: 1)
        #expect(LayoutAudit.audit([dock, shortRow], screen: screen).clippedControls.map(\.control.identifier) == ["control.5"])

        // Cut at the right edge with the dock at the bottom, the right edge is not excused.
        let wide = control(6, LayoutAuditRect(x: 300, y: 100, width: 200, height: 80), viewport: page, viewportIndex: 2)
        #expect(LayoutAudit.audit([dock, wide], screen: screen).clippedControls.map(\.control.identifier) == ["control.6"])
    }

    // The closed Duo's side rail sits beside the content, not across the edge where it scrolls out of view. A row cut
    // at the bottom of the screen with the rail over its middle stays under the rail however it scrolls, so it gets
    // only the ordinary underlap limit. Reviewer's synthetic case (rr10a/siderail-case.json).
    @Test("a partly scrolled control passes under the dock only when the dock sits at its cut edge")
    func partlyScrolledExemptionNeedsTheDockAtTheCutEdge() {
        let cover = LayoutAuditRect(x: 0, y: 0, width: 466, height: 678)
        let rail = control(1, LayoutAuditRect(x: 396, y: 434, width: 44, height: 58), isDockItem: true)
        let row = control(2, LayoutAuditRect(x: 24, y: 420, width: 442, height: 400), viewport: cover, viewportIndex: 0)
        let nextRow = control(3, LayoutAuditRect(x: 24, y: 900, width: 334, height: 60), viewport: cover, viewportIndex: 0)
        let report = LayoutAudit.audit([rail, row, nextRow], screen: cover)
        #expect(report.skippedPartiallyScrolledCount == 1)
        #expect(!report.noOverlap)

        // The same rail at the bottom of the cover, within the underlap limit of the cut edge, is passed under.
        let low = control(4, LayoutAuditRect(x: 396, y: 610, width: 44, height: 58), isDockItem: true)
        #expect(LayoutAudit.audit([low, row, nextRow], screen: cover).noOverlap)

        // A row cut at the cover's right edge in a sideways scroller faces a rail on that edge.
        let shelf = control(5, LayoutAuditRect(x: 300, y: 420, width: 400, height: 120), viewport: cover, viewportIndex: 1)
        let nextShelf = control(6, LayoutAuditRect(x: 720, y: 420, width: 200, height: 120), viewport: cover, viewportIndex: 1)
        #expect(LayoutAudit.audit([rail, shelf, nextShelf], screen: cover).noOverlap)
        // Cut at the right but with the rail on the left, it does not.
        let leftRail = control(7, LayoutAuditRect(x: 310, y: 434, width: 44, height: 58), isDockItem: true)
        #expect(!LayoutAudit.audit([leftRail, shelf, nextShelf], screen: cover).noOverlap)

        // Mirrored: cut at the left and top edges, with the dock at that edge.
        let earlierShelf = control(8, LayoutAuditRect(x: -300, y: 420, width: 400, height: 120), viewport: cover, viewportIndex: 2)
        let firstShelf = control(9, LayoutAuditRect(x: -600, y: 420, width: 200, height: 120), viewport: cover, viewportIndex: 2)
        let edgeRail = control(10, LayoutAuditRect(x: 26, y: 434, width: 44, height: 58), isDockItem: true)
        #expect(LayoutAudit.audit([edgeRail, earlierShelf, firstShelf], screen: cover).noOverlap)
        let scrolledRow = control(11, LayoutAuditRect(x: 24, y: -300, width: 442, height: 400), viewport: cover, viewportIndex: 3)
        let rowAbove = control(12, LayoutAuditRect(x: 24, y: -500, width: 442, height: 100), viewport: cover, viewportIndex: 3)
        let topDock = control(13, LayoutAuditRect(x: 100, y: 10, width: 44, height: 58), isDockItem: true)
        #expect(LayoutAudit.audit([topDock, scrolledRow, rowAbove], screen: cover).noOverlap)
        let lowerDock = control(14, LayoutAuditRect(x: 100, y: 40, width: 44, height: 58), isDockItem: true)
        #expect(!LayoutAudit.audit([lowerDock, scrolledRow, rowAbove], screen: cover).noOverlap)
    }

    // Any edge's exemption needs the scroll view to scroll along that edge's axis, with room left to carry the control
    // past the dock: hidden depth plus the dock's clearance from the edge.
    @Test("the last control cut at a dock's edge is scrolled only along an axis the scroll view scrolls, with room left")
    func lastControlExemptionNeedsRoomAlongTheCutAxis() {
        let cover = LayoutAuditRect(x: 0, y: 0, width: 466, height: 678)

        // Top edge, dock at the top: the row starts at -300 and the dock ends at 68, so 368 pt are needed.
        let topDock = control(1, LayoutAuditRect(x: 100, y: 10, width: 44, height: 58), isDockItem: true)
        let room = metrics(cover, content: (466, 1600), offset: (0, 400))
        #expect(room.axis == .vertical)
        let scrolledRow = control(2, LayoutAuditRect(x: 24, y: -300, width: 442, height: 400), viewport: cover, viewportIndex: 0, scroll: room)
        #expect(LayoutAudit.audit([topDock, scrolledRow], screen: cover).controlsOnScreen)
        let cramped = metrics(cover, content: (466, 1600), offset: (0, 300))
        let crampedRow = control(2, scrolledRow.frame, viewport: cover, viewportIndex: 0, scroll: cramped)
        #expect(!LayoutAudit.audit([topDock, crampedRow], screen: cover).controlsOnScreen)

        // Right edge, rail on the right, in a shelf that scrolls sideways: 700 - 396 = 304 pt needed.
        let rail = control(3, LayoutAuditRect(x: 396, y: 434, width: 44, height: 58), isDockItem: true)
        let shelf = metrics(cover, content: (800, 678), insets: (0, 0, 0, 40))
        #expect(shelf.axis == .horizontal)
        let shelfItem = control(4, LayoutAuditRect(x: 300, y: 420, width: 400, height: 120), viewport: cover, viewportIndex: 1, scroll: shelf)
        #expect(LayoutAudit.audit([rail, shelfItem], screen: cover).controlsOnScreen)
        // The same item in a page that scrolls only up and down cannot be carried out from under the rail.
        let tall = metrics(cover, content: (466, 1600))
        let pageItem = control(4, shelfItem.frame, viewport: cover, viewportIndex: 1, scroll: tall)
        #expect(!LayoutAudit.audit([rail, pageItem], screen: cover).controlsOnScreen)

        // Left edge, rail on the left, in a shelf scrolled sideways that also scrolls down (both axes).
        let leftRail = control(5, LayoutAuditRect(x: 26, y: 434, width: 44, height: 58), isDockItem: true)
        let both = metrics(cover, content: (1400, 1600), offset: (400, 0))
        #expect(both.axis == .both)
        let leftItem = control(6, LayoutAuditRect(x: -300, y: 420, width: 400, height: 120), viewport: cover, viewportIndex: 2, scroll: both)
        #expect(LayoutAudit.audit([leftRail, leftItem], screen: cover).controlsOnScreen)

        // A scroll view whose content fits its frame does not scroll at all.
        let still = metrics(cover, content: (466, 678))
        #expect(still.axis == .none)
        let stillItem = control(6, leftItem.frame, viewport: cover, viewportIndex: 2, scroll: still)
        #expect(!LayoutAudit.audit([leftRail, stillItem], screen: cover).controlsOnScreen)
    }

    @Test("the dock's tab items are not compared with each other, but are with the app's controls")
    func dockItemsAreComparedOnlyWithOtherControls() {
        // The iPhone Duo's closed rail: 58 pt items at a 50 pt pitch.
        let kitchen = control(1, LayoutAuditRect(x: 396, y: 384, width: 44, height: 58), isDockItem: true)
        let recipes = control(2, LayoutAuditRect(x: 396, y: 434, width: 44, height: 58), isDockItem: true)
        #expect(LayoutAudit.audit([kitchen, recipes], screen: screen).noOverlap)

        // The iPhone 6.9" dock's tabs share 12.4 pt side by side; past the limit two dock tabs fail like any controls.
        let left = control(5, LayoutAuditRect(x: 20, y: 700, width: 90, height: 54), isDockItem: true)
        let right = control(6, LayoutAuditRect(x: 97.6, y: 700, width: 90, height: 54), isDockItem: true)
        #expect(LayoutAudit.audit([left, right], screen: screen).noOverlap)
        #expect(LayoutAudit.dockNeighbourOverlapLimit == 16)
        let crowded = control(7, LayoutAuditRect(x: 90, y: 700, width: 90, height: 54), isDockItem: true)
        #expect(!LayoutAudit.audit([left, crowded], screen: screen).noOverlap)

        let appButton = control(4, LayoutAuditRect(x: 380, y: 400, width: 44, height: 44))
        let mixed = LayoutAudit.audit([kitchen, recipes, appButton], screen: screen)
        #expect(Set(mixed.overlaps.map(\.first.identifier) + mixed.overlaps.map(\.second.identifier)) == ["control.1", "control.2", "control.4"])
        #expect(mixed.overlaps.count == 2)
    }

    private func text(
        _ index: Int,
        _ frame: LayoutAuditRect,
        label: String? = nil,
        container: LayoutAuditRect? = nil,
        viewport: LayoutAuditRect? = nil
    ) -> LayoutAuditElement {
        LayoutAuditElement(index: index, ancestors: [], role: .text, type: "staticText", identifier: "", label: label ?? "Text \(index)", frame: frame, viewport: viewport, container: container)
    }

    private func drawn(_ text: String, _ frame: LayoutAuditRect) -> LayoutAuditDrawnText {
        LayoutAuditDrawnText(text: text, frame: frame)
    }

    @Test("two controls whose frames cross fail, and the report names both")
    func crossingControlsFail() {
        let report = LayoutAudit.audit([
            control(0, .init(x: 20, y: 100, width: 120, height: 44)),
            control(1, .init(x: 100, y: 120, width: 120, height: 44))
        ], screen: screen)

        #expect(report.noOverlap == false)
        #expect(report.overlaps.count == 1)
        #expect(report.overlaps[0].first.identifier == "control.0")
        #expect(report.overlaps[0].second.identifier == "control.1")
        #expect(report.overlaps[0].intersection == .init(x: 100, y: 120, width: 40, height: 24))
        #expect(report.interactiveCount == 2)
        #expect(report.controlsOnScreen)
    }

    @Test("controls that touch, sit apart, or nest pass")
    func touchingSeparateAndNestedControlsPass() {
        let report = LayoutAudit.audit([
            control(0, .init(x: 0, y: 0, width: 100, height: 44)),
            control(1, .init(x: 100.4, y: 0, width: 100, height: 44)),
            control(2, .init(x: 0, y: 300, width: 400, height: 60)),
            control(3, .init(x: 340, y: 308, width: 44, height: 44), ancestors: [2])
        ], screen: screen)

        #expect(report.noOverlap)
        #expect(report.overlaps.isEmpty)
    }

    @Test("a control scrolled out of its viewport is skipped, and only the visible part of one can overlap")
    func scrolledControlsUseTheirVisibleFrame() {
        let viewport = LayoutAuditRect(x: 0, y: 0, width: 400, height: 700)
        let report = LayoutAudit.audit([
            control(0, .init(x: 0, y: 900, width: 400, height: 44), viewport: viewport, viewportIndex: 9),
            control(1, .init(x: 0, y: 680, width: 400, height: 60), viewport: viewport, viewportIndex: 9),
            control(2, .init(x: 0, y: 700, width: 400, height: 100))
        ], screen: screen)

        #expect(report.skippedOffscreenCount == 1)
        #expect(report.skippedPartiallyScrolledCount == 1)
        #expect(report.noOverlap)
        #expect(report.controlsOnScreen)
    }

    @Test("everything in a scroll view that is itself off screen is skipped")
    func offscreenViewportHidesItsContent() {
        let report = LayoutAudit.audit([
            control(0, .init(x: 0, y: 100, width: 100, height: 44), viewport: .init(x: 500, y: 0, width: 400, height: 800), viewportIndex: 1)
        ], screen: screen)

        #expect(report.skippedOffscreenCount == 1)
        #expect(report.interactiveCount == 0)
    }

    @Test("a control running off the screen is clipped, with the share still visible")
    func controlOffScreenIsClipped() {
        let report = LayoutAudit.audit([
            control(0, .init(x: 300, y: 100, width: 200, height: 44)),
            control(1, .init(x: 0, y: 700, width: 400, height: 200))
        ], screen: screen)

        #expect(report.controlsOnScreen == false)
        #expect(report.clippedControls.map(\.control.identifier) == ["control.0", "control.1"])
        #expect(report.clippedControls.map(\.visibleFraction) == [0.5, 0.5])
    }

    @Test("a control cut by a pager that does not scroll that way is clipped")
    func controlCutByAPagerIsClipped() {
        let pager = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)
        let report = LayoutAudit.audit([
            control(0, .init(x: 40, y: 600, width: 300, height: 300), viewport: pager, viewportIndex: 5),
            control(1, .init(x: 440, y: 100, width: 300, height: 44), viewport: pager, viewportIndex: 5),
            control(2, .init(x: 40, y: 900, width: 300, height: 44), viewport: pager, viewportIndex: 6)
        ], screen: screen)

        #expect(report.clippedControls.map(\.control.identifier) == ["control.0"])
        #expect(report.skippedOffscreenCount == 2)
    }

    @Test("a control entirely off screen outside any scroll view is clipped with nothing visible")
    func controlEntirelyOffScreenIsClipped() {
        let report = LayoutAudit.audit([
            control(0, .init(x: 500, y: 100, width: 100, height: 44)),
            control(1, .init(x: 20, y: 300, width: 0, height: 44))
        ], screen: screen)

        #expect(report.controlsOnScreen == false)
        #expect(report.clippedControls.map(\.control.identifier) == ["control.0"])
        #expect(report.clippedControls.map(\.visibleFraction) == [0])
        #expect(report.skippedOffscreenCount == 1)
    }

    @Test("two controls cut by the same scroll view edge do not excuse each other")
    func controlsCutByTheSameEdgeAreBothClipped() {
        let viewport = LayoutAuditRect(x: 0, y: 0, width: 400, height: 700)
        let cut = [
            control(0, .init(x: 0, y: 680, width: 150, height: 60), viewport: viewport, viewportIndex: 1),
            control(1, .init(x: 200, y: 670, width: 150, height: 60), viewport: viewport, viewportIndex: 1)
        ]

        let alone = LayoutAudit.audit(cut, screen: screen)
        #expect(alone.clippedControls.map(\.control.identifier) == ["control.0", "control.1"])

        let continued = LayoutAudit.audit(cut + [control(2, .init(x: 0, y: 760, width: 150, height: 44), viewport: viewport, viewportIndex: 1)], screen: screen)
        #expect(continued.controlsOnScreen)
        #expect(continued.skippedPartiallyScrolledCount == 2)
    }

    @Test("a control cut by a scroll view on any edge is scrolled when other content lies past that edge")
    func controlCutWhereContentContinuesIsScrolled() {
        let viewport = LayoutAuditRect(x: 50, y: 50, width: 300, height: 700)
        let report = LayoutAudit.audit([
            control(0, .init(x: 20, y: 100, width: 100, height: 44), viewport: viewport, viewportIndex: 1),
            control(1, .init(x: -200, y: 200, width: 100, height: 44), viewport: viewport, viewportIndex: 1),
            control(2, .init(x: 300, y: 300, width: 100, height: 44), viewport: viewport, viewportIndex: 1),
            control(3, .init(x: 500, y: 300, width: 100, height: 44), viewport: viewport, viewportIndex: 1),
            control(4, .init(x: 100, y: 20, width: 100, height: 44), viewport: viewport, viewportIndex: 1),
            control(5, .init(x: 100, y: -100, width: 100, height: 44), viewport: viewport, viewportIndex: 1),
            control(6, .init(x: 100, y: 730, width: 100, height: 44), viewport: viewport, viewportIndex: 1),
            control(7, .init(x: 100, y: 900, width: 100, height: 44), viewport: viewport, viewportIndex: 1)
        ], screen: screen)

        #expect(report.controlsOnScreen)
        #expect(report.skippedPartiallyScrolledCount == 4)
    }

    @Test("text inside its container and the screen, with no truncated line, fits")
    func textThatHasRoomFits() {
        let report = LayoutAudit.audit(
            [text(0, .init(x: 20, y: 20, width: 200, height: 40), container: .init(x: 10, y: 10, width: 300, height: 60))],
            drawnText: [drawn("Text 0", .init(x: 22, y: 25, width: 80, height: 30))],
            screen: screen
        )

        #expect(report.textFits)
        #expect(report.textCount == 1)
        #expect(report.drawnTextCount == 1)
        #expect(report.textProblems.isEmpty)
    }

    @Test("text breaking the screen or its container fails on each edge it breaks")
    func textOutsideItsBoundsFails() {
        let report = LayoutAudit.audit([
            text(0, .init(x: 350, y: 20, width: 100, height: 30)),
            text(1, .init(x: 20, y: 100, width: 200, height: 30), container: .init(x: 20, y: 100, width: 150, height: 30))
        ], screen: screen)

        #expect(report.textFits == false)
        #expect(report.textProblems.map(\.kind) == [.outsideScreen, .outsideContainer])
        #expect(report.textProblems.map(\.text.label) == ["Text 0", "Text 1"])
    }

    @Test("a drawn line ending in an ellipsis is truncated, judged by what was drawn, not the accessibility label")
    func drawnEllipsisIsTruncated() {
        let report = LayoutAudit.audit(
            [
                text(0, .init(x: 20, y: 20, width: 250, height: 50), label: "Saved kitchen may be out of date"),
                control(1, .init(x: 0, y: 200, width: 400, height: 60)),
                text(2, .init(x: 20, y: 205, width: 200, height: 50), label: "Worcestershire sauce")
            ],
            drawnText: [
                drawn("Saved copy...", .init(x: 24, y: 25, width: 200, height: 40)),
                drawn("Worcester…", .init(x: 24, y: 210, width: 150, height: 40)),
                drawn("Pasta…", .init(x: 20, y: 500, width: 100, height: 40))
            ],
            screen: screen
        )

        #expect(report.textFits == false)
        #expect(report.textProblems.map(\.kind) == [.truncated, .truncated, .truncated])
        #expect(report.textProblems.map(\.text.label) == ["Saved kitchen may be out of date", "Worcestershire sauce", "Pasta…"])
        #expect(report.textProblems.map(\.text.type) == ["staticText", "staticText", "drawnText"])
        #expect(report.textProblems.map(\.drawnText) == ["Saved copy...", "Worcester…", "Pasta…"])
    }

    @Test("an ellipsis that is an icon, or that the label itself ends with, is not truncation")
    func intendedEllipsesAreNotTruncation() {
        let report = LayoutAudit.audit(
            [text(0, .init(x: 20, y: 20, width: 250, height: 50), label: "Loading recipes…")],
            drawnText: [
                drawn("Loading recipes...", .init(x: 24, y: 25, width: 200, height: 40)),
                drawn("• • •", .init(x: 300, y: 300, width: 40, height: 10)),
                drawn("...", .init(x: 300, y: 400, width: 40, height: 10)),
                drawn("Lemon", .init(x: 300, y: 500, width: 40, height: 10))
            ],
            screen: screen
        )

        #expect(report.textFits)
        #expect(LayoutAudit.isTruncated("Saved copy…"))
        #expect(LayoutAudit.isTruncated(" … ") == false)
        #expect(LayoutAudit.isTruncated("• …") == false)
        #expect(LayoutAudit.isTruncated("1 of 12…"))
    }

    @Test("text cut by a scroll view's edge is skipped, not counted as clipped; text off screen is skipped")
    func scrolledTextIsSkipped() {
        let viewport = LayoutAuditRect(x: 0, y: 100, width: 400, height: 600)
        let report = LayoutAudit.audit([
            text(0, .init(x: 20, y: 680, width: 200, height: 40), viewport: viewport),
            text(1, .init(x: 20, y: 900, width: 200, height: 40)),
            text(2, .init(x: 20, y: 300, width: 0, height: 40))
        ], screen: screen)

        #expect(report.textFits)
        #expect(report.skippedPartiallyScrolledCount == 1)
        #expect(report.skippedOffscreenCount == 2)
        #expect(report.textCount == 0)
    }

    @Test("the report round-trips through JSON")
    func reportRoundTrips() throws {
        let report = LayoutAudit.audit(
            [
                control(0, .init(x: 0, y: 0, width: 100, height: 44)),
                control(1, .init(x: 50, y: 0, width: 100, height: 44)),
                control(2, .init(x: 350, y: 300, width: 100, height: 44)),
                text(3, .init(x: 20, y: 200, width: 60, height: 30))
            ],
            drawnText: [drawn("Tex…", .init(x: 20, y: 200, width: 60, height: 30))],
            screen: screen
        )
        let decoded = try JSONDecoder().decode(LayoutAuditReport.self, from: JSONEncoder().encode(report))

        #expect(decoded == report)
        #expect(decoded.textProblems[0].kind == .truncated)
        #expect(decoded.clippedControls.count == 1)

        let page = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)
        let measured = control(5, .init(x: 0, y: 700, width: 100, height: 200), viewport: page, viewportIndex: 4, scroll: metrics(page, content: (400, 1200), offset: (0, 10), insets: (1, 2, 3, 4)))
        #expect(try JSONDecoder().decode(LayoutAuditElement.self, from: JSONEncoder().encode(measured)) == measured)
    }
}
