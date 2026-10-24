import SpoonjoyCore
import XCTest

/// Journey 6: cook mode on a foldable stood half-open on the counter, like a small laptop. The step sits on the half
/// above the fold, facing the cook, and the ingredient checklist sits on the half below it, flat on the counter;
/// nothing sits on the fold. The Journeys job's simulator hinge cannot stand half-open, so the app is launched reporting
/// a half-open hinge (`-SpoonjoyForcePosture tabletop`); the split itself is the shipping layout. The Duo tour workflow
/// runs this journey on an iPhone Duo stood half-open, where the app reads the real hinge. Next turns the step from
/// below the fold, and the app reopens in cook mode on that step after a relaunch.
@MainActor
final class TabletopJourney: JourneyTestCase {
    func testTabletopCookModeSplitsAtTheFoldJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Tabletop J6"
        let flour = "Journey\(token)flour"
        let jam = "Journey\(token)jam"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Make the dough",
                    description: "Rub the butter into the flour until it looks like breadcrumbs.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 2, unit: "cup", name: flour)],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 2,
                    stepTitle: "Fill the tart",
                    description: "Spread the jam over the pastry.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: jam)],
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

        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        // The Duo tour workflow reads this line to open the same cook mode when it photographs each pose.
        print("Duo tour cook link: \(cookLink.absoluteString)")
        journey.useTabletopPostureOnNextLaunch()
        // The link opens cook mode in both shells: the tab bar, and the sidebar a wide screen such as the Duo's inner
        // screen gets.
        journey.openLink(cookLink)

        let stepHalf = journey.element(JourneyID.cookTabletopStep)
        let controlsHalf = journey.element(JourneyID.cookTabletopControls)
        XCTAssertTrue(
            stepHalf.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode on a half-open hinge did not put the step above the fold. Screen: \(journey.screen)"
        )
        XCTAssertTrue(controlsHalf.exists, "Cook mode on a half-open hinge has no controls half. Screen: \(journey.screen)")
        XCTAssertGreaterThanOrEqual(
            controlsHalf.frame.minY - stepHalf.frame.maxY,
            TabletopLayout.foldMargin * 2 - 0.5,
            "The step and the controls are closer to the fold than its margin."
        )
        // XCUITest reports each half as the union of its contents, not the row it fills, so check where the halves sit in
        // the window: neither may be pushed against the far edge. For the same reason, "below the fold" below compares
        // against the bottom of the step half, never the controls half that contains the element.
        let window = journey.app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(
            stepHalf.frame.maxY,
            window.maxY - TabletopLayout.minimumHalfHeight,
            "The step half runs too far down."
        )
        XCTAssertGreaterThanOrEqual(
            controlsHalf.frame.minY,
            window.minY + TabletopLayout.minimumHalfHeight,
            "The controls half starts too high."
        )
        XCTAssertLessThanOrEqual(
            controlsHalf.frame.minY,
            window.maxY - TabletopLayout.minimumHalfHeight,
            "The controls half starts too low."
        )

        let ingredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: flour)
        XCTAssertTrue(
            ingredient.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Tabletop cook mode does not list the flour. Screen: \(journey.screen)"
        )
        XCTAssertGreaterThanOrEqual(ingredient.frame.minY, stepHalf.frame.maxY, "The checklist is not below the fold.")
        journey.attachScreenshot(named: "00-tabletop-cook-mode", to: self)

        ingredient.tap()
        // The checkbox reads "1" as a switch and "checked" as a button, depending on how the platform exposes it.
        XCTAssertTrue(
            ["1", "checked"].contains(ingredient.value as? String ?? ""),
            "Tapping the flour did not check it in tabletop cook mode. Value: \(String(describing: ingredient.value))"
        )
        journey.attachScreenshot(named: "01-tabletop-flour-checked", to: self)

        // Next, below the fold, turns to the second step; cook mode stays split.
        let next = journey.element(JourneyID.cookDockNext)
        XCTAssertGreaterThanOrEqual(next.frame.minY, stepHalf.frame.maxY, "Next step is not below the fold.")
        next.tap()
        let jamIngredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: jam)
        XCTAssertTrue(
            jamIngredient.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Next step did not turn to the second step in tabletop cook mode. Screen: \(journey.screen)"
        )
        XCTAssertTrue(stepHalf.exists, "Turning the step undid the split. Screen: \(journey.screen)")
        XCTAssertGreaterThanOrEqual(jamIngredient.frame.minY, stepHalf.frame.maxY, "The second step's checklist is not below the fold.")
        journey.attachScreenshot(named: "02-tabletop-second-step", to: self)

        // The relaunch keeps the forced posture and this device's cook progress, and the app reopens where it was
        // left: cook mode, split again, on the second step, with no taps.
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
            let jamAfterRelaunch = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: jam)
            XCTAssertTrue(
                jamAfterRelaunch.waitForExistence(timeout: JourneyApp.networkTimeout),
                "The app did not reopen in cook mode on the second step after a relaunch. Screen: \(journey.screen)"
            )
            XCTAssertTrue(stepHalf.exists, "Cook mode was not split at the fold after a relaunch. Screen: \(journey.screen)")
        }
        journey.attachScreenshot(named: "03-tabletop-after-relaunch", to: self)
    }
}
