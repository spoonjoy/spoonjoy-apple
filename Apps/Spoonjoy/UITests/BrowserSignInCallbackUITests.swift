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
        // iOS asks before ASWebAuthenticationSession shares the browser's cookies with the app. SpringBoard hosts the
        // alert on some iOS versions and the app on others.
        let prompts = [springboard.buttons["Continue"], app.alerts.buttons["Continue"]]
        // One tap only. After the workflow's reinstall, iOS often ends the first session itself (canceledLogin, code 1,
        // before any prompt) while swcd re-fetches spoonjoy.app's association (spoonjoy-apple#320). The app now starts
        // one fresh session after such an early cancel (SpoonjoyWebAuthenticationSession), and this test proves that: the
        // prompt must appear from this single tap. The app's log in the run's swc.log shows whether the retry fired.
        google.tap()
        // The app registers its client over the network before the session starts, so the prompt can be slow.
        let promptDeadline = Date().addingTimeInterval(Self.networkTimeout)
        while Date() < promptDeadline, !prompts.contains(where: \.exists) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        let allow = try XCTUnwrap(
            prompts.first(where: \.exists),
            "No sign-in prompt after one tap. App status: \(element("native sign-in status").label)"
        )
        screenshot("01-system-prompt")
        allow.tap()

        let identifier = try XCTUnwrap(
            webElement(.textField, label: "Username or email", timeout: Self.networkTimeout),
            "The sheet did not show spoonjoy.app/login. App status: \(element("native sign-in status").label). Sheet: \(webSheet.debugDescription)"
        )
        screenshot("02-sheet-on-login")
        identifier.tap()
        identifier.typeText(account.username)
        XCTAssertEqual(identifier.value as? String, account.username, "The username did not land in the Username or email field as typed.")

        // Tab moves focus to Password inside the page. A tap is not used: while the page scrolls above the keyboard,
        // the field's reported frame lags, and in run 43181444584 the tap landed on the keyboard instead.
        let password = try XCTUnwrap(webElement(.secureTextField, label: "Password"), "The login page has no Password field.")
        identifier.typeText("\t")
        // Web fields in the sheet do not report hasKeyboardFocus (run 43186142426: Tab moved the caret, the check failed),
        // so the paste below is checked by the field's value instead. Nor is isHittable a gate: in run 43196617025 the
        // field was focused and on screen and still reported false. A short pause lets focus settle before the paste.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertEqual(identifier.value as? String, account.username, "The username changed while moving to the Password field.")
        // A fresh simulator shows the keyboard's slide-to-type tip over the keys on first use (run 43214650507).
        dismissKeyboardTip()

        // Typed. Pasting failed twice: Command-V does nothing without a hardware keyboard (run 43214650507), and a
        // secure web field offers no Paste menu (run 43226406912), while the keyboard shows pasteboard text on screen.
        // The workflow masks the password in the job log and redacts it from every file before the upload.
        let existing = (password.value as? String).map { $0 == "Password" ? 0 : $0.count } ?? 0
        if existing > 0 {
            password.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing))
        }
        password.typeText(account.password)
        // A secure field shows its last character for a moment; wait it out before the screenshot.
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        let typedValue = (password.value as? String) ?? ""
        XCTAssertEqual(typedValue.count, account.password.count, "The Password field does not hold exactly the password's length.")
        screenshot("03-sheet-filled")

        let logIn = try XCTUnwrap(webElement(.button, label: "Log in"), "The login page has no Log in button.")
        logIn.tap()

        // The proof: the server redirects to https://spoonjoy.app/oauth/callback, the sheet hands it to the app, the
        // app exchanges the code and opens the kitchen. With the webcredentials association in place, iOS may first
        // offer to save the password (run 43260720667), and the sheet waits until that alert is answered.
        XCTAssertTrue(
            waitForKitchenAnsweringSavePassword(),
            "The app did not open the kitchen after the web sign-in. Status: \(element("native sign-in status").label). Screen: \(app.debugDescription)"
        )
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: Self.launchTimeout), "The app is not in the foreground after sign-in.")
        screenshot("04-signed-in-kitchen")

        let accountButton = element("kitchen.account")
        XCTAssertTrue(accountButton.waitForExistence(timeout: Self.interactionTimeout), "The kitchen has no account button.")
        accountButton.tap()
        let email = element("settings.profile.email")
        XCTAssertTrue(email.waitForExistence(timeout: Self.networkTimeout), "Settings shows no account email.")
        XCTAssertTrue(email.label == account.email || email.label.hasSuffix(" \(account.email)"), "The app is signed in as someone other than the throwaway account: \(email.label)")
        screenshot("05-settings-signed-in-as-throwaway")
        app.terminate()
    }

    /// Waits for the kitchen, answering "Not Now" if iOS offers to save the password; true once the kitchen shows.
    private func waitForKitchenAnsweringSavePassword() -> Bool {
        let kitchen = element("kitchen.root")
        let deadline = Date().addingTimeInterval(Self.networkTimeout)
        var answered = false
        var captured = false
        repeat {
            if kitchen.exists { return true }
            if !answered {
                for owner: XCUIApplication in [app!, webSheet, springboard] {
                    let alert = owner.alerts["Save Password?"]
                    guard alert.exists else { continue }
                    if !captured {
                        screenshot("03b-save-password-offered")
                        captured = true
                    }
                    // The alert can close by itself when the callback arrives first (run 43274026769), and a failed
                    // element tap ends the test even inside XCTExpectFailure (run 43282912644). So the button is read
                    // from a snapshot, which throws instead of failing, and tapped by its screen point.
                    if !kitchen.exists,
                       let snapshot = try? alert.snapshot(),
                       let notNow = snapshot.children.flatMap(Self.flatten).first(where: { $0.elementType == .button && $0.label == "Not Now" }) {
                        owner.coordinate(withNormalizedOffset: .zero)
                            .withOffset(CGVector(dx: notNow.frame.midX, dy: notNow.frame.midY))
                            .tap()
                        answered = true
                    }
                    break
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        return kitchen.exists
    }

    private static func flatten(_ snapshot: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
        [snapshot] + snapshot.children.flatMap(flatten)
    }

    private func dismissKeyboardTip() {
        for owner: XCUIApplication in [webSheet, app!] {
            let tip = owner.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Speed up your typing")).firstMatch
            guard tip.exists else { continue }
            let continueButton = owner.buttons.matching(NSPredicate(format: "label == %@", "Continue")).allElementsBoundByIndex.last
            continueButton?.tap()
            _ = tip.waitForNonExistence(timeout: Self.interactionTimeout)
            return
        }
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }

    /// The sign-in sheet's web content is in the app's tree on some iOS versions and in SafariViewService's on others.
    /// Waits for the element in either tree; nil when neither shows it in time.
    private func webElement(_ type: XCUIElement.ElementType, label: String, timeout: TimeInterval = BrowserSignInCallbackUITests.interactionTimeout) -> XCUIElement? {
        // The app's own sign-in form uses the same placeholders, under identifiers that start with "native"; in run
        // 43232570879 the password went to the app's field instead of the page's.
        let predicate = NSPredicate(
            format: "(label == %@ OR placeholderValue == %@) AND NOT (identifier BEGINSWITH %@)", label, label, "native"
        )
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
