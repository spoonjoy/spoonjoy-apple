import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// Headless TabletopJourney (`Apps/Spoonjoy/Journeys/TabletopJourney.swift`): cook mode on a foldable stood half-open,
/// folded shut and opened again, with a step timer running across relaunches. The postures are the launch display, as
/// the live journey forces them with `-SpoonjoyForcePosture`; the split is `TabletopLayout`'s, read from node state.
@MainActor
@Suite("TabletopJourney", .serialized)
struct TabletopJourneyTests {
    private static func kitchen(_ id: String, _ steps: [SpoonjoyJourneyKitchen.Step]) -> SpoonjoyJourneyKitchen {
        SpoonjoyJourneyKitchen(recipes: [.init(id, "Journey \(id)", steps: steps)])
    }

    private func checked(_ screen: ReinsScreen, _ id: String) -> Bool {
        screen.state["ingredients"]?.arrayValue?.first { $0["id"] == .string(id) }?["checked"] == true
    }

    private func fixtures(_ display: SpoonjoyReinsDisplay, alarms: SpoonjoyReinsCookFixtures.Alarms = .recording, clock: SpoonjoyReinsClock? = nil) -> SpoonjoyReinsFixtures {
        var fixtures = SpoonjoyReinsFixtures()
        fixtures.cook.display = display
        fixtures.cook.alarms = alarms
        if let clock {
            fixtures.now = clock.now
        }
        return fixtures
    }

    @Test func testTabletopCookModeSplitsAtTheFoldJourney() async throws {
        try await headless {
            let id = "recipe_tart"
            let app = try await HeadlessApp.launch(Self.kitchen(id, [
                .init("step_dough", title: "Make the dough", "Rub the butter into the flour until it looks like breadcrumbs.", minutes: 5, ingredients: [.init("ing_flour", "flour", 2, "cup")]),
                .init("step_fill", title: "Fill the tart", "Spread the jam over the pastry.", ingredients: [.init("ing_jam", "jam", 1, "cup")]),
            ]), fixtures: fixtures(.duoTabletop))
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" && $0.state["layout"]?["surface"] == "tabletop" })

            // The split as layout facts: the step and ring above the fold, the checklist below, a margin each side of
            // the fold, and neither half under its minimum height.
            let layout = try #require(app.screen.state["layout"])
            #expect(layout["stepHalf"] == ["step", "ring"])
            #expect(layout["controlsHalf"]?[0] == "checklist")
            let top = try #require(layout["top"]?["height"]?.numberValue)
            let bottomMinY = try #require(layout["bottom"]?["minY"]?.numberValue)
            let bottom = try #require(layout["bottom"]?["height"]?.numberValue)
            #expect(bottomMinY - top >= TabletopLayout.foldMargin * 2 - 0.5)
            #expect(top >= TabletopLayout.minimumHalfHeight && bottom >= TabletopLayout.minimumHalfHeight)

            // 96-101, 102-107: checking the flour checks it and, as the step's only ingredient, starts its timer.
            try await app.journey.do("checkIngredient", ["id": "ing_flour", "checked": true], until: { checked($0, "ing_flour") })
            try await app.journey.expect("cook", describing: "checking the flour started the step's timer") { $0.state["ring"]?["running"] == true }

            // 110-114: Cancel stops it.
            try await app.journey.do("cancelTimer", until: { $0.state["ring"]?["running"] == false })

            // 117-122: a swipe on the step half turns to the second step; cook mode stays split.
            try await app.journey.do("swipe", ["direction": "next"], until: { $0.state["step"] == "Step 2 of 2" })
            #expect(app.screen.state["ingredients"]?[0]?["id"] == "ing_jam")
            #expect(app.screen.state["layout"]?["surface"] == "tabletop")

            // 134-139: the relaunch reopens split, on the second step.
            try await app.relaunch()
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" && $0.state["step"] == "Step 2 of 2" })
            #expect(app.screen.state["layout"]?["surface"] == "tabletop")
        }
    }

    @Test func testAutoStartFailureShowsOnTheRingJourney() async throws {
        try await headless {
            let id = "recipe_rest"
            let app = try await HeadlessApp.launch(Self.kitchen(id, [
                .init("step_rest", title: "Rest the dough", "Cover the dough and leave it to rest.", minutes: 5, ingredients: [.init("ing_flour", "flour", 2, "cup")]),
            ]), fixtures: fixtures(.phone, alarms: .denied))
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" })
            try await app.journey.do("checkIngredient", ["id": "ing_flour", "checked": true], until: { checked($0, "ing_flour") })

            // 186-191: the ring says why no timer started, and none runs.
            try await app.journey.expect("cook", describing: "the ring says why the refused timer did not start") {
                $0.state["ring"]?["line"]?["error"] == "Allow system timers in Settings to set this timer."
            }
            #expect(app.screen.state["ring"]?["running"] == false)
            #expect(app.screen.state["runningTimers"] == 0)
            // 192-195: the refusal kept the check.
            #expect(checked(app.screen, "ing_flour"))

            // 198-212: after a relaunch the check is kept and still no timer runs.
            try await app.relaunch()
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" })
            #expect(checked(app.screen, "ing_flour"))
            #expect(app.screen.state["ring"]?["running"] == false)
        }
    }

