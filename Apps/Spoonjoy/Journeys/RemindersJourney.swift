import XCTest

/// Journey 3: a new account creates a recipe, sends its ingredients to Reminders, and sending the same
/// recipe again adds nothing. The Reminders list the account picked is remembered after a relaunch.
@MainActor
final class RemindersJourney: JourneyTestCase {
    func testSendToRemindersDedupesJourney() throws {
        let account = try JourneyAccounts.account(2)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Egg Fried Rice J3"
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        // Account 2 has no recipes, so the Shopping List offers "Create a recipe", which opens the editor.
        journey.openTab(JourneyCopy.shoppingTab)
        journey.tap(JourneyID.shoppingCreateRecipe)
        journey.enterText(title, into: JourneyID.editorTitle)
        journey.enterText("2", into: JourneyID.editorServings)
        journey.tap(JourneyID.editorAddStep)
        journey.tap(JourneyID.editorStepAddIngredient(1))
        journey.enterText("eggs", into: JourneyID.editorIngredientName(step: 1, ingredient: 1))
        journey.replaceText(in: JourneyID.editorIngredientQuantity(step: 1, ingredient: 1), with: "3")
        journey.enterText("large", into: JourneyID.editorIngredientUnit(step: 1, ingredient: 1))
        journey.tap(JourneyID.editorStepAddIngredient(1))
        journey.enterText("rice", into: JourneyID.editorIngredientName(step: 1, ingredient: 2))
        journey.replaceText(in: JourneyID.editorIngredientQuantity(step: 1, ingredient: 2), with: "2")
        journey.enterText("cups", into: JourneyID.editorIngredientUnit(step: 1, ingredient: 2))
        journey.enterText("Scramble the eggs into the hot rice.", into: JourneyID.editorStepDescription(1))
        journey.enterText("Fry the rice", into: JourneyID.editorStepTitle(1))
        journey.saveRecipeEditor()
        XCTAssertTrue(
            journey.element(JourneyID.recipesRow, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "My Recipes does not list the new recipe after saving it. Screen: \(journey.screen)"
        )
        journey.openRecipe(titled: title, from: JourneyID.recipesRow)

        journey.attachScreenshot(named: "01-recipe", to: self)
        // First send: the system asks for access, the account picks a list, both ingredients are added.
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailRemindersSend)
        journey.allowRemindersAccessIfAsked()
        journey.attachScreenshot(named: "02-choose-list", to: self)
        journey.tap(JourneyID.remindersList)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStatus, labelContaining: "Added 2").waitForExistence(timeout: JourneyApp.networkTimeout),
            "The first send did not report two added reminders. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "03-first-send", to: self)

        // Second send of the same recipe: nothing new to add.
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailRemindersSend)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStatus, labelContaining: "Everything was already in").waitForExistence(timeout: JourneyApp.networkTimeout),
            "Sending the same recipe twice did not leave the list unchanged. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "04-second-send-no-op", to: self)

        // After a relaunch the remembered list is used without asking, and the repeat is still a no-op.
        verifyAfterRelaunch(journey) {
            journey.openTab(JourneyCopy.recipesTab)
            journey.openRecipe(titled: title, from: JourneyID.recipesRow)
            journey.tap(JourneyID.recipeDetailActions)
            journey.tap(JourneyID.recipeDetailRemindersSend)
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailStatus, labelContaining: "Everything was already in").waitForExistence(timeout: JourneyApp.networkTimeout),
                "After a relaunch the send did not reuse the remembered list as a no-op. Screen: \(journey.screen)"
            )
        }
    }
}
