import OuroFeel
import OuroFeelCore
import UIKit
import XCTest

/// Ouro Feel (ourostack/ouro-ui-apple) over the fixture kitchen, by genre of jank: the way back from every screen the
/// Chefs page reaches, and, on iPad, the library sidebar closing once you pick a section. They need the seeded fixture
/// kitchen, so only `scripts/check-feel.sh` runs them; anywhere else they skip. Each writes its report to the result
/// bundle and, with `OURO_FEEL_REPORT_DIR`, to that folder.
@MainActor
final class FeelUITests: XCTestCase {
    nonisolated static let fixtureVariable = "SPOONJOY_FEEL_CHECK"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.fixtureVariable] == "1",
            "Needs the seeded fixture kitchen; run scripts/check-feel.sh."
        )
    }

    /// Opens the app upright on the kitchen. Each check calls it first: setUp is not on the main actor, and the app is.
    private func openApp() {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        for key in ["SPOONJOY_SCREENSHOT_AUTH", "SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY", "SPOONJOY_SCREENSHOT_ACCOUNT_ID"] {
            if let value = environment[key] { app.launchEnvironment[key] = value }
        }
        // Spoonjoy reopens on the last page; the walk relaunches to replay paths, so every launch opens on the kitchen.
        app.launchEnvironment["SPOONJOY_LAUNCH_ON_KITCHEN"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        // Ouro Feel's recorder in the app (DEBUG builds), for films of a push or a sheet frame by frame.
        app.launchEnvironment.merge(OuroFeel.recorderEnvironment) { _, new in new }
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["kitchen.root"].waitForExistence(timeout: 60), "the kitchen opened")
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            app?.terminate()
            app = nil
        }
    }

    /// Every screen one tap from Chefs (each chef's page, and the rest) has a visible way back and a gesture back
    /// (jank item 7: a chef page had neither).
    func testTheWayBackFromChefs() {
        openApp()
        let chefs = FeelEntry("Chefs") { app in
            let button = app.buttons["kitchen.chefs"].firstMatch
            if button.waitForExistence(timeout: 10) { button.tap() }
        }
        let feel = OuroFeel(app)
        feel.expect(feel.wayBack(from: [chefs], follow: FeelFollow(types: [.button]), depth: 1, limit: 12))
    }

    /// Every screen a cook can reach, from each tab, from Chefs and from Account and settings, two taps deep: each has
    /// a visible way back and a gesture back. One chef page without them (jank item 7) means the whole app is walked.
    func testTheWayBackFromEveryScreen() {
        openApp()
        let feel = OuroFeel(app)
        feel.expect(feel.wayBack(from: Self.everyEntry, follow: Self.follow, depth: 2, limit: 80))
    }

    /// Where a walk of the whole app starts: the kitchen, each tab in the dock, Chefs, and Account and settings.
    static var everyEntry: [FeelEntry] {
        [FeelEntry("Kitchen") { _ in }]
            + ["recipes", "cookbooks", "shopping", "search"].map { tab in
                FeelEntry(tab.capitalized) { app in
                    let button = app.buttons["dock.\(tab)"].firstMatch
                    if button.waitForExistence(timeout: 10) { button.tap() }
                }
            }
            + [FeelEntry("Chefs") { app in
                let button = app.buttons["kitchen.chefs"].firstMatch
                if button.waitForExistence(timeout: 10) { button.tap() }
            }, FeelEntry("Account and settings") { app in
                let button = app.buttons["kitchen.account"].firstMatch
                if button.waitForExistence(timeout: 10) { button.tap() }
            }]
    }

    /// What a walk of the whole app taps: rows, links and buttons, but nothing that deletes, signs out, pays or sends
    /// (``FeelFollow/dangerous``), nor anything that saves or creates, so the fixture kitchen stays as seeded.
    static let follow = FeelFollow(
        types: [.cell, .link, .button],
        avoid: FeelFollow.dangerous + ["save", "create", "import", "upload", "camera", "photo", "invite", "rotate", "revoke"]
    )

    /// Every screen a cook lands on, each opened the way a cook opens it: as it lands and for two seconds after, nothing
    /// on it jumps once at rest, and nothing is drawn twice; a push, a sheet or cook mode also travels in (no snap) and
    /// settles within a second. Each screen's anchors are the texts it shows near its top that the screen under it
    /// did not, found by opening it once; the second opening is filmed by the app's recorder, frame by frame.
    func testEveryScreenLandsStill() {
        // FEEL_LANDING_ONLY (comma-separated screen names) narrows the run to those screens, to look again at one.
        let only = Set((ProcessInfo.processInfo.environment["FEEL_LANDING_ONLY"] ?? "").split(separator: ",").map(String.init))
        for screen in Self.everyLanding where only.isEmpty || only.contains(screen.name) {
            openApp()
            let feel = OuroFeel(app)
            screen.parent(app)
            let before = Self.texts(app)
            guard let door = screen.door(app), door.waitForExistence(timeout: 10) else {
                feel.expect(FeelResult(check: "landing", passed: false, summary: "\(screen.name): its way in was not on screen",
                                       findings: [.couldNotCheck("\(screen.name): its way in was not on screen, so it was not checked")]))
                continue
            }
            door.tap()
            Thread.sleep(forTimeInterval: 1.5)
            Self.keepScreenshot(app, named: screen.name)
            let anchors = screen.anchors.isEmpty ? Self.newTexts(app, before: before) : screen.anchors
            guard !anchors.isEmpty else {
                feel.expect(FeelResult(check: "landing", passed: false, summary: "\(screen.name): no text of its own to watch",
                                       findings: [.couldNotCheck("\(screen.name): it showed no text near its top that the screen under it did not, so it was not checked")]))
                continue
            }
            app.terminate()
            openApp()
            screen.parent(app)
            guard let again = screen.door(app), again.waitForExistence(timeout: 10) else {
                feel.expect(FeelResult(check: "landing", passed: false, summary: "\(screen.name): its way in was gone the second time",
                                       findings: [.couldNotCheck("\(screen.name): its way in was not on screen the second time, so it was not filmed")]))
                continue
            }
            let recorded = feel.recordedFilm(anchors) {
                again.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(2.5))
            }
            let slug = screen.name.lowercased().replacingOccurrences(of: " ", with: "-")
            // A text XCUITest reads may be part of a larger element in the app (a stat, a toolbar item), which the
            // recorder cannot find by that label. Watch the anchors it saw; with none seen, the screen is not checked.
            let seen = anchors.filter { !recorded.track($0).isEmpty }
            if seen.isEmpty {
                feel.expect(FeelResult(check: "landing", passed: false, summary: "\(screen.name): the recorder saw none of its texts",
                                       findings: [.couldNotCheck("\(screen.name): the app's recorder found none of \(anchors), so it was not checked")]))
                app.terminate()
                continue
            }
            for anchor in seen {
                Self.judge(feel.record(recorded.jumps(of: anchor), name: "\(slug)-jumps", film: recorded))
            }
            if screen.arrival == .travels, let first = seen.first {
                Self.judge(feel.record(recorded.snaps(of: first, appearing: true), name: "\(slug)-snaps"))
                Self.judge(feel.record(recorded.settles(first, within: 1.0), name: "\(slug)-settles"))
            }
            // Frame timing on the simulator is a proxy that depends on the Mac (and this is a debug build), so the
            // hitches are reported for each screen, not judged.
            let stamps = recorded.frames.map(\.t)
            if stamps.count > 2 {
                feel.record(FeelHitches.analyze(timestamps: stamps, refresh: 1.0 / 60).result(), name: "\(slug)-hitches")
            }
            let after = feel.film(seen, for: 1.5)
            Self.judge(feel.record(after.doubleDraws(of: seen), name: "\(slug)-double-draws", film: after))
            app.terminate()
        }
    }

    /// Fails the test on a failed result that `record` already wrote under its own name.
    static func judge(_ result: FeelResult, file: StaticString = #filePath, line: UInt = #line) {
        if !result.passed { XCTFail(result.text, file: file, line: line) }
    }

    /// How a screen arrives, which decides whether the snap and settle checks apply.
    enum Arrival {
        /// A push, a sheet or cook mode: its texts move in, so they must travel (no snap) and settle.
        case travels
        /// A tab, or a link that switches tabs: it appears at once, as a tab does.
        case appears
        /// A recipe page, which zooms out of its cover (`navigationTransition(.zoom)`): its texts fade in place, and the
        /// recorder sees an element's frame, not its opacity, so a snap or a settle cannot be told from a fade.
        case zooms
        /// A page fetched as it opens (a chef's page): it travels in on its loading state and crossfades to the page
        /// once it arrives (`ArrivingFromLoading`), so its texts appear in place, as a fade the recorder cannot see.
        case loads
    }

    /// A screen a cook lands on: where it opens from, the control that opens it, and how it arrives.
    struct Landing {
        let name: String
        let parent: (XCUIApplication) -> Void
        let door: (XCUIApplication) -> XCUIElement?
        var arrival = Arrival.travels
        var anchors: [String] = []
    }

    static func button(_ key: String) -> (XCUIApplication) -> XCUIElement? { { $0.buttons[key].firstMatch } }

    static func tap(_ key: String) -> (XCUIApplication) -> Void {
        { app in
            let button = app.buttons[key].firstMatch
            if button.waitForExistence(timeout: 10) { button.tap() }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    static func then(_ steps: ((XCUIApplication) -> Void)...) -> (XCUIApplication) -> Void {
        { app in steps.forEach { $0(app) } }
    }

    /// Every screen a cook lands on from the kitchen, each tab, Chefs and Account: 17.
    static var everyLanding: [Landing] {
        let kitchen: (XCUIApplication) -> Void = { _ in }
        let searchToast: (XCUIApplication) -> Void = { app in
            let field = app.searchFields.firstMatch
            if field.waitForExistence(timeout: 10) { field.tap(); field.typeText("toast\n") }
            Thread.sleep(forTimeInterval: 1.5)
        }
        let firstCookbook: (XCUIApplication) -> XCUIElement? = { app in
            app.descendants(matching: .any)["cookbookShelf"].buttons
                .matching(NSPredicate(format: "NOT (label ENDSWITH ', 0 recipes')")).firstMatch
        }
        let firstNumberedRecipe: (XCUIApplication) -> XCUIElement? = { app in
            app.buttons.matching(NSPredicate(format: "label MATCHES '^[0-9]+\\. .*'")).firstMatch
        }
        return [
            Landing(name: "Recipes tab", parent: kitchen, door: button("dock.recipes"), arrival: .appears),
            Landing(name: "Cookbooks tab", parent: kitchen, door: button("dock.cookbooks"), arrival: .appears),
            Landing(name: "Shopping List tab", parent: kitchen, door: button("dock.shopping"), arrival: .appears),
            Landing(name: "Search tab", parent: kitchen, door: button("dock.search"), arrival: .appears),
            Landing(name: "Kitchen tab", parent: tap("dock.recipes"), door: button("dock.kitchen"), arrival: .appears),
            Landing(name: "Recipe", parent: kitchen, door: button("kitchen.recipe.open"), arrival: .zooms,
                    anchors: ["recipeDetail.title"]),
            // See all switches to the Recipes tab, so it appears as a tab does rather than travelling in.
            Landing(name: "All recipes", parent: kitchen, door: button("kitchen.recipes.seeAll"), arrival: .appears),
            // Everyone's recipes: the fixture kitchen's recipes are another chef's, so Mine and Saved are empty there.
            // The fixture chef owns the fixture recipes in these checks (check-feel.sh), so the Recipes tab lists them
            // without the network.
            Landing(name: "Recipe from Recipes", parent: tap("dock.recipes"),
                    door: { $0.descendants(matching: .any)["recipes.row"].firstMatch }, arrival: .zooms,
                    anchors: ["recipeDetail.title"]),
            Landing(name: "Cookbook", parent: tap("dock.cookbooks"), door: firstCookbook),
            Landing(name: "Recipe in a cookbook", parent: then(tap("dock.cookbooks"), { app in
                if let book = firstCookbook(app), book.waitForExistence(timeout: 10) { book.tap() }
                Thread.sleep(forTimeInterval: 1)
            }), door: firstNumberedRecipe, arrival: .zooms, anchors: ["recipeDetail.title"]),
            Landing(name: "Chefs", parent: kitchen, door: button("kitchen.chefs")),
            Landing(name: "Chef", parent: tap("kitchen.chefs"), door: button("chefs.chef.row"), arrival: .loads),
            Landing(name: "Search result", parent: then(tap("dock.search"), searchToast), door: button("search.result"),
                    arrival: .zooms, anchors: ["recipeDetail.title"]),
            Landing(name: "Cook mode", parent: kitchen, door: button("kitchen.recipe.cook")),
            Landing(name: "Account and settings", parent: kitchen, door: button("kitchen.account")),
            Landing(name: "Add a recipe", parent: kitchen, door: button("kitchen.addRecipe")),
            // Add from recipe switches to the Search tab.
            Landing(name: "Add from recipe", parent: tap("dock.shopping"), door: { app in
                app.buttons.matching(NSPredicate(format: "label == 'Add from recipe' OR identifier == 'book'")).firstMatch
            }, arrival: .appears),
        ]
    }

    /// Every label on screen, top to bottom, each marked whether it is a text of its own: a static text that is not
    /// part of a button or a link (the app's recorder finds an element by its own label, and a button's text has none).
    static func texts(_ app: XCUIApplication) -> [(label: String, y: CGFloat, own: Bool)] {
        guard let root = try? app.snapshot() else { return [] }
        var found: [(String, CGFloat, Bool)] = []
        var stack: [(XCUIElementSnapshot, Bool)] = [(root, false)]
        let window = root.frame
        while let (node, inControl) = stack.popLast() {
            let control = inControl || node.elementType == .button || node.elementType == .link
            stack.append(contentsOf: node.children.map { ($0, control) })
            guard !node.label.isEmpty, node.frame.width > 0, node.frame.height > 0, window.intersects(node.frame) else { continue }
            found.append((node.label, node.frame.minY, node.elementType == .staticText && !inControl))
        }
        return found.sorted { $0.1 < $1.1 }
    }

    /// Keeps what the screen looked like when its anchors were chosen, beside the reports.
    static func keepScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "landing-\(name)"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Landed on \(name)") { $0.add(attachment) }
        if let dir = ProcessInfo.processInfo.environment["OURO_FEEL_REPORT_DIR"], !dir.isEmpty {
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("landing-\(slug).png"))
        }
    }

    /// Up to three texts of its own near the top of the screen now whose words were nowhere on the screen before (not
    /// even as a tab's name), each shown once (a label shown twice on purpose would read as a double draw) and short
    /// enough to be a title rather than a paragraph.
    static func newTexts(_ app: XCUIApplication, before: [(label: String, y: CGFloat, own: Bool)]) -> [String] {
        let old = Set(before.map(\.label))
        let now = texts(app)
        let counts = Dictionary(now.map { ($0.label, 1) }, uniquingKeysWith: +)
        var picked: [String] = []
        for text in now where text.own && !old.contains(text.label) && counts[text.label] == 1 && text.label.count <= 60 {
            picked.append(text.label)
            if picked.count == 3 { break }
        }
        return picked
    }

    /// On iPad in portrait the library sidebar is an overlay: picking a section closes it, and so does a tap beside
    /// it (jank item 8: it stayed open).
    func testTheSidebarClosesOncePicked() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "The sidebar is an overlay only on iPad.")
        openApp()
        let feel = OuroFeel(app)
        let open = FeelOverlay("library sidebar", overlay: "sidebar.addRecipe", pick: "Saved Recipes") { app in
            let toggle = app.buttons.matching(NSPredicate(format: "label == 'Show Sidebar' OR identifier == 'ToggleSidebar'")).firstMatch
            if toggle.waitForExistence(timeout: 10) { toggle.tap() }
        }
        feel.expect(feel.overlays([open]))
    }
}
