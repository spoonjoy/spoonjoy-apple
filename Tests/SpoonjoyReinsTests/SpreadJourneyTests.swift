import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// Headless Wide/SpreadJourney (`Apps/Spoonjoy/Journeys/Wide/SpreadJourney.swift`): cook mode laid open flat and wide
/// as a two-page spread. Which controls sit on which page is `CookModeControlPlan`'s, and the pages are
/// `BookSpreadLayout`'s, read from node state; the frames the live journey measures stay with it.
@MainActor
@Suite("SpreadJourney", .serialized)
struct SpreadJourneyTests {
    static let recipe = "recipe_sponge"

    static let kitchen = SpoonjoyJourneyKitchen(recipes: [
        .init(recipe, "Journey Spread J7", steps: [
            .init("step_whisk", title: "Whisk the eggs", "Whisk the eggs and sugar until pale and thick enough to hold a ribbon.", ingredients: [.init("ing_eggs", "eggs", 3, "whole")]),
            .init("step_fold", title: "Fold in the flour", "Sift the flour over the eggs and fold it in with a large spoon.", ingredients: [.init("ing_flour", "flour", 1, "cup")]),
        ]),
    ])

    private func fixtures(_ display: SpoonjoyReinsDisplay) -> SpoonjoyReinsFixtures {
        var fixtures = SpoonjoyReinsFixtures()
        fixtures.cook.display = display
        return fixtures
    }

    @Test func testSpreadControlsStayOnTheirPagesAtTheLargestTextJourney() async throws {
        try await headless {
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures(SpoonjoyReinsDisplay.duoOpenWide.with(accessibilityText: true)))
            // 29-33: a wide screen opens cook mode as a spread, its pages either side of the middle.
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" && $0.state["layout"]?["surface"] == "spread" })
            let layout = try #require(app.screen.state["layout"])
            let middle = SpoonjoyReinsDisplay.duoOpenWide.width / 2
            #expect((layout["leadingPage"]?["maxX"]?.numberValue ?? .infinity) <= middle)
            #expect((layout["trailingPage"]?["minX"]?.numberValue ?? 0) >= middle)
            // Back and Close on the left page; Mark done and Next on the right.
            #expect(layout["leadingPage"]?["controls"] == ["back", "close"])
            #expect(layout["trailingPage"]?["controls"] == ["markDone", "next"])

            // 47-55: on the last step Finish cooking takes Next's place on the right page, and there is no Next.
            try await app.journey.do("nextStep", until: { $0.state["step"] == "Step 2 of 2" })
            #expect(app.screen.state["layout"]?["trailingPage"]?["controls"] == ["markDone", "finish"])
            #expect(!app.screen.actionNames.contains("nextStep"), "the last step still offers Next beside Finish cooking")
        }
    }

    @Test func testSpreadTurnsUnderReduceMotionJourney() async throws {
        try await headless {
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures(SpoonjoyReinsDisplay.duoOpenWide.with(reduceMotion: true)))
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" && $0.state["layout"]?["surface"] == "spread" })
            #expect(app.screen.state["layout"]?["turn"] == "crossfade")
            // 79-82: the spread opens on the first step.
            #expect(app.screen.state["stepTitle"] == "Whisk the eggs")
            // 83-92: a swipe on the right page still turns it under Reduce Motion, and step 1 leaves the page.
            try await app.journey.do("swipe", ["direction": "next"], until: { $0.state["stepTitle"] == "Fold in the flour" })
            #expect(app.screen.state["step"] == "Step 2 of 2")
            // 96-104: the turned step survives a relaunch.
            try await app.relaunch()
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" && $0.state["stepTitle"] == "Fold in the flour" })
        }
    }
}
