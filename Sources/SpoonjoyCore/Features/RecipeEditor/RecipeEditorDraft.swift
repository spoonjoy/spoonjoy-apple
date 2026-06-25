import Foundation

public struct RecipeEditorIngredientDraft: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var quantity: Double
    public var unit: String?

    public init(id: String, name: String, quantity: Double, unit: String?) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    var apiDraft: RecipeIngredientDraft {
        RecipeIngredientDraft(quantity: quantity, unit: trimmedOptional(unit), name: name.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public struct RecipeEditorStepDraft: Identifiable, Equatable, Sendable {
    public var id: String
    public var stepNum: Int
    public var title: String?
    public var description: String
    public var duration: Int?
    public var ingredients: [RecipeEditorIngredientDraft]
    public var outputStepNums: [Int]

    public init(
        id: String,
        stepNum: Int,
        title: String?,
        description: String,
        duration: Int?,
        ingredients: [RecipeEditorIngredientDraft],
        outputStepNums: [Int]
    ) {
        self.id = id
        self.stepNum = stepNum
        self.title = title
        self.description = description
        self.duration = duration
        self.ingredients = ingredients
        self.outputStepNums = outputStepNums
    }

    var apiDraft: RecipeStepDraft {
        RecipeStepDraft(
            stepNum: stepNum,
            stepTitle: trimmedOptional(title),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration,
            ingredients: ingredients.map(\.apiDraft),
            outputStepNums: outputStepNums
        )
    }
}

public struct RecipeEditorDraft: Equatable, Sendable {
    public var recipeID: String?
    public var currentChefID: String
    public var title: String
    public var description: String?
    public var servings: String?
    public var steps: [RecipeEditorStepDraft]

    public init(
        recipeID: String?,
        currentChefID: String,
        title: String,
        description: String?,
        servings: String?,
        steps: [RecipeEditorStepDraft]
    ) {
        self.recipeID = recipeID
        self.currentChefID = currentChefID
        self.title = title
        self.description = description
        self.servings = servings
        self.steps = steps
    }

    public static func blank(currentChefID: String) -> RecipeEditorDraft {
        RecipeEditorDraft(
            recipeID: nil,
            currentChefID: currentChefID,
            title: "",
            description: nil,
            servings: nil,
            steps: []
        )
    }

    public init(recipe: Recipe, currentChefID: String) {
        self.init(
            recipeID: recipe.id,
            currentChefID: currentChefID,
            title: recipe.title,
            description: recipe.description,
            servings: recipe.servings,
            steps: recipe.steps.map { step in
                RecipeEditorStepDraft(
                    id: step.id,
                    stepNum: step.stepNum,
                    title: step.stepTitle,
                    description: step.description,
                    duration: step.duration,
                    ingredients: step.ingredients.map { ingredient in
                        RecipeEditorIngredientDraft(
                            id: ingredient.id,
                            name: ingredient.name,
                            quantity: ingredient.quantity,
                            unit: ingredient.unit
                        )
                    },
                    outputStepNums: step.usingSteps.map(\.outputStepNum)
                )
            }
        )
    }

    var titleForRequest: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var descriptionForRequest: String? {
        trimmedOptional(description)
    }

    var servingsForRequest: String? {
        trimmedOptional(servings)
    }

    var apiStepDrafts: [RecipeStepDraft] {
        steps.map(\.apiDraft)
    }
}

public struct RecipeEditorValidationIssue: Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum RecipeEditorValidator {
    public static func validate(_ draft: RecipeEditorDraft) -> [RecipeEditorValidationIssue] {
        var issues: [RecipeEditorValidationIssue] = []

        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(RecipeEditorValidationIssue(message: "Add a recipe title."))
        }

        if draft.steps.isEmpty {
            issues.append(RecipeEditorValidationIssue(message: "Add at least one step."))
        }

        for step in draft.steps {
            for ingredient in step.ingredients where trimmedOptional(ingredient.unit) == nil {
                let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
                issues.append(RecipeEditorValidationIssue(message: "Choose a unit for \(name.isEmpty ? "ingredient" : name)."))
            }

            for outputStepNum in step.outputStepNums where outputStepNum >= step.stepNum {
                issues.append(RecipeEditorValidationIssue(message: "Step \(step.stepNum) cannot use output from future step \(outputStepNum)."))
            }
        }

        return issues
    }
}

func trimmedOptional(_ value: String?) -> String? {
    guard let value else {
        return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
