import SpoonjoyCore
import SwiftUI

struct PlatformNavigationView: View {
    @Binding var navigation: AppNavigationState
    @Binding var search: SearchState

    private let contentState: NativeShellContentState
    private let offlineIndicatorState: OfflineIndicatorState
    private let dismissOfflineIndicator: @MainActor @Sendable () -> Void
    private let queueMutation: @Sendable (NativeQueuedMutation) async throws -> Void
    private let queueMutations: @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    private let discardQueuedMutation: @Sendable (String) async throws -> Void
    private let executeRecipeEditorRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> Void
    private let recordCookProgress: @MainActor @Sendable (CookModeProgress) -> Void
    private let syncTriggerCoordinator: NativeSyncTriggerCoordinator

    init(
        navigation: Binding<AppNavigationState>,
        search: Binding<SearchState>,
        contentState: NativeShellContentState,
        offlineIndicatorState: OfflineIndicatorState,
        dismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void,
        queueMutation: @escaping @Sendable (NativeQueuedMutation) async throws -> Void,
        queueMutations: @escaping @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        discardQueuedMutation: @escaping @Sendable (String) async throws -> Void,
        executeRecipeEditorRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> Void,
        recordCookProgress: @escaping @MainActor @Sendable (CookModeProgress) -> Void,
        syncTriggerCoordinator: NativeSyncTriggerCoordinator
    ) {
        _navigation = navigation
        _search = search
        self.contentState = contentState
        self.offlineIndicatorState = offlineIndicatorState
        self.dismissOfflineIndicator = dismissOfflineIndicator
        self.queueMutation = queueMutation
        self.queueMutations = queueMutations
        self.discardQueuedMutation = discardQueuedMutation
        self.executeRecipeEditorRequest = executeRecipeEditorRequest
        self.recordCookProgress = recordCookProgress
        self.syncTriggerCoordinator = syncTriggerCoordinator
    }

    var body: some View {
        let spotlightDocuments = spotlightIndexDocuments
        NavigationSplitView {
            sidebar
                .navigationTitle("Spoonjoy")
        } detail: {
            NavigationStack {
                detailContent
                    .navigationTitle(title(for: navigation.route))
#if os(iOS)
                    .navigationBarTitleDisplayMode(.large)
#endif
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationContent(for: route)
            }
            .searchable(text: searchText, prompt: "Search Spoonjoy")
            .searchScopes(searchScope) {
                ForEach(SearchScope.allCases, id: \.rawValue) { scope in
                    Text(label(for: scope)).tag(scope)
                }
            }
            .onSubmit(of: .search) {
                navigation.navigate(to: search.route)
            }
            .spoonjoyToolbar(navigation: $navigation, search: $search)
            .safeAreaInset(edge: .bottom) {
                OfflineStatusView(display: offlineIndicatorState.display, onDismiss: dismissOfflineIndicator)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .background(KitchenTableTheme.bone.opacity(0.94))
            }
            .task(id: spotlightIndexIdentity) {
                await Self.indexSpotlightIfAvailable(documents: spotlightDocuments)
            }
            .task(id: contentState.environment.rawValue) {
                _ = try? await syncTriggerCoordinator.handle(.foreground)
            }
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
#endif
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            sidebarLink(section: .kitchen, title: "Kitchen", systemImage: "house")
            sidebarLink(section: .recipes, title: "Recipes", systemImage: "book.closed")
            sidebarLink(section: .cookbooks, title: "Cookbooks", systemImage: "books.vertical")
            sidebarLink(section: .shoppingList, title: "Shopping", systemImage: "checklist")
            sidebarLink(section: .search, title: "Search", systemImage: "magnifyingglass")
            sidebarLink(section: .capture, title: "Capture", systemImage: "camera")
            sidebarLink(section: .settings, title: "Settings", systemImage: "gearshape")
        }
    }

    @ViewBuilder private var detailContent: some View {
        destinationContent(for: navigation.route)
    }

