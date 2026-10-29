import SpoonjoyCore
import XCTest

/// Cook mode's hands-free mic. A simulator has no voice to speak, so the app hears scripted transcripts instead of the
/// microphone (`NativeJourneyVoiceFixture`); the parser, the listener's states and the actions they run are the real
/// ones. "okay next step" turns the page, a sentence with "next" inside it does nothing, "go back" turns back, "start
/// the timer" starts the step's timer and "check all" checks the step's ingredients. Leaving the app turns the mic
/// off. A refused microphone shows the mic as unavailable with a line pointing to Settings, and no prompt.
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
        journey.useVoiceFixtureOnNextLaunch("okay next step|the next thing is garlic and onions|go back|start the timer|check all")
        journey.openLink(cookLink)
        let mic = journey.element(JourneyID.cookVoice)
        XCTAssertTrue(mic.waitForExistence(timeout: JourneyApp.networkTimeout), "Cook mode has no mic. Screen: \(journey.screen)")
        XCTAssertTrue(stepMeta(journey, "Step 1 of 3").exists, "Cook mode did not open on step 1. Screen: \(journey.screen)")
        XCTAssertTrue(mic.label.hasPrefix("Listen for next"), "The mic was on before the cook turned it on. Label: \(mic.label)")
        journey.attachScreenshot(named: "voice-01-mic-off", to: self)

        mic.tap()
        XCTAssertTrue(waitForLabel(mic, prefix: "Listening"), "Tapping the mic did not start listening. Label: \(mic.label)")
        let notice = journey.element(JourneyID.cookVoiceNotice)
        XCTAssertTrue(
            notice.waitForExistence(timeout: JourneyApp.interactionTimeout) && notice.label.contains("Listening for next, back, repeat, timer"),
            "Listening did not say what it listens for. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "voice-02-mic-listening", to: self)

        XCTAssertTrue(
            stepMeta(journey, "Step 2 of 3").waitForExistence(timeout: 15),
            "\"okay next step\" did not turn to step 2. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "voice-03-heard-next", to: self)
        // "the next thing is garlic and onions" must not turn the page, so "go back" lands on step 1, not step 2.
        XCTAssertTrue(
            stepMeta(journey, "Step 1 of 3").waitForExistence(timeout: 20),
            "\"go back\" did not return to step 1, so a sentence with \"next\" inside it turned the page. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.cookTimerRunning).waitForExistence(timeout: 15),
            "\"start the timer\" did not start step 1's timer. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "voice-04-heard-timer", to: self)
        let garlicRow = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: garlic)
        XCTAssertTrue(
            waitForValue(garlicRow, in: ["1", "checked"], timeout: 15),
            "\"check all\" did not check the garlic. Value: \(String(describing: garlicRow.value))"
        )
        XCTAssertEqual(
            journey.app.descendants(matching: .any).matching(identifier: JourneyID.cookTimerRunning).count,
            1,
            "Checking the step after \"start the timer\" set a second timer."
        )

        // Leaving the app stops the mic, and it stays off when the cook comes back. The open-flat Duo simulator keeps
        // the app in the foreground when Home is pressed, so there the step records that it could not leave instead.
        XCUIDevice.shared.press(.home)
        if journey.app.wait(for: .runningBackground, timeout: JourneyApp.interactionTimeout)
            || journey.app.state == .runningBackgroundSuspended {
            journey.app.activate()
            XCTAssertTrue(mic.waitForExistence(timeout: JourneyApp.interactionTimeout), "Cook mode did not come back. Screen: \(journey.screen)")
            XCTAssertTrue(waitForLabel(mic, prefix: "Listen for next"), "The mic kept listening after the app left the screen. Label: \(mic.label)")
        } else {
            let note = XCTAttachment(string: "Home left the app in state \(journey.app.state.rawValue) on this simulator; the background step was not exercised.")
            note.name = "voice-background-not-exercised"
            note.lifetime = .keepAlways
            add(note)
            mic.tap()
            XCTAssertTrue(waitForLabel(mic, prefix: "Listen for next"), "Tapping the mic did not stop listening. Label: \(mic.label)")
        }
        journey.tap(JourneyID.cookTimerCancel)

        // A refused microphone: the mic shows as unavailable and says where to allow it, without a prompt.
        journey.useVoiceFixtureOnNextLaunch("denied")
        journey.openLink(cookLink)
        XCTAssertTrue(mic.waitForExistence(timeout: JourneyApp.networkTimeout), "Cook mode has no mic after relaunch. Screen: \(journey.screen)")
        mic.tap()
        XCTAssertTrue(waitForLabel(mic, prefix: "Voice unavailable"), "A refused microphone did not show the mic as unavailable. Label: \(mic.label)")
        XCTAssertTrue(
            notice.waitForExistence(timeout: JourneyApp.interactionTimeout) && notice.label.contains("Settings"),
            "A refused microphone did not say to allow it in Settings. Screen: \(journey.screen)"
        )
        XCTAssertFalse(journey.app.alerts.firstMatch.exists, "A refused microphone asked again.")
        journey.attachScreenshot(named: "voice-05-mic-unavailable", to: self)

        // At the largest text size the mic stays in the toolbar and its line wraps instead of clipping.
        journey.useLargestAccessibilityTextOnNextLaunch()
        journey.useVoiceFixtureOnNextLaunch("okay next step")
        journey.openLink(cookLink)
        XCTAssertTrue(mic.waitForExistence(timeout: JourneyApp.networkTimeout), "Cook mode has no mic at the largest text size. Screen: \(journey.screen)")
        mic.tap()
        XCTAssertTrue(waitForLabel(mic, prefix: "Listening"), "The mic did not listen at the largest text size. Label: \(mic.label)")
        XCTAssertTrue(notice.waitForExistence(timeout: JourneyApp.interactionTimeout), "Listening said nothing at the largest text size.")
        let window = journey.app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(notice.frame), "The listening line runs off the screen at the largest text size.")
        journey.attachScreenshot(named: "voice-06-mic-listening-ax5", to: self)
    }

    private func stepMeta(_ journey: JourneyApp, _ text: String) -> XCUIElement {
        journey.element(JourneyID.cookStepMeta, labelContaining: text)
    }

    /// The mic's label carries its state (Listen for…, Listening, Voice unavailable).
    private func waitForLabel(_ element: XCUIElement, prefix: String) -> Bool {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: JourneyApp.interactionTimeout) == .completed
    }

    private func waitForValue(_ element: XCUIElement, in values: [String], timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value IN %@", values)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }
}
