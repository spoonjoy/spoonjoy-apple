import SpoonjoyCore
import SwiftUI

struct RecipeDetailRouteView: View {
    let recipeID: String
    let repository: any RecipeCatalogRepository
    let spoonRepository: any SpoonCookLogRepository
    let snapshotViewModel: RecipeDetailScreenViewModel?
    let actionConnectivity: RecipeActionConnectivity
    let shoppingViewModel: ShoppingSurfaceViewModel
    let context: (Recipe) -> RecipeDetailContext
    let actionPlanner: @MainActor @Sendable (RecipeDetailScreenViewModel, RecipeDetailContext) -> RecipeActionsViewModel
    let spoonCookLogViewModel: @MainActor @Sendable (RecipeDetailScreenViewModel, RecipeDetailSpoonSummary) -> SpoonCookLogViewModel
    let spoonCookLogDraft: @MainActor @Sendable (RecipeDetailScreenViewModel) -> SpoonCookLogDraftState?
    let openRoute: (AppRoute) -> Void
    let performRecipeAction: @MainActor @Sendable (RecipeActionPlan) async throws -> Void
    let performSpoonCookLogAction: @MainActor @Sendable (SpoonCookLogMutationPlan) async throws -> Void
    let recordSpoonCookLogDraft: @MainActor @Sendable (SpoonCookLogDraftState?, String) -> Void
    let discardSpoonCookLogConflict: @MainActor @Sendable (String) async throws -> Void
    let performShoppingAction: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var viewModel: RecipeDetailScreenViewModel?
    @State private var errorMessage: String?

    init(
        recipeID: String,
        repository: any RecipeCatalogRepository,
        spoonRepository: any SpoonCookLogRepository,
        initialViewModel: RecipeDetailScreenViewModel?,
        actionConnectivity: RecipeActionConnectivity,
        shoppingViewModel: ShoppingSurfaceViewModel,
        context: @escaping (Recipe) -> RecipeDetailContext,
        actionPlanner: @escaping @MainActor @Sendable (RecipeDetailScreenViewModel, RecipeDetailContext) -> RecipeActionsViewModel,
        spoonCookLogViewModel: @escaping @MainActor @Sendable (RecipeDetailScreenViewModel, RecipeDetailSpoonSummary) -> SpoonCookLogViewModel,
        spoonCookLogDraft: @escaping @MainActor @Sendable (RecipeDetailScreenViewModel) -> SpoonCookLogDraftState?,
        openRoute: @escaping (AppRoute) -> Void,
        performRecipeAction: @escaping @MainActor @Sendable (RecipeActionPlan) async throws -> Void,
        performSpoonCookLogAction: @escaping @MainActor @Sendable (SpoonCookLogMutationPlan) async throws -> Void,
        recordSpoonCookLogDraft: @escaping @MainActor @Sendable (SpoonCookLogDraftState?, String) -> Void,
        discardSpoonCookLogConflict: @escaping @MainActor @Sendable (String) async throws -> Void,
        performShoppingAction: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.recipeID = recipeID
        self.repository = repository
        self.spoonRepository = spoonRepository
        snapshotViewModel = initialViewModel
        self.actionConnectivity = actionConnectivity
        self.shoppingViewModel = shoppingViewModel
        self.context = context
        self.actionPlanner = actionPlanner
        self.spoonCookLogViewModel = spoonCookLogViewModel
        self.spoonCookLogDraft = spoonCookLogDraft
        self.openRoute = openRoute
        self.performRecipeAction = performRecipeAction
        self.performSpoonCookLogAction = performSpoonCookLogAction
        self.recordSpoonCookLogDraft = recordSpoonCookLogDraft
        self.discardSpoonCookLogConflict = discardSpoonCookLogConflict
        self.performShoppingAction = performShoppingAction
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _viewModel = State(initialValue: initialViewModel)
    }

