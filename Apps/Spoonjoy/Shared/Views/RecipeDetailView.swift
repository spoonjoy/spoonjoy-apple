import SpoonjoyCore
import SwiftUI

private enum RecipeDetailRouteState {
    case loading(snapshotTitle: String?)
    case loaded(RecipeDetailScreenViewModel)
    case missing(message: String)
    case failed(message: String)
}

struct RecipeDetailRouteView: View {
    let recipeID: String
    let repository: any RecipeCatalogRepository
    let spoonRepository: any SpoonCookLogRepository
    let snapshotViewModel: RecipeDetailScreenViewModel?
    let loadingTitle: String?
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

    @State private var routeState: RecipeDetailRouteState
    @State private var errorMessage: String?

    init(
        recipeID: String,
        repository: any RecipeCatalogRepository,
        spoonRepository: any SpoonCookLogRepository,
        initialViewModel: RecipeDetailScreenViewModel?,
        loadingTitle: String? = nil,
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
        self.loadingTitle = loadingTitle
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
        _routeState = State(initialValue: initialViewModel.map(RecipeDetailRouteState.loaded) ?? .loading(snapshotTitle: loadingTitle))
    }

    var body: some View {
        Group {
            switch routeState {
            case .loaded(let viewModel):
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
            case .loading(let snapshotTitle):
                let loadingTitle = snapshotTitle
                KitchenTableLoadingStateView(
                    title: loadingTitle ?? "Loading recipe",
                    subtitle: loadingTitle == nil ? nil : "Loading recipe",
                    systemImage: "text.book.closed"
                )
            case .missing(let errorMessage), .failed(let errorMessage):
                KitchenTableRouteErrorView(message: errorMessage, systemImage: "text.book.closed")
            }
        }
        .task(id: recipeID) {
            await loadRecipe()
        }
        .onChange(of: snapshotViewModel) { _, nextViewModel in
            guard let nextViewModel, nextViewModel != routeState.currentViewModel else {
                return
            }
            routeState = .loaded(nextViewModel)
        }
    }

