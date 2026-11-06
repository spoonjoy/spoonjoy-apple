import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// Headless VoiceJourney (`Apps/Spoonjoy/Journeys/VoiceJourney.swift`): the mic hears the live journey's own scripted
/// phrases through `NativeJourneyVoiceFixture`, and the parser, the listener's states and the actions they run are the
/// app's (`CookVoiceController`, `CookVoiceAction`, `CookModeSessionResolver.perform`).
@MainActor
@Suite("VoiceJourney", .serialized)
struct VoiceJourneyTests {
    static let recipe = "recipe_voice"
    static let garlic = "ing_garlic"

    static let kitchen = SpoonjoyJourneyKitchen(recipes: [
        .init(recipe, "Journey Voice J4", steps: [
            .init("step_toast", title: "Toast the garlic", "Toast the garlic in oil until golden.", minutes: 5, ingredients: [.init(garlic, "garlic", 3, "clove")]),
            .init("step_tomatoes", title: "Add the tomatoes", "Add the tomatoes and stir."),
            .init("step_serve", title: "Serve", "Spoon over pasta."),
        ]),
    ])

    private func fixtures(_ voice: NativeJourneyVoiceFixture?) -> SpoonjoyReinsFixtures {
        var fixtures = SpoonjoyReinsFixtures()
        fixtures.cook.voice = voice
        return fixtures
    }

    private func micLabel(_ screen: ReinsScreen) -> String {
        screen.state["mic"]?["label"]?.stringValue ?? ""
    }

    @Test func testVoiceCommandsDriveCookModeJourney() async throws {
        try await headless {
            #expect(SpoonjoyReinsCookFixtures.voiceJourneyPhrases == .transcripts(["okay next step", "the next thing is garlic and onions", "go back", "start the timer", "check all"]))
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures(SpoonjoyReinsCookFixtures.voiceJourneyPhrases))
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" })

            // 42-45: the mic starts off, on step 1.
            #expect(app.screen.state["step"] == "Step 1 of 3")
            #expect(micLabel(app.screen).hasPrefix("Listen for next"))
            #expect(app.screen.state["mic"]?["listening"] == false)

            // 48-54: tapping the mic listens and says what it listens for.
            try await app.journey.do("toggleMic", until: { micLabel($0).hasPrefix("Listening") })
            try await app.journey.expect("cook", describing: "listening says what it listens for") {
                $0.state["voiceNotice"]?["text"]?.stringValue?.contains("Say next, back, repeat or timer when you're ready") == true
            }

            // 57-60: "okay next step" turns to step 2.
            try await app.journey.expect("cook", describing: "\"okay next step\" turned to step 2") { $0.state["step"] == "Step 2 of 3" }
            // 63-66: the sentence with "next" in it does nothing, so "go back" lands on step 1, not step 2.
            try await app.journey.expect("cook", describing: "\"go back\" returned to step 1") { $0.state["step"] == "Step 1 of 3" }
            // 67-70: "start the timer" starts step 1's timer.
            try await app.journey.expect("cook", describing: "\"start the timer\" started step 1's timer") { $0.state["ring"]?["running"] == true }
            // 72-81: "check all" checks the garlic and sets no second timer.
            try await app.journey.expect("cook", describing: "\"check all\" checked the garlic") { $0.state["ingredients"]?[0]?["checked"] == true }
            try await Task.sleep(for: .milliseconds(400))
            #expect(app.screen.state["runningTimers"] == 1)
            #expect(app.shell.cook.scheduledAlarms.count == 1, "checking the step after \"start the timer\" set a second timer")

            // 85-103 (P live; the rule runs here): leaving the app stops the mic, and it stays off on return.
            try await app.journey.do("leaveApp", until: { $0.state["app"] == "background" })
            try await app.journey.do("returnToApp", until: { micLabel($0).hasPrefix("Listen for next") })
            try await app.journey.do("cancelTimer", until: { $0.state["ring"]?["running"] == false })

            // 107-117: the voice check is saved, and the mic never comes back on by itself.
            try await app.relaunch()
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" })
            try await app.journey.expect("cook", describing: "the voice-checked garlic was saved") { $0.state["ingredients"]?[0]?["checked"] == true }
            #expect(micLabel(app.screen).hasPrefix("Listen for next"), "the mic came back on after a relaunch")

            // 120-133: a refused mic shows as unavailable and points to Settings, without a prompt.
            try await app.relaunch(fixtures: fixtures(.denied))
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" })
            try await app.journey.do("toggleMic", until: { micLabel($0).hasPrefix("Voice unavailable") })
            try await app.journey.expect("cook", describing: "a refused mic says to allow it in Settings") {
                $0.state["voiceNotice"]?["text"]?.stringValue?.contains("Settings") == true && $0.state["voiceNotice"]?["settings"] == true
            }
            try await app.journey.do("openVoiceSettings", until: { _ in app.shell.cook.openedURLs == ["app-settings:"] })
        }
    }
}
