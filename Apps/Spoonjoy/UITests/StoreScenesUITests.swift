import UIKit
import XCTest

/// Photographs the App Store scenes (distribution/app-store/frames/spec.json) in the real App Store build, signed in
/// as the App Review demo account on production. That kitchen is seeded from distribution/app-store/review-demo-kitchen.json,
/// so the same commit always shows the same recipes, covers, cookbooks and list. The Store scenes workflow sets the
/// status bar to 9:41 with full bars and battery, the locale to en_US and the appearance before each run, then
/// turns the attachments into raw scenes that scripts/store-frames/render.mjs frames.
///
/// Only that workflow runs it, with `SPOONJOY_STORE_SCENES_FILE` naming a runner-local file that holds the demo
/// sign-in and the scenes to take; every other run of this target skips it. The only thing it changes is cook
/// progress on the cook-mode recipe, which it resets to the seed (none) before and after that scene, the last one.
@MainActor
final class StoreScenesUITests: XCTestCase {
    private struct Request: Decodable {
        let username: String
        let password: String
        /// Scene names from spec.json, in the order to take them. Unknown names fail the run.
        let scenes: [String]
        /// "landscape" turns the device on its side before the first scene (the iPad set); anything else is portrait.
        let orientation: String?
    }

    private static let fileVariable = "SPOONJOY_STORE_SCENES_FILE"
    private static let networkTimeout: TimeInterval = 45
    /// Long enough for covers to fade in and for scroll indicators and transitions to finish.
    private static let settle: TimeInterval = 6

    /// Every scene the test knows. A scene ending in -dark is the same screen, taken in the dark appearance run.
    static let known = ["kitchen", "recipes", "recipe-detail", "recipe-cooks", "cookbooks", "cookbook-detail", "shopping-list", "cook-mode"]
    private static let forkTitle = "Brown Butter Apple Crumble, with pecans"
    private static let cookTitle = "Honeycrisp Galette"
    private static let cookbookTitle = "The Orchard"
    /// The first item on the demo kitchen's seeded shopping list, so the shot waits for the list itself, not its tab.
    private static let shoppingItem = "Honeycrisp apples"

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

        XCUIDevice.shared.orientation = request.orientation == "landscape" ? .landscapeLeft : .portrait
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        shell = ShellNavigationDriver(app: app)
        signInIfNeeded(as: request.username, password: request.password)
        clearCookingNow()

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
            // Cooking now comes from the server after the kitchen appears, so give it time to show before ruling it out.
            XCTAssertFalse(element("kitchen.cookingNow").waitForExistence(timeout: 8),
                           "The demo kitchen still shows Cooking now after the run cleared every cook it found.")
        case "recipes":
            shell.go(to: .recipes)
            XCTAssertTrue(recipeRow(Self.forkTitle).waitForExistence(timeout: Self.networkTimeout), "Recipes does not list \(Self.forkTitle).")
        case "recipe-detail":
            openRecipe(Self.forkTitle)
        case "recipe-cooks":
            // The cook-mode recipe carries the friend's cook note, so its Cooks section shows someone else's cook.
            openRecipe(Self.cookTitle)
            scrollToCooks()
        case "cookbooks":
            shell.go(to: .cookbooks)
            XCTAssertTrue(element("cookbookShelf").waitForExistence(timeout: Self.networkTimeout), "The cookbook shelf did not open.")
        case "cookbook-detail":
            shell.go(to: .cookbooks)
            let row = shell.element("cookbookShelf").buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.cookbookTitle)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: Self.networkTimeout), "The shelf does not list \(Self.cookbookTitle).")
            row.tap()
            XCTAssertTrue(element("CookbookDetailHero").waitForExistence(timeout: Self.networkTimeout), "\(Self.cookbookTitle) did not open.")
        case "shopping-list":
            shell.go(to: .shopping)
            let item = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", Self.shoppingItem)).firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: Self.networkTimeout), "The shopping list does not show \(Self.shoppingItem).")
        case "cook-mode":
            openRecipe(Self.cookTitle)
            // Clear progress a reviewer may have left, so the step shows unchecked.
            let clear = element("recipeDetail.clearProgress")
            if clear.waitForExistence(timeout: 5), clear.isHittable {
                clear.tap()
            }
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
        // Always PNG: the exporter and the renderer read nothing else, whatever Xcode's default encoding becomes.
        let attachment = XCTAttachment(data: Self.uprightPNG(XCUIScreen.main.screenshot()), uniformTypeIdentifier: "public.png")
        attachment.name = "scene-\(scene)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A landscape screenshot holds portrait pixels plus an orientation flag, and its PNG keeps the portrait pixels;
    /// drawing the image applies the flag, so the scene comes out the way the device was held.
    private static func uprightPNG(_ screenshot: XCUIScreenshot) -> Data {
        let image = screenshot.image
        guard image.imageOrientation != .up else { return screenshot.pngRepresentation }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Cook progress left by an earlier run or by App Review puts Cooking now on the kitchen, which every scene would
    /// show. Each cook it lists is cleared on its recipe page (closing cook mode from the kitchen returns to the
    /// kitchen, where there is nothing to clear), until none is left.
    private func clearCookingNow() {
        for _ in 0..<4 {
            shell.go(to: .kitchen)
            guard element("kitchen.root").waitForExistence(timeout: Self.networkTimeout) else { return }
            let card = element("kitchen.cookingNow.card")
            guard card.waitForExistence(timeout: 8) else { return }
            // The card reads "<title>, <progress>"; titles may hold commas, the progress line does not.
            let label = card.label
            guard let comma = label.range(of: ", ", options: .backwards) else { return }
            openRecipe(String(label[..<comma.lowerBound]))
            let clear = element("recipeDetail.clearProgress")
            for _ in 0..<10 where !(clear.exists && clear.isHittable) {
                app.swipeUp()
            }
            guard clear.exists, clear.isHittable else { return }
            clear.tap()
        }
    }

    /// Scrolls the open recipe until its Cooks heading sits in the top half of the screen.
    private func scrollToCooks() {
        let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", "Cooks")).firstMatch
        let window = app.windows.firstMatch
        for _ in 0..<12 {
            if heading.exists, heading.isHittable, heading.frame.minY < window.frame.height * 0.45 { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(heading.exists && heading.isHittable, "\(Self.cookTitle) shows no Cooks section. Screen: \(app.debugDescription)")
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
        // The list loads from the network, then the row may sit below the fold of a long recipe box.
        _ = row.waitForExistence(timeout: Self.networkTimeout)
        for _ in 0..<8 where !(row.exists && row.isHittable) {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(row.exists && row.isHittable, "No recipe row shows \(title). Screen: \(app.debugDescription)")
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
        // iOS may offer to save the password a little after the kitchen opens; a screenshot would show the alert.
        let notNow = app.alerts["Save Password?"].buttons["Not Now"]
        if notNow.waitForExistence(timeout: 8) {
            notNow.tap()
        }
    }
}
