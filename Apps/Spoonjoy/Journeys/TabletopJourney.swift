import SpoonjoyCore
import XCTest

/// Journey 6: cook mode on a foldable stood half-open on the counter, like a small laptop. The step sits on the half
/// above the fold, facing the cook, and the ingredient checklist sits on the half below it, flat on the counter;
/// nothing sits on the fold. The Journeys job's simulator hinge cannot stand half-open, so the app is launched reporting
/// a half-open hinge (`-SpoonjoyForcePosture tabletop`); the split itself is the shipping layout. The Duo tour workflow
/// runs this journey on an iPhone Duo stood half-open, where the app reads the real hinge. Checking the step's flour
/// starts its timer, a swipe on the step half turns the step, and the step survives a relaunch.
///
/// `testTimerRunsOnForTheDuoTourJourney` leaves a timer running for the Duo tour, which then folds the phone through
/// every posture and fails if the timer's end date moves.
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
                    duration: 5,
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
        // The flour is the step's only ingredient, so checking it starts the step's timer, above the fold with the step.
        let running = journey.element(JourneyID.cookTimerRunning)
        XCTAssertTrue(
            running.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Checking the flour did not start the step's timer. Screen: \(journey.screen)"
        )
        XCTAssertLessThanOrEqual(running.frame.maxY, controlsHalf.frame.minY, "The running timer is not above the fold.")
        journey.attachScreenshot(named: "01-tabletop-flour-checked-timer-running", to: self)
        journey.tap(JourneyID.cookTimerCancel)
        XCTAssertTrue(
            running.waitForNonExistence(timeout: JourneyApp.interactionTimeout),
            "Cancelling the timer did not stop it. Screen: \(journey.screen)"
        )

        // A swipe on the step half turns to the second step; cook mode stays split.
        stepHalf.swipeLeft()
        let jamIngredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: jam)
        XCTAssertTrue(
            jamIngredient.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "A swipe did not turn to the second step in tabletop cook mode. Screen: \(journey.screen)"
        )
        XCTAssertTrue(stepHalf.exists, "Turning the step undid the split. Screen: \(journey.screen)")
        XCTAssertGreaterThanOrEqual(jamIngredient.frame.minY, stepHalf.frame.maxY, "The second step's checklist is not below the fold.")
        journey.attachScreenshot(named: "02-tabletop-second-step", to: self)

        // The relaunch keeps the forced posture and this device's cook progress: cook mode opens split again, on the
        // second step it was left on.
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        // The link opens cook mode in both shells: the tab bar, and the sidebar a wide screen such as the Duo's inner
        // screen gets.
        journey.openLink(cookLink)
        let jamAfterRelaunch = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: jam)
        XCTAssertTrue(
            jamAfterRelaunch.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode did not reopen on the second step after a relaunch. Screen: \(journey.screen)"
        )
        XCTAssertTrue(stepHalf.exists, "Cook mode was not split at the fold after a relaunch. Screen: \(journey.screen)")
        journey.attachScreenshot(named: "03-tabletop-after-relaunch", to: self)
    }

    /// The CI simulator refuses system timers without asking. With the stand-in alarm off, checking a timed step's only
    /// ingredient must not pretend a timer is running: the ring says why it could not set one.
    func testAutoStartFailureShowsOnTheRingJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let flour = "Journey\(token)flour"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: "Journey \(token) Refused timer J6",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Rest the dough",
                    description: "Cover the dough and leave it to rest.",
                    duration: 5,
                    ingredients: [RecipeIngredientDraft(quantity: 2, unit: "cup", name: flour)],
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
        journey.useSystemAlarmsOnNextLaunch()
        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        journey.openLink(cookLink)

        let ingredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: flour)
        XCTAssertTrue(
            ingredient.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode does not list the flour. Screen: \(journey.screen)"
        )
        ingredient.tap()
        // A simulator that asks rather than refuses is answered no, so the journey sees the refusal either way.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let refuse = springboard.alerts.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Don")).firstMatch
        if refuse.waitForExistence(timeout: 3) {
            refuse.tap()
        }
        let error = journey.element(JourneyID.cookTimerError)
        XCTAssertTrue(
            error.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Checking the flour with timers refused did not say why no timer started. Screen: \(journey.screen)"
        )
        XCTAssertFalse(journey.element(JourneyID.cookTimerRunning).exists, "A refused timer still shows as running.")
        XCTAssertTrue(
            ["1", "checked"].contains(ingredient.value as? String ?? ""),
            "A refused timer undid the flour's check. Value: \(String(describing: ingredient.value))"
        )
        journey.attachScreenshot(named: "04-refused-timer-on-the-ring", to: self)

        // After a relaunch the check is kept and still no timer pretends to run.
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        journey.openLink(cookLink)
        let ingredientAfterRelaunch = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: flour)
        XCTAssertTrue(
            ingredientAfterRelaunch.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode did not reopen on the flour after a relaunch. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            ["1", "checked"].contains(ingredientAfterRelaunch.value as? String ?? ""),
            "The flour's check was lost on relaunch. Value: \(String(describing: ingredientAfterRelaunch.value))"
        )
        XCTAssertFalse(journey.element(JourneyID.cookTimerRunning).exists, "A refused timer shows as running after a relaunch.")
    }

    /// A timer started with the phone open keeps its end time when the phone is folded shut, where the cover shows the
    /// kitchen-timer glance, and when it is stood half-open, where cook mode splits at the fold. The Journeys job's
    /// simulator cannot fold, so each pose is a relaunch with a forced posture; the Duo tour photographs the real folds.
    func testFoldingMidTimerKeepsTheTimerJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let butter = "Journey\(token)butter"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: "Journey \(token) Fold J6",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Brown the butter",
                    description: "Melt the butter and cook it until it smells of hazelnuts.",
                    duration: 30,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: butter)],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 2,
                    stepTitle: "Cool the butter",
                    description: "Pour the butter into a bowl to cool.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "Journey\(token)ice")],
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
        journey.openLink(cookLink)
        let ingredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: butter)
        XCTAssertTrue(
            ingredient.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode does not list the butter. Screen: \(journey.screen)"
        )
        ingredient.tap()
        let running = journey.element(JourneyID.cookTimerRunning)
        XCTAssertTrue(
            running.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Checking the butter did not start the step's timer. Screen: \(journey.screen)"
        )
        let endsAt = try XCTUnwrap(Self.endTime(of: running), "The running timer's label has no time left: \(running.label)")
        journey.attachScreenshot(named: "10-fold-timer-started", to: self)

        // The cover is narrow, so it is checked at the largest text size: its controls must sit whole on screen.
        journey.useLargestAccessibilityTextOnNextLaunch()
        journey.useClosedPostureOnNextLaunch()
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        journey.openLink(cookLink)
        let glance = journey.element(JourneyID.cookCoverGlance)
        XCTAssertTrue(
            glance.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Folded shut mid-cook, cook mode did not show the cover glance. Screen: \(journey.screen)"
        )
        try assertSameEnd(endsAt, running, "the cover glance")
        let window = journey.app.windows.firstMatch.frame
        let glanceNext = journey.element(JourneyID.cookCoverGlanceNext)
        let glanceShowStep = journey.element(JourneyID.cookCoverGlanceShowStep)
        XCTAssertTrue(glanceNext.isHittable, "The cover glance's Next can't be tapped. Screen: \(journey.screen)")
        XCTAssertTrue(glanceShowStep.isHittable, "The cover glance's Show step can't be tapped. Screen: \(journey.screen)")
        XCTAssertTrue(window.contains(glanceNext.frame), "The cover glance's Next runs off the screen at the largest text size: \(glanceNext.frame) in \(window)")
        XCTAssertTrue(window.contains(glanceShowStep.frame), "The cover glance's Show step runs off the screen at the largest text size: \(glanceShowStep.frame) in \(window)")
        XCTAssertFalse(glanceNext.frame.intersects(glanceShowStep.frame), "The cover glance's Next and Show step overlap at the largest text size.")
        XCTAssertGreaterThanOrEqual(glanceNext.frame.height, 44, "The cover glance's Next is not thumb-sized.")
        let glanceTitle = journey.element(JourneyID.cookCoverGlanceTitle)
        XCTAssertTrue(glanceTitle.exists, "The cover glance has no step title. Screen: \(journey.screen)")
        XCTAssertGreaterThanOrEqual(glanceTitle.frame.minX, window.minX, "The cover glance's title runs off the left edge.")
        XCTAssertLessThanOrEqual(glanceTitle.frame.maxX, window.maxX, "The cover glance's title runs off the right edge.")
        XCTAssertLessThanOrEqual(glanceTitle.frame.maxY, running.frame.minY, "The cover glance's ring is not under its title.")
        journey.attachScreenshot(named: "11-fold-closed-cover-glance-largest-text", to: self)

        journey.useTabletopPostureOnNextLaunch()
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        journey.openLink(cookLink)
        XCTAssertTrue(
            journey.element(JourneyID.cookTabletopStep).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Stood half-open mid-cook, cook mode did not split at the fold. Screen: \(journey.screen)"
        )
        XCTAssertFalse(glance.exists, "The cover glance stayed after the phone was opened. Screen: \(journey.screen)")
        try assertSameEnd(endsAt, running, "tabletop cook mode")
        // Still at the largest text size: the dock would cut its labels short, so the controls stack whole on the half
        // below the fold, inside the screen, one clear of the next.
        let stepHalf = journey.element(JourneyID.cookTabletopStep)
        let next = journey.element(JourneyID.cookTabletopNext)
        let markDone = journey.element(JourneyID.cookTabletopMarkDone)
        let back = journey.element(JourneyID.cookTabletopBack)
        XCTAssertTrue(next.isHittable, "Tabletop Next can't be tapped at the largest text size. Screen: \(journey.screen)")
        XCTAssertTrue(markDone.isHittable, "Tabletop Mark done can't be tapped at the largest text size. Screen: \(journey.screen)")
        XCTAssertTrue(back.exists, "Tabletop has no Back step at the largest text size. Screen: \(journey.screen)")
        XCTAssertFalse(journey.element(JourneyID.cookDockNext).exists, "Tabletop still shows the dock at the largest text size.")
        XCTAssertGreaterThanOrEqual(next.frame.minY, stepHalf.frame.maxY, "Tabletop Next is not below the fold.")
        XCTAssertTrue(window.contains(next.frame), "Tabletop Next runs off the screen: \(next.frame) in \(window)")
        XCTAssertTrue(window.contains(markDone.frame), "Tabletop Mark done runs off the screen: \(markDone.frame) in \(window)")
        XCTAssertLessThanOrEqual(next.frame.maxY, markDone.frame.minY, "Tabletop Next and Mark done overlap.")
        XCTAssertLessThanOrEqual(markDone.frame.maxY, back.frame.minY, "Tabletop Mark done and Back step overlap.")
        XCTAssertGreaterThanOrEqual(next.frame.height, 44, "Tabletop Next is not thumb-sized.")
        journey.attachScreenshot(named: "12-fold-tabletop-largest-text", to: self)
        journey.tap(JourneyID.cookTimerCancel)
        XCTAssertTrue(
            running.waitForNonExistence(timeout: JourneyApp.interactionTimeout),
            "Cancelling the timer did not stop it. Screen: \(journey.screen)"
        )
    }

    /// Starts a timer for the Duo tour and leaves it running. The tour opens this cook mode, folds the phone through
    /// tabletop, open flat and shut without relaunching, and compares the end date the app logs at each posture. Here,
    /// on any simulator, the timer survives a relaunch with its end time.
    func testTimerRunsOnForTheDuoTourJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let stock = "Journey\(token)stock"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: "Journey \(token) Duo tour J6",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Simmer the stock",
                    description: "Bring the stock to a simmer and let it reduce by a third.",
                    duration: 45,
                    ingredients: [RecipeIngredientDraft(quantity: 4, unit: "cup", name: stock)],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 2,
                    stepTitle: "Season",
                    description: "Taste the stock and season it with salt.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "tsp", name: "Journey\(token)salt")],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 3,
                    stepTitle: "Strain",
                    description: "Strain the stock through a fine sieve.",
                    duration: nil,
                    ingredients: [],
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
        // The Duo tour workflow reads this line to open the same cook mode, timer running, in each pose.
        print("Duo tour cook link: \(cookLink.absoluteString)")
        journey.openLink(cookLink)
        let ingredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: stock)
        XCTAssertTrue(
            ingredient.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode does not list the stock. Screen: \(journey.screen)"
        )
        ingredient.tap()
        let running = journey.element(JourneyID.cookTimerRunning)
        XCTAssertTrue(
            running.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Checking the stock did not start the step's timer. Screen: \(journey.screen)"
        )
        let endsAt = try XCTUnwrap(Self.endTime(of: running), "The running timer's label has no time left: \(running.label)")
        journey.attachScreenshot(named: "20-duo-tour-timer-started", to: self)

        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        journey.openLink(cookLink)
        try assertSameEnd(endsAt, running, "cook mode after a relaunch")
    }
}

