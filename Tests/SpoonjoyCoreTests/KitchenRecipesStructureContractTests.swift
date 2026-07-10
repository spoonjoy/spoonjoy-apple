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
                "Latest from the kitchen",
                "private var indexedRecipes",
                "recipe.id != leadRecipe.id",
                "RecipeIndex(recipes: indexedRecipes",
                "CookbookShelf(cookbooks: cookbooks",
                "countLabel(kitchen.counts.recipes",
                "countLabel(kitchen.counts.cookbooks"
            ],
            forbids: [
                "From your kitchen",
                "kitchen.counts.shoppingItems",
                "RecipeIndex(recipes: recipes"
            ]
        )
    }

    @Test("Kitchen recipe index rows read as index entries instead of bare open rows")
    func kitchenRecipeIndexRowsReadAsIndexEntries() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                "let ordinal: Int",
                "ordinalLabel",
                "String(format: \"%02d\", ordinal)",
                "recipe.description",
                "recipe.servings",
                "recipe.displayCoverProvenanceLabel",
                "shareRecipe",
                ".accessibilityHint(\"Opens recipe detail\")"
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
                "KitchenTableLoadingStateView(title: \"Loading recipes\"",
                "OfflineStatusView(indicator: state.offlineIndicator",
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

    @Test("Screenshot proof and validators name the richer kitchen and recipes hierarchy")
    func screenshotProofNamesRicherKitchenAndRecipesHierarchy() throws {
        let proofPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let proof = uncommentedSwift(try readRepoFile(proofPath))
        let capture = try readRepoFile(capturePath)
        let validator = try readRepoFile(validatorPath)

        for (path, content) in [
            (proofPath, proof),
            (capturePath, capture),
            (validatorPath, validator)
        ] {
            expectContent(
                content,
                in: path,
                contains: [
                    "Latest from the kitchen",
                    "Recipe index",
                    "Cookbook shelf",
                    "RecipeIndexRow",
                    "ordinal",
                    "Loading recipes",
                    "OfflineStatusView"
                ],
                forbids: [
                    "Spoonjoy Kitchen\", \"Open Recipe\", \"Start Cooking\""
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
