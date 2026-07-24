import Foundation
import Testing

@Suite("Native macOS window diagnostic contract")
struct NativeMacWindowDiagnosticContractTests {
    @Test("signed-out diagnostics use a semantic identifier while authenticated routes keep exact labels")
    func signedOutDiagnosticUsesSemanticIdentifier() throws {
        let sourceURL = repositoryRoot()
            .appendingPathComponent("Apps/SpoonjoyMacWindowDiagnosticUITests/NativeMacWindowDiagnosticTests.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let requiredTokens = [
            "private enum MacWindowDiagnosticMarkerSelector: String, Encodable",
            "case accessibilityIdentifier = \"accessibility-identifier\"",
            "case exactLabel = \"exact-label\"",
            "private static let signedOutMarker = MacWindowDiagnosticMarker(",
            "selector: .accessibilityIdentifier",
            "value: \"native sign-in email or username\"",
            "let expectedMarker = signedIn",
            "Self.signedOutMarker",
            "switch selector",
            "matching(identifier: value)",
            "NSPredicate(format: \"label == %@\", value)",
            "routeMarker.waitForExistence"
        ]
        let missingTokens = requiredTokens.filter { !source.contains($0) }
        #expect(
            missingTokens.isEmpty,
            Comment(rawValue: "macOS diagnostic missing semantic marker contract: \(missingTokens.joined(separator: ", "))")
        )

        let forbiddenTokens = [
            "let routeMarkerLabel = signedIn ? signedInMarker : \"Spoonjoy\"",
            "NSPredicate(format: \"label == %@\", routeMarkerLabel)"
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
