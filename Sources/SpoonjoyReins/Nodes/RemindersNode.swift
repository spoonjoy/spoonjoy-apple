import OuroReins
import SpoonjoyCore

struct ListInput: ReinsInput {
    let id: String
}

struct ListNameInput: ReinsInput {
    let name: String
}

extension SpoonjoyReinsShell {
    /// The recipe page's Send to Reminders flow (RecipeDetailView's `@State remindersSender`), one per page.
    func remindersSender(for recipeID: String) -> SpoonjoyRemindersSender {
        if let sender = page.remindersSenders[recipeID] { return sender }
        let sender = SpoonjoyRemindersSender(store: fixtures.reminders ?? SpoonjoyReinsReminders())
        sender.refreshCurrentListTitle()
        page.remindersSenders[recipeID] = sender
        return sender
    }

    /// Send to Reminders and the list menu item, offered while some step has ingredients
    /// (`hasIngredientsToSendToReminders`). Send runs `sendIngredientsToReminders()`; the page's scale is 1.
    func remindersActions(for recipe: Recipe) -> [ReinsAction] {
        guard recipe.steps.contains(where: { !$0.ingredients.isEmpty }) else { return [] }
        let sender = remindersSender(for: recipe.id)
        return [
            ReinsAction("sendToReminders", "Send to Reminders") {
                await sender.send(
                    ingredients: ReminderIncomingIngredient.fromRecipe(recipe.steps.flatMap(\.ingredients), scaleFactor: 1),
                    source: ReminderSource(id: recipe.id, label: recipe.title)
                )?.value
            },
            ReinsAction("chooseRemindersList", sender.currentListTitle.map { "Reminders list: \($0)" } ?? "Choose Reminders list") {
                await sender.chooseList().value
            },
        ]
    }

    /// The page's status line (`actionStatusMessage` / `actionErrorMessage`) as the sender sets it.
    func remindersStatus(for recipe: Recipe) -> ReinsValue {
        guard let sender = page.remindersSenders[recipe.id] else { return .null }
        return (sender.statusMessage ?? sender.errorMessage).map(ReinsValue.string) ?? .null
    }

    /// The Reminders list picker (SpoonjoyRemindersSendModifier's sheet), over the recipe page while it is open.
    func remindersListPicker(for recipeID: String) -> ReinsNode? {
        guard let sender = page.remindersSenders[recipeID], sender.isPickingList else { return nil }
        let lists = sender.availableLists
        var actions = [
            ReinsAction("createList", "New list", input: ListNameInput.self) { await sender.createList(named: $0.name)?.value },
            ReinsAction("cancel", "Cancel") { sender.cancelListChoice() },
        ]
        if !lists.isEmpty {
            actions.insert(ReinsAction("selectList", "Use a list", input: ListInput.self) { input in
                guard let list = lists.first(where: { $0.id == input.id }) else { return }
                await sender.select(list)?.value
            }.narrowed(.object(properties: ["id": .oneOf(lists.map(\.id))], required: ["id"])), at: 0)
        }
        return ReinsNode("remindersLists", state: [
            "lists": .array(lists.map { ["id": .string($0.id), "title": .string($0.title)] }),
        ], actions: actions)
    }
}
