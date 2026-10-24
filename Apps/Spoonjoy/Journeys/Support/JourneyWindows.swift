import XCTest

/// The phone shows one of the app's windows at a time and a "2 Views Open" pill that lists them. These helpers bring
/// another window forward through that pill, so a journey can check what each window shows.
@MainActor
extension JourneyApp {
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    /// The system's pill naming how many of the app's windows are open, in the app or drawn by SpringBoard.
    var openWindowsPill: XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", "Views Open")
        let inApp = app.descendants(matching: .any).matching(predicate).firstMatch
        return inApp.waitForExistence(timeout: 5) ? inApp : springboard.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Opens the pill's list of windows and brings forward the one whose entry names `title`, then reports what the
    /// system showed on the way, for the result bundle. Returns false when the pill or the entry could not be found.
    func bringWindowForward(named title: String, to testCase: XCTestCase) -> Bool {
        let pill = openWindowsPill
        guard pill.waitForExistence(timeout: Self.interactionTimeout) else {
            attach("windows-no-pill", app.debugDescription, to: testCase)
            return false
        }
        pill.tap()
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", title)
        let inApp = app.descendants(matching: .any).matching(predicate)
        let inSystem = springboard.descendants(matching: .any).matching(predicate)
        _ = inSystem.firstMatch.waitForExistence(timeout: Self.interactionTimeout)
        attach("windows-picker-app", app.debugDescription, to: testCase)
        attach("windows-picker-springboard", springboard.debugDescription, to: testCase)
        let entry = inSystem.firstMatch.exists ? inSystem.firstMatch : inApp.firstMatch
        guard entry.exists else {
            return false
        }
        entry.tap()
        return true
    }

    private func attach(_ name: String, _ text: String, to testCase: XCTestCase) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
}
