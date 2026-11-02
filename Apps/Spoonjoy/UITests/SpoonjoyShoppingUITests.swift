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
            // A failure in this block must be recorded, not interrupt the test. With continueAfterFailure false,
            // XCTest answers a failed terminate() by interrupting the test and running the teardown sequence
            // again, nested on the main thread. That nested pass waits for this async tearDown, which needs the
            // main actor this block is still holding, so the runner deadlocks until the 5-minute allowance
            // expires and xcodebuild restarts it (runs 38085281435 and 38152804640: the spindump shows
            // `MainActor.run` -> `terminate` -> `_interruptTest` -> `_performTearDownSequence` waiting forever).
            // The failure itself still fails the test.
            continueAfterFailure = true
            // Turn the device upright while the app is still in front. With no app open, an iPhone's
            // SpringBoard stays portrait, so a later rotation request never gets the confirmation XCUITest
            // waits for (run 37059261350: "Timed out waiting for confirmation of orientation change").
            if let launchedApp, launchedApp.state != .notRunning {
                if XCUIDevice.shared.orientation != .portrait {
                    XCUIDevice.shared.orientation = .portrait
                }
                launchedApp.terminate()
            }
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
        // Need, Basket and All, and the aisle filter, live in the ⋯ menu.
        XCTAssertTrue(app.buttons["Receipt actions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Receipt actions"].isHittable)

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

        chooseShoppingView("Need 1", in: app)
        XCTAssertTrue(app.staticTexts["Showing Need 1"].waitForExistence(timeout: 5), "Choosing Need 1 did not say so. \(app.debugDescription)")
        chooseShoppingView("Basket 1", in: app)
        chooseShoppingView("All 2", in: app)
        XCTAssertTrue(app.staticTexts["Showing Basket 1"].waitForNonExistence(timeout: 5), "Choosing All left a filter line. \(app.debugDescription)")
        chooseAisle("Produce", in: app)
        XCTAssertTrue(app.staticTexts["Showing Produce"].waitForExistence(timeout: 5), "Choosing Produce did not say so. \(app.debugDescription)")
        tapOnceItExists(app.buttons["Show all"], named: "Show all", in: app)
        XCTAssertTrue(app.buttons["Show all"].waitForNonExistence(timeout: 5), "Show all did not clear the filter. \(app.debugDescription)")

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
        tapConfirmation("Remove Item", in: app)
        waitForNoSheet(in: app)

        tapOnceItExists(app.buttons["Receipt actions"], named: "Receipt actions", in: app)
        tapWhenHittable(app.buttons["Clear checked"], named: "The Clear checked menu item", in: app)
        tapConfirmation("Clear Completed", in: app)
        waitForNoSheet(in: app)

        tapOnceItExists(app.buttons["Receipt actions"], named: "Receipt actions", in: app)
        tapWhenHittable(app.buttons["Clear all"], named: "The Clear all menu item", in: app)
        tapConfirmation("Clear All", in: app)
        waitForNoSheet(in: app)
    }

    func testAccessibilityMenusAndRecipeFallbacksAreInteractive() {
        ensurePortrait()
        var app = launchShopping(
            variant: "normal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        // The filter line under the composer names the chosen view once the menu has closed and the choice applied.
        chooseShoppingView("Need 1", in: app)
        XCTAssertTrue(app.staticTexts["Showing Need 1"].waitForExistence(timeout: 10), "Choosing Need 1 did not update the filter line. \(app.debugDescription)")

        chooseAisle("Produce", in: app)
        XCTAssertTrue(app.staticTexts["Showing Need 1 · Produce"].waitForExistence(timeout: 10), "Choosing Produce did not update the filter line. \(app.debugDescription)")
        XCTAssertTrue(app.buttons["Show all"].isHittable)
        tapOnceItExists(app.buttons["Add from recipe"], named: "Add from recipe", in: app)
        app.terminate()

        app = launchShopping(
            variant: "normal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            noRecipes: true
        )
        XCTAssertTrue(app.buttons["Add a recipe"].waitForExistence(timeout: 8))
        app.buttons["Add a recipe"].tap()
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
        // The tile's one action; the composer above offers the same action as an icon.
        let addRecipe = app.buttons["Add a recipe"].firstMatch
        XCTAssertTrue(addRecipe.waitForExistence(timeout: 8))
        addRecipe.tap()
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
        // On a phone the actions menu lives in the navigation bar, and no search field sits over the list.
        XCTAssertTrue(app.buttons["Receipt actions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Receipt actions"].isHittable)
        XCTAssertFalse(app.searchFields["Search Spoonjoy"].exists)
        platformItem.tap()
        app.buttons["Add a recipe"].tap()
    }

    /// The search field belongs to the Search tab only: it is absent over the shopping list and present, and
    /// usable, once the Search tab is chosen.
    func testSearchFieldBelongsToTheSearchTabOnly() {
        ensurePortrait()
        let app = launchShopping(variant: "normal", platformFixture: true)
        XCTAssertTrue(app.descendants(matching: .any)["shopping.item.item_lemons"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.searchFields["Search Spoonjoy"].exists)

        let searchTab = app.tabBars.buttons["Search"].firstMatch
        XCTAssertTrue(searchTab.waitForExistence(timeout: 8), "The Search tab is missing. \(app.debugDescription)")
        searchTab.tap()
        let searchField = app.searchFields["Search Spoonjoy"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "The Search tab has no search field. \(app.debugDescription)")
        XCTAssertTrue(searchField.isHittable)
    }

    /// Waits for `element` to exist and be hittable and enabled: for menu items, confirmation buttons and a
    /// long-press target, which must be on screen and uncovered, not still behind a closing sheet, menu or
    /// the keyboard. Fails with the screen if it does not settle. Nothing is retried.
    ///
    /// The 10 seconds bound the element's state, not the accessibility queries that read it. On the hosted
    /// runner a single query of a popover over the shopping page took 7 to 9 seconds (runs 37366696305 and
    /// 37386300404: the popover and its button were on screen with valid frames when the snapshot was taken, and
    /// the whole 10 second window held one or two evaluations). A fixed `XCTWaiter` window therefore judged the
    /// button after one slow look. This loop keeps polling until the 10 seconds have passed and the button has
    /// been evaluated at least `minimumEvaluations` times; an element that never becomes hittable still fails.
    private func waitUntilHittable(
        _ element: XCUIElement,
        named name: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let minimumEvaluations = 3
        let deadline = Date().addingTimeInterval(10)
        var evaluations = 0
        var ready = false
        repeat {
            evaluations += 1
            if element.exists && element.isHittable && element.isEnabled {
                ready = true
                break
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline || evaluations < minimumEvaluations
        XCTAssertTrue(
            ready,
            "\(name) did not become hittable after \(evaluations) evaluations. \(app.debugDescription)",
            file: file,
            line: line
        )
    }

    /// Taps a button in the confirmation sheet. The sheet is presented after the menu or swipe action that
    /// opens it has closed, and on the hosted runner that takes well over 10 seconds. The wait for the sheet
    /// itself is therefore longer; the button must then be hittable by the rules of `waitUntilHittable`.
    /// Nothing is retried and a missing sheet still fails.
    private func tapConfirmation(
        _ title: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 45),
            "The confirmation sheet for \(title) never appeared. \(app.debugDescription)",
            file: file,
            line: line
        )
        tapWhenHittable(sheet.buttons[title], named: title, in: app, file: file, line: line)
    }

    /// Picks Need, Basket or All from the ⋯ menu's inline picker.
    private func chooseShoppingView(_ option: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tapOnceItExists(app.buttons["Receipt actions"], named: "Receipt actions", in: app, file: file, line: line)
        tapWhenHittable(app.buttons[option], named: "The menu's \(option) item", in: app, file: file, line: line)
    }

    /// Picks an aisle from the ⋯ menu's aisle submenu, whose label names the current aisle.
    private func chooseAisle(_ aisle: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tapOnceItExists(app.buttons["Receipt actions"], named: "Receipt actions", in: app, file: file, line: line)
        let submenu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Aisle: '")).firstMatch
        tapWhenHittable(submenu, named: "The menu's aisle submenu", in: app, file: file, line: line)
        tapWhenHittable(app.buttons[aisle], named: "The aisle menu's \(aisle) item", in: app, file: file, line: line)
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
        // NativeJourneyConsole: a blocked stderr write would stall the main thread XCUITest queries on.
        app.launchEnvironment["OS_ACTIVITY_DT_MODE"] = "NO"
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