    @Test func testFoldingMidTimerKeepsTheTimerJourney() async throws {
        try await headless {
            let id = "recipe_butter"
            let clock = SpoonjoyReinsClock()
            let app = try await HeadlessApp.launch(Self.kitchen(id, [
                .init("step_brown", title: "Brown the butter", "Melt the butter and cook it until it smells of hazelnuts.", minutes: 30, ingredients: [.init("ing_butter", "butter", 1, "cup")]),
                .init("step_cool", title: "Cool the butter", "Pour the butter into a bowl to cool.", ingredients: [.init("ing_ice", "ice", 1, "cup")]),
            ]), fixtures: fixtures(.phone, clock: clock))
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" })

            // 257-263: checking the butter starts the timer.
            try await app.journey.do("checkIngredient", ["id": "ing_butter", "checked": true], until: { checked($0, "ing_butter") })
            try await app.journey.expect("cook", describing: "checking the butter started the timer") { $0.state["ring"]?["running"] == true }
            let endsAt = try #require(app.screen.state["ring"]?["endsAt"]?.stringValue)
            #expect(app.screen.state["ring"]?["secondsLeft"] == 1_800)

            // 278: folded shut at the largest text size, the cover glance keeps the same end.
            clock.advance(by: 60)
            try await app.relaunch(fixtures: fixtures(SpoonjoyReinsDisplay.duoClosed.with(accessibilityText: true), clock: clock))
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" && $0.state["layout"]?["surface"] == "coverGlance" })
            #expect(app.screen.state["ring"]?["endsAt"]?.stringValue == endsAt)
            #expect(app.screen.state["ring"]?["secondsLeft"] == 1_740)
            // The glance offers Next and Show step, and has the step's title.
            #expect(app.screen.state["layout"]?["controls"] == ["next"])
            #expect(app.screen.actionNames.contains("showStep") && app.screen.actionNames.contains("nextStep"))
            #expect(app.screen.state["stepTitle"] == "Brown the butter")

            // 305: stood half-open the glance is gone, cook mode splits, and the end is the same.
            clock.advance(by: 60)
            try await app.relaunch(fixtures: fixtures(SpoonjoyReinsDisplay.duoTabletop.with(accessibilityText: true), clock: clock))
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" && $0.state["layout"]?["surface"] == "tabletop" })
            #expect(!app.screen.actionNames.contains("showStep"))
            #expect(app.screen.state["ring"]?["endsAt"]?.stringValue == endsAt)
            // At the largest text size the controls stack whole below the fold, with no dock: Next, Mark done, Back.
            #expect(app.screen.state["layout"]?["controlsHalf"] == ["checklist", "next", "markDone", "back"])

            // 323-327: Cancel stops it.
            try await app.journey.do("cancelTimer", until: { $0.state["ring"]?["running"] == false })
        }
    }

    @Test func testTimerRunsOnForTheDuoTourJourney() async throws {
        try await headless {
            let id = "recipe_stock"
            let clock = SpoonjoyReinsClock()
            let app = try await HeadlessApp.launch(Self.kitchen(id, [
                .init("step_simmer", title: "Simmer the stock", "Bring the stock to a simmer and let it reduce by a third.", minutes: 45, ingredients: [.init("ing_stock", "stock", 4, "cup")]),
                .init("step_season", title: "Season", "Taste the stock and season it with salt.", ingredients: [.init("ing_salt", "salt", 1, "tsp")]),
                .init("step_strain", title: "Strain", "Strain the stock through a fine sieve."),
            ]), fixtures: fixtures(.phone, clock: clock))
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" })

            // 384-389: checking the stock starts the timer.
            try await app.journey.do("checkIngredient", ["id": "ing_stock", "checked": true], until: { checked($0, "ing_stock") })
            try await app.journey.expect("cook", describing: "checking the stock started the timer") { $0.state["ring"]?["running"] == true }
            let endsAt = try #require(app.screen.state["ring"]?["endsAt"]?.stringValue)

            // 393-397: its end survives a relaunch.
            clock.advance(by: 120)
            try await app.relaunch()
            try await app.journey.do("startCooking", ["id": .string(id)], until: { $0.focus == "cook" })
            #expect(app.screen.state["ring"]?["running"] == true)
            #expect(app.screen.state["ring"]?["endsAt"]?.stringValue == endsAt)
            #expect(app.screen.state["ring"]?["secondsLeft"] == 2_580)
        }
    }
}
