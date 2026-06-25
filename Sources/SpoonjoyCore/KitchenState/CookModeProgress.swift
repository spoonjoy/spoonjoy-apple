import Foundation

public struct CookModeProgress: Codable, Equatable {
    public let recipeID: String
    public let stepIDs: [String]
    public let activeStepIndex: Int
    public let completedStepIDs: [String]
    public let ingredientIDs: [String]
    public let stepOutputUseIDs: [String]
    public let scaleFactor: Double
    public let checkedIngredientIDs: [String]
    public let checkedStepOutputUseIDs: [String]
    public let startedAt: String
    public let updatedAt: String

    public init(recipeID: String, stepIDs: [String], startedAt: String) {
        self.init(
            recipeID: recipeID,
            stepIDs: stepIDs,
            activeStepIndex: 0,
            completedStepIDs: [],
            ingredientIDs: [],
            stepOutputUseIDs: [],
            scaleFactor: 1,
            checkedIngredientIDs: [],
            checkedStepOutputUseIDs: [],
            startedAt: startedAt,
            updatedAt: startedAt
        )
    }

    public static func starting(recipe: Recipe, startedAt: String) -> CookModeProgress {
        CookModeProgress(
            recipeID: recipe.id,
            stepIDs: recipe.cookModeStepIDs,
            activeStepIndex: 0,
            completedStepIDs: [],
            ingredientIDs: recipe.cookModeIngredientIDs,
            stepOutputUseIDs: recipe.cookModeStepOutputUseIDs,
            scaleFactor: 1,
            checkedIngredientIDs: [],
            checkedStepOutputUseIDs: [],
            startedAt: startedAt,
            updatedAt: startedAt
        )
    }

    public init(recipeID: String, completedStepIDs: [String], currentStepID: String?) {
        var stepIDs = completedStepIDs
        if let currentStepID, !stepIDs.contains(currentStepID) {
            stepIDs.append(currentStepID)
        }
        let activeStepIndex = currentStepID.flatMap { stepIDs.firstIndex(of: $0) } ?? 0

        self.init(
            recipeID: recipeID,
            stepIDs: stepIDs,
            activeStepIndex: activeStepIndex,
            completedStepIDs: completedStepIDs,
            ingredientIDs: [],
            stepOutputUseIDs: [],
            scaleFactor: 1,
            checkedIngredientIDs: [],
            checkedStepOutputUseIDs: [],
            startedAt: "",
            updatedAt: ""
        )
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case recipeID
        case stepIDs
        case activeStepIndex
        case completedStepIDs
        case ingredientIDs
        case stepOutputUseIDs
        case scaleFactor
        case checkedIngredientIDs
        case checkedStepOutputUseIDs
        case startedAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedStepIDs = try container.decodeIfPresent([String].self, forKey: .stepIDs) ?? []
        let decodedIngredientIDs = try container.decodeIfPresent([String].self, forKey: .ingredientIDs) ?? []
        let decodedStepOutputUseIDs = try container.decodeIfPresent([String].self, forKey: .stepOutputUseIDs) ?? []
        self.init(
            recipeID: try container.decode(String.self, forKey: .recipeID),
            stepIDs: decodedStepIDs,
            activeStepIndex: try container.decodeIfPresent(Int.self, forKey: .activeStepIndex) ?? 0,
            completedStepIDs: try container.decodeIfPresent([String].self, forKey: .completedStepIDs) ?? [],
            ingredientIDs: decodedIngredientIDs,
            stepOutputUseIDs: decodedStepOutputUseIDs,
            scaleFactor: container.decodeLossyDouble(forKey: .scaleFactor) ?? 1,
            checkedIngredientIDs: try container.decodeIfPresent([String].self, forKey: .checkedIngredientIDs) ?? [],
            checkedStepOutputUseIDs: try container.decodeIfPresent([String].self, forKey: .checkedStepOutputUseIDs) ?? [],
            startedAt: try container.decodeIfPresent(String.self, forKey: .startedAt) ?? "",
            updatedAt: try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recipeID, forKey: .recipeID)
        try container.encode(stepIDs, forKey: .stepIDs)
        try container.encode(activeStepIndex, forKey: .activeStepIndex)
        try container.encode(completedStepIDs, forKey: .completedStepIDs)
        try container.encode(ingredientIDs, forKey: .ingredientIDs)
        try container.encode(stepOutputUseIDs, forKey: .stepOutputUseIDs)
        try container.encode(scaleFactor, forKey: .scaleFactor)
        try container.encode(checkedIngredientIDs, forKey: .checkedIngredientIDs)
        try container.encode(checkedStepOutputUseIDs, forKey: .checkedStepOutputUseIDs)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
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

        return copy(completedStepIDs: nextCompleted, updatedAt: updatedAt)
    }

