import SpoonjoyCore
import UIKit
import XCTest

/// Drives the Spoonjoy iOS app for journeys. Every query goes through an accessibility identifier
/// (`JourneyID`) or asserted copy (`JourneyCopy`).
@MainActor
final class JourneyApp {
    static let launchTimeout: TimeInterval = 30
    static let networkTimeout: TimeInterval = 45
    static let interactionTimeout: TimeInterval = 10

    let app: XCUIApplication

    private init(app: XCUIApplication) {
        self.app = app
    }

    /// Launches the app with its on-disk state cleared and pointed at the QA mirror, waits for the
    /// signed-out screen, then proves through Settings that the build honours the QA base URL.
    /// With `continueAfterFailure = false` a build that would talk to production stops here,
    /// before any sign-in.
    static func launchFresh(file: StaticString = #filePath, line: UInt = #line) -> JourneyApp {
        let app = XCUIApplication()
        app.launchEnvironment["SPOONJOY_API_BASE_URL"] = JourneyQA.baseURL.absoluteString
        app.launchEnvironment[NativeJourneyLaunchReset.environmentKey] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let journey = JourneyApp(app: app)
        journey.waitFor(JourneyID.passwordSignIn, timeout: launchTimeout, "The signed-out screen did not appear after a fresh launch.", file: file, line: line)
        journey.tap(JourneyID.signInSettings, file: file, line: line)
        journey.assertQAEnvironment(file: file, line: line)
        journey.closeSettings(file: file, line: line)
        journey.waitFor(JourneyID.passwordSignIn, timeout: launchTimeout, "Closing Settings did not return to the sign-in screen.", file: file, line: line)
        return journey
    }

    /// Terminates the app and launches it again without clearing its state.
    func relaunch() {
        app.terminate()
        app.launchEnvironment.removeValue(forKey: NativeJourneyLaunchReset.environmentKey)
        app.launch()
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func element(_ id: String, labelContaining text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", id, text))
            .firstMatch
    }

    /// Finds user-visible copy the journey asserts. Only for `JourneyCopy` values.
    func copy(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// Signs in with the native password form. The password is pasted, never typed, so it cannot
    /// appear in XCUITest activity titles, the xcodebuild log or the result bundle.
    func signIn(as identifier: String, password: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = element(JourneyID.signInIdentifier)
        waitFor(JourneyID.signInIdentifier, timeout: Self.interactionTimeout, "The email or username field is missing.", file: file, line: line)
        field.tap()
        let current = field.value as? String ?? ""
        let existing = current == field.placeholderValue ? "" : current
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + identifier)

        pastePassword(password, file: file, line: line)
        tap(JourneyID.passwordSignIn, file: file, line: line)
    }

    /// Opens Settings from the signed-in shell's "More" menu.
    func openSettings(file: StaticString = #filePath, line: UInt = #line) {
        tap(JourneyID.shellMore, file: file, line: line)
        tap(JourneyID.shellMoreSettings, file: file, line: line)
    }

    /// Leaves the standalone (signed-out) Settings screen through its "Kitchen" button.
    func closeSettings(file: StaticString = #filePath, line: UInt = #line) {
        tap(JourneyID.settingsClose, file: file, line: line)
    }

    /// Signs out from Settings. Sign Out revokes the local session and then hands off to the web
    /// sign-out page in Safari, so this waits for Safari and brings the app back.
    func signOut(file: StaticString = #filePath, line: UInt = #line) {
        tap(JourneyID.settingsSignOut, file: file, line: line)
        let confirm = app.buttons
            .matching(NSPredicate(format: "label == %@ AND identifier != %@", JourneyCopy.signOutConfirm, JourneyID.settingsSignOut))
            .firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: Self.interactionTimeout), "The sign-out confirmation did not appear.", file: file, line: line)
        confirm.tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(
            safari.wait(for: .runningForeground, timeout: Self.launchTimeout),
            "Sign Out did not hand off to the web sign-out page.",
            file: file,
            line: line
        )
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: Self.launchTimeout), "The app did not come back after the web sign-out handoff.", file: file, line: line)
    }

    /// Asserts the visible Settings screen's Environment row names the QA mirror.
    func assertQAEnvironment(file: StaticString = #filePath, line: UInt = #line) {
        let value = element(JourneyID.settingsEnvironmentValue)
        XCTAssertTrue(value.waitForExistence(timeout: Self.launchTimeout), "Settings has no Environment row.", file: file, line: line)
        XCTAssertEqual(
            value.label,
            JourneyQA.expectedEnvironmentValue,
            "The app is not pointed at the QA mirror; stopping before any sign-in.",
            file: file,
            line: line
        )
    }

    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id, timeout: Self.launchTimeout, "\(id) did not appear.", file: file, line: line)
        element(id).tap()
    }

    private func waitFor(_ id: String, timeout: TimeInterval, _ message: String, file: StaticString, line: UInt) {
        XCTAssertTrue(element(id).waitForExistence(timeout: timeout), message, file: file, line: line)
    }

    private func pastePassword(_ password: String, file: StaticString, line: UInt) {
        let field = element(JourneyID.signInPassword)
        waitFor(JourneyID.signInPassword, timeout: Self.interactionTimeout, "The password field is missing.", file: file, line: line)
        UIPasteboard.general.string = password
        defer { UIPasteboard.general.items = [] }
        field.tap()
        field.press(forDuration: 1.2)
        let paste = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Paste")).firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: Self.interactionTimeout), "The Paste action did not appear on the password field.", file: file, line: line)
        paste.tap()
    }
}
