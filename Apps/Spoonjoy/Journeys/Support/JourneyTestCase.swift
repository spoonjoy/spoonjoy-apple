import XCTest

/// Base class for every journey: stop at the first failure and give each test an explicit time limit.
@MainActor
class JourneyTestCase: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        executionTimeAllowance = 600
    }
}
