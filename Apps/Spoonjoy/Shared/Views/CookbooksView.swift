import SpoonjoyCore
import SwiftUI

struct CookbooksView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    let viewModel: CookbookSurfaceViewModel
    let openRoute: (AppRoute) -> Void
    let performCookbookAction: (@MainActor @Sendable (CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation?)?
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var list: CookbookSurfaceListState
    @State private var errorMessage: String?
    @State private var isPresentingCreate = false
    @State private var newCookbookTitle = ""
    @State private var createErrorMessage: String?

    init(
        viewModel: CookbookSurfaceViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        performCookbookAction: (@MainActor @Sendable (CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation?)? = nil,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.performCookbookAction = performCookbookAction
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _list = State(initialValue: viewModel.list)
    }

    var body: some View {
        KitchenTablePage(maxContentWidth: 860, bottomReserve: cookbookPageBottomReserve) {
            header
            statusBanner

            if let emptyState = list.emptyState {
                cookbookEmptyState(emptyState)
            } else {
                cookbookShelf
            }
        }
        .reloadsOnPull { await loadCookbooks() }
        .task {
            await loadCookbooks()
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "cookbooks",
                source: "CookbooksView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
        .onChange(of: viewModel.list.rows) { _, _ in
            // The shelf follows the chef's synced cookbooks: after a create, delete or sync the app
            // passes a new view model, and its rows replace the ones this view loaded earlier.
            list = viewModel.list
        }
        .sheet(isPresented: $isPresentingCreate) {
            CookbookCreateSheet(
                title: $newCookbookTitle,
                errorMessage: createErrorMessage,
                submit: submitCreateCookbook,
                cancel: cancelCreateCookbook
            )
        }
    }

    private var header: some View {
        KitchenTableHeader(
            title: "Cookbooks",
            subtitle: list.resultCountLabel,
            hidesTitleInCompactNavigation: true
        ) {
            // An empty shelf offers New Cookbook in its empty state instead, so it appears once.
            if canCreateCookbook, list.emptyState == nil {
                newCookbookButton
            }
        }
    }

    private var newCookbookButton: some View {
        Button {
            newCookbookTitle = ""
            createErrorMessage = nil
            isPresentingCreate = true
        } label: {
            Label("New Cookbook", systemImage: "plus")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
    }

    private var usesCompactCookbookLayout: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    private var cookbookPageBottomReserve: CGFloat {
        usesCompactCookbookLayout ? 196 : KitchenTableTheme.compactDockReserve
    }

    /// Two covers to a row on a phone, more on a wider page; one at the accessibility sizes, so a title under its
    /// cover wraps by word, never inside one.
    private var shelfColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), alignment: .top)]
        }
        return [GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 18, alignment: .top)]
    }

    /// Every cookbook once, as a book: its cover, then its title and how many recipes it holds. Share lives in the
    /// long-press menu, so a cover carries one action.
    private var cookbookShelf: some View {
        LazyVGrid(columns: shelfColumns, alignment: .leading, spacing: 24) {
            ForEach(list.rows) { row in
                Button {
                    openRoute(row.openRoute)
                } label: {
                    CookbookShelfBook(row: row)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.title), \(row.recipeCountLabel)")
                .accessibilityHint("Opens the cookbook")
                .contextMenu {
                    if let publicURL = row.sharePayload?.publicURL {
                        ShareLink(item: publicURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("cookbookShelf")
    }

    private func cookbookEmptyState(_ emptyState: CookbookSurfaceEmptyState) -> some View {
        KitchenTableEmptyTile(
            systemImage: emptyState.systemImage,
            title: emptyState.title,
            message: emptyState.message
        ) {
            if canCreateCookbook {
                newCookbookButton
            }
        }
    }

    @ViewBuilder private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if list.offlineIndicator.display != .synced {
                OfflineStatusView(display: list.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
            }
        }
    }

    @MainActor private func loadCookbooks() async {
        do {
            try await viewModel.loadList(query: list.query, limit: list.limit, cursor: list.cursor)
            list = viewModel.list
            errorMessage = nil
        } catch {
            errorMessage = "We couldn't load your cookbooks."
        }
    }

    private var canCreateCookbook: Bool {
        viewModel.canCreateCookbook && performCookbookAction != nil
    }

    private func submitCreateCookbook() {
        Task { @MainActor in
            await createCookbook()
        }
    }

    @MainActor private func createCookbook() async {
        guard let performCookbookAction else {
            return
        }

        do {
            let plan = try viewModel.planCreate(
                title: newCookbookTitle,
                clientMutationID: clientMutationID(prefix: "cookbook-create")
            )
            if let blockedReason = plan.blockedReason {
                createErrorMessage = blockedReason
                return
            }
            let queuedMutation = try await performCookbookAction(plan)
            // A queued create shows its local cookbook right away. A create that reached the server
            // refreshed the synced cookbooks, which arrive through the list's onChange; adding the
            // local copy as well would show the cookbook twice.
            if let queuedMutation, let createdCookbook = plan.updatedCookbook {
                list = list.applyingCreatedCookbook(createdCookbook, queuedMutation: queuedMutation)
            }
            if let successRoute = plan.successRoute {
                openRoute(successRoute)
            }
            isPresentingCreate = false
            newCookbookTitle = ""
            createErrorMessage = nil
        } catch {
            createErrorMessage = "Cookbook action failed."
        }
    }

    private func cancelCreateCookbook() {
        isPresentingCreate = false
        newCookbookTitle = ""
        createErrorMessage = nil
    }

    private func clientMutationID(prefix: String) -> String {
        "cm_\(prefix)_\(UUID().uuidString)"
    }
}

private struct CookbookCreateSheet: View {
    @Binding var title: String
    let errorMessage: String?
    let submit: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(KitchenTableTheme.tomato)
                }
            }
            .navigationTitle("New Cookbook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: submit)
                }
            }
        }
    }
}

