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
        isDockItem: Bool = false
    ) -> LayoutAuditElement {
        LayoutAuditElement(index: index, ancestors: ancestors, role: .interactive, type: "button", identifier: "control.\(index)", label: "Control \(index)", frame: frame, viewport: viewport, viewportIndex: viewportIndex, container: nil, isDockItem: isDockItem)
    }

    @Test("a control scrolling under the floating dock is not an overlap; one outside a scroll view is")
    func controlsScrollUnderTheDock() {
        let page = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)
        let dock = control(1, LayoutAuditRect(x: 20, y: 720, width: 80, height: 54), isDockItem: true)
        let seeAll = control(2, LayoutAuditRect(x: 20, y: 740, width: 150, height: 60), viewport: page, viewportIndex: 0)
        #expect(LayoutAudit.audit([dock, seeAll], screen: screen).noOverlap)
        #expect(LayoutAudit.audit([seeAll, dock], screen: screen).noOverlap)

        // A scroll view that stops above the dock does not run under it, and a fixed control never scrolls clear.
        let shortPage = LayoutAuditRect(x: 0, y: 0, width: 400, height: 760)
        let clipped = control(3, LayoutAuditRect(x: 20, y: 700, width: 150, height: 40), viewport: shortPage, viewportIndex: 0)
        let tallDock = control(5, LayoutAuditRect(x: 20, y: 690, width: 80, height: 90), isDockItem: true)
        #expect(!LayoutAudit.audit([tallDock, clipped], screen: screen).noOverlap)
        let fixed = control(4, LayoutAuditRect(x: 20, y: 740, width: 150, height: 60))
        #expect(!LayoutAudit.audit([dock, fixed], screen: screen).noOverlap)
    }

    @Test("the dock's tab items are not compared with each other, but are with the app's controls")
    func dockItemsAreComparedOnlyWithOtherControls() {
        // The iPhone Duo's closed rail: 58 pt items at a 50 pt pitch.
        let kitchen = control(1, LayoutAuditRect(x: 396, y: 384, width: 44, height: 58), isDockItem: true)
        let recipes = control(2, LayoutAuditRect(x: 396, y: 434, width: 44, height: 58), isDockItem: true)
        #expect(LayoutAudit.audit([kitchen, recipes], screen: screen).noOverlap)

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
    }
}
