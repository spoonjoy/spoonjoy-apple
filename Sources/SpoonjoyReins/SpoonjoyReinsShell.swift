import Foundation
import OuroReins
import SpoonjoyCore

/// Spoonjoy's phone shell without SwiftUI, driven by Ouro Reins: the live store, and `SpoonjoyShell`, the Core model
/// `PlatformNavigationView` runs for every tab tap, back swipe and link.
///
/// Each screen's node lives in `Nodes/` and reads the same Core view models its SwiftUI view reads. Its actions call the
/// same `SpoonjoyShell` moves and store methods the view's handlers call, so a headless journey and the app take one path.
/// What the view keeps in `@State` (an unsaved editor draft, a search field) the shell keeps in `page`.
@MainActor
public final class SpoonjoyReinsShell {
    public let store: NativeLiveAppStore
    public let fixtures: SpoonjoyReinsFixtures
    public private(set) var shell: SpoonjoyShell
    /// A sheet over the page (Add a recipe, a report, a confirmation), as the view presents with `.sheet`.
    public internal(set) var sheet: SpoonjoyReinsSheet?
    /// Page state the SwiftUI views keep in `@State`.
    public internal(set) var page = SpoonjoyReinsPageState()
    let timestamp: () -> String
    /// The kitchen folder this launch reads, where the app keeps its state files.
    public let directory: URL?
    /// Report and block, as the root view hands it to every screen (`\.moderation`), with its ledger beside the
    /// app state so it survives a relaunch.
    public let moderation: ModerationController
    /// The folder the kitchen lives in, so what the app keeps outside the store (step timers, the recipe page's
    /// checks) survives a relaunch too.
    public var kitchenDirectory: URL? { directory }
    /// Cook mode's own state outside the store: the step timers, the mic and the lines it shows (`Nodes/CookNode.swift`).
    lazy var cook = SpoonjoyReinsCook(shell: self)

    public init(store: NativeLiveAppStore, fixtures: SpoonjoyReinsFixtures = SpoonjoyReinsFixtures(), route: AppRoute = .kitchen, directory: URL? = nil) {
        self.store = store
        self.fixtures = fixtures
        self.shell = SpoonjoyShell(route: route)
        self.timestamp = fixtures.timestamp
        self.directory = directory
        self.moderation = ModerationController(
            store: ChefModerationLedgerStore(directoryURL: directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-reins-moderation")),
            send: { [store] request, handling in try await store.executeSettingsActionRequest(request, responseHandling: handling) }
        )
    }

    public var navigation: AppNavigationState { shell.navigation }
    public var compactTabs: CompactTabNavigation { shell.compactTabs }
    public var content: NativeShellContentState { store.bootstrapState.contentState }

    // MARK: The shell's moves (SpoonjoyShell, as PlatformNavigationView calls them)

    func move(_ change: (inout SpoonjoyShell) -> Void) {
        change(&shell)
        rememberPage()
    }

    func navigate(to route: AppRoute) { move { $0.navigate(to: route) } }
    func select(_ tab: CompactTab) { move { $0.select(tab) } }
    func goBack() { move { $0.goBack() } }
    func openRecipe(_ id: String) { move { $0.openRecipe(id) } }
    func openCookbook(_ id: String) { move { $0.openCookbook(id) } }

    /// `startCooking(_:)`, then CookModeView's `.onAppear`, which tells the store cook mode opened.
    func startCooking(_ id: String) {
        move { $0.startCooking(id) }
        store.cookModeOpened(recipeID: id)
        cook.opened(id)
    }

    func closeCook(_ id: String) {
        cook.closed(id)
        move { $0.closeCook(id) }
    }

    func cookProgress(for recipe: Recipe) -> CookModeProgress {
        SpoonjoyShell.cookProgress(for: recipe, saved: content.cookProgress(for: recipe.id), startedAt: timestamp())
    }
}

/// What the views keep in `@State`, for the screens Reins models.
public struct SpoonjoyReinsPageState {
    /// The recipe editors open, by visit, and what each shows over its draft (Nodes/EditorNode.swift).
    public internal(set) var editors = SpoonjoyReinsEditorPages()
    /// Each Recipes list as it last loaded, by route (Nodes/RecipesNode.swift).
    public internal(set) var recipeCatalogs: [String: RecipeCatalogState] = [:]
    /// The Search tab's last run (Nodes/SearchNode.swift).
    public internal(set) var search: SearchSurfaceViewModel?
    /// The recipe page's scale and checks, by recipe, and whether its Serves stepper is open (Nodes/RecipeNode.swift).
    public internal(set) var recipePages = SpoonjoyReinsRecipePages()
    /// The link typed into Add a recipe (Nodes/AddRecipeNode.swift).
    public internal(set) var addRecipeLink = ""
    /// Each recipe page's Send to Reminders flow (RecipeDetailView's `@State remindersSender`).
    var remindersSenders: [String: SpoonjoyRemindersSender] = [:]
    /// Settings' status line after an action (SettingsView's `settingsActionMessage`).
    var settingsMessage: String?
    /// The search typed into a cookbook page's "Search this cookbook" field.
    var cookbookQuery = ""
    /// Web pages the app handed to Safari (a secure sign-out, a hand-off), in order.
    public internal(set) var openedURLs: [URL] = []

