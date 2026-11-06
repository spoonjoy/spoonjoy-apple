import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// RemindersJourney, headless: a recipe sends its two ingredients to Reminders, a second send adds nothing, and after a
/// relaunch the remembered list is used without asking and the send is still a no-op. Reminders is
/// `SpoonjoyReinsReminders`, which outlives the relaunch as the device's Reminders do.
@MainActor
@Suite("RemindersJourney", .serialized)
struct RemindersJourney {
    static let rice = "recipe_j3_rice"

    static var kitchen: SpoonjoyJourneyKitchen {
        SpoonjoyJourneyKitchen(recipes: [
            .init(rice, "Journey Egg Fried Rice J3", steps: [
                .init("step_j3_fry", title: "Fry the rice", "Scramble the eggs into the hot rice.", ingredients: [
                    .init("ing_j3_eggs", "eggs", 3, "large"),
                    .init("ing_j3_rice", "rice", 2, "cups"),
                ]),
            ]),
        ])
    }

    @Test("testSendToRemindersDedupesJourney")
    func testSendToRemindersDedupesJourney() async throws {
        let reminders = SpoonjoyReinsReminders()
        let fixtures = SpoonjoyReinsFixtures(reminders: reminders)
        try await headless {
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures)
            try await app.journey.do("openRecipe", ["id": .string(Self.rice)], until: { $0.focus == "recipe" && $0.actionNames.contains("sendToReminders") })

            // First send: access is granted, there is no list yet, so the picker asks; a new list gets both ingredients.
            try await app.journey.do("sendToReminders", until: { $0.focus == "remindersLists" })
            try await app.journey.do("createList", ["name": "Journey Groceries"], until: { screen in
                screen.focus == "recipe" && screen.state["status"]?.stringValue?.contains("Added 2") == true
            })
            let list = try #require(reminders.lists().first)
            #expect(list.title == "Journey Groceries")
            #expect(reminders.chosenListID == list.id)
            #expect(reminders.reminders(in: list.id).count == 2)

            // Second send of the same recipe: nothing new to add.
            try await app.journey.do("sendToReminders", until: { $0.state["status"]?.stringValue?.contains("Everything was already in") == true })
            #expect(reminders.reminders(in: list.id).count == 2)

            // After a relaunch the remembered list is used without asking, and the repeat is still a no-op.
            try await app.relaunch()
            try await app.journey.do("openRecipe", ["id": .string(Self.rice)], until: { $0.focus == "recipe" })
            #expect(app.screen.actionInfo("chooseRemindersList")?.title == "Reminders list: Journey Groceries")
            try await app.journey.do("sendToReminders", until: { screen in
                screen.focus == "recipe" && screen.state["status"]?.stringValue?.contains("Everything was already in") == true
            })
            #expect(reminders.reminders(in: list.id).count == 2)
        }
    }
}

extension ReinsScreen {
    func actionInfo(_ name: String) -> ReinsActionInfo? {
        actions.first { $0.name == name }
    }
}
