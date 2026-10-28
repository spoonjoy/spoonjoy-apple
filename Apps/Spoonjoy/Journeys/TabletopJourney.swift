import SpoonjoyCore
import XCTest

/// Journey 6: cook mode on a foldable stood half-open on the counter, like a small laptop. The step sits on the half
/// above the fold, facing the cook, and the ingredient checklist sits on the half below it, flat on the counter;
/// nothing sits on the fold. The Journeys job's simulator hinge cannot stand half-open, so the app is launched reporting
/// a half-open hinge (`-SpoonjoyForcePosture tabletop`); the split itself is the shipping layout. The Duo tour workflow
/// runs this journey on an iPhone Duo stood half-open, where the app reads the real hinge. Checking the step's flour
/// starts its timer, a swipe on the step half turns the step, and the step survives a relaunch.
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
        journey.openLink(try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook")))

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
    }

    /// The Duo tour folds and unfolds a real iPhone Duo simulator while this journey waits, so it runs only there
    /// (`SPOONJOY_JOURNEY_FOLD_TOUR=1`). Each "Duo tour fold:" line tells the workflow which pose to set next. The timer
    /// started on the counter keeps the same end time through the cover, the half-open stand and the open spread.
    func testFoldingMidTimerKeepsTheTimerJourney() async throws {
        guard ProcessInfo.processInfo.environment["SPOONJOY_JOURNEY_FOLD_TOUR"] == "1" else {
            throw XCTSkip("Only the Duo tour can fold the simulator.")
        }
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let butter = "Journey\(token)butter"
        let sugar = "Journey\(token)sugar"
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
                    stepTitle: "Whisk in the sugar",
                    description: "Take the pan off the heat and whisk in the sugar.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: sugar)],
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
        journey.openLink(try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook")))
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
        print("Duo tour fold: timer started")

        let poseTimeout: TimeInterval = 120
        let glance = journey.element(JourneyID.cookCoverGlance)
        XCTAssertTrue(
            glance.waitForExistence(timeout: poseTimeout),
            "Folding shut mid-cook did not show the cover glance. Screen: \(journey.screen)"
        )
        assertSameEnd(endsAt, running, "the cover glance")
        XCTAssertTrue(journey.element(JourneyID.cookCoverGlanceNext).exists, "The cover glance has no Next. Screen: \(journey.screen)")
        journey.attachScreenshot(named: "11-fold-closed-cover-glance", to: self)
        print("Duo tour fold: closed")

        let stepHalf = journey.element(JourneyID.cookTabletopStep)
        XCTAssertTrue(
            stepHalf.waitForExistence(timeout: poseTimeout),
            "Standing the phone half-open did not split cook mode at the fold. Screen: \(journey.screen)"
        )
        XCTAssertTrue(glance.waitForNonExistence(timeout: JourneyApp.interactionTimeout), "The cover glance stayed after opening.")
        assertSameEnd(endsAt, running, "tabletop cook mode")
        journey.attachScreenshot(named: "12-fold-tabletop", to: self)
        print("Duo tour fold: tabletop")

        let stepPage = journey.element(JourneyID.cookSpreadStepPage)
        XCTAssertTrue(
            stepPage.waitForExistence(timeout: poseTimeout),
            "Opening the phone flat did not show cook mode as a spread. Screen: \(journey.screen)"
        )
        assertSameEnd(endsAt, running, "the open spread")
        journey.attachScreenshot(named: "13-fold-open-flat-spread", to: self)
        print("Duo tour fold: open flat")

        stepPage.swipeLeft()
        XCTAssertTrue(
            journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: sugar).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "A swipe on the spread's step page did not turn to the second step. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "14-fold-spread-turned", to: self)
        print("Duo tour fold: done")
    }
}

extension TabletopJourney {
    /// The end time a running timer implies: now plus the time its digits show, read as "m:ss" or "h:mm:ss", or as
    /// VoiceOver's "4 minutes, 59 seconds".
    fileprivate static func endTime(of running: XCUIElement) -> Date? {
        let label = running.label
        let clock = label.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if clock.count >= 2, label.contains(":") {
            let seconds = clock.reduce(0) { $0 * 60 + $1 }
            return Date().addingTimeInterval(TimeInterval(seconds))
        }
        var seconds = 0
        var found = false
        let words = label.lowercased().replacingOccurrences(of: ",", with: " ").split(separator: " ")
        for (index, word) in words.enumerated() where index > 0 {
            guard let value = Int(words[index - 1]) else { continue }
            if word.hasPrefix("hour") { seconds += value * 3600; found = true }
            if word.hasPrefix("minute") { seconds += value * 60; found = true }
            if word.hasPrefix("second") { seconds += value; found = true }
        }
        return found ? Date().addingTimeInterval(TimeInterval(seconds)) : nil
    }

    fileprivate func assertSameEnd(_ endsAt: Date, _ running: XCUIElement, _ pose: String, file: StaticString = #filePath, line: UInt = #line) {
        guard running.waitForExistence(timeout: JourneyApp.interactionTimeout), let now = Self.endTime(of: running) else {
            XCTFail("The timer is gone in \(pose).", file: file, line: line)
            return
        }
        XCTAssertEqual(now.timeIntervalSince1970, endsAt.timeIntervalSince1970, accuracy: 2, "The timer's end moved in \(pose).", file: file, line: line)
    }
}