    public func advancing() -> CookModeProgress {
        copy(activeStepIndex: min(activeStepIndex + 1, max(stepIDs.count - 1, 0)))
    }

    public func selectingStep(id stepID: String, updatedAt: String) throws -> CookModeProgress {
        guard let nextIndex = stepIDs.firstIndex(of: stepID) else {
            throw KitchenStateError.missingCookModeStep(stepID)
        }

        return copy(activeStepIndex: nextIndex, updatedAt: updatedAt)
    }

    public func settingScaleFactor(_ scaleFactor: Double, updatedAt: String) -> CookModeProgress {
        copy(scaleFactor: Self.normalizedScaleFactor(scaleFactor), updatedAt: updatedAt)
    }

    public func togglingIngredient(id ingredientID: String, checked: Bool, updatedAt: String) throws -> CookModeProgress {
        guard ingredientIDs.contains(ingredientID) else {
            throw KitchenStateError.missingCookModeIngredient(ingredientID)
        }

        return copy(
            checkedIngredientIDs: Self.settingMembership(
                id: ingredientID,
                included: checked,
                in: checkedIngredientIDs
            ),
            updatedAt: updatedAt
        )
    }

    public func togglingStepOutputUse(id stepOutputUseID: String, checked: Bool, updatedAt: String) throws -> CookModeProgress {
        guard stepOutputUseIDs.contains(stepOutputUseID) else {
            throw KitchenStateError.missingCookModeStepOutputUse(stepOutputUseID)
        }

        return copy(
            checkedStepOutputUseIDs: Self.settingMembership(
                id: stepOutputUseID,
                included: checked,
                in: checkedStepOutputUseIDs
            ),
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
            ingredientIDs: decoded.ingredientIDs,
            stepOutputUseIDs: decoded.stepOutputUseIDs,
            scaleFactor: decoded.scaleFactor,
            checkedIngredientIDs: decoded.checkedIngredientIDs,
            checkedStepOutputUseIDs: decoded.checkedStepOutputUseIDs,
            startedAt: decoded.startedAt,
            updatedAt: decoded.updatedAt
        )
    }

    public static func restore(from snapshot: Data, recipe: Recipe) throws -> CookModeProgress {
        let decoded = try JSONDecoder().decode(CookModeProgress.self, from: snapshot)
        let recipeStepIDs = recipe.cookModeStepIDs
        let activeStepIndex = decoded.currentStepID
            .flatMap { recipeStepIDs.firstIndex(of: $0) } ?? decoded.activeStepIndex
        return CookModeProgress(
            recipeID: recipe.id,
            stepIDs: recipeStepIDs,
            activeStepIndex: activeStepIndex,
            completedStepIDs: decoded.completedStepIDs,
            ingredientIDs: recipe.cookModeIngredientIDs,
            stepOutputUseIDs: recipe.cookModeStepOutputUseIDs,
            scaleFactor: decoded.scaleFactor,
            checkedIngredientIDs: decoded.checkedIngredientIDs,
            checkedStepOutputUseIDs: decoded.checkedStepOutputUseIDs,
            startedAt: decoded.startedAt,
            updatedAt: decoded.updatedAt
        )
    }

