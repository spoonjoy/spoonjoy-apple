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
                cookbookLibrarySpread
                cookbookShelfStrip
                cookbookIndexRows
            }
        }
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
            eyebrow: "Shelf",
            title: "Cookbooks",
            subtitle: list.resultCountLabel,
            hidesTitleInCompactNavigation: true
        ) {
            if canCreateCookbook {
                Button {
                    newCookbookTitle = ""
                    createErrorMessage = nil
                    isPresentingCreate = true
                } label: {
                    Label("New Cookbook", systemImage: "plus")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
            }
        }
    }

    private var leadCookbook: CookbookSurfaceRowViewModel? {
        list.rows.max { current, candidate in
            if current.cover.primaryImageURL != candidate.cover.primaryImageURL {
                return current.cover.primaryImageURL == nil
            }
            if current.recipeCount != candidate.recipeCount {
                return current.recipeCount < candidate.recipeCount
            }
            return current.title.localizedCaseInsensitiveCompare(candidate.title) == .orderedDescending
        }
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

    private var leadCoverWidth: CGFloat {
        usesCompactCookbookLayout ? 188 : 220
    }

    private var compactLeadCoverWidth: CGFloat {
        usesCompactCookbookLayout ? 188 : 240
    }

    private var cookbookLibrarySpread: some View {
        Group {
            if let leadCookbook {
                if usesCompactCookbookLayout {
                    VStack(alignment: .leading, spacing: 16) {
                        leadCookbookStory(leadCookbook)
                        CookbookCoverArt(row: leadCookbook)
                            .frame(width: compactLeadCoverWidth)
                            .accessibilityIdentifier("cookbookLibrarySpread")
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .bottom, spacing: 28) {
                            CookbookCoverArt(row: leadCookbook)
                                .frame(width: leadCoverWidth)
                                .accessibilityIdentifier("cookbookLibrarySpread")
                            leadCookbookStory(leadCookbook)
                        }

                        VStack(alignment: .leading, spacing: 18) {
                            CookbookCoverArt(row: leadCookbook)
                                .frame(width: compactLeadCoverWidth)
                                .accessibilityIdentifier("cookbookLibrarySpread")
                            leadCookbookStory(leadCookbook)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    private func leadCookbookStory(_ cookbook: CookbookSurfaceRowViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest shelf")
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(KitchenTableTheme.brass)
            Text(cookbook.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(cookbook.chefLine) - \(cookbook.recipeCountLabel)")
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
            leadCookbookActions(cookbook)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func leadCookbookActions(_ cookbook: CookbookSurfaceRowViewModel) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                openCookbookButton(cookbook)
                    .frame(maxWidth: 220)

                shareCookbookLink(cookbook)
                    .frame(maxWidth: 160)
            }

            VStack(alignment: .leading, spacing: 10) {
                openCookbookButton(cookbook)
                shareCookbookLink(cookbook)
            }
        }
    }

    private func openCookbookButton(_ cookbook: CookbookSurfaceRowViewModel) -> some View {
        Button {
            openRoute(cookbook.openRoute)
        } label: {
            Label("Open cookbook", systemImage: "text.book.closed")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
    }

    @ViewBuilder private func shareCookbookLink(_ cookbook: CookbookSurfaceRowViewModel) -> some View {
        if let payload = cookbook.sharePayload, let publicURL = payload.publicURL {
            ShareLink(item: publicURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        }
    }

    private var cookbookShelfStrip: some View {
        KitchenTableSection(title: "Shelf", subtitle: "\(list.rows.count) \(list.rows.count == 1 ? "cover" : "covers")") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(list.rows) { row in
                        Button {
                            openRoute(row.openRoute)
                        } label: {
                            CookbookCoverArt(row: row)
                                .frame(width: 132)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(row.title), \(row.recipeCountLabel)")
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityIdentifier("cookbookShelfStrip")
        }
    }

    private var cookbookIndexRows: some View {
        KitchenTableSection(title: "Index", subtitle: list.resultCountLabel) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(list.rows) { row in
                    HStack(spacing: 10) {
                        Button {
                            openRoute(row.openRoute)
                        } label: {
                            KitchenTableObjectRow(title: row.title, subtitle: "\(row.chefLine) - \(row.recipeCountLabel)") {
                                CookbookCoverArt(row: row)
                            } trailing: {
                                Image(systemName: "chevron.forward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(KitchenTableTheme.brass)
                            }
                        }
                        .buttonStyle(.plain)

                        if let payload = row.sharePayload, let publicURL = payload.publicURL {
                            ShareLink(item: publicURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.semibold))
                                    .frame(width: 36, height: 44)
                                    .foregroundStyle(KitchenTableTheme.brass)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Share \(row.title)")
                        }
                    }
                }
            }
            .accessibilityIdentifier("cookbookIndexRows")
        }
    }

    private func cookbookEmptyState(_ emptyState: CookbookSurfaceEmptyState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: emptyState.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.brass)
            Text(emptyState.title)
                .font(KitchenTableTheme.sectionTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(emptyState.message)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(KitchenTableTheme.lineStrong.opacity(0.44))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.lineStrong.opacity(0.44))
                .frame(height: 1)
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
            if let createdCookbook = plan.updatedCookbook {
                list = list.applyingCreatedCookbook(createdCookbook, queuedMutation: queuedMutation)
            }
            if let successRoute = plan.successRoute {
                openRoute(successRoute)
            }
            isPresentingCreate = false
            newCookbookTitle = ""
            createErrorMessage = nil
            if queuedMutation == nil {
                await loadCookbooks()
            }
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
                KitchenEmptySection(
                    title: "No cookbooks saved yet",
                    systemImage: "books.vertical",
                    tint: KitchenTableTheme.brass
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            Button {
                                openRoute(row.openRoute)
                            } label: {
                                KitchenTableObjectRow(title: row.title, subtitle: row.recipeCountLabel) {
                                    CookbookThumb(row: row)
                                } trailing: {
                                    Image(systemName: "chevron.forward")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(KitchenTableTheme.brass)
                                }
                            }
                            .buttonStyle(.plain)

                            if let payload = row.sharePayload, let publicURL = payload.publicURL {
                                ShareLink(item: publicURL) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.body.weight(.semibold))
                                        .frame(width: 36, height: 44)
                                        .foregroundStyle(KitchenTableTheme.brass)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .accessibilityLabel("Share \(row.title)")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CookbookThumb: View {
    let row: CookbookSurfaceRowViewModel

    var body: some View {
        CookbookCoverArt(row: row)
    }
}

private struct CookbookCoverArt: View {
    let title: String
    let recipeCountLabel: String
    let cover: CookbookCover

    init(row: CookbookSurfaceRowViewModel) {
        title = row.title
        recipeCountLabel = row.recipeCountLabel
        cover = row.cover
    }

    init(cookbook: Cookbook) {
        title = cookbook.title
        recipeCountLabel = "\(cookbook.recipeCount) \(cookbook.recipeCount == 1 ? "recipe" : "recipes")"
        cover = cookbook.cover
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if cover.primaryImageURL == nil {
                CookbookFallbackCover(title: title, recipeCountLabel: recipeCountLabel)
            } else {
                CookbookImageCover(imageURLs: cover.imageURLs.compactMap { $0 }, title: title)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Spoonjoy cookbook")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                    Text(title)
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(KitchenTableTheme.onPhoto)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(recipeCountLabel)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KitchenTableTheme.photoCharcoal.opacity(0.82))
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .strokeBorder(KitchenTableTheme.lineStrong.opacity(0.56), lineWidth: 1)
        }
        .shadow(color: KitchenTableTheme.charcoal.opacity(0.08), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(recipeCountLabel)")
        .accessibilityIdentifier("CookbookCoverArt")
    }
}

private struct CookbookImageCover: View {
    let imageURLs: [URL]
    let title: String

    var body: some View {
        GeometryReader { proxy in
            coverMosaic(in: proxy.size)
        }
        .background(KitchenTableTheme.paper)
    }

    @ViewBuilder private func coverMosaic(in size: CGSize) -> some View {
        let URLs = Array(imageURLs.prefix(4))
        if URLs.count <= 1 {
            cookbookCoverTile(url: URLs.first, size: size)
        } else if URLs.count == 2 {
            HStack(spacing: 1) {
                ForEach(Array(URLs.enumerated()), id: \.offset) { _, imageURL in
                    cookbookCoverTile(url: imageURL, size: CGSize(width: (size.width - 1) / 2, height: size.height))
                }
            }
        } else {
            VStack(spacing: 1) {
                cookbookCoverRow(URLs.prefix(2), size: CGSize(width: size.width, height: (size.height - 1) / 2))
                cookbookCoverRow(URLs.dropFirst(2), size: CGSize(width: size.width, height: (size.height - 1) / 2))
            }
        }
    }

    private func cookbookCoverRow<C: Collection>(_ URLs: C, size: CGSize) -> some View where C.Element == URL {
        let rowURLs = Array(URLs)
        let tileWidth = rowURLs.isEmpty ? size.width : (size.width - CGFloat(max(rowURLs.count - 1, 0))) / CGFloat(rowURLs.count)
        return HStack(spacing: 1) {
            ForEach(Array(rowURLs.enumerated()), id: \.offset) { _, imageURL in
                cookbookCoverTile(url: imageURL, size: CGSize(width: tileWidth, height: size.height))
            }
        }
    }

    private func cookbookCoverTile(url: URL?, size: CGSize) -> some View {
        RecipeCoverImage(url: url, title: title, subtitle: "Cover", showsFallbackLabel: false)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

private struct CookbookFallbackCover: View {
    let title: String
    let recipeCountLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Spoonjoy")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(KitchenTableTheme.brass)
                Spacer()
                Text(recipeCountLabel)
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            .padding([.horizontal, .top], 14)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(KitchenTableTheme.lineStrong.opacity(0.45))
                    .frame(height: 1)
            }

            Spacer(minLength: 8)

            Text(title)
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(2)
                .minimumScaleFactor(0.66)
                .allowsTightening(true)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 8) {
                Rectangle().frame(height: 1)
                Rectangle().frame(width: 120, height: 1)
                Rectangle().frame(width: 88, height: 1)
            }
            .foregroundStyle(KitchenTableTheme.line.opacity(0.72))
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(KitchenTableTheme.paper)
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
        KitchenTablePage(maxContentWidth: 860) {
            cookbookDetailSpread
            statusBanner
            recipes
            ownerTools
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
            VStack(alignment: .leading, spacing: 18) {
                detailHeader
                CookbookCoverArt(cookbook: viewModel.cookbook)
                    .frame(width: detailCoverWidth)
                    .accessibilityIdentifier("CookbookDetailHero")
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
                eyebrow: "Cookbook",
                title: viewModel.title,
                subtitle: "\(viewModel.chefLine) - \(viewModel.recipeCountLabel)"
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
        KitchenTableSection(title: "Contents", subtitle: viewModel.recipeCountLabel) {
            if viewModel.recipes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No recipes yet")
                        .font(KitchenTableTheme.sectionTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                    Text(viewModel.ownerTools.isVisible ? "Add recipes with owner tools below." : "This cookbook is empty.")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(KitchenTableTheme.lineStrong.opacity(0.44))
                        .frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(KitchenTableTheme.lineStrong.opacity(0.44))
                        .frame(height: 1)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.recipes.enumerated()), id: \.element.id) { index, recipe in
                        CookbookRecipeIndexRow(recipe: recipe, ordinal: index + 1) {
                            openRoute(recipe.openRoute)
                        } remove: {
                            runAction(.removeRecipe(
                                recipeID: recipe.id,
                                clientMutationID: clientMutationID(prefix: "cookbook-remove-recipe"),
                                confirmation: .required
                            ))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if viewModel.ownerTools.isVisible {
                                Button(role: .destructive) {
                                    runAction(.removeRecipe(
                                        recipeID: recipe.id,
                                        clientMutationID: clientMutationID(prefix: "cookbook-remove-recipe"),
                                        confirmation: .required
                                    ))
                                } label: {
                                    Label("Remove from cookbook", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("cookbookContentsIndex")
            }
        }
    }

    @ViewBuilder private var ownerTools: some View {
        if viewModel.ownerTools.isVisible {
            DisclosureGroup(isExpanded: $isOwnerToolsExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cookbook details")
                            .font(KitchenTableTheme.sectionTitle)
                            .foregroundStyle(KitchenTableTheme.charcoal)
                        TextField("Title", text: $renameTitle)
                            .textFieldStyle(.roundedBorder)
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
                                .foregroundStyle(KitchenTableTheme.charcoal)
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
                    .foregroundStyle(KitchenTableTheme.charcoal)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(KitchenTableTheme.line.opacity(0.55))
                    .frame(height: 1)
            }
            .accessibilityIdentifier("CookbookOwnerToolsDisclosure")
        }
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

private struct CookbookRecipeIndexRow: View {
    let recipe: CookbookRecipeRowViewModel
    let ordinal: Int
    let open: () -> Void
    let remove: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .center, spacing: 12) {
                Text(String(ordinal).padStart(length: 2, pad: "0"))
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(KitchenTableTheme.brass)
                    .frame(width: 30, alignment: .leading)

                if recipe.coverImageURL != nil {
                    CookbookRecipeThumbnail(recipe: recipe)
                        .frame(width: 58, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(KitchenTableTheme.objectTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let servingsLabel = recipe.servingsLabel {
                        Text(servingsLabel)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(KitchenTableTheme.line.opacity(0.35))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ordinal). \(recipe.title)")
    }
}

private struct CookbookRecipeThumbnail: View {
    let recipe: CookbookRecipeRowViewModel

    var body: some View {
        RecipeCoverImage(url: recipe.coverImageURL, title: recipe.title, subtitle: "Photo not added", showsFallbackLabel: false)
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
