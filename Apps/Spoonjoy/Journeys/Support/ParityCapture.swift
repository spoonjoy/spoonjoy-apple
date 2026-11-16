import SpoonjoyCore
import UIKit
import XCTest

/// The native half of the web/native parity sheet (desk task spoonjoy/web-native-visual-parity, plan Task 4): the
/// canonical screens, each shot in light and dark as `parity-<screen>-<device>-<scheme>`, the names spoonjoy-v2's
/// parity.desktop.journey.ts gives the same screens on web. `scripts/parity-sheet.rb` pairs the two.
///
/// The account's kitchen mirrors the web QA chef's (spoonjoy-v2 scripts/seed-qa-kitchen.mjs): Lemon Herb Rice and a
/// tomato soup, a Weeknight Dinners cookbook holding the rice, and three items on the shopping list. ParityJourneys
/// shoots it on the iPhone and iPad; DuoCanonicalScreensJourney on the open Duo, through the posture driver.
@MainActor
struct ParityCapture {
    static let recipeTitle = "Lemon Herb Rice"
    static let soupTitle = "Roasted Tomato Soup"
    static let cookbookTitle = "Weeknight Dinners"
    static let shoppingItem = "jasmine rice"
    /// The appearance change redraws the whole window; a shot taken at once can catch it half drawn.
    private static let schemeSettle: TimeInterval = 1.5

    struct Kitchen: Sendable {
        let recipeID: String
        let soupID: String
        let cookbookID: String
        let username: String
    }

    let journey: JourneyApp
    /// "iphone", "ipad" or "duo-open".
    let device: String
    /// Keeps one shot under the given name.
    let shoot: (String) throws -> Void

    /// "ipad" on an iPad, otherwise "iphone". The runner reports the phone idiom on an iPad, so the simulator model decides.
    static var deviceName: String {
        ParityShotDevice.name(
            simulatorModelIdentifier: ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
            idiomIsPad: UIDevice.current.userInterfaceIdiom == .pad
        )
    }

    static func shotName(_ screen: String, device: String, scheme: String) -> String {
        "parity-\(screen)-\(device)-\(scheme)"
    }

    /// Makes the web QA chef's kitchen on this account, through QA as the connector or a share would.
    static func seed(_ account: JourneyAccount) async throws -> Kitchen {
        let qa = try await JourneyQAClient.signIn(account)
        let riceID = try await qa.createRecipe(title: recipeTitle, servings: "4", steps: riceSteps)
        let soupID = try await qa.createRecipe(title: soupTitle, servings: "4", steps: soupSteps)
        let weeknightID = try await qa.createCookbook(title: cookbookTitle)
        try await qa.addRecipe(riceID, toCookbook: weeknightID)
        let soupsID = try await qa.createCookbook(title: "Soups")
        try await qa.addRecipe(soupID, toCookbook: soupsID)
        try await qa.addShoppingItem(name: shoppingItem, quantity: 1, unit: "cup")
        try await qa.addShoppingItem(name: "lemon", quantity: 1, unit: "whole")
        try await qa.addShoppingItem(name: "parsley", quantity: 0.25, unit: "cup")
        return Kitchen(recipeID: riceID, soupID: soupID, cookbookID: weeknightID, username: account.username)
    }

    /// Shoots the screen as it stands in light, then in dark, and leaves the simulator light. On the iPad it then turns
    /// the iPad on its side and shoots the same screen again as `ipad-landscape`, so every iPad layout is seen both ways,
    /// and turns it back.
    func shootBothSchemes(_ screen: String) throws {
        try shootSchemes(screen, device: device)
        guard device == "ipad" else { return }
        Self.turn(.landscapeLeft)
        try shootSchemes(screen, device: "ipad-landscape")
        Self.turn(.portrait)
    }

    /// Shoots the screen in light and dark as it stands, without turning an iPad on its side.
    func shootPortraitSchemes(_ screen: String) throws {
        try shootSchemes(screen, device: device)
    }

    private func shootSchemes(_ screen: String, device: String) throws {
        Self.setAppearance(.light)
        try shoot(Self.shotName(screen, device: device, scheme: "light"))
        Self.setAppearance(.dark)
        try shoot(Self.shotName(screen, device: device, scheme: "dark"))
        XCUIDevice.shared.appearance = .light
        Self.post(.system)
    }

    /// Turns the device and lets the rotation and the relayout that follows it finish. It always sets the orientation:
    /// the simulator's reading of it can be stale, and a skipped turn back would leave every later shot sideways.
    static func turn(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        Thread.sleep(forTimeInterval: rotationSettle)
    }

