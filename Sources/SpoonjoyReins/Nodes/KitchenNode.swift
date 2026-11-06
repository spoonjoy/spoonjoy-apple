import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    var kitchenNode: ReinsNode {
        let ids = content.recipes.map(\.id)
        var lead: ReinsValue = .null
        if case .recipe(let id, let title) = content.kitchen.leadObject { lead = ["id": .string(id), "title": .string(title)] }
        let recipeInput = ReinsSchema.object(properties: ["id": .oneOf(ids)], required: ["id"])
        return ReinsNode("kitchen", state: [
            "lead": lead,
            "recipes": .array(content.recipes.map { ["id": .string($0.id), "title": .string($0.title), "steps": .number(Double($0.steps.count))] }),
            "counts": ["recipes": .number(Double(content.kitchen.counts.recipes)), "shoppingItems": .number(Double(content.kitchen.counts.shoppingItems))],
        ], actions: ids.isEmpty ? [] : [
            ReinsAction("openRecipe", "Open a recipe", input: RecipeID.self) { [unowned self] in self.openRecipe($0.id) }.narrowed(recipeInput),
            ReinsAction("startCooking", "Start cooking a recipe", input: RecipeID.self) { [unowned self] in self.startCooking($0.id) }.narrowed(recipeInput),
        ])
    }
}
