import XCTest

/// iOS 1.2 and 1.2.1 closed at launch on iPhones, every time, until a fix shipped (#355). Launch safe mode ends a loop
/// like that: after two launches in a row that never finished opening, the next one shows a plain page with
/// Try again instead of the shell.
///
/// A launch finishes once the shell has been up and active for three seconds. The test fails two launches in a row:
/// one with `-SpoonjoyLaunchSafeModeNeverSucceed` (the shell comes up but never counts as finished, and the app is
/// killed) and one with `-SpoonjoyLaunchSafeModeCrashShell` (a real crash while the shell is built), so the count is
/// carried across real process deaths, including a crash. Debug builds only count launches when `-SpoonjoyLaunchSafeModeArmed`
/// is passed, so every other UI test's quick relaunches leave it alone.
///
/// It uses the hermetic shopping fixture in the real tabbed shell (PlatformNavigationView, where the 1.2 crash was), so
/// it needs no account or network. The Shopping UI tests job in journeys.yml runs it with the rest of this target.
@MainActor
final class LaunchSafeModeUITests: XCTestCase {
    private static let armed = "-SpoonjoyLaunchSafeModeArmed"
    private static let preset = "-SpoonjoyLaunchSafeModeUnfinishedLaunches"
    private static let neverSucceed = "-SpoonjoyLaunchSafeModeNeverSucceed"
    private static let crashShell = "-SpoonjoyLaunchSafeModeCrashShell"
    /// Longer than the three seconds after which a shell that stays up counts as a finished launch.
    private static let pastSuccessDelay: TimeInterval = 5

    private var launchedApp: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Async, for the same reason as SpoonjoyShoppingUITests.tearDown: terminate() is main-actor isolated.
    override func tearDown() async throws {
        try await super.tearDown()
        await MainActor.run {
            continueAfterFailure = true
            if let launchedApp, launchedApp.state != .notRunning {
                launchedApp.terminate()
            }
            launchedApp = nil
        }
    }

    func testTwoUnfinishedLaunchesOpenTheSafePageAndTryAgainBringsTheShellBack() {
        // 1. A launch that reaches the shell but never finishes, ended by killing the app. It starts the count from
        // zero, whatever an earlier run left.
        let first = launch([Self.preset, "0", Self.neverSucceed])
        assertShell(first, "The first unfinished launch did not open the shell.")
        pause(Self.pastSuccessDelay)
        first.terminate()

        // 2. A real crash while the shell is built.
        crashingLaunch()

        // 3. The next launch opens the safe page instead of the shell.
        let app = launch()
        let safePage = app.descendants(matching: .any)["launchSafeMode.root"]
        XCTAssertTrue(safePage.waitForExistence(timeout: 15), "After two unfinished launches the safe page did not open. \(app.debugDescription)")
        XCTAssertTrue(app.staticTexts["A quiet start"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["shopping.ui-test.root"].exists, "The shell was built behind the safe page.")
        attachScreenshot(app, named: "launch-safe-mode")

        // Try again loads the normal shell.
        let tryAgain = app.buttons["launchSafeMode.tryAgain"]
        XCTAssertTrue(tryAgain.waitForExistence(timeout: 5))
        tryAgain.tap()
        assertShell(app, "Try again did not bring the shell back.")
        XCTAssertFalse(safePage.exists, "The safe page stayed after Try again.")

        // 4. That shell stays up past the delay, so it finished and the count is back to zero. One more unfinished
        // launch is then not enough: the launch after it is normal.
        pause(Self.pastSuccessDelay)
        app.terminate()
        let unfinished = launch([Self.neverSucceed])
        assertShell(unfinished, "An unfinished launch after a finished one did not open the shell.")
        unfinished.terminate()

        let relaunched = launch()
        assertShell(relaunched, "One unfinished launch after a finished one sent the next to the safe page.")
        XCTAssertFalse(relaunched.descendants(matching: .any)["launchSafeMode.root"].exists, "The safe page came back after a finished launch.")
    }

    /// Launches with the shell set to crash as it is built, and waits for the app to die. XCTest may report the crash
    /// while launching; that report is expected, so it is allowed without being required.
    private func crashingLaunch() {
        let app = XCUIApplication()
        configure(app, extra: [Self.crashShell])
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        continueAfterFailure = true
        XCTExpectFailure("The app crashes on purpose while its shell is built.", options: options) {
            app.launch()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 30), "The crashing launch did not stop the app.")
        }
        continueAfterFailure = false
        XCTAssertEqual(app.state, .notRunning, "The shell crash did not stop the app.")
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        configure(app, extra: extra)
        app.launch()
        launchedApp = app
        return app
    }

    private func configure(_ app: XCUIApplication, extra: [String]) {
        // The fixture never bootstraps the live store; the QA URL is defense in depth, as in SpoonjoyShoppingUITests.
        app.launchEnvironment["SPOONJOY_API_BASE_URL"] = "https://spoonjoy-v2-qa.mendelow-studio.workers.dev"
        app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_FIXTURE"] = "1"
        app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_PLATFORM"] = "1"
        app.launchEnvironment["SPOONJOY_SHOPPING_UI_TEST_STATE"] = Self.shoppingStateJSON
        app.launchEnvironment["OS_ACTIVITY_DT_MODE"] = "NO"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", Self.armed] + extra
    }

    private func assertShell(_ app: XCUIApplication, _ message: String) {
        XCTAssertTrue(app.descendants(matching: .any)["shopping.ui-test.root"].waitForExistence(timeout: 15), "\(message) \(app.debugDescription)")
        XCTAssertTrue(app.tabBars.buttons["Search"].firstMatch.waitForExistence(timeout: 8), "\(message) No tab bar. \(app.debugDescription)")
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "wait \(seconds)s")], timeout: seconds)
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static let shoppingStateJSON = #"{"id":"launch_safe_mode","chef":{"id":"chef_ui_test","username":"ui-test"},"items":[{"id":"item_lemons","name":"lemons","quantity":2,"unit":"each","checked":false,"checkedAt":null,"deletedAt":null,"categoryKey":"produce","iconKey":"citrus","sortIndex":0,"updatedAt":"2026-08-21T20:00:00.000Z"}],"nextCursor":"ui-test","updatedAt":"2026-08-21T20:01:00.000Z"}"#
}
