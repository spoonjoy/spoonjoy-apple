import XCTest

/// Journey 1: a wrong password is rejected, sign-in works by username and by email, a relaunch
/// keeps the session, the build talks to the QA mirror, and signing out ends the session.
@MainActor
final class SignInJourney: JourneyTestCase {
    func testSignInOutJourney() throws {
        let account = try JourneyAccounts.account(1)
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: JourneyQA.rejectedPassword)
        XCTAssertTrue(
            journey.element(JourneyID.signInStatus, labelContaining: JourneyCopy.wrongPasswordStatus)
                .waitForExistence(timeout: JourneyApp.networkTimeout),
            "A wrong password did not show the sign-in error."
        )
        XCTAssertFalse(journey.element(JourneyID.kitchenRoot).exists)

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in by username did not open the kitchen."
        )

        verifyAfterRelaunch(journey) {
            XCTAssertTrue(
                journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
                "The session did not survive a relaunch."
            )
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists)
        }

        journey.openSettings()
        journey.assertQAEnvironment()
        journey.signOut()
        journey.closeSettings()
        XCTAssertTrue(
            journey.element(JourneyID.passwordSignIn).waitForExistence(timeout: JourneyApp.launchTimeout),
            "Signing out did not return to the sign-in screen."
        )

        verifyAfterRelaunch(journey) {
            XCTAssertTrue(
                journey.element(JourneyID.passwordSignIn).waitForExistence(timeout: JourneyApp.launchTimeout),
                "The app was signed in again after a relaunch."
            )
            XCTAssertFalse(journey.element(JourneyID.kitchenRoot).exists)
        }

        journey.signIn(as: account.email, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in by email did not open the kitchen."
        )
    }
}
