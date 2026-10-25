import XCTest

/// The phone shows one of the app's windows at a time and a "2 Views Open" pill that opens the window switcher. The
/// switcher labels every card "Spoonjoy" and names it by the system's identifier for the window, so these helpers
/// read the front window's identifier from the app and bring another window forward by tapping its card.
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

    /// The system's identifier for the app window that holds element `id` (whose label contains `text`, when given),
    /// read from the window's own probe. After a kill only the window in front is connected, so this finds only it.
    /// Nil when that window does not hold it.
    func windowID(holding id: String, labelContaining text: String? = nil) -> String? {
        let content = text.map { NSPredicate(format: "identifier == %@ AND label CONTAINS %@", id, $0) }
            ?? NSPredicate(format: "identifier == %@", id)
        let window = app.windows.containing(content).firstMatch
        guard window.waitForExistence(timeout: Self.networkTimeout) else {
            return nil
        }
        let probe = window.descendants(matching: .any).matching(identifier: "journey.window").firstMatch
        return probe.exists ? probe.value as? String : nil
    }

    /// Opens the window switcher from the pill and taps the card of a window other than `id`, the one in front,
    /// then reports what the system showed, for the result bundle. Returns false when the pill or the card could not
    /// be found.
    func bringWindowForward(otherThan id: String, to testCase: XCTestCase) -> Bool {
        let pill = openWindowsPill
        guard pill.waitForExistence(timeout: Self.interactionTimeout) else {
            attach("windows-no-pill", app.debugDescription, to: testCase)
            return false
        }
        pill.tap()
        let card = springboard.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND NOT (identifier CONTAINS %@)", "card:app.spoonjoy:", id)
        ).firstMatch
        guard card.waitForExistence(timeout: Self.interactionTimeout) else {
            attach("windows-switcher", springboard.debugDescription, to: testCase)
            return false
        }
        attach("windows-switcher", springboard.debugDescription, to: testCase)
        // The cards overlap, the newer on top, so a tap at a card's centre can land on the card above it. Its
        // leading edge is always its own.
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        _ = card.waitForNonExistence(timeout: Self.interactionTimeout)
        attach("windows-after-card", springboard.debugDescription, to: testCase)
        return true
    }

    /// Waits until `element` can be tapped, which only an element in the front window can.
    func waitForFront(_ element: XCUIElement) -> Bool {
        let front = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in element.exists && element.isHittable }, object: nil)
        return XCTWaiter().wait(for: [front], timeout: Self.networkTimeout) == .completed
    }

    private func attach(_ name: String, _ text: String, to testCase: XCTestCase) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
}
