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

private struct MacWindowDiagnostic: Encodable {
    let classification = "ui-window-diagnostic"
    let releaseAccessibilityEvidence: Bool = false
    let platform: String
    let route: String
    let routeMarkerLabel: String
    let routeMarkerFrame: MacWindowDiagnosticRect
    let windowFrame: MacWindowDiagnosticRect
    let accessibilityElementCount: Int
    let labeledAccessibilityElementCount: Int
    let recordedAt: String
}

final class NativeMacWindowDiagnosticTests: XCTestCase {
    private static let supportedRouteMarkers = [
        "kitchen": "Lemon Pantry Pasta",
        "recipes": "Lemon Pantry Pasta",
        "saved-recipes": "Lemon Pantry Pasta",
        "recipe-detail": "Lemon Pantry Pasta",
        "recipe-editor": "Recipe",
        "recipe-covers": "Photo Studio",
        "cook-mode": "Current cooking step 1, Boil pasta",
        "cook-log": "Cooks",
        "cookbooks": "Weeknights",
        "cookbook-detail": "Weeknights",
        "shopping-list": "Lemons",
        "chefs": "Chefs",
        "profile": "@ari",
        "profile-graph": "jules",
        "search": "Search",
        "capture": "Imports",
        "settings": "Account",
        "unknown-link": "Link Not Found"
    ]

    @MainActor
    func testExplicitRouteWindowDiagnostic() throws {
        let environment = ProcessInfo.processInfo.environment
        let configuredRoute = try XCTUnwrap(
            environment["SPOONJOY_SCREENSHOT_EXPECTED_ROUTE"],
            "The macOS UI window diagnostic requires SPOONJOY_SCREENSHOT_EXPECTED_ROUTE."
        )
        let route = configuredRoute.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(route.isEmpty, "The macOS UI window diagnostic requires a nonempty explicit route.")
        let signedIn = environment["SPOONJOY_SCREENSHOT_AUTH"] != "0"
        let signedInMarker = try XCTUnwrap(
            Self.supportedRouteMarkers[route],
            "Unsupported explicit macOS screenshot route: \(route)"
        )
        let routeMarkerLabel = signedIn ? signedInMarker : "Spoonjoy"

        let app = XCUIApplication()
        app.launchEnvironment = environment.filter { entry in
            entry.key.hasPrefix("SPOONJOY_")
        }
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15), "Spoonjoy did not expose a macOS application window")
        XCTAssertGreaterThan(window.frame.width, 0, "Spoonjoy macOS window has no measurable width")
        XCTAssertGreaterThan(window.frame.height, 0, "Spoonjoy macOS window has no measurable height")

        let routeMarker = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", routeMarkerLabel))
            .firstMatch
        XCTAssertTrue(
            routeMarker.waitForExistence(timeout: 30),
            "Route \(route) did not expose its expected XCUI marker \(routeMarkerLabel)."
        )
        XCTAssertTrue(
            routeMarker.frame.intersects(window.frame),
            "Route \(route) marker is outside the application window."
        )
        XCTAssertTrue(
            app.staticTexts["Preparing"].waitForNonExistence(timeout: 10),
            "Route \(route) remained in its preparing state."
        )

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

        let diagnostic = MacWindowDiagnostic(
            platform: "macos",
            route: route,
            routeMarkerLabel: routeMarkerLabel,
            routeMarkerFrame: MacWindowDiagnosticRect(routeMarker.frame),
            windowFrame: MacWindowDiagnosticRect(window.frame),
            accessibilityElementCount: accessibilityElements.count,
            labeledAccessibilityElementCount: labeledAccessibilityElements.count,
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
}
