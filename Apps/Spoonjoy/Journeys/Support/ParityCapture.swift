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
        return Kitchen(recipeID: riceID, cookbookID: weeknightID, username: account.username)
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

    private func shootSchemes(_ screen: String, device: String) throws {
        Self.setAppearance(.light)
        try shoot(Self.shotName(screen, device: device, scheme: "light"))
        Self.setAppearance(.dark)
        try shoot(Self.shotName(screen, device: device, scheme: "dark"))
        XCUIDevice.shared.appearance = .light
        Self.post(.system)
    }

    /// Turns the device and lets the rotation and the relayout that follows it finish.
    static func turn(_ orientation: UIDeviceOrientation) {
        guard XCUIDevice.shared.orientation != orientation else { return }
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
