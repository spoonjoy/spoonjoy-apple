import Foundation

/// Where the recipe page keeps each recipe's scale, so cook mode can open at it. The page saves a version 1 JSON
/// snapshot under `storageKey(recipeID:)`; only its `version` and `scaleFactor` matter here.
public enum RecipeScaleStorage {
    public static let snapshotVersion = 1

    public static func storageKey(recipeID: String) -> String {
        "spoonjoy-cook-progress:\(recipeID)"
    }

    /// The scale in a saved snapshot, or 1 when there is none, it does not decode, or it is another version.
    public static func scaleFactor(fromSnapshot data: Data?) -> Double {
        guard
            let data,
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
            snapshot.version == snapshotVersion
        else {
            return 1
        }
        return RecipeServes.normalizedScale(snapshot.scaleFactor)
    }

    /// The scale the recipe page last saved for this recipe, or 1 when it has none.
    public static func scaleFactor(forRecipeID recipeID: String, in defaults: UserDefaults) -> Double {
        scaleFactor(fromSnapshot: defaults.data(forKey: storageKey(recipeID: recipeID)))
    }

    private struct Snapshot: Decodable {
        let version: Int
        let scaleFactor: Double
    }
}
