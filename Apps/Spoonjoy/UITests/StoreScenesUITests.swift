import XCTest

/// Photographs the App Store scenes (distribution/app-store/frames/spec.json) in the real App Store build, signed in
/// as the App Review demo account on production. That kitchen is seeded from distribution/app-store/review-demo-kitchen.json,
/// so the same commit always shows the same recipes, covers, cookbooks and list. The Store scenes workflow sets the
/// status bar to 9:41 with full bars and battery, the locale to en_US and the appearance before each run, then
/// turns the attachments into raw scenes that scripts/store-frames/render.mjs frames.
///
/// Only that workflow runs it, with `SPOONJOY_STORE_SCENES_FILE` naming a runner-local file that holds the demo
/// sign-in and the scenes to take; every other run of this target skips it. It changes nothing it does not put back:
/// cook mode is the last scene and its progress is cleared after.
@MainActor
final class StoreScenesUITests: XCTestCase {
    private struct Request: Decodable {
        let username: String
        let password: String
        /// Scene names from spec.json, in the order to take them. Unknown names fail the run.
        let scenes: [String]
    }

    private static let fileVariable = "SPOONJOY_STORE_SCENES_FILE"
    private static let networkTimeout: TimeInterval = 45
    /// Long enough for covers to fade in and for scroll indicators and transitions to finish.
    private static let settle: TimeInterval = 4

    /// Every scene the test knows. A scene ending in -dark is the same screen, taken in the dark appearance run.
    static let known = ["kitchen", "recipes", "recipe-detail", "cookbooks", "cookbook-detail", "shopping-list", "cook-mode"]
    private static let forkTitle = "Brown Butter Apple Crumble, with pecans"
    private static let cookTitle = "Honeycrisp Galette"
    private static let cookbookTitle = "The Orchard"

    private var app: XCUIApplication!
    private var shell: ShellNavigationDriver!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 900
    }

    func testStoreScenes() throws {
        guard let path = ProcessInfo.processInfo.environment[Self.fileVariable], !path.isEmpty else {
            throw XCTSkip("\(Self.fileVariable) is not set; only the Store scenes workflow runs this test.")
        }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let unknown = request.scenes.map(Self.screen).filter { !Self.known.contains($0) }
        XCTAssertTrue(unknown.isEmpty, "Unknown scenes \(unknown); StoreScenesUITests knows \(Self.known).")
        XCTAssertFalse(request.scenes.isEmpty, "The request names no scenes.")
        // Cook mode leaves the recipe open on its page and may leave progress, so it is always taken last.
        let cookLast = request.scenes.filter { Self.screen($0) != "cook-mode" } + request.scenes.filter { Self.screen($0) == "cook-mode" }

        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        shell = ShellNavigationDriver(app: app)
        signInIfNeeded(as: request.username, password: request.password)

        for scene in cookLast {
            take(scene)
        }
        app.terminate()
    }

    /// "cook-mode-dark" is the cook-mode screen; the run's appearance makes it dark.
    private static func screen(_ scene: String) -> String {
        scene.hasSuffix("-dark") ? String(scene.dropLast("-dark".count)) : scene
    }

    private func take(_ scene: String) {
        switch Self.screen(scene) {
        case "kitchen":
            shell.go(to: .kitchen)
            XCTAssertTrue(element("kitchen.root").waitForExistence(timeout: Self.networkTimeout), "The kitchen did not open.")
            XCTAssertFalse(element("kitchen.cookingNow").exists,
                           "The demo kitchen shows Cooking now, so an earlier run left cook progress; clear it on spoonjoy.app.")
        case "recipes":
            shell.go(to: .recipes)
            XCTAssertTrue(recipeRow(Self.forkTitle).waitForExistence(timeout: Self.networkTimeout), "Recipes does not list \(Self.forkTitle).")
        case "recipe-detail":
            openRecipe(Self.forkTitle)
        case "cookbooks":
            shell.go(to: .cookbooks)
            XCTAssertTrue(element("cookbookShelf").waitForExistence(timeout: Self.networkTimeout), "The cookbook shelf did not open.")
        case "cookbook-detail":
            shell.go(to: .cookbooks)
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", Self.cookbookTitle)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: Self.networkTimeout), "The shelf does not list \(Self.cookbookTitle).")
            row.tap()
            XCTAssertTrue(element("CookbookDetailHero").waitForExistence(timeout: Self.networkTimeout), "\(Self.cookbookTitle) did not open.")
        case "shopping-list":
            shell.go(to: .shopping)
            XCTAssertTrue(shell.text("Shopping").waitForExistence(timeout: Self.networkTimeout) || shell.text("Shopping List").exists,
                          "The shopping list did not open.")
        case "cook-mode":
            openRecipe(Self.cookTitle)
            let cook = element("recipeDetail.cook")
            XCTAssertTrue(cook.waitForExistence(timeout: Self.networkTimeout), "\(Self.cookTitle) has no Cook button.")
            cook.tap()
            XCTAssertTrue(element("cook.page").waitForExistence(timeout: Self.networkTimeout), "Cook mode did not open.")
            settleAndShoot(scene)
            closeCookMode()
            return
        default:
            return
        }
        settleAndShoot(scene)
    }

    private func settleAndShoot(_ scene: String) {
        // Idle, then take the shot: nothing is mid-animation and every cover has loaded.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: Self.settle)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "scene-\(scene)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func closeCookMode() {
        let close = element("cook.close").exists ? element("cook.close") : element("cookSpread.close")
        if close.waitForExistence(timeout: 10) {
            close.tap()
        }
        let clear = element("recipeDetail.clearProgress")
        if clear.waitForExistence(timeout: 5), clear.isHittable {
            clear.tap()
        }
    }

    private func openRecipe(_ title: String) {
        shell.go(to: .recipes)
        let row = recipeRow(title)
        XCTAssertTrue(row.waitForExistence(timeout: Self.networkTimeout), "No recipe row shows \(title). Screen: \(app.debugDescription)")
        row.tap()
        XCTAssertTrue(element("recipeDetail.title").waitForExistence(timeout: Self.networkTimeout), "The \(title) recipe did not open.")
    }

    private func recipeRow(_ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "recipes.row", title)).firstMatch
    }

    private func element(_ id: String) -> XCUIElement {
        shell.element(id)
    }

    /// Types the username and pastes the password, so the password never appears in activity titles, the xcodebuild
    /// log or the result bundle. A second run on the same simulator (the dark appearance) is already signed in.
    private func signInIfNeeded(as username: String, password: String) {
        let signIn = element("native password sign-in")
        let kitchen = element("kitchen.root")
        _ = shell.waitUntil(30) { signIn.exists || kitchen.exists }
        guard signIn.exists else { return }
        let identifier = element("native sign-in email or username")
        XCTAssertTrue(identifier.waitForExistence(timeout: 10), "The email or username field is missing.")
        identifier.tap()
        identifier.typeText(username)
        let passwordField = element("native sign-in password")
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "The password field is missing.")
        UIPasteboard.general.string = password
        defer { UIPasteboard.general.items = [] }
        passwordField.tap()
        passwordField.press(forDuration: 1.2)
        let paste = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Paste")).firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 10), "The Paste action did not appear on the password field.")
        paste.tap()
        signIn.tap()
        XCTAssertTrue(kitchen.waitForExistence(timeout: Self.networkTimeout), "Signing in as the review demo account did not open the kitchen.")
    }
}
