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
    private let read: (String) -> Data?
    private let write: (Data, String) -> Void

    public init(defaults: UserDefaults = .standard) {
        read = { defaults.data(forKey: $0) }
        write = { defaults.set($0, forKey: $1) }
    }

    /// A store over other storage, keyed the same way: a headless journey keeps it in its kitchen folder.
    public init(read: @escaping (String) -> Data?, write: @escaping (Data, String) -> Void) {
        self.read = read
        self.write = write
    }

    /// Posted after cook mode sets a recipe's scale, with the recipe ID as the object. On iPhone cook mode covers the
    /// recipe page, which stays on screen underneath, so the page listens for this instead of reloading on appear.
    public static let scaleDidChange = Notification.Name("RecipePageProgressStore.scaleDidChange")

    public static func key(recipeID: String) -> String {
        "spoonjoy-cook-progress:\(recipeID)"
    }

    public func snapshot(recipeID: String) -> RecipePageProgressSnapshot? {
        guard
            let data = read(Self.key(recipeID: recipeID)),
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
        write(try! JSONEncoder().encode(snapshot), Self.key(recipeID: recipeID))
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

/// The recipe page's checks and scale while it is on screen: what a tap on an ingredient, Clear progress and a
/// relaunch do to them. The page draws each step's ingredients in `CheckedIngredientOrder`, so a checked one sinks to
/// the bottom of its step and an unchecked one goes back where it was.
public struct RecipePageChecks: Equatable, Sendable {
    public var scaleFactor: Double
    public var checkedIngredientIDs: Set<String>
    public var checkedStepDependencyIDs: Set<String>

    public init(scaleFactor: Double = 1, checkedIngredientIDs: Set<String> = [], checkedStepDependencyIDs: Set<String> = []) {
        self.scaleFactor = scaleFactor
        self.checkedIngredientIDs = checkedIngredientIDs
        self.checkedStepDependencyIDs = checkedStepDependencyIDs
    }

    /// What the page opens with: the saved checks that still name an ingredient or dependency of the recipe, at the
    /// saved scale; with nothing saved, a fresh page.
    public init(restoring snapshot: RecipePageProgressSnapshot?, validIngredientIDs: Set<String>, validDependencyIDs: Set<String>) {
        guard let snapshot else {
            self.init()
            return
        }
        self.init(
            scaleFactor: snapshot.scaleFactor,
            checkedIngredientIDs: Set(snapshot.checkedIngredientIDs).intersection(validIngredientIDs),
            checkedStepDependencyIDs: Set(snapshot.checkedStepDependencyIDs).intersection(validDependencyIDs)
        )
    }

    /// Clear progress shows only when there is something to clear.
    public var hasProgress: Bool {
        scaleFactor != 1 || !checkedIngredientIDs.isEmpty || !checkedStepDependencyIDs.isEmpty
    }

    public mutating func toggleIngredient(_ id: String) {
        if checkedIngredientIDs.remove(id) == nil {
            checkedIngredientIDs.insert(id)
        }
    }

    public mutating func toggleDependency(_ id: String) {
        if checkedStepDependencyIDs.remove(id) == nil {
            checkedStepDependencyIDs.insert(id)
        }
    }

    /// Clear progress: every check off and the scale back to 1.
    public static let cleared = RecipePageChecks()

    public func snapshot(updatedAt: String) -> RecipePageProgressSnapshot {
        RecipePageProgressSnapshot(
            scaleFactor: scaleFactor,
            checkedIngredientIDs: checkedIngredientIDs.sorted(),
            checkedStepDependencyIDs: checkedStepDependencyIDs.sorted(),
            updatedAt: updatedAt
        )
    }
}
