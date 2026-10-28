import Foundation
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
    @Environment(\.moderation) private var moderation

    private var moderatedTarget: ContentReportTarget {
        ContentReportTarget(type: .recipe, id: recipeID)
    }

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
                // The server answers 404 for a recipe the person reported or whose chef they blocked.
                if let chef = moderation.ledger.blockedChef(hiding: moderatedTarget) {
                    ModerationHiddenView(message: "You blocked \(chef.name), so their recipes are hidden.", unblockChef: chef)
                } else if moderation.ledger.isHidden(moderatedTarget) {
                    ModerationHiddenView(message: "You reported this recipe, so it's hidden for you.", unblockChef: nil)
                } else {
                    KitchenTableRouteErrorView(message: errorMessage, systemImage: "text.book.closed")
                }
            }
        }
        .reloadsOnPull { await loadRecipe() }
        .task(id: recipeID) {
            await loadRecipe()
        }
        .onChange(of: moderation.ledger.blockedChefs) {
            Task { await loadRecipe() }
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
        let hasVisibleCurrentRecipe = routeState.currentViewModel?.id == recipeID
        if !hasVisibleCurrentRecipe {
            routeState = .loading(snapshotTitle: loadingTitle)
        }
        do {
            let result = try await repository.recipeDetail(id: recipeID)
            let detailResult = await detailResultByLoadingFullSpoonList(result)
            routeState = .loaded(RecipeDetailScreenViewModel(result: detailResult, context: context(detailResult.recipe)))
            errorMessage = nil
        } catch RecipeCatalogRepositoryError.recipeNotFound {
            if !hasVisibleCurrentRecipe {
                errorMessage = "We couldn't find this recipe."
                routeState = .missing(message: errorMessage ?? "We couldn't find this recipe.")
            }
        } catch {
            if !hasVisibleCurrentRecipe {
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
    private static let screenshotCookLogFocusEnvironmentKey = "SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS"
    private static let provenanceIconName = "link"

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
    @State private var didPresentCookLogForScreenshot = false
    @State private var localSavedCookbookIDs: Set<String>?
    @State private var localHasIngredientsInShoppingList: Bool?
    @State private var checkedRecipeIngredientIDs: Set<String> = []
    @State private var checkedRecipeStepDependencyIDs: Set<String> = []
    @State private var shoppingScaleFactor: Double = 1
    @State private var remindersSender = SpoonjoyRemindersSender()
    @State private var spreadSelection = RecipeSpreadSelection()
    /// The anchor each page of the spread is scrolled to. Setting one scrolls that page; the two pages scroll on
    /// their own otherwise.
    @State private var spreadIngredientScrollPosition = ScrollPosition(idType: String.self)
    /// Where each ingredient group starts on the left page, measured in the page's content coordinates.
    @State private var spreadIngredientGroupOffsets: [String: CGFloat] = [:]
    @State private var spreadMethodScrollAnchor: String?
    /// How far the page is pulled down past its top; the photo stretches by this much.
    @State private var heroPull: CGFloat = 0
    /// How far the page has scrolled; paper covers the status bar once the photo has gone under it.
    @State private var heroScrollOffset: CGFloat = 0
    @State private var isServesPopoverPresented = false
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.moderation) private var moderation
    @ScaledMetric(relativeTo: .title3) private var scaledUtilityButtonSize = RecipeHeroMetrics.utilityButtonSize
    @Environment(\.dismiss) private var dismiss
    @State private var moderationPrompt: ModerationPrompt?

    var body: some View {
        Group {
            if isHiddenByModeration {
                ModerationHiddenView(
                    message: moderation.ledger.isBlocked(chefID: viewModel.recipe.chef.id)
                        ? "You blocked @\(viewModel.recipe.chef.username), so their recipes are hidden."
                        : "You reported this recipe, so it's hidden for you.",
                    unblockChef: moderation.ledger.blockedChefs.first { $0.id == viewModel.recipe.chef.id }
                )
            } else {
                recipeLayout
                    .toolbar { recipeToolbar }
            }
        }
        .moderationPrompts($moderationPrompt) { dismiss() }
        .spoonjoyRemindersSend(remindersSender)
        .onChange(of: remindersSender.statusMessage) { _, message in
            if let message {
                actionErrorMessage = nil
                actionStatusMessage = message
            }
        }
        .onChange(of: remindersSender.errorMessage) { _, message in
            if let message {
                actionStatusMessage = nil
                actionErrorMessage = message
            }
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
#if os(iOS)
            cookLogSheet
#else
            cookLogSheet
                .frame(minWidth: 560, idealWidth: 620, maxWidth: 700, minHeight: 400, idealHeight: 440, maxHeight: 480)
#endif
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
            presentCookLogForScreenshotIfNeeded()
        }
        .onChange(of: viewModel.id) { _, _ in
            didPresentCookLogForScreenshot = false
            localSavedCookbookIDs = viewModel.cookbookSave.savedCookbookIDs
            localHasIngredientsInShoppingList = viewModel.hasIngredientsInShoppingList
            loadRecipeProgress()
            presentCookLogForScreenshotIfNeeded()
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

    /// Compact width keeps the single scrolling page. Regular width opens into a two-page spread when the
    /// screen is wide and landscape, such as the inner screen of the iPhone Duo, and reads as one page otherwise.
    @ViewBuilder private var recipeLayout: some View {
        if usesCompactRecipeDock {
            singlePageLayout
        } else {
            SpreadLayoutReader(isRegularWidth: true) { layout in
                if layout.isSpread {
                    recipeSpread(layout)
                } else {
                    singlePageLayout
                }
            }
        }
    }

    /// With a real cover the photo runs edge to edge under the status bar and the recipe sits on a sheet of paper
    /// over its foot; without one the page opens on the title.
    @ViewBuilder private var singlePageLayout: some View {
        if let coverImageURL = viewModel.cover.imageURL, viewModel.cover.hasRealCover {
            heroPage(coverImageURL: coverImageURL)
        } else {
            KitchenTablePage {
                offlineIndicator
                recipeMasthead
                stepsSection
                cookLogView(showsHeader: true)
            }
        }
    }

    private func heroPage(coverImageURL: URL) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                recipeHeroMedia(coverImageURL: coverImageURL)
                VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
                    offlineIndicator
                    recipeMasthead
                    stepsSection
                    cookLogView(showsHeader: true)
                }
                .padding(.horizontal, KitchenTableTheme.pagePadding)
                .padding(.top, 26)
                .padding(.bottom, KitchenTableTheme.compactDockReserve)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(
                    KitchenTableTheme.page,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: RecipeHeroMetrics.sheetRadius,
                        topTrailingRadius: RecipeHeroMetrics.sheetRadius,
                        style: .continuous
                    )
                )
                .padding(.top, -RecipeHeroMetrics.sheetOverlap)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            heroScrollOffset = offset
            heroPull = CGFloat(KitchenHeroStretch.pull(contentOffsetY: Double(offset), topInset: 0))
        }
        .background(KitchenTableTheme.page.ignoresSafeArea())
#if os(iOS)
        .ignoresSafeArea(edges: .top)
        // As on the Kitchen: nothing over the photo at rest, a hard edge behind the bar buttons once it scrolls.
        .scrollEdgeEffectHidden(!KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: Double(heroScrollOffset)), for: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
        // The dish is the title; Back, Share and More float over it as glass.
        .toolbar(removing: .title)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .overlay(alignment: .top) {
            // Once the photo has scrolled away, paper covers the status bar so text never runs under the clock.
            Color.clear
                .frame(height: 0)
                .background(KitchenTableTheme.page.ignoresSafeArea(edges: .top))
                .opacity(heroScrollOffset > RecipeHeroMetrics.height(isRegular: !usesCompactRecipeDock) - RecipeHeroMetrics.sheetOverlap ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
#else
        .scrollEdgeEffectStyle(.hard, for: .top)
#endif
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    @MainActor private func presentCookLogForScreenshotIfNeeded() {
#if DEBUG
        guard !didPresentCookLogForScreenshot else {
            return
        }
        let focus = ProcessInfo.processInfo.environment[Self.screenshotCookLogFocusEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard focus == "cook-log" else {
            return
        }
        didPresentCookLogForScreenshot = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else {
                return
            }
            isCookLogSheetPresented = true
        }
#endif
    }

    /// Title, story, the one meta row, then the actions: Cook filled, Save and Add to list as glass.
    private var recipeMasthead: some View {
        VStack(alignment: .leading, spacing: 18) {
            recipeIdentityAndProvenance
            if !viewModel.cover.hasRealCover {
                recipeNoPhotoStatus
            }
            recipeMastheadActions
        }
    }

    /// The photo, stretched from its top edge while the page is pulled down, as the Kitchen's hero is.
    private func recipeHeroMedia(coverImageURL: URL) -> some View {
        GeometryReader { proxy in
            let scale = KitchenHeroStretch.scale(
                pull: Double(heroPull),
                heroHeight: Double(proxy.size.height),
                reduceMotion: accessibilityReduceMotion
            )
            RecipeCoverImage(
                url: coverImageURL,
                title: viewModel.title,
                subtitle: "Cover",
                showsFallbackLabel: false
            )
            .scaledToFill()
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .overlay {
                // Darkens the top so the status bar and the glass buttons read over any photo.
                LinearGradient(
                    stops: [
                        .init(color: KitchenTableTheme.photoCharcoal.opacity(0.34), location: 0),
                        .init(color: KitchenTableTheme.photoCharcoal.opacity(0), location: 0.26)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .scaleEffect(scale, anchor: .top)
            // Pulled down, the page moves; the photo stays pinned to the top of the screen and grows instead.
            .offset(y: accessibilityReduceMotion ? 0 : -heroPull)
            .background(alignment: .top) {
                // Under Reduce Motion the photo moves down with the page; its dark ground fills the space above it.
                let fill = CGFloat(KitchenHeroStretch.stillPhotoFill(pull: Double(heroPull), reduceMotion: accessibilityReduceMotion))
                KitchenTableTheme.photoCharcoal
                    .frame(height: fill + 1)
                    .offset(y: -fill)
            }
        }
        .frame(height: RecipeHeroMetrics.height(isRegular: !usesCompactRecipeDock))
        // One labelled image element, so VoiceOver and the journeys can find the cover.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("\(viewModel.title) cover image")
        .accessibilityIdentifier("recipeDetail.cover")
    }

    private var recipeNoPhotoStatus: some View {
        Label(viewModel.cover.noPhotoLabel, systemImage: "photo.badge.plus")
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.ink2)
            .accessibilityLabel(viewModel.cover.accessibilityLabel)
    }

    private var recipeIdentityAndProvenance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recipeDetail.title")
            if let story = viewModel.recipe.displaySubtitle {
                Text(story)
                    .font(KitchenTableTheme.story)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            recipeMetaRow
            recipeProvenance
        }
    }

    /// "23 min · Serves 4 · by maya": every fact once. "Serves 4" is the recipe's one scale control; it opens a
    /// stepper in place. The time is the timed steps added up and is left out when no step is timed.
    private var recipeMetaRow: some View {
        // One layout, so "Serves" has one popover owner: a line, or a stack at accessibility sizes.
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            recipeMetaFacts(separated: !stacked)
        }
        .font(KitchenTableTheme.meta)
        .foregroundStyle(KitchenTableTheme.ink2)
    }

    @ViewBuilder private func recipeMetaFacts(separated: Bool) -> some View {
        if let cookTime {
            Text(cookTime)
                .monospacedDigit()
                .accessibilityLabel("Takes \(cookTime)")
            if separated {
                metaDot
            }
        }
        recipeServesControl
        if separated {
            metaDot
        }
        Text("by \(viewModel.recipe.chef.username)")
            .lineLimit(1)
    }

    private var metaDot: some View {
        Text("·")
            .accessibilityHidden(true)
    }

    private var cookTime: String? {
        RecipeCookTime.label(stepDurations: viewModel.stepSections.map(\.durationMinutes))
    }

    private var serves: RecipeServes {
        RecipeServes(servings: viewModel.recipe.servings)
    }

    private var recipeServesControl: some View {
        Button {
            isServesPopoverPresented = true
        } label: {
            HStack(spacing: 4) {
                Text(serves.label(scale: shoppingScaleFactor))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: shoppingScaleFactor))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(KitchenTableTheme.meta.weight(.semibold))
            .foregroundStyle(KitchenTableTheme.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(KitchenTableTheme.vellum, in: Capsule())
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(serves.label(scale: shoppingScaleFactor))
        .accessibilityHint("Changes how many the recipe serves; every amount scales with it.")
        .accessibilityIdentifier("recipe.serves")
        .popover(isPresented: $isServesPopoverPresented, arrowEdge: .top) {
            RecipeServesPopover(
                serves: serves,
                scaleFactor: Binding(
                    get: { shoppingScaleFactor },
                    set: { shoppingScaleFactor = RecipeServes.normalizedScale($0) }
                )
            )
        }
        .kitchenAnimation(.snappy, value: shoppingScaleFactor)
    }

    @ViewBuilder private var recipeProvenance: some View {
        if let sourceAttribution = viewModel.sourceAttribution {
            Label(sourceAttribution.creditLine, systemImage: Self.provenanceIconName)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink2)
        }
    }

    private var clearProgressButton: some View {
        Button {
            withAnimation(KitchenTableTheme.Checklist.reorder(reduceMotion: accessibilityReduceMotion)) {
                clearRecipeProgress()
            }
        } label: {
            Label("Clear progress", systemImage: "arrow.counterclockwise")
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .font(KitchenTableTheme.uiLabel)
        .foregroundStyle(KitchenTableTheme.ink2)
        .buttonStyle(.plain)
        .accessibilityHint("Clears checked step ingredients and resets recipe scale.")
        .accessibilityIdentifier("recipeDetail.clearProgress")
    }

    /// The Steps heading's Clear progress. Its room is always kept, so the button fades in with the first check
    /// and nothing on the page moves; while there is nothing to clear it is hidden from VoiceOver and taps.
    private var stepsClearProgress: some View {
        clearProgressButton
            .opacity(hasRecipeProgress ? 1 : 0)
            .disabled(!hasRecipeProgress)
            .accessibilityHidden(!hasRecipeProgress)
            .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.2), value: hasRecipeProgress)
    }

    /// Cook is the page's one filled button. Save and Add to list are glass circles beside it; everything else is
    /// under More in the bar.
    /// At the accessibility text sizes Cook takes the full width and the circles move to the row under it.
    private var recipeMastheadActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: 10) {
            layout {
                if hasAction(.startCooking) {
                    startCookingButton
                }
                HStack(spacing: 10) {
                    recipeUtilityButtons
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            actionStatus
        }
    }

    /// Grows with the text size, capped so two circles still sit beside each other at AX5.
    private var utilityButtonSize: CGFloat {
        min(scaledUtilityButtonSize, RecipeHeroMetrics.maximumUtilityButtonSize)
    }

    private var utilityButtonFont: Font {
        .system(size: utilityButtonSize * 0.4, weight: .semibold)
    }

    @ViewBuilder private var recipeUtilityButtons: some View {
        if hasAction(.saveToCookbook) {
            Button {
                isCookbookSaveSheetPresented = true
            } label: {
                Label("Save", systemImage: "bookmark")
                    .labelStyle(.iconOnly)
                    .font(utilityButtonFont)
                    .frame(width: utilityButtonSize, height: utilityButtonSize)
            }
            .recipeGlassCircle()
            .accessibilityLabel("Save")
            .accessibilityHint("Saves this recipe to a cookbook.")
        }
        if hasAction(.addToShoppingList) {
            Button {
                addRecipeIngredients()
            } label: {
                Label(
                    hasIngredientsInShoppingList ? "In list" : "Add to list",
                    systemImage: hasIngredientsInShoppingList ? "checkmark" : "cart.badge.plus"
                )
                .labelStyle(.iconOnly)
                .font(utilityButtonFont)
                .frame(width: utilityButtonSize, height: utilityButtonSize)
            }
            .disabled(hasIngredientsInShoppingList)
            .recipeGlassCircle()
            .accessibilityLabel(hasIngredientsInShoppingList ? "In list" : "Add to list")
        }
    }

    private var recipeMastheadLogCookAction: some View {
        Button {
            isCookLogSheetPresented = true
        } label: {
            Label("Log", systemImage: "fork.knife.circle")
        }
    }

    private var cookLogSheet: some View {
        NavigationStack {
            KitchenTablePage(maxContentWidth: 620, bottomReserve: 28) {
                cookLogView(showsHeader: false)
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

    private var usesCompactRecipeDock: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    private var startCookingButton: some View {
        Button {
            openRoute(viewModel.actions.startCookingRoute)
        } label: {
            Label("Cook", systemImage: "play.fill")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
        .accessibilityHint("Opens cook mode at this recipe's servings.")
        .accessibilityIdentifier("recipeDetail.cook")
    }

    /// Back, Share and More, as glass in the bar over the photo.
    @ToolbarContentBuilder private var recipeToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if hasAction(.share), let shareURL = viewModel.actions.sharePayload?.publicURL {
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("recipeDetail.share")
            }
            if hasMoreRecipeActions || showsSearchAllInMore {
                Menu {
                    recipeMoreMenuItems
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("recipeDetail.actions")
            }
        }
    }

    /// Everything that is not Cook, Save, Add to list or Share: logging a cook, variations, Reminders, owner tools
    /// and moderation.
    @ViewBuilder private var recipeMoreMenuItems: some View {
        if hasAction(.logCook) {
            recipeMastheadLogCookAction
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
        remindersMenuItems
        ownerToolsMenuItems
        if showsSearchAllInMore {
            Button {
                openRoute(.search(query: "", scope: .all))
            } label: {
                Label("Search All", systemImage: "magnifyingglass")
            }
        }
        if canModerate {
            ModerationMenuItems(
                reportTarget: ContentReportTarget(type: .recipe, id: viewModel.recipe.id),
                reportSubject: "this recipe",
                chef: BlockedChef(id: viewModel.recipe.chef.id, username: viewModel.recipe.chef.username),
                prompt: $moderationPrompt
            )
        }
    }

    /// Report and block appear on other chefs' recipes once someone is signed in (App Review guideline 1.2).
    private var canModerate: Bool {
        guard let accountID = moderation.accountID else { return false }
        return !viewModel.ownerTools.isVisible && viewModel.recipe.chef.id != accountID
    }

    private var isHiddenByModeration: Bool {
        moderation.ledger.hidesRecipe(id: viewModel.recipe.id, chefID: viewModel.recipe.chef.id)
    }

    @ViewBuilder private var remindersMenuItems: some View {
        if hasIngredientsToSendToReminders {
            Button {
                sendIngredientsToReminders()
            } label: {
                Label("Send to Reminders", systemImage: "checklist")
            }
            .accessibilityIdentifier("recipeDetail.remindersSend")
            Button {
                remindersSender.chooseList()
            } label: {
                Label(remindersListMenuTitle, systemImage: "list.bullet")
            }
        }
    }

    private var hasIngredientsToSendToReminders: Bool {
        viewModel.recipe.steps.contains { !$0.ingredients.isEmpty }
    }

    private var remindersListMenuTitle: String {
        remindersSender.currentListTitle.map { "Reminders list: \($0)" } ?? "Choose Reminders list"
    }

    private func sendIngredientsToReminders() {
        remindersSender.send(
            ingredients: ReminderIncomingIngredient.fromRecipe(
                viewModel.recipe.steps.flatMap(\.ingredients),
                scaleFactor: shoppingScaleFactor
            ),
            source: ReminderSource(id: viewModel.recipe.id, label: viewModel.recipe.title)
        )
    }

    /// The shell's Actions menu steps aside on the recipe page, so its Search All moves here. Phones have the
    /// Search tab instead.
    private var showsSearchAllInMore: Bool {
#if os(iOS)
        horizontalSizeClass == .regular
#else
        true
#endif
    }

    private var hasMoreRecipeActions: Bool {
        hasAction(.logCook) || hasAction(.fork) || hasAction(.makeVariation) || hasIngredientsToSendToReminders
            || viewModel.ownerTools.isVisible || canModerate
    }

    private var stepsSection: some View {
        KitchenTableSection(title: "Steps", subtitle: "Tap ingredients as you go") {
            if viewModel.stepSections.isEmpty {
                Text("No steps added yet")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ForEach(viewModel.stepSections) { section in
                    recipeStepSection(section, isLast: section.id == viewModel.stepSections.last?.id)
                }
            }
        } accessory: {
            stepsClearProgress
        }
        // Scaling rolls every amount to its new value.
        .kitchenAnimation(.snappy, value: shoppingScaleFactor)
    }
    /// The step's ingredients as the web shows them: unchecked first, checked ones sunk to the bottom, each
    /// group in the step's own order.
    private func orderedIngredients(_ ingredients: [RecipeDetailIngredientRow]) -> [RecipeDetailIngredientRow] {
        CheckedIngredientOrder.ordered(ingredients, checkedIDs: checkedRecipeIngredientIDs)
    }

    private func recipeStepSection(_ section: RecipeDetailStepSection, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: KitchenTableTheme.stepBlockSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    stepEyebrow(section)
                    if let title = section.title, !title.isEmpty {
                        Text(title)
                            .font(KitchenTableTheme.stepTitle)
                            .foregroundStyle(KitchenTableTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let durationLabel = section.durationLabel {
                    RecipeStepDurationCue(durationLabel: durationLabel)
                }
            }

            if !section.dependencies.isEmpty || !section.ingredients.isEmpty {
                let ingredients = orderedIngredients(section.ingredients)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ingredients")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .padding(.bottom, KitchenTableTheme.Checklist.headingGap)

                    // Step outputs stay above the ingredients in their own order, as on the web.
                    ForEach(section.dependencies) { dependency in
                        RecipeStepChecklistRow(
                            title: dependency.label,
                            note: "step output",
                            amount: "",
                            systemImage: "arrow.triangle.branch",
                            isChecked: dependencyIsChecked(dependency.id),
                            showsSeparator: !(ingredients.isEmpty && dependency.id == section.dependencies.last?.id),
                            accessibilityID: "recipeDetail.stepOutput",
                            toggle: { toggleDependency(id: dependency.id) }
                        )
                    }

                    ForEach(ingredients) { ingredient in
                        RecipeStepChecklistRow(
                            title: ingredient.name,
                            note: ingredient.aisleLabel,
                            amount: ingredient.quantityText(scaleFactor: shoppingScaleFactor),
                            systemImage: "cart",
                            isChecked: ingredientIsChecked(ingredient.id),
                            showsSeparator: ingredient.id != ingredients.last?.id,
                            accessibilityID: "recipeDetail.ingredient",
                            toggle: { toggleIngredient(id: ingredient.id) }
                        )
                    }
                }
                .accessibilityElement(children: .contain)
            }

            Text(section.body)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, KitchenTableTheme.stepSpacing)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(KitchenTableTheme.hairline.opacity(0.35))
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recipeDetail.step.\(section.stepNumber)")
    }

    private func stepEyebrow(_ section: RecipeDetailStepSection) -> some View {
        Text("Step \(section.stepNumber)")
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.brass)
            .textCase(.uppercase)
            .tracking(1.3)
            .accessibilityLabel("Step \(section.stepNumber)")
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
                        .fill(KitchenTableTheme.hairline.opacity(0.35))
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

    private func cookLogView(showsHeader: Bool) -> some View {
        SpoonCookLogView(
            viewModel: spoonCookLogViewModel(viewModel, viewModel.spoonSummary),
            showsHeader: showsHeader,
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

    @ViewBuilder private var ownerToolsMenuItems: some View {
        if let editRoute = viewModel.ownerTools.editRoute {
            Button {
                openRoute(editRoute)
            } label: {
                Label("Edit recipe", systemImage: "pencil")
            }
            .accessibilityIdentifier("recipeDetail.edit")
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
    }

    @ViewBuilder private var offlineIndicator: some View {
        if viewModel.offlineIndicator.display != .synced {
            OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
        }
    }

    @ViewBuilder private var actionStatus: some View {
        if let actionStatusMessage {
            Label(actionStatusMessage, systemImage: "checkmark.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
                .accessibilityIdentifier("recipeDetail.status")
        } else if let actionErrorMessage {
            Label(actionErrorMessage, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.tomato)
                .accessibilityIdentifier("recipeDetail.status")
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

    /// A checked ingredient moves to the bottom of its step with the web's spring, or at once with Reduce Motion.
    private func toggleIngredient(id: String) {
        withAnimation(KitchenTableTheme.Checklist.reorder(reduceMotion: accessibilityReduceMotion)) {
            if checkedRecipeIngredientIDs.contains(id) {
                checkedRecipeIngredientIDs.remove(id)
            } else {
                checkedRecipeIngredientIDs.insert(id)
            }
        }
    }

    private func toggleDependency(id: String) {
        if checkedRecipeStepDependencyIDs.contains(id) {
            checkedRecipeStepDependencyIDs.remove(id)
        } else {
            checkedRecipeStepDependencyIDs.insert(id)
        }
    }

    private var hasRecipeProgress: Bool {
        shoppingScaleFactor != 1 || !checkedRecipeIngredientIDs.isEmpty || !checkedRecipeStepDependencyIDs.isEmpty
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
        RecipePageProgress.storageKey(recipeID: viewModel.id)
    }

    private func normalizedScaleFactor(_ value: Double) -> Double {
        RecipeServes.normalizedScale(value)
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

// MARK: - Cookbook spread

extension RecipeDetailView {
    /// The recipe laid open like a cookbook. The left page holds the title, cover, yield and every ingredient
    /// grouped under the step that uses it; the right page holds the method. The pages scroll on their own.
    /// Tapping a step highlights its ingredients on the left page and brings them into view; tapping an
    /// ingredient group's heading selects its step on the right.
    fileprivate func recipeSpread(_ layout: BookSpreadLayout) -> some View {
        let index = RecipeSpreadIngredientIndex(stepSections: viewModel.stepSections)
        return KitchenTableSpread(layout: layout) {
            ScrollView {
                spreadIngredientPage(index: index)
                    .spreadPagePadding(.leading)
            }
            .scrollPosition($spreadIngredientScrollPosition)
            .accessibilityIdentifier("recipeSpread.ingredientsPage")
        } trailing: {
            ScrollView {
                spreadMethodPage(index: index)
                    .spreadPagePadding(.trailing)
            }
            .scrollPosition(id: $spreadMethodScrollAnchor, anchor: .top)
            .accessibilityIdentifier("recipeSpread.methodPage")
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onChange(of: viewModel.id) { _, _ in
            spreadSelection.clear()
        }
    }

    private func spreadIngredientPage(index: RecipeSpreadIngredientIndex) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            offlineIndicator
            if let coverImageURL = viewModel.cover.imageURL, viewModel.cover.hasRealCover {
                RecipeCoverImage(
                    url: coverImageURL,
                    title: viewModel.title,
                    subtitle: "Cover",
                    showsFallbackLabel: false
                )
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel("\(viewModel.title) cover image")
                .accessibilityIdentifier("recipeDetail.cover")
            }
            recipeMasthead
            spreadIngredientList(index: index)
        }
        .scrollTargetLayout()
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(name: Self.spreadIngredientContentSpace)
    }

    @ViewBuilder private func spreadIngredientList(index: RecipeSpreadIngredientIndex) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Ingredients")
                    .font(KitchenTableTheme.sectionTitle)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                stepsClearProgress
            }
            Text(index.isEmpty ? "No ingredients added yet" : "Grouped by the step that uses them")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink2)
        }
        .padding(.top, 6)

        // The groups sit directly in the page's scroll target layout so the page can scroll to any of them.
        ForEach(index.groups) { group in
            spreadIngredientGroup(group, isHighlighted: spreadSelection.isHighlighted(groupID: group.id, in: index))
                .id(Self.spreadIngredientAnchor(group.id))
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .named(Self.spreadIngredientContentSpace)).minY
                } action: { minY in
                    spreadIngredientGroupOffsets[Self.spreadIngredientAnchor(group.id)] = minY
                }
        }
    }

    private func spreadIngredientGroup(_ group: RecipeSpreadIngredientGroup, isHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                selectSpreadStep(group.id, scrollIngredients: false)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.stepLabel)
                        .spreadRunningHead()
                    if let title = group.title {
                        Text(title)
                            .font(KitchenTableTheme.instructionBody.italic())
                            .foregroundStyle(KitchenTableTheme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(group.accessibilityHeading)
            .accessibilityHint("Shows this step in the method.")
            .accessibilityAddTraits(.isHeader)

            ForEach(group.dependencies) { dependency in
                RecipeSpreadIngredientRow(
                    name: dependency.label,
                    amount: "",
                    note: "from an earlier step",
                    isChecked: dependencyIsChecked(dependency.id),
                    toggle: { toggleDependency(id: dependency.id) }
                )
            }
            ForEach(orderedIngredients(group.ingredients)) { ingredient in
                RecipeSpreadIngredientRow(
                    name: ingredient.name,
                    amount: ingredient.quantityText(scaleFactor: shoppingScaleFactor),
                    note: ingredient.aisleLabel,
                    isChecked: ingredientIsChecked(ingredient.id),
                    toggle: { toggleIngredient(id: ingredient.id) }
                )
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(isHighlighted ? KitchenTableTheme.selectionWash : Color.clear)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isHighlighted ? KitchenTableTheme.brass : KitchenTableTheme.hairline)
                .frame(width: isHighlighted ? 3 : 1)
        }
        .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.2), value: isHighlighted)
        .accessibilityElement(children: .contain)
        .accessibilityValue(isHighlighted ? "Ingredients for the selected step" : "")
    }

    private func spreadMethodPage(index: RecipeSpreadIngredientIndex) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.title)
                    .spreadRunningHead()
                    .lineLimit(1)
                Text("Method")
                    .font(KitchenTableTheme.displayTitle)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(spreadMethodSummary)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
            .padding(.bottom, 12)

            if viewModel.stepSections.isEmpty {
                Text("No steps added yet")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .padding(.vertical, 18)
            } else {
                ForEach(viewModel.stepSections) { section in
                    spreadMethodStep(section, index: index)
                        .id(Self.spreadMethodAnchor(section.id))
                }
            }

            cookLogView(showsHeader: true)
                .padding(.top, 28)
        }
        .scrollTargetLayout()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spreadMethodSummary: String {
        let count = viewModel.stepSections.count
        let steps = count == 1 ? "1 step" : "\(count) steps"
        let minutes = viewModel.stepSections.compactMap(\.durationMinutes).reduce(0, +)
        return minutes > 0 ? "\(steps) · about \(minutes) min" : steps
    }

    private func spreadMethodStep(_ section: RecipeDetailStepSection, index: RecipeSpreadIngredientIndex) -> some View {
        let isSelected = spreadSelection.isSelected(stepID: section.id)
        let gathers = index.group(forStepID: section.id) != nil
        return Button {
            selectSpreadStep(section.id, scrollIngredients: true)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("\(section.stepNumber)")
                    .font(KitchenTableTheme.stepNumeral)
                    .foregroundStyle(isSelected ? KitchenTableTheme.brass : KitchenTableTheme.brass.opacity(0.62))
                    .frame(minWidth: 30, alignment: .trailing)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    if let title = section.title, !title.isEmpty {
                        Text(title)
                            .font(KitchenTableTheme.objectTitle)
                            .foregroundStyle(KitchenTableTheme.ink)
                    }
                    Text(section.body)
                        .font(KitchenTableTheme.instructionBody)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let durationLabel = section.durationLabel {
                        RecipeStepDurationCue(durationLabel: durationLabel)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(isSelected ? KitchenTableTheme.selectionWash : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(KitchenTableTheme.hairline.opacity(0.35))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spreadStepAccessibilityLabel(section))
        .accessibilityHint(gathers ? "Highlights this step's ingredients." : "Selects this step.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("recipeSpread.step.\(section.stepNumber)")
    }

    private func spreadStepAccessibilityLabel(_ section: RecipeDetailStepSection) -> String {
        var parts = ["Step \(section.stepNumber)"]
        if let title = section.title, !title.isEmpty {
            parts.append(title)
        }
        parts.append(section.body)
        if let durationLabel = section.durationLabel {
            parts.append(durationLabel)
        }
        return parts.joined(separator: ", ")
    }

    private func selectSpreadStep(_ stepID: String, scrollIngredients: Bool) {
        let index = RecipeSpreadIngredientIndex(stepSections: viewModel.stepSections)
        spreadSelection.toggle(stepID: stepID)
        let target: String?
        if scrollIngredients {
            target = spreadSelection.highlightedGroupID(in: index).map(Self.spreadIngredientAnchor)
        } else {
            target = spreadSelection.isSelected(stepID: stepID) ? Self.spreadMethodAnchor(stepID) : nil
        }
        guard let target else {
            return
        }
        // Scroll the facing page once the highlight has rendered, so the two updates do not cancel each other.
        Task { @MainActor in
            await Task.yield()
            withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.3)) {
                if scrollIngredients {
                    scrollIngredientPage(to: target)
                } else {
                    spreadMethodScrollAnchor = target
                }
            }
        }
    }

    private nonisolated static let spreadIngredientContentSpace = "spread.ingredients.content"

    /// Scrolls the ingredients page so a group sits just under the top of the page. The page scrolls by measured
    /// offset: scrolling to the group's ID left the page where it was.
    private func scrollIngredientPage(to anchor: String) {
        guard let minY = spreadIngredientGroupOffsets[anchor] else {
            spreadIngredientScrollPosition.scrollTo(id: anchor, anchor: .top)
            return
        }
        spreadIngredientScrollPosition.scrollTo(y: max(0, minY + Self.spreadPageTopPadding - 12))
    }

    private static var spreadPageTopPadding: CGFloat { 24 }

    private static func spreadIngredientAnchor(_ id: String) -> String {
        "spread.ingredients.\(id)"
    }

    private static func spreadMethodAnchor(_ id: String) -> String {
        "spread.method.\(id)"
    }
}

/// An ingredient on the left page of a recipe spread, set like a printed cookbook: the amount in its own
/// column, then the ingredient in serif. Tapping it checks it off, the same progress the single page keeps.
private struct RecipeSpreadIngredientRow: View {
    let name: String
    let amount: String
    let note: String?
    let isChecked: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isChecked ? KitchenTableTheme.herb : KitchenTableTheme.lineStrong)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(amount)
                    .font(KitchenTableTheme.uiLabel)
                    .monospacedDigit()
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .frame(width: 72, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(KitchenTableTheme.instructionBody)
                        .foregroundStyle(isChecked ? KitchenTableTheme.ink2 : KitchenTableTheme.ink)
                        .strikethrough(isChecked, color: KitchenTableTheme.ink2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note {
                        Text(note)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.ink2)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel([name, amount, note ?? ""].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityValue(isChecked ? "used" : "not used")
    }
}

private struct RecipeActionConfirmationDialog {
    let prompt: RecipeActionConfirmationPrompt
    let clientMutationID: String
}

private struct RecipeDetailCookProgressSnapshot: Codable, Equatable {
    static let currentVersion = RecipeScaleStorage.snapshotVersion

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

/// The recipe page's saved progress, one entry per recipe: its scale and its checked rows. The scale is the
/// recipe's single source of truth for how much to cook; cook mode opens at `scaleFactor(forRecipeID:)`.
enum RecipePageProgress {
    static func storageKey(recipeID: String) -> String {
        RecipeScaleStorage.storageKey(recipeID: recipeID)
    }

    /// The scale the recipe page last saved for this recipe, or 1 when it has none. `RecipeScaleStorage` holds
    /// the logic and its tests; this stays the app's entry point for cook mode.
    static func scaleFactor(forRecipeID recipeID: String, in defaults: UserDefaults = .standard) -> Double {
        RecipeScaleStorage.scaleFactor(forRecipeID: recipeID, in: defaults)
    }
}

/// What "Serves 4" opens: a stepper that scales every amount on the page, in place.
private struct RecipeServesPopover: View {
    let serves: RecipeServes
    @Binding var scaleFactor: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper {
                servesLabel
            } onIncrement: {
                increment()
            } onDecrement: {
                decrement()
            }
            .accessibilityIdentifier("recipe.serves.stepper")

            Text("Every amount on the page scales with it, and cook mode opens at it.")
                .font(KitchenTableTheme.meta)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            if scaleFactor != 1 {
                Button("Back to the recipe's amounts") {
                    scaleFactor = 1
                }
                .font(KitchenTableTheme.control)
                .foregroundStyle(KitchenTableTheme.brass)
                .buttonStyle(.plain)
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .kitchenTransition(.opacity)
            }
        }
        .padding(20)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, alignment: .leading)
        .kitchenAnimation(.snappy, value: scaleFactor)
        .kitchenHaptic(.servingsStepped, trigger: scaleFactor)
        // Paper, so the page under the popover never shows through its words.
        .presentationBackground(KitchenTableTheme.page)
        .presentationCompactAdaptation(.popover)
    }

    private var servesLabel: some View {
        Text(serves.label(scale: scaleFactor))
            .font(KitchenTableTheme.sectionTitle)
            .foregroundStyle(KitchenTableTheme.ink)
            .monospacedDigit()
            .contentTransition(.numericText(value: scaleFactor))
            .fixedSize(horizontal: false, vertical: true)
    }

    // At the ends of the range the stepper's button does nothing; the label already shows the limit.
    private func increment() {
        guard serves.canIncrement(scaleFactor) else { return }
        scaleFactor = serves.incremented(scaleFactor)
    }

    private func decrement() {
        guard serves.canDecrement(scaleFactor) else { return }
        scaleFactor = serves.decremented(scaleFactor)
    }
}

/// The recipe page's photo and the paper sheet that rides up over its foot, matching the Kitchen's hero.
private enum RecipeHeroMetrics {
    static let sheetOverlap: CGFloat = 28
    static let sheetRadius: CGFloat = 28
    /// Save and Add to list at the default text size: a full touch target with room for the glass rim. It scales
    /// with Dynamic Type up to `maximumUtilityButtonSize`.
    static let utilityButtonSize: CGFloat = 52
    static let maximumUtilityButtonSize: CGFloat = 80

    /// About half a phone's height, so the dish leads and the title still shows on the first screen.
    static func height(isRegular: Bool) -> CGFloat {
#if os(macOS)
        360
#else
        isRegular ? 480 : 420
#endif
    }
}

private extension View {
    /// A quiet glass circle for the page's secondary actions; Cook is the only filled button.
    func recipeGlassCircle() -> some View {
        buttonStyle(.plain)
            .font(.title3.weight(.semibold))
            .foregroundStyle(KitchenTableTheme.ink)
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: Circle())
    }
}

