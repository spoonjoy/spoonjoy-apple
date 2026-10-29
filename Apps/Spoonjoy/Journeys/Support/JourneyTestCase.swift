import XCTest

/// Base class for every journey: stop at the first failure, give each test an explicit time limit, and leave no
/// signed-in QA session behind for the next launch.
@MainActor
class JourneyTestCase: XCTestCase {
    /// Set by a journey whose saved state a later workflow step reads, such as the Duo tour's running timer.
    var keepsAppStateAfterTest = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        executionTimeAllowance = 600
    }

    // The async teardown runs on the main actor, where the app and this flag live; the synchronous one does not.
    override func tearDown() async throws {
        if !keepsAppStateAfterTest {
            JourneyApp.clearSavedState()
        }
        try await super.tearDown()
    }
}
