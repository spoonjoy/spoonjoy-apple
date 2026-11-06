import OuroReins
import SpoonjoyCore

extension SpoonjoyReinsShell {
    func recipeNode(_ recipe: Recipe) -> ReinsNode {
        // RecipeDetailView shows ModerationHiddenView in place of a reported recipe or a blocked chef's.
        if let hidden = moderation.ledger.hiddenNotice(recipeID: recipe.id, chefID: recipe.chef.id, chefUsername: recipe.chef.username) {
            return moderationHiddenNode(hidden)
        }
        let model = RecipeDetailViewModel(recipe: recipe)
        return ReinsNode("recipe", state: [
            "id": .string(model.id),
            "title": .string(model.title),
            "servings": recipe.servings.map(ReinsValue.string) ?? .null,
            "steps": .array(model.stepSections.map { section in
                [
                    "number": .number(Double(section.stepNumber)),
                    "title": section.step.stepTitle.map(ReinsValue.string) ?? .null,
                    "ingredients": .array(section.step.ingredients.map { .string($0.name) }),
                ]
            }),
            "status": remindersStatus(for: recipe),
        ], actions: [
            ReinsAction("startCooking", "Start cooking") { [unowned self] in self.startCooking(recipe.id) },
        ] + remindersActions(for: recipe) + moderationActions(for: recipe), child: remindersListPicker(for: recipe.id))
    }
}
