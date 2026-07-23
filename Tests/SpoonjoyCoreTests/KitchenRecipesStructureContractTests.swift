import Foundation
import Testing

@Suite("Kitchen and recipes structure contract")
struct KitchenRecipesStructureContractTests {
    @Test("Kitchen follows the web kitchen-table masthead lead index and shelf hierarchy")
    func kitchenFollowsWebKitchenTableHierarchy() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let cookbooksPath = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))
        let cookbooks = uncommentedSwift(try readRepoFile(cookbooksPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                "KitchenMasthead",
                "RecipeLead",
                "RecipeIndex",
                "CookbookShelf",
                "My Kitchen",
                "On the Counter",
                "private var indexedRecipes",
                "recipe.id != leadRecipe.id",
                "RecipeIndex(recipes: indexedRecipes",
                "CookbookShelf(cookbooks: cookbooks",
                "private let narrowSpacing: CGFloat = 16",
                "countLabel(kitchen.counts.recipes",
                "countLabel(kitchen.counts.cookbooks",
                ".accessibilityIdentifier(\"kitchen.lead.\\(recipe.id)\")",
                "aspectRatio(16 / 10, contentMode: .fit)",
                ".clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))"
            ],
            forbids: [
                "let openRoute: (AppRoute) -> Void",
                "CookbookShelf(cookbooks: cookbooks, openRoute:",
                "coverlessNoPhotoBadge",
                "Text(\"Photo not added\")",
                "From your kitchen",
                "Latest from the kitchen",
                "recipe.attribution.creditText",
                "case .ready:\n            \"Ready\"",
                "recipes.first?.chef.username",
                "kitchen.counts.shoppingItems",
                "RecipeIndex(recipes: recipes",
                ".frame(maxWidth: .infinity, minHeight: 210"
            ]
        )
        expectContent(
            cookbooks,
            in: cookbooksPath,
            contains: [
                "CookbookCoverArt(row: row)",
                "ScrollView(.horizontal, showsIndicators: false)",
                "if horizontalSizeClass == .compact || dynamicTypeSize >= .xxLarge",
                "KitchenTableObjectRow("
            ]
        )
        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "ownerUsername: currentKitchenOwnerUsername",
                ".fixedSize(horizontal: false, vertical: true)",
                "contentState.cachedProfiles.first(where: { $0.profile.id == currentChefID })?.profile.username"
            ],
            forbids: ["recipes.first?.chef.username"]
        )
    }

    @Test("Kitchen recipe index rows read as index entries instead of bare open rows")
    func kitchenRecipeIndexRowsReadAsIndexEntries() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let cookbooksPath = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))
        let cookbooks = uncommentedSwift(try readRepoFile(cookbooksPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                "NavigationLink(value: recipeRoute)",
                ".contextMenu",
                "subtitle: nil",
                "private var accessibilityDetails",
                "usesWideKitchenSpread ? KitchenTableTheme.pageSpacing : KitchenTableTheme.sectionSpacing",
                "recipe.description",
                "recipe.servings",
                "recipe.displayCoverProvenanceLabel",
                ".frame(minHeight: KitchenTableTheme.minimumTouchTarget)",
                "shareRecipe",
                ".accessibilityHint(\"Opens recipe detail\")"
            ],
            forbids: [
                "subtitle: recipe.chef.username",
                "subtitle: rowSubtitle",
                "accessibilitySubtitleIdentifier: \"kitchen.recipe-index.count\"",
                "Text(\"Open\")",
                "Label(\"Open\"",
                "ordinalLabel",
                "let ordinal: Int",
                "HStack(spacing: 8) {\n            Button(action: open)"
            ]
        )
        expectContent(
            cookbooks,
            in: cookbooksPath,
            contains: [
                ".accessibilityIdentifier(\"kitchen.cookbook.\\(row.id)\")"
            ],
            forbids: ["accessibilitySubtitleIdentifier: \"kitchen.cookbook-shelf.count\""]
        )
    }

    @Test("owned loading routes retain cached content and animate settled replacements")
    func ownedLoadingRoutesRetainCachedContentAndAnimateSettledReplacements() throws {
        let recipesPath = "Apps/Spoonjoy/Shared/Views/RecipesView.swift"
        let cookbooksPath = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let profilePath = "Apps/Spoonjoy/Shared/Views/ProfileView.swift"
        let recipes = uncommentedSwift(try readRepoFile(recipesPath))
        let cookbooks = uncommentedSwift(try readRepoFile(cookbooksPath))
        let profile = uncommentedSwift(try readRepoFile(profilePath))

        expectContent(
            recipes,
            in: recipesPath,
            contains: [
                "_isLoading = State(initialValue: viewModel.state.rows.isEmpty)",
                "withAnimation(contentAnimation)",
                ".transition(.opacity)"
            ]
        )
        expectContent(
            cookbooks,
            in: cookbooksPath,
            contains: [
                "@State private var isLoading",
                "_isLoading = State(initialValue: viewModel.list.rows.isEmpty)",
                "if isLoading, list.rows.isEmpty",
                "detail?.id == cookbookID",
                "withAnimation(contentAnimation)",
                ".transition(.opacity)"
            ]
        )
        expectContent(
            profile,
            in: profilePath,
            contains: [
                "viewModel.profile.map",
                "withAnimation(contentAnimation)",
                ".transition(.opacity)"
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

    @Test("Screenshot readiness and observers separate app state from accessibility evidence")
    func screenshotReadinessAndObserversSeparateAppStateFromAccessibilityEvidence() throws {
        let proofPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let observerPath = "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"
        let validatorPath = "scripts/validate-design-review.rb"
        let proof = uncommentedSwift(try readRepoFile(proofPath))
        let observer = uncommentedSwift(try readRepoFile(observerPath))
        let validator = try readRepoFile(validatorPath)

        expectContent(
            proof,
            in: proofPath,
            contains: [
                "observedDynamicTypeSize",
                "observedReduceMotion",
                "visualReadiness"
            ],
            forbids: [
                "voiceOverLabels",
                "keyboardNavigationTargets",
                "routeEvidence"
            ]
        )
        expectContent(
            observer,
            in: observerPath,
            contains: [
                "root.descendants(matching: type).allElementsBoundByAccessibilityElement",
                "performAccessibilityAudit",
                "scrollPrimarySurfaceToTerminal",
                "recipe-detail",
                "cookbook-detail"
            ]
        )
        expectContent(
            validator,
            in: validatorPath,
            contains: [
                "observedAccessibilityEvidenceArtifacts",
                "geometryFindings",
                "auditIssues",
                "deepScroll"
            ]
        )
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
