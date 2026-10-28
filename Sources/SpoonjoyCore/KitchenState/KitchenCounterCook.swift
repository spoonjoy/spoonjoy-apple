import Foundation

/// The cook the Kitchen hero resumes: the recipe whose unfinished cook was touched last, and where it stands.
public struct KitchenCounterCook: Equatable, Sendable {
    public let recipeID: String
    /// 1-based position of the active step.
    public let stepNumber: Int
    public let stepCount: Int

    public init(recipeID: String, stepNumber: Int, stepCount: Int) {
        self.recipeID = recipeID
        self.stepNumber = stepNumber
        self.stepCount = stepCount
    }

    /// The hero's kicker, "On the counter · step 2 of 4".
    public var label: String {
        "\(Self.idleLabel) · step \(stepNumber) of \(stepCount)"
    }

    /// The hero's kicker when nothing is being cooked.
    public static let idleLabel = "On the counter"

    /// A cook resumes while it has steps and some are not done. Ties on `updatedAt` keep the earlier recipe.
    public static func resolve(
        recipeIDs: [String],
        progress: (String) -> CookModeProgress?
    ) -> KitchenCounterCook? {
        var best: (cook: KitchenCounterCook, updatedAt: String)?
        for recipeID in recipeIDs {
            guard let cook = progress(recipeID),
                  !cook.stepIDs.isEmpty,
                  cook.completedStepIDs.count < cook.stepIDs.count else {
                continue
            }
            if let best, best.updatedAt >= cook.updatedAt {
                continue
            }
            let stepNumber = min(max(cook.activeStepIndex, 0), cook.stepIDs.count - 1) + 1
            best = (KitchenCounterCook(recipeID: recipeID, stepNumber: stepNumber, stepCount: cook.stepIDs.count), cook.updatedAt)
        }
        return best?.cook
    }
}
