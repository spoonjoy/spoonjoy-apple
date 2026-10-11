import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native quick wins")
struct NativeQuickWinsTests {
    @Test("a generated credit line is not shown as a subtitle")
    func generatedCreditIsHidden() {
        #expect(RecipeDisplayCopy.subtitle(
            description: nil,
            creditText: "Lemon Pantry Pasta by ari on Spoonjoy",
            title: "Lemon Pantry Pasta",
            chefUsername: "ari"
        ) == nil)
        #expect(RecipeDisplayCopy.subtitle(
            description: "  lemon pantry pasta BY ari on spoonjoy ",
            creditText: "Lemon Pantry Pasta by ari on Spoonjoy",
            title: "Lemon Pantry Pasta",
            chefUsername: "ari"
        ) == nil)
    }

    @Test("a written description is shown, and other credit lines still show")
    func writtenDescriptionIsShown() {
        #expect(RecipeDisplayCopy.subtitle(
            description: "Bright and fast.",
            creditText: "Lemon Pantry Pasta by ari on Spoonjoy",
            title: "Lemon Pantry Pasta",
            chefUsername: "ari"
        ) == "Bright and fast.")
        #expect(RecipeDisplayCopy.subtitle(
            description: nil,
            creditText: "Adapted from Nonna",
            title: "Lemon Pantry Pasta",
            chefUsername: "ari"
        ) == "Adapted from Nonna")
    }

    @Test("blank text is skipped and a recipe exposes its display subtitle")
    func blankTextAndRecipeSubtitle() {
        #expect(RecipeDisplayCopy.subtitle(description: "   ", creditText: "", title: "T", chefUsername: "c") == nil)
        #expect(RecipeDisplayCopy.subtitle(description: nil, creditText: "Some note on Spoonjoy", title: "T", chefUsername: "c") == "Some note on Spoonjoy")

        func recipe(description: String?, credit: String) -> Recipe {
            let url = URL(string: "https://spoonjoy.app/recipes/r1")!
            return Recipe(
                id: "r1",
                title: "Lemon Pasta",
                description: description,
                servings: nil,
                chef: ChefSummary(id: "c1", username: "ari"),
                coverImageURL: nil,
                coverProvenanceLabel: nil,
                coverSourceType: nil,
                coverVariant: nil,
                href: "/recipes/r1",
                canonicalURL: url,
                attribution: RecipeAttribution(creditText: credit, canonicalURL: url, sourceURLRaw: nil, sourceHost: nil, sourceRecipe: nil),
                createdAt: "2026-06-01T00:00:00.000Z",
                updatedAt: "2026-06-01T00:10:00.000Z",
                steps: [],
                cookbooks: [],
                recentSpoons: []
            )
        }
        #expect(recipe(description: nil, credit: "Lemon Pasta by ari on Spoonjoy").displaySubtitle == nil)
        #expect(recipe(description: "Zesty.", credit: "Lemon Pasta by ari on Spoonjoy").displaySubtitle == "Zesty.")
    }

    @Test("the screen stays awake only while cook mode is visible and the app is active")
    func screenAwakePolicy() {
        #expect(CookModeScreenAwakePolicy.shouldKeepScreenAwake(isCookModeVisible: true, isAppActive: true))
        #expect(!CookModeScreenAwakePolicy.shouldKeepScreenAwake(isCookModeVisible: false, isAppActive: true))
        #expect(!CookModeScreenAwakePolicy.shouldKeepScreenAwake(isCookModeVisible: true, isAppActive: false))
    }

    @Test("pull to refresh covers the list screens and recipe detail only")
    func pullToRefreshRoutes() {
        let supported: [AppRoute] = [.kitchen, .recipes, .savedRecipes, .everyoneRecipes, .recipeDetail(id: "r", presentation: .detail), .cookbooks, .shoppingList]
        for route in supported {
            #expect(PullToRefreshPolicy.supportsPullToRefresh(route))
        }
        #expect(!PullToRefreshPolicy.supportsPullToRefresh(.recipeDetail(id: "r", presentation: .cook)))
        #expect(!PullToRefreshPolicy.supportsPullToRefresh(.settings))
    }

    @Test("app sources wire idle timer, refresh, haptics, header and settings changes")
    func appSourcesWireTheChanges() throws {
        let cook = try readRepoFile("Apps/Spoonjoy/Shared/Views/CookModeView.swift")
        #expect(cook.contains(".keepsScreenAwake()"))
        #expect(cook.contains(".sensoryFeedback("))
        let awake = try readRepoFile("Apps/Spoonjoy/Shared/Components/KeepScreenAwake.swift")
        #expect(awake.contains("isIdleTimerDisabled"))
        #expect(awake.contains(".onDisappear"))
        #expect(awake.contains("scenePhase"))

        for file in ["RecipesView", "CookbooksView", "RecipeDetailView"] {
            let source = try readRepoFile("Apps/Spoonjoy/Shared/Views/\(file).swift")
            #expect(source.contains(".reloadsOnPull"), "\(file) needs pull to refresh")
        }
        let navigation = try readRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")
        #expect(navigation.contains(".shellRefreshable(for: route)"))
        let shopping = try readRepoFile("Apps/Spoonjoy/Shared/Views/ShoppingListView.swift")
        #expect(shopping.contains(".sensoryFeedback(.selection, trigger: checkHapticTick)"))

        let detail = try readRepoFile("Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift")
        #expect(detail.contains("viewModel.recipe.displaySubtitle"))
        #expect(!detail.contains("viewModel.description ?? viewModel.recipe.attribution.creditText"))
        let kitchen = try readRepoFile("Apps/Spoonjoy/Shared/Views/KitchenView.swift")
        #expect(kitchen.contains("recipe.displaySubtitle"))

        let settings = try readRepoFile("Apps/Spoonjoy/Shared/Views/SettingsView.swift")
        let debugRange = try #require(settings.range(of: "#if DEBUG\n        // Diagnostics"))
        let envRange = try #require(settings.range(of: "title: \"Environment\", subtitle: \"Current data source\""))
        let endRange = try #require(settings.range(of: "#endif", range: envRange.upperBound..<settings.endIndex))
        #expect(debugRange.lowerBound < envRange.lowerBound && envRange.lowerBound < endRange.lowerBound)
    }
}

private func readRepoFile(_ relativePath: String) throws -> String {
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
        directory.deleteLastPathComponent()
    }
    return try String(contentsOf: directory.appendingPathComponent(relativePath), encoding: .utf8)
}
