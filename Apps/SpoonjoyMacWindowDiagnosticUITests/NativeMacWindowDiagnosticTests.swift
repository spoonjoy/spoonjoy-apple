import XCTest

private struct MacWindowDiagnosticRect: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.width
        height = rect.height
    }
}

private enum MacWindowDiagnosticMarkerSelector: String, Encodable {
    case accessibilityIdentifier = "accessibility-identifier"
}

private struct MacWindowDiagnosticMarker {
    let selector: MacWindowDiagnosticMarkerSelector
    let value: String

    @MainActor
    func element(in app: XCUIApplication) -> XCUIElement {
        let descendants = app.descendants(matching: .any)
        switch selector {
        case .accessibilityIdentifier:
            return descendants.matching(identifier: value).firstMatch
        }
    }
}

private struct MacWindowDiagnostic: Encodable {
    let classification = "ui-window-diagnostic"
    let releaseAccessibilityEvidence: Bool = false
    let platform: String
    let route: String
    let restoredRoute: String?
    let routeMarkerSelector: MacWindowDiagnosticMarkerSelector
    let routeMarkerValue: String
    let routeMarkerLabel: String
    let routeMarkerFrame: MacWindowDiagnosticRect
    let windowFrame: MacWindowDiagnosticRect
    let accessibilityElementCount: Int
    let labeledAccessibilityElementCount: Int
    let initialWindowCount: Int
    let reopenedWindowCount: Int
    let restoredMinimizedWindow: Bool
    let recordedAt: String
}

final class NativeMacWindowDiagnosticTests: XCTestCase {
    private static let signedOutMarker = MacWindowDiagnosticMarker(
        selector: .accessibilityIdentifier,
        value: "native sign-in email or username"
    )

    private static let expectedRestoredRoutes = [
        "kitchen": "kitchen",
        "recipes": "recipes",
        "saved-recipes": "saved-recipes",
        "recipe-detail": "recipe:recipe_lemon_pantry_pasta",
        "recipe-editor": "recipe-editor:recipe_lemon_pantry_pasta",
        "recipe-covers": "recipe-covers:recipe_lemon_pantry_pasta",
        "cook-mode": "recipe-cook:recipe_lemon_pantry_pasta",
        "cook-log": "recipe:recipe_lemon_pantry_pasta",
        "cookbooks": "cookbooks",
        "cookbook-detail": "cookbook:cookbook_weeknights",
        "shopping-list": "shopping-list",
        "chefs": "chefs",
        "profile": "profile:ari",
        "profile-graph": "profile-graph:ari:kitchen-visitors:1",
        "search": "search:all:",
        "capture": "capture",
        "settings": "settings",
        "unknown-link": "unknown-link"
    ]

    @MainActor
    func testExplicitRouteWindowDiagnostic() throws {
        let environment = ProcessInfo.processInfo.environment
        let reopenProofURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-mac-reopen-\(UUID().uuidString).log")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: reopenProofURL)
        }
        let configuredRoute = try XCTUnwrap(
            environment["SPOONJOY_SCREENSHOT_EXPECTED_ROUTE"],
            "The macOS UI window diagnostic requires SPOONJOY_SCREENSHOT_EXPECTED_ROUTE."
        )
        let route = configuredRoute.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(route.isEmpty, "The macOS UI window diagnostic requires a nonempty explicit route.")
        let signedIn = environment["SPOONJOY_SCREENSHOT_AUTH"] != "0"
        let expectedRestoredRoute = try XCTUnwrap(
            Self.expectedRestoredRoutes[route],
            "Unsupported explicit macOS screenshot route: \(route)"
        )
        let expectedMarker = MacWindowDiagnosticMarker(
            selector: .accessibilityIdentifier,
            value: "screenshot.route.\(expectedRestoredRoute)"
        )
        let expectedSignedOutRouteMarker = MacWindowDiagnosticMarker(
            selector: .accessibilityIdentifier,
            value: route == "settings"
                ? "screenshot.route.settings"
                : "signed-out.route.\(expectedRestoredRoute)"
        )

