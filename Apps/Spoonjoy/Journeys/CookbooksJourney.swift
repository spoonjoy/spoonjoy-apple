import SpoonjoyCore
import XCTest

/// The cookbook page's checks that need the real UI: its search field stays pinned when the page scrolls under the
/// solid top edge, a match and the no-match message stay above the keyboard, and Return closes the keyboard. What the
/// search matches, the shelf and the not-found route are proved headless in SpoonjoyReinsTests. The checks run on a
/// cold start: the relaunch comes first.
@MainActor
final class CookbooksJourney: JourneyTestCase {
    func testCookbooksJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let cookbookTitle = "Journey \(token) Shelf J5"
        let titles = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"].map { "Journey \(token) \($0) J5" }

        // Six recipes, so the page is long enough to scroll.
        let qa = try await JourneyQAClient.signIn(account)
        let cookbookID = try await qa.createCookbook(title: cookbookTitle)
        try await addRecipe(titles[0], number: 1, to: cookbookID, using: qa)
        try await addRecipe(titles[1], number: 2, to: cookbookID, using: qa)
        try await addRecipe(titles[2], number: 3, to: cookbookID, using: qa)
        try await addRecipe(titles[3], number: 4, to: cookbookID, using: qa)
        try await addRecipe(titles[4], number: 5, to: cookbookID, using: qa)
        try await addRecipe(titles[5], number: 6, to: cookbookID, using: qa)
        let cookbookLink = try XCTUnwrap(URL(string: "spoonjoy://cookbooks/\(cookbookID)"))

        let journey = JourneyApp.launchFresh()
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        verifyAfterRelaunch(journey) {
            journey.openLink(cookbookLink)
            XCTAssertTrue(
                cookbookRow(journey, titles[0]).waitForExistence(timeout: JourneyApp.networkTimeout),
                "The cookbook page does not list its first recipe. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "02-cookbook-top", to: self)

            // UI: scrolling moves the title under the solid top edge while the search field stays reachable.
            journey.app.swipeUp()
            journey.attachScreenshot(named: "03-cookbook-scrolled", to: self)
            XCTAssertTrue(journey.element(JourneyID.cookbookSearchField).exists, "The scrolled cookbook page lost its search field. Screen: \(journey.screen)")

            // UI: a match sits above the keyboard.
            journey.enterText("Charlie", into: JourneyID.cookbookSearchField)
            assertAboveKeyboard(cookbookRow(journey, titles[2]), in: journey, "The Charlie match is hidden under the keyboard. Screen: \(journey.screen)")
            journey.attachScreenshot(named: "04-cookbook-search-match", to: self)

            // UI: the no-match message sits above the keyboard.
            journey.replaceText(in: JourneyID.cookbookSearchField, with: "Journey\(token)nothing")
            assertAboveKeyboard(journey.element(JourneyID.cookbookSearchEmpty), in: journey, "The no-match message is hidden under the keyboard. Screen: \(journey.screen)")
            journey.attachScreenshot(named: "05-cookbook-search-empty", to: self)

            // UI: Return closes the keyboard and leaves the message in view.
            journey.pressReturn()
            XCTAssertTrue(
                journey.app.keyboards.firstMatch.waitForNonExistence(timeout: JourneyApp.interactionTimeout),
                "Return did not close the keyboard. Screen: \(journey.screen)"
            )
            XCTAssertTrue(journey.element(JourneyID.cookbookSearchEmpty).exists, "Closing the keyboard lost the no-match message. Screen: \(journey.screen)")
            journey.attachScreenshot(named: "05b-cookbook-search-keyboard-closed", to: self)
        }
    }

    private func addRecipe(_ title: String, number: Int, to cookbookID: String, using qa: JourneyQAClient) async throws {
        let recipeID = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Step \(number)",
                    description: "Cook it.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "journeyflour\(number)")],
                    outputStepNums: []
                )
            ]
        )
        try await qa.addRecipe(recipeID, toCookbook: cookbookID)
    }

    /// Waits until the element is on screen and tappable while the search field still has focus, and, when a software
    /// keyboard is up, sits fully above it. It reads what the app shows, not the keyboard alone: a simulator with a
    /// hardware keyboard connected raises none, and the match is then simply in view (#217).
    private func assertAboveKeyboard(_ element: XCUIElement, in journey: JourneyApp, _ message: @autoclosure () -> String, file: StaticString = #filePath, line: UInt = #line) {
        let keyboard = journey.app.keyboards.firstMatch
        let field = journey.focusedField(JourneyID.cookbookSearchField)
        let isClear = NSPredicate { _, _ in
            guard element.exists, element.isHittable, field.exists else { return false }
            return !keyboard.exists || element.frame.maxY <= keyboard.frame.minY
        }
        let wait = { XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: isClear, object: nil)], timeout: JourneyApp.interactionTimeout) }
        XCTAssertEqual(wait(), .completed, message(), file: file, line: line)
        // A keyboard still on its way up could cover the element after the first look; once it is up, look again.
        if keyboard.waitForExistence(timeout: 1) {
            XCTAssertEqual(wait(), .completed, message(), file: file, line: line)
        }
    }

    private func cookbookRow(_ journey: JourneyApp, _ recipeTitle: String) -> XCUIElement {
        journey.app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ". \(recipeTitle)")).firstMatch
    }
}
