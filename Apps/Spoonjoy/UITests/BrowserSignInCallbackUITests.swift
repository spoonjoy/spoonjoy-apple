import XCTest

/// iOS 1.2 never got the https://spoonjoy.app/oauth/callback redirect back from ASWebAuthenticationSession, so every
/// Google and GitHub sign-in stopped in the sheet. This proves on a simulator that a Debug build signed with the app's
/// entitlements (webcredentials:spoonjoy.app) gets the callback back and lands signed in, on production.
///
/// The Browser sign-in callback workflow seeds a throwaway production account, writes its email, username and
/// password to a runner-local file named by `SPOONJOY_BROWSER_CALLBACK_ACCOUNT_FILE`, and deletes the account after
/// the run; every other run of this target skips the test. The launch sets `SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE`
/// (honoured in Debug builds only), so "Continue with Google" opens /oauth/authorize without the provider hint and
/// the sheet shows spoonjoy.app/login instead of Google. Everything after the web sign-in is the same for every
/// provider: first-party consent is skipped and the server redirects to the callback the sheet must hand back.
@MainActor
final class BrowserSignInCallbackUITests: XCTestCase {
    private struct Account: Decodable {
        let email: String
        let username: String
        let password: String
    }

    private static let fileVariable = "SPOONJOY_BROWSER_CALLBACK_ACCOUNT_FILE"
    private static let launchTimeout: TimeInterval = 30
    private static let networkTimeout: TimeInterval = 60
    private static let interactionTimeout: TimeInterval = 15

    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let webSheet = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 600
    }

    func testBrowserSignInCallbackReturnsToTheAppSignedIn() throws {
        guard let path = ProcessInfo.processInfo.environment[Self.fileVariable], !path.isEmpty else {
            throw XCTSkip("\(Self.fileVariable) is not set; only the Browser sign-in callback workflow runs this test.")
        }
        let account = try JSONDecoder().decode(Account.self, from: Data(contentsOf: URL(fileURLWithPath: path)))

        app = XCUIApplication()
        app.launchEnvironment["SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(element("native password sign-in").waitForExistence(timeout: Self.launchTimeout), "The signed-out screen did not appear after a fresh launch.")
        XCTAssertFalse(element("kitchen.root").exists, "The app was already signed in.")
        screenshot("00-signed-out")

        let google = element("native Google OAuth sign-in")
        XCTAssertTrue(google.waitForExistence(timeout: Self.interactionTimeout), "There is no Continue with Google button.")
        google.tap()

        // iOS asks before ASWebAuthenticationSession shares the browser's cookies with the app.
        let allow = springboard.buttons["Continue"]
        if allow.waitForExistence(timeout: Self.interactionTimeout) {
            screenshot("01-system-prompt")
            allow.tap()
        }

        let identifier = try XCTUnwrap(
            webElement(.textField, label: "Username or email", timeout: Self.networkTimeout),
            "The sheet did not show spoonjoy.app/login. Sheet: \(webSheet.debugDescription)"
        )
        screenshot("02-sheet-on-login")
        identifier.tap()
        identifier.typeText(account.username)

        // Pasted, not typed, so the password never appears in activity titles, the log or the result bundle.
        let password = try XCTUnwrap(webElement(.secureTextField, label: "Password"), "The login page has no Password field.")
        UIPasteboard.general.string = account.password
        defer { UIPasteboard.general.items = [] }
        password.tap()
        password.press(forDuration: 1.2)
        let paste = try XCTUnwrap(webElement(.menuItem, label: "Paste"), "The Paste action did not appear on the Password field.")
        paste.tap()
        UIPasteboard.general.items = []
        screenshot("03-sheet-filled")

        let logIn = try XCTUnwrap(webElement(.button, label: "Log in"), "The login page has no Log in button.")
        logIn.tap()

        // The proof: the server redirects to https://spoonjoy.app/oauth/callback, the sheet hands it to the app, the
        // app exchanges the code and opens the kitchen.
        XCTAssertTrue(
            element("kitchen.root").waitForExistence(timeout: Self.networkTimeout),
            "The app did not open the kitchen after the web sign-in. Status: \(element("native sign-in status").label). Screen: \(app.debugDescription)"
        )
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: Self.launchTimeout), "The app is not in the foreground after sign-in.")
        screenshot("04-signed-in-kitchen")

        let accountButton = element("kitchen.account")
        XCTAssertTrue(accountButton.waitForExistence(timeout: Self.interactionTimeout), "The kitchen has no account button.")
        accountButton.tap()
        let email = element("settings.profile.email")
        XCTAssertTrue(email.waitForExistence(timeout: Self.networkTimeout), "Settings shows no account email.")
        XCTAssertEqual(email.label, account.email, "The app is signed in as someone other than the throwaway account.")
        screenshot("05-settings-signed-in-as-throwaway")
        app.terminate()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }

    /// The sign-in sheet's web content is in the app's tree on some iOS versions and in SafariViewService's on others.
    /// Waits for the element in either tree; nil when neither shows it in time.
    private func webElement(_ type: XCUIElement.ElementType, label: String, timeout: TimeInterval = BrowserSignInCallbackUITests.interactionTimeout) -> XCUIElement? {
        let predicate = NSPredicate(format: "label == %@ OR placeholderValue == %@", label, label)
        let candidates = [app, webSheet].map { $0.descendants(matching: type).matching(predicate).firstMatch }
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let found = candidates.first(where: \.exists) { return found }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        return nil
    }

    /// The whole screen, so the system prompt and the sign-in sheet show too.
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
