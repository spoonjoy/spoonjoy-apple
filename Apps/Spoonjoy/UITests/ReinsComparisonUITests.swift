import XCTest

/// SPIKE (W13, Ouro Reins). The XCUITest twin of `Tests/SpoonjoyReinsTests/KitchenToCookJourneyTests.swift`: the same
/// journey over the same fixture kitchen (seeded by scripts/check-motion.sh), timed, so the two can be compared.
///
///   scripts/check-motion.sh <udid> <derived data> ReinsComparisonUITests
///
/// Kitchen → recipe → Start cooking → next step → previous step → close cook → back to the Kitchen. Each run relaunches
/// the app; the report separates launch from the journey.
@MainActor
final class ReinsComparisonUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[ShellNavigationDriver.fixtureVariable] == "1",
            "Needs the seeded fixture kitchen; run scripts/check-motion.sh."
        )
    }

    func testKitchenToCookAndBackTimed() throws {
        let runs = Int(ProcessInfo.processInfo.environment["REINS_UI_RUNS"] ?? "") ?? 5
        var launches: [Double] = []
        var journeys: [Double] = []
        for run in 0..<runs {
            app?.terminate()
            let launchStart = Date()
            app = ShellNavigationDriver.launch()
            XCTAssertTrue(element("kitchen.root").waitForExistence(timeout: 60), "The fixture kitchen did not open.")
            launches.append(Date().timeIntervalSince(launchStart) * 1000)

            let start = Date()
            element("kitchen.recipe.open").tap()
            let cook = element("recipeDetail.cook")
            XCTAssertTrue(cook.waitForExistence(timeout: 30), "The recipe did not open.")
            cook.tap()
            let meta = element("cook.step.meta")
            XCTAssertTrue(meta.waitForExistence(timeout: 30), "Cook mode did not open.")
            wait(for: meta, labelContaining: "Step 1 of 3")
            element("cook.page").swipeLeft()
            wait(for: meta, labelContaining: "Step 2 of 3")
            element("cook.page").swipeRight()
            wait(for: meta, labelContaining: "Step 1 of 3")
            element("cook.close").tap()
            XCTAssertTrue(cook.waitForExistence(timeout: 30), "Closing cook mode did not return to the recipe.")
            ShellNavigationDriver(app: app).backButton.tap()
            XCTAssertTrue(element("kitchen.root").waitForExistence(timeout: 30), "Back did not return to the Kitchen.")
            journeys.append(Date().timeIntervalSince(start) * 1000)
            if run == 0 {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "reins-comparison-kitchen-after-journey"
                shot.lifetime = .keepAlways
                add(shot)
            }
        }
        let line = "[reins-spike-ui] \(runs) runs; launch ms \(launches.map { Int($0) }); journey ms \(journeys.map { Int($0) }); "
            + "median launch \(Int(median(launches))) ms, median journey \(Int(median(journeys))) ms"
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "reins-comparison-timing"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func wait(for element: XCUIElement, labelContaining text: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 30), .completed, "\(element) never read \(text); it reads \(element.label)", file: file, line: line)
    }

    private func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
}