/// An ingredient, or an earlier step's output, in a step's checklist. The separator starts under the text, not
/// the checkbox, and the name and amount share a baseline. At accessibility text sizes the cart icon gives its
/// room to the words and the amount moves under the name.
private struct RecipeStepChecklistRow: View {
    let title: String
    let note: String?
    let amount: String
    let systemImage: String
    let isChecked: Bool
    let showsSeparator: Bool
    let accessibilityID: String
    let toggle: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var checkColumn = KitchenTableTheme.Checklist.checkColumn
    @ScaledMetric(relativeTo: .body) private var iconColumn = KitchenTableTheme.Checklist.iconColumn
    @ScaledMetric(relativeTo: .body) private var rowPadding = KitchenTableTheme.Checklist.rowVerticalPadding

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: KitchenTableTheme.Checklist.columnGap) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isChecked ? KitchenTableTheme.herb : KitchenTableTheme.brass)
                    .frame(width: checkColumn, alignment: .center)
                    .accessibilityHidden(true)

                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.brass.opacity(0.85))
                        .frame(width: iconColumn)
                        .accessibilityHidden(true)
                }

                rowText
                    .padding(.vertical, rowPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        if showsSeparator {
                            Rectangle()
                                .fill(KitchenTableTheme.ruleSoft)
                                .frame(height: KitchenTableTheme.hairlineWidth)
                        }
                    }
            }
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isChecked ? "used" : "not used")
        .accessibilityIdentifier(accessibilityID)
    }

    @ViewBuilder private var rowText: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                nameAndNote
                amountText
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                nameAndNote
                Spacer(minLength: 0)
                amountText
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var nameAndNote: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(isChecked ? KitchenTableTheme.ink2 : KitchenTableTheme.ink)
                .strikethrough(isChecked, color: KitchenTableTheme.ink2)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            if let note, !note.isEmpty {
                Text(note)
                    .font(KitchenTableTheme.uiLabel)
                    .tracking(0.8)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .textCase(.uppercase)
            }
        }
    }

    @ViewBuilder private var amountText: some View {
        if !amount.isEmpty {
            Text(amount)
                .font(KitchenTableTheme.uiLabel)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
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

struct RecipeStepDurationCue: View {
    let durationLabel: String

    var body: some View {
        Label("\(durationLabel) timer", systemImage: "timer")
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.herb)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(KitchenTableTheme.vellum.opacity(0.58))
            .clipShape(Capsule())
            .accessibilityLabel("\(durationLabel) timer")
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