    @ViewBuilder private func destinationContent(for route: AppRoute) -> some View {
        switch route {
        case .kitchen:
            KitchenView(
                kitchen: contentState.kitchen,
                recipes: contentState.recipes,
                cookbooks: contentState.cookbooks,
                openRecipe: openRecipe,
                startCooking: startCooking,
                openCookbook: openCookbook
            )
        case .recipes:
            RecipesView(viewModel: recipeCatalogViewModel, openRoute: openRoute)
        case .recipeDetail(let id, .detail):
            RecipeDetailRouteView(
                recipeID: id,
                repository: recipeCatalogRepository,
                initialViewModel: recipe(id: id).map(recipeDetailScreenViewModel(for:)),
                actionConnectivity: recipeActionConnectivity,
                context: recipeDetailContext(for:),
                actionPlanner: { viewModel, context in
                    recipeActionsViewModel(for: viewModel, context: context)
                },
                openRoute: openRoute,
                performRecipeAction: performRecipeAction
            )
        case .recipeDetail(let id, .cook):
            CookModeRouteView(
                recipeID: id,
                repository: recipeCatalogRepository,
                initialRecipe: recipe(id: id),
                progress: cookProgress(for:),
                progressDidChange: recordCookProgress,
                close: {
                    openRecipe(id)
                }
            )
        case .recipeEditor(let id):
            if let editorViewModel = recipeEditorViewModel(id: id) {
                RecipeEditorView(
                    viewModel: editorViewModel,
                    mutationDidPlan: handleRecipeEditorPlan,
                    mutationsDidQueue: queueMutations,
                    conflictDidDiscardLocalChange: discardRecipeEditorLocalChange,
                    close: openRoute
                )
            } else {
                ShellPlaceholderView(title: "Recipe Editor", systemImage: "pencil", detail: "Recipe unavailable.")
            }
        case .recipeCoverControls(let id):
            ShellPlaceholderView(title: "Recipe Covers", systemImage: "photo.on.rectangle", detail: id)
        case .cookbooks:
            CookbooksView(cookbooks: contentState.cookbooks, openCookbook: openCookbook)
        case .cookbookDetail(let id):
            if let cookbook = cookbook(id: id) {
                CookbookDetailPlaceholder(cookbook: cookbook)
            } else {
                ShellPlaceholderView(title: "Cookbook", systemImage: "book", detail: id)
            }
        case .shoppingList:
            if let shoppingViewModel {
                ShoppingListView(
                    viewModel: shoppingViewModel,
                    viewModelDidChange: { nextViewModel, item, checked, changedAt in
                        queueShoppingListMutation(nextViewModel.shoppingList, item: item, checked: checked, changedAt: changedAt)
                    }
                )
            } else {
                ShellPlaceholderView(title: "Shopping", systemImage: "checklist", detail: "Shopping list unavailable.")
            }
        case .search(let query, let scope):
            SearchView(
                search: $search,
                recipes: contentState.recipes,
                cookbooks: contentState.cookbooks,
                shoppingList: contentState.shoppingList,
                openRecipe: openRecipe,
                openCookbook: openCookbook,
                openShoppingItem: { _ in
                    navigation.navigate(to: .shoppingList)
                },
                openChef: { username in
                    search.update(query: username, scope: .chefs)
                    navigation.navigate(to: search.route)
                }
            )
            .onAppear {
                search.apply(route: .search(query: query, scope: scope))
            }
        case .capture:
            if let captureViewModel {
                CaptureDraftView(viewModel: captureViewModel, draftDidChange: { _ in })
            } else {
                ShellPlaceholderView(title: "Capture", systemImage: "camera", detail: "Capture drafts will appear here after sign-in or offline restore.")
            }
        case .settings:
            SettingsView(
                viewModel: contentState.settingsViewModel,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case .unknownLink:
            ShellPlaceholderView(title: "Link Not Found", systemImage: "link.badge.plus", detail: "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link.")
        }
    }

    private var searchText: Binding<String> {
        Binding(
            get: { search.query },
            set: { value in
                search.update(query: value, scope: search.scope)
            }
        )
    }

    private var searchScope: Binding<SearchScope> {
        Binding(
            get: { search.scope },
            set: { scope in
                search.update(query: search.query, scope: scope)
            }
        )
    }

    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { navigation.sidebarSelection },
            set: { section in
                guard let section else { return }
                navigateToSidebar(section)
            }
        )
    }

    private func sidebarLink(section: AppSection, title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .tag(section)
    }

    private func navigateToSidebar(_ section: AppSection) {
        switch section {
        case .kitchen:
            navigation.navigate(to: .kitchen)
        case .recipes:
            navigation.navigate(to: .recipes)
        case .cookbooks:
            navigation.navigate(to: .cookbooks)
        case .shoppingList:
            navigation.navigate(to: .shoppingList)
        case .search:
            search.apply(route: search.route)
            navigation.navigate(to: search.route)
        case .capture:
            navigation.navigate(to: .capture)
        case .settings:
            navigation.navigate(to: .settings)
        }
    }

    private func title(for route: AppRoute) -> String {
        switch route {
        case .kitchen:
            "Kitchen"
        case .recipes, .recipeDetail, .recipeEditor, .recipeCoverControls:
            "Recipes"
        case .cookbooks, .cookbookDetail:
            "Cookbooks"
        case .shoppingList:
            "Shopping"
        case .search:
            "Search"
        case .capture:
            "Capture"
        case .settings:
            "Settings"
        case .unknownLink:
            "Unknown Link"
        }
    }

    private func label(for scope: SearchScope) -> String {
        switch scope {
        case .all:
            "All"
        case .recipes:
            "Recipes"
        case .cookbooks:
            "Cookbooks"
        case .chefs:
            "Chefs"
        case .shoppingList:
            "Shopping"
        }
    }

    private func recipe(id: String) -> Recipe? {
        contentState.recipes.first { $0.id == id }
    }

    private func cookbook(id: String) -> Cookbook? {
        contentState.cookbooks.first { $0.id == id }
    }

    private func cookProgress(for recipe: Recipe) -> CookModeProgress {
        contentState.cookProgress(for: recipe.id) ?? CookModeProgress.starting(recipe: recipe, startedAt: timestamp())
    }

    private func openRecipe(_ id: String) {
        navigation.navigate(to: .recipeDetail(id: id, presentation: .detail))
    }

    private func openRoute(_ route: AppRoute) {
        navigation.navigate(to: route)
    }

    private func startCooking(_ id: String) {
        navigation.navigate(to: .recipeDetail(id: id, presentation: .cook))
    }

    private func openCookbook(_ id: String) {
        navigation.navigate(to: .cookbookDetail(id: id))
    }

    private var shoppingViewModel: ShoppingListViewModel? {
        contentState.shoppingList.map(ShoppingListViewModel.init(shoppingList:))
    }

    private var recipeCatalogRepository: any RecipeCatalogRepository {
        let catalog = contentState.recipeCatalog
        let snapshotRepository = SnapshotRecipeCatalogRepository(
            page: catalog,
            details: contentState.recipes.map { recipe in
                RecipeCatalogDetailResult(recipe: recipe, source: catalog.source)
            }
        )
        let liveRepository = LiveRecipeCatalogRepository(configuration: contentState.configuration)
        return FallbackRecipeCatalogRepository(primary: liveRepository, fallback: snapshotRepository)
    }

    private var recipeCatalogViewModel: RecipeCatalogViewModel {
        let viewModel = RecipeCatalogViewModel(repository: recipeCatalogRepository)
        viewModel.apply(page: contentState.recipeCatalog)
        return viewModel
    }

    private func recipeDetailScreenViewModel(for recipe: Recipe) -> RecipeDetailScreenViewModel {
        RecipeDetailScreenViewModel(
            result: RecipeCatalogDetailResult(recipe: recipe, source: contentState.recipeCatalog.source),
            context: recipeDetailContext(for: recipe)
        )
    }

    private func recipeActionsViewModel(for viewModel: RecipeDetailScreenViewModel, context: RecipeDetailContext) -> RecipeActionsViewModel {
        let plannedAt = timestamp()
        return RecipeActionsViewModel(
            recipe: viewModel.recipe,
            context: context,
            connectivity: recipeActionConnectivity,
            now: { plannedAt }
        )
    }

    private func recipeDetailContext(for recipe: Recipe) -> RecipeDetailContext {
        RecipeDetailContext(
            currentChefID: currentChefID,
            availableCookbooks: contentState.cookbooks.map { cookbook in
                RecipeCookbookSaveOption(id: cookbook.id, title: cookbook.title)
            },
            savedInCookbookIDs: Set(recipe.cookbooks.map(\.id)),
            hasIngredientsInShoppingList: hasShoppingListIngredient(for: recipe),
            now: Date()
        )
    }

    private var currentChefID: String? {
        switch contentState.authSessionState {
        case .signedOut:
            nil
        case .authenticated(let session), .refreshRequired(let session):
            session.accountID
        }
    }

    private func recipeEditorViewModel(id: String?) -> RecipeEditorViewModel? {
        let chefID = currentChefID ?? "signed-out"
        switch id {
        case .some(let recipeID):
            guard let recipe = recipe(id: recipeID) else {
                return nil
            }
            return RecipeEditorViewModel(
                mode: .edit(recipe: recipe, currentChefID: chefID),
                connectivity: recipeEditorConnectivity,
                conflict: recipeEditorConflict(for: recipeID),
                queuedRecipeMutations: contentState.queuedMutations,
                now: timestamp
            )
        case nil:
            return RecipeEditorViewModel(
                mode: .create(currentChefID: chefID, draft: .blank(currentChefID: chefID)),
                connectivity: recipeEditorConnectivity,
                conflict: nil,
                queuedRecipeMutations: contentState.queuedMutations,
                now: timestamp
            )
        }
    }

    private var recipeEditorConnectivity: RecipeEditorConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var recipeActionConnectivity: RecipeActionConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private func recipeEditorConflict(for recipeID: String) -> RecipeEditorConflict? {
        for conflict in contentState.syncConflicts {
            guard let mutation = contentState.queuedMutations.first(where: { $0.clientMutationID == conflict.clientMutationID }),
                  mutation.optimisticRecipeID == recipeID else {
                continue
            }

            return RecipeEditorConflict(
                resourceID: recipeID,
                serverRevision: conflict.serverRevision,
                localClientMutationID: conflict.clientMutationID,
                message: conflict.message
            )
        }

        return nil
    }

    private func handleRecipeEditorPlan(_ plan: RecipeEditorMutationPlan) async throws {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRecipeEditorRequest(requestBuilder)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return
                }
                throw error
            }
        }
    }

    private func performRecipeAction(_ plan: RecipeActionPlan) async throws {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRecipeEditorRequest(requestBuilder)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return
                }
                throw error
            }
        }
    }

    private func discardRecipeEditorLocalChange(_ conflict: RecipeEditorConflict) async throws {
        try await discardQueuedMutation(conflict.localClientMutationID)
    }

    private func hasShoppingListIngredient(for recipe: Recipe) -> Bool {
        guard let shoppingList = contentState.shoppingList else {
            return false
        }

        let shoppingNames = Set(shoppingList.activeItems.map { $0.name.lowercased() })
        return recipe.steps
            .flatMap(\.ingredients)
            .contains { shoppingNames.contains($0.name.lowercased()) }
    }

    private var spotlightIndexIdentity: String {
        [
            contentState.recipes.map(\.id).joined(separator: ","),
            contentState.cookbooks.map(\.id).joined(separator: ","),
            contentState.searchResultsByScope[search.scope]?.joined(separator: ",") ?? "search-unavailable",
            contentState.shoppingList?.activeItems.map(\.id).joined(separator: ",") ?? "shopping-unavailable"
        ].joined(separator: "|")
    }

    private var spotlightIndexDocuments: [SpotlightIndexDocument] {
        guard let shoppingList = contentState.shoppingList else {
            return []
        }

        return SpotlightIndexPlan.documents(
            recipes: contentState.recipes,
            cookbooks: contentState.cookbooks,
            shoppingList: shoppingList
        )
    }

    private var captureViewModel: CaptureDraftViewModel? {
        contentState.captureDraft.map(CaptureDraftViewModel.init(draft:))
    }

    private func queueShoppingListMutation(
        _: ShoppingListState,
        item: ShoppingListItem,
        checked: Bool,
        changedAt: String
    ) {
        let mutation = NativeQueuedMutation.shoppingCheckItem(
            itemID: item.id,
            checked: checked,
            clientMutationID: "native-check-\(item.id)-\(Self.safeIdentifier(changedAt))",
            createdAt: changedAt
        )
        Task {
            try? await queueMutation(mutation)
        }
    }

    private static func indexSpotlightIfAvailable(documents: [SpotlightIndexDocument]) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *), !documents.isEmpty {
            try? await SpoonjoySpotlightIndexer().index(documents: documents)
        }
#endif
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func safeIdentifier(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined()
    }
}

private struct ShellPlaceholderView: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

private struct CookbookDetailPlaceholder: View {
    let cookbook: Cookbook

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(cookbook.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(cookbook.attribution.creditText)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.secondary)
            CookbookShelf(cookbooks: [cookbook]) { _ in }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
    }
}