struct CookbookShelf: View {
    let rows: [CookbookSurfaceRowViewModel]
    let openRoute: (AppRoute) -> Void

    init(rows: [CookbookSurfaceRowViewModel], openRoute: @escaping (AppRoute) -> Void) {
        self.rows = rows
        self.openRoute = openRoute
    }

    init(cookbooks: [Cookbook], openCookbook: @escaping (String) -> Void) {
        rows = cookbooks.map { CookbookSurfaceRowViewModel(summary: CookbookSummary(cookbook: $0)) }
        openRoute = { route in
            if case .cookbookDetail(let id) = route {
                openCookbook(id)
            }
        }
    }

    var body: some View {
        KitchenTableSection(title: "Cookbook Shelf", subtitle: "\(rows.count) \(rows.count == 1 ? "shelf" : "shelves")") {
            if rows.isEmpty {
                KitchenTableEmptyTile(
                    systemImage: "books.vertical",
                    title: "No cookbooks saved yet",
                    message: "Cookbooks you make or save gather here."
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        // The whole row opens the cookbook; Share is in the long-press menu, not a second icon.
                        Button {
                            openRoute(row.openRoute)
                        } label: {
                            KitchenTableObjectRow(title: row.title, subtitle: row.recipeCountLabel, titleFont: KitchenTableTheme.indexTitle) {
                                CookbookThumb(row: row)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if let publicURL = row.sharePayload?.publicURL {
                                ShareLink(item: publicURL) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// A cookbook's small cover for index rows: its first cover photo, filling the frame with no text on it.
/// Only a cookbook with no photo yet shows its serif initial on a vellum tile.
struct CookbookThumb: View {
    let title: String
    let primaryImageURL: URL?

    init(row: CookbookSurfaceRowViewModel) {
        title = row.title
        primaryImageURL = row.cover.primaryImageURL
    }

    var body: some View {
        if let primaryImageURL {
            RecipeCoverImage(url: primaryImageURL, title: title, subtitle: "Cover", showsFallbackLabel: false)
                .frame(width: 56, height: 56)
                .clipped()
        } else {
            RecipeInitialTile(title: title)
                .frame(width: 56, height: 56)
        }
    }
}

/// One book on the Cookbooks shelf: the cover, then the title in the serif and how many recipes it holds.
private struct CookbookShelfBook: View {
    let row: CookbookSurfaceRowViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CookbookCoverArt(row: row)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 240 : .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(KitchenTableTheme.indexTitle)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.recipeCountLabel)
                    .font(KitchenTableTheme.meta)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A cookbook as a book: one cover photo, or a vellum cover with the title's initial in the serif, with a shadowed spine
/// along the binding edge.
private struct CookbookCoverArt: View {
    let title: String
    let cover: CookbookCover

    init(row: CookbookSurfaceRowViewModel) {
        title = row.title
        cover = row.cover
    }

    init(cookbook: Cookbook) {
        title = cookbook.title
        cover = cookbook.cover
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 2,
            bottomLeadingRadius: 2,
            bottomTrailingRadius: KitchenTableTheme.Radius.panel,
            topTrailingRadius: KitchenTableTheme.Radius.panel,
            style: .continuous
        )
        ZStack(alignment: .leading) {
            if let primaryImageURL = cover.primaryImageURL {
                CookbookImageCover(imageURL: primaryImageURL, title: title)
            } else {
                CookbookFallbackCover(title: title)
            }
            CookbookSpine()
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(shape)
        .shadow(color: KitchenTableTheme.ink.opacity(0.16), radius: 10, x: 2, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityIdentifier("CookbookCoverArt")
    }
}

/// The binding: a soft shadow and a pale crease a few points in from the left edge.
private struct CookbookSpine: View {
    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [KitchenTableTheme.photoCharcoal.opacity(0.38), KitchenTableTheme.photoCharcoal.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 10)
            Rectangle()
                .fill(KitchenTableTheme.onPhoto.opacity(0.22))
                .frame(width: 1)
            LinearGradient(
                colors: [KitchenTableTheme.photoCharcoal.opacity(0.12), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 8)
        }
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

private struct CookbookImageCover: View {
    let imageURL: URL
    let title: String

    var body: some View {
        GeometryReader { proxy in
            RecipeCoverImage(url: imageURL, title: title, subtitle: "Cover", showsFallbackLabel: false)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .background(KitchenTableTheme.raised)
    }
}

private struct CookbookFallbackCover: View {
    let title: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [KitchenTableTheme.vellum, KitchenTableTheme.brass.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // The title is printed beside the cover, so the cover carries only its initial, as a recipe without a
            // photo does. It is decoration and keeps to the cover's size instead of growing with the text.
            Text(String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
                .font(.system(size: 64, weight: .bold, design: .serif))
                .foregroundStyle(KitchenTableTheme.brass)
                .dynamicTypeSize(.large)
                .padding(.leading, 30)
                .padding([.trailing, .bottom], 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CookbookDetailRouteView: View {
    let cookbookID: String
    let viewModel: CookbookSurfaceViewModel
    let openRoute: (AppRoute) -> Void
    let performCookbookAction: @MainActor @Sendable (CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation?
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var detail: CookbookDetailViewModel?
    @State private var errorMessage: String?

    init(
        cookbookID: String,
        viewModel: CookbookSurfaceViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        performCookbookAction: @escaping @MainActor @Sendable (CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation?,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.cookbookID = cookbookID
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.performCookbookAction = performCookbookAction
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _detail = State(initialValue: viewModel.detail)
    }

    var body: some View {
        Group {
            if let detail {
                CookbookDetailView(
                    viewModel: detail,
                    openRoute: openRoute,
                    performCookbookAction: performAndApplyCookbookAction,
                    onDismissOfflineIndicator: onDismissOfflineIndicator
                )
            } else if let errorMessage {
                KitchenTableRouteErrorView(message: errorMessage, systemImage: "books.vertical")
            } else {
                KitchenTableLoadingStateView(title: "Loading cookbook", subtitle: "Opening the cookbook shelf.", systemImage: "books.vertical")
            }
        }
        .task(id: cookbookID) {
            await loadDetail()
        }
    }

    @MainActor private func loadDetail() async {
        do {
            try await viewModel.loadDetail(id: cookbookID)
            detail = viewModel.detail
            errorMessage = nil
        } catch {
            if detail == nil {
                errorMessage = "We couldn't load this cookbook."
            }
        }
    }

    @MainActor private func performAndApplyCookbookAction(_ plan: CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation? {
        let queuedMutation = try await performCookbookAction(plan)
        if let updatedCookbook = plan.updatedCookbook {
            detail = detail?.applying(updatedCookbook: updatedCookbook, queuedMutation: queuedMutation)
        }
        return queuedMutation
    }
}

private struct CookbookDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    let viewModel: CookbookDetailViewModel
    let openRoute: (AppRoute) -> Void
    let performCookbookAction: @MainActor @Sendable (CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation?
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var actionStatusMessage: String?
    @State private var actionErrorMessage: String?
    @State private var renameTitle: String
    @State private var selectedRecipeID: String?
    @State private var activeConfirmationDialog: CookbookConfirmationDialog?
    @State private var isOwnerToolsExpanded = false
    @State private var recipeQuery = ""
    @FocusState private var isRecipeSearchFocused: Bool
    /// The tab stack's cover-zoom namespace, so a recipe's thumbnail grows into its page.
    @Environment(\.recipeZoomNamespace) private var tabRecipeTransition
    @Namespace private var localRecipeTransition

    init(
        viewModel: CookbookDetailViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        performCookbookAction: @escaping @MainActor @Sendable (CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation?,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.performCookbookAction = performCookbookAction
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _renameTitle = State(initialValue: viewModel.title)
        _selectedRecipeID = State(initialValue: viewModel.ownerTools.availableRecipes.first?.id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            cookbookPage
                // Focusing the search field lifts it to the top of the page so its matches sit above the keyboard.
                .onChange(of: isRecipeSearchFocused) { _, isFocused in
                    if isFocused {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(Self.recipeSearchAnchor, anchor: UnitPoint(x: 0.5, y: 0.14))
                        }
                    }
                }
        }
    }

    private static let recipeSearchAnchor = "cookbook.search.anchor"

    private var cookbookPage: some View {
        KitchenTablePage(maxContentWidth: 860) {
            cookbookDetailSpread
            statusBanner
            recipes
            ownerTools
            if isRecipeSearchFocused {
                // A short result list cannot scroll the field up by itself, so the page gains room while typing.
                Color.clear.frame(height: 480)
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
                    runAction(dialog.confirmedAction)
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
        .task(id: viewModel.id) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "cookbook-detail",
                source: "CookbookDetailView",
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

    private var usesCompactCookbookDetailLayout: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    private var detailCoverWidth: CGFloat {
        usesCompactCookbookDetailLayout ? 188 : 208
    }

    private var detailHeaderWidth: CGFloat {
        360
    }

    @ViewBuilder private var cookbookDetailSpread: some View {
        if usesCompactCookbookDetailLayout {
            // On a phone the book leads, then its title, the way a cover opens onto its first page.
            VStack(alignment: .leading, spacing: 18) {
                CookbookCoverArt(cookbook: viewModel.cookbook)
                    .frame(width: detailCoverWidth)
                    .accessibilityIdentifier("CookbookDetailHero")
                detailHeader
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 28) {
                    detailHeader
                        .frame(width: detailHeaderWidth, alignment: .leading)
                    CookbookCoverArt(cookbook: viewModel.cookbook)
                        .frame(width: detailCoverWidth)
                        .accessibilityIdentifier("CookbookDetailHero")
                }

                VStack(alignment: .leading, spacing: 18) {
                    detailHeader
                    CookbookCoverArt(cookbook: viewModel.cookbook)
                        .frame(width: detailCoverWidth)
                        .accessibilityIdentifier("CookbookDetailHero")
                }
            }
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            KitchenTableHeader(
                title: viewModel.title,
                subtitle: "\(viewModel.chefLine) · \(viewModel.recipeCountLabel)",
                titleFont: .system(.title, design: .serif).weight(.bold)
            )
            detailShareAction
        }
    }

    private var detailShareAction: some View {
        ShareLink(item: shareURL) {
            Label("Share Cookbook", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        .frame(maxWidth: 220)
    }

    @ViewBuilder private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
            }
            if let queuedWorkSummary = viewModel.queuedWorkSummary {
                Label(queuedWorkSummary, systemImage: "arrow.triangle.2.circlepath")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }
            if let conflictBanner = viewModel.conflictBanner {
                Label(conflictBanner.message, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
                    .accessibilityHint(conflictBanner.actionTitle)
            }
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
    }

    private var recipes: some View {
        // The header already says how many recipes the book holds, so Contents does not repeat the count.
        KitchenTableSection(title: "Contents") {
            if viewModel.recipes.isEmpty {
                KitchenTableEmptyTile(
                    systemImage: "text.book.closed",
                    title: "No recipes yet",
                    message: viewModel.ownerTools.isVisible ? "Add the first recipe from your kitchen." : "This cookbook is empty."
                ) {
                    if viewModel.ownerTools.isVisible, !viewModel.ownerTools.availableRecipes.isEmpty {
                        Button {
                            isOwnerToolsExpanded = true
                        } label: {
                            Label(viewModel.ownerTools.addRecipeActionTitle, systemImage: "plus")
                        }
                        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                        .accessibilityIdentifier("cookbook.empty.addRecipe")
                    }
                }
            } else {
                if viewModel.recipes.count > 1 {
                    recipeSearchField
                        .id(Self.recipeSearchAnchor)
                }
                let visibleRecipeIDs = matchingRecipeIDs
                if visibleRecipeIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No recipes match \u{201C}\(recipeQuery.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
                            .font(KitchenTableTheme.bodyNote)
                            .foregroundStyle(KitchenTableTheme.ink)
                        Text(SearchSurfaceEmptyState.noMatchHelp)
                            .font(KitchenTableTheme.bodyNote)
                            .foregroundStyle(KitchenTableTheme.ink2)
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cookbook.search.empty")
                }
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.recipes.enumerated()), id: \.element.id) { index, recipe in
                        if visibleRecipeIDs.contains(recipe.id) {
                            if recipe.id != visibleRecipeIDs.firstID(in: viewModel.recipes) {
                                RecipeIndexRowSeparator()
                            }
                            CookbookRecipeIndexRow(
                                recipe: recipe,
                                ordinal: index + 1,
                                namespace: tabRecipeTransition ?? localRecipeTransition,
                                removeAccessibilityLabel: removeAccessibilityLabel(for: recipe)
                            ) {
                                openRoute(recipe.openRoute)
                            } remove: {
                                runAction(.removeRecipe(
                                    recipeID: recipe.id,
                                    clientMutationID: clientMutationID(prefix: "cookbook-remove-recipe"),
                                    confirmation: .required
                                ))
                            }
                        }
                    }
                }
                .accessibilityIdentifier("cookbookContentsIndex")
            }
        }
    }

    /// The recipes matching the search. Rows keep their place in the whole cookbook, so numbering holds still.
    private var matchingRecipeIDs: Set<String> {
        Set(CookbookRecipeSearch.filter(viewModel.recipes, query: recipeQuery) { $0.title }.map(\.id))
    }

    private var recipeSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KitchenTableTheme.ink2)
                .accessibilityHidden(true)
            TextField("Search this cookbook", text: $recipeQuery)
                .textFieldStyle(.plain)
                .font(KitchenTableTheme.bodyNote)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isRecipeSearchFocused)
                .onSubmit { isRecipeSearchFocused = false }
                .accessibilityIdentifier("cookbook.search.field")
            if !recipeQuery.isEmpty {
                Button {
                    recipeQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KitchenTableTheme.ink2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: KitchenTableTheme.minimumTouchTarget + 2)
        .glassEffect(.regular, in: Capsule())
    }

    @ViewBuilder private var ownerTools: some View {
        if viewModel.ownerTools.isVisible {
            DisclosureGroup(isExpanded: $isOwnerToolsExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cookbook details")
                            .font(KitchenTableTheme.sectionTitle)
                            .foregroundStyle(KitchenTableTheme.ink)
                        TextField("Title", text: $renameTitle)
                            .textFieldStyle(.plain)
                            .font(KitchenTableTheme.bodyNote)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(KitchenTableTheme.lineStrong)
                                    .frame(height: KitchenTableTheme.hairlineWidth)
                            }
                        Button {
                            runAction(.rename(
                                title: renameTitle,
                                clientMutationID: clientMutationID(prefix: "cookbook-rename")
                            ))
                        } label: {
                            Label(viewModel.ownerTools.editTitleActionTitle, systemImage: "pencil")
                        }
                        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                        .frame(maxWidth: 220)
                    }

                    if !viewModel.ownerTools.availableRecipes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add recipe to cookbook")
                                .font(KitchenTableTheme.sectionTitle)
                                .foregroundStyle(KitchenTableTheme.ink)
                            Picker("Recipe", selection: selectedRecipeBinding) {
                                ForEach(viewModel.ownerTools.availableRecipes, id: \.id) { recipe in
                                    Text(recipe.title).tag(Optional(recipe.id))
                                }
                            }
                            Button {
                                if let selectedRecipeID {
                                    runAction(.addRecipe(
                                        recipeID: selectedRecipeID,
                                        clientMutationID: clientMutationID(prefix: "cookbook-add-recipe")
                                    ))
                                }
                            } label: {
                                Label(viewModel.ownerTools.addRecipeActionTitle, systemImage: "plus.circle")
                            }
                            .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
                            .frame(maxWidth: 220)
                        }
                    }

                    Button(role: .destructive) {
                        runAction(.deleteCookbook(
                            clientMutationID: clientMutationID(prefix: "cookbook-delete"),
                            confirmation: .required
                        ))
                    } label: {
                        Label("Delete Cookbook", systemImage: "trash")
                    }
                    .buttonStyle(KitchenTableActionButtonStyle(prominence: .destructive))
                    .frame(maxWidth: 220)
                }
                .padding(.top, 10)
            } label: {
                Label("Owner tools", systemImage: "wrench.and.screwdriver")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(KitchenTableTheme.hairline.opacity(0.55))
                    .frame(height: 1)
            }
            .accessibilityIdentifier("CookbookOwnerToolsDisclosure")
        }
    }

    /// The label of a row's Remove button, or nil when this chef cannot remove recipes.
    private func removeAccessibilityLabel(for recipe: CookbookRecipeRowViewModel) -> String? {
        viewModel.canRemoveRecipes ? viewModel.removeRecipeAccessibilityLabel(for: recipe) : nil
    }

    private var selectedRecipeBinding: Binding<String?> {
        Binding(
            get: { selectedRecipeID },
            set: { selectedRecipeID = $0 }
        )
    }

    private var shareURL: URL {
        let payload = (try? NativeSharePayload.publicCookbook(viewModel.cookbook)) ?? viewModel.sharePayload
        return payload.publicURL ?? viewModel.cookbook.canonicalURL
    }

    private func runAction(_ action: CookbookSurfaceAction) {
        Task { @MainActor in
            do {
                let plan = try viewModel.plan(action)
                if let prompt = plan.confirmationPrompt {
                    activeConfirmationDialog = CookbookConfirmationDialog(
                        prompt: prompt,
                        confirmedAction: confirmedAction(for: action)
                    )
                    return
                }
                if let blockedReason = plan.blockedReason {
                    actionErrorMessage = blockedReason
                    actionStatusMessage = nil
                    return
                }
                _ = try await performCookbookAction(plan)
                if let successRoute = plan.successRoute {
                    openRoute(successRoute)
                }
                actionStatusMessage = statusMessage(for: action)
                actionErrorMessage = nil
            } catch {
                actionStatusMessage = nil
                actionErrorMessage = "Cookbook action failed."
            }
        }
    }

    private func confirmedAction(for action: CookbookSurfaceAction) -> CookbookSurfaceAction {
        switch action {
        case .deleteCookbook(let clientMutationID, .required):
            .deleteCookbook(clientMutationID: clientMutationID, confirmation: .confirmed)
        case .removeRecipe(let recipeID, let clientMutationID, .required):
            .removeRecipe(recipeID: recipeID, clientMutationID: clientMutationID, confirmation: .confirmed)
        default:
            action
        }
    }

    private func statusMessage(for action: CookbookSurfaceAction) -> String {
        switch action {
        case .create:
            "Cookbook created"
        case .rename:
            "Cookbook renamed"
        case .deleteCookbook:
            "Cookbook deleted"
        case .addRecipe:
            "Recipe added"
        case .removeRecipe:
            "Recipe removed"
        }
    }

    private func clientMutationID(prefix: String) -> String {
        "cm_\(prefix)_\(UUID().uuidString)"
    }
}

/// A cookbook's recipe: the shared recipe row with its place in the book, and Remove for the book's owner.
private struct CookbookRecipeIndexRow: View {
    let recipe: CookbookRecipeRowViewModel
    let ordinal: Int
    let namespace: Namespace.ID
    /// The Remove button's label; nil hides Remove, for chefs who do not own the cookbook.
    let removeAccessibilityLabel: String?
    let open: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            RecipeIndexRow(
                id: recipe.id,
                title: recipe.title,
                detail: recipe.servingsLabel,
                coverURL: recipe.coverImageURL,
                accessibilityLabel: "\(ordinal). \(recipe.title)",
                ordinal: ordinal,
                namespace: namespace,
                action: open
            )
            if let removeAccessibilityLabel {
                // The rows sit in a scroll view, where swipe actions never trigger, so Remove is a
                // visible button. Borderless, so a tap on it never also opens the recipe.
                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.tomato)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(removeAccessibilityLabel)
                // One identifier for every row; a journey picks the row by the label, which names the recipe.
                .accessibilityIdentifier("cookbook.recipe.remove")
            }
        }
    }
}

private struct CookbookConfirmationDialog: Identifiable {
    let id = UUID()
    let prompt: CookbookActionConfirmationPrompt
    let confirmedAction: CookbookSurfaceAction
}

private extension String {
    func padStart(length: Int, pad: Character) -> String {
        if count >= length {
            return self
        }
        return String(repeating: String(pad), count: length - count) + self
    }
}

private extension Set where Element == String {
    /// The first recipe of the book that this set holds, so the separator goes between visible rows only.
    func firstID(in recipes: [CookbookRecipeRowViewModel]) -> String? {
        recipes.first { contains($0.id) }?.id
    }
}
