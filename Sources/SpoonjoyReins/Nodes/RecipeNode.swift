import Foundation
import OuroReins
import SpoonjoyCore

struct RecipeIngredientTap: ReinsInput {
    let id: String
}

extension SpoonjoyReinsShell {
    /// The recipe page's checks and scale, kept in the kitchen folder as the app keeps them in its defaults under the
    /// same keys (`RecipePageProgressStore`), so they survive a relaunch.
    var recipePageProgress: RecipePageProgressStore {
        let url = kitchenDirectory?.appendingPathComponent("native-recipe-page-progress.json")
        func load() -> [String: Data] {
            guard let url, let data = try? Data(contentsOf: url) else { return [:] }
            return (try? JSONDecoder().decode([String: Data].self, from: data)) ?? [:]
        }
        return RecipePageProgressStore(read: { load()[$0] }, write: { data, key in
            guard let url else { return }
            var all = load()
            all[key] = data
            try? JSONEncoder().encode(all).write(to: url, options: .atomic)
        })
    }

    /// RecipeDetailView's `loadRecipeProgress`: the saved checks that still name one of the page's rows.
    func recipePageChecks(_ screen: RecipeDetailScreenViewModel) -> RecipePageChecks {
        RecipePageChecks(
            restoring: recipePageProgress.snapshot(recipeID: screen.id),
            validIngredientIDs: Set(screen.stepSections.flatMap { $0.ingredients.map(\.id) }),
            validDependencyIDs: Set(screen.stepSections.flatMap { $0.dependencies.map(\.id) })
        )
    }

    /// RecipeDetailView's `persistRecipeProgress`, which runs on every change of the page's checks.
    func saveRecipePageChecks(_ checks: RecipePageChecks, recipeID: String) {
        recipePageProgress.save(checks.snapshot(updatedAt: timestamp()), recipeID: recipeID)
    }

    func recipeNode(_ recipe: Recipe) -> ReinsNode {
        let model = RecipeDetailViewModel(recipe: recipe)
        let screen = RecipeDetailScreenViewModel(recipe: recipe)
        let checks = recipePageChecks(screen)
        var actions = [
            ReinsAction("startCooking", "Start cooking") { [unowned self] in self.startCooking(recipe.id) },
        ]
        let ingredientIDs = screen.stepSections.flatMap { $0.ingredients.map(\.id) }
        if !ingredientIDs.isEmpty {
            actions.append(ReinsAction("toggleIngredient", "Check or uncheck an ingredient on the recipe page", input: RecipeIngredientTap.self) { [unowned self] in
                var next = self.recipePageChecks(screen)
                next.toggleIngredient($0.id)
                self.saveRecipePageChecks(next, recipeID: recipe.id)
            }.narrowed(.object(properties: ["id": .oneOf(ingredientIDs)], required: ["id"])))
        }
        if checks.hasProgress {
            actions.append(ReinsAction("clearProgress", "Clear progress") { [unowned self] in
                self.saveRecipePageChecks(.cleared, recipeID: recipe.id)
            })
        }
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
            // Each step's ingredients in the order the page draws them (`CheckedIngredientOrder`): checked ones sunk
            // to the bottom of their step.
            "checklist": .array(screen.stepSections.map { section in
                .array(CheckedIngredientOrder.ordered(section.ingredients, checkedIDs: checks.checkedIngredientIDs).map {
                    ["id": .string($0.id), "name": .string($0.name), "checked": .bool(checks.checkedIngredientIDs.contains($0.id))]
                })
            }),
            // Clear progress has its room kept in the Steps heading and shows only with something to clear.
            "clearProgress": .bool(checks.hasProgress),
        ], actions: actions)
    }
}
