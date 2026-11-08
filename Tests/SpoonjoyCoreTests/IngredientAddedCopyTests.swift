import Testing
@testable import SpoonjoyCore

@Suite("Adding one ingredient says which")
struct IngredientAddedCopyTests {
    @Test("online, the ingredient is on the list")
    func added() {
        #expect(IngredientAddedCopy.status(name: "lemon", queuedForSync: false) == "lemon added to your list")
    }

    @Test("offline, that ingredient is saved for sync")
    func queued() {
        #expect(IngredientAddedCopy.status(name: "lemon", queuedForSync: true) == "lemon saved for sync")
    }
}
