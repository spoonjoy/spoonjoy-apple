import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    var kitchenNode: ReinsNode {
        let layout = kitchenLayout
        let ids = content.recipes.map(\.id)
        var lead: ReinsValue = .null
        if case .recipe(let id, let title) = content.kitchen.leadObject { lead = ["id": .string(id), "title": .string(title)] }
        let recipeInput = ReinsSchema.object(properties: ["id": .oneOf(ids)], required: ["id"])
        return ReinsNode("kitchen", state: [
            "lead": lead,
            "recipes": .array(content.recipes.map { ["id": .string($0.id), "title": .string($0.title), "steps": .number(Double($0.steps.count))] }),
            "counts": ["recipes": .number(Double(content.kitchen.counts.recipes)), "shoppingItems": .number(Double(content.kitchen.counts.shoppingItems))],
            // `KitchenView`: a kitchen with no recipes and no cookbooks leads with its hero instead.
            "emptyHero": content.recipes.isEmpty && content.cookbooks.isEmpty ? ["title": "Add a recipe", "choices": ["Add a recipe", "Import"]] : .null,
            "hero": heroState(layout),
            "cookingNow": .array(layout.cookingNow.map(Self.cookingNowRow)),
        ], actions: (ids.isEmpty ? [] : [
            ReinsAction("openRecipe", "Open a recipe", input: RecipeID.self) { [unowned self] in self.openRecipe($0.id) }.narrowed(recipeInput),
            ReinsAction("startCooking", "Start cooking a recipe", input: RecipeID.self) { [unowned self] in self.startCooking($0.id) }.narrowed(recipeInput),
        ]) + [
            // The hero's Add a recipe and the toolbar's both call the shell's `createRecipe`; Import queue opens Imports.
            ReinsAction("addRecipe", "Add a recipe") { [unowned self] in self.presentAddRecipe() },
            ReinsAction("openImports", "Open the import queue") { [unowned self] in self.navigate(to: .capture) },
        ] + kitchenExtraActions(layout))
    }

    /// The Kitchen page's layout (KitchenView's `layout`): the hero, the Cooking now rows and the index.
    var kitchenLayout: KitchenPageLayout {
        KitchenPageLayout(
            recipes: content.recipes,
            leadObject: content.kitchen.leadObject,
            cookProgress: { [content] in content.cookProgress(for: $0) },
            cookingNow: cookingNowEntries
        )
    }

    /// The rows CookingNowCenter publishes, from this device's cooks alone: a headless launch has no server list.
    var cookingNowEntries: [CookingNowEntry] {
        CookingNowBoard.board(
            server: [],
            serverFetchedAt: nil,
            local: CookingNowBoard.localEntries(progress: content.cookProgressByRecipeID, recipes: content.recipes),
            recipes: content.recipes,
            now: fixtures.now()
        )
    }

    static func cookingNowRow(_ entry: CookingNowEntry) -> ReinsValue {
        ["recipeID": .string(entry.recipeID), "title": .string(entry.title), "step": .string(entry.stepLabel)]
    }

    private func heroState(_ layout: KitchenPageLayout) -> ReinsValue {
        guard let lead = layout.leadRecipe else { return .null }
        var hero: [String: ReinsValue] = ["id": .string(lead.id), "title": .string(lead.title)]
        if let cook = layout.counterCook, cook.recipeID == lead.id {
            hero["cooking"] = .string("Step \(cook.stepNumber) of \(cook.stepCount)")
        }
        return .object(hero)
    }

    /// A Cooking now row and the hero's Resume go back into cook mode (`startCooking`, as the view's rows do); the
    /// account button opens Settings (`openRoute(.settings)`).
    private func kitchenExtraActions(_ layout: KitchenPageLayout) -> [ReinsAction] {
        var actions: [ReinsAction] = []
        let resumable = layout.cookingNow.map(\.recipeID) + (layout.counterCook.map { [$0.recipeID] } ?? [])
        if !resumable.isEmpty {
            actions.append(ReinsAction("resumeCooking", "Go back to a recipe on the stove", input: RecipeID.self) { [unowned self] in
                self.startCooking($0.id)
            }.narrowed(.object(properties: ["id": .oneOf(resumable)], required: ["id"])))
        }
        actions.append(ReinsAction("openSettings", "Open account and settings") { [unowned self] in self.navigate(to: .settings) })
        return actions
    }
}
