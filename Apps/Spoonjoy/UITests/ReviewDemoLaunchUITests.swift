import XCTest

/// App Review rejected 1.0 because "the app crashed after the initial launch". The reviewer signs in with the
/// review demo account, whose seeded kitchen (distribution/app-store/review-demo-kitchen.json) is unlike any QA
/// account. This signs the App Store configuration in as that account on production, relaunches, and opens every
/// seeded recipe and cookbook without changing anything.
///
/// Only the Review demo launch workflow runs it, with `SPOONJOY_REVIEW_DEMO_LAUNCH_FILE` naming the runner-local
/// file it writes; every other run of this target skips it.
@MainActor
final class ReviewDemoLaunchUITests: XCTestCase {
    private struct Kitchen: Decodable {
        let username: String
        let password: String
        let recipes: [String]
        let cookbooks: [String]
    }

    private static let fileVariable = "SPOONJOY_REVIEW_DEMO_LAUNCH_FILE"
    private static let networkTimeout: TimeInterval = 45
    private static let interactionTimeout: TimeInterval = 10

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 900
    }

    func testReviewDemoKitchenSurvivesSignInAndRelaunch() throws {
        guard let path = ProcessInfo.processInfo.environment[Self.fileVariable], !path.isEmpty else {
            throw XCTSkip("\(Self.fileVariable) is not set; only the Review demo launch workflow runs this test.")
        }
        let kitchen = try JSONDecoder().decode(Kitchen.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertFalse(kitchen.recipes.isEmpty, "The demo kitchen file names no recipes.")
        XCTAssertFalse(kitchen.cookbooks.isEmpty, "The demo kitchen file names no cookbooks.")

        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(element("native password sign-in").waitForExistence(timeout: 30), "The signed-out screen did not appear after a fresh launch.")
        screenshot("00-signed-out")

        signIn(as: kitchen.username, password: kitchen.password)
        assertKitchen("Signing in as the review demo account did not open the kitchen.")
        screenshot("01-kitchen-after-sign-in")

        relaunch()
        assertKitchen("The kitchen did not come back after a relaunch.")
        screenshot("02-kitchen-after-relaunch")

        openTab("Recipes")
        for (index, title) in kitchen.recipes.enumerated() {
            let row = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "recipes.row", title)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: Self.networkTimeout), "No recipe row shows \(title). Screen: \(app.debugDescription)")
            row.tap()
            XCTAssertTrue(element("recipeDetail.title").waitForExistence(timeout: Self.networkTimeout), "The \(title) recipe did not open.")
            app.swipeUp()
            screenshot("10-recipe-\(index)")
            goBack()
        }

        openTab("Cookbooks")
        for (index, title) in kitchen.cookbooks.enumerated() {
            let shelfRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
            XCTAssertTrue(shelfRow.waitForExistence(timeout: Self.networkTimeout), "The Cookbooks shelf does not list \(title).")
            shelfRow.tap()
            let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", title)).firstMatch
            XCTAssertTrue(heading.waitForExistence(timeout: Self.networkTimeout), "The \(title) cookbook did not open.")
            app.swipeUp()
            screenshot("20-cookbook-\(index)")
            goBack()
        }

        openTab("Kitchen")
        relaunch()
        assertKitchen("The kitchen did not come back after the second relaunch.")
        screenshot("30-kitchen-after-second-relaunch")
        app.terminate()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }

    private func assertKitchen(_ message: String) {
        XCTAssertTrue(element("kitchen.root").waitForExistence(timeout: Self.networkTimeout), message)
    }

    /// Types the username and pastes the password, so the password never appears in activity titles, the
    /// xcodebuild log or the result bundle.
    private func signIn(as username: String, password: String) {
        let identifier = element("native sign-in email or username")
        XCTAssertTrue(identifier.waitForExistence(timeout: Self.interactionTimeout), "The email or username field is missing.")
        identifier.tap()
        identifier.typeText(username)

        let passwordField = element("native sign-in password")
        XCTAssertTrue(passwordField.waitForExistence(timeout: Self.interactionTimeout), "The password field is missing.")
        UIPasteboard.general.string = password
        defer { UIPasteboard.general.items = [] }
        passwordField.tap()
        passwordField.press(forDuration: 1.2)
        let paste = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Paste")).firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: Self.interactionTimeout), "The Paste action did not appear on the password field.")
        paste.tap()
        element("native password sign-in").tap()
    }

    private func relaunch() {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "The app did not come back to the foreground after a relaunch.")
    }

    /// Tab items carry no identifiers; a minimized tab bar shows only the selected tab until it is tapped.
    private func openTab(_ title: String) {
        let buttons = app.tabBars.buttons
        XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 30), "The tab bar is missing.")
        let collapsed = buttons.matching(NSPredicate(format: "value == %@", "Collapsed")).firstMatch
        if collapsed.exists {
            collapsed.tap()
        }
        let tab = buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "The \(title) tab is missing.")
        tab.tap()
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: Self.interactionTimeout), "There is no back button.")
        back.tap()
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
