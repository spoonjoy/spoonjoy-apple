import Foundation
import OuroReins
import SpoonjoyCore

/// The recipe page's scale and checks, by recipe, as `RecipeDetailView` keeps them in `@State` over
/// `RecipePageProgressStore`: loaded when the page first shows, saved on every change.
public struct SpoonjoyReinsRecipePages {
    var progress: [String: RecipePageChecks] = [:]
}

struct IngredientID: ReinsInput { let id: String }
struct HeldChangeChoice: ReinsInput { let choice: String }

extension SpoonjoyReinsShell {
    /// Where the recipe page keeps its scale and checks. The app keeps them in its defaults; headless, they live in the
    /// kitchen folder under the same keys, so they survive a relaunch and never leak between journeys. A journey may pass
    /// its own store instead.
    var recipePageProgress: RecipePageProgressStore {
        if let store = fixtures.recipePageProgress {
            return store
        }
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

    func recipeNode(_ recipe: Recipe) -> ReinsNode {
        let model = RecipeDetailViewModel(recipe: recipe)
        let screen = recipeDetailScreenViewModel(for: recipe)
        let progress = recipePageProgress(for: screen)
        let serves = RecipeServes(servings: recipe.servings)
        let held = content.recipeEditorConflict(for: recipe.id)

        var state: [String: ReinsValue] = [
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
            // The meta row's Serves control and the amounts it scales (`RecipeServesPopover`, `RecipeStepChecklistRow`).
            "serves": .string(serves.label(scale: progress.scaleFactor)),
            "scale": .number(progress.scaleFactor),
            "ingredientRows": .array(screen.stepSections.flatMap { section in
                CheckedIngredientOrder.ordered(section.ingredients, checkedIDs: progress.checkedIngredientIDs).map { row in
                    [
                        "id": .string(row.id),
                        "step": .number(Double(section.stepNumber)),
                        "name": .string(row.name),
                        "amount": .string(row.quantityText(scaleFactor: progress.scaleFactor)),
                        "value": .string(progress.checkedIngredientIDs.contains(row.id) ? "used" : "not used"),
                    ]
                }
            }),
            "canEdit": .bool(screen.ownerTools.editRoute != nil),
            "heldChange": held.map { held in
                [
                    "title": .string(NativeRecipeEditConflict.heldChangeTitle(held.recipeEdit)),
                    "message": .string(NativeRecipeEditConflict.heldChangeMessage(held.recipeEdit, serverMessage: held.message)),
                    "fields": .array((held.recipeEdit?.fields ?? []).map { field in
                        [
                            "field": .string(field.field.rawValue),
                            "mine": field.mine.map(ReinsValue.string) ?? .null,
                            "theirs": field.theirs.map(ReinsValue.string) ?? .null,
                        ]
                    }),
                    "choices": held.recipeEdit == nil ? ["Retry", "Discard Change"] : ["Keep My Edit", "Use Saved Version"],
                ]
            } ?? .null,
        ]
        // Each step's ingredients in the order the page draws them (`CheckedIngredientOrder`): checked ones sunk to the
        // bottom of their step. Clear progress has its room kept in the Steps heading and shows only with something to clear.
        state["checklist"] = .array(screen.stepSections.map { section in
            .array(CheckedIngredientOrder.ordered(section.ingredients, checkedIDs: progress.checkedIngredientIDs).map {
                ["id": .string($0.id), "name": .string($0.name), "checked": .bool(progress.checkedIngredientIDs.contains($0.id))]
            })
        })
        state["clearProgress"] = .bool(progress.hasProgress)
        state["x-unmodelled"] = "the Serves popover's open and closed states, cook log, cookbooks and shopping actions"

        let ingredientIDs = screen.stepSections.flatMap { $0.ingredients.map(\.id) }
        var actions = [
            ReinsAction("startCooking", "Start cooking") { [unowned self] in self.startCooking(recipe.id) },
        ]
        if serves.canIncrement(progress.scaleFactor) {
            actions.append(ReinsAction("incrementServes", "Serve one more") { [unowned self] in
                self.editRecipePage(screen) { $0.scaleFactor = serves.steppedUp($0.scaleFactor) }
            })
        }
        if serves.canDecrement(progress.scaleFactor) {
            actions.append(ReinsAction("decrementServes", "Serve one fewer") { [unowned self] in
                self.editRecipePage(screen) { $0.scaleFactor = serves.steppedDown($0.scaleFactor) }
            })
        }
        if !ingredientIDs.isEmpty {
            actions.append(ReinsAction("toggleIngredient", "Check or uncheck an ingredient", input: IngredientID.self) { [unowned self] input in
                self.editRecipePage(screen) { $0.toggleIngredient(input.id) }
            }.narrowed(.object(properties: ["id": .oneOf(ingredientIDs)], required: ["id"])))
        }
        if progress.hasProgress {
            actions.append(ReinsAction("clearProgress", "Clear progress") { [unowned self] in
                self.editRecipePage(screen) { $0 = .cleared }
            })
        }
        if let editRoute = screen.ownerTools.editRoute {
            actions.append(ReinsAction("edit", "Edit the recipe") { [unowned self] in self.navigate(to: editRoute) })
        }
        if let held, held.recipeEdit != nil {
            // `HeldChangeBanner`'s Keep My Edit and Use Saved Version, through the shell's `resolveRecipeEditConflict`.
            actions.append(ReinsAction("resolveHeldChange", "Keep my edit, or use the version saved elsewhere", input: HeldChangeChoice.self) { [unowned self] input in
                try await self.store.resolveRecipeEditConflict(clientMutationID: held.localClientMutationID, keeping: input.choice == "mine" ? .mine : .theirs)
            }.narrowed(.object(properties: ["choice": .oneOf(["mine", "theirs"])], required: ["choice"])))
        }
        return ReinsNode("recipe", state: .object(state), actions: actions)
    }

    /// `PlatformNavigationView.recipeDetailScreenViewModel(for:)`.
    func recipeDetailScreenViewModel(for recipe: Recipe) -> RecipeDetailScreenViewModel {
        RecipeDetailScreenViewModel(
            result: RecipeCatalogDetailResult(recipe: recipe, source: content.recipeCatalog.source),
            context: RecipeDetailContext(
                currentChefID: content.sessionAccountID,
                availableCookbooks: content.cookbooks.map { RecipeCookbookSaveOption(id: $0.id, title: $0.title) },
                savedInCookbookIDs: Set(recipe.cookbooks.map(\.id)),
                hasIngredientsInShoppingList: false,
                now: fixtures.now()
            )
        )
    }

    /// `RecipeDetailView.loadRecipeProgress()`: what the page last saved for this recipe.
    private func recipePageProgress(for screen: RecipeDetailScreenViewModel) -> RecipePageChecks {
        if let progress = page.recipePages.progress[screen.id] {
            return progress
        }
        let progress = recipePageProgress.checks(for: screen)
        page.recipePages.progress[screen.id] = progress
        return progress
    }

    /// `RecipeDetailView.persistRecipeProgress`: every change is saved for the next visit and the next launch.
    private func editRecipePage(_ screen: RecipeDetailScreenViewModel, _ change: (inout RecipePageChecks) -> Void) {
        var progress = recipePageProgress(for: screen)
        change(&progress)
        page.recipePages.progress[screen.id] = progress
        recipePageProgress.save(progress, recipeID: screen.id, updatedAt: timestamp())
    }
}
