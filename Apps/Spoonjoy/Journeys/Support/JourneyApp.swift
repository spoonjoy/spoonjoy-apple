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
        // "Add Photo" stages a built-in picture instead of opening the system photo picker.
        app.launchEnvironment[NativeJourneyPhotoFixture.environmentKey] = "1"
        // The app records each sync request and the server's answer in a hidden element, read on failure.
        app.launchEnvironment[NativeSyncDiagnostics.environmentKey] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        // Animations and spinners never go idle for XCUITest, which then waits 60 seconds per action.
        app.launchArguments.append(NativeJourneyAnimations.launchArgument)
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

    /// Opens a `spoonjoy://` link. `XCUIApplication.open` starts a new app process, so the launch-time reset
    /// flag is dropped first, as in `relaunch()`; otherwise the new process would be signed out and park the
    /// link until sign-in.
    func openLink(_ url: URL) {
        app.launchEnvironment.removeValue(forKey: NativeJourneyLaunchReset.environmentKey)
        app.open(url)
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

    /// An element `id` whose label contains `text`, ignoring case, for data a journey created.
    func element(_ id: String, labelContainingIgnoringCase text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label CONTAINS[c] %@", id, text))
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

    /// Opens Settings from the account button on the Kitchen tab's root.
    func openSettings(file: StaticString = #filePath, line: UInt = #line) {
        tap(JourneyID.kitchenAccount, file: file, line: line)
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
    ///
    /// After the content scrolls, iOS minimizes the tab bar to one button for the selected tab (its value is
    /// "Collapsed") and hides the others. The page now updates in place instead of being rebuilt, so that state
    /// survives. Tapping the collapsed button expands the bar, and only then is the wanted tab tapped.
    func openTab(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let tabButtons = app.tabBars.buttons
        XCTAssertTrue(tabButtons.firstMatch.waitForExistence(timeout: Self.launchTimeout), "The tab bar is missing.", file: file, line: line)
        let collapsed = tabButtons.matching(NSPredicate(format: "value == %@", "Collapsed")).firstMatch
        if collapsed.exists {
            collapsed.tap()
        }
        let tab = tabButtons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: Self.launchTimeout), "The \(title) tab is missing.", file: file, line: line)
        tab.tap()
    }

    /// Opens the Search tab and waits for its search field.
    func openSearch(file: StaticString = #filePath, line: UInt = #line) {
        openTab(JourneyCopy.searchTab, file: file, line: line)
        XCTAssertTrue(searchField.waitForExistence(timeout: Self.launchTimeout), "Search has no search field.", file: file, line: line)
    }

    /// Replaces the text in Search's field with `query`. Results follow as the user types.
    func search(for query: String, file: StaticString = #filePath, line: UInt = #line) {
        replaceText(in: app.searchFields, named: "The search field", with: query, scrolls: false, file: file, line: line)
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
        let fields = fieldQuery(id)
        let field = fields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.launchTimeout), "\(id) did not appear. Screen: \(screen)", file: file, line: line)
        focus(fields, named: id, firstTapAt: Self.fieldCentre, file: file, line: line)
        field.typeText(text)
        assertValue(of: field, equals: text, "\(id) does not hold exactly the typed text.", file: file, line: line)
    }

    /// Replaces the text in a field that already holds a value.
    func replaceText(in id: String, with text: String, file: StaticString = #filePath, line: UInt = #line) {
        let fields = fieldQuery(id)
        XCTAssertTrue(fields.firstMatch.waitForExistence(timeout: Self.launchTimeout), "\(id) did not appear.", file: file, line: line)
        replaceText(in: fields, named: id, with: text, file: file, line: line)
    }

    /// Presses Return in the focused field.
    func pressReturn() {
        app.typeText(XCUIKeyboardKey.return.rawValue)
    }

    /// Waits for the field `id` to hold exactly `text`, then asserts it.
    func assertFieldValue(_ id: String, equals text: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = fieldQuery(id).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.interactionTimeout), "\(id) did not appear. Screen: \(screen)", file: file, line: line)
        assertValue(of: field, equals: text, "\(id) does not hold \(text).", file: file, line: line)
    }

    /// Saves the recipe editor. Save is in the navigation bar, so it is reachable with the keyboard up. The
    /// field being edited is closed with Return first, so the last field before Save must be a single-line field.
    func saveRecipeEditor(file: StaticString = #filePath, line: UInt = #line) {
        app.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForNonExistence(timeout: Self.interactionTimeout),
            "Return did not close the keyboard; the last field before Save must be a single-line text field.",
            file: file,
            line: line
        )
        saveOpenRecipeEditor(file: file, line: line)
    }

    /// Saves an editor from its toolbar Save button and checks the editor closes.
    func saveOpenRecipeEditor(file: StaticString = #filePath, line: UInt = #line) {
        let save = element(JourneyID.editorSave)
        XCTAssertTrue(save.waitForExistence(timeout: Self.interactionTimeout), "The editor's Save button is missing.", file: file, line: line)
        XCTAssertTrue(save.isEnabled, "Save is disabled, so the editor rejected the draft.", file: file, line: line)
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

    /// Chooses the first photo in the system photo picker the editor opened. The picker closes on its own
    /// when one photo is picked. The CI workflow puts a photo in the simulator's library first.
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
        "Sync log: \(syncLog)\n" + app.debugDescription
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

    /// Allows the Reminders permission prompt (its button reads "Allow" on iOS 27) when the system shows it. A simulator that already granted
    /// access shows no prompt, so the wait simply ends.
    /// Waits once for whichever comes first: the system's Reminders permission alert, or the list-name field that
    /// shows access is already settled. The alert can take longer than a button tap to appear on a cold
    /// simulator, so a fixed short wait missed it; waiting on either outcome costs nothing when it is not asked.
    func allowRemindersAccessIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Allow")).firstMatch
        let field = element(JourneyID.remindersNewListName)
        let either = NSPredicate { _, _ in allow.exists || field.exists }
        let settled = XCTNSPredicateExpectation(predicate: either, object: nil)
        _ = XCTWaiter().wait(for: [settled], timeout: Self.networkTimeout)
        if allow.exists {
            allow.tap()
        }
    }

    /// The recent sync requests and the server's answers, recorded by the app for this run. It is empty text when
    /// the app does not expose it.
    var syncLog: String {
        let log = element("journey.syncLog")
        return log.exists ? ((log.value as? String) ?? "unreadable") : "no sync log element"
    }

    /// Keeps a screenshot of the current screen in the result bundle.
    func attachScreenshot(named name: String, to testCase: XCTestCase) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
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
    private func replaceText(in query: XCUIElementQuery, named name: String, with text: String, scrolls: Bool = true, file: StaticString, line: UInt) {
        let field = query.firstMatch
        let current = field.value as? String ?? ""
        let existing = current == field.placeholderValue ? "" : current
        // The caret has to land after the text, so this starts at the trailing edge; the centre is the fallback.
        focus(query, named: name, firstTapAt: Self.fieldTrailingEdge, scrolls: scrolls, file: file, line: line)
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

    /// A text input found by its type as well as its identifier. The editor form holds dozens of elements, and
    /// a query over every element type timed out evaluating on a slow runner (run 37952511182, "Failed to get
    /// matching snapshot" on `editor.step.2.ingredient.4.quantity`). The multi-line step description and the
    /// paste box are text views; every other input a journey types into is a text field.
    private func fieldQuery(_ id: String) -> XCUIElementQuery {
        let named = NSPredicate(format: "identifier == %@", id)
        let isTextView = id == JourneyID.editorPasteText || id.hasSuffix(".description")
        return (isTextView ? app.textViews : app.textFields).matching(named)
    }

    private static let fieldCentre = CGVector(dx: 0.5, dy: 0.5)
    private static let fieldTrailingEdge = CGVector(dx: 0.97, dy: 0.5)
    private static let focusAttempts = 3
    private static let scrollDrags = 12
    private static let focusWait: TimeInterval = 4

    /// Puts keyboard focus in the first match of `query`. Focus flaked on four heads when a tap landed on a
    /// field that was still moving, half under the keyboard or behind the floating tab bar. So the field is
    /// scrolled fully into view first, then tapped (`firstTapAt`, normally its centre) up to three times, each
    /// followed by a bounded wait for focus, then once at the other end of the field. Only then does it fail,
    /// naming the field's and the keyboard's frames. The assertion stays strict: focus must really land.
    private func focus(_ query: XCUIElementQuery, named name: String, firstTapAt: CGVector, scrolls: Bool = true, file: StaticString, line: UInt) {
        let fallback = firstTapAt == Self.fieldCentre ? Self.fieldTrailingEdge : Self.fieldCentre
        let taps = Array(repeating: firstTapAt, count: Self.focusAttempts) + [fallback]
        // Recursion, not a loop: the house rules keep journey code free of `for` and `while`.
        if !tapUntilFocused(query, taps: taps[...], scrolls: scrolls) {
            let field = query.firstMatch
            let holder = app.descendants(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
            XCTFail(
                "\(name) did not take keyboard focus after \(taps.count) taps. Field frame: \(field.frame). Keyboard frame: \(app.keyboards.firstMatch.exists ? "\(app.keyboards.firstMatch.frame)" : "no keyboard"). Hittable: \(field.isHittable). Focus is on: \(holder.exists ? holder.debugDescription : "nothing"). Tapped element: \(field.debugDescription)",
                file: file,
                line: line
            )
        }
    }

    /// Taps at the first offset in `taps` and waits for focus; on a miss, tries the next offset.
    private func tapUntilFocused(_ query: XCUIElementQuery, taps: ArraySlice<CGVector>, scrolls: Bool) -> Bool {
        guard let offset = taps.first else {
            return false
        }
        let field = query.firstMatch
        if scrolls {
            scrollIntoView(field, dragsLeft: Self.scrollDrags)
        }
        guard Self.isLocated(field) else {
            // Tapping an element with no frame throws inside XCUITest; fail with the reason instead.
            XCTFail("\(query.firstMatch.debugDescription) has no usable frame after scrolling both ways.")
            return true
        }
        field.coordinate(withNormalizedOffset: offset).tap()
        if query.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch.waitForExistence(timeout: Self.focusWait) {
            return true
        }
        return tapUntilFocused(query, taps: taps.dropFirst(), scrolls: scrolls)
    }

    /// An off-screen field can still report `exists` while its frame is infinite or empty (the editor lets
    /// SwiftUI drop fields far outside the viewport), so a frame, not existence, says where it is.
    private static func isLocated(_ field: XCUIElement) -> Bool {
        guard field.exists else {
            return false
        }
        let frame = field.frame
        return frame.minY.isFinite && frame.maxY.isFinite && !frame.isEmpty && !frame.isInfinite
    }

    /// Drags the form until `field` sits fully between the navigation bar and whatever covers the bottom of the
    /// screen (the keyboard, or the floating tab bar), with a margin. Stops after a few drags either way.
    private func scrollIntoView(_ field: XCUIElement, dragsLeft: Int) {
        let margin: CGFloat = 24
        let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : 0
        var bottom = app.frame.maxY
        if app.tabBars.firstMatch.exists {
            bottom = min(bottom, app.tabBars.firstMatch.frame.minY)
        }
        if app.keyboards.firstMatch.exists {
            // The keyboard's glass top edge sits about 70 pt above its reported frame.
            bottom = min(bottom, app.keyboards.firstMatch.frame.minY - 70)
        }
        let located = Self.isLocated(field)
        let visible = located && field.frame.minY >= top + margin && field.frame.maxY <= bottom - margin
        guard !visible, dragsLeft > 0 else {
            return
        }
        // A field without a frame may be above or below the viewport (the editor drops
        // off-screen fields): look below first, then, after a few drags, look above.
        let towardsTop = located ? field.frame.maxY > bottom - margin : dragsLeft > Self.scrollDrags / 2
        // The keyboard is drawn taller than its reported frame (a drag started at 0.65 of the screen height
        // landed on the keys and scrolled nothing), so with it up the drag stays in the top half of the screen.
        let keyboardUp = app.keyboards.firstMatch.exists
        let startY = keyboardUp ? 0.45 : 0.65
        let endY = keyboardUp ? 0.15 : 0.35
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardsTop ? startY : endY))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardsTop ? endY : startY))
        from.press(forDuration: 0.05, thenDragTo: to)
        scrollIntoView(field, dragsLeft: dragsLeft - 1)
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
