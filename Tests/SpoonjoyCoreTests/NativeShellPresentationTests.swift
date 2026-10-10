import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Root shell stays the same view across sync states")
struct NativeShellPresentationTests {
    private static let chef = ChefSummary(id: "chef_ari", username: "ari")

    @Test("every state with a kitchen to show uses the one kitchen shell")
    func kitchenStatesShareOneShell() {
        let empty = Self.emptyContent()
        let kitchenStates: [NativeAppBootstrapState] = [
            .liveSynced(empty),
            .offlineStale(empty),
            .queuedWork(empty),
            .conflict(empty),
            .blocker(empty),
            .destructiveConfirmation(empty)
        ]
        for state in kitchenStates {
            #expect(state.shellPresentation(isShowingSettings: false) == .kitchen)
            #expect(state.shellPresentation(isShowingSettings: true) == .kitchen)
        }
        #expect(NativeAppBootstrapState.signedOut(empty).shellPresentation(isShowingSettings: false) == .signedOut)
        #expect(NativeAppBootstrapState.restoringCache(empty).shellPresentation(isShowingSettings: false) == .restoring)
    }

    @Test("a failed sync keeps showing a kitchen that has something in it")
    func failedSyncKeepsAKitchenWithContent() {
        let empty = Self.emptyContent()
        let withRecipe = empty.copy(recipes: [Self.recipe()])
        let withCookbook = empty.copy(cookbooks: [Self.cookbook()])
        let withShopping = empty.copy(shoppingList: Self.shoppingList(checked: false))
        let withOnlyCheckedShopping = empty.copy(shoppingList: Self.shoppingList(checked: true))

        #expect(NativeAppBootstrapState.syncFailed(withRecipe, message: "offline").shellPresentation(isShowingSettings: false) == .kitchen)
        #expect(NativeAppBootstrapState.syncFailed(withCookbook, message: "offline").shellPresentation(isShowingSettings: false) == .kitchen)
        #expect(NativeAppBootstrapState.syncFailed(withShopping, message: "offline").shellPresentation(isShowingSettings: false) == .kitchen)
        #expect(NativeAppBootstrapState.syncFailed(withOnlyCheckedShopping, message: "offline").shellPresentation(isShowingSettings: false) == .syncFailed(message: "offline"))
        #expect(NativeAppBootstrapState.syncFailed(empty, message: "offline").shellPresentation(isShowingSettings: false) == .syncFailed(message: "offline"))
        #expect(NativeAppBootstrapState.syncFailed(withRecipe, message: "offline").shellPresentation(isShowingSettings: true) == .settingsAfterSyncFailure(message: "offline"))
    }

    /// SwiftUI gives each call site in a view builder its own identity. With one `platformNavigation` call per state,
    /// a sync that moved the app from "queued" to "synced" replaced the whole shell and reset tabs, search and child
    /// view state. One call site keeps the shell the same view whatever kitchen state the app is in.
    @Test("the root view builds the kitchen shell from a single call site")
    func rootViewHasOneKitchenShellCallSite() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: rootURL.appendingPathComponent("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private var rootContent: some View {"))
        let end = try #require(source.range(of: "\n    }\n", range: start.upperBound..<source.endIndex))
        let rootContent = source[start.upperBound..<end.lowerBound]
        #expect(rootContent.components(separatedBy: "platformNavigation(").count - 1 == 1)
        // An identity keyed on the sync state would reset the shell just the same.
        #expect(!rootContent.contains(".id("))
    }

    private static func emptyContent() -> NativeShellContentState {
        NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
    }

    private static func recipe() -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/recipe_toast")!
        return Recipe(
            id: "recipe_toast",
            title: "Toast",
            description: nil,
            servings: nil,
            chef: chef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/recipe_toast",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(creditText: "Recipe by ari", canonicalURL: canonicalURL, sourceURLRaw: nil, sourceHost: nil, sourceRecipe: nil),
            createdAt: "2026-07-01T10:00:00.000Z",
            updatedAt: "2026-07-01T10:00:00.000Z",
            steps: [],
            cookbooks: []
        )
    }

    private static func cookbook() -> Cookbook {
        let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/cookbook_shelf")!
        return Cookbook(
            id: "cookbook_shelf",
            title: "Shelf",
            chef: chef,
            recipeCount: 0,
            cover: CookbookCover(imageURLs: []),
            href: "/cookbooks/cookbook_shelf",
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(creditText: "Cookbook by ari", canonicalURL: canonicalURL),
            createdAt: "2026-07-01T10:00:00.000Z",
            updatedAt: "2026-07-01T10:00:00.000Z",
            recipes: []
        )
    }

    private static func shoppingList(checked: Bool) -> ShoppingListState {
        ShoppingListState(
            id: "shopping_ari",
            chef: chef,
            items: [
                ShoppingListItem(
                    id: "item_salt",
                    name: "salt",
                    quantity: nil,
                    unit: nil,
                    checked: checked,
                    checkedAt: checked ? "2026-07-01T10:00:00.000Z" : nil,
                    deletedAt: nil,
                    categoryKey: nil,
                    iconKey: nil,
                    sortIndex: 0,
                    updatedAt: "2026-07-01T10:00:00.000Z"
                )
            ],
            nextCursor: "",
            updatedAt: "2026-07-01T10:00:00.000Z"
        )
    }
}