    @MainActor private func loadRecipe() async {
        errorMessage = nil
        if routeState.currentViewModel == nil {
            routeState = .loading(snapshotTitle: loadingTitle)
        }
        do {
            let result = try await repository.recipeDetail(id: recipeID)
            let detailResult = await detailResultByLoadingFullSpoonList(result)
            routeState = .loaded(RecipeDetailScreenViewModel(result: detailResult, context: context(detailResult.recipe)))
            errorMessage = nil
        } catch RecipeCatalogRepositoryError.recipeNotFound {
            if routeState.currentViewModel == nil {
                errorMessage = "We couldn't find this recipe."
                routeState = .missing(message: errorMessage ?? "We couldn't find this recipe.")
            }
        } catch {
            if routeState.currentViewModel == nil {
                errorMessage = "We couldn't load this recipe."
                routeState = .failed(message: errorMessage ?? "We couldn't load this recipe.")
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

private extension RecipeDetailRouteState {
    var currentViewModel: RecipeDetailScreenViewModel? {
        switch self {
        case .loaded(let viewModel):
            viewModel
        case .loading, .missing, .failed:
            nil
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
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var actionErrorMessage: String?
    @State private var actionStatusMessage: String?
    @State private var activeConfirmationDialog: RecipeActionConfirmationDialog?
    @State private var isCookbookSaveSheetPresented = false
    @State private var isCookLogSheetPresented = false
    @State private var localSavedCookbookIDs: Set<String>?
    @State private var localHasIngredientsInShoppingList: Bool?
    @State private var checkedRecipeIngredientIDs: Set<String> = []
    @State private var checkedRecipeStepDependencyIDs: Set<String> = []
    @State private var shoppingScaleFactor: Double = 1
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        KitchenTablePage {
            offlineIndicator
            recipeMasthead
            stepsSection
            cookLogView
        }
        .sheet(isPresented: $isCookbookSaveSheetPresented) {
            NavigationStack {
                KitchenTablePage {
                    cookbookSave
                }
                .navigationTitle("Save to Cookbook")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isCookbookSaveSheetPresented = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isCookLogSheetPresented) {
            NavigationStack {
                KitchenTablePage {
                    cookLogView
                }
                .navigationTitle("Cooks")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isCookLogSheetPresented = false
                        }
                    }
                }
            }
        }
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
            loadRecipeProgress()
        }
        .onChange(of: viewModel.id) { _, _ in
            localSavedCookbookIDs = viewModel.cookbookSave.savedCookbookIDs
            localHasIngredientsInShoppingList = viewModel.hasIngredientsInShoppingList
            loadRecipeProgress()
        }
        .onChange(of: viewModel.cookbookSave.savedCookbookIDs) { _, nextIDs in
            localSavedCookbookIDs = nextIDs
        }
        .onChange(of: viewModel.hasIngredientsInShoppingList) { _, hasIngredients in
            localHasIngredientsInShoppingList = hasIngredients
        }
        .onChange(of: shoppingScaleFactor) { _, _ in
            persistRecipeProgress()
        }
        .onChange(of: checkedRecipeIngredientIDs) { _, _ in
            persistRecipeProgress()
        }
        .onChange(of: checkedRecipeStepDependencyIDs) { _, _ in
            persistRecipeProgress()
        }
        .task(id: viewModel.id) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "recipe-detail",
                source: "RecipeDetailView",
                runtimeContext: screenshotAccessibilityRuntimeContext
            )
        }
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    private var provenance: String {
        viewModel.cover.provenanceLabel ?? viewModel.recipe.attribution.creditText
    }

    private var recipeMasthead: some View {
        VStack(alignment: .leading, spacing: 16) {
            recipeHeroMedia
            recipeIdentityAndProvenance
            recipeMastheadActions
            recipeHeaderControls
        }
    }

    private var recipeHeroMedia: some View {
        Group {
            if let coverImageURL = viewModel.cover.imageURL, viewModel.cover.hasRealCover {
                RecipeCoverImage(
                    url: coverImageURL,
                    title: viewModel.title,
                    subtitle: "Cover",
                    showsFallbackLabel: false
                )
                    .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 320)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text(provenance)
                            .font(KitchenTableTheme.uiLabel)
                            .padding(10)
                            .background(KitchenTableTheme.photoOverlay, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                    .accessibilityLabel("\(viewModel.title) cover image")
            } else {
                RecipeCoverImage(
                    url: nil,
                    title: viewModel.title,
                    subtitle: viewModel.cover.noPhotoLabel,
                    showsFallbackLabel: true
                )
                    .frame(maxWidth: .infinity, minHeight: 168, maxHeight: 220)
                    .accessibilityLabel(viewModel.cover.accessibilityLabel)
            }
        }
    }

    private var recipeIdentityAndProvenance: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recipe".uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(KitchenTableTheme.brass)

            Text(viewModel.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.description ?? viewModel.recipe.attribution.creditText)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.chefAttribution)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)

            if let servingsLabel = viewModel.servingsLabel {
                Text(servingsLabel)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }

            if let sourceAttribution = viewModel.sourceAttribution {
                Label(sourceText(sourceAttribution), systemImage: "link")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
        }
    }

    private var recipeHeaderControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            RecipeScaleSelector(
                scaleFactor: shoppingScaleFactor,
                displayValue: scaledYieldLabel,
                setScaleFactor: { shoppingScaleFactor = normalizedScaleFactor($0) }
            )

            Button {
                clearRecipeProgress()
            } label: {
                Label("Clear progress", systemImage: "arrow.counterclockwise")
            }
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.inkMuted)
            .buttonStyle(.plain)
            .accessibilityHint("Clears checked step ingredients and resets recipe scale.")
        }
    }

    private var recipeMastheadActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            recipePrimaryActions
            if hasAction(.logCook) {
                recipeMastheadLogCookAction
            }
            if !usesCompactRecipeDock {
                recipeSecondaryActions
            }
            ownerTools
            actionStatus
        }
    }

    private var recipeMastheadLogCookAction: some View {
        Button {
            isCookLogSheetPresented = true
        } label: {
            Label("Log", systemImage: "fork.knife.circle")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
    }

    private var usesCompactRecipeDock: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    @ViewBuilder private var recipePrimaryActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasAction(.startCooking) {
                if usesCompactRecipeDock && hasCompactRecipeMenuActions {
                    HStack(spacing: 10) {
                        startCookingButton
                        compactRecipeActionsMenu
                    }
                } else {
                    startCookingButton
                }
            }

            if hasRecipeUtilityActions && !usesCompactRecipeDock {
                HStack(spacing: 10) {
                    if hasAction(.saveToCookbook) {
                        Button {
                            isCookbookSaveSheetPresented = true
                        } label: {
                            Label("Save", systemImage: "book.closed")
                        }
                        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                    }

                    if hasAction(.addToShoppingList) {
                        Button {
                            addRecipeIngredients()
                        } label: {
                            Label(
                                hasIngredientsInShoppingList ? "In list" : "Add to list",
                                systemImage: hasIngredientsInShoppingList ? "checkmark.circle.fill" : "cart.badge.plus"
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        }
                        .disabled(hasIngredientsInShoppingList)
                        .buttonStyle(KitchenTableActionButtonStyle(prominence: hasIngredientsInShoppingList ? .quiet : .secondary))
                    }
                }
            }
        }
    }

    private var startCookingButton: some View {
        Button {
            openRoute(viewModel.actions.startCookingRoute)
        } label: {
            Label("Cook mode", systemImage: "fork.knife")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
    }

    private var compactRecipeActionsMenu: some View {
        Menu {
            recipeMenuItems(includeSave: true, includeAddToList: true)
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline.weight(.semibold))
                .frame(width: KitchenTableTheme.minimumTouchTarget + 2, height: KitchenTableTheme.minimumTouchTarget + 2)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                        .strokeBorder(KitchenTableTheme.line.opacity(0.75), lineWidth: 1)
                }
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder private var recipeSecondaryActions: some View {
        if hasSecondaryRecipeActions {
            Menu {
                recipeMenuItems(includeSave: false, includeAddToList: true)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        }
    }

    @ViewBuilder private func recipeMenuItems(includeSave: Bool, includeAddToList: Bool) -> some View {
        if includeSave && hasAction(.saveToCookbook) {
            Button {
                isCookbookSaveSheetPresented = true
            } label: {
                Label("Save", systemImage: "book.closed")
            }
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
        }
        if hasAction(.share), let shareURL = viewModel.actions.sharePayload?.publicURL {
            ShareLink(item: shareURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        if includeAddToList && hasAction(.addToShoppingList) {
            Button {
                addRecipeIngredients()
            } label: {
                Label("Add to list", systemImage: "cart.badge.plus")
            }
            .disabled(hasIngredientsInShoppingList)
        }
    }

    private var hasSecondaryRecipeActions: Bool {
        hasAction(.fork) || hasAction(.makeVariation) || hasAction(.share) || hasAction(.addToShoppingList)
    }

    private var hasCompactRecipeMenuActions: Bool {
        hasRecipeUtilityActions || hasAction(.fork) || hasAction(.makeVariation) || hasAction(.share)
    }

    private var hasRecipeUtilityActions: Bool {
        hasAction(.saveToCookbook) || hasAction(.addToShoppingList)
    }

    private var stepsSection: some View {
        KitchenTableSection(title: "Steps", subtitle: "Tap ingredients as you go") {
            if viewModel.stepSections.isEmpty {
                Text("No steps added yet")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ForEach(viewModel.stepSections) { section in
                    recipeStepSection(section)
                }
            }
        }
    }

    private func recipeStepSection(_ section: RecipeDetailStepSection) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(section.stepNumber)")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
                    .textCase(.uppercase)
                    .tracking(1.3)
                    .accessibilityLabel("Step \(section.stepNumber)")

                if let title = section.title, !title.isEmpty {
                    Text(title)
                        .font(KitchenTableTheme.sectionTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !section.dependencies.isEmpty || !section.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ingredients")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .padding(.bottom, 6)

                    ForEach(section.dependencies) { dependency in
                        RecipeStepChecklistRow(
                            title: dependency.label,
                            note: "step output",
                            amount: "",
                            systemImage: "arrow.triangle.branch",
                            isChecked: dependencyIsChecked(dependency.id),
                            toggle: { toggleDependency(id: dependency.id) }
                        )
                    }

                    ForEach(section.ingredients) { ingredient in
                        RecipeStepChecklistRow(
                            title: ingredient.name,
                            note: nil,
                            amount: ingredient.quantityText(scaleFactor: shoppingScaleFactor),
                            systemImage: "cart",
                            isChecked: ingredientIsChecked(ingredient.id),
                            toggle: { toggleIngredient(id: ingredient.id) }
                        )
                    }
                }
                .accessibilityElement(children: .contain)
            }

            Text(section.body)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.line.opacity(0.35))
                .frame(height: 1)
        }
    }

    private var cookbookSave: some View {
        KitchenTableSection(title: "Save to Cookbook") {
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
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(KitchenTableTheme.line.opacity(0.35))
                        .frame(height: 1)
                }
            }

            if hasIngredientsInShoppingList {
                Label("Ingredients are on your shopping list", systemImage: "checklist")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
            }
        }
    }

    private var cookLogView: some View {
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
    }

    @ViewBuilder private var ownerTools: some View {
        if viewModel.ownerTools.isVisible {
            ownerToolsMenu
        }
    }

    private var ownerToolsMenu: some View {
        Menu {
            Button {
                if let editRoute = viewModel.ownerTools.editRoute {
                    openRoute(editRoute)
                }
            } label: {
                Label("Edit recipe", systemImage: "pencil")
            }

            if let coverControlsRoute = viewModel.ownerTools.coverControlsRoute {
                Button {
                    openRoute(coverControlsRoute)
                } label: {
                    Label("Manage covers", systemImage: "photo.on.rectangle")
                }
            }

            if let deleteConfirmation = viewModel.ownerTools.deleteConfirmation {
                Button(role: .destructive) {
                    activeConfirmationDialog = RecipeActionConfirmationDialog(
                        prompt: deleteConfirmation,
                        clientMutationID: clientMutationID(prefix: "delete-recipe")
                    )
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Label("Manage recipe", systemImage: "ellipsis.circle")
        }
        .font(KitchenTableTheme.uiLabel)
        .foregroundStyle(KitchenTableTheme.inkMuted)
        .buttonStyle(.plain)
        .accessibilityLabel("Manage recipe")
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
                .foregroundStyle(KitchenTableTheme.tomato)
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
                    : "\(stepIngredientCount) ingredients added at \(shoppingScaleFactor.formatted(.number.precision(.fractionLength(0...2))))x"
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

    private var scaledYieldLabel: String {
        guard let rawServings = viewModel.recipe.servings?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawServings.isEmpty else {
            return "\(formattedScaleFactor)x"
        }

        guard let baseServings = Double(rawServings) else {
            return shoppingScaleFactor == 1 ? "Serves \(rawServings)" : "\(rawServings) at \(formattedScaleFactor)x"
        }

        return "Serves \(formattedServings(baseServings * shoppingScaleFactor))"
    }

    private var formattedScaleFactor: String {
        shoppingScaleFactor.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func formattedServings(_ servings: Double) -> String {
        servings.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var stepIngredientCount: Int {
        viewModel.stepSections.reduce(0) { total, section in
            total + section.ingredients.count
        }
    }

    private func ingredientIsChecked(_ id: String) -> Bool {
        checkedRecipeIngredientIDs.contains(id)
    }

    private func dependencyIsChecked(_ id: String) -> Bool {
        checkedRecipeStepDependencyIDs.contains(id)
    }

    private func toggleIngredient(id: String) {
        if checkedRecipeIngredientIDs.contains(id) {
            checkedRecipeIngredientIDs.remove(id)
        } else {
            checkedRecipeIngredientIDs.insert(id)
        }
    }

    private func toggleDependency(id: String) {
        if checkedRecipeStepDependencyIDs.contains(id) {
            checkedRecipeStepDependencyIDs.remove(id)
        } else {
            checkedRecipeStepDependencyIDs.insert(id)
        }
    }

    private func clearRecipeProgress() {
        shoppingScaleFactor = 1
        checkedRecipeIngredientIDs = []
        checkedRecipeStepDependencyIDs = []
        persistRecipeProgress(
            scaleFactor: 1,
            checkedIngredientIDs: [],
            checkedStepDependencyIDs: []
        )
    }

    private func loadRecipeProgress() {
        let validIngredientIDs = Set(viewModel.stepSections.flatMap { section in
            section.ingredients.map(\.id)
        })
        let validDependencyIDs = Set(viewModel.stepSections.flatMap { section in
            section.dependencies.map(\.id)
        })
        guard
            let data = UserDefaults.standard.data(forKey: progressStorageKey),
            let snapshot = try? JSONDecoder().decode(RecipeDetailCookProgressSnapshot.self, from: data),
            snapshot.version == RecipeDetailCookProgressSnapshot.currentVersion
        else {
            shoppingScaleFactor = 1
            checkedRecipeIngredientIDs = []
            checkedRecipeStepDependencyIDs = []
            return
        }

        shoppingScaleFactor = normalizedScaleFactor(snapshot.scaleFactor)
        checkedRecipeIngredientIDs = Set(snapshot.checkedIngredientIDs).intersection(validIngredientIDs)
        checkedRecipeStepDependencyIDs = Set(snapshot.checkedStepDependencyIDs).intersection(validDependencyIDs)
    }

    private func persistRecipeProgress() {
        persistRecipeProgress(
            scaleFactor: shoppingScaleFactor,
            checkedIngredientIDs: checkedRecipeIngredientIDs,
            checkedStepDependencyIDs: checkedRecipeStepDependencyIDs
        )
    }

    private func persistRecipeProgress(
        scaleFactor: Double,
        checkedIngredientIDs: Set<String>,
        checkedStepDependencyIDs: Set<String>
    ) {
        let snapshot = RecipeDetailCookProgressSnapshot(
            scaleFactor: normalizedScaleFactor(scaleFactor),
            checkedIngredientIDs: Array(checkedIngredientIDs).sorted(),
            checkedStepDependencyIDs: Array(checkedStepDependencyIDs).sorted(),
            updatedAt: timestamp()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        UserDefaults.standard.set(data, forKey: progressStorageKey)
    }

    private var progressStorageKey: String {
        "spoonjoy-cook-progress:\(viewModel.id)"
    }

    private func normalizedScaleFactor(_ value: Double) -> Double {
        guard value.isFinite else {
            return 1
        }
        return min(50, max(0.25, (value * 100).rounded() / 100))
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

private struct RecipeDetailCookProgressSnapshot: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    let scaleFactor: Double
    let checkedIngredientIDs: [String]
    let checkedStepDependencyIDs: [String]
    let updatedAt: String

    init(
        scaleFactor: Double,
        checkedIngredientIDs: [String],
        checkedStepDependencyIDs: [String],
        updatedAt: String
    ) {
        version = Self.currentVersion
        self.scaleFactor = scaleFactor
        self.checkedIngredientIDs = checkedIngredientIDs
        self.checkedStepDependencyIDs = checkedStepDependencyIDs
        self.updatedAt = updatedAt
    }
}

private struct RecipeScaleSelector: View {
    let scaleFactor: Double
    let displayValue: String
    let setScaleFactor: (Double) -> Void

    private let step = 0.25
    private let minimum = 0.25
    private let maximum = 50.0

    var body: some View {
        HStack(spacing: 0) {
            scaleButton(systemImage: "minus", label: "Decrease scale", isDisabled: scaleFactor <= minimum) {
                setScaleFactor(max(minimum, rounded(scaleFactor - step)))
            }

            VStack(spacing: 2) {
                Text("Yield")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text(displayValue)
                    .font(KitchenTableTheme.sectionTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 12)

            scaleButton(systemImage: "plus", label: "Increase scale", isDisabled: scaleFactor >= maximum) {
                setScaleFactor(min(maximum, rounded(scaleFactor + step)))
            }
        }
        .background(KitchenTableTheme.paper)
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .stroke(KitchenTableTheme.line.opacity(0.72), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Yield")
        .accessibilityValue(displayValue)
    }

    private func scaleButton(
        systemImage: String,
        label: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .frame(width: 52, height: 64)
                .contentShape(Rectangle())
        }
        .disabled(isDisabled)
        .foregroundStyle(isDisabled ? KitchenTableTheme.inkMuted.opacity(0.42) : KitchenTableTheme.charcoal)
        .accessibilityLabel(label)
    }

    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

private struct RecipeStepChecklistRow: View {
    let title: String
    let note: String?
    let amount: String
    let systemImage: String
    let isChecked: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isChecked ? KitchenTableTheme.herb : KitchenTableTheme.brass)
                    .frame(width: 32, alignment: .center)
                    .accessibilityHidden(true)

                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .strikethrough(isChecked, color: KitchenTableTheme.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let note, !note.isEmpty {
                        Text(note)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                            .textCase(.uppercase)
                    }
                }

                Spacer(minLength: 12)

                if !amount.isEmpty {
                    Text(amount)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 72, alignment: .trailing)
                }
            }
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isChecked ? "used" : "not used")
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.line.opacity(0.34))
                .frame(height: 1)
        }
    }

    private var accessibilityLabel: String {
        [title, amount, note].compactMap { value in
            guard let value, !value.isEmpty else {
                return nil
            }
            return value
        }.joined(separator: ", ")
    }
}

struct MobileActionFlow: View {
    private let primaryActions: AnyView
    private let secondaryActions: AnyView

    init<PrimaryActions: View, SecondaryActions: View>(
        @ViewBuilder primaryActions: () -> PrimaryActions,
        @ViewBuilder secondaryActions: () -> SecondaryActions
    ) {
        self.primaryActions = AnyView(primaryActions())
        self.secondaryActions = AnyView(secondaryActions())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            primaryActions
            secondaryActions
        }
    }
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
