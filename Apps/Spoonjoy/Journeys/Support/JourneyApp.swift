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
    private static let pasteMenuTitle = "Paste"

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
        query(id).firstMatch
    }

    func element(_ id: String, labelContaining text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", id, text))
            .firstMatch
    }

    /// An element inside the element `id` whose label contains `text`, ignoring case, for data a journey
    /// created. The web API stores ingredient names lowercased (normalizeName in
    /// app/lib/api-v1.server.ts), so `Journey<token>basil` comes back as `journey<token>basil`.
    func element(_ id: String, descendantLabelContaining text: String) -> XCUIElement {
        element(id).descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
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
        let current = field.value as? String ?? ""
        let existing = current == field.placeholderValue ? "" : current
        if existing != identifier {
            // Tap past the end of the text so the caret lands after it, delete exactly that many
            // characters, and prove the field is empty before typing. No edit menu is involved.
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
            assertKeyboardFocus(in: query(JourneyID.signInIdentifier), named: "The identifier field", file: file, line: line)
            if !existing.isEmpty {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
            }
            assertCleared(field, "The identifier field still holds text after clearing it.", file: file, line: line)
            field.typeText(identifier)
        }
        assertValue(of: field, equals: identifier, "The identifier field does not hold exactly the identifier. Screen: \(screen)", file: file, line: line)

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

    /// Selects a tab bar item. Tab items cannot carry identifiers, so the tab is found by its
    /// `JourneyCopy` title, and only among the tab bar's buttons.
    func openTab(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: Self.launchTimeout), "The \(title) tab is missing.", file: file, line: line)
        tab.tap()
    }

    /// Opens Search from the signed-in shell's "More" menu and waits for its search field.
    func openSearch(file: StaticString = #filePath, line: UInt = #line) {
        tap(JourneyID.shellMore, file: file, line: line)
        tap(JourneyID.shellMoreSearch, file: file, line: line)
        XCTAssertTrue(searchField.waitForExistence(timeout: Self.launchTimeout), "Search has no search field.", file: file, line: line)
    }

    /// Replaces the text in Search's field with `query`. Results follow as the user types.
    func search(for query: String, file: StaticString = #filePath, line: UInt = #line) {
        replaceText(in: app.searchFields, named: "The search field", with: query, file: file, line: line)
    }

    /// Opens the recipe whose row `listID` has a label containing `title`, and waits for its detail page.
    func openRecipe(titled title: String, from listID: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = element(listID, labelContaining: title)
        XCTAssertTrue(row.waitForExistence(timeout: Self.networkTimeout), "No \(listID) row shows \(title).", file: file, line: line)
        row.tap()
        waitFor(JourneyID.recipeDetailTitle, timeout: Self.networkTimeout, "The recipe detail page did not open.", file: file, line: line)
    }

    /// Types into an empty field and reads the value back.
    func enterText(_ text: String, into id: String, file: StaticString = #filePath, line: UInt = #line) {
        tap(id, file: file, line: line)
        let field = element(id)
        assertKeyboardFocus(in: query(id), named: id, file: file, line: line)
        field.typeText(text)
        assertValue(of: field, equals: text, "\(id) does not hold exactly the typed text.", file: file, line: line)
    }

    /// Replaces the text in a field that already holds a value.
    func replaceText(in id: String, with text: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id, timeout: Self.launchTimeout, "\(id) did not appear.", file: file, line: line)
        replaceText(in: query(id), named: id, with: text, file: file, line: line)
    }

    /// Saves the recipe editor. Save is the form's last row. Run 36333893304 showed the keyboard still up
    /// after two swipes, with Save at y 904, under the tab bar, so the tap never reached it. The field
    /// being edited is closed with Return first, then one swipe reaches the end of the form, and Save must
    /// sit above the tab bar before it is tapped.
    func saveRecipeEditor(file: StaticString = #filePath, line: UInt = #line) {
        app.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForNonExistence(timeout: Self.interactionTimeout),
            "Return did not close the keyboard; the last field before Save must be a single-line text field.",
            file: file,
            line: line
        )
        app.swipeUp()
        let save = element(JourneyID.editorSave)
        XCTAssertTrue(save.waitForExistence(timeout: Self.interactionTimeout), "The editor's Save button is missing.", file: file, line: line)
        XCTAssertTrue(save.isEnabled, "Save is disabled, so the editor rejected the draft.", file: file, line: line)
        XCTAssertLessThanOrEqual(
            save.frame.maxY,
            app.tabBars.firstMatch.frame.minY,
            "Save is under the tab bar, where a tap would not reach it. Screen: \(screen)",
            file: file,
            line: line
        )
        save.tap()
        // The editor's title field, not Save, shows whether the editor closed: while saving, Save's label
        // becomes a progress view and the Save button query stops matching (run 36337705822).
        XCTAssertTrue(
            element(JourneyID.editorTitle).waitForNonExistence(timeout: Self.networkTimeout),
            "The editor did not close after Save. Editor message: \(editorStatusAtTop()). Screen: \(screen)",
            file: file,
            line: line
        )
    }

    /// For a failure message only: scrolls the editor back to its top, where a blocked or failed save
    /// shows its message, and returns that message.
    private func editorStatusAtTop() -> String {
        app.swipeDown()
        app.swipeDown()
        let status = element(JourneyID.editorStatus)
        return status.waitForExistence(timeout: Self.interactionTimeout) ? status.label : "none shown"
    }

    /// The app's current accessibility hierarchy, for failure messages only.
    var screen: String {
        app.debugDescription
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
        waitFor(id, timeout: Self.launchTimeout, "\(id) did not appear. Screen: \(screen)", file: file, line: line)
        element(id).tap()
    }

    /// The message is evaluated only on failure, so a screen dump in it costs nothing on success.
    private func waitFor(_ id: String, timeout: TimeInterval, _ message: @autoclosure () -> String, file: StaticString, line: UInt) {
        XCTAssertTrue(element(id).waitForExistence(timeout: timeout), message(), file: file, line: line)
    }

    private var searchField: XCUIElement {
        app.searchFields.firstMatch
    }

    /// Taps past the end of the text so the caret lands after it, deletes exactly that many characters,
    /// proves the field is empty, types the text and reads it back. No edit menu is involved.
    private func replaceText(in query: XCUIElementQuery, named name: String, with text: String, file: StaticString, line: UInt) {
        let field = query.firstMatch
        let current = field.value as? String ?? ""
        let existing = current == field.placeholderValue ? "" : current
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        assertKeyboardFocus(in: query, named: name, file: file, line: line)
        if !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        assertCleared(field, "\(name) still holds text after clearing it.", file: file, line: line)
        field.typeText(text)
        assertValue(of: field, equals: text, "\(name) does not hold exactly the typed text.", file: file, line: line)
    }

    /// Waits up to `interactionTimeout` for the field to hold exactly `text`, then asserts that it does.
    /// XCUITest's idle check covers the app's main thread, not the keyboard's input queue, so `typeText` can
    /// return while keys are still arriving: run 36340239763 read "c" from a field whose recording then showed
    /// "cod" and "codex-na". A late key passes. A dropped, trimmed or changed key never makes the value equal
    /// `text`, so the assertion still fails and reports the value it read. Nothing is typed again.
    private func assertValue(of field: XCUIElement, equals text: String, _ message: @autoclosure () -> String, file: StaticString, line: UInt) {
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: field)
        _ = XCTWaiter.wait(for: [settled], timeout: Self.interactionTimeout)
        XCTAssertEqual(field.value as? String, text, message(), file: file, line: line)
    }

    /// Waits up to `interactionTimeout` for deleted characters to leave the field, then asserts that it is
    /// empty (an empty field reports its placeholder as its value). Nothing is deleted again.
    private func assertCleared(_ field: XCUIElement, _ message: @autoclosure () -> String, file: StaticString, line: UInt) {
        let placeholder = field.placeholderValue ?? ""
        let empty = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == nil OR value == '' OR value == %@", placeholder),
            object: field
        )
        _ = XCTWaiter.wait(for: [empty], timeout: Self.interactionTimeout)
        let cleared = field.value as? String ?? ""
        XCTAssertTrue(cleared.isEmpty || cleared == field.placeholderValue, message(), file: file, line: line)
    }

    /// Matches the accessibility identifier alone. `matching(identifier:)` also compares each element's
    /// label, title, value and placeholder, which XCUITest evaluates on the app's main thread for every
    /// element on screen: with the editor form and keyboard up that took seconds per lookup, dropped
    /// keystrokes, and once crashed the app while fetching a placeholder (runs 36331139692, 36332727373).
    private func query(_ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id))
    }

    /// Waits for the tapped field (the first match of `query`) to take keyboard focus before anything is
    /// typed: the keyboard's arrival can move the layout, and typing into a field that is not focused yet
    /// fails. Fails naming the element that holds focus instead.
    private func assertKeyboardFocus(in query: XCUIElementQuery, named name: String, file: StaticString, line: UInt) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let holder = app.descendants(matching: .any).matching(focused).firstMatch
        XCTAssertTrue(
            query.matching(focused).firstMatch.waitForExistence(timeout: Self.interactionTimeout),
            "\(name) did not take keyboard focus after a tap. Tapped element: \(query.firstMatch.debugDescription) Hittable: \(query.firstMatch.isHittable). Keyboard shown: \(app.keyboards.firstMatch.exists). Focus is on: \(holder.exists ? holder.debugDescription : "nothing")",
            file: file,
            line: line
        )
    }

    /// A system edit-menu item (system copy, so it is matched by label).
    private func editMenuItem(_ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func pastePassword(_ password: String, file: StaticString, line: UInt) {
        let field = element(JourneyID.signInPassword)
        waitFor(JourneyID.signInPassword, timeout: Self.interactionTimeout, "The password field is missing.", file: file, line: line)
        UIPasteboard.general.string = password
        defer { UIPasteboard.general.items = [] }
        field.tap()
        field.press(forDuration: 1.2)
        let paste = editMenuItem(Self.pasteMenuTitle)
        XCTAssertTrue(paste.waitForExistence(timeout: Self.interactionTimeout), "The Paste action did not appear on the password field.", file: file, line: line)
        paste.tap()
    }
}
