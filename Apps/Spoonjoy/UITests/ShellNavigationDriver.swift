import XCTest

/// Drives the app's shell for the navigation genre checks (`BackNavigationUITests`, `OverlayDismissalUITests`) on
/// whichever layout the simulator gives it: the tab bar on an iPhone or a folded Duo, the sidebar on an iPad or an
/// open Duo. The checks themselves (`assertGoesBack…`, `assertSidebarStepsAside…`) are the parts Ouro Feel's
/// back-affordance and overlay-dismissal checks will replace when they land in ouro-ui-apple.
///
/// Like the motion checks, these need the screenshot fixture kitchen seeded into the simulator, so only
/// `scripts/check-motion.sh` runs them; anywhere else they skip.
@MainActor
struct ShellNavigationDriver {
    nonisolated static let fixtureVariable = "SPOONJOY_MOTION_CHECK"

    let app: XCUIApplication

    /// A place the shell can go: its tab on the phone, its sidebar row on the iPad.
    enum Place: String {
        case kitchen, recipes, cookbooks, chefs

        var tabIdentifier: String {
            switch self {
            case .kitchen, .chefs: "dock.kitchen"
            case .recipes: "dock.recipes"
            case .cookbooks: "dock.cookbooks"
            }
        }

        var sidebarTitle: String {
            switch self {
            case .kitchen: "Kitchen"
            case .recipes: "My Recipes"
            case .cookbooks: "Cookbooks"
            case .chefs: "Chefs"
            }
        }
    }

    static func launch() -> XCUIApplication {
        let app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        for key in ["SPOONJOY_SCREENSHOT_AUTH", "SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY", "SPOONJOY_SCREENSHOT_ACCOUNT_ID"] {
            if let value = environment[key] {
                app.launchEnvironment[key] = value
            }
        }
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func text(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Whether the shell has come up, in either layout.
    var shellIsUp: Bool {
        element("dock.kitchen").exists || sidebarToggle.exists || sidebarRow.exists
    }

    /// Whether the shell is the split view with a sidebar, rather than the tab bar.
    var usesSidebar: Bool {
        // The dock's identifiers arrive a moment after the tab bar, so wait for one layout or the other first.
        _ = waitUntil(10) { element("dock.kitchen").exists || sidebarToggle.exists || sidebarRow.exists }
        return !element("dock.kitchen").exists && (sidebarToggle.exists || sidebarRow.exists)
    }

    var sidebarToggle: XCUIElement {
        // The system's own toggle, "Show Sidebar" or "Hide Sidebar"; the sidebar's own rows carry "sidebar." identifiers.
        app.buttons.matching(NSPredicate(format: "label ENDSWITH[c] ' sidebar'")).firstMatch
    }

    /// The sidebar's Kitchen Search row, which only the sidebar has.
    var sidebarRow: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Kitchen Search'")).firstMatch
    }

    var sidebarShows: Bool {
        sidebarRow.exists && sidebarRow.isHittable
    }

    /// A row of the sidebar by its title. A pushed page's back button and the page itself can carry the same title,
    /// so the row is the match inside the sidebar's column that is not a back button.
    func sidebarRow(_ title: String) -> XCUIElement {
        // The sidebar column is at most 400 points wide on every layout the checks run on.
        let column: CGFloat = 400
        let matches = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND identifier != 'BackButton'", title))
            .allElementsBoundByIndex
        return matches.first { $0.frame.maxX <= column && $0.isHittable } ?? matches.first ?? app.otherElements["missing sidebar row \(title)"]
    }

    func showSidebar(file: StaticString = #filePath, line: UInt = #line) {
        if sidebarShows {
            return
        }
        XCTAssertTrue(sidebarToggle.waitForExistence(timeout: 10), "No sidebar button.\n\(app.debugDescription)", file: file, line: line)
        sidebarToggle.tap()
        XCTAssertTrue(waitUntil(10) { sidebarShows }, "The sidebar button did not show the sidebar.", file: file, line: line)
    }

    func go(to place: Place, file: StaticString = #filePath, line: UInt = #line) {
        if usesSidebar {
            showSidebar(file: file, line: line)
            sidebarRow(place.sidebarTitle).tap()
            // On an upright iPad the sidebar steps aside after the choice; wait for it, so the next tap reaches
            // the page.
            _ = waitUntil(3) { !sidebarShows }
            // The page then widens to the whole window; let it settle so the next tap lands where it aims.
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        } else {
            let tab = element(place.tabIdentifier)
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "The tab bar has no \(place.rawValue) tab.", file: file, line: line)
            tab.tap()
            // Tapping the selected tab again pops it to its root.
            tab.tap()
            if place == .chefs {
                let chefs = element("kitchen.chefs")
                XCTAssertTrue(chefs.waitForExistence(timeout: 10), "The Kitchen has no Chefs link.", file: file, line: line)
                chefs.tap()
            }
        }
    }

    /// The system back button of the page on top.
    var backButton: XCUIElement {
        app.navigationBars.buttons.matching(identifier: "BackButton").firstMatch
    }

    /// Slides a finger in from the left edge of the screen, as a person goes back by swiping.
    func edgeSwipe() {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.003, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.1)
    }

    /// Pulls a sheet down by its own bar (the bar holding `control`), as a person flicks a sheet away.
    func swipeSheetDown(holding control: XCUIElement) {
        let bar = app.navigationBars.containing(NSPredicate(format: "label == %@", control.label)).firstMatch
        let grip = (bar.exists ? bar : control).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let window = app.windows.firstMatch.frame
        let start = bar.exists ? bar.frame : control.frame
        grip.press(forDuration: 0.05, thenDragTo: grip.withOffset(CGVector(dx: 0, dy: window.maxY - start.midY - 20)), withVelocity: .fast, thenHoldForDuration: 0)
    }

    func waitUntil(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return condition()
    }

    // MARK: Checks (to switch to Ouro Feel's back-affordance check)

    /// A page opened from another has a back button, the back button returns, and so does a swipe in from the edge.
    func assertGoesBack(
        _ name: String,
        from place: Place,
        home: () -> XCUIElement,
        open: () -> Void,
        page: () -> XCUIElement,
        backTo: (() -> XCUIElement)? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for way in ["the back button", "an edge swipe"] {
            go(to: place, file: file, line: line)
            XCTAssertTrue(home().waitForExistence(timeout: 15), "\(name): the starting page did not show.", file: file, line: line)
            open()
            XCTAssertTrue(page().waitForExistence(timeout: 15), "\(name): the page did not open.", file: file, line: line)
            if way == "the back button" {
                XCTAssertTrue(
                    backButton.waitForExistence(timeout: 5) && backButton.isHittable,
                    "\(name): the page has no back button.", file: file, line: line
                )
                backButton.tap()
            } else {
                edgeSwipe()
            }
            XCTAssertTrue(
                waitUntil(15) { !page().exists && (backTo?() ?? home()).exists },
                "\(name): \(way) did not go back.", file: file, line: line
            )
        }
    }

    // MARK: Checks (to switch to Ouro Feel's overlay-dismissal check)

    /// A sidebar that squeezes or covers the page steps aside once a destination is chosen.
    func assertSidebarStepsAsideAfterChoosing(_ title: String, lands: () -> XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        showSidebar(file: file, line: line)
        sidebarRow(title).tap()
        XCTAssertTrue(lands().waitForExistence(timeout: 15), "Choosing \(title) did not open it.", file: file, line: line)
        XCTAssertTrue(waitUntil(10) { !sidebarShows }, "The sidebar stayed over the page after choosing \(title).", file: file, line: line)
    }
}