    public init() {}
}

/// A sheet the shell presents over the page.
public enum SpoonjoyReinsSheet: Equatable {
    case addRecipe
    /// The report sheet (ReportContentSheet): the reason picked so far, and whether the report was sent.
    case report(ContentReportTarget, subject: String, reason: ContentReportReason?, sent: Bool)
    /// The Block <chef> confirmation.
    case blockChef(BlockedChef, from: ContentReportTarget)
    /// Settings > Blocked chefs.
    case blockedChefs
    /// Settings > Delete account….
    case deleteAccount(AccountDeletionForm)
    /// Settings' "Sign out?" confirmation.
    case confirmSignOut

    var name: String {
        switch self {
        case .addRecipe: "addRecipe"
        case .report: "report"
        case .blockChef: "blockChef"
        case .blockedChefs: "blockedChefs"
        case .deleteAccount: "deleteAccount"
        case .confirmSignOut: "confirmSignOut"
        }
    }
}

// MARK: - Nodes

struct RecipeID: ReinsInput {
    let id: String
}

extension SpoonjoyReinsShell: ReinsDrivable {
    public var reinsNode: ReinsNode {
        // The root view's `.onChange(of: trustedAccountID, initial: true) { moderation.useAccount($0) }`.
        moderation.useAccount(content.trustedAccountID)
        var tabbed = ReinsNode.tabs(selected: compactTabs.selectedTab.rawValue, tabs: CompactTab.allCases.map(\.rawValue), select: { [unowned self] in
            if let tab = CompactTab(rawValue: $0) { self.select(tab) }
        }, child: tabStack)
        carryCookingNowSwitcher(on: &tabbed)
        // A sheet is modal: the page and tab bar under it aren't reachable until it closes.
        if let sheet {
            return ReinsNode("spoonjoy", state: shellState, child: ReinsNode("sheet", state: ["sheet": .string(sheet.name)], child: sheetNode(sheet)))
        }
        // Signed out, every page but Settings is the sign-in screen (SpoonjoyRootView.signedOutContent).
        if store.bootstrapState.shellPresentation(isShowingSettings: navigation.route == .settings) == .signedOut {
            return ReinsNode("spoonjoy", state: shellState, child: navigation.route == .settings ? standaloneSettingsNode : signedOutNode)
        }
        guard let cover = compactTabs.fullScreenRoute, case .recipeDetail(let id, .cook) = cover, let recipe = content.recipe(id: id) else {
            return ReinsNode("spoonjoy", state: shellState, child: tabbed)
        }
        // Cook mode covers the tabs (CompactRoutePlacement.fullScreen): the tab bar isn't reachable, so it isn't in the
        // tree; the cover lends the way back.
        let cook = ReinsNode("cover", state: ["route": .string(cover.stateIdentifier)], lends: [
            ReinsAction("goBack", "Close cook mode") { [unowned self] in self.closeCook(id) },
        ], child: cookNode(recipe))
        return ReinsNode("spoonjoy", state: shellState, child: cook)
    }

    private var shellState: ReinsValue {
        ["route": .string(navigation.route.stateIdentifier), "bootstrap": .string(bootstrapName)]
    }

    private var bootstrapName: String {
        String(describing: store.bootstrapState).split(separator: "(").first.map(String.init) ?? "unknown"
    }

    /// The selected tab's stack. It lends `goBack` only when `SpoonjoyShell.canGoBack` says there is a way back: an
    /// editor leaves through Cancel or Save.
    private var tabStack: ReinsNode {
        let depth = compactTabs.path(for: compactTabs.selectedTab).count
        let child = page(for: compactTabs.visibleRoute)
        guard shell.canGoBack else {
            return ReinsNode("stack", state: ["depth": .number(Double(depth))], child: child)
        }
        return .stack(depth: depth, goBack: { [unowned self] in self.goBack() }, child: child)
    }

    func sheetNode(_ sheet: SpoonjoyReinsSheet) -> ReinsNode {
        switch sheet {
        case .addRecipe: addRecipeNode
        case .report(let target, let subject, let reason, let sent): reportSheetNode(target, subject: subject, reason: reason, sent: sent)
        case .blockChef(let chef, let target): blockChefSheetNode(chef, from: target)
        case .blockedChefs: blockedChefsSheetNode
        case .deleteAccount(let form): deleteAccountSheetNode(form)
        case .confirmSignOut: confirmSignOutSheetNode
        }
    }

    /// The page each route shows. One case per screen; each lives in `Nodes/`.
    func page(for route: AppRoute) -> ReinsNode {
        switch route {
        case .kitchen: kitchenNode
        case .recipeDetail(let id, _): content.recipe(id: id).map(recipeNode) ?? notFoundNode(route)
        case .recipeEditor(let id): editorNode(id)
        case .recipeCoverControls: unmodelled("coverControls")
        case .recipes, .savedRecipes, .everyoneRecipes: recipesNode(route)
        case .cookbooks: cookbooksNode
        case .cookbookDetail(let id): cookbookNode(id)
        case .search(let query, let scope): searchNode(query: query, scope: scope)
        case .shoppingList: shoppingNode
        case .capture: captureNode
        case .settings: settingsNode
        case .chefs, .profile, .profileGraph: unmodelled("chefs")
        case .unknownLink: notFoundNode(route)
        }
    }

    func unmodelled(_ name: String) -> ReinsNode {
        ReinsNode(name, state: ["route": .string(navigation.route.stateIdentifier), "x-unmodelled": "no journey drives this screen headless yet"])
    }
}
