import Foundation

/// What the cook-mode Live Activity shows. It is the activity's content state, so it stays small and Codable.
///
/// This file is plain Foundation because the widget extension compiles it too. ActivityKit rejects content state
/// over about 4 KB, so `make` (in CookSessionSnapshot+Make.swift) bounds the step text, the titles and the timer list.
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
}
