import Foundation
import Testing

@Suite("Kitchen and recipes structure contract")
struct KitchenRecipesStructureContractTests {
    @Test("Kitchen follows the web kitchen-table masthead lead index and shelf hierarchy")
    func kitchenFollowsWebKitchenTableHierarchy() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                "KitchenMasthead",
                "RecipeLead",
                "RecipeIndex",
                "CookbookShelf",
                "KitchenCounterCook.idleLabel",
                "counterCook?.label",
                "private var indexedRecipes",
                "recipe.id != leadRecipe.id",
                "recipes: indexedRecipes",
                "CookbookShelf(cookbooks: cookbooks",
                "KitchenMasthead.countSummary(recipes: kitchen.counts.recipes, cookbooks: kitchen.counts.cookbooks)",
                "Start cooking",
                "Keep cooking",
                "See all"
            ],
            forbids: [
                "From your kitchen",
                "kitchen.counts.shoppingItems",
                "RecipeIndex(recipes: recipes",
                ".frame(maxWidth: .infinity, minHeight: 210"
            ]
        )
    }

    @Test("Kitchen bar keeps a clean top at rest, backs its buttons once the page scrolls, and keeps their glyphs legible")
    func kitchenBarBacksButtonsOnceScrolled() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                ".scrollEdgeEffectHidden(!KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: Double(scrollOffset)), for: .top)",
                ".scrollEdgeEffectStyle(.hard, for: .top)"
            ],
            forbids: [
                ".scrollEdgeEffectHidden(true, for: .top)",
                // A forced bar scheme left the buttons' glyphs white on the paper once the photo scrolled away;
                // the status bar already follows what is under it.
                ".toolbarColorScheme("
            ]
        )

        // The page scrolls under the offline capsule, so a see-through capsule let headings show through its words.
        let shellPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let shell = uncommentedSwift(try readRepoFile(shellPath))
        expectContent(
            shell,
            in: shellPath,
            contains: [".padding(.vertical, 2)\n                .background(KitchenTableTheme.raised, in: Capsule())"],
            forbids: [".padding(.vertical, 2)\n                .background(KitchenTableTheme.raised.opacity(0.94), in: Capsule())"]
        )
    }

    @Test("Recipe index rows read as index entries instead of bare open rows")
    func kitchenRecipeIndexRowsReadAsIndexEntries() throws {
        let rowPath = "Apps/Spoonjoy/Shared/Components/RecipeIndexRow.swift"
        let row = uncommentedSwift(try readRepoFile(rowPath))

        expectContent(
            row,
            in: rowPath,
            contains: [
                "recipe.displaySubtitle",
                "recipe.servings",
                "recipe.displayCoverProvenanceLabel",
                ".joined(separator: \" · \")",
                "ShareLink(item: content.shareURL)",
                ".accessibilityHint(\"Opens the recipe\")"
            ],
            forbids: [
                "subtitle: recipe.chef.username",
                "Text(\"Open\")",
                "Label(\"Open\""
            ]
        )
    }

    @Test("Recipes view is a native searchable recipe index with loading offline and structured empty states")
    func recipesViewIsNativeSearchableIndexWithHonestStates() throws {
        let recipesPath = "Apps/Spoonjoy/Shared/Views/RecipesView.swift"
        let recipes = uncommentedSwift(try readRepoFile(recipesPath))

        expectContent(
            recipes,
            in: recipesPath,
            contains: [
                "@State private var query",
                "@State private var isLoading",
                ".searchable(text: $query",
                "loadingTitle: String = \"Loading recipes\"",
                "KitchenTableLoadingStateView(title: loadingTitle",
                "RecipeCatalogEmptyState",
                "emptyState.title",
                "emptyState.message",
                "emptyState.systemImage",
                "state.leadRow",
                "state.indexRows",
                "RecipeCoverPrefetcher.prefetch"
            ],
            forbids: [
                "KitchenEmptySection(title: emptyState",
                "emptyState: String?",
                "catch {\n            state = viewModel.state\n        }"
            ]
        )
    }

    @Test("Recipe catalog state exposes lead and index rows plus structured empty copy")
    func recipeCatalogStateExposesLeadIndexAndStructuredEmptyCopy() throws {
        let catalogPath = "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogViewModel.swift"
        let catalog = uncommentedSwift(try readRepoFile(catalogPath))

        expectContent(
            catalog,
            in: catalogPath,
            contains: [
                "public struct RecipeCatalogEmptyState",
                "public let title: String",
                "public let message: String",
                "public let systemImage: String",
                "public var leadRow: RecipeCatalogRowViewModel?",
                "public var indexRows: [RecipeCatalogRowViewModel]",
                "rows.dropFirst()",
                "No recipes yet",
                "No matching recipes",
                "Start your recipe box"
            ],
            forbids: [
                "public let emptyState: String?",
                "private static func emptyState(for query: String) -> String"
            ]
        )
    }

    // Recipes lists the signed-in chef's own recipes. The fixture recipes belonged to another chef, so the
    // captured Recipes page was always empty and the catalog lead never rendered at any text size.
    @Test("the Recipes capture signs in as the chef who owns the fixture recipes")
    func recipesCaptureOwnsTheFixtureRecipes() throws {
        let capturePath = "scripts/capture-native-screenshots.sh"
        expectContent(
            try readRepoFile(capturePath),
            in: capturePath,
            contains: [
                "if route == \"recipes\"",
                "recipes = recipes.map { |recipe| recipe.merge(\"chef\" => recipe.fetch(\"chef\").merge(\"id\" => account_id)) }"
            ],
            forbids: []
        )
    }

    @Test("Screenshot proof and validators name the richer kitchen and recipes hierarchy")
    func screenshotProofNamesRicherKitchenAndRecipesHierarchy() throws {
        let proofPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let proof = uncommentedSwift(try readRepoFile(proofPath))
        let capture = try readRepoFile(capturePath)
        let validator = try readRepoFile(validatorPath)

        expectContent(
            proof,
            in: proofPath,
            contains: [
                "voiceOverLabels: [\"Recipes\", \"On the Counter\", \"Recipe index\", \"Loading recipes\"]",
                "keyboardNavigationTargets: [\"recipe lead button\", \"RecipeIndexRow buttons\", \"search field\"]",
                "declaredLayoutGuards: [\"scroll-view\", \"text-fit\", \"no-tiny-clusters\", \"dock-safe-area\"]"
            ],
            forbids: [
                "\"recipe lead button\", \"RecipeIndexRow buttons\", \"search field\", \"offline status dismiss\"",
                "\"dock-safe-area\", \"ordinal\""
            ]
        )

        for (path, content) in [
            (proofPath, proof),
            (capturePath, capture),
            (validatorPath, validator)
        ] {
            expectContent(
                content,
                in: path,
                contains: [
                    "On the Counter",
                    "On the counter",
                    "Your recipes",
                    "Recipe index",
                    "Cookbook shelf",
                    "RecipeIndexRow",
                    "edge-to-edge-hero",
                    "Loading recipes",
                    "OfflineStatusView"
                ],
                forbids: [
                    "Spoonjoy Kitchen\", \"Open Recipe\", \"Start Cooking\"",
                    "RecipeIndexRow ordinal"
                ]
            )
        }
    }
}

private let kitchenRecipesRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func readRepoFile(_ relativePath: String) throws -> String {
    try String(
        contentsOf: kitchenRecipesRepoURL.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"//.*$"#, with: "", options: .regularExpression)
}

private func expectContent(
    _ content: String,
    in path: String,
    contains requiredTokens: [String] = [],
    forbids forbiddenTokens: [String] = []
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    let presentForbidden = forbiddenTokens.filter { content.contains($0) }

    #expect(
        missing.isEmpty,
        Comment(rawValue: "\(path) missing required tokens: \(missing.joined(separator: ", "))")
    )
    #expect(
        presentForbidden.isEmpty,
        Comment(rawValue: "\(path) contains forbidden tokens: \(presentForbidden.joined(separator: ", "))")
    )
}
