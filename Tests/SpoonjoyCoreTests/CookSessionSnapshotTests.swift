import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cook session snapshot")
struct CookSessionSnapshotTests {
    static func recipe(steps: [RecipeStep]) -> Recipe {
        let url = URL(string: "https://spoonjoy.app/recipes/r1")!
        return Recipe(
            id: "r1", title: "Soup", description: nil, servings: nil,
            chef: ChefSummary(id: "c", username: "ari"),
            coverImageURL: nil, coverProvenanceLabel: nil, coverSourceType: nil, coverVariant: nil,
            href: "/recipes/r1", canonicalURL: url,
            attribution: RecipeAttribution(creditText: "By ari", canonicalURL: url, sourceURLRaw: nil, sourceHost: nil, sourceRecipe: nil),
            createdAt: "2026-10-05T00:00:00.000Z", updatedAt: "2026-10-05T00:00:00.000Z",
            steps: steps, cookbooks: []
        )
    }

    static let steps = [
        RecipeStep(id: "s1", stepNum: 1, stepTitle: "Chop", description: "Chop onions.", duration: nil,
                   ingredients: [RecipeIngredient(id: "i1", name: "Onion", quantity: 1, unit: nil)]),
        RecipeStep(id: "s2", stepNum: 2, stepTitle: nil, description: "Simmer.", duration: 10,
                   ingredients: [RecipeIngredient(id: "i2", name: "Stock", quantity: 1, unit: "l")]),
        RecipeStep(id: "s3", stepNum: 3, stepTitle: "Serve", description: "Ladle.", duration: nil, ingredients: []),
    ]

    static let board = CookTimerBoard(timers: [
        CookTimerEntry(id: "r1#s2", stepNumber: 2, label: "Simmer", endsAt: Date(timeIntervalSince1970: 1000), isPaused: false),
    ])

    @Test func snapshotNamesNextStep() throws {
        let recipe = Self.recipe(steps: Self.steps)
        let start = CookModeProgress.starting(recipe: recipe, startedAt: "t")
        let second = try start.selectingStep(id: "s2", updatedAt: "t")
            .togglingIngredient(id: "i1", checked: true, updatedAt: "t")
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: second, board: Self.board)
        #expect(snap.recipeID == "r1")
        #expect(snap.recipeTitle == "Soup")
        #expect(snap.stepNumber == 2)
        #expect(snap.stepCount == 3)
        #expect(snap.stepTitle == "Step 2")
        #expect(snap.stepText == "Simmer.")
        #expect(snap.nextStepTitle == "Serve")
        #expect(snap.checkedCount == 1)
        #expect(snap.ingredientCount == 2)
        #expect(snap.timers == Self.board.ordered)
    }

    @Test func lastStepHasNoNextStep() throws {
        let recipe = Self.recipe(steps: Self.steps)
        let last = try CookModeProgress.starting(recipe: recipe, startedAt: "t").selectingStep(id: "s3", updatedAt: "t")
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: last, board: CookTimerBoard(timers: []))
        #expect(snap.nextStepTitle == nil)
        #expect(snap.stepTitle == "Serve")
        #expect(snap.timers.isEmpty)
    }

    @Test func untitledNextStepFallsBackToNumber() {
        let recipe = Self.recipe(steps: Self.steps)
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: .starting(recipe: recipe, startedAt: "t"), board: Self.board)
        #expect(snap.nextStepTitle == "Step 2")
    }

    @Test func recipeWithoutStepsStillMakesASnapshot() {
        let recipe = Self.recipe(steps: [])
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: .starting(recipe: recipe, startedAt: "t"), board: Self.board)
        #expect(snap.stepCount == 0)
        #expect(snap.stepNumber == 0)
        #expect(snap.stepTitle == "")
        #expect(snap.stepText == "")
        #expect(snap.nextStepTitle == nil)
    }

    @Test func snapshotRoundTripsCodable() throws {
        let recipe = Self.recipe(steps: Self.steps)
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: .starting(recipe: recipe, startedAt: "t"), board: Self.board)
        let decoded = try JSONDecoder().decode(CookSessionSnapshot.self, from: JSONEncoder().encode(snap))
        #expect(decoded == snap)
        #expect(Set([snap, decoded]).count == 1)
    }
}
