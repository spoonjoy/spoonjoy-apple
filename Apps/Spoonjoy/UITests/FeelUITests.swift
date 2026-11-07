import OuroFeel
import UIKit
import XCTest

/// Ouro Feel (ourostack/ouro-ui-apple) over the fixture kitchen, by genre of jank: the way back from every screen the
/// Chefs page reaches, and, on iPad, the library sidebar closing once you pick a section. They need the seeded fixture
/// kitchen, so only `scripts/check-feel.sh` runs them; anywhere else they skip. Each writes its report to the result
/// bundle and, with `OURO_FEEL_REPORT_DIR`, to that folder.
@MainActor
final class FeelUITests: XCTestCase {
    nonisolated static let fixtureVariable = "SPOONJOY_FEEL_CHECK"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.fixtureVariable] == "1",
            "Needs the seeded fixture kitchen; run scripts/check-feel.sh."
        )
    }

    /// Opens the app upright on the kitchen. Each check calls it first: setUp is not on the main actor, and the app is.
    private func openApp() {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        for key in ["SPOONJOY_SCREENSHOT_AUTH", "SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY", "SPOONJOY_SCREENSHOT_ACCOUNT_ID"] {
            if let value = environment[key] { app.launchEnvironment[key] = value }
        }
        // Spoonjoy reopens on the last page; the walk relaunches to replay paths, so every launch opens on the kitchen.
        app.launchEnvironment["SPOONJOY_LAUNCH_ON_KITCHEN"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["kitchen.root"].waitForExistence(timeout: 60), "the kitchen opened")
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            app?.terminate()
            app = nil
        }
    }

    /// Every screen one tap from Chefs (each chef's page, and the rest) has a visible way back and a gesture back
    /// (jank item 7: a chef page had neither).
    func testTheWayBackFromChefs() {
        openApp()
        let chefs = FeelEntry("Chefs") { app in
            let button = app.buttons["kitchen.chefs"].firstMatch
            if button.waitForExistence(timeout: 10) { button.tap() }
        }
        let feel = OuroFeel(app)
        feel.expect(feel.wayBack(from: [chefs], follow: FeelFollow(types: [.button]), depth: 1, limit: 12))
    }

    /// On iPad in portrait the library sidebar is an overlay: picking a section closes it, and so does a tap beside
    /// it (jank item 8: it stayed open).
    func testTheSidebarClosesOncePicked() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "The sidebar is an overlay only on iPad.")
        openApp()
        let feel = OuroFeel(app)
        let open = FeelOverlay("library sidebar", overlay: "sidebar.addRecipe", pick: "Saved Recipes") { app in
            let toggle = app.buttons.matching(NSPredicate(format: "label == 'Show Sidebar' OR identifier == 'ToggleSidebar'")).firstMatch
            if toggle.waitForExistence(timeout: 10) { toggle.tap() }
        }
        feel.expect(feel.overlays([open]))
    }
}
