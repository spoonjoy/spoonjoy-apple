import SpoonjoyCore
import XCTest

/// Journey 3: a new account has a recipe made elsewhere, sends its ingredients to Reminders, and sending the same
/// recipe again adds nothing. The Reminders list the account picked is remembered after a relaunch.
@MainActor
final class RemindersJourney: JourneyTestCase {
    func testSendToRemindersDedupesJourney() async throws {
        let account = try JourneyAccounts.account(2)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Egg Fried Rice J3"
        // There is no in-app recipe form, so the recipe is made on QA, the way the connector or a share would.
        let qa = try await JourneyQAClient.signIn(account)
        _ = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Fry the rice",
                    description: "Scramble the eggs into the hot rice.",
                    duration: nil,
                    ingredients: [
                        RecipeIngredientDraft(quantity: 3, unit: "large", name: "eggs"),
                        RecipeIngredientDraft(quantity: 2, unit: "cups", name: "rice")
                    ],
                    outputStepNums: []
                )
            ]
        )
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        journey.openTab(JourneyCopy.recipesTab)
        journey.openRecipe(titled: title, from: JourneyID.recipesRow)

        journey.attachScreenshot(named: "01-recipe", to: self)
        // First send: the system asks for access, the account picks a list, both ingredients are added.
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailRemindersSend)
        journey.allowRemindersAccessIfAsked()
        journey.attachScreenshot(named: "02-choose-list", to: self)
        journey.enterText("Journey \(token) Groceries", into: JourneyID.remindersNewListName)
        journey.tap(JourneyID.remindersCreateList)
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
