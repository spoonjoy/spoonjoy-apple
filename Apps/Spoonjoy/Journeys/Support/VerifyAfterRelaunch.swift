import XCTest

/// Terminates and relaunches the app (keeping its state), then runs the assertions that prove a
/// change survived. Every journey test calls this after it changes something.
@MainActor
func verifyAfterRelaunch(
    _ journey: JourneyApp,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ assertions: () throws -> Void
) rethrows {
    journey.relaunch()
    XCTAssertTrue(
        journey.app.wait(for: .runningForeground, timeout: JourneyApp.launchTimeout),
        "The app did not come back to the foreground after a relaunch.",
        file: file,
        line: line
    )
    try assertions()
}
