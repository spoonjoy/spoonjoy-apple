import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Synchronization
import Testing

/// DuoJourney, headless, for the closed Duo (a phone): two recipes cooked to step 2; the Kitchen's hero leads with the
/// pasta and Cooking now lists the chickpeas; the tab bar's switcher is off on the Kitchen and leads with the pasta on
/// another tab; it goes back to the pasta's step, and after a kill the app reopens in cook mode on that step; a
/// Cooking now row opens the chickpeas' cook mode on its step. The hinge postures, the second window and the
/// switcher's covering are the live Duo journey's.
@MainActor
@Suite("DuoJourney", .serialized)
struct DuoJourney {
    static let pasta = "recipe_duo_pasta"
    static let chickpeas = "recipe_duo_chickpeas"

    static var kitchen: SpoonjoyJourneyKitchen {
        func steps(_ prefix: String, _ count: Int) -> [SpoonjoyJourneyKitchen.Step] {
            (1...count).map { .init("step_\(prefix)_\($0)", title: "Step \($0)", "Do step \($0).", ingredients: [.init("ing_\(prefix)_\($0)", "thing \($0)", 1)]) }
        }
        return SpoonjoyJourneyKitchen(recipes: [
            .init(pasta, "Lemon Pantry Pasta", servings: "4", steps: steps("pasta", 4)),
            .init(chickpeas, "Crispy Chickpeas", servings: "4 as a side", steps: steps("chickpeas", 3)),
        ])
    }

    /// A clock that moves on a second each read, so the cook touched last is the newest on the stove.
    final class Clock: Sendable {
        private let seconds = Mutex<Double>(1_793_000_000)
        func now() -> Date { seconds.withLock { $0 += 1; return Date(timeIntervalSince1970: $0) } }
    }

    @Test("testCookingNowThroughEveryDuoPostureJourney")
    func testCookingNowThroughEveryDuoPostureJourney() async throws {
        let clock = Clock()
        let fixtures = SpoonjoyReinsFixtures(now: { clock.now() }, restoresPages: true)
        try await headless {
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures)

            // Two pans on the go: the chickpeas left on their second step, then the pasta. Cooking starts from the
            // Kitchen, so closing cook mode lands back on the Kitchen, the page the cover closes over (#215).
            try await app.journey.do("startCooking", ["id": .string(Self.chickpeas)], until: { $0.focus == "cook" && $0.state["step"] == "Step 1 of 3" })
            try await app.journey.do("nextStep", until: { $0.state["step"] == "Step 2 of 3" })
            try await app.journey.do("goBack", until: { $0.focus == "kitchen" && $0.context["stack"]?["depth"] == 0 })
            try await app.journey.do("startCooking", ["id": .string(Self.pasta)], until: { $0.focus == "cook" && $0.state["step"] == "Step 1 of 4" })
            try await app.journey.do("nextStep", until: { $0.state["step"] == "Step 2 of 4" })
            try await app.journey.do("goBack", until: { $0.focus == "kitchen" && $0.context["stack"]?["depth"] == 0 })

            // The Kitchen leads with the pasta, the cook on the counter, and lists the chickpeas under Cooking now.
            let kitchen = app.screen
            #expect(kitchen.state["hero"]?["id"] == .string(Self.pasta))
            #expect(kitchen.state["hero"]?["cooking"] == "Step 2 of 4")
            #expect(kitchen.state["cookingNow"] == [["recipeID": .string(Self.chickpeas), "title": "Crispy Chickpeas", "step": "Step 2 of 3"]])

            // On the Kitchen the strip is the switcher, so the tab bar has none.
            #expect(kitchen.context["tabs"]?["switcher"] == nil)
            #expect(!kitchen.actionNames.contains("switcherResume"))

            // Every other tab carries the switcher, leading with the pasta.
            try await app.journey.do("selectTab", ["tab": "recipes"], until: { $0.context["tabs"]?["switcher"]?["lead"]?["recipeID"] == .string(Self.pasta) })
            #expect(app.screen.actionNames.contains("switcherResume"))
            #expect(app.screen.context["tabs"]?["switcher"]?["lead"]?["title"] == "Lemon Pantry Pasta")

            // The switcher goes back to the pasta's step; killed there, the app reopens in cook mode on that step.
            try await app.journey.do("switcherResume", until: { $0.focus == "cook" && $0.state["step"] == "Step 2 of 4" })
            try await app.relaunch()
            try await app.journey.expect("cook", describing: "the app reopened in cook mode on step 2") { $0.state["step"] == "Step 2 of 4" }
            #expect(app.shell.navigation.route == .recipeDetail(id: Self.pasta, presentation: .cook))
            #expect(app.shell.content.trustedAccountID != nil, "the app signed out on relaunch")

            // A Cooking now row goes straight back into cook mode on its step.
            try await app.journey.do("goBack", until: { $0.focus != "cook" })
            app.shell.openLink(try #require(URL(string: "spoonjoy://kitchen")))
            try await app.journey.expect("kitchen", describing: "the Kitchen lists the chickpeas under Cooking now") { screen in
                screen.state["cookingNow"]?[0]?["recipeID"] == .string(Self.chickpeas)
            }
            try await app.journey.do("resumeCooking", ["id": .string(Self.chickpeas)], until: { $0.focus == "cook" && $0.state["step"] == "Step 2 of 3" })
        }
    }
}
