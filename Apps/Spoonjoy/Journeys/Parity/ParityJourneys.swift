import SpoonjoyCore
import XCTest

/// The parity capture on the iPhone and the iPad: every canonical screen in light and dark, kept in the result bundle
/// as `parity-<screen>-<device>-<scheme>` for `scripts/parity-sheet.rb` (see `ParityCapture`). It is its own target,
/// SpoonjoyParityJourneys, which the Parity capture job runs on each device with an account of its own.
@MainActor
final class ParityJourneys: JourneyTestCase {
    func testParityScreensJourney() async throws {
        let account = try JourneyAccounts.account(1)
        // Every shot starts upright; on the iPad, ParityCapture turns it on its side for the landscape shot and back.
        ParityCapture.turn(.portrait)
        let journey = JourneyApp.launchFresh()
        let capture = ParityCapture(journey: journey, device: ParityCapture.deviceName) { [self] name in
            journey.attachScreenshot(named: name, to: self)
        }

        try capture.signInScreen()
        journey.signIn(as: account.username, password: account.password)
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
