import SpoonjoyCore
import XCTest

/// The iPhone Duo journey: one recipe cooked through every posture of the device. Closed, the Kitchen shows the
/// "Cooking now" strip and the tab bar's switcher, and the app reopens in cook mode on the saved step after it is
/// killed. Opened flat, the Kitchen, the cook spread and the recipe page fill the inner screen held sideways and held
/// tall. Half-open (forced with `-SpoonjoyForcePosture`, as the simulator's hinge cannot stand half-open), cook mode
/// splits at the fold on the counter and runs down the spine held like a book. Last, a recipe opens in a window of
/// its own beside the Kitchen. Every screen is saved twice: by XCUITest, and by the Mac for both Duo displays.
@MainActor
final class DuoJourney: JourneyTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        executionTimeAllowance = 1800
    }

    func testCookingThroughEveryDuoPostureJourney() async throws {
        let account = try JourneyAccounts.account(1)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Duo Tart"
        let flour = "Journey\(token)flour"
        let jam = "Journey\(token)jam"
        let qa = try await JourneyQAClient.signIn(account)
        _ = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Make the dough",
                    description: "Rub the butter into the flour until it looks like breadcrumbs, then rest the dough for an hour.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 2, unit: "cup", name: flour)],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 2,
                    stepTitle: "Fill the tart",
                    description: "Roll out the pastry, line the tin and spread the jam over it.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: jam)],
                    outputStepNums: []
                )
            ]
        )

        // Closed: the outer screen, a phone.
        try DuoHinge.set(.closed)
        XCUIDevice.shared.orientation = .portrait
        let journey = JourneyApp.launchFresh()
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )
        journey.openTab(JourneyCopy.recipesTab)
        journey.openRecipe(titled: title, from: JourneyID.recipesRow)
        journey.tap(JourneyID.recipeDetailCook)
        XCTAssertTrue(
            journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: flour).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode did not open on the first step. Screen: \(journey.screen)"
        )
        journey.tap(JourneyID.cookDockNext)
        let jamInCook = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: jam)
        XCTAssertTrue(
            jamInCook.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Next step did not turn to the second step. Screen: \(journey.screen)"
        )
        try capture("01-closed-cook-step-2", journey)

        journey.tap(JourneyID.cookClose)
        journey.openTab(JourneyCopy.kitchenTab)
        let card = journey.element(JourneyID.kitchenCookingNowCard, labelContaining: title)
        XCTAssertTrue(
            card.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Kitchen has no Cooking now card for the recipe left on step 2. Screen: \(journey.screen)"
        )
        XCTAssertTrue(card.label.contains("Step 2 of 2"), "The Cooking now card does not say step 2: \(card.label)")
        let accessory = journey.element(JourneyID.cookingNowAccessoryResume)
        XCTAssertTrue(
            accessory.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The tab bar has no Cooking now switcher. Screen: \(journey.screen)"
        )
        XCTAssertTrue(accessory.label.contains(title), "The switcher does not name the recipe: \(accessory.label)")
        try capture("02-closed-kitchen-strip-and-switcher", journey)

        accessory.tap()
        XCTAssertTrue(
            jamInCook.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The switcher did not go back to cooking on step 2. Screen: \(journey.screen)"
        )

        // Killed and launched again, the window reopens in cook mode on step 2 with no taps.
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
            XCTAssertTrue(
                jamInCook.waitForExistence(timeout: JourneyApp.networkTimeout),
                "The app did not reopen in cook mode on step 2 after it was killed. Screen: \(journey.screen)"
            )
        }
        try capture("03-closed-restored-cook-step-2", journey)

        journey.tap(JourneyID.cookClose)
        journey.openTab(JourneyCopy.kitchenTab)
        XCTAssertTrue(card.waitForExistence(timeout: JourneyApp.networkTimeout), "The Cooking now card is gone. Screen: \(journey.screen)")

        // Open flat, held sideways: the inner screen as a two-page spread.
        try DuoHinge.set(.open)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(
            card.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Opening the Duo lost the Kitchen. Screen: \(journey.screen)"
        )
        try capture("04-open-landscape-kitchen", journey)

        card.tap()
        XCTAssertTrue(
            jamInCook.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Cooking now card did not open cook mode on step 2. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.cookSpreadClose).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Cook mode on the open Duo held sideways is not the two-page spread. Screen: \(journey.screen)"
        )
        try capture("05-open-landscape-cook-spread", journey)

        journey.tap(JourneyID.cookSpreadClose)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Closing the cook spread did not return to the recipe. Screen: \(journey.screen)"
        )
        try capture("06-open-landscape-recipe", journey)

        // Open flat, held tall.
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Turning the open Duo upright lost the recipe. Screen: \(journey.screen)"
        )
        try capture("07-open-portrait-recipe", journey)

        journey.openLink(try XCTUnwrap(URL(string: "spoonjoy://kitchen")))
        XCTAssertTrue(
            card.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The kitchen link did not open the Kitchen with its Cooking now card. Screen: \(journey.screen)"
        )
        try capture("08-open-portrait-kitchen", journey)

        card.tap()
        XCTAssertTrue(
            jamInCook.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Cooking now card did not open cook mode on step 2. Screen: \(journey.screen)"
        )
        try capture("09-open-portrait-cook", journey)

        // Half-open on the counter (tabletop), then held like a book: the step and the checklist sit either side of
        // the fold.
        journey.useForcedPostureOnNextLaunch("tabletop")
        journey.relaunch()
        let stepHalf = journey.element(JourneyID.cookTabletopStep)
        XCTAssertTrue(
            stepHalf.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode on a half-open Duo did not put the step above the fold. Screen: \(journey.screen)"
        )
        XCTAssertTrue(jamInCook.waitForExistence(timeout: JourneyApp.interactionTimeout), "Tabletop cook mode is not on step 2. Screen: \(journey.screen)")
        try capture("10-tabletop-cook", journey)

        journey.useForcedPostureOnNextLaunch("book")
        journey.relaunch()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(
            jamInCook.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Book cook mode is not on step 2. Screen: \(journey.screen)"
        )
        try capture("11-book-cook", journey)

        // Back to the real hinge, open flat and sideways: a recipe opens in a window of its own beside the Kitchen.
        journey.useForcedPostureOnNextLaunch(nil)
        journey.relaunch()
        XCTAssertTrue(
            jamInCook.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The app did not reopen in cook mode on step 2 with the real hinge. Screen: \(journey.screen)"
        )
        journey.openLink(try XCTUnwrap(URL(string: "spoonjoy://kitchen")))
        let recipe = journey.element(JourneyID.kitchenRecipe, labelContaining: title)
        XCTAssertTrue(
            recipe.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Kitchen does not list the recipe. Screen: \(journey.screen)"
        )
        recipe.press(forDuration: 1.2)
        let openInNewWindow = journey.copy(JourneyCopy.openInNewWindow)
        XCTAssertTrue(
            openInNewWindow.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The recipe's menu has no Open in New Window on the open Duo. Screen: \(journey.screen)"
        )
        try capture("12-open-landscape-recipe-menu", journey)
        openInNewWindow.tap()
        let windowCount = waitForTwoWindows(journey)
        try captureScreen("13-two-windows", journey)
        XCTAssertEqual(windowCount, .completed, "Open in New Window did not open a second window. Screen: \(journey.screen)")
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The new window did not open on the recipe. Screen: \(journey.screen)"
        )

        // Killed with two windows open, each window comes back on its own page.
        journey.relaunch()
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The recipe window did not come back after the app was killed. Screen: \(journey.screen)"
        )
        try captureScreen("14-two-windows-after-relaunch", journey)
    }

    /// XCTWaiter's synchronous wait is unavailable in an async test, so it waits here.
    private func waitForTwoWindows(_ journey: JourneyApp) -> XCTWaiter.Result {
        let windows = journey.app.windows
        let twoWindows = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in windows.count >= 2 }, object: nil)
        return XCTWaiter().wait(for: [twoWindows], timeout: JourneyApp.networkTimeout)
    }

    /// Saves the app's screenshot in the result bundle and the Mac's screenshots of both Duo displays.
    private func capture(_ name: String, _ journey: JourneyApp) throws {
        journey.attachScreenshot(named: name, to: self)
        try DuoHinge.shot(name)
    }

    /// Saves the whole screen, every window of the app included, and the Mac's screenshots of both Duo displays.
    private func captureScreen(_ name: String, _ journey: JourneyApp) throws {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try DuoHinge.shot(name)
    }
}
