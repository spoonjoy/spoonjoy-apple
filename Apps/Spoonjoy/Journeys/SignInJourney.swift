import SpoonjoyCore
import XCTest

/// Live journey: QA rejects a wrong password, signs the cook in by username and by email, ends the session on sign-out,
/// and keeps the cook's blocked chefs on the server, so a fresh sign-in lists them again. Sign-in state handling and
/// the moderation ledger are proved headless in SpoonjoyReinsTests; this journey keeps what needs QA, plus the
/// Settings paper under the status bar.
@MainActor
final class SignInJourney: JourneyTestCase {
    func testSignInOutJourney() async throws {
        let account = try JourneyAccounts.account(1)
        let chef = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let chefQA = try await JourneyQAClient.signIn(chef)
        let chefRecipeID = try await chefQA.createRecipe(
            title: "Journey \(token) Blocked chef J1",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Step 1",
                    description: "Cook it.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "journeyflour")],
                    outputStepNums: []
                )
            ]
        )
        let chefRecipeLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(chefRecipeID)"))
        let journey = JourneyApp.launchFresh()

        // Live: QA rejects a wrong password.
        journey.signIn(as: account.username, password: JourneyQA.rejectedPassword)
        XCTAssertTrue(
            journey.element(JourneyID.signInStatus, labelContaining: JourneyCopy.wrongPasswordStatus)
                .waitForExistence(timeout: JourneyApp.networkTimeout),
            "A wrong password did not show the sign-in error."
        )
        XCTAssertFalse(journey.element(JourneyID.kitchenRoot).exists)

        // Live: sign-in by username.
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in by username did not open the kitchen."
        )

        // Live: blocking the chef reaches QA (checked after the fresh sign-in below).
        journey.openLink(chefRecipeLink)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.networkTimeout),
            "\(chefRecipeLink) did not open the recipe. Screen: \(journey.screen)"
        )
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.moderationBlock)
        journey.tap(JourneyID.moderationBlockConfirm)
        XCTAssertTrue(
            journey.element(JourneyID.moderationBlockConfirm).waitForNonExistence(timeout: JourneyApp.networkTimeout),
            "The block confirmation did not close. Screen: \(journey.screen)"
        )

        // Live: QA itself holds the block, read as the viewer. The Blocked chefs check below could pass from the
        // device's own ledger, which survives sign-out, so this is the proof the server has it.
        let viewerQA = try await JourneyQAClient.signIn(account)
        let blocked = try await viewerQA.blockedChefUsernames(waitingFor: chef.username)
        XCTAssertTrue(blocked.contains(chef.username), "QA does not list @\(chef.username) among the viewer's blocks.")

        // Guard: the build talks to the QA mirror.
        journey.openTab(JourneyCopy.kitchenTab)
        journey.openSettings()
        journey.assertQAEnvironment()
        // UI: a swiped page slides under the status bar and the back button; its paper must cover them cleanly.
        journey.app.swipeUp()
        journey.attachScreenshot(named: "00-settings-swiped", to: self)

        // Live: sign-out ends the session.
        journey.signOut()
        journey.closeSettings()
        XCTAssertTrue(
            journey.element(JourneyID.passwordSignIn).waitForExistence(timeout: JourneyApp.launchTimeout),
            "Signing out did not return to the sign-in screen."
        )
        verifyAfterRelaunch(journey) {
            XCTAssertTrue(
                journey.element(JourneyID.passwordSignIn).waitForExistence(timeout: JourneyApp.launchTimeout),
                "The app was signed in again after a relaunch."
            )
            XCTAssertFalse(journey.element(JourneyID.kitchenRoot).exists)
        }

        // Live: sign-in by email.
        journey.signIn(as: account.email, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in by email did not open the kitchen."
        )

        // After the fresh sign-in, Blocked chefs lists the chef (QA's copy is checked above).
        journey.openSettings()
        journey.tap(JourneyID.settingsBlockedChefs)
        XCTAssertTrue(
            journey.element(JourneyID.blockedChefsRow, descendantLabelContaining: chef.username)
                .waitForExistence(timeout: JourneyApp.networkTimeout),
            "Blocked chefs does not list @\(chef.username). Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "01-blocked-chefs", to: self)
    }
}
