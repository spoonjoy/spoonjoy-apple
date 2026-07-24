import Foundation
import Testing

@Suite("Native macOS window diagnostic contract")
struct NativeMacWindowDiagnosticContractTests {
    @Test("signed-out and authenticated diagnostics prove the requested route from live route-state identifiers")
    func signedOutDiagnosticProvesRequestedRoute() throws {
        let sourceURL = repositoryRoot()
            .appendingPathComponent("Apps/SpoonjoyMacWindowDiagnosticUITests/NativeMacWindowDiagnosticTests.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let requiredTokens = [
            "private enum MacWindowDiagnosticMarkerSelector: String, Encodable",
            "case accessibilityIdentifier = \"accessibility-identifier\"",
            "private static let signedOutMarker = MacWindowDiagnosticMarker(",
            "selector: .accessibilityIdentifier",
            "value: \"native sign-in email or username\"",
            "private static let expectedRestoredRoutes",
            "value: \"screenshot.route.\\(expectedRestoredRoute)\"",
            "? \"screenshot.route.settings\"",
            ": \"signed-out.route.\\(expectedRestoredRoute)\"",
            "restoredRoute = try readRestoredRoute(",
            "XCTAssertEqual(restoredRoute, expectedRestoredRoute",
            "let routeMarker = (signedIn ? expectedMarker : expectedSignedOutRouteMarker).element(in: app)",
            "routeMarker.waitForExistence(timeout: 30)",
            "switch selector",
            "matching(identifier: value)",
            "routeMarker.waitForExistence"
        ]
        let missingTokens = requiredTokens.filter { !source.contains($0) }
        #expect(
            missingTokens.isEmpty,
            Comment(rawValue: "macOS diagnostic missing semantic marker contract: \(missingTokens.joined(separator: ", "))")
        )

        let forbiddenTokens = [
            "let routeMarkerLabel = signedIn ? signedInMarker : \"Spoonjoy\"",
            "NSPredicate(format: \"label == %@\", routeMarkerLabel)",
            "selector: .exactLabel",
            "private static let supportedRouteMarkers",
            "private static let signedOutRouteMarkers"
        ]
        let forbiddenHits = forbiddenTokens.filter(source.contains)
        #expect(
            forbiddenHits.isEmpty,
            Comment(rawValue: "macOS diagnostic still uses brittle anonymous brand-label matching: \(forbiddenHits.joined(separator: ", "))")
        )
    }
}

private func repositoryRoot() -> URL {
    var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}
