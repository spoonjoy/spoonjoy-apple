import SpoonjoyCore
import XCTest

/// Cook mode's hands-free mic against the real OS. A simulator has no voice to speak, so the app hears scripted
/// transcripts instead of the microphone (`NativeJourneyVoiceFixture`). Leaving the app turns the mic off, and at the
/// largest text size the mic's listening line stays inside the window above the step heading. The command parser,
/// the listener's states and the actions they run are proved headless in SpoonjoyReinsTests.
@MainActor
final class VoiceJourney: JourneyTestCase {
    func testVoiceCommandsDriveCookModeJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Voice J4"
        let garlic = "Journey\(token)garlic"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Toast the garlic",
                    description: "Toast the garlic in oil until golden.",
                    duration: 5,
                    ingredients: [RecipeIngredientDraft(quantity: 3, unit: "clove", name: garlic)],
                    outputStepNums: []
                ),
                RecipeStepDraft(stepNum: 2, stepTitle: "Add the tomatoes", description: "Add the tomatoes and stir.", duration: nil, ingredients: [], outputStepNums: []),
                RecipeStepDraft(stepNum: 3, stepTitle: "Serve", description: "Spoon over pasta.", duration: nil, ingredients: [], outputStepNums: [])
            ]
        )
        let journey = JourneyApp.launchFresh()
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        // A sentence that is not a command, so the mic listens without turning the page.
        journey.useVoiceFixtureOnNextLaunch("the next thing is garlic and onions")
        journey.openLink(cookLink)
        let mic = journey.element(JourneyID.cookVoice)
        XCTAssertTrue(mic.waitForExistence(timeout: JourneyApp.networkTimeout), "Cook mode has no mic. Screen: \(journey.screen)")
        mic.tap()
        XCTAssertTrue(waitForLabel(mic, prefix: "Listening"), "Tapping the mic did not start listening. Label: \(mic.label)")
        journey.attachScreenshot(named: "voice-02-mic-listening", to: self)

        // OS: leaving the app stops the mic, and it stays off when the cook comes back. The open-flat Duo simulator keeps
        // the app in the foreground when Home is pressed, so there the step records that it could not leave instead.
        XCUIDevice.shared.press(.home)
        let leftTheScreen = journey.app.wait(for: .runningBackground, timeout: JourneyApp.interactionTimeout)
            || journey.app.state == .runningBackgroundSuspended
        // Only the Duo simulator may keep the app in front; on every other phone Home must background it.
        XCTAssertTrue(
            leftTheScreen || JourneyApp.runsOnRealHinge,
            "Home did not move the app to the background. State: \(journey.app.state.rawValue)"
        )
        if leftTheScreen {
            journey.app.activate()
        } else {
            let note = XCTAttachment(string: "Home left the app in state \(journey.app.state.rawValue) on this simulator; the background step was not exercised, so the mic is turned off by tapping it.")
            note.name = "voice-background-not-exercised"
            note.lifetime = .keepAlways
            add(note)
            mic.tap()
        }
        XCTAssertTrue(mic.waitForExistence(timeout: JourneyApp.interactionTimeout), "Cook mode did not come back. Screen: \(journey.screen)")
        XCTAssertTrue(waitForLabel(mic, prefix: "Listen for next"), "The mic kept listening. Label: \(mic.label)")

        // UI: at the largest text size the mic stays in the toolbar and its line wraps instead of clipping.
        journey.useLargestAccessibilityTextOnNextLaunch()
        journey.useVoiceFixtureOnNextLaunch("okay next step")
        verifyAfterRelaunch(journey) {
            journey.openLink(cookLink)
            let notice = journey.element(JourneyID.cookVoiceNotice)
            XCTAssertTrue(mic.waitForExistence(timeout: JourneyApp.networkTimeout), "Cook mode has no mic at the largest text size. Screen: \(journey.screen)")
            mic.tap()
            XCTAssertTrue(waitForLabel(mic, prefix: "Listening"), "The mic did not listen at the largest text size. Label: \(mic.label)")
            XCTAssertTrue(notice.waitForExistence(timeout: JourneyApp.interactionTimeout), "Listening said nothing at the largest text size.")
            let window = journey.app.windows.firstMatch.frame
            XCTAssertTrue(window.contains(notice.frame), "The listening line runs off the screen at the largest text size.")
            let heading = stepMeta(journey, "Step 1 of 3")
            XCTAssertTrue(heading.waitForExistence(timeout: JourneyApp.interactionTimeout), "Cook mode lost its step heading at the largest text size.")
            XCTAssertLessThanOrEqual(notice.frame.maxY, heading.frame.minY + 1, "The listening line covers the step heading at the largest text size.")
            journey.attachScreenshot(named: "voice-06-mic-listening-ax5", to: self)
        }
    }

    private func stepMeta(_ journey: JourneyApp, _ text: String) -> XCUIElement {
        journey.element(JourneyID.cookStepMeta, labelContaining: text)
    }

    /// The mic's label carries its state (Listen for…, Listening, Voice unavailable).
    private func waitForLabel(_ element: XCUIElement, prefix: String) -> Bool {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: JourneyApp.interactionTimeout) == .completed
    }
}
