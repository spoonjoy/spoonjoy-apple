import SpoonjoyCore
import XCTest

/// Journey 7: someone reports another chef's recipe and blocks another chef (App Review guideline 1.2). The
/// reported recipe and the blocked chef's recipe stay hidden after a relaunch; unblocking from Settings brings the
/// chef's recipe back, and that holds after a relaunch too.
@MainActor
final class ModerationJourney: JourneyTestCase {
    func testReportBlockAndUnblock() async throws {
        let viewer = try JourneyAccounts.account(2)
        let chef = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()

        let qa = try await JourneyQAClient.signIn(chef)
        let reportedID = try await qa.createRecipe(title: "Journey \(token) Reported J7", steps: [Self.step])
        let blockedTitle = "Journey \(token) Blocked chef J7"
        let blockedID = try await qa.createRecipe(title: blockedTitle, steps: [Self.step])
        let reportedLink = URL(string: "spoonjoy://recipes/\(reportedID)")!
        let blockedLink = URL(string: "spoonjoy://recipes/\(blockedID)")!

        let journey = JourneyApp.launchFresh()
        journey.signIn(as: viewer.username, password: viewer.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        // Report: the actions menu offers Report…, the sheet takes a reason, and the thanks line names the review time.
        openRecipe(reportedLink, in: journey)
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.moderationReport)
        journey.tap(JourneyID.moderationReason("spam"))
        journey.tap(JourneyID.moderationReportSubmit)
        XCTAssertTrue(
            journey.element(JourneyID.moderationReportThanks).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Sending the report did not thank the person. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "01-report-thanks", to: self)
        journey.tap(JourneyID.moderationReportDone)
        journey.openLink(reportedLink)
        XCTAssertTrue(
            journey.element(JourneyID.moderationHidden).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The reported recipe still shows. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "02-reported-hidden", to: self)

        // Block: the actions menu offers Block <chef>, a confirmation follows, and the chef's recipe is hidden.
        openRecipe(blockedLink, in: journey)
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.moderationBlock)
        journey.tap(JourneyID.moderationBlockConfirm)
        XCTAssertTrue(
            journey.element(JourneyID.moderationBlockConfirm).waitForNonExistence(timeout: JourneyApp.networkTimeout),
            "The block confirmation did not close. Screen: \(journey.screen)"
        )
        journey.openLink(blockedLink)
        XCTAssertTrue(
            journey.element(JourneyID.moderationHidden).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The blocked chef's recipe still shows. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "03-blocked-hidden", to: self)

        verifyAfterRelaunch(journey) {
            journey.openLink(blockedLink)
            XCTAssertTrue(
                journey.element(JourneyID.moderationHidden).waitForExistence(timeout: JourneyApp.networkTimeout),
                "After a relaunch the blocked chef's recipe shows again. Screen: \(journey.screen)"
            )
            journey.openLink(reportedLink)
            XCTAssertTrue(
                journey.element(JourneyID.moderationHidden).waitForExistence(timeout: JourneyApp.networkTimeout),
                "After a relaunch the reported recipe shows again. Screen: \(journey.screen)"
            )
        }

        // Unblock: Settings lists the chef from the server, and Unblock empties the list.
        journey.openTab(JourneyCopy.kitchenTab)
        journey.openSettings()
        journey.tap(JourneyID.settingsBlockedChefs)
        XCTAssertTrue(
            journey.element(JourneyID.blockedChefsRow, descendantLabelContaining: chef.username).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Blocked chefs does not list @\(chef.username). Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "04-blocked-chefs", to: self)
        journey.tap(JourneyID.blockedChefsUnblock)
        XCTAssertTrue(
            journey.element(JourneyID.blockedChefsEmpty).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Unblocking did not empty Blocked chefs. Screen: \(journey.screen)"
        )

        verifyAfterRelaunch(journey) {
            openRecipe(blockedLink, in: journey)
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailTitle, labelContaining: blockedTitle).exists,
                "After unblocking and a relaunch, the chef's recipe is not back. Screen: \(journey.screen)"
            )
            XCTAssertFalse(journey.element(JourneyID.moderationHidden).exists, "The unblocked chef's recipe is still hidden.")
        }
        journey.attachScreenshot(named: "05-unblocked", to: self)
    }

    private static let step = RecipeStepDraft(
        stepNum: 1,
        stepTitle: "Step 1",
        description: "Cook it.",
        duration: nil,
        ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "journeyflour")],
        outputStepNums: []
    )

    private func openRecipe(_ link: URL, in journey: JourneyApp) {
        journey.openLink(link)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.networkTimeout),
            "\(link) did not open the recipe. Screen: \(journey.screen)"
        )
    }
}