        let app = XCUIApplication()
        app.launchEnvironment = environment.filter { entry in
            entry.key.hasPrefix("SPOONJOY_")
        }
        app.launchEnvironment["SPOONJOY_MAC_LAUNCH_PROOF_PATH"] = reopenProofURL.path
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15), "Spoonjoy did not expose a macOS application window")
        let initialWindowCount = app.windows.allElementsBoundByIndex.filter(\.exists).count
        XCTAssertEqual(initialWindowCount, 1, "Spoonjoy must launch with exactly one macOS application window")
        XCTAssertGreaterThan(window.frame.width, 0, "Spoonjoy macOS window has no measurable width")
        XCTAssertGreaterThan(window.frame.height, 0, "Spoonjoy macOS window has no measurable height")

        let authenticationMarker = Self.signedOutMarker.element(in: app)
        if !signedIn {
            XCTAssertTrue(
                authenticationMarker.waitForExistence(timeout: 30),
                "Signed-out route \(route) did not expose the semantic sign-in field."
            )
        }
        let routeMarker = (signedIn ? expectedMarker : expectedSignedOutRouteMarker).element(in: app)
        XCTAssertTrue(
            routeMarker.waitForExistence(timeout: 30),
            "Route \(route) did not expose its expected route-specific marker."
        )
        XCTAssertTrue(
            routeMarker.frame.intersects(window.frame),
            "Route \(route) marker is outside the application window."
        )
        XCTAssertTrue(
            app.staticTexts["Preparing"].waitForNonExistence(timeout: 10),
            "Route \(route) remained in its preparing state."
        )
        let restoredRoute: String?
        if signedIn {
            restoredRoute = nil
        } else {
            let stateDirectory = try XCTUnwrap(
                environment["SPOONJOY_SCREENSHOT_STATE_DIRECTORY"],
                "Signed-out route diagnostics require isolated screenshot state."
            )
            restoredRoute = try readRestoredRoute(in: stateDirectory)
            XCTAssertEqual(restoredRoute, expectedRestoredRoute, "Signed-out route restoration drifted for \(route).")
            if route == "cook-log" {
                XCTAssertEqual(environment["SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS"], "cook-log")
            }
        }

        let accessibilityElements = app.descendants(matching: .any)
            .allElementsBoundByAccessibilityElement
            .filter(\.exists)
        let labeledAccessibilityElements = accessibilityElements.filter {
            !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        XCTAssertGreaterThan(
            accessibilityElements.count,
            0,
            "The macOS window exposed no XCUI accessibility elements."
        )
        XCTAssertGreaterThan(
            labeledAccessibilityElements.count,
            0,
            "The macOS window exposed no labeled XCUI accessibility elements."
        )

        let proofLineCountBeforeReopen = try launchProofLines(at: reopenProofURL).count
        let minimizeButton = window.buttons[XCUIIdentifierMinimizeWindow]
        XCTAssertTrue(minimizeButton.waitForExistence(timeout: 5), "Spoonjoy did not expose a native minimize control")
        minimizeButton.click()
        XCTAssertTrue(
            waitUntil(timeout: 5) { !window.isHittable },
            "Spoonjoy did not minimize its existing macOS window"
        )

        app.activate()
        XCTAssertTrue(
            waitUntil(timeout: 10) { window.exists && window.isHittable },
            "Reactivating Spoonjoy did not restore its minimized macOS window"
        )
        let reopenedWindowCount = app.windows.allElementsBoundByIndex.filter(\.exists).count
        XCTAssertEqual(reopenedWindowCount, 1, "Dock reopen must not construct a second Spoonjoy window")
        let reopenProofLines = try launchProofLines(at: reopenProofURL).dropFirst(proofLineCountBeforeReopen)
        XCTAssertTrue(
            reopenProofLines.contains { $0.contains("show-main-window-existing-deminiaturized cardinality-before=1 cardinality-after=1") },
            "Dock reopen must deminiaturize the existing app window while preserving cardinality: \(Array(reopenProofLines))"
        )

        let diagnostic = MacWindowDiagnostic(
            platform: "macos",
            route: route,
            restoredRoute: restoredRoute,
            routeMarkerSelector: signedIn ? expectedMarker.selector : expectedSignedOutRouteMarker.selector,
            routeMarkerValue: signedIn ? expectedMarker.value : expectedSignedOutRouteMarker.value,
            routeMarkerLabel: routeMarker.label,
            routeMarkerFrame: MacWindowDiagnosticRect(routeMarker.frame),
            windowFrame: MacWindowDiagnosticRect(window.frame),
            accessibilityElementCount: accessibilityElements.count,
            labeledAccessibilityElementCount: labeledAccessibilityElements.count,
            initialWindowCount: initialWindowCount,
            reopenedWindowCount: reopenedWindowCount,
            restoredMinimizedWindow: true,
            recordedAt: ISO8601DateFormatter().string(from: Date())
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(diagnostic)
        let diagnosticAttachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        diagnosticAttachment.name = "macos-ui-window-diagnostic"
        diagnosticAttachment.lifetime = .keepAlways
        add(diagnosticAttachment)

        let screenshotAttachment = XCTAttachment(screenshot: window.screenshot())
        screenshotAttachment.name = "macos-ui-window-diagnostic-screenshot"
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)
    }

    private func launchProofLines(at url: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        return try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }

    private func readRestoredRoute(in stateDirectory: String) throws -> String {
        let stateURL = URL(fileURLWithPath: stateDirectory, isDirectory: true)
            .appendingPathComponent("native-app-state.json")
        let data = try Data(contentsOf: stateURL)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "The screenshot app-state fixture is not a JSON object."
        )
        return try XCTUnwrap(
            object["lastOpenedRoute"] as? String,
            "The screenshot app-state fixture has no lastOpenedRoute."
        )
    }

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return condition()
    }
}
