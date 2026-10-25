import Foundation

/// What the cook-mode Live Activity shows. It is the activity's content state, so it stays small and Codable.
///
/// ActivityKit rejects content state over about 4 KB, so `make` bounds the step text, the titles and the timer list.
public struct CookSessionSnapshot: Codable, Hashable, Sendable {
    public static let maxStepTextLength = 280
    public static let maxTitleLength = 80
    public static let maxTimers = 3

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
        let timers = board.ordered.prefix(maxTimers).map {
            CookTimerEntry(
                id: $0.id,
                stepNumber: $0.stepNumber,
                label: truncated($0.label, limit: maxTitleLength),
                endsAt: $0.endsAt,
                isPaused: $0.isPaused
            )
        }
        return CookSessionSnapshot(
            recipeID: recipe.id,
            recipeTitle: truncated(recipe.title, limit: maxTitleLength),
            stepNumber: current == nil ? 0 : index + 1,
            stepCount: recipe.steps.count,
            stepTitle: current.map { truncated(title(for: $0), limit: maxTitleLength) } ?? "",
            stepText: current.map { truncated($0.description, limit: maxStepTextLength) } ?? "",
            nextStepTitle: next.map { truncated(title(for: $0), limit: maxTitleLength) },
            checkedCount: Set(progress.checkedIngredientIDs).intersection(progress.ingredientIDs).count,
            ingredientCount: progress.ingredientIDs.count,
            timers: Array(timers)
        )
    }

    private static func title(for step: RecipeStep) -> String {
        step.stepTitle ?? "Step \(step.stepNum)"
    }

    /// Text over `limit` characters is cut on a word boundary where there is one and ends with an ellipsis. The result,
    /// ellipsis included, never exceeds `limit` characters.
    static func truncated(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        let head = String(text.prefix(limit - 1))
        let cut = head.lastIndex(where: \.isWhitespace).map { String(head[..<$0]) } ?? head
        let trimmed = cut.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed + "\u{2026}"
    }
}
