import Foundation

public enum RecipeEditorDraftChangePlanner {
    public static func actions(
        original: RecipeEditorDraft,
        draft: RecipeEditorDraft,
        clientMutationID: (String) -> String
    ) -> [RecipeEditorAction] {
        var actions: [RecipeEditorAction] = [
            .save(clientMutationID: clientMutationID("recipe-save"))
        ]

        guard original.recipeID != nil, draft.recipeID != nil else {
            return actions
        }

        let originalStepsByID = Dictionary(uniqueKeysWithValues: original.steps.map { ($0.id, $0) })
        let currentStepsByID = Dictionary(uniqueKeysWithValues: draft.steps.map { ($0.id, $0) })

        appendRemovedIngredientDeletes(
            to: &actions,
            originalSteps: original.steps,
            currentStepsByID: currentStepsByID,
            clientMutationID: clientMutationID
        )

        for step in original.steps where currentStepsByID[step.id] == nil {
            actions.append(.deleteStep(
                stepID: step.id,
                clientMutationID: clientMutationID("delete-step-\(step.id)"),
                confirmation: .confirmed
            ))
        }

        for step in draft.steps {
            guard let originalStep = originalStepsByID[step.id] else {
                actions.append(.createStep(
                    clientMutationID: clientMutationID("create-step-\(step.id)"),
                    step: step
                ))
                continue
            }

            if originalStep.stepNum != step.stepNum {
                actions.append(.reorderStep(
                    stepID: step.id,
                    toStepNum: step.stepNum,
                    clientMutationID: clientMutationID("reorder-step-\(step.id)-\(step.stepNum)")
                ))
            }

            if stepBodyChanged(original: originalStep, draft: step) {
                actions.append(.updateStep(
                    stepID: step.id,
                    clientMutationID: clientMutationID("update-step-\(step.id)"),
                    title: step.title,
                    description: step.description,
                    duration: step.duration,
                    outputStepNums: step.outputStepNums
                ))
            }

            appendIngredientAdds(
                to: &actions,
                originalStep: originalStep,
                draftStep: step,
                clientMutationID: clientMutationID
            )
        }

        return actions
    }

    private static func appendRemovedIngredientDeletes(
        to actions: inout [RecipeEditorAction],
        originalSteps: [RecipeEditorStepDraft],
        currentStepsByID: [String: RecipeEditorStepDraft],
        clientMutationID: (String) -> String
    ) {
        for originalStep in originalSteps {
            guard let currentStep = currentStepsByID[originalStep.id] else {
                continue
            }

            let currentIngredientsByID = Dictionary(uniqueKeysWithValues: currentStep.ingredients.map { ($0.id, $0) })
            for ingredient in originalStep.ingredients {
                guard currentIngredientsByID[ingredient.id] == nil else {
                    continue
                }

                actions.append(.deleteIngredient(
                    stepID: originalStep.id,
                    ingredientID: ingredient.id,
                    clientMutationID: clientMutationID("delete-ingredient-\(ingredient.id)"),
                    confirmation: .confirmed
                ))
            }
        }
    }

    private static func appendIngredientAdds(
        to actions: inout [RecipeEditorAction],
        originalStep: RecipeEditorStepDraft,
        draftStep: RecipeEditorStepDraft,
        clientMutationID: (String) -> String
    ) {
        let originalIngredientsByID = Dictionary(uniqueKeysWithValues: originalStep.ingredients.map { ($0.id, $0) })
        for ingredient in draftStep.ingredients {
            guard let originalIngredient = originalIngredientsByID[ingredient.id] else {
                actions.append(.addIngredient(
                    stepID: draftStep.id,
                    clientMutationID: clientMutationID("add-ingredient-\(draftStep.id)-\(ingredient.id)"),
                    ingredient: ingredient
                ))
                continue
            }

            if ingredientChanged(original: originalIngredient, draft: ingredient) {
                actions.append(.deleteIngredient(
                    stepID: draftStep.id,
                    ingredientID: ingredient.id,
                    clientMutationID: clientMutationID("replace-delete-ingredient-\(ingredient.id)"),
                    confirmation: .confirmed
                ))
                actions.append(.addIngredient(
                    stepID: draftStep.id,
                    clientMutationID: clientMutationID("replace-add-ingredient-\(draftStep.id)-\(ingredient.id)"),
                    ingredient: ingredient
                ))
            }
        }
    }

    private static func stepBodyChanged(original: RecipeEditorStepDraft, draft: RecipeEditorStepDraft) -> Bool {
        trimmedOptional(original.title) != trimmedOptional(draft.title)
            || original.description.trimmingCharacters(in: .whitespacesAndNewlines) != draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            || original.duration != draft.duration
            || original.outputStepNums != draft.outputStepNums
    }

    private static func ingredientChanged(original: RecipeEditorIngredientDraft, draft: RecipeEditorIngredientDraft) -> Bool {
        original.name.trimmingCharacters(in: .whitespacesAndNewlines) != draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            || original.quantity != draft.quantity
            || trimmedOptional(original.unit) != trimmedOptional(draft.unit)
    }
}