    var body: some View {
        Group {
            if let viewModel {
                RecipeDetailView(
                    viewModel: viewModel,
                    actionConnectivity: actionConnectivity,
                    shoppingViewModel: shoppingViewModel,
                    actionPlanner: actionPlanner,
                    spoonCookLogViewModel: spoonCookLogViewModel,
                    spoonCookLogDraft: spoonCookLogDraft,
                    openRoute: openRoute,
                    performRecipeAction: performRecipeAction,
                    performSpoonCookLogAction: performSpoonCookLogAction,
                    recordSpoonCookLogDraft: recordSpoonCookLogDraft,
                    discardSpoonCookLogConflict: discardSpoonCookLogConflict,
                    performShoppingAction: performShoppingAction,
                    onDismissOfflineIndicator: onDismissOfflineIndicator
                )
            } else if let errorMessage {
                Label(errorMessage, systemImage: "text.book.closed")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .background(KitchenTableTheme.bone)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KitchenTableTheme.bone)
            }
        }
        .task(id: recipeID) {
            await loadRecipe()
        }
        .onChange(of: snapshotViewModel) { _, nextViewModel in
            guard let nextViewModel, nextViewModel != viewModel else {
                return
            }
            viewModel = nextViewModel
        }
    }

    @MainActor private func loadRecipe() async {
        do {
            let result = try await repository.recipeDetail(id: recipeID)
            let detailResult = await detailResultByLoadingFullSpoonList(result)
            viewModel = RecipeDetailScreenViewModel(result: detailResult, context: context(detailResult.recipe))
            errorMessage = nil
        } catch {
            if viewModel == nil {
                errorMessage = "Recipe unavailable."
            }
        }
    }

    private func detailResultByLoadingFullSpoonList(_ result: RecipeCatalogDetailResult) async -> RecipeCatalogDetailResult {
        do {
            let cookLog = try await fullCookLog(recipeID: result.recipe.id)
            return RecipeCatalogDetailResult(
                recipe: result.recipe.replacingRecentSpoons(cookLog.spoons),
                source: result.source
            )
        } catch {
            return result
        }
    }

    private func fullCookLog(recipeID: String) async throws -> SpoonCookLogData {
        var cursor: PaginationCursor?
        var seenCursors = Set<String>()
        var spoons: [RecipeDetailRecentSpoon] = []

        while true {
            let page = try await spoonRepository.fetchCookLog(recipeID: recipeID, cursor: cursor, limit: 50)
            spoons.append(contentsOf: page.spoons)

            guard page.hasMore else {
                return SpoonCookLogData(spoons: spoons, nextCursor: page.nextCursor, hasMore: false)
            }
            guard let nextCursor = page.nextCursor else {
                throw RecipeDetailCookLogPaginationError.missingNextCursor
            }
            guard seenCursors.insert(nextCursor.rawValue).inserted else {
                throw RecipeDetailCookLogPaginationError.repeatedCursor(nextCursor.rawValue)
            }
            cursor = nextCursor
        }
    }
}

private enum RecipeDetailCookLogPaginationError: Error {
    case missingNextCursor
    case repeatedCursor(String)
}

struct RecipeDetailView: View {
    let viewModel: RecipeDetailScreenViewModel
    let actionConnectivity: RecipeActionConnectivity
    let shoppingViewModel: ShoppingSurfaceViewModel
    let actionPlanner: @MainActor @Sendable (RecipeDetailScreenViewModel, RecipeDetailContext) -> RecipeActionsViewModel
    let spoonCookLogViewModel: @MainActor @Sendable (RecipeDetailScreenViewModel, RecipeDetailSpoonSummary) -> SpoonCookLogViewModel
    let spoonCookLogDraft: @MainActor @Sendable (RecipeDetailScreenViewModel) -> SpoonCookLogDraftState?
    let openRoute: (AppRoute) -> Void
    let performRecipeAction: @MainActor @Sendable (RecipeActionPlan) async throws -> Void
    let performSpoonCookLogAction: @MainActor @Sendable (SpoonCookLogMutationPlan) async throws -> Void
    let recordSpoonCookLogDraft: @MainActor @Sendable (SpoonCookLogDraftState?, String) -> Void
    let discardSpoonCookLogConflict: @MainActor @Sendable (String) async throws -> Void
    let performShoppingAction: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome

    @State private var actionErrorMessage: String?
    @State private var actionStatusMessage: String?
    @State private var activeConfirmationDialog: RecipeActionConfirmationDialog?
    @State private var localSavedCookbookIDs: Set<String>?
    @State private var localHasIngredientsInShoppingList: Bool?
    @State private var shoppingScaleFactor: Double = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                offlineIndicator
                hero
                cookbookSpread
                ingredientReceipt
                method
                SpoonCookLogView(
                    viewModel: spoonCookLogViewModel(viewModel, viewModel.spoonSummary),
                    draft: spoonCookLogDraft(viewModel),
                    actionDidPlan: performSpoonCookLogAction,
                    draftDidChange: { draft in
                        recordSpoonCookLogDraft(draft, viewModel.id)
                    },
                    conflictDidRequestReview: discardSpoonCookLogConflict,
                    onDismissOfflineIndicator: onDismissOfflineIndicator
                )
                .id(viewModel.id)
                cookbookSave
                ownerTools
            }
            .padding()
        }
        .background(KitchenTableTheme.bone)
        .confirmationDialog(
            activeConfirmationDialog?.prompt.title ?? "",
            isPresented: Binding(
                get: { activeConfirmationDialog != nil },
                set: { isPresented in
                    if !isPresented {
                        activeConfirmationDialog = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let dialog = activeConfirmationDialog {
                Button(dialog.prompt.confirmButtonTitle, role: dialog.prompt.isDestructive ? .destructive : nil) {
                    runAction(.deleteRecipe(clientMutationID: dialog.clientMutationID, confirmation: .confirmed))
                    activeConfirmationDialog = nil
                }
                Button("Cancel", role: .cancel) {
                    activeConfirmationDialog = nil
                }
            }
        } message: {
            if let message = activeConfirmationDialog?.prompt.message {
                Text(message)
            }
        }
        .onAppear {
            syncSavedCookbookStateIfNeeded()
            syncShoppingStateIfNeeded()
        }
        .onChange(of: viewModel.id) { _, _ in
            localSavedCookbookIDs = viewModel.cookbookSave.savedCookbookIDs
            localHasIngredientsInShoppingList = viewModel.hasIngredientsInShoppingList
            shoppingScaleFactor = 1
        }
        .onChange(of: viewModel.cookbookSave.savedCookbookIDs) { _, nextIDs in
            localSavedCookbookIDs = nextIDs
        }
        .onChange(of: viewModel.hasIngredientsInShoppingList) { _, hasIngredients in
            localHasIngredientsInShoppingList = hasIngredients
        }
    }

    private var provenance: String {
        viewModel.cover.provenanceLabel ?? viewModel.recipe.attribution.creditText
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecipeCoverImage(url: viewModel.cover.imageURL)
            .frame(maxWidth: .infinity, minHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            .overlay(alignment: .bottomLeading) {
                Text(provenance)
                    .font(KitchenTableTheme.uiLabel)
                    .padding(8)
                    .background(KitchenTableTheme.photoOverlay)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("\(viewModel.title) cover image")

            Text(viewModel.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(viewModel.description ?? viewModel.recipe.attribution.creditText)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.secondary)

            Text(viewModel.chefAttribution)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)

            if let servingsLabel = viewModel.servingsLabel {
                Text(servingsLabel)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }

            if let sourceAttribution = viewModel.sourceAttribution {
                Label(sourceText(sourceAttribution), systemImage: "link")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if hasAction(.startCooking) {
                    Button("Start Cooking") { openRoute(viewModel.actions.startCookingRoute) }
                        .buttonStyle(.borderedProminent)
                }
                if hasAction(.fork) || hasAction(.makeVariation) {
                    Button {
                        runAction(.fork(
                            clientMutationID: clientMutationID(prefix: "fork"),
                            titleOverride: viewModel.actions.fork.titleOverride
                        ))
                    } label: {
                        Label(viewModel.actions.fork.label, systemImage: "arrow.branch")
                    }
                    .buttonStyle(.bordered)
                }
                if hasAction(.share), let shareURL = viewModel.actions.sharePayload?.publicURL {
                    ShareLink(item: shareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                if hasAction(.addToShoppingList) {
                    Stepper(value: $shoppingScaleFactor, in: 0.25...4, step: 0.25) {
                        Label("Scale \(shoppingScaleFactor.formatted(.number.precision(.fractionLength(0...2))))x", systemImage: "person.2")
                    }
                    .frame(maxWidth: 220)

                    Button {
                        addRecipeIngredients()
                    } label: {
                        Label(
                            hasIngredientsInShoppingList ? "In List" : "Add Ingredients",
                            systemImage: hasIngredientsInShoppingList ? "checkmark.circle.fill" : "cart.badge.plus"
                        )
                    }
                    .disabled(hasIngredientsInShoppingList)
                    .buttonStyle(.bordered)
                }
            }

            actionStatus
        }
    }

    private var ingredientReceipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredient Receipt")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(viewModel.ingredientReceipt.rows) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Text(ingredient.quantityText)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var cookbookSpread: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cookbook Spread")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(viewModel.recipe.cookbooks, id: \.id) { cookbook in
                HStack {
                    Label(cookbook.title, systemImage: "book.closed")
                    Spacer()
                    Text(cookbook.canonicalURL.host() ?? "spoonjoy.app")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.brass)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method")
                .font(.title2)
            ForEach(viewModel.methodSections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(section.stepNumber). \(section.title)")
                        .font(.headline)
                        .foregroundStyle(KitchenTableTheme.charcoal)

                    if !section.dependencies.isEmpty {
                        ForEach(section.dependencies, id: \.label) { dependency in
                            Label(dependency.label, systemImage: "arrow.triangle.branch")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                        }
                    }

                    Text(section.body)
                        .font(KitchenTableTheme.bodyNote)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var cookbookSave: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save To Cookbook")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(viewModel.cookbookSave.availableCookbooks) { cookbook in
                let isSaved = isCookbookSaved(cookbook.id)
                HStack {
                    Label(
                        cookbook.title,
                        systemImage: isSaved ? "checkmark.circle.fill" : "circle"
                    )
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(isSaved ? KitchenTableTheme.herb : .secondary)

                    Spacer()

                    if isSaved {
                        Button {
                            runAction(.removeFromCookbook(
                                cookbookID: cookbook.id,
                                clientMutationID: clientMutationID(prefix: "remove-cookbook")
                            ))
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            runAction(.saveToCookbook(
                                cookbookID: cookbook.id,
                                clientMutationID: clientMutationID(prefix: "save-cookbook")
                            ))
                        } label: {
                            Label("Save", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if hasIngredientsInShoppingList {
                Label("Ingredients are on your shopping list", systemImage: "checklist")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
            }
        }
    }

    @ViewBuilder private var ownerTools: some View {
        if viewModel.ownerTools.isVisible {
            VStack(alignment: .leading, spacing: 10) {
                Text("Owner Tools")
                    .font(.title2)
                    .foregroundStyle(KitchenTableTheme.charcoal)

                Button {
                    if let editRoute = viewModel.ownerTools.editRoute {
                        openRoute(editRoute)
                    }
                } label: {
                    Label("Edit Recipe", systemImage: "pencil")
                }
                .font(KitchenTableTheme.bodyNote)

                if let coverControlsRoute = viewModel.ownerTools.coverControlsRoute {
                    Button {
                        openRoute(coverControlsRoute)
                    } label: {
                        Label("Manage Covers", systemImage: "photo.on.rectangle")
                    }
                    .font(KitchenTableTheme.bodyNote)
                }

                if let deleteConfirmation = viewModel.ownerTools.deleteConfirmation {
                    Button(role: .destructive) {
                        activeConfirmationDialog = RecipeActionConfirmationDialog(
                            prompt: deleteConfirmation,
                            clientMutationID: clientMutationID(prefix: "delete-recipe")
                        )
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                    .font(KitchenTableTheme.bodyNote)
                }
            }
        }
    }

    @ViewBuilder private var offlineIndicator: some View {
        if viewModel.offlineIndicator.display != .synced {
            OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
        }
    }

    private func sourceText(_ attribution: RecipeDetailSourceAttribution) -> String {
        if let host = attribution.host {
            return "\(attribution.title) from \(host)"
        }

        return attribution.title
    }

    @ViewBuilder private var actionStatus: some View {
        if let actionStatusMessage {
            Label(actionStatusMessage, systemImage: "checkmark.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
        } else if let actionErrorMessage {
            Label(actionErrorMessage, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(.red)
        }
    }

    private func hasAction(_ id: RecipeDetailActionID) -> Bool {
        viewModel.actions.availableActionIDs.contains(id)
    }

    private func runAction(_ action: RecipeAction) {
        Task {
            do {
                let plan = try actionPlanner(viewModel, currentActionContext).plan(action)
                if let prompt = plan.confirmationPrompt {
                    activeConfirmationDialog = RecipeActionConfirmationDialog(
                        prompt: prompt,
                        clientMutationID: action.clientMutationID
                    )
                    return
                }
                if let blockedReason = plan.blockedReason {
                    actionErrorMessage = blockedReason
                    actionStatusMessage = nil
                    return
                }
                try await performRecipeAction(plan)
                applyLocalSuccess(for: action)
                actionErrorMessage = nil
                actionStatusMessage = successMessage(for: action)
                if shouldNavigateAfterSuccess(for: action), let successRoute = plan.successRoute {
                    openRoute(successRoute)
                }
            } catch {
                actionStatusMessage = nil
                actionErrorMessage = "Could not update recipe."
            }
        }
    }

    private func addRecipeIngredients() {
        let shoppingListMetadata = viewModel.actions.shoppingListMetadata
        let action: ShoppingSurfaceAction = .addRecipeIngredients(
            recipeID: shoppingListMetadata.recipeID,
            scaleFactor: shoppingScaleFactor,
            recipeIngredients: viewModel.recipe.steps.flatMap(\.ingredients),
            clientMutationID: clientMutationID(prefix: "shopping-recipe")
        )
        runShoppingAction(action)
    }

    private func runShoppingAction(_ action: ShoppingSurfaceAction) {
        let createdAt = timestamp()
        Task {
            do {
                let plan = try ShoppingSurfaceViewModel(
                    shoppingList: shoppingViewModel.shoppingList,
                    queuedMutations: shoppingViewModel.queuedMutations,
                    conflicts: shoppingViewModel.conflicts,
                    connectivity: shoppingViewModel.connectivity,
                    now: { createdAt }
                ).plan(action)
                let outcome = try await performShoppingAction(plan)
                localHasIngredientsInShoppingList = true
                actionErrorMessage = nil
                actionStatusMessage = outcome == .queuedForSync
                    ? "Ingredients saved for sync"
                    : "\(viewModel.ingredientReceipt.rows.count) ingredients added at \(shoppingScaleFactor.formatted(.number.precision(.fractionLength(0...2))))x"
            } catch {
                actionStatusMessage = nil
                actionErrorMessage = "Could not update shopping list."
            }
        }
    }

    private func clientMutationID(prefix: String) -> String {
        "native-\(prefix)-\(safeIdentifier(timestamp()))-\(UUID().uuidString.lowercased())"
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func safeIdentifier(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined()
    }

    private var currentSavedCookbookIDs: Set<String> {
        localSavedCookbookIDs ?? viewModel.cookbookSave.savedCookbookIDs
    }

    private var currentActionContext: RecipeDetailContext {
        RecipeDetailContext(
            currentChefID: viewModel.actionContext.currentChefID,
            availableCookbooks: viewModel.actionContext.availableCookbooks,
            savedInCookbookIDs: currentSavedCookbookIDs,
            hasIngredientsInShoppingList: hasIngredientsInShoppingList,
            now: viewModel.actionContext.now
        )
    }

    private var hasIngredientsInShoppingList: Bool {
        localHasIngredientsInShoppingList ?? viewModel.hasIngredientsInShoppingList
    }

    private func isCookbookSaved(_ cookbookID: String) -> Bool {
        currentSavedCookbookIDs.contains(cookbookID)
    }

    private func syncSavedCookbookStateIfNeeded() {
        if localSavedCookbookIDs == nil {
            localSavedCookbookIDs = viewModel.cookbookSave.savedCookbookIDs
        }
    }

    private func syncShoppingStateIfNeeded() {
        if localHasIngredientsInShoppingList == nil {
            localHasIngredientsInShoppingList = viewModel.hasIngredientsInShoppingList
        }
    }

    private func applyLocalSuccess(for action: RecipeAction) {
        var nextIDs = currentSavedCookbookIDs
        switch action {
        case .saveToCookbook(let cookbookID, _):
            nextIDs.insert(cookbookID)
        case .removeFromCookbook(let cookbookID, _):
            nextIDs.remove(cookbookID)
        case .fork, .deleteRecipe:
            break
        }
        localSavedCookbookIDs = nextIDs
    }

    private func successMessage(for action: RecipeAction) -> String {
        switch action {
        case .saveToCookbook:
            "Saved to cookbook"
        case .removeFromCookbook:
            "Removed from cookbook"
        case .fork:
            "Variation started"
        case .deleteRecipe:
            "Recipe deleted"
        }
    }

    private func shouldNavigateAfterSuccess(for action: RecipeAction) -> Bool {
        switch action {
        case .fork, .deleteRecipe:
            true
        case .saveToCookbook, .removeFromCookbook:
            false
        }
    }
}

private extension Recipe {
    func replacingRecentSpoons(_ recentSpoons: [RecipeDetailRecentSpoon]) -> Recipe {
        Recipe(
            id: id,
            title: title,
            description: description,
            servings: servings,
            chef: chef,
            coverImageURL: coverImageURL,
            coverProvenanceLabel: coverProvenanceLabel,
            coverSourceType: coverSourceType,
            coverVariant: coverVariant,
            href: href,
            canonicalURL: canonicalURL,
            attribution: attribution,
            createdAt: createdAt,
            updatedAt: updatedAt,
            steps: steps,
            cookbooks: cookbooks,
            recentSpoons: recentSpoons
        )
    }
}

private struct RecipeActionConfirmationDialog {
    let prompt: RecipeActionConfirmationPrompt
    let clientMutationID: String
}

private extension RecipeAction {
    var clientMutationID: String {
        switch self {
        case .fork(let clientMutationID, _),
             .saveToCookbook(_, let clientMutationID),
             .removeFromCookbook(_, let clientMutationID),
             .deleteRecipe(let clientMutationID, _):
            clientMutationID
        }
    }
}