    /// The rotation animation is about half a second; the relayout after it can run a moment longer.
    private static let rotationSettle: TimeInterval = 1.5

    /// Sets the simulator's appearance and tells the app to match, then lets it redraw. On CI the simulator setting
    /// alone left every dark shot identical to the light one (Journeys run 42481642383), so the app's own override,
    /// driven by `NativeJourneyAppearance`, is what makes the scheme certain.
    private static func setAppearance(_ appearance: NativeJourneyAppearance) {
        XCUIDevice.shared.appearance = appearance == .dark ? .dark : .light
        post(appearance)
        Thread.sleep(forTimeInterval: schemeSettle)
    }

    private static func post(_ appearance: NativeJourneyAppearance) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(appearance.notificationName as CFString),
            nil,
            nil,
            true
        )
    }

    func signInScreen() throws {
        wait(journey.element(JourneyID.passwordSignIn), "The signed-out screen is not showing.")
        try shootBothSchemes("sign-in")
    }

    /// Signs in through the form and waits for the app to leave the sign-in screen, then shoots the empty kitchen.
    ///
    /// Journeys run 43931150392 (#383) failed here as "the kitchen does not show its empty hero", but the app never
    /// got that far: the form said "Could not sign in" for the run's own new account, whose password the account
    /// script then used to sign in to QA. So a failed sign-in is named as one, with what QA says to the same
    /// credentials from the test runner, and is tried once more. Whether sign-in works is SignInJourney's subject;
    /// here it is only the way in to the screens.
    func signInToEmptyKitchen(_ account: JourneyAccount) async throws {
        journey.signIn(as: account.username, password: account.password)
        if formRejectedSignIn() {
            let firstStatus = signInStatus
            let runner = await runnerSignIn(account)
            XCTContext.runActivity(named: "The sign-in form said \"\(firstStatus)\"; \(runner). Signing in once more.") { _ in }
            journey.signIn(as: account.username, password: account.password)
            // The failure line stays until the app takes the new attempt; do not read the first attempt's answer.
            _ = journey.element(JourneyID.signInStatus, labelContaining: JourneyCopy.wrongPasswordStatus)
                .waitForNonExistence(timeout: JourneyApp.interactionTimeout)
            if formRejectedSignIn() {
                XCTFail(
                    "The sign-in form rejected the run's own account twice (\"\(signInStatus)\"); \(runner). "
                        + "The kitchen was never reached. Screen: \(journey.screen)"
                )
                return
            }
        }
        try emptyKitchen()
    }

    /// Waits for either the new account's kitchen or the sign-in form's failure line, and says whether it was the
    /// failure. Neither within the network timeout counts as not rejected, so `emptyKitchen` reports it.
    private func formRejectedSignIn() -> Bool {
        let outcome = journey.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ OR (identifier == %@ AND label CONTAINS %@)",
            JourneyID.kitchenEmptyHero,
            JourneyID.signInStatus,
            JourneyCopy.wrongPasswordStatus
        )).firstMatch
        guard outcome.waitForExistence(timeout: JourneyApp.networkTimeout) else { return false }
        return !journey.element(JourneyID.kitchenEmptyHero).exists
            && journey.element(JourneyID.signInStatus, labelContaining: JourneyCopy.wrongPasswordStatus).exists
    }

    private var signInStatus: String {
        let status = journey.element(JourneyID.signInStatus)
        return status.exists ? status.label : "no status line"
    }

    /// What QA answers when the test runner signs in with the same credentials the form was given: it tells a
    /// problem in the app or simulator apart from one on QA.
    private func runnerSignIn(_ account: JourneyAccount) async -> String {
        do {
            _ = try await JourneyQAClient.signIn(account)
            return "the same credentials signed in to QA from the test runner"
        } catch {
            return "the test runner's sign-in to QA with the same credentials failed too (\(error))"
        }
    }

    func emptyKitchen() throws {
        wait(journey.element(JourneyID.kitchenEmptyHero), "The new account's kitchen does not show its empty hero.")
        try shootBothSchemes("kitchen-empty")
    }

    func kitchen() throws {
        journey.openLink(try link("kitchen"))
        wait(
            journey.element(JourneyID.kitchenRecipe, labelContaining: Self.recipeTitle),
            "The kitchen does not list \(Self.recipeTitle)."
        )
        try shootBothSchemes("kitchen")
    }

    func recipe(_ kitchen: Kitchen) throws {
        journey.openLink(try link("recipes/\(kitchen.recipeID)"))
        wait(journey.element(JourneyID.recipeDetailTitle, labelContaining: Self.recipeTitle), "The recipe page did not open.")
        try shootBothSchemes("recipe")
    }

    /// The recipe page with jasmine rice checked: the checked row web and native both draw. Clear progress puts the
    /// page back, so the cook-mode shots start unchecked.
    func recipeChecked(_ kitchen: Kitchen) throws {
        journey.openLink(try link("recipes/\(kitchen.recipeID)"))
        let rice = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: Self.shoppingItem)
        wait(rice, "The recipe page does not list \(Self.shoppingItem).")
        journey.swipeUpUntilHittable(rice)
        rice.tap()
        wait(journey.element(JourneyID.recipeDetailClearProgress), "Checking \(Self.shoppingItem) did not show Clear progress.")
        try shootBothSchemes("recipe-checked")
        // Clear progress sits in the Steps heading, above the row, so a long page may have scrolled it off the top.
        let clear = journey.element(JourneyID.recipeDetailClearProgress)
        journey.swipeDownUntilHittable(clear)
        clear.tap()
        XCTAssertTrue(
            clear.waitForNonExistence(timeout: JourneyApp.interactionTimeout),
            "Clear progress did not clear the check. Screen: \(journey.screen)"
        )
    }

    func shopping() throws {
        journey.openLink(try link("shopping-list"))
        wait(label(containing: Self.shoppingItem), "The shopping list does not show \(Self.shoppingItem).")
        try shootBothSchemes("shopping")
    }

    func cookbooks() throws {
        journey.openLink(try link("cookbooks"))
        wait(journey.element(JourneyID.cookbookShelf), "The Cookbooks shelf did not open.")
        wait(label(containing: Self.cookbookTitle), "The Cookbooks shelf does not show \(Self.cookbookTitle).")
        try shootBothSchemes("cookbooks")
    }

    func cookbook(_ kitchen: Kitchen) throws {
        journey.openLink(try link("cookbooks/\(kitchen.cookbookID)"))
        wait(journey.element(JourneyID.cookbookDetailHero), "The cookbook page did not open.")
        // At AX5 the hero fills the iPhone's first screen and the lazy list has not made the row yet (Journeys run
        // 42945229333), so swipe to it; at the default size it is already on screen and this does nothing.
        journey.swipeUpUntilHittable(label(containing: Self.recipeTitle))
        wait(label(containing: Self.recipeTitle), "The cookbook page does not list \(Self.recipeTitle).")
        try shootBothSchemes("cookbook")
    }

    func chef(_ kitchen: Kitchen) throws {
        journey.openLink(try link("users/\(kitchen.username)"))
        wait(label(containing: kitchen.username), "The chef page for \(kitchen.username) did not open.")
        try shootBothSchemes("chef")
    }

    /// Add to list sends the ingredients to Reminders, through the list picker sheet. Web has no sheet here.
    func addToListSheet(_ kitchen: Kitchen) throws {
        journey.openLink(try link("recipes/\(kitchen.recipeID)"))
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailRemindersSend)
        journey.allowRemindersAccessIfAsked()
        // The picker is a lazy List: at AX5 on iPhone its "new list" field is below the first screen and not made
        // yet (Journeys run 42948350953), so either of its rows proves it opened.
        let picker = journey.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@",
            [JourneyID.remindersList, JourneyID.remindersNewListName]
        )).firstMatch
        wait(picker, "The Reminders list picker did not open.")
        try shootBothSchemes("sheet-add-to-list")
    }

    /// Cook mode on the recipe's first step, in whichever form the device gives it: the page, or the open spread.
    func cookStep(_ kitchen: Kitchen) throws {
        journey.openLink(try link("recipes/\(kitchen.recipeID)/cook"))
        let step = journey.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@",
            [JourneyID.cookStepText, JourneyID.cookSpreadStepPage, JourneyID.cookTabletopStep]
        )).firstMatch
        wait(step, "Cook mode did not open on a step.")
        try shootBothSchemes("cook-step")
    }

    /// Cook mode's last step with Finish cooking in view (#276). A regular-width screen also shows the dock's Mark step;
    /// a compact iPhone has no dock, so Finish cooking at the end of the last page is how a cook marks it done.
    /// Run after `cookStep`.
    func cookFinish() throws {
        // Only the page on screen carries the step-text identifier; a neighbouring page's preview does not.
        let lastStep = journey.element(JourneyID.cookStepText, labelContaining: Self.riceSteps.last?.description ?? "")
        // The rice has three steps: two turns from the first.
        turnCookPage()
        turnCookPage()
        wait(lastStep, "Cook mode did not turn to the last step.")
        let finish = journey.element(JourneyID.cookFinish)
        wait(finish, "The last step has no Finish cooking.")
        journey.swipeUpUntilHittable(finish)
        XCTAssertTrue(finish.isHittable, "Finish cooking cannot be reached on the last step. Screen: \(journey.screen)")
        try shootBothSchemes("cook-finish")
    }

    /// Turns cook mode to the next step: the dock's or the spread's Next where there is one, a swipe on a compact page.
    private func turnCookPage() {
        let dockNext = journey.element(JourneyID.cookDockNext)
        let spreadNext = journey.element(JourneyID.cookSpreadNext)
        let page = journey.element(JourneyID.cookStepText)
        let before = page.label
        if dockNext.exists {
            dockNext.tap()
        } else if spreadNext.exists {
            spreadNext.tap()
        } else {
            journey.element(JourneyID.cookPage).swipeLeft()
        }
        let turned = NSPredicate { _, _ in page.exists && page.label != before }
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: JourneyApp.interactionTimeout)
    }

    /// On the iPad, the soup opened in a window of its own from its Kitchen row's menu: the second scene. Shot of the
    /// whole screen, upright only. Other devices have no such menu item here, so this does nothing there. The soup,
    /// because after cook mode the rice is the Kitchen's hero, which has no menu.
    func secondWindow(_ kitchen: Kitchen) throws {
        guard device == "ipad" else { return }
        journey.openLink(try link("kitchen"))
        let row = journey.element(JourneyID.kitchenRecipe, labelContaining: Self.soupTitle)
        wait(row, "The kitchen does not list \(Self.soupTitle).")
        // At AX5 the hero can push the index row below the first screen.
        journey.swipeUpUntilHittable(row)
        row.press(forDuration: 1.2)
        let openInNewWindow = journey.copy(JourneyCopy.openInNewWindow)
        XCTAssertTrue(
            openInNewWindow.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The Kitchen row's menu has no Open in New Window on the iPad. Screen: \(journey.screen)"
        )
        openInNewWindow.tap()
        wait(journey.element(JourneyID.recipeDetailTitle, labelContaining: Self.soupTitle), "The new window is not the soup.")
        try shootPortraitSchemes("second-window")
        // A window the system has put behind the new one may stop reporting itself, so only the soup's own window is
        // required; the count goes in the failure message of the assertion above if that fails.
        let windows = journey.windowProbes
        XCTAssertTrue(
            windows.contains { $0.contains(kitchen.soupID) },
            "No window reports the soup's recipe page: \(windows). Screen: \(journey.screen)"
        )
    }

    private func link(_ path: String) throws -> URL {
        try XCTUnwrap(URL(string: "spoonjoy://\(path)"))
    }

    private func label(containing text: String) -> XCUIElement {
        journey.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func wait(_ element: XCUIElement, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            element.waitForExistence(timeout: JourneyApp.networkTimeout),
            "\(message) Screen: \(journey.screen)",
            file: file,
            line: line
        )
    }

    private static let riceSteps = [
        RecipeStepDraft(
            stepNum: 1,
            stepTitle: "Cook the rice",
            description: "Simmer rice in stock until tender.",
            duration: 15,
            ingredients: [
                RecipeIngredientDraft(quantity: 1, unit: "cup", name: "jasmine rice"),
                RecipeIngredientDraft(quantity: 2, unit: "cup", name: "chicken stock")
            ],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 2,
            stepTitle: "Make the dressing",
            description: "Whisk lemon juice, zest and herbs.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 1, unit: "whole", name: "lemon"),
                RecipeIngredientDraft(quantity: 0.25, unit: "cup", name: "parsley")
            ],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 3,
            stepTitle: "Combine",
            description: "Fold the dressing through the cooked rice.",
            duration: nil,
            ingredients: [],
            outputStepNums: [1]
        )
    ]

    private static let soupSteps = [
        RecipeStepDraft(
            stepNum: 1,
            stepTitle: "Roast",
            description: "Roast tomatoes and garlic until blistered.",
            duration: nil,
            ingredients: [
                RecipeIngredientDraft(quantity: 6, unit: "whole", name: "tomato"),
                RecipeIngredientDraft(quantity: 4, unit: "clove", name: "garlic")
            ],
            outputStepNums: []
        ),
        RecipeStepDraft(
            stepNum: 2,
            stepTitle: "Blend",
            description: "Blend with stock until smooth.",
            duration: nil,
            ingredients: [RecipeIngredientDraft(quantity: 2, unit: "cup", name: "vegetable stock")],
            outputStepNums: []
        )
    ]
}
