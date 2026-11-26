import SpoonjoyCore
import XCTest

/// The app on a Spoonjoy server the cook runs: the workflow builds one from spoonjoy-v2's self-host/ folder and runs it
/// beside the simulator. The cook picks it on the sign-in screen, is told plainly when an address is not Spoonjoy,
/// switches back to the built-in server and to it again, signs in there, sees a recipe only that server holds,
/// renames it in the editor, and is still on that server, signed in, after a relaunch.
@MainActor
final class SelfHostedServerJourney: JourneyTestCase {
    func testSignInOnASelfHostedServerJourney() async throws {
        let account = try JourneyAccounts.account(1)
        let token = try JourneyAccounts.runToken()
        let address = try JourneySelfHostedServer.address()
        let server = try SpoonjoyServerAddress.parse(address)
        let original = "Self-hosted \(token) Lentil Soup"
        let renamed = "Self-hosted \(token) Lentil Soup, Smoky"
        let kitchen = try await JourneyQAClient.signIn(account, on: server.baseURL)
        let recipeID = try await kitchen.createRecipe(
            title: original,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Simmer",
                    description: "Simmer the lentils until soft.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "lentils")],
                    outputStepNums: []
                )
            ]
        )
        let journey = JourneyApp.launchFresh()

        // The one place to choose the server: the sign-in screen's Server row opens the sheet.
        journey.tap(JourneyID.signInServer)
        journey.tap(JourneyID.serverOwn)
        journey.attachScreenshot(named: "server-picker", to: self)

        // An address that answers but is not Spoonjoy is refused, in words, and nothing changes.
        journey.replaceText(in: JourneyID.serverAddress, with: try JourneySelfHostedServer.notSpoonjoyAddress())
        journey.tap(JourneyID.serverUse)
        XCTAssertTrue(
            journey.element(JourneyID.serverProblem, labelContaining: JourneyCopy.notSpoonjoyServer)
                .waitForExistence(timeout: JourneyApp.networkTimeout),
            "The server sheet did not say the address isn't a Spoonjoy server. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "server-picker-not-spoonjoy", to: self)

        // The self-hosted server checks out; the sign-in screen comes back naming it.
        journey.replaceText(in: JourneyID.serverAddress, with: address)
        journey.tap(JourneyID.serverUse)
        XCTAssertTrue(
            journey.element(JourneyID.signInServer, labelContaining: server.displayName)
                .waitForExistence(timeout: JourneyApp.networkTimeout),
            "The sign-in screen does not name \(server.displayName) after choosing it. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "server-picker-chosen", to: self)

        // Switching back to the built-in server drops the self-hosted one; choosing it again brings it back.
        journey.tap(JourneyID.signInServer)
        journey.tap(JourneyID.serverBuiltIn)
        journey.tap(JourneyID.serverUse)
        XCTAssertTrue(
            journey.element(JourneyID.signInServer, labelContaining: server.displayName)
                .waitForNonExistence(timeout: JourneyApp.networkTimeout),
            "The sign-in screen still names \(server.displayName) after switching back. Screen: \(journey.screen)"
        )
        journey.tap(JourneyID.signInServer)
        journey.tap(JourneyID.serverOwn)
        journey.replaceText(in: JourneyID.serverAddress, with: address)
        journey.tap(JourneyID.serverUse)
        XCTAssertTrue(
            journey.element(JourneyID.signInServer, labelContaining: server.displayName)
                .waitForExistence(timeout: JourneyApp.networkTimeout),
            "The sign-in screen does not name \(server.displayName) after choosing it again. Screen: \(journey.screen)"
        )

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in on \(server.displayName) did not open the kitchen. Screen: \(journey.screen)"
        )

        // The recipe exists only on the self-hosted server, so seeing it proves the app reads from there.
        journey.openTab(JourneyCopy.recipesTab)
        journey.openRecipe(titled: original, from: JourneyID.recipesRow)
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailEdit)
        journey.assertFieldValue(JourneyID.editorTitle, equals: original)
        journey.replaceText(in: JourneyID.editorTitle, with: renamed)
        journey.saveOpenRecipeEditor()

        // And the edit reaches the self-hosted server.
        let saved = try await kitchen.recipeTitle(recipeID, waitingFor: renamed)
        XCTAssertEqual(saved, renamed, "\(server.displayName) does not hold the title saved in the app.")
        journey.attachScreenshot(named: "self-hosted-recipe-renamed", to: self)

        // After a relaunch the app is still on the self-hosted server, signed in, and lists the renamed recipe.
        verifyAfterRelaunch(journey) {
            XCTAssertTrue(
                journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
                "After a relaunch the app is not signed in on \(server.displayName). Screen: \(journey.screen)"
            )
            journey.openTab(JourneyCopy.recipesTab)
            journey.openRecipe(titled: renamed, from: JourneyID.recipesRow)
            journey.attachScreenshot(named: "self-hosted-after-relaunch", to: self)
        }
    }
}
