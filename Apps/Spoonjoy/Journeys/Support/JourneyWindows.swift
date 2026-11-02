import XCTest

/// Reads which of the app's windows holds what. Each window carries a one-pixel `journey.window` probe whose value is
/// the system's name for the window and the page it shows, so a journey can tell two windows apart without driving
/// the system's window switcher.
@MainActor
extension JourneyApp {
    /// The probe values of every window of the app that is connected now, such as "<scene id> recipe-cook:<id>".
    var windowProbes: [String] {
        app.descendants(matching: .any).matching(identifier: "journey.window").allElementsBoundByIndex
            .compactMap { $0.value as? String }
    }

    /// Waits until `count` windows of the app are connected, and returns their probes.
    func waitForWindows(_ count: Int, timeout: TimeInterval = JourneyApp.networkTimeout) -> [String] {
        let probes = app.descendants(matching: .any).matching(identifier: "journey.window")
        let enough = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in probes.count >= count }, object: nil)
        _ = XCTWaiter().wait(for: [enough], timeout: timeout)
        return windowProbes
    }

    /// Waits until at least one window is back and every window holds one of `pages` (probe values from before a kill),
    /// and returns the probes as they then stand. A window restores its page a moment after it connects.
    func waitForWindowsRestored(to pages: [String], timeout: TimeInterval = JourneyApp.networkTimeout) -> [String] {
        let windows = app.descendants(matching: .any).matching(identifier: "journey.window")
        let restored = NSPredicate { _, _ in
            let probes = windows.allElementsBoundByIndex.compactMap { $0.value as? String }
            return !probes.isEmpty && probes.allSatisfy(pages.contains)
        }
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: restored, object: nil)], timeout: timeout)
        return windowProbes
    }

    /// Waits until `element` can be tapped, which only an element in a window on screen can.
    func waitForFront(_ element: XCUIElement, timeout: TimeInterval = JourneyApp.networkTimeout) -> Bool {
        let front = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in element.exists && element.isHittable }, object: nil)
        return XCTWaiter().wait(for: [front], timeout: timeout) == .completed
    }

    /// Asks the system for Split View the way a person does on the open iPhone Duo held sideways: from the Home Screen,
    /// touch and hold the app's icon, choose Open in Split View, then choose the app again for its other window. Each
    /// stage calls `snap`, so the journey keeps a picture of what the system offered. It never touches the system's
    /// window switcher, and it stops quietly where the system offers nothing, so the journey proves windows by their
    /// probes, not by this.
    func requestSplitViewFromHomeScreen(_ snap: (String) throws -> Void) rethrows {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        let icon = springboard.icons[JourneyCopy.appName]
        guard icon.waitForExistence(timeout: JourneyApp.interactionTimeout) else {
            try snap("split-1-no-icon")
            return
        }
        icon.press(forDuration: 1.5)
        try snap("split-1-icon-menu")
        let split = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Split View")).firstMatch
        guard split.waitForExistence(timeout: JourneyApp.interactionTimeout) else {
            XCUIDevice.shared.press(.home)
            app.activate()
            return
        }
        split.tap()
        try snap("split-2-choose-second")
        if icon.waitForExistence(timeout: JourneyApp.interactionTimeout) {
            icon.tap()
        }
        _ = app.wait(for: .runningForeground, timeout: JourneyApp.interactionTimeout)
        try snap("split-3-side-by-side")
    }
}
