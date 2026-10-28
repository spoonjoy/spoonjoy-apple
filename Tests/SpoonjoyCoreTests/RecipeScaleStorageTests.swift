import Foundation
import SpoonjoyCore
import Testing

@Suite("Recipe scale storage")
struct RecipeScaleStorageTests {
    /// The snapshot the recipe page writes, field for field.
    private func pageSnapshot(version: Int = 1, scaleFactor: Double) -> Data {
        let json = """
        {"version":\(version),"scaleFactor":\(scaleFactor),"checkedIngredientIDs":["a"],\
        "checkedStepDependencyIDs":[],"updatedAt":"2026-10-28T12:00:00Z"}
        """
        return Data(json.utf8)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "RecipeScaleStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func keyMatchesTheRecipePage() {
        #expect(RecipeScaleStorage.storageKey(recipeID: "r1") == "spoonjoy-cook-progress:r1")
    }

    @Test func readsBackAVersionOneSnapshot() {
        let defaults = isolatedDefaults()
        defaults.set(pageSnapshot(scaleFactor: 1.5), forKey: RecipeScaleStorage.storageKey(recipeID: "r1"))
        #expect(RecipeScaleStorage.scaleFactor(forRecipeID: "r1", in: defaults) == 1.5)
        #expect(RecipeScaleStorage.scaleFactor(forRecipeID: "r2", in: defaults) == 1)
    }

    @Test func missingSnapshotIsOne() {
        #expect(RecipeScaleStorage.scaleFactor(fromSnapshot: nil) == 1)
        #expect(RecipeScaleStorage.scaleFactor(forRecipeID: "none", in: isolatedDefaults()) == 1)
    }

    @Test func otherVersionsAndBadDataAreOne() {
        #expect(RecipeScaleStorage.scaleFactor(fromSnapshot: pageSnapshot(version: 2, scaleFactor: 3)) == 1)
        #expect(RecipeScaleStorage.scaleFactor(fromSnapshot: Data("not json".utf8)) == 1)
    }

    @Test func savedScaleIsClamped() {
        #expect(RecipeScaleStorage.scaleFactor(fromSnapshot: pageSnapshot(scaleFactor: 0.01)) == RecipeServes.minimumScale)
        #expect(RecipeScaleStorage.scaleFactor(fromSnapshot: pageSnapshot(scaleFactor: 900)) == RecipeServes.maximumScale)
    }
}
