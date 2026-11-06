import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// ModerationJourney, headless: report another chef's recipe and block the chef (App Review guideline 1.2). Both
/// stay hidden after a relaunch; unblocking from Settings > Blocked chefs brings the chef's recipe back, and that holds
/// after a relaunch too. The server is `SpoonjoyReinsModerationServer`, which keeps the reports and blocks.
@MainActor
@Suite("ModerationJourney", .serialized)
struct ModerationJourney {
    static let chef = SpoonjoyJourneyKitchen.Chef(id: "chef_j7_other", username: "otherchef")
    static let reported = "recipe_j7_reported"
    static let blocked = "recipe_j7_blocked"
    static let blockedTitle = "Journey Blocked chef J7"

    static var kitchen: SpoonjoyJourneyKitchen {
        let step = SpoonjoyJourneyKitchen.Step("step_j7", title: "Step 1", "Cook it.", ingredients: [.init("ing_j7", "journeyflour", 1, "cup")])
        return SpoonjoyJourneyKitchen(recipes: [
            .init(reported, "Journey Reported J7", chef: chef, steps: [step]),
            .init(blocked, blockedTitle, chef: chef, steps: [step]),
        ])
    }

    @Test("testReportBlockAndUnblock")
    func testReportBlockAndUnblock() async throws {
        let server = SpoonjoyReinsModerationServer(chefs: [BlockedChef(id: Self.chef.id, username: Self.chef.username)])
        var fixtures = SpoonjoyReinsFixtures.online(vault: try FixtureTokenVault.signedIn())
        fixtures.apiTransport = { _ in server.transport() }
        try await headless {
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures)

            // Report: the recipe offers Report…, the sheet takes a reason, and the thanks line names the review time.
            try await app.journey.do("openRecipe", ["id": .string(Self.reported)], until: { $0.focus == "recipe" && $0.actionNames.contains("report") })
            try await app.journey.do("report", until: { $0.focus == "report" && $0.state["sent"] == false })
            #expect(!app.screen.actionNames.contains("send"), "Send waits for a reason")
            try await app.journey.do("pickReason", ["reason": "spam"], until: { $0.actionNames.contains("send") })
            try await app.journey.do("send", until: { $0.state["thanks"] == .string(ModerationPrompt.reportThanks) })
            #expect(app.screen.state["hidden"] == "We've hidden this recipe for you.")
            #expect(server.reported == ["recipe/\(Self.reported)"])
            try await app.journey.do("done", until: { $0.focus == "kitchen" })
            try await app.journey.do("openRecipe", ["id": .string(Self.reported)], until: { screen in
                screen.focus == "moderationHidden" && screen.state["message"] == "You reported this recipe, so it's hidden for you."
            })

            // Block: the recipe offers Block <chef>, a confirmation follows, and the chef's recipe is hidden.
            try await app.journey.do("goBack", until: { $0.focus == "kitchen" })
            try await app.journey.do("openRecipe", ["id": .string(Self.blocked)], until: { $0.focus == "recipe" })
            try await app.journey.do("block", until: { $0.focus == "blockChef" && $0.state["title"] == .string(ModerationPrompt.blockTitle(BlockedChef(id: Self.chef.id, username: Self.chef.username))) })
            try await app.journey.do("confirm", until: { $0.focus == "kitchen" && $0.context["sheet"] == nil })
            #expect(server.blocked == [Self.chef.id])
            try await app.journey.do("openRecipe", ["id": .string(Self.blocked)], until: { screen in
                screen.focus == "moderationHidden" && screen.state["message"] == "You blocked @otherchef, so their recipes are hidden."
            })

            // Both stay hidden after a relaunch.
            try await app.relaunch()
            try await app.journey.do("openRecipe", ["id": .string(Self.blocked)], until: { $0.focus == "moderationHidden" })
            try await app.journey.do("goBack", until: { $0.focus == "kitchen" })
            try await app.journey.do("openRecipe", ["id": .string(Self.reported)], until: { $0.focus == "moderationHidden" })

            // Unblock: Settings lists the chef from the server, and Unblock empties the list.
            try await app.journey.do("goBack", until: { $0.focus == "kitchen" })
            try await app.journey.do("openSettings", until: { $0.focus == "settings" && $0.actionNames.contains("openBlockedChefs") })
            try await app.journey.do("openBlockedChefs", until: { screen in
                screen.focus == "blockedChefs" && screen.state["chefs"]?.arrayValue?.contains { $0["username"] == "otherchef" } == true
            })
            try await app.journey.do("unblock", ["id": .string(Self.chef.id)], until: { $0.state["empty"] == "You haven't blocked anyone." })
            #expect(server.blocked.isEmpty)

            // After unblocking and a relaunch, the chef's recipe is back.
            try await app.relaunch()
            try await app.journey.do("openRecipe", ["id": .string(Self.blocked)], until: { $0.focus == "recipe" && $0.state["title"] == .string(Self.blockedTitle) })
        }
    }
}
