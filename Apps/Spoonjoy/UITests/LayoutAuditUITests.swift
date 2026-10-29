import SpoonjoyCore
import UIKit
import XCTest

/// The layout audit behind the accessibility proof's `noOverlap` and `textFits`. The fixture tests prove the audit
/// passes a sound screen and fails a real overlap and real clipped text. `testMeasureCaptureRoute` measures a
/// screenshot route; only `scripts/capture-native-screenshots.sh` runs it, with `SPOONJOY_LAYOUT_AUDIT_OUTPUT` set.
@MainActor
final class LayoutAuditUITests: XCTestCase {
    private static let outputVariable = "SPOONJOY_LAYOUT_AUDIT_OUTPUT"
    private static let proofVariable = "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"
    private var launchedApp: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            // Record a failed terminate instead of interrupting the test; see SpoonjoyShoppingUITests.tearDown.
            continueAfterFailure = true
            launchedApp?.terminate()
            launchedApp = nil
        }
    }

    func testAuditPassesASoundScreen() throws {
        let report = try measureFixture("sound")

        XCTAssertTrue(report.noOverlap, "The sound fixture overlaps: \(report.overlaps)")
        XCTAssertTrue(report.textFits, "The sound fixture clips text: \(report.textProblems)")
        XCTAssertGreaterThanOrEqual(report.interactiveCount, 2)
        XCTAssertGreaterThanOrEqual(report.textCount, 1)
    }

    func testAuditFailsOnOverlappingControls() throws {
        let report = try measureFixture("overlap")

        XCTAssertFalse(report.noOverlap, "The audit missed two crossing buttons.")
        let pairs = report.overlaps.map { Set([$0.first.identifier, $0.second.identifier]) }
        XCTAssertTrue(pairs.contains(["layoutAuditFixture.first", "layoutAuditFixture.second"]), "Overlaps: \(report.overlaps)")
    }

    func testAuditFailsOnClippedText() throws {
        let report = try measureFixture("clipped")

        XCTAssertFalse(report.textFits, "The audit missed clipped text.")
        let problems = Set(report.textProblems.map { "\($0.text.identifier):\($0.kind.rawValue)" })
        XCTAssertTrue(problems.contains("layoutAuditFixture.text:truncatedHeight"), "Problems: \(problems)")
        XCTAssertTrue(problems.contains("layoutAuditFixture.word:truncatedWidth"), "Problems: \(problems)")
    }

    /// Launches the app with the screenshot harness's environment, waits for the app's accessibility proof, then
    /// measures the screen and writes the audit, with a screenshot of what it measured, to the output path.
    func testMeasureCaptureRoute() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let output = environment[Self.outputVariable], !output.isEmpty else {
            throw XCTSkip("\(Self.outputVariable) is not set; only the screenshot capture script runs this test.")
        }
        let proofPath = try XCTUnwrap(environment[Self.proofVariable], "The capture script must pass \(Self.proofVariable).")
        try? FileManager.default.removeItem(atPath: proofPath)

        let app = XCUIApplication()
        for (key, value) in environment where key.hasPrefix("SPOONJOY_SCREENSHOT_") {
            app.launchEnvironment[key] = value
        }
        app.launch()
        launchedApp = app

        let proofWritten = expectation(for: NSPredicate { _, _ in FileManager.default.fileExists(atPath: proofPath) }, evaluatedWith: nil)
        wait(for: [proofWritten], timeout: 60)
        let proof = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: proofPath))) as? [String: Any],
            "The app's accessibility proof is not a JSON object."
        )
        let observedSize = try XCTUnwrap(proof["observedDynamicTypeSize"] as? String, "The app's proof has no observedDynamicTypeSize.")
        let contentSize = try XCTUnwrap(LayoutAuditCollector.contentSize(observed: observedSize), "Unknown text size \(observedSize).")

        let measurement = try LayoutAuditCollector.measure(app, contentSize: contentSize)
        let screenshotURL = URL(fileURLWithPath: output).deletingPathExtension().appendingPathExtension("png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: screenshotURL)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload: [String: Any] = [
            "emittedBy": "SpoonjoyLayoutAuditUITests",
            "route": proof["route"] ?? NSNull(),
            "source": proof["source"] ?? NSNull(),
            "observedDynamicTypeSize": observedSize,
            "minimumPointSize": measurement.minimumPointSize,
            "method": LayoutAuditCollector.method,
            "screen": try JSONSerialization.jsonObject(with: encoder.encode(measurement.screen)),
            "screenshot": screenshotURL.lastPathComponent,
            "report": try JSONSerialization.jsonObject(with: encoder.encode(measurement.report))
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: output))
    }

    private func measureFixture(_ name: String) throws -> LayoutAuditReport {
        let app = XCUIApplication()
        app.launchEnvironment["SPOONJOY_LAYOUT_AUDIT_FIXTURE"] = name
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", UIContentSizeCategory.large.rawValue,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        launchedApp = app
        XCTAssertTrue(app.descendants(matching: .any)["layoutAuditFixture.root"].waitForExistence(timeout: 30), "The \(name) fixture did not appear. Screen: \(app.debugDescription)")
        let measurement = try LayoutAuditCollector.measure(app, contentSize: .large)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "layout-audit-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return measurement.report
    }
}
