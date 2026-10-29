import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe page progress")
struct RecipePageProgressTests {
    static func withStore(_ body: (RecipePageProgressStore, UserDefaults) throws -> Void) throws {
        let suite = "spoonjoy-recipe-page-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(RecipePageProgressStore(defaults: defaults), defaults)
    }

    @Test("a recipe with nothing saved has no page scale")
    func nothingSaved() throws {
        try Self.withStore { store, _ in
            #expect(store.snapshot(recipeID: "r1") == nil)
            #expect(store.scaleFactor(recipeID: "r1") == nil)
        }
    }

    @Test("the page's saved progress reads back, under the key the page has always used")
    func roundTrip() throws {
        try Self.withStore { store, defaults in
            let snapshot = RecipePageProgressSnapshot(scaleFactor: 2, checkedIngredientIDs: ["a"], checkedStepDependencyIDs: ["d"], updatedAt: "t1")
            store.save(snapshot, recipeID: "r1")
            #expect(defaults.data(forKey: "spoonjoy-cook-progress:r1") != nil)
            #expect(store.snapshot(recipeID: "r1") == snapshot)
            #expect(store.scaleFactor(recipeID: "r1") == 2)
        }
    }

    @Test("progress saved by the page before this change still reads")
    func readsTheExistingFormat() throws {
        try Self.withStore { store, defaults in
            let json = #"{"version":1,"scaleFactor":1.5,"checkedIngredientIDs":["a"],"checkedStepDependencyIDs":[],"updatedAt":"t0"}"#
            defaults.set(Data(json.utf8), forKey: RecipePageProgressStore.key(recipeID: "r1"))
            #expect(store.scaleFactor(recipeID: "r1") == 1.5)
        }
    }

    @Test("another version or unreadable data is ignored")
    func ignoresUnknownData() throws {
        try Self.withStore { store, defaults in
            let json = #"{"version":2,"scaleFactor":3,"checkedIngredientIDs":[],"checkedStepDependencyIDs":[],"updatedAt":"t0"}"#
            defaults.set(Data(json.utf8), forKey: RecipePageProgressStore.key(recipeID: "r1"))
            defaults.set(Data("nope".utf8), forKey: RecipePageProgressStore.key(recipeID: "r2"))
            #expect(store.snapshot(recipeID: "r1") == nil)
            #expect(store.snapshot(recipeID: "r2") == nil)
        }
    }

    @Test("a scale set in cook mode keeps the page's checks")
    func settingTheScaleKeepsChecks() throws {
        try Self.withStore { store, _ in
            store.save(RecipePageProgressSnapshot(scaleFactor: 1, checkedIngredientIDs: ["a"], checkedStepDependencyIDs: ["d"], updatedAt: "t1"), recipeID: "r1")
            store.setScaleFactor(3, recipeID: "r1", updatedAt: "t2")
            #expect(store.snapshot(recipeID: "r1") == RecipePageProgressSnapshot(scaleFactor: 3, checkedIngredientIDs: ["a"], checkedStepDependencyIDs: ["d"], updatedAt: "t2"))
            store.setScaleFactor(0.5, recipeID: "fresh", updatedAt: "t3")
            #expect(store.snapshot(recipeID: "fresh") == RecipePageProgressSnapshot(scaleFactor: 0.5, checkedIngredientIDs: [], checkedStepDependencyIDs: [], updatedAt: "t3"))
        }
    }

    @Test("a scale set in cook mode tells the recipe page underneath")
    func settingTheScaleNotifiesThePage() throws {
        try Self.withStore { store, _ in
            let recipeID = "notify-\(UUID().uuidString)"
            let heard = HeardIDs()
            let observer = NotificationCenter.default.addObserver(forName: RecipePageProgressStore.scaleDidChange, object: nil, queue: nil) { note in
                if let id = note.object as? String, id == recipeID {
                    heard.append(id)
                }
            }
            defer { NotificationCenter.default.removeObserver(observer) }
            store.setScaleFactor(2, recipeID: recipeID, updatedAt: "t1")
            #expect(heard.ids == [recipeID])
        }
    }

    @Test("scales are clamped and rounded like the page's picker")
    func normalizesScale() {
        #expect(RecipePageProgressSnapshot.normalizedScaleFactor(.nan) == 1)
        #expect(RecipePageProgressSnapshot.normalizedScaleFactor(0.1) == 0.25)
        #expect(RecipePageProgressSnapshot.normalizedScaleFactor(99) == 50)
        #expect(RecipePageProgressSnapshot.normalizedScaleFactor(1.234) == 1.23)
        #expect(RecipePageProgressSnapshot(scaleFactor: 0.1, checkedIngredientIDs: [], checkedStepDependencyIDs: [], updatedAt: "t").scaleFactor == 0.25)
    }

    @Test("cook mode opens at the page's scale, and is unchanged when the page has none or the same")
    func cookModeOpensAtThePageScale() {
        let progress = CookModeProgress(recipeID: "r1", stepIDs: ["s1"], startedAt: "t0")
        #expect(progress.openingAtRecipePageScale(nil, updatedAt: "t1") == progress)
        #expect(progress.openingAtRecipePageScale(1, updatedAt: "t1") == progress)
        let scaled = progress.openingAtRecipePageScale(2, updatedAt: "t1")
        #expect(scaled.scaleFactor == 2)
        #expect(scaled.updatedAt == "t1")
    }
}

private final class HeardIDs: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    var ids: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    func append(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        values.append(id)
    }
}
