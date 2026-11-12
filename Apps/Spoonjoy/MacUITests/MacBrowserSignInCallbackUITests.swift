import XCTest

/// The Mac counterpart of BrowserSignInCallbackUITests: proves that a Developer ID-signed Debug build with the app's
/// entitlements (webcredentials:spoonjoy.app) gets https://spoonjoy.app/oauth/callback back from
/// ASWebAuthenticationSession after one click and lands signed in, on production, with the early-cancel gate
/// (macOS sheet and key-window signals) in place.
///
/// The Mac browser sign-in callback workflow seeds a throwaway production account, writes its email, username and
/// password to a runner-local file named by `SPOONJOY_BROWSER_CALLBACK_ACCOUNT_FILE`, and deletes the account after the
/// run; every other run skips the test. `SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE` (Debug only) drops the provider
/// hint, so the sheet shows spoonjoy.app/login.
@MainActor
final class MacBrowserSignInCallbackUITests: XCTestCase {
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

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 600
    }

    func testBrowserSignInCallbackReturnsToTheMacAppSignedIn() throws {
        guard let path = ProcessInfo.processInfo.environment[Self.fileVariable], !path.isEmpty else {
            throw XCTSkip("\(Self.fileVariable) is not set; only the Mac browser sign-in callback workflow runs this test.")
        }
        let account = try JSONDecoder().decode(Account.self, from: Data(contentsOf: URL(fileURLWithPath: path)))

        app = XCUIApplication()
        app.launchEnvironment["SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(element("native password sign-in").waitForExistence(timeout: Self.launchTimeout), "The signed-out window did not appear after a fresh launch.")
        XCTAssertFalse(element("kitchen.root").exists, "The app was already signed in.")
        screenshot("00-signed-out")

        let google = element("native Google OAuth sign-in")
        XCTAssertTrue(google.waitForExistence(timeout: Self.interactionTimeout), "There is no Continue with Google button.")
        // One click only: the app's own early-cancel retry covers a session the system ends before anything shows.
        google.click()

        // macOS asks before the session shares the browser's cookies, in a sheet on the app's window.
        let allow = try XCTUnwrap(
            webElement(.button, label: "Continue", timeout: Self.networkTimeout),
            "No sign-in prompt after one click. App status: \(element("native sign-in status").label). Window: \(app.debugDescription)"
        )
        screenshot("01-system-prompt")
        allow.click()

        let identifier = try XCTUnwrap(
            webElement(.textField, label: "Username or email", timeout: Self.networkTimeout),
            "The sheet did not show spoonjoy.app/login. App status: \(element("native sign-in status").label). Window: \(app.debugDescription)"
        )
        screenshot("02-sheet-on-login")
        identifier.click()
        identifier.typeText(account.username)
        XCTAssertEqual(identifier.value as? String, account.username, "The username did not land in the Username or email field as typed.")

        let password = try XCTUnwrap(webElement(.secureTextField, label: "Password"), "The login page has no Password field.")
        password.click()
        password.typeText(account.password)
        let typedValue = (password.value as? String) ?? ""
        XCTAssertEqual(typedValue.count, account.password.count, "The Password field does not hold exactly the password's length.")
        screenshot("03-sheet-filled")

        let logIn = try XCTUnwrap(webElement(.button, label: "Log in"), "The login page has no Log in button.")
        logIn.click()

        XCTAssertTrue(
            waitForKitchenAnsweringSavePassword(),
            "The app did not open the kitchen after the web sign-in. Status: \(element("native sign-in status").label). Window: \(app.debugDescription)"
        )
        screenshot("04-signed-in-kitchen")

        // The Mac app opens Settings from the app menu (Settings…, Command-comma); the kitchen toolbar has no account button.
        app.typeKey(",", modifierFlags: .command)
        let email = element("settings.profile.email")
        XCTAssertTrue(email.waitForExistence(timeout: Self.networkTimeout), "Settings shows no account email.")
        XCTAssertTrue(email.label == account.email || email.label.hasSuffix(" \(account.email)"), "The app is signed in as someone other than the throwaway account: \(email.label)")
        screenshot("05-settings-signed-in-as-throwaway")
        app.terminate()
    }

    /// Waits for the kitchen, clicking "Not Now" if macOS offers to save the password; true once the kitchen shows.
    private func waitForKitchenAnsweringSavePassword() -> Bool {
        let kitchen = element("kitchen.root")
        let notNow = app.descendants(matching: .button).matching(NSPredicate(format: "label == %@", "Not Now")).firstMatch
        let deadline = Date().addingTimeInterval(Self.networkTimeout)
        var answered = false
        repeat {
            if kitchen.exists { return true }
            // Read from a snapshot, which throws instead of failing when the prompt closes first.
            if !answered, let snapshot = try? notNow.snapshot() {
                screenshot("03b-save-password-offered")
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: snapshot.frame.midX - app.frame.minX, dy: snapshot.frame.midY - app.frame.minY))
                    .click()
                answered = true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        return kitchen.exists
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }

    /// An element in the sign-in sheet; the app's own sign-in form, whose identifiers start with "native", never matches.
    private func webElement(_ type: XCUIElement.ElementType, label: String, timeout: TimeInterval = MacBrowserSignInCallbackUITests.interactionTimeout) -> XCUIElement? {
        let predicate = NSPredicate(
            format: "(label == %@ OR placeholderValue == %@ OR title == %@) AND NOT (identifier BEGINSWITH %@)", label, label, label, "native"
        )
        let candidate = app.descendants(matching: type).matching(predicate).firstMatch
        return candidate.waitForExistence(timeout: timeout) ? candidate : nil
    }

    /// The whole screen, so the prompt and the sheet show too.
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
