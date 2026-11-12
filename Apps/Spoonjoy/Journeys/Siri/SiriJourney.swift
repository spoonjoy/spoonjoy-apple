import SpoonjoyCore
import XCTest

/// Siri and Shortcuts against the real app. A simulator has no Siri to speak to, so AppIntentsTesting stands in for the
/// spoken request: it runs each App Shortcut's intent out of process, by bundle identifier, the way Siri does once it
/// has matched the phrase. Everything after the phrase is real: the recipe query Siri asks "Which Spoonjoy recipe?"
/// with, each intent's `perform()` in the app's process, cook mode on screen, the cook sync and QA's shopping list.
/// Matching the spoken phrase itself needs a device (spoonjoy/app-store-submission/siri in the desk has the checklist).
@MainActor
final class SiriJourney: JourneyTestCase {
    @available(iOS 27.0, *)
    func testSiriShortcutsDriveCookModeAndShoppingJourney() async throws {
        let account = try JourneyAccounts.account(1)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Siri J3"
        let eggs = "Journey\(token)siri-eggs"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Brown the butter",
                    description: "Melt the butter and let it foam until it smells nutty.",
                    duration: 4,
                    ingredients: [RecipeIngredientDraft(quantity: 50, unit: "g", name: "Journey\(token)butter")],
                    outputStepNums: []
                ),
                RecipeStepDraft(stepNum: 2, stepTitle: "Add the sage", description: "Add the sage leaves and let them crisp.", duration: nil, ingredients: [], outputStepNums: []),
                RecipeStepDraft(stepNum: 3, stepTitle: "Toss the pasta", description: "Toss the pasta in the butter and serve.", duration: nil, ingredients: [], outputStepNums: [])
            ]
        )
        let journey = JourneyApp.launchFresh()
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )
        // The job's simulator is an iPhone Duo, whose hinge may read closed on a later launch; cook mode then shows the
        // cover glance instead of the step page (run 43196335144). The cook talks to Siri with the phone open, so every
        // launch from here on reports it lying flat.
        journey.useForcedPostureOnNextLaunch("flat")
        journey.relaunch()
        let siri = JourneyIntents()
        try await siri.waitUntilRegistered()

        // A cook asks Siri for a recipe in their kitchen, so the journey waits until the kitchen shows it: the app has
        // synced it, and Siri must then find it by name (run 43099980913 asked before the sync and found nothing).
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRecipe, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The kitchen never showed the new recipe, so the app had not synced it. Screen: \(journey.screen)"
        )
        // "Start cooking in Spoonjoy" → "Which Spoonjoy recipe?" → the cook says the title. The recipe query must find
        // it by name, and Start Cooking must open it in cook mode.
        let recipe = try await siri.recipe(titled: title, recipeID: recipeID)
        try await siri.startCooking(recipe)
        // Start Cooking's perform() hands the system the cook link to open (`opensIntent: OpenURLIntent`, the link that
        // CookModeParityTests pins). Siri opens it; AppIntentsTesting only runs perform() and left the app on the kitchen
        // (run 43192397701), so the journey opens that same link the way the system would. That Siri itself follows the
        // link is on the device checklist. AppIntentsTesting returns only the intent's value, not its opensIntent, so here
        // the journey proves perform() succeeds for this recipe; the link itself is CookModeParityTests' to pin.
        journey.openLink(try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook")))
        XCTAssertTrue(
            stepMeta(journey, "Step 1 of 3").waitForExistence(timeout: JourneyApp.networkTimeout),
            "Start Cooking did not open the recipe in cook mode at step 1. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "siri-01-start-cooking", to: self)

        // "Next step in Spoonjoy" turns the page; "Previous step" turns it back; "Read the step" leaves it put.
        try await siri.nextStep()
        XCTAssertTrue(
            stepMeta(journey, "Step 2 of 3").waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Next step did not move cook mode to step 2. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "siri-02-next-step", to: self)
        try await siri.previousStep()
        XCTAssertTrue(
            stepMeta(journey, "Step 1 of 3").waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Previous step did not move cook mode back to step 1. Screen: \(journey.screen)"
        )
        try await siri.readStep()
        XCTAssertFalse(
            stepMeta(journey, "Step 2 of 3").waitForExistence(timeout: 2),
            "Read the step moved cook mode off step 1. Screen: \(journey.screen)"
        )
        XCTAssertTrue(stepMeta(journey, "Step 1 of 3").exists, "Read the step moved cook mode off step 1. Screen: \(journey.screen)")

        // "Start the step timer in Spoonjoy" on the timed step starts its timer.
        try await siri.startStepTimer()
        XCTAssertTrue(
            journey.element(JourneyID.cookTimerRunning).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Start the step timer did not start step 1's timer. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "siri-03-step-timer", to: self)

        try await siri.nextStep()
        XCTAssertTrue(
            stepMeta(journey, "Step 2 of 3").waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The second Next step did not move cook mode to step 2. Screen: \(journey.screen)"
        )

        // "Add to my Spoonjoy shopping list" → "What should I add?" → the cook names it. It reaches QA's list.
        try await siri.addShoppingItem(named: eggs, quantity: 6)
        let list = try await qa.shoppingList(waitingForItemNamed: eggs)
        XCTAssertTrue(
            list.receiptItems.contains { $0.name.localizedCaseInsensitiveContains(eggs) },
            "Add Shopping Item did not put \(eggs) on QA's shopping list."
        )

        // Live: Siri's step reaches QA's cook session, so the relaunch below reads it back rather than racing the sync.
        let synced = try await qa.cookSession(recipeID: recipeID, waitingForStep: 1)
        XCTAssertEqual(synced.activeStepIndex, 1, "QA's cook session is not on step 2 after Siri moved it there.")

        // After a relaunch, cook mode reopens where Siri left it, and the list still holds the item.
        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        verifyAfterRelaunch(journey) {
            journey.openLink(cookLink)
            XCTAssertTrue(
                stepMeta(journey, "Step 2 of 3").waitForExistence(timeout: JourneyApp.networkTimeout),
                "Cook mode did not reopen at the step Siri moved it to. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "siri-04-after-relaunch", to: self)
        }
        let afterRelaunch = try await qa.cookSession(recipeID: recipeID)
        XCTAssertGreaterThanOrEqual(afterRelaunch.revision, synced.revision, "A relaunch moved QA's cook session backwards.")
        let listAfterRelaunch = try await qa.shoppingList()
        XCTAssertTrue(
            listAfterRelaunch.receiptItems.contains { $0.name.localizedCaseInsensitiveContains(eggs) },
            "\(eggs) left QA's shopping list after a relaunch."
        )
    }

    private func stepMeta(_ journey: JourneyApp, _ text: String) -> XCUIElement {
        journey.element(JourneyID.cookStepMeta, labelContaining: text)
    }
}
