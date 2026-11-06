import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// Headless CookSyncJourney (`Apps/Spoonjoy/Journeys/CookSyncJourney.swift`): the recipe page's checklist, then cook
/// mode's checks, swipes, step timer and relaunch. The server half (QA's revision holds the check, and never moves
/// backwards) stays live.
@MainActor
@Suite("CookSyncJourney", .serialized)
struct CookSyncJourneyTests {
    static let recipe = "recipe_cook_sync"
    static let lemon = "ing_lemon"
    static let salt = "ing_salt"
    static let oil = "ing_oil"

    static let kitchen = SpoonjoyJourneyKitchen(recipes: [
        .init(recipe, "Journey Cook Sync J4", steps: [
            .init("step_zest", title: "Zest the lemon", "Zest the lemon into a bowl.", minutes: 10, ingredients: [
                .init(lemon, "lemon", 1, "whole"),
                .init(salt, "salt", 1, "tsp"),
                .init(oil, "oil", 2, "tbsp"),
            ]),
            .init("step_serve", title: "Serve", "Spoon the zest over the dish."),
        ]),
    ])

    private func checklist(_ screen: ReinsScreen) -> [String] {
        screen.state["checklist"]?[0]?.arrayValue?.compactMap { $0["id"]?.stringValue } ?? []
    }

    private func checked(_ screen: ReinsScreen, _ id: String) -> Bool {
        screen.state["ingredients"]?.arrayValue?.first { $0["id"] == .string(id) }?["checked"] == true
    }

