import Foundation

public struct CookModeProgress: Codable, Equatable {
    public let recipeID: String
    public let stepIDs: [String]
    public let activeStepIndex: Int
    public let completedStepIDs: [String]
    public let startedAt: String
    public let updatedAt: String

    public init(recipeID: String, stepIDs: [String], startedAt: String) {
        self.recipeID = recipeID
        self.stepIDs = stepIDs
        self.activeStepIndex = 0
        self.completedStepIDs = []
        self.startedAt = startedAt
        self.updatedAt = startedAt
    }

    public var currentStepID: String? {
        guard stepIDs.indices.contains(activeStepIndex) else {
            return stepIDs.last
        }

        return stepIDs[activeStepIndex]
    }

    public var completionFraction: Double {
        guard !stepIDs.isEmpty else {
            return 0
        }

        return Double(completedStepIDs.count) / Double(stepIDs.count)
    }

    public func markingStepCompleted(_ stepID: String, updatedAt: String) throws -> CookModeProgress {
        guard stepIDs.contains(stepID) else {
            throw KitchenStateError.missingCookModeStep(stepID)
        }

        var nextCompleted = completedStepIDs
        if !nextCompleted.contains(stepID) {
            nextCompleted.append(stepID)
        }

        return CookModeProgress(
            recipeID: recipeID,
            stepIDs: stepIDs,
            activeStepIndex: activeStepIndex,
            completedStepIDs: nextCompleted,
            startedAt: startedAt,
            updatedAt: updatedAt
        )
    }

    public func advancing() -> CookModeProgress {
        CookModeProgress(
            recipeID: recipeID,
            stepIDs: stepIDs,
            activeStepIndex: min(activeStepIndex + 1, max(stepIDs.count - 1, 0)),
            completedStepIDs: completedStepIDs,
            startedAt: startedAt,
            updatedAt: updatedAt
        )
    }

    public func snapshot() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func restore(from snapshot: Data) throws -> CookModeProgress {
        let decoded = try JSONDecoder().decode(CookModeProgress.self, from: snapshot)
        let validCompleted = decoded.completedStepIDs.filter { decoded.stepIDs.contains($0) }
        let clampedIndex = min(max(decoded.activeStepIndex, 0), max(decoded.stepIDs.count - 1, 0))

        return CookModeProgress(
            recipeID: decoded.recipeID,
            stepIDs: decoded.stepIDs,
            activeStepIndex: clampedIndex,
            completedStepIDs: validCompleted,
            startedAt: decoded.startedAt,
            updatedAt: decoded.updatedAt
        )
    }

    private init(
        recipeID: String,
        stepIDs: [String],
        activeStepIndex: Int,
        completedStepIDs: [String],
        startedAt: String,
        updatedAt: String
    ) {
        self.recipeID = recipeID
        self.stepIDs = stepIDs
        self.activeStepIndex = activeStepIndex
        self.completedStepIDs = completedStepIDs
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}
