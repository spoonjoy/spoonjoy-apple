import XCTest

/// Doubled content, as a genre: a page's title shows once, in the bar or in the page, never in both. On an iPad the
/// bar's large title and the page's own heading both read "My Recipes" (the explorer sweep, 2026-11-05); on the phone
/// the heading already stepped aside for the bar.
@MainActor
final class DoubledContentUITests: XCTestCase {
    private var app: XCUIApplication!
    private var shell: ShellNavigationDriver { ShellNavigationDriver(app: app) }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[ShellNavigationDriver.fixtureVariable] == "1",
            "Needs the seeded fixture kitchen; run scripts/check-motion.sh."
        )
    }

    /// Opens the app upright. Each check calls it first: setUp is not on the main actor, and the app is.
    private func openApp() {
        XCUIDevice.shared.orientation = .portrait
        app = ShellNavigationDriver.launch()
        XCTAssertTrue(shell.waitUntil(60) { shell.shellIsUp }, "The app did not open.")
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            app?.terminate()
            app = nil
        }
    }

    func testEveryPageTitleShowsOnce() {
        openApp()
        let pages: [(ShellNavigationDriver.Place, String, () -> XCUIElement)] = [
            (.recipes, "My Recipes", { self.shell.text("Add a recipe") }),
            (.cookbooks, "Cookbooks", { self.shell.element("cookbookShelf") }),
            (.chefs, "Chefs", { self.shell.element("chefs.chef.row") }),
        ]
        for (place, title, lands) in pages {
            shell.go(to: place)
            XCTAssertTrue(lands().waitForExistence(timeout: 15), "\(title) did not open.")
            shell.assertShowsOnce(title)
        }
    }

    /// The shopping list's Edit sits in its bar; the bar's Actions menu used to carry a second Edit, on every page.
    func testShoppingListHasOneEdit() {
        openApp()
        shell.go(to: .shopping)
        let actions = app.buttons["Actions"]
        if actions.waitForExistence(timeout: 5) {
            actions.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        // The open menu covers the bar's own Edit, so count every Edit on screen rather than the hittable ones.
        let window = app.windows.firstMatch.frame
        let edits = app.buttons.matching(NSPredicate(format: "label == 'Edit'")).allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && window.intersects($0.frame)
        }
        XCTAssertEqual(edits.count, 1, "The shopping list shows \(edits.count) Edit controls: \(edits.map { $0.frame })")
    }
}
