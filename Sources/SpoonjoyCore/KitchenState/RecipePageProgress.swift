import Foundation

/// The recipe page's scale and checks for one recipe, kept on this device. The page's scale is the one cook mode
/// opens at, and a scale chosen in cook mode is written back here, so the two never disagree.
public struct RecipePageProgressSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let scaleFactor: Double
    public let checkedIngredientIDs: [String]
    public let checkedStepDependencyIDs: [String]
    public let updatedAt: String

    public init(scaleFactor: Double, checkedIngredientIDs: [String], checkedStepDependencyIDs: [String], updatedAt: String) {
        version = Self.currentVersion
        self.scaleFactor = Self.normalizedScaleFactor(scaleFactor)
        self.checkedIngredientIDs = checkedIngredientIDs
        self.checkedStepDependencyIDs = checkedStepDependencyIDs
        self.updatedAt = updatedAt
    }

    /// The scale range and step the page's picker and cook mode share.
    public static func normalizedScaleFactor(_ value: Double) -> Double {
        CookModeProgress.normalizedScaleFactor(value)
    }
}

/// Reads and writes `RecipePageProgressSnapshot` in the app's defaults, under the key the recipe page has always used.
public struct RecipePageProgressStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Posted after cook mode sets a recipe's scale, with the recipe ID as the object. On iPhone cook mode covers the
    /// recipe page, which stays on screen underneath, so the page listens for this instead of reloading on appear.
    public static let scaleDidChange = Notification.Name("RecipePageProgressStore.scaleDidChange")

    public static func key(recipeID: String) -> String {
        "spoonjoy-cook-progress:\(recipeID)"
    }

    public func snapshot(recipeID: String) -> RecipePageProgressSnapshot? {
        guard
            let data = defaults.data(forKey: Self.key(recipeID: recipeID)),
            let snapshot = try? JSONDecoder().decode(RecipePageProgressSnapshot.self, from: data),
            snapshot.version == RecipePageProgressSnapshot.currentVersion
        else {
            return nil
        }
        return snapshot
    }

    public func scaleFactor(recipeID: String) -> Double? {
        snapshot(recipeID: recipeID)?.scaleFactor
    }

    public func save(_ snapshot: RecipePageProgressSnapshot, recipeID: String) {
        // Encoding a struct of strings and numbers cannot fail.
        defaults.set(try! JSONEncoder().encode(snapshot), forKey: Self.key(recipeID: recipeID))
    }

    /// A scale chosen in cook mode. The page's checks stay as they are.
    public func setScaleFactor(_ scaleFactor: Double, recipeID: String, updatedAt: String) {
        let current = snapshot(recipeID: recipeID)
        save(
            RecipePageProgressSnapshot(
                scaleFactor: scaleFactor,
                checkedIngredientIDs: current?.checkedIngredientIDs ?? [],
                checkedStepDependencyIDs: current?.checkedStepDependencyIDs ?? [],
                updatedAt: updatedAt
            ),
            recipeID: recipeID
        )
        NotificationCenter.default.post(name: Self.scaleDidChange, object: recipeID)
    }
}

extension CookModeProgress {
    /// Cook mode opens at the scale the recipe page shows. With nothing saved on the page, or the same scale, the
    /// progress is unchanged.
    public func openingAtRecipePageScale(_ pageScale: Double?, updatedAt: String) -> CookModeProgress {
        guard let pageScale, Self.normalizedScaleFactor(pageScale) != scaleFactor else {
            return self
        }
        return settingScaleFactor(pageScale, updatedAt: updatedAt)
    }
}

/// What the recipe page shows of a cook's progress: the scale every amount is multiplied by, and the ingredients and
/// step dependencies checked off. `RecipeDetailView` keeps it while the page is open and saves it on every change.
public struct RecipePageProgress: Equatable, Sendable {
    public var scaleFactor: Double
    public var checkedIngredientIDs: Set<String>
    public var checkedStepDependencyIDs: Set<String>

    public static let fresh = RecipePageProgress(scaleFactor: 1, checkedIngredientIDs: [], checkedStepDependencyIDs: [])

    public init(scaleFactor: Double, checkedIngredientIDs: Set<String>, checkedStepDependencyIDs: Set<String>) {
        self.scaleFactor = scaleFactor
        self.checkedIngredientIDs = checkedIngredientIDs
        self.checkedStepDependencyIDs = checkedStepDependencyIDs
    }

    /// A tap on an ingredient checks it, or unchecks it.
    public mutating func toggleIngredient(_ id: String) {
        if checkedIngredientIDs.remove(id) == nil {
            checkedIngredientIDs.insert(id)
        }
    }

    public func snapshot(updatedAt: String) -> RecipePageProgressSnapshot {
        RecipePageProgressSnapshot(
            scaleFactor: scaleFactor,
            checkedIngredientIDs: checkedIngredientIDs.sorted(),
            checkedStepDependencyIDs: checkedStepDependencyIDs.sorted(),
            updatedAt: updatedAt
        )
    }
}

extension RecipePageProgressStore {
    /// The progress saved for the recipe, keeping only checks on ingredients and dependencies it still has. A recipe
    /// with nothing saved starts fresh.
    public func progress(for recipe: RecipeDetailScreenViewModel) -> RecipePageProgress {
        guard let snapshot = snapshot(recipeID: recipe.id) else {
            return .fresh
        }
        let ingredientIDs = Set(recipe.stepSections.flatMap { $0.ingredients.map(\.id) })
        let dependencyIDs = Set(recipe.stepSections.flatMap { $0.dependencies.map(\.id) })
        return RecipePageProgress(
            scaleFactor: snapshot.scaleFactor,
            checkedIngredientIDs: Set(snapshot.checkedIngredientIDs).intersection(ingredientIDs),
            checkedStepDependencyIDs: Set(snapshot.checkedStepDependencyIDs).intersection(dependencyIDs)
        )
    }

    public func save(_ progress: RecipePageProgress, recipeID: String, updatedAt: String) {
        save(progress.snapshot(updatedAt: updatedAt), recipeID: recipeID)
    }
}
