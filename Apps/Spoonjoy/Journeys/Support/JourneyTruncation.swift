import SpoonjoyCore
import XCTest

/// Holds a screen to no text cut short. Web's faces differ in width from San Francisco and New York, so the recipe,
/// cook step and kitchen are held to this at the default and the largest accessibility text size.
@MainActor
enum JourneyTruncation {
    /// Fails when a line on the screen is drawn cut short with an ellipsis, read from a screenshot by the layout audit
    /// (`LayoutAuditCollector`), naming each cut line, or when the audit can't read the screen.
    static func assertNone(
        _ journey: JourneyApp, on screen: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let report = try? LayoutAuditCollector.measure(journey.app).report
        let cut = report?.textProblems.filter { $0.kind == .truncated } ?? []
        XCTAssertNotNil(report, "\(screen): the layout audit could not measure the screen.", file: file, line: line)
        XCTAssertGreaterThan(report?.drawnTextCount ?? 0, 0, "\(screen): the audit read no drawn text.", file: file, line: line)
        XCTAssertTrue(cut.isEmpty, "\(screen) cuts text short: \(cut.map { $0.drawnText ?? $0.text.identifier })", file: file, line: line)
    }
}
