import SpoonjoyCore
import XCTest

/// The parity capture on the iPhone Duo, open flat and held sideways like the web's 951 x 669 open Duo: every canonical
/// screen in light and dark (see `ParityCapture`). The open Duo's outer display is off, so the shot that counts is the
/// Mac's screenshot of the inner display, `parity-<screen>-duo-open-<scheme>-inner.png`, saved by the posture driver
/// and kept in the result bundle as well.
///
/// XCTest runs the target's classes in name order, so this runs before DuoJourney, on a Duo no journey has turned yet.
@MainActor
final class DuoCanonicalScreensJourney: JourneyTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        executionTimeAllowance = 1200
    }

    func testCanonicalScreensOnTheOpenDuoJourney() async throws {
        let account = try JourneyAccounts.account(2)
        try DuoHinge.set(.closed)
        XCUIDevice.shared.orientation = .portrait
        try DuoHinge.set(.open)
        let journey = JourneyApp.launchFresh()
        let capture = ParityCapture(journey: journey, device: "duo-open") { [self] name in
            try DuoHinge.shot(name)
            try DuoHinge.attachShot(name, to: self)
        }

        try capture.signInScreen()
        // Signed in by the Mac, as in DuoJourney: the sign-in form's paste fails on the Duo simulator.
        try DuoHinge.installSession(try await JourneyQAClient.nativeSession(account))
        journey.relaunch()
        try capture.emptyKitchen()

        let kitchen = try await ParityCapture.seed(account)
        // The kitchen QA now holds reaches the app on a cold start.
        try verifyAfterRelaunch(journey) {
            try capture.kitchen()
        }
        try capture.recipe(kitchen)
        try capture.shopping()
        try capture.cookbooks()
        try capture.cookbook(kitchen)
        try capture.chef(kitchen)
        try capture.addToListSheet(kitchen)
        // A relaunch closes the Reminders sheet; cook mode comes last, as it puts the recipe under Cooking now.
        journey.relaunch()
        try capture.cookStep(kitchen)
    }
}