extension TabletopJourney {
    /// The end time a running timer implies: now plus the time its digits show, read as "m:ss" or "h:mm:ss", or as
    /// VoiceOver's "4 minutes, 59 seconds".
    fileprivate static func endTime(of running: XCUIElement) -> Date? {
        let label = running.label.lowercased()
        let seconds: Int
        if let clock = label.firstMatch(of: /(?:(\d+):)?(\d+):(\d{2})/) {
            seconds = (Int(clock.1 ?? "0") ?? 0) * 3600 + (Int(clock.2) ?? 0) * 60 + (Int(clock.3) ?? 0)
        } else {
            let hours = label.firstMatch(of: /(\d+) hour/).flatMap { Int($0.1) } ?? 0
            let minutes = label.firstMatch(of: /(\d+) minute/).flatMap { Int($0.1) } ?? 0
            let secs = label.firstMatch(of: /(\d+) second/).flatMap { Int($0.1) } ?? 0
            guard hours + minutes + secs > 0 else { return nil }
            seconds = hours * 3600 + minutes * 60 + secs
        }
        return Date().addingTimeInterval(TimeInterval(seconds))
    }

    fileprivate func assertSameEnd(_ endsAt: Date, _ running: XCUIElement, _ pose: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(running.waitForExistence(timeout: JourneyApp.interactionTimeout), "The timer is gone in \(pose).", file: file, line: line)
        let now = try XCTUnwrap(Self.endTime(of: running), "The timer in \(pose) shows no time left: \(running.label)", file: file, line: line)
        XCTAssertEqual(now.timeIntervalSince1970, endsAt.timeIntervalSince1970, accuracy: 2, "The timer's end moved in \(pose).", file: file, line: line)
    }
}
