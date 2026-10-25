import Foundation

/// What the cook-mode Live Activity shows. It is the activity's content state, so it stays small and Codable.
///
/// ActivityKit rejects content state over about 4 KB, so `make` bounds the step text, the titles and the timer list.
public struct CookSessionSnapshot: Codable, Hashable, Sendable {
    public static let maxStepTextLength = 280
    public static let maxTitleLength = 80
    public static let maxTimers = 3
    /// UTF-8 budgets that sit beside the character caps, because one emoji family is a single character but 25 bytes.
    public static let maxStepTextBytes = 800
    public static let maxTitleBytes = 200
    public static let maxIDBytes = 200

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
                id: boundedID($0.id),
                stepNumber: $0.stepNumber,
                label: truncated($0.label, limit: maxTitleLength, maxBytes: maxTitleBytes),
                endsAt: $0.endsAt,
                isPaused: $0.isPaused
            )
        }
        return CookSessionSnapshot(
            recipeID: boundedID(recipe.id),
            recipeTitle: truncated(recipe.title, limit: maxTitleLength, maxBytes: maxTitleBytes),
            stepNumber: current == nil ? 0 : index + 1,
            stepCount: recipe.steps.count,
            stepTitle: current.map { truncated(title(for: $0), limit: maxTitleLength, maxBytes: maxTitleBytes) } ?? "",
            stepText: current.map { truncated($0.description, limit: maxStepTextLength, maxBytes: maxStepTextBytes) } ?? "",
            nextStepTitle: next.map { truncated(title(for: $0), limit: maxTitleLength, maxBytes: maxTitleBytes) },
            checkedCount: Set(progress.checkedIngredientIDs).intersection(progress.ingredientIDs).count,
            ingredientCount: progress.ingredientIDs.count,
            timers: Array(timers)
        )
    }

    private static func title(for step: RecipeStep) -> String {
        step.stepTitle ?? "Step \(step.stepNum)"
    }

    /// Text over `limit` characters or `maxBytes` UTF-8 bytes is cut and ends with an ellipsis. The cut falls on a
    /// Character boundary, so no emoji or accent splits, and on a word boundary when that keeps at least half the
    /// text. The result, ellipsis included, fits both budgets.
    static func truncated(_ text: String, limit: Int, maxBytes: Int) -> String {
        guard text.count > limit || text.utf8.count > maxBytes else {
            return text
        }
        let ellipsis = "\u{2026}"
        var head = String(text.prefix(limit - 1))
        while head.utf8.count + ellipsis.utf8.count > maxBytes, !head.isEmpty {
            head.removeLast()
        }
        if let space = head.lastIndex(where: \.isWhitespace),
           head.distance(from: head.startIndex, to: space) >= head.count / 2 {
            head = String(head[..<space])
        }
        return head.trimmingCharacters(in: .whitespacesAndNewlines) + ellipsis
    }

    /// An id cut to the byte budget on a Character boundary, with no ellipsis.
    static func boundedID(_ id: String) -> String {
        var bounded = id
        while bounded.utf8.count > maxIDBytes {
            bounded.removeLast()
        }
        return bounded
    }
}
