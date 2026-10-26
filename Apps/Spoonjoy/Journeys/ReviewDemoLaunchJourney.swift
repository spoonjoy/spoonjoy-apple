import XCTest

/// App Review rejected 1.0 because "the app crashed after the initial launch". The reviewer signs in with the
/// review demo account, whose seeded kitchen (distribution/app-store/review-demo-kitchen.json) is unlike any QA
/// account. This signs the App Store configuration in as that account on production, relaunches, and opens every
/// seeded recipe and cookbook without changing anything.
///
/// Only the Review demo launch workflow runs it: it skips unless `SPOONJOY_REVIEW_DEMO_LAUNCH_FILE` names the
/// runner-local file that workflow writes.
@MainActor
final class ReviewDemoLaunchJourney: JourneyTestCase {
    private struct Kitchen: Decodable {
        let username: String
        let password: String
        let recipes: [String]
        let cookbooks: [String]
    }

    private static let fileVariable = "SPOONJOY_REVIEW_DEMO_LAUNCH_FILE"

    func testReviewDemoKitchenSurvivesSignInAndRelaunch() throws {
        guard let path = ProcessInfo.processInfo.environment[Self.fileVariable], !path.isEmpty else {
            throw XCTSkip("\(Self.fileVariable) is not set; only the Review demo launch workflow runs this journey.")
        }
        let kitchen = try JSONDecoder().decode(Kitchen.self, from: Data(contentsOf: URL(fileURLWithPath: path)))

        let journey = JourneyApp.launchAsShipped()
        journey.attachScreenshot(named: "00-signed-out", to: self)
        journey.signIn(as: kitchen.username, password: kitchen.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in as the review demo account did not open the kitchen. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "01-kitchen-after-sign-in", to: self)

        verifyAfterRelaunch(journey) {
            XCTAssertTrue(
                journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
                "The kitchen did not come back after a relaunch. Screen: \(journey.screen)"
            )
        }
        journey.attachScreenshot(named: "02-kitchen-after-relaunch", to: self)

        journey.openTab(JourneyCopy.recipesTab)
        for (index, title) in kitchen.recipes.enumerated() {
            journey.openRecipe(titled: title, from: JourneyID.recipesRow)
            journey.app.swipeUp()
            journey.attachScreenshot(named: "10-recipe-\(index)", to: self)
            journey.goBack()
        }

        journey.openTab(JourneyCopy.cookbooksTab)
        for (index, title) in kitchen.cookbooks.enumerated() {
            let shelfRow = journey.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
            XCTAssertTrue(shelfRow.waitForExistence(timeout: JourneyApp.networkTimeout), "The Cookbooks shelf does not list \(title). Screen: \(journey.screen)")
            shelfRow.tap()
            let heading = journey.app.staticTexts.matching(NSPredicate(format: "label == %@", title)).firstMatch
            XCTAssertTrue(heading.waitForExistence(timeout: JourneyApp.networkTimeout), "The \(title) cookbook did not open. Screen: \(journey.screen)")
            journey.app.swipeUp()
            journey.attachScreenshot(named: "20-cookbook-\(index)", to: self)
            journey.goBack()
        }

        journey.openTab(JourneyCopy.kitchenTab)
        verifyAfterRelaunch(journey) {
            XCTAssertTrue(
                journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
                "The kitchen did not come back after the second relaunch. Screen: \(journey.screen)"
            )
        }
        journey.attachScreenshot(named: "30-kitchen-after-second-relaunch", to: self)
    }
}
