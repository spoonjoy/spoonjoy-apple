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
}