    @Test func testCookModeCheckReachesTheServerJourney() async throws {
        try await headless {
            let app = try await HeadlessApp.launch(Self.kitchen)
            try await app.journey.do("openRecipe", ["id": .string(Self.recipe)], until: { $0.focus == "recipe" })

            // 63-80: the page lists lemon, salt and oil, with nothing to clear yet.
            #expect(checklist(app.screen) == [Self.lemon, Self.salt, Self.oil])
            #expect(app.screen.state["clearProgress"] == false)
            #expect(!app.screen.actionNames.contains("clearProgress"))

            // 85-90, 97-98: checking the first ingredient checks it, sinks it below the others and shows Clear progress.
            try await app.journey.do("toggleIngredient", ["id": .string(Self.lemon)], until: { $0.state["clearProgress"] == true })
            #expect(app.screen.state["checklist"]?[0]?[2]?["checked"] == true, "the lemon reads as used")
            #expect(checklist(app.screen) == [Self.salt, Self.oil, Self.lemon], "the checked lemon sank and the rest kept their order")

            // 102-108: Clear progress unchecks it, puts it back on top and hides.
            try await app.journey.do("clearProgress", until: { $0.state["clearProgress"] == false && !$0.actionNames.contains("clearProgress") })
            #expect(checklist(app.screen) == [Self.lemon, Self.salt, Self.oil])
            #expect(app.screen.state["checklist"]?[0]?[0]?["checked"] == false)

            // 116-128: cook mode lists the lemon on Step 1 of 2, with More and the timer ring.
            try await app.journey.do("startCooking", until: { $0.focus == "cook" && $0.state["step"] == "Step 1 of 2" })
            #expect(app.screen.state["ingredients"]?.arrayValue?.contains { $0["id"] == .string(Self.lemon) } == true)
            #expect(app.screen.state["more"]?.arrayValue?.contains("Scale") == true)
            #expect(app.screen.state["ring"]?["duration"] == "10 min")

            // 131-141: a swipe that starts on the lemon's row turns the page and never checks the row.
            try await app.journey.do("swipe", ["direction": "next", "from": .string(Self.lemon)], until: { $0.state["step"] == "Step 2 of 2" })
            try await app.journey.do("swipe", ["direction": "previous"], until: { $0.state["step"] == "Step 1 of 2" })
            #expect(!checked(app.screen, Self.lemon), "the swipe that started on the lemon also checked it")

            // 142-143: tapping the lemon checks it.
            try await app.journey.do("checkIngredient", ["id": .string(Self.lemon), "checked": true], until: { checked($0, Self.lemon) })

            // 156-169: checking the rest starts the timer by itself; it offers Cancel, with no second line.
            #expect(app.screen.state["ring"]?["running"] == false, "the timer started before every ingredient was checked")
            try await app.journey.do("checkIngredient", ["id": .string(Self.salt), "checked": true], until: { checked($0, Self.salt) })
            try await app.journey.do("checkIngredient", ["id": .string(Self.oil), "checked": true], until: { checked($0, Self.oil) })
            try await app.journey.expect("cook", describing: "the step's timer started by itself") { $0.state["ring"]?["running"] == true }
            #expect(app.screen.actionNames.contains("cancelTimer"))
            #expect(app.screen.state["ring"]?["line"] == .null, "the running timer repeats its status in a second line")

            // 172-179: Cancel stops it, brings the ring back to start and says so.
            try await app.journey.do("cancelTimer", until: { $0.state["ring"]?["running"] == false })
            #expect(app.screen.actionNames.contains("startTimer"))
            #expect(!app.screen.actionNames.contains("cancelTimer"))
            #expect(app.screen.state["ring"]?["line"]?["status"] == "10 min timer cancelled.")

            // 184-192: a swipe that starts on the ring turns the page and starts no timer.
            try await app.journey.do("swipe", ["direction": "next", "from": "ring"], until: { $0.state["step"] == "Step 2 of 2" })
            try await Task.sleep(for: .milliseconds(400))
            #expect(app.shell.cook.registry.runningStepIDs(forRecipe: Self.recipe).isEmpty, "the swipe on the ring started the timer")
            #expect(app.shell.cook.scheduledAlarms.count == 1, "only the automatic start set an alarm")

            // 199-201: a relaunch at the largest text size keeps the chef signed in.
            var largest = app.fixtures
            largest.cook.display = .phone.with(accessibilityText: true)
            try await app.relaunch(fixtures: largest)
            guard case .authenticated = app.shell.content.authSessionState else {
                Issue.record("the app signed out on relaunch")
                return
            }
            #expect(app.screen.focus == "kitchen")

            // 202-206: the cook link (the kitchen's own start) reopens on step 2.
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" && $0.state["step"] == "Step 2 of 2" })

            // 207-213: step 1 still has its checks.
            try await app.journey.do("swipe", ["direction": "previous"], until: { $0.state["step"] == "Step 1 of 2" })
            #expect(checked(app.screen, Self.lemon) && checked(app.screen, Self.salt) && checked(app.screen, Self.oil))

            // 219-241: at the largest text size a swipe from the ring turns the page, starts no timer and keeps the checks.
            try await app.journey.do("swipe", ["direction": "next", "from": "ring"], until: { $0.state["step"] == "Step 2 of 2" })
            try await Task.sleep(for: .milliseconds(400))
            #expect(app.shell.cook.registry.runningStepIDs(forRecipe: Self.recipe).isEmpty, "the swipe at the largest text size started a timer")
            try await app.journey.do("swipe", ["direction": "previous"], until: { $0.state["step"] == "Step 1 of 2" })
            #expect(checked(app.screen, Self.lemon) && checked(app.screen, Self.salt) && checked(app.screen, Self.oil), "a swipe unchecked a row")
        }
    }

    /// 131-141, 261-273: regular width turns with the dock. Step 1 has Next and Mark done and no Back; Back joins after
    /// Next, and Next never checks the row.
    @Test func testCookModeCheckReachesTheServerJourneyOnTheDock() async throws {
        try await headless {
            var fixtures = SpoonjoyReinsFixtures()
            fixtures.cook.display = SpoonjoyReinsDisplay(width: 820, height: 1_180, isRegularWidth: true)
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures)
            try await app.journey.do("startCooking", ["id": .string(Self.recipe)], until: { $0.focus == "cook" })
            #expect(app.screen.state["layout"]?["surface"] == "pager")
            #expect(app.screen.state["layout"]?["dock"] == true)
            #expect(app.screen.actionNames.contains("nextStep") && app.screen.actionNames.contains("markStepDone"))
            #expect(!app.screen.actionNames.contains("previousStep"), "step 1 shows a Back with nowhere to go")
            try await app.journey.do("nextStep", until: { $0.state["step"] == "Step 2 of 2" && $0.actionNames.contains("previousStep") })
            try await app.journey.do("previousStep", until: { $0.state["step"] == "Step 1 of 2" })
            #expect(!checked(app.screen, Self.lemon))
        }
    }
}