    private init(
        recipeID: String,
        stepIDs: [String],
        activeStepIndex: Int,
        completedStepIDs: [String],
        ingredientIDs: [String],
        stepOutputUseIDs: [String],
        scaleFactor: Double,
        checkedIngredientIDs: [String],
        checkedStepOutputUseIDs: [String],
        startedAt: String,
        updatedAt: String
    ) {
        let uniqueStepIDs = Self.uniquing(stepIDs)
        let uniqueIngredientIDs = Self.uniquing(ingredientIDs)
        let uniqueStepOutputUseIDs = Self.uniquing(stepOutputUseIDs)
        let uniqueCheckedIngredientIDs = Self.uniquing(checkedIngredientIDs)
        let uniqueCheckedStepOutputUseIDs = Self.uniquing(checkedStepOutputUseIDs)
        self.recipeID = recipeID
        self.stepIDs = uniqueStepIDs
        self.activeStepIndex = Self.clampedStepIndex(activeStepIndex, stepCount: uniqueStepIDs.count)
        self.completedStepIDs = Self.uniquing(completedStepIDs).filter { uniqueStepIDs.contains($0) }
        self.ingredientIDs = uniqueIngredientIDs
        self.stepOutputUseIDs = uniqueStepOutputUseIDs
        self.scaleFactor = Self.normalizedScaleFactor(scaleFactor)
        self.checkedIngredientIDs = uniqueIngredientIDs.isEmpty
            ? uniqueCheckedIngredientIDs
            : uniqueCheckedIngredientIDs.filter { uniqueIngredientIDs.contains($0) }
        self.checkedStepOutputUseIDs = uniqueStepOutputUseIDs.isEmpty
            ? uniqueCheckedStepOutputUseIDs
            : uniqueCheckedStepOutputUseIDs.filter { uniqueStepOutputUseIDs.contains($0) }
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    private func copy(
        activeStepIndex: Int? = nil,
        completedStepIDs: [String]? = nil,
        scaleFactor: Double? = nil,
        checkedIngredientIDs: [String]? = nil,
        checkedStepOutputUseIDs: [String]? = nil,
        updatedAt: String? = nil
    ) -> CookModeProgress {
        CookModeProgress(
            recipeID: recipeID,
            stepIDs: stepIDs,
            activeStepIndex: activeStepIndex ?? self.activeStepIndex,
            completedStepIDs: completedStepIDs ?? self.completedStepIDs,
            ingredientIDs: ingredientIDs,
            stepOutputUseIDs: stepOutputUseIDs,
            scaleFactor: scaleFactor ?? self.scaleFactor,
            checkedIngredientIDs: checkedIngredientIDs ?? self.checkedIngredientIDs,
            checkedStepOutputUseIDs: checkedStepOutputUseIDs ?? self.checkedStepOutputUseIDs,
            startedAt: startedAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }

    private static func normalizedScaleFactor(_ value: Double) -> Double {
        guard value.isFinite else {
            return 1
        }

        let clamped = min(max(value, 0.25), 50)
        return (clamped * 100).rounded() / 100
    }

    private static func clampedStepIndex(_ index: Int, stepCount: Int) -> Int {
        min(max(index, 0), max(stepCount - 1, 0))
    }

    private static func settingMembership(id: String, included: Bool, in ids: [String]) -> [String] {
        var nextIDs = ids.filter { $0 != id }
        if included {
            nextIDs.append(id)
        }
        return nextIDs
    }

    private static func uniquing(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }
}

private extension KeyedDecodingContainer where Key == CookModeProgress.CodingKeys {
    func decodeLossyDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}

private extension Recipe {
    var cookModeStepIDs: [String] {
        steps.map(\.id)
    }

    var cookModeIngredientIDs: [String] {
        steps.flatMap { $0.ingredients.map(\.id) }
    }

    var cookModeStepOutputUseIDs: [String] {
        steps.flatMap { $0.usingSteps.map(\.id) }
    }
}
