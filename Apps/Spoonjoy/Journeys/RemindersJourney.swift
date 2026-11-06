import SpoonjoyCore
import XCTest

/// Sending a recipe's ingredients to Reminders through the real system: the OS asks for Reminders access, the cook
/// makes a list, and EventKit takes the reminders; after a relaunch a send goes through without asking again. What
/// gets added and the dedupe are proved headless in SpoonjoyReinsTests.
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
        // OS: the send reached EventKit and reported back.
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStatus).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The first send did not report back from Reminders. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "03-first-send", to: self)

        // OS: after a relaunch the send goes through without asking for access or a list again.
        verifyAfterRelaunch(journey) {
            journey.openTab(JourneyCopy.recipesTab)
            journey.openRecipe(titled: title, from: JourneyID.recipesRow)
            journey.tap(JourneyID.recipeDetailActions)
            journey.tap(JourneyID.recipeDetailRemindersSend)
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailStatus).waitForExistence(timeout: JourneyApp.networkTimeout),
                "After a relaunch the send did not go through without asking. Screen: \(journey.screen)"
            )
        }
    }
}
