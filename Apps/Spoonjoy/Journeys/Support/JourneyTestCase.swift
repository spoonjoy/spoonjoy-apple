import XCTest

/// Base class for every journey: stop at the first failure, give each test an explicit time limit, and leave no
/// signed-in QA session behind for the next launch.
@MainActor
class JourneyTestCase: XCTestCase {
    /// Set by a journey whose saved state a later workflow step reads, such as the Duo tour's running timer.
    /// Set from the test body and read in the synchronous teardown; both run on the main thread.
    nonisolated(unsafe) var keepsAppStateAfterTest = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        executionTimeAllowance = 600
    }

    // XCTest calls the synchronous teardown on the main thread. The async one hung after an assertion failure in an
    // async journey (ModerationJourney, Journeys run 40967650456), so this stays synchronous.
    nonisolated override func tearDown() {
        if !keepsAppStateAfterTest {
            MainActor.assumeIsolated {
                JourneyApp.clearSavedState()
            }
        }
        super.tearDown()
    }
}
