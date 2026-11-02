import SpoonjoyCore
import XCTest

/// The iPhone Duo journey: two real recipes on the go, cooked through every posture of the device. Closed, the Kitchen
/// shows "Cooking now" and the tab bar's switcher, and the app reopens in cook mode on the saved step after it is
/// killed. Opened flat, the Kitchen fills the inner screen held sideways and held tall. Half-open (forced with
/// `-SpoonjoyForcePosture`, as the simulator's hinge cannot stand half-open), cook mode splits at the fold on the
/// counter and lies open held like a book. Last, a recipe opens in a window of its own beside the first, and after a
/// kill whichever window comes back in front is on its own recipe. Every screen is saved twice: by XCUITest, and by the
/// Mac for both Duo displays.
///
/// It is its own target, SpoonjoyDuoJourneys, which only the Duo journeys job runs: it needs the posture driver beside
/// the simulator (`DuoHinge`), and fails without it.
@MainActor
final class DuoJourney: JourneyTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        executionTimeAllowance = 1800
    }

    func testCookingNowThroughEveryDuoPostureJourney() async throws {
        let account = try JourneyAccounts.account(1)
        let qa = try await JourneyQAClient.signIn(account)
        let pastaID = try await qa.createRecipe(
            title: JourneyRecipes.pastaTitle,
            description: JourneyRecipes.pastaDescription,
            servings: "4",
            steps: JourneyRecipes.pastaSteps
        )
        try await qa.uploadCover(recipeID: pastaID, photo: try JourneyRecipes.pastaPhoto())
        // The chickpeas keep no photo: their rows show the warm initial plate.
        let chickpeasID = try await qa.createRecipe(
            title: JourneyRecipes.chickpeasTitle,
            description: JourneyRecipes.chickpeasDescription,
            servings: "4 as a side",
            steps: JourneyRecipes.chickpeasSteps
        )
        let pastaStepTwo = "Step 2 of \(JourneyRecipes.pastaStepCount)"
        let chickpeasStepTwo = "Step 2 of \(JourneyRecipes.chickpeasStepCount)"
        let pastaLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(pastaID)"))
        let chickpeasLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(chickpeasID)"))
        let kitchenLink = try XCTUnwrap(URL(string: "spoonjoy://kitchen"))

        // Closed: the outer screen, a phone.
        try DuoHinge.set(.closed)
        XCUIDevice.shared.orientation = .portrait
        let journey = JourneyApp.launchFresh()
        try DuoHinge.installSession(try await JourneyQAClient.nativeSession(account))
        journey.relaunch()
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The installed session did not open the kitchen. Screen: \(journey.screen)"
        )

        // Two pans on the go: the chickpeas left on their second step, then the pasta.
        try cookToStepTwo(journey, link: chickpeasLink, stepLabel: chickpeasStepTwo)
        journey.tap(JourneyID.cookClose)
        try cookToStepTwo(journey, link: pastaLink, stepLabel: pastaStepTwo)
        try capture("01-closed-cook-step-2", journey)

        // The Kitchen leads with the pasta, the cook on the counter, and lists the chickpeas under Cooking now; the
        // tab bar carries the pasta.
        journey.tap(JourneyID.cookClose)
        journey.openLink(kitchenLink)
        let chickpeasRow = journey.element(JourneyID.kitchenCookingNowCard, labelContaining: JourneyRecipes.chickpeasTitle)
        XCTAssertTrue(
            chickpeasRow.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Kitchen has no Cooking now row for the chickpeas. Screen: \(journey.screen)"
        )
        XCTAssertTrue(chickpeasRow.label.contains(chickpeasStepTwo), "The chickpeas row does not say step 2: \(chickpeasRow.label)")
        XCTAssertFalse(
            journey.element(JourneyID.kitchenCookingNowCard, labelContaining: JourneyRecipes.pastaTitle).exists,
            "Cooking now names the pasta the hero already leads with. Screen: \(journey.screen)"
        )
        let accessory = journey.element(JourneyID.cookingNowAccessoryResume)
        XCTAssertTrue(
            accessory.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The tab bar has no Cooking now switcher. Screen: \(journey.screen)"
        )
        XCTAssertTrue(accessory.label.contains(JourneyRecipes.pastaTitle), "The switcher does not lead with the pasta: \(accessory.label)")
        try capture("02-closed-kitchen-cooking-now", journey)
        XCTAssertEqual(
            journey.hittableButtons(coveredBy: journey.element(JourneyID.cookingNowAccessoryBar)), [],
            "The Cooking now switcher covers buttons on the Kitchen at rest. Screen: \(journey.screen)"
        )
        // Scrolled to the foot, the page's last row still clears the switcher.
        journey.element(JourneyID.kitchenRoot).swipeUp()
        journey.element(JourneyID.kitchenRoot).swipeUp()
        try capture("03-closed-kitchen-foot-with-switcher", journey)
        XCTAssertEqual(
            journey.hittableButtons(coveredBy: journey.element(JourneyID.cookingNowAccessoryBar)), [],
            "The Cooking now switcher covers buttons at the foot of the Kitchen. Screen: \(journey.screen)"
        )

        // The switcher goes back to the pasta's step; killed there, the app reopens in cook mode on that step.
        accessory.tap()
        let pastaCookStep = cookOnStepTwo(journey, stepLabel: pastaStepTwo)
        XCTAssertTrue(
            pastaCookStep.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The switcher did not go back to cooking the pasta on step 2. Screen: \(journey.screen)"
        )
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
            XCTAssertTrue(
                pastaCookStep.waitForExistence(timeout: JourneyApp.networkTimeout),
                "The app did not reopen in cook mode on step 2 after it was killed. Screen: \(journey.screen)"
            )
        }
        try capture("04-closed-restored-cook-step-2", journey)

        // Open flat, held sideways: the inner screen.
        journey.tap(JourneyID.cookClose)
        journey.openLink(kitchenLink)
        try DuoHinge.set(.open)
        XCTAssertTrue(
            chickpeasRow.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Opening the Duo lost the Kitchen's Cooking now. Screen: \(journey.screen)"
        )
        try capture("05-open-landscape-kitchen", journey)

        // Open flat, held tall.
        try DuoHinge.rotateRight()
        XCTAssertTrue(
            chickpeasRow.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Turning the open Duo upright lost the Kitchen's Cooking now. Screen: \(journey.screen)"
        )
        try capture("06-open-portrait-kitchen", journey)

        // A Cooking now row goes straight back into cook mode on its step.
        chickpeasRow.tap()
        let chickpeasCookStep = cookOnStepTwo(journey, stepLabel: chickpeasStepTwo)
        XCTAssertTrue(
            chickpeasCookStep.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Cooking now row did not open the chickpeas' cook mode on step 2. Screen: \(journey.screen)"
        )
        try capture("07-open-portrait-cook", journey)

        // Half-open on the counter (tabletop): the window reopens in cook mode, split at the fold.
        journey.useForcedPostureOnNextLaunch("tabletop")
        journey.relaunch()
        XCTAssertTrue(
            journey.element(JourneyID.cookTabletopStep).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode on a half-open Duo did not put the step above the fold. Screen: \(journey.screen)"
        )
        try capture("08-tabletop-cook", journey)

        // Half-open and turned on its side, held like a book: the fold runs down the middle.
        try DuoHinge.rotateRight()
        journey.useForcedPostureOnNextLaunch("book")
        journey.relaunch()
        // Held like a book, cook mode can lie as a spread, stand at the fold or keep its single page; any of them is
        // cook mode back on the chickpeas.
        let bookCook = journey.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@",
            [JourneyID.cookSpreadStepPage, JourneyID.cookTabletopStep, JourneyID.cookStepText]
        )).firstMatch
        XCTAssertTrue(
            bookCook.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode on a Duo held like a book did not come back. Screen: \(journey.screen)"
        )
        try capture("09-book-cook", journey)

        // Back to the real hinge, open flat and sideways: the chickpeas open in a window of its own beside the
        // Kitchen, and the Kitchen's window goes on to cook the pasta. One recipe per window.
        journey.useForcedPostureOnNextLaunch(nil)
        journey.relaunch()
        journey.openLink(kitchenLink)
        XCTAssertTrue(
            chickpeasRow.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Kitchen did not come back open flat. Screen: \(journey.screen)"
        )
        chickpeasRow.press(forDuration: 1.2)
        let openInNewWindow = journey.copy(JourneyCopy.openInNewWindow)
        XCTAssertTrue(
            openInNewWindow.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The Cooking now row's menu has no Open in New Window on the open Duo. Screen: \(journey.screen)"
        )
        try captureScreen("10-open-in-new-window-menu", journey)
        openInNewWindow.tap()
        let windows = journey.waitForWindows(2)
        try captureScreen("11-two-windows", journey)
        attachText("11-two-windows-probes", windows.joined(separator: "\n"))
        XCTAssertGreaterThanOrEqual(windows.count, 2, "Open in New Window did not open a second window. Screen: \(journey.screen)")

        let keepCooking = journey.element(JourneyID.kitchenRecipeCook)
        if journey.waitForFront(keepCooking, timeout: JourneyApp.interactionTimeout) {
            keepCooking.tap()
        }
        _ = cookOnStepTwo(journey, stepLabel: pastaStepTwo).waitForExistence(timeout: JourneyApp.networkTimeout)
        try captureScreen("12-two-windows-two-recipes", journey)
        let twoRecipes = journey.windowProbes
        attachText("12-two-windows-probes", twoRecipes.joined(separator: "\n"))
        XCTAssertTrue(
            twoRecipes.contains { $0.contains(pastaID) } && twoRecipes.contains { $0.contains(chickpeasID) },
            "The two windows are not on the pasta and the chickpeas: \(twoRecipes). Screen: \(journey.screen)"
        )

        // Killed with two windows open, the window that comes back in front is on its own recipe, not the other's.
        journey.relaunch()
        let front = journey.waitForWindows(1)
        try captureScreen("13-windows-after-relaunch", journey)
        attachText("13-windows-after-relaunch-probes", front.joined(separator: "\n"))
        XCTAssertFalse(front.isEmpty, "No window came back after the app was killed. Screen: \(journey.screen)")
        XCTAssertTrue(
            front.allSatisfy { $0.contains(pastaID) || $0.contains(chickpeasID) },
            "A window came back on neither recipe after the app was killed: \(front). Screen: \(journey.screen)"
        )
    }

    /// Opens a recipe by link, starts cooking and turns to its second step. On the closed Duo cook mode opens as the
    /// cover glance, whose Next turns the step.
    private func cookToStepTwo(_ journey: JourneyApp, link: URL, stepLabel: String) throws {
        journey.openLink(link)
        journey.tap(JourneyID.recipeDetailCook)
        journey.tap(JourneyID.cookCoverGlanceNext)
        XCTAssertTrue(
            cookOnStepTwo(journey, stepLabel: stepLabel).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Next did not turn cook mode to \(stepLabel). Screen: \(journey.screen)"
        )
    }

    /// Cook mode on its second step, in whichever form the posture gives it: the page's step line ("Step 2 of 5"),
    /// or the closed Duo's cover glance ("Current cooking step 2, ...").
    private func cookOnStepTwo(_ journey: JourneyApp, stepLabel: String) -> XCUIElement {
        journey.app.descendants(matching: .any).matching(NSPredicate(
            format: "(identifier == %@ AND label CONTAINS %@) OR (identifier == %@ AND label BEGINSWITH %@)",
            JourneyID.cookStepMeta,
            stepLabel,
            JourneyID.cookCoverGlanceTitle,
            "Current cooking step 2,"
        )).firstMatch
    }

    /// Saves the app's screenshot in the result bundle and the Mac's screenshots of both Duo displays.
    private func capture(_ name: String, _ journey: JourneyApp) throws {
        journey.attachScreenshot(named: name, to: self)
        attachText("\(name)-log", "Sync log: \(journey.syncLog)\nCooking now: \(journey.cookingNowLog)")
        try DuoHinge.shot(name)
    }

    /// Saves the whole screen, every window of the app included, and the Mac's screenshots of both Duo displays.
    private func captureScreen(_ name: String, _ journey: JourneyApp) throws {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try DuoHinge.shot(name)
    }

    private func attachText(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
