import XCTest

@MainActor
final class SpoonjoyShoppingUITests: XCTestCase {
    /// The most recently launched app in the current test, terminated in `tearDown` so one test's app never
    /// leaks into the next test's `launch()` (evidence: CI run 36349596485, where the platform-fixture test's
    /// app was still running when the next test launched and XCTest failed waiting 60s to terminate it).
    private var launchedApp: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // The synchronous tearDownWithError() override is nonisolated (it matches a nonisolated XCTestCase
    // requirement), so under Swift 6 it can't touch this class's @MainActor state or call
    // XCUIApplication.terminate() (itself @MainActor) without an actual actor hop. Overriding the async
    // variant instead lets `await MainActor.run` make that hop for real, rather than reaching for
    // MainActor.assumeIsolated, whose synchronous "self capture" is flagged as a possible data race here.
    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            // Turn the device upright while the app is still in front. With no app open, an iPhone's
            // SpringBoard stays portrait, so a later rotation request never gets the confirmation XCUITest
            // waits for (run 37059261350: "Timed out waiting for confirmation of orientation change").
            if launchedApp != nil && XCUIDevice.shared.orientation != .portrait {
                XCUIDevice.shared.orientation = .portrait
            }
            launchedApp?.terminate()
            launchedApp = nil
        }
    }

    func testAccessibilityDynamicTypeAndResponsiveOrientationsKeepPrimaryControlsReachable() {
        ensurePortrait()
        let app = launchShopping(
            variant: "normal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        XCTAssertTrue(app.otherElements["shopping.ui-test.root"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["Add an item"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["Add an item"].isHittable)
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Add item"].isHittable)
        let modeSelector = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'Shopping view, All '")).firstMatch
        XCTAssertTrue(modeSelector.waitForExistence(timeout: 8))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.textFields["Add an item"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add item"].isHittable)
    }

    func testPendingAndRetryStatesStayLocalizedToTheShoppingSurface() {
        ensurePortrait()
        var app = launchShopping(variant: "pending", offline: true)
        let pendingItem = app.descendants(matching: .any)["shopping.item.item_lemons.pending"]
        XCTAssertTrue(pendingItem.waitForExistence(timeout: 8))
        XCTAssertFalse(pendingItem.isEnabled)
        let hideOfflineStatus = app.buttons["Hide offline status"]
        XCTAssertTrue(hideOfflineStatus.waitForExistence(timeout: 8))
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
        ensurePortrait()
        let app = launchShopping(variant: "normal")
        let itemField = app.textFields["Add an item"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 8))
        itemField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add item"].isHittable)
    }

    func testMarketFiltersComposerCheckAndDestructiveActionsAreInteractive() {
        ensurePortrait()
        let app = launchShopping(variant: "normal")
        XCTAssertTrue(app.otherElements["shopping.ui-test.root"].waitForExistence(timeout: 8))

        tapOnceItExists(app.buttons["Need 1"], named: "Need 1", in: app)
        tapOnceItExists(app.buttons["Basket 1"], named: "Basket 1", in: app)
        tapOnceItExists(app.buttons["All 2"], named: "All 2", in: app)
        tapOnceItExists(app.buttons["Produce"], named: "Produce", in: app)
        tapOnceItExists(app.buttons["All aisles"], named: "All aisles", in: app)

        tapOnceItExists(app.descendants(matching: .any)["shopping.item.item_lemons"], named: "The lemons row", in: app)
        XCTAssertTrue(app.staticTexts["Shopping list updated"].waitForExistence(timeout: 3))

        let itemField = app.textFields["Add an item"]
        itemField.tap()
        itemField.typeText("mint")
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.staticTexts["Shopping list updated"].waitForExistence(timeout: 3))
        // Adding with the button keeps the field focused for the next item. Return submits the next item and
        // closes the keyboard, which otherwise covers the rows below (run 36345815010: the long press on the
        // lemons row landed on the keyboard, so its context menu never opened).
        itemField.typeText("basil" + XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Return did not close the keyboard. \(app.debugDescription)")

        // Remove the row by its trailing swipe action before any confirmation dialog has been shown. A closed
        // confirmation dialog can leave an empty, full-screen window over the page that never goes away, and
        // that window covers the revealed Remove button (run 36983006897 attempt 2: the swipe revealed Remove
        // at {330, 733}, but an extra empty Window sat above it, so it never became hittable). The checked
        // parmesan row stays, so the receipt actions below still have something to clear.
        //
        // Removal goes through the trailing swipe action (ReceiptDeleteSwipeModifier in ReceiptListView.swift)
        // rather than a long-press context menu, which repeatedly opened an empty second context-menu window
        // (runs 36333893304, 36341886285, 36345815010 and 36373059798). The context menu keeps its coverage at
        // the contract level: NativeMobileDesignContractTests asserts both `.contextMenu` and
        // `ReceiptDeleteSwipeModifier {` are still present in ReceiptListView.swift.
        let lemons = app.descendants(matching: .any)["shopping.item.item_lemons"]
        scrollFullyOnScreen(lemons, in: app)
        waitUntilHittable(lemons, named: "The lemons row", in: app)
        lemons.swipeLeft()
        tapWhenHittable(app.buttons["Remove"], named: "The row's revealed Remove swipe action", in: app)
        tapWhenHittable(app.sheets.firstMatch.buttons["Remove Item"], named: "Remove Item", in: app)
        waitForNoSheet(in: app)

        tapOnceItExists(app.buttons["Receipt actions"], named: "Receipt actions", in: app)
        tapWhenHittable(app.buttons["Clear checked"], named: "The Clear checked menu item", in: app)
        tapWhenHittable(app.sheets.firstMatch.buttons["Clear Completed"], named: "Clear Completed", in: app)
        waitForNoSheet(in: app)

        tapOnceItExists(app.buttons["Receipt actions"], named: "Receipt actions", in: app)
        tapWhenHittable(app.buttons["Clear all"], named: "The Clear all menu item", in: app)
        tapWhenHittable(app.sheets.firstMatch.buttons["Clear All"], named: "Clear All", in: app)
        waitForNoSheet(in: app)
    }

    func testAccessibilityMenusAndRecipeFallbacksAreInteractive() {
        ensurePortrait()
        var app = launchShopping(
            variant: "normal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        let modeMenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'Shopping view, All '")).firstMatch
        XCTAssertTrue(modeMenu.waitForExistence(timeout: 8))
        modeMenu.tap()
        tapWhenHittable(app.buttons["Need 1"], named: "The menu's Need 1 item", in: app)
        // The menu's label names the chosen view once the menu has closed and the choice applied.
        let needSelected = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Shopping view, Need 1 selected'")).firstMatch
        XCTAssertTrue(needSelected.waitForExistence(timeout: 10), "Choosing Need 1 did not update the shopping view menu. \(app.debugDescription)")

        let categoryMenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'Aisle filter, All aisles'")).firstMatch
        tapOnceItExists(categoryMenu, named: "The aisle filter menu", in: app)
        tapWhenHittable(app.buttons["Produce"], named: "The menu's Produce item", in: app)
        let produceSelected = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Aisle filter, Produce selected'")).firstMatch
        XCTAssertTrue(produceSelected.waitForExistence(timeout: 10), "Choosing Produce did not update the aisle filter menu. \(app.debugDescription)")
        tapOnceItExists(app.buttons["Add from recipe"], named: "Add from recipe", in: app)
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
        XCTAssertTrue(primaryAdd.waitForExistence(timeout: 8))
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
        XCTAssertTrue(platformItem.waitForExistence(timeout: 8))
        platformItem.tap()
        app.buttons["Create a recipe"].tap()
    }

    /// Waits for `element` to exist and be hittable and enabled: for menu items, confirmation buttons and a
    /// long-press target, which must be on screen and uncovered, not still behind a closing sheet, menu or
    /// the keyboard. Fails with the screen if it does not settle. Nothing is retried.
    private func waitUntilHittable(
        _ element: XCUIElement,
        named name: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isHittable == true AND isEnabled == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [ready], timeout: 10),
            .completed,
            "\(name) did not become hittable. \(app.debugDescription)",
            file: file,
            line: line
        )
    }

    private func tapWhenHittable(
        _ element: XCUIElement,
        named name: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        waitUntilHittable(element, named: name, in: app, file: file, line: line)
        element.tap()
    }

    /// For a control in the scrolling page: waits for it to exist, scrolls it wholly into the safe middle of the
    /// screen, then taps it. At accessibility sizes the menus start at or below the bottom edge.
    private func tapOnceItExists(
        _ element: XCUIElement,
        named name: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) is missing. \(app.debugDescription)", file: file, line: line)
        scrollFullyOnScreen(element, in: app)
        element.tap()
    }

    /// Scrolls the page until `element` sits wholly between the navigation bar and the home indicator.
    ///
    /// XCUITest only scrolls a control into view when its center is off screen. A control whose center is on
    /// screen but whose frame runs past the bottom edge is tapped where it is, inside the home indicator's
    /// gesture zone, where the system sometimes keeps the touch (run 36983006897 attempt 3: the "Shopping
    /// view" menu spanned y 864 to 927 on a 912-point screen, the tap landed at y 896, and the menu never
    /// opened). The page is dragged slowly from its left margin, outside every control, so it does not coast
    /// past the target. A control that does not move with the page (a navigation bar button) is left as is.
    private func scrollFullyOnScreen(_ element: XCUIElement, in app: XCUIApplication) {
        let screen = app.windows.firstMatch.frame
        let safeTop = screen.minY + 200
        let safeBottom = screen.maxY - 120
        let maximumStep = screen.height * 0.4
        for _ in 0..<6 {
            let frame = element.frame
            if frame.minY >= safeTop && frame.maxY <= safeBottom { return }
            let target = frame.maxY > safeBottom ? safeBottom - frame.height : safeTop
            let step = max(min(target - frame.minY, maximumStep), -maximumStep)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: 8, dy: screen.midY))
            let end = origin.withOffset(CGVector(dx: 8, dy: screen.midY + step))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            if element.frame == frame { return }
        }
    }

    /// Turns the simulator upright only when it is not upright already. Setting the orientation it already
    /// has still waits for SpringBoard to confirm a change, and on a simulator that has just booted that
    /// confirmation can time out (run 36983006897 attempt 1, the first test of the run). Tests also call
    /// this again from `launchShopping`, once the app is in front, because a rotation requested while only
    /// SpringBoard is showing can never be confirmed on an iPhone.
    private func ensurePortrait() {
        if XCUIDevice.shared.orientation != .portrait {
            XCUIDevice.shared.orientation = .portrait
        }
    }

    /// Waits for a confirmation sheet to finish closing.
    private func waitForNoSheet(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.sheets.firstMatch.waitForNonExistence(timeout: 10),
            "A confirmation sheet did not close. \(app.debugDescription)",
            file: file,
            line: line
        )
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
        // The shopping UI test fixture is hermetic and never bootstraps the live store or reaches this URL
        // (SpoonjoyRootView skips liveStore.bootstrap() and swaps in a no-op sync coordinator whenever the
        // fixture is enabled). This is set only as defense in depth, so nothing that ever read
        // SPOONJOY_API_BASE_URL ahead of that guard could reach production.
        app.launchEnvironment["SPOONJOY_API_BASE_URL"] = "https://spoonjoy-v2-qa.mendelow-studio.workers.dev"
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
        ensurePortrait()
        launchedApp = app
        return app
    }

    private static let shoppingStateJSON = #"{"id":"shopping_ui_test","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[{"id":"item_lemons","name":"lemons","quantity":2,"unit":"each","checked":false,"checkedAt":null,"deletedAt":null,"categoryKey":"produce","iconKey":"citrus","sortIndex":0,"updatedAt":"2026-08-21T20:00:00.000Z"},{"id":"item_parmesan","name":"parmesan","quantity":0.5,"unit":"cup","checked":true,"checkedAt":"2026-08-21T20:01:00.000Z","deletedAt":null,"categoryKey":"dairy","iconKey":"milk","sortIndex":1,"updatedAt":"2026-08-21T20:01:00.000Z"}],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
    private static let emptyShoppingStateJSON = #"{"id":"shopping_empty","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
    private static let uncheckedOnlyShoppingStateJSON = #"{"id":"shopping_unchecked","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[{"id":"item_lemons","name":"lemons","quantity":2,"unit":"each","checked":false,"checkedAt":null,"deletedAt":null,"categoryKey":"produce","iconKey":"citrus","sortIndex":0,"updatedAt":"2026-08-21T20:00:00.000Z"}],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
    private static let checkedOnlyShoppingStateJSON = #"{"id":"shopping_checked","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[{"id":"item_parmesan","name":"parmesan","quantity":0.5,"unit":"cup","checked":true,"checkedAt":"2026-08-21T20:01:00.000Z","deletedAt":null,"categoryKey":"dairy","iconKey":"milk","sortIndex":0,"updatedAt":"2026-08-21T20:01:00.000Z"}],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
}
