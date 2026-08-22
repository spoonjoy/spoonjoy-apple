import XCTest

@MainActor
final class SpoonjoyShoppingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAccessibilityDynamicTypeAndResponsiveOrientationsKeepPrimaryControlsReachable() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchShopping(
            variant: "normal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        XCTAssertTrue(app.otherElements["shopping.ui-test.root"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["Add an item"].isHittable)
        XCTAssertTrue(app.buttons["Add item"].isHittable)
        let modeSelector = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'Shopping view, All '")).firstMatch
        XCTAssertTrue(modeSelector.exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.textFields["Add an item"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add item"].isHittable)
    }

    func testPendingAndRetryStatesStayLocalizedToTheShoppingSurface() {
        XCUIDevice.shared.orientation = .portrait
        var app = launchShopping(variant: "pending", offline: true)
        let pendingItem = app.descendants(matching: .any)["shopping.item.item_lemons.pending"]
        XCTAssertTrue(pendingItem.waitForExistence(timeout: 8))
        XCTAssertFalse(pendingItem.isEnabled)
        let hideOfflineStatus = app.buttons["Hide offline status"]
        XCTAssertTrue(hideOfflineStatus.isHittable)
        hideOfflineStatus.tap()
        XCTAssertTrue(app.otherElements["shopping.ui-test.root"].exists)
        app.terminate()

        app = launchShopping(variant: "row-error")
        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 8))
        XCTAssertTrue(retry.isHittable)
        XCTAssertTrue(app.otherElements["shopping.ui-test.root"].exists)
    }

    func testComposerKeepsAddActionVisibleWhileKeyboardIsPresented() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchShopping(variant: "normal")
        let itemField = app.textFields["Add an item"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 8))
        itemField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add item"].isHittable)
    }

    func testMarketFiltersComposerCheckAndDestructiveActionsAreInteractive() {
        let app = launchShopping(variant: "normal")
        XCTAssertTrue(app.otherElements["shopping.ui-test.root"].waitForExistence(timeout: 8))

        app.buttons["Need 1"].tap()
        app.buttons["Basket 1"].tap()
        app.buttons["All 2"].tap()
        app.buttons["Produce"].tap()
        app.buttons["All aisles"].tap()

        app.descendants(matching: .any)["shopping.item.item_lemons"].tap()
        XCTAssertTrue(app.staticTexts["Shopping list updated"].waitForExistence(timeout: 3))

        let itemField = app.textFields["Add an item"]
        itemField.tap()
        itemField.typeText("mint")
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.staticTexts["Shopping list updated"].waitForExistence(timeout: 3))

        app.buttons["Receipt actions"].tap()
        app.buttons["Clear checked"].tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
        app.sheets.firstMatch.buttons["Clear Completed"].tap()

        app.buttons["Receipt actions"].tap()
        app.buttons["Clear all"].tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
        app.sheets.firstMatch.buttons["Clear All"].tap()

        let lemons = app.descendants(matching: .any)["shopping.item.item_lemons"]
        lemons.press(forDuration: 1)
        app.buttons["Remove"].tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
        app.sheets.firstMatch.buttons["Remove Item"].tap()
    }

    func testAccessibilityMenusAndRecipeFallbacksAreInteractive() {
        var app = launchShopping(
            variant: "normal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        let modeMenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'Shopping view, All '")).firstMatch
        XCTAssertTrue(modeMenu.waitForExistence(timeout: 8))
        modeMenu.tap()
        app.buttons["Need 1"].tap()

        let categoryMenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'Aisle filter, All aisles'")).firstMatch
        categoryMenu.tap()
        app.buttons["Produce"].tap()
        app.buttons["Add from recipe"].tap()
        app.terminate()

        app = launchShopping(
            variant: "normal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            noRecipes: true
        )
        XCTAssertTrue(app.buttons["Create a recipe"].waitForExistence(timeout: 8))
        app.buttons["Create a recipe"].tap()
    }

    func testMutationOutcomesFailureAndBothRetryPathsStayLocalized() {
        for (outcome, message) in [
            ("queued", "Saved for sync"),
            ("recovering", "Confirming shopping change…"),
        ] {
            let app = launchShopping(variant: "normal", outcome: outcome)
            let item = app.descendants(matching: .any)["shopping.item.item_lemons"]
            XCTAssertTrue(item.waitForExistence(timeout: 8))
            item.tap()
            XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 3))
            app.terminate()
        }

        var app = launchShopping(variant: "normal", outcome: "failed")
        let item = app.descendants(matching: .any)["shopping.item.item_lemons"]
        XCTAssertTrue(item.waitForExistence(timeout: 8))
        item.tap()
        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 3))
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 3))
        app.terminate()

        app = launchShopping(variant: "row-error")
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 8))
        app.buttons["Retry"].tap()
        XCTAssertTrue(app.staticTexts["Shopping list updated"].waitForExistence(timeout: 3))
    }

    func testEmptyFilteredNilAndPlatformFixturesRenderWithoutGlobalBlocking() {
        var app = launchShopping(variant: "normal", stateJSON: Self.emptyShoppingStateJSON)
        XCTAssertTrue(app.staticTexts["Your shopping list is empty"].waitForExistence(timeout: 8))
        app.terminate()

        app = launchShopping(variant: "normal", stateJSON: Self.uncheckedOnlyShoppingStateJSON, mode: "basket")
        XCTAssertTrue(app.staticTexts["Nothing in the basket yet"].waitForExistence(timeout: 8))
        app.terminate()

        app = launchShopping(variant: "normal", stateJSON: Self.checkedOnlyShoppingStateJSON, mode: "need")
        XCTAssertTrue(app.staticTexts["Nothing left in this view"].waitForExistence(timeout: 8))
        app.terminate()

        app = launchShopping(variant: "normal", noRecipes: true, omitState: true)
        XCTAssertTrue(app.staticTexts["Sync the receipt"].waitForExistence(timeout: 8))
        let primaryAdd = app.buttons.matching(NSPredicate(format: "label == 'Add item' AND identifier != 'plus'")).firstMatch
        XCTAssertTrue(primaryAdd.exists)
        primaryAdd.tap()
        app.terminate()

        app = launchShopping(variant: "normal", omitState: true)
        let addFromRecipe = app.buttons["Add from recipe"].firstMatch
        XCTAssertTrue(addFromRecipe.waitForExistence(timeout: 8))
        addFromRecipe.tap()
        app.terminate()

        app = launchShopping(variant: "normal", platformFixture: true)
        XCTAssertTrue(app.otherElements["shopping.ui-test.root"].waitForExistence(timeout: 8))
        let platformItem = app.descendants(matching: .any)["shopping.item.item_lemons"]
        XCTAssertTrue(platformItem.exists)
        platformItem.tap()
        app.buttons["Create a recipe"].tap()
    }

    private func launchShopping(
        variant: String,
        contentSizeCategory: String = "UICTContentSizeCategoryL",
        outcome: String? = nil,
        noRecipes: Bool = false,
        platformFixture: Bool = false,
        offline: Bool = false,
        stateJSON: String? = nil,
        omitState: Bool = false,
        mode: String = "all"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_FIXTURE"] = "1"
        if !omitState {
            app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_STATE"] = stateJSON ?? Self.shoppingStateJSON
        }
        if let outcome {
            app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_OUTCOME"] = outcome
        }
        if noRecipes {
            app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_NO_RECIPES"] = "1"
        }
        if platformFixture {
            app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_PLATFORM"] = "1"
        }
        if offline {
            app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_OFFLINE"] = "1"
        }
        app.launchEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT"] = variant
        app.launchEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_MODE"] = mode
        app.launchEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_CATEGORY"] = "all"
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", contentSizeCategory,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        return app
    }

    private static let shoppingStateJSON = #"{"id":"shopping_ui_test","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[{"id":"item_lemons","name":"lemons","quantity":2,"unit":"each","checked":false,"checkedAt":null,"deletedAt":null,"categoryKey":"produce","iconKey":"citrus","sortIndex":0,"updatedAt":"2026-08-21T20:00:00.000Z"},{"id":"item_parmesan","name":"parmesan","quantity":0.5,"unit":"cup","checked":true,"checkedAt":"2026-08-21T20:01:00.000Z","deletedAt":null,"categoryKey":"dairy","iconKey":"milk","sortIndex":1,"updatedAt":"2026-08-21T20:01:00.000Z"}],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
    private static let emptyShoppingStateJSON = #"{"id":"shopping_empty","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
    private static let uncheckedOnlyShoppingStateJSON = #"{"id":"shopping_unchecked","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[{"id":"item_lemons","name":"lemons","quantity":2,"unit":"each","checked":false,"checkedAt":null,"deletedAt":null,"categoryKey":"produce","iconKey":"citrus","sortIndex":0,"updatedAt":"2026-08-21T20:00:00.000Z"}],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
    private static let checkedOnlyShoppingStateJSON = #"{"id":"shopping_checked","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[{"id":"item_parmesan","name":"parmesan","quantity":0.5,"unit":"cup","checked":true,"checkedAt":"2026-08-21T20:01:00.000Z","deletedAt":null,"categoryKey":"dairy","iconKey":"milk","sortIndex":0,"updatedAt":"2026-08-21T20:01:00.000Z"}],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
}
