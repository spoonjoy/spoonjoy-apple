import XCTest

/// Back navigation, as a genre: every page opened from another has a back button and goes back with a swipe in from
/// the edge, and every sheet has a close control and goes away with a swipe down. Run on an iPhone (tab bar) and on an
/// iPad (sidebar); on the iPad, Chefs then a chef used to have neither (Ari, 2026-11-05).
@MainActor
final class BackNavigationUITests: XCTestCase {
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
            app?.terminate()
            app = nil
        }
    }

    /// Walks every kind of pushed page the fixture kitchen has: a recipe from a Kitchen row and from the counter, a
    /// cookbook from the shelf, a recipe from a cookbook, and a chef from Chefs.
    func testEveryPushedPageGoesBackByButtonAndEdgeSwipe() {
        openApp()
        let recipePage = { self.shell.element("recipeDetail.cook") }

        shell.assertGoesBack(
            "Kitchen, then a recipe", from: .kitchen,
            home: { self.shell.element("kitchen.root") },
            open: { self.shell.text("Tomato Toast").firstMatchTap() },
            page: recipePage
        )
        shell.assertGoesBack(
            "Kitchen, then the recipe on the counter", from: .kitchen,
            home: { self.shell.element("kitchen.root") },
            open: { self.shell.element("kitchen.recipe.open").firstMatchTap() },
            page: recipePage
        )
        shell.assertGoesBack(
            "Cookbooks, then a cookbook", from: .cookbooks,
            home: { self.shell.element("cookbookShelf") },
            open: { self.shell.text("Weeknights").firstMatchTap() },
            page: { self.shell.element("cookbookContentsIndex") }
        )
        shell.assertGoesBack(
            "A cookbook, then a recipe", from: .cookbooks,
            home: { self.shell.element("cookbookShelf") },
            open: {
                self.shell.text("Weeknights").firstMatchTap()
                XCTAssertTrue(self.shell.element("cookbookContentsIndex").waitForExistence(timeout: 15))
                self.shell.text("Tomato Toast").firstMatchTap()
            },
            page: recipePage,
            backTo: { self.shell.element("cookbookContentsIndex") }
        )
        shell.assertGoesBack(
            "Chefs, then a chef", from: .chefs,
            home: { self.shell.element("chefs.chef.row") },
            open: { self.shell.element("chefs.chef.row").firstMatchTap() },
            page: { self.shell.element("profile.moderationMenu") }
        )
    }

    /// Cook mode started from the Kitchen's counter closes back to the Kitchen, by its Close and by a pull on the lower
    /// edge of its own bar (#215: Close pushed the recipe, and a pull there did nothing).
    func testCookModeFromTheKitchenClosesBackToTheKitchen() {
        openApp()
        for way in ["its close button", "a pull on its bar"] {
            shell.go(to: .kitchen)
            let cook = shell.element("kitchen.recipe.cook")
            XCTAssertTrue(cook.waitForExistence(timeout: 30), "The Kitchen has no recipe to cook.")
            cook.tap()
            let close = shell.element("cook.close")
            XCTAssertTrue(close.waitForHittable(timeout: 30), "Cook mode did not open.")
            if way == "its close button" {
                close.tap()
            } else {
                // Just above the bar's lower edge, where a pull used to belong to the page.
                let bar = app.navigationBars.firstMatch.frame
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: bar.maxY - 8))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: app.frame.height * 0.6)),
                            withVelocity: .fast, thenHoldForDuration: 0)
            }
            XCTAssertTrue(shell.waitUntil(10) { !close.exists }, "Cook mode did not close with \(way).")
            XCTAssertTrue(shell.waitUntil(10) { shell.element("kitchen.root").isHittable },
                          "Closing cook mode with \(way) did not land back on the Kitchen. Back: \(shell.backButton.exists ? shell.backButton.label : "none")")
            XCTAssertFalse(shell.backButton.exists, "Closing cook mode with \(way) pushed a page onto the Kitchen.")
        }
    }

    /// Every sheet the fixture kitchen can open has a close control, and a swipe down closes it too.
    func testEverySheetClosesByButtonAndSwipeDown() {
        openApp()
        for way in ["its close button", "a swipe down"] {
            // Add a recipe, from the bar's plus.
            shell.go(to: .kitchen)
            shell.element("kitchen.addRecipe").tap()
            let close = app.buttons["Close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10), "Add a recipe has no close control.")
            if way == "its close button" {
                close.tap()
            } else {
                shell.swipeSheetDown(holding: close)
            }
            XCTAssertTrue(shell.waitUntil(8) { !close.exists }, "Add a recipe did not close with \(way).")
        }
    }
}

private extension XCUIElement {
    func firstMatchTap() {
        XCTAssertTrue(waitForExistence(timeout: 15), "\(self) is not on screen.")
        tap()
    }
}
