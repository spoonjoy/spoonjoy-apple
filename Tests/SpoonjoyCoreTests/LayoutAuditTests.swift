import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Layout audit")
struct LayoutAuditTests {
    private let screen = LayoutAuditRect(x: 0, y: 0, width: 400, height: 800)

    private func control(_ index: Int, _ frame: LayoutAuditRect, ancestors: [Int] = [], viewport: LayoutAuditRect? = nil) -> LayoutAuditElement {
        LayoutAuditElement(index: index, ancestors: ancestors, role: .interactive, type: "button", identifier: "control.\(index)", label: "Control \(index)", frame: frame, viewport: viewport, container: nil)
    }

    private func text(
        _ index: Int,
        _ frame: LayoutAuditRect,
        container: LayoutAuditRect? = nil,
        viewport: LayoutAuditRect? = nil,
        wordWidth: Double? = nil,
        height: Double? = nil
    ) -> LayoutAuditElement {
        LayoutAuditElement(index: index, ancestors: [], role: .text, type: "staticText", identifier: "", label: "Text \(index)", frame: frame, viewport: viewport, container: container, minimumWordWidth: wordWidth, minimumHeight: height)
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
            control(0, .init(x: 0, y: 900, width: 400, height: 44), viewport: viewport),
            control(1, .init(x: 0, y: 680, width: 400, height: 60), viewport: viewport),
            control(2, .init(x: 0, y: 700, width: 400, height: 100))
        ], screen: screen)

        #expect(report.skippedOffscreenCount == 1)
        #expect(report.noOverlap)
    }

    @Test("text inside its container and the screen, with room for its words, fits")
    func textThatHasRoomFits() {
        let report = LayoutAudit.audit([
            text(0, .init(x: 20, y: 20, width: 200, height: 40), container: .init(x: 10, y: 10, width: 300, height: 60), wordWidth: 120, height: 40.3)
        ], screen: screen)

        #expect(report.textFits)
        #expect(report.textCount == 1)
        #expect(report.textProblems.isEmpty)
    }

    @Test("clipped text fails on each edge it breaks")
    func clippedTextFails() {
        let report = LayoutAudit.audit([
            text(0, .init(x: 350, y: 20, width: 100, height: 30)),
            text(1, .init(x: 20, y: 100, width: 200, height: 30), container: .init(x: 20, y: 100, width: 150, height: 30)),
            text(2, .init(x: 20, y: 200, width: 60, height: 30), wordWidth: 140),
            text(3, .init(x: 20, y: 300, width: 200, height: 20), height: 60)
        ], screen: screen)

        #expect(report.textFits == false)
        #expect(report.textProblems.map(\.kind) == [.outsideScreen, .outsideContainer, .truncatedWidth, .truncatedHeight])
        #expect(report.textProblems.map(\.text.label) == ["Text 0", "Text 1", "Text 2", "Text 3"])
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
        let report = LayoutAudit.audit([
            control(0, .init(x: 0, y: 0, width: 100, height: 44)),
            control(1, .init(x: 50, y: 0, width: 100, height: 44)),
            text(2, .init(x: 20, y: 200, width: 60, height: 30), wordWidth: 140)
        ], screen: screen)
        let decoded = try JSONDecoder().decode(LayoutAuditReport.self, from: JSONEncoder().encode(report))

        #expect(decoded == report)
        #expect(decoded.textProblems[0].kind == .truncatedWidth)
    }
}
