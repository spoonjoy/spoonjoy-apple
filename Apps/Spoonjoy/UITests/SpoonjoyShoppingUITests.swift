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
        var app = launchShopping(variant: "pending")
        let pendingItem = app.descendants(matching: .any)["shopping.item.item_lemons.pending"]
        XCTAssertTrue(pendingItem.waitForExistence(timeout: 8))
        XCTAssertFalse(pendingItem.isEnabled)
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

    private func launchShopping(
        variant: String,
        contentSizeCategory: String = "UICTContentSizeCategoryL"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_FIXTURE"] = "1"
        app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_STATE"] = Self.shoppingStateJSON
        app.launchEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT"] = variant
        app.launchEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_MODE"] = "all"
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
}
