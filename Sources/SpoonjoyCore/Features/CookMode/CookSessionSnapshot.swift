import Foundation

/// What the cook-mode Live Activity shows. It is the activity's content state, so it stays small and Codable.
public struct CookSessionSnapshot: Codable, Hashable, Sendable {
    public let recipeID: String
    public let recipeTitle: String
    public let stepNumber: Int
    public let stepCount: Int
    public let stepTitle: String
    public let stepText: String
    public let nextStepTitle: String?
    public let checkedCount: Int
    public let ingredientCount: Int
    public let timers: [CookTimerEntry]

    public init(
        recipeID: String,
        recipeTitle: String,
        stepNumber: Int,
        stepCount: Int,
        stepTitle: String,
        stepText: String,
        nextStepTitle: String?,
        checkedCount: Int,
        ingredientCount: Int,
        timers: [CookTimerEntry]
    ) {
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.stepNumber = stepNumber
        self.stepCount = stepCount
        self.stepTitle = stepTitle
        self.stepText = stepText
        self.nextStepTitle = nextStepTitle
        self.checkedCount = checkedCount
        self.ingredientCount = ingredientCount
        self.timers = timers
    }

    public static func make(recipe: Recipe, progress: CookModeProgress, board: CookTimerBoard) -> CookSessionSnapshot {
        let index = progress.activeStepIndex
        let current = recipe.steps.indices.contains(index) ? recipe.steps[index] : nil
        let next = recipe.steps.indices.contains(index + 1) ? recipe.steps[index + 1] : nil
        return CookSessionSnapshot(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            stepNumber: current == nil ? 0 : index + 1,
            stepCount: recipe.steps.count,
            stepTitle: current.map(title(for:)) ?? "",
            stepText: current?.description ?? "",
            nextStepTitle: next.map(title(for:)),
            checkedCount: progress.checkedIngredientIDs.count,
            ingredientCount: progress.ingredientIDs.count,
            timers: board.ordered
        )
    }

    private static func title(for step: RecipeStep) -> String {
        step.stepTitle ?? "Step \(step.stepNum)"
    }
}
