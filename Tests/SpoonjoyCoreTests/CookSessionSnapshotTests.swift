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

    @Test func sessionFinishesWhenTheLastStepIsMarkedDone() throws {
        let recipe = Self.recipe(steps: Self.steps)
        let start = CookModeProgress.starting(recipe: recipe, startedAt: "t")
        #expect(!CookSessionSnapshot.isFinished(recipe: recipe, progress: start))
        let middleDone = try start.markingStepCompleted("s2", updatedAt: "t")
        #expect(!CookSessionSnapshot.isFinished(recipe: recipe, progress: middleDone))
        let lastDone = try start.markingStepCompleted("s3", updatedAt: "t")
        #expect(CookSessionSnapshot.isFinished(recipe: recipe, progress: lastDone))
        let empty = Self.recipe(steps: [])
        #expect(!CookSessionSnapshot.isFinished(recipe: empty, progress: CookModeProgress.starting(recipe: empty, startedAt: "t")))
    }

    @Test func timerEntryCarriesItsLengthAndPausedTime() throws {
        let entry = CookTimerEntry(id: "k", stepNumber: 1, label: "Boil", endsAt: Date(timeIntervalSince1970: 60), isPaused: true, duration: 600, pausedRemaining: 42)
        #expect(entry.duration == 600)
        #expect(entry.pausedRemaining == 42)
        let plain = CookTimerEntry(id: "k", stepNumber: 1, label: "Boil", endsAt: Date(timeIntervalSince1970: 60), isPaused: false)
        #expect(plain.duration == 0)
        #expect(plain.pausedRemaining == nil)
        #expect(try JSONDecoder().decode(CookTimerEntry.self, from: JSONEncoder().encode(entry)) == entry)
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

    @Test func longStepTextCutsOnAWordBoundaryWithEllipsis() {
        let text = (0..<200).map { _ in "simmer" }.joined(separator: " ")
        let cut = CookSessionSnapshot.truncated(text, limit: CookSessionSnapshot.maxStepTextLength, maxBytes: 10_000)
        #expect(cut.count <= CookSessionSnapshot.maxStepTextLength)
        #expect(cut.hasSuffix("simmer\u{2026}"))
        #expect(CookSessionSnapshot.truncated("short", limit: 280, maxBytes: 800) == "short")
    }

    @Test func textWithoutSpacesCutsHard() {
        let cut = CookSessionSnapshot.truncated(String(repeating: "x", count: 500), limit: 80, maxBytes: 200)
        #expect(cut.count == 80)
        #expect(cut.hasSuffix("\u{2026}"))
    }

    @Test func snapshotBoundsStepTextAndTimers() {
        let long = Array(repeating: "Stir gently until thick.", count: 60).joined(separator: " ")
        let step = RecipeStep(id: "s1", stepNum: 1, stepTitle: nil, description: long, duration: nil, ingredients: [])
        let recipe = Self.recipe(steps: [step])
        let timers = (0..<6).map {
            CookTimerEntry(id: "k\($0)", stepNumber: $0, label: "T\($0)", endsAt: Date(timeIntervalSince1970: Double(100 - $0)), isPaused: false)
        }
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: .starting(recipe: recipe, startedAt: "t"), board: CookTimerBoard(timers: timers))
        #expect(snap.stepText.count <= CookSessionSnapshot.maxStepTextLength)
        #expect(snap.stepText.hasSuffix("\u{2026}"))
        #expect(snap.timers.map(\.id) == ["k5", "k4", "k3"])
    }

    @Test func worstCaseSnapshotStaysUnder4KB() throws {
        let word = String(repeating: "w", count: 12)
        let long = Array(repeating: word, count: 400).joined(separator: " ")
        let steps = (1...3).map {
            RecipeStep(id: String(repeating: "s", count: 100) + "\($0)", stepNum: $0, stepTitle: long, description: long, duration: 5, ingredients: [])
        }
        var recipe = Self.recipe(steps: steps)
        recipe = Recipe(
            id: String(repeating: "r", count: 100), title: long, description: nil, servings: nil,
            chef: recipe.chef, coverImageURL: nil, coverProvenanceLabel: nil, coverSourceType: nil, coverVariant: nil,
            href: recipe.href, canonicalURL: recipe.canonicalURL, attribution: recipe.attribution,
            createdAt: recipe.createdAt, updatedAt: recipe.updatedAt, steps: steps, cookbooks: []
        )
        let timers = (0..<20).map {
            CookTimerEntry(id: String(repeating: "k", count: 200) + "\($0)", stepNumber: $0, label: long, endsAt: Date(timeIntervalSince1970: Double($0)), isPaused: true)
        }
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: .starting(recipe: recipe, startedAt: "t"), board: CookTimerBoard(timers: timers))
        let bytes = try JSONEncoder().encode(snap).count
        #expect(bytes < 4096)
    }

    @Test func checkedCountNeverExceedsIngredientCount() throws {
        let data = Data(#"{"recipeID":"r1","stepIDs":["s1"],"checkedIngredientIDs":["i1","ghost"]}"#.utf8)
        let progress = try CookModeProgress.restore(from: data)
        let recipe = Self.recipe(steps: Self.steps)
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: progress, board: CookTimerBoard(timers: []))
        #expect(snap.ingredientCount == 0)
        #expect(snap.checkedCount == 0)
    }

    @Test func checkedCountIgnoresGhostIDsButKeepsRecipeOnes() throws {
        let data = Data(#"{"recipeID":"r1","stepIDs":["s1","s2"],"ingredientIDs":["i1","i2"],"checkedIngredientIDs":["i1","ghost","i2"]}"#.utf8)
        let progress = try CookModeProgress.restore(from: data)
        let recipe = Self.recipe(steps: Self.steps)
        let snap = CookSessionSnapshot.make(recipe: recipe, progress: progress, board: CookTimerBoard(timers: []))
        #expect(snap.ingredientCount == 2)
        #expect(snap.checkedCount == 2)
        let partial = Data(#"{"recipeID":"r1","stepIDs":["s1"],"ingredientIDs":["i1","i2"],"checkedIngredientIDs":["i1"]}"#.utf8)
        let one = CookSessionSnapshot.make(recipe: recipe, progress: try CookModeProgress.restore(from: partial), board: CookTimerBoard(timers: []))
        #expect(one.checkedCount == 1)
    }

    @Test func wordCutInTheFirstHalfFallsBackToTheCharacterLimit() {
        let cut = CookSessionSnapshot.truncated("a " + String(repeating: "x", count: 400), limit: 280, maxBytes: 800)
        #expect(cut.count == 280)
        #expect(cut.hasPrefix("a xxx"))
    }

    @Test func byteBudgetCutsEmojiOnACharacterBoundary() {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"
        let cut = CookSessionSnapshot.truncated(String(repeating: family, count: 200), limit: 280, maxBytes: 800)
        #expect(cut.utf8.count <= 800)
        #expect(cut.dropLast().allSatisfy { String($0) == family })
        #expect(cut.hasSuffix("\u{2026}"))
    }

    @Test func hugeCombiningMarkClusterIsDropped() {
        let cut = CookSessionSnapshot.truncated("e" + String(repeating: "\u{0301}", count: 2000), limit: 80, maxBytes: 200)
        #expect(cut == "\u{2026}")
    }

    @Test func worstCaseEmojiAndCombiningMarksStayUnder4KB() throws {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"
        let emoji = String(repeating: family, count: 400)
        let marks = String(repeating: "e\u{0301}\u{0302}\u{0303}\u{0304} ", count: 400)
        let ids = String(repeating: family, count: 100)
        let steps = [
            RecipeStep(id: ids + "1", stepNum: 1, stepTitle: emoji, description: emoji, duration: 5, ingredients: []),
            RecipeStep(id: ids + "2", stepNum: 2, stepTitle: marks, description: marks, duration: 5, ingredients: []),
        ]
        let base = Self.recipe(steps: steps)
        let recipe = Recipe(
            id: ids, title: emoji, description: nil, servings: nil, chef: base.chef,
            coverImageURL: nil, coverProvenanceLabel: nil, coverSourceType: nil, coverVariant: nil,
            href: base.href, canonicalURL: base.canonicalURL, attribution: base.attribution,
            createdAt: base.createdAt, updatedAt: base.updatedAt, steps: steps, cookbooks: []
        )
        let timers = (0..<9).map {
            CookTimerEntry(id: ids + "\($0)", stepNumber: $0, label: emoji, endsAt: Date(timeIntervalSince1970: Double($0)), isPaused: true)
        }
        let board = CookTimerBoard(timers: timers)
        for text in [emoji, marks] {
            let tweaked = Recipe(
                id: ids, title: text, description: nil, servings: nil, chef: base.chef,
                coverImageURL: nil, coverProvenanceLabel: nil, coverSourceType: nil, coverVariant: nil,
                href: base.href, canonicalURL: base.canonicalURL, attribution: base.attribution,
                createdAt: base.createdAt, updatedAt: base.updatedAt, steps: steps, cookbooks: []
            )
            for index in 0..<2 {
                let progress = try CookModeProgress.starting(recipe: tweaked, startedAt: "t").selectingStep(id: steps[index].id, updatedAt: "t")
                let snap = CookSessionSnapshot.make(recipe: tweaked, progress: progress, board: board)
                #expect(try JSONEncoder().encode(snap).count < 4096)
            }
        }
        _ = recipe
    }
}
