import SpoonjoyCore
import UIKit
import XCTest

/// The layout audit behind the accessibility proof's `noOverlap`, `textFits` and `controlsOnScreen`. The fixture
/// tests prove the audit passes a sound screen and fails a real overlap, a control run off the screen and really
/// truncated text, and that the app's proof states only what it observed. `testMeasureCaptureRoute` measures a
/// screenshot route; only `scripts/capture-native-screenshots.sh` runs it, with `SPOONJOY_LAYOUT_AUDIT_OUTPUT` set.
@MainActor
final class LayoutAuditUITests: XCTestCase {
    private static let outputVariable = "SPOONJOY_LAYOUT_AUDIT_OUTPUT"
    private static let expectedDynamicTypeVariable = "SPOONJOY_LAYOUT_AUDIT_EXPECTED_DYNAMIC_TYPE"
    private static let proofVariable = "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"
    /// Layout results only the audit measures, so the app's own proof must never state them.
    private static let unmeasuredProofKeys = ["reduceMotion", "noOverlap", "textFits", "controlsOnScreen", "noTinyClusters"]
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
        let report = try measureFixture(.sound)

        XCTAssertTrue(report.noOverlap, "The sound fixture overlaps: \(report.overlaps)")
        XCTAssertTrue(report.textFits, "The sound fixture clips text: \(report.textProblems)")
        XCTAssertTrue(report.controlsOnScreen, "The sound fixture clips controls: \(report.clippedControls)")
        XCTAssertGreaterThanOrEqual(report.interactiveCount, 2)
        XCTAssertGreaterThanOrEqual(report.textCount, 1)
        XCTAssertGreaterThanOrEqual(report.drawnTextCount, 3, "Text recognition read too little of the sound fixture.")
    }

    func testAuditFailsOnOverlappingControls() throws {
        let report = try measureFixture(.overlap)

        XCTAssertFalse(report.noOverlap, "The audit missed two crossing buttons.")
        let pairs = report.overlaps.map { Set([$0.first.identifier, $0.second.identifier]) }
        XCTAssertTrue(pairs.contains(["layoutAuditFixture.first", "layoutAuditFixture.second"]), "Overlaps: \(report.overlaps)")
    }

    func testAuditFailsOnControlRunOffScreen() throws {
        let report = try measureFixture(.offscreenControl)

        XCTAssertFalse(report.controlsOnScreen, "The audit missed a button running off the screen.")
        let clipped = try XCTUnwrap(report.clippedControls.first { $0.control.identifier == "layoutAuditFixture.first" }, "Clipped: \(report.clippedControls)")
        XCTAssertLessThan(clipped.visibleFraction, 1)
    }

    func testAuditFailsOnTruncatedText() throws {
        let report = try measureFixture(.clipped)

        XCTAssertFalse(report.textFits, "The audit missed truncated text.")
        let problems = Set(report.textProblems.map { "\($0.text.identifier):\($0.kind.rawValue)" })
        XCTAssertTrue(problems.contains("layoutAuditFixture.text:truncated"), "Problems: \(report.textProblems)")
        XCTAssertTrue(problems.contains("layoutAuditFixture.word:truncated"), "Problems: \(report.textProblems)")
    }

    /// The offline status pill's case: the drawn text is truncated while its accessibility label, which differs,
    /// would fit. The audit must judge what was drawn.
    func testAuditFailsOnATruncatedPillWhoseLabelDiffers() throws {
        let report = try measureFixture(.pill)

        let problem = try XCTUnwrap(report.textProblems.first { $0.text.identifier == "layoutAuditFixture.pill" }, "Problems: \(report.textProblems)")
        XCTAssertEqual(problem.kind, .truncated)
        XCTAssertEqual(problem.text.label, "Saved kitchen may be out of date")
        XCTAssertTrue(problem.drawnText?.contains("Saved copy") == true, "Drawn: \(problem.drawnText ?? "nil")")
    }

    /// The app's proof reports Reduce Motion and the text size as observed on the device, and states no layout
    /// result, which only this audit can measure.
    func testProofStatesOnlyWhatTheAppObserved() throws {
        let proofURL = FileManager.default.temporaryDirectory.appendingPathComponent("layout-audit-fixture-proof-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: proofURL) }
        _ = try measureFixture(.sound, proofPath: proofURL.path)

        let proofWritten = expectation(for: NSPredicate { _, _ in FileManager.default.fileExists(atPath: proofURL.path) }, evaluatedWith: nil)
        wait(for: [proofWritten], timeout: 30)
        let proof = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: proofURL)) as? [String: Any])

        XCTAssertEqual(proof["observedReduceMotion"] as? Bool, UIAccessibility.isReduceMotionEnabled)
        XCTAssertEqual(proof["observedDynamicTypeSize"] as? String, "large")
        for key in Self.unmeasuredProofKeys {
            XCTAssertNil(proof[key], "The app's proof claims \(key), which nothing in the app measures.")
        }
    }

    /// Launches the app with the screenshot harness's environment, waits for the app's accessibility proof, checks
    /// the app drew the requested text size, then measures the screen and writes the audit, with the screenshot it
    /// measured, to the output path.
    func testMeasureCaptureRoute() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let output = environment[Self.outputVariable], !output.isEmpty else {
            throw XCTSkip("\(Self.outputVariable) is not set; only the screenshot capture script runs this test.")
        }
        let proofPath = try XCTUnwrap(environment[Self.proofVariable], "The capture script must pass \(Self.proofVariable).")
        let expectedSize = try XCTUnwrap(environment[Self.expectedDynamicTypeVariable], "The capture script must pass \(Self.expectedDynamicTypeVariable).")
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
        XCTAssertEqual(observedSize, expectedSize, "The app drew \(observedSize), not the requested \(expectedSize); the audit would measure the wrong screen.")

        let measurement = try LayoutAuditCollector.measure(app)
        let screenshotURL = URL(fileURLWithPath: output).deletingPathExtension().appendingPathExtension("png")
        try measurement.screenshot.pngRepresentation.write(to: screenshotURL)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload: [String: Any] = [
            "emittedBy": "SpoonjoyLayoutAuditUITests",
            "route": proof["route"] ?? NSNull(),
            "source": proof["source"] ?? NSNull(),
            "observedDynamicTypeSize": observedSize,
            "method": LayoutAuditCollector.method,
            "screen": try JSONSerialization.jsonObject(with: encoder.encode(measurement.screen)),
            "screenshot": screenshotURL.lastPathComponent,
            "drawnText": try JSONSerialization.jsonObject(with: encoder.encode(measurement.drawnText)),
            "elements": try JSONSerialization.jsonObject(with: encoder.encode(measurement.elements)),
            "report": try JSONSerialization.jsonObject(with: encoder.encode(measurement.report))
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: output))
    }

    private func measureFixture(_ fixture: String, proofPath: String? = nil) throws -> LayoutAuditReport {
        let app = XCUIApplication()
        app.launchEnvironment["SPOONJOY_LAYOUT_AUDIT_FIXTURE"] = fixture
        if let proofPath {
            app.launchEnvironment[Self.proofVariable] = proofPath
        }
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", UIContentSizeCategory.large.rawValue,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        launchedApp = app
        XCTAssertTrue(app.descendants(matching: .any)["layoutAuditFixture.root"].waitForExistence(timeout: 30), "The \(fixture) fixture did not appear. Screen: \(app.debugDescription)")
        let measurement = try LayoutAuditCollector.measure(app)
        let attachment = XCTAttachment(screenshot: measurement.screenshot)
        attachment.name = "layout-audit-\(fixture)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let lines = XCTAttachment(string: measurement.drawnText.map(\.text).joined(separator: "\n"))
        lines.name = "layout-audit-\(fixture)-drawn-text"
        lines.lifetime = .keepAlways
        add(lines)
        return measurement.report
    }
}

private extension String {
    static let sound = "sound"
    static let overlap = "overlap"
    static let clipped = "clipped"
    static let pill = "pill"
    static let offscreenControl = "offscreenControl"
}
