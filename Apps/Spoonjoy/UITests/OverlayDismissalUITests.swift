import XCTest

/// Overlays, as a genre: a panel that covers or squeezes the page (the sidebar on an upright iPad; popovers and menus
/// are the system's own) steps aside once something in it is chosen. A sidebar beside the page on a wide screen
/// stays. The sidebar used to stay after a choice until it was closed by hand (Ari, 2026-11-05).
@MainActor
final class OverlayDismissalUITests: XCTestCase {
    private var app: XCUIApplication!
    private var shell: ShellNavigationDriver { ShellNavigationDriver(app: app) }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[ShellNavigationDriver.fixtureVariable] == "1",
            "Needs the seeded fixture kitchen; run scripts/check-motion.sh."
        )
    }

    /// Opens the app upright. Each check calls it first: setUp is not on the main actor, and the app is.
    private func openApp() {
        XCUIDevice.shared.orientation = .portrait
        app = ShellNavigationDriver.launch()
        // The app reopens on the page the last check left it on, so the checks wait for the shell, not the Kitchen.
        XCTAssertTrue(shell.waitUntil(60) { shell.shellIsUp }, "The app did not open.")
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            XCUIDevice.shared.orientation = .portrait
            app?.terminate()
            app = nil
        }
    }

    /// Upright, the sidebar squeezes the page into a narrow column beside it, so each row chosen in it puts it away
    /// and the page gets the whole window back.
    func testSidebarSqueezingThePageStepsAsideAfterAChoice() throws {
        openApp()
        try XCTSkipUnless(shell.usesSidebar, "The phone layout has no sidebar.")
        shell.assertSidebarStepsAsideAfterChoosing("My Recipes", lands: { self.app.navigationBars["My Recipes"] })
        shell.assertSidebarStepsAsideAfterChoosing("Chefs", lands: { self.app.navigationBars["Chefs"] })
        // Cookbooks heads a disclosure group; its label used to take no part in the selection, so it opened nothing.
        shell.assertSidebarStepsAsideAfterChoosing("Cookbooks", lands: { self.shell.element("cookbookShelf") })
        // The fixture kitchen's own books are not listed under Cookbooks in the sidebar, so a book row is not walked here.
        shell.assertSidebarStepsAsideAfterChoosing("Saved Recipes", lands: { self.app.navigationBars["Saved Recipes"] })
    }

    /// Sideways, the sidebar sits beside the page, so choosing in it leaves it where it is.
    func testSidebarBesideThePageStays() throws {
        openApp()
        try XCTSkipUnless(shell.usesSidebar, "The phone layout has no sidebar.")
        XCUIDevice.shared.orientation = .landscapeLeft
        // Start somewhere else, so the app reopening on Chefs cannot pass the check without a choice.
        shell.showSidebar()
        shell.sidebarRow("My Recipes").tap()
        XCTAssertTrue(app.navigationBars["My Recipes"].waitForExistence(timeout: 15), "Choosing My Recipes did not open it.")
        shell.showSidebar()
        shell.sidebarRow("Chefs").tap()
        XCTAssertTrue(app.navigationBars["Chefs"].waitForExistence(timeout: 15), "Choosing Chefs did not open it.")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertTrue(shell.sidebarShows, "The sidebar beside the page closed after a choice.")
    }
}
