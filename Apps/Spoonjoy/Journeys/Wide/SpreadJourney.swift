import SpoonjoyCore
import XCTest

/// Journey 7: cook mode laid open flat and wide as a two-page spread, which only a screen at least
/// `BookSpreadLayout.minimumSpreadWidth` wide shows: the iPhone Duo's inner screen held wide, or an iPad in landscape.
/// The Journeys job's iPhone is too narrow, so this sits in its own target, SpoonjoyWideJourneys, which the Duo tour
/// runs on an iPhone Duo open flat and wide. The fold lies at the middle of the screen on both.
@MainActor
final class SpreadJourney: JourneyTestCase {
    /// At the largest text size the controls stack rather than push a page past the screen's edge or into the gutter:
    /// Back and Close stay on the left page, Mark done, Next and Finish cooking on the right.
    func testSpreadControlsStayOnTheirPagesAtTheLargestTextJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let recipeID = try await createTwoStepRecipe(token: token, title: "Journey \(token) Spread text J7")
        let journey = JourneyApp.launchFresh()
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )
        journey.useLargestAccessibilityTextOnNextLaunch()
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        journey.openLink(cookLink)

        let stepPage = journey.element(JourneyID.cookSpreadStepPage)
        XCTAssertTrue(
            stepPage.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode did not open as a spread on a wide screen. Screen: \(journey.screen)"
        )
        let window = journey.app.windows.firstMatch.frame
        let gatherPage = journey.element(JourneyID.cookSpreadGatherPage)
        XCTAssertGreaterThanOrEqual(gatherPage.frame.minX, window.minX, "The left page runs off the screen: \(gatherPage.frame) in \(window)")
        XCTAssertLessThanOrEqual(gatherPage.frame.maxX, window.midX, "The left page runs into the gutter: \(gatherPage.frame) in \(window)")
        XCTAssertGreaterThanOrEqual(stepPage.frame.minX, window.midX, "The right page runs into the gutter: \(stepPage.frame) in \(window)")
        XCTAssertLessThanOrEqual(stepPage.frame.maxX, window.maxX, "The right page runs off the screen: \(stepPage.frame) in \(window)")
        assertOnLeftPage(journey.element(JourneyID.cookSpreadBack), "Back step", window: window)
        assertOnLeftPage(journey.element(JourneyID.cookSpreadClose), "Close", window: window)
        assertOnRightPage(journey.element(JourneyID.cookSpreadMarkDone), "Mark done", window: window)
        assertOnRightPage(journey.element(JourneyID.cookSpreadNext), "Next step", window: window)
        journey.attachScreenshot(named: "30-spread-largest-text", to: self)

        // The last step: Finish cooking is the right page's filled button, and it too stays on that page.
        journey.tap(JourneyID.cookSpreadNext)
        let finish = journey.element(JourneyID.cookFinish)
        XCTAssertTrue(
            finish.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Next did not turn to the last step's Finish cooking. Screen: \(journey.screen)"
        )
        assertOnRightPage(finish, "Finish cooking", window: window)
        assertOnRightPage(journey.element(JourneyID.cookSpreadMarkDone), "Mark done on the last step", window: window)
        XCTAssertFalse(journey.element(JourneyID.cookSpreadNext).exists, "The last step still shows Next beside Finish cooking.")
        journey.attachScreenshot(named: "31-spread-largest-text-last-step", to: self)
    }

    /// With Reduce Motion on, a swipe on the right page still turns the step; the page crossfades instead of curling.
    func testSpreadTurnsUnderReduceMotionJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let recipeID = try await createTwoStepRecipe(token: token, title: "Journey \(token) Spread motion J7")
        let journey = JourneyApp.launchFresh()
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )
        journey.useReduceMotionOnNextLaunch()
        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        journey.openLink(cookLink)

        let stepPage = journey.element(JourneyID.cookSpreadStepPage)
        XCTAssertTrue(
            stepPage.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode did not open as a spread on a wide screen. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.cookSpreadStepPage, descendantLabelContaining: "Whisk the eggs").exists,
            "The spread did not open on the first step. Screen: \(journey.screen)"
        )
        stepPage.swipeLeft()
        let secondStep = journey.element(JourneyID.cookSpreadStepPage, descendantLabelContaining: "Fold in the flour")
        XCTAssertTrue(
            secondStep.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "A swipe under Reduce Motion did not turn the spread to the second step. Screen: \(journey.screen)"
        )
        XCTAssertFalse(
            journey.element(JourneyID.cookSpreadStepPage, descendantLabelContaining: "Whisk the eggs").exists,
            "The first step is still on the right page after the turn."
        )
        journey.attachScreenshot(named: "32-spread-reduce-motion-turned", to: self)

        // The turned step is this device's cook progress, so it survives a relaunch.
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        journey.openLink(cookLink)
        XCTAssertTrue(
            journey.element(JourneyID.cookSpreadStepPage, descendantLabelContaining: "Fold in the flour")
                .waitForExistence(timeout: JourneyApp.networkTimeout),
            "The spread did not reopen on the second step after a relaunch. Screen: \(journey.screen)"
        )
    }

    private func createTwoStepRecipe(token: String, title: String) async throws -> String {
        let qa = try await JourneyQAClient.signIn(try JourneyAccounts.account(4))
        return try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Whisk the eggs",
                    description: "Whisk the eggs and sugar until pale and thick enough to hold a ribbon.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 3, unit: nil, name: "Journey\(token)eggs")],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 2,
                    stepTitle: "Fold in the flour",
                    description: "Sift the flour over the eggs and fold it in with a large spoon.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "Journey\(token)flour")],
                    outputStepNums: []
                )
            ]
        )
    }

    /// Whole, on screen, and on the left of the gutter, with the pages' inner margin to spare.
    private func assertOnLeftPage(_ control: XCUIElement, _ name: String, window: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.exists, "The spread has no \(name).", file: file, line: line)
        XCTAssertGreaterThanOrEqual(control.frame.minX, window.minX, "\(name) runs off the left edge: \(control.frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(control.frame.maxX, window.midX - Self.gutterClearance, "\(name) crosses into the gutter: \(control.frame) in \(window)", file: file, line: line)
        XCTAssertLessThanOrEqual(control.frame.maxY, window.maxY, "\(name) runs off the bottom: \(control.frame)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(control.frame.height, 44, "\(name) is not thumb-sized.", file: file, line: line)
    }

    private func assertOnRightPage(_ control: XCUIElement, _ name: String, window: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.exists, "The spread has no \(name).", file: file, line: line)
        XCTAssertGreaterThanOrEqual(control.frame.minX, window.midX + Self.gutterClearance, "\(name) crosses into the gutter: \(control.frame) in \(window)", file: file, line: line)
        XCTAssertLessThanOrEqual(control.frame.maxX, window.maxX, "\(name) runs off the right edge: \(control.frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(control.frame.maxY, window.maxY, "\(name) runs off the bottom: \(control.frame)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(control.frame.height, 44, "\(name) is not thumb-sized.", file: file, line: line)
    }

    /// Half the narrowest gutter plus a little: a control this far from the middle is clear of the fold.
    private static let gutterClearance: CGFloat = 16
}
