import OuroReins
import SpoonjoyCore

struct IngredientCheck: ReinsInput {
    let id: String
    let checked: Bool
}

extension SpoonjoyReinsShell {
    /// CookModeView's `advance()` and `previous()`: SpoonjoyShell's page turn, handed to `progressDidChange`.
    func turn(_ recipe: Recipe, forward: Bool) {
        let model = CookModeViewModel(recipe: recipe, progress: cookProgress(for: recipe))
        store.recordCookProgress(SpoonjoyShell.turnCookPage(model, forward: forward, updatedAt: timestamp()))
    }

    /// An ingredient row's checkbox binding.
    func check(_ recipe: Recipe, ingredient id: String, checked: Bool) throws {
        let model = CookModeViewModel(recipe: recipe, progress: cookProgress(for: recipe))
        store.recordCookProgress(try SpoonjoyShell.checkIngredient(model, id: id, checked: checked, updatedAt: timestamp()))
    }

    func cookNode(_ recipe: Recipe) -> ReinsNode {
        let model = CookModeViewModel(recipe: recipe, progress: cookProgress(for: recipe))
        let index = model.activeStep.flatMap { step in recipe.steps.firstIndex { $0.id == step.id } } ?? 0
        var actions: [ReinsAction] = []
        if index < recipe.steps.count - 1 {
            actions.append(ReinsAction("nextStep", "Turn to the next step") { [unowned self] in self.turn(recipe, forward: true) })
        }
        if index > 0 {
            actions.append(ReinsAction("previousStep", "Turn back a step") { [unowned self] in self.turn(recipe, forward: false) })
        }
        let rows = model.ingredientChecklistRows
        if !rows.isEmpty {
            actions.append(ReinsAction("checkIngredient", "Check or uncheck an ingredient on this step", input: IngredientCheck.self) { [unowned self] in
                try self.check(recipe, ingredient: $0.id, checked: $0.checked)
            }.narrowed(.object(properties: ["id": .oneOf(rows.map(\.id)), "checked": .boolean], required: ["id", "checked"])))
        }
        return ReinsNode("cook", state: [
            "recipe": .string(recipe.id),
            "title": .string(recipe.title),
            "step": .string(model.stepProgressLabel),
            "stepTitle": model.activeStep?.stepTitle.map(ReinsValue.string) ?? .null,
            "page": .string(model.currentPageProgressLabel),
            "ingredients": .array(rows.map { ["id": .string($0.id), "title": .string($0.title), "quantity": .string($0.quantityText), "checked": .bool($0.isChecked)] }),
            "timer": model.systemTimer.map { .string($0.durationLabel) } ?? .null,
        ], actions: actions)
    }
}
