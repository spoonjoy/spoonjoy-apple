import SpoonjoyCore
import SwiftUI

struct CookbooksView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

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
        KitchenTablePage {
            header
            statusBanner

            if let emptyState = list.emptyState {
                KitchenEmptySection(
                    title: "\(emptyState.title). \(emptyState.message)",
                    systemImage: emptyState.systemImage,
                    tint: KitchenTableTheme.brass
                )
            } else {
                CookbookShelf(rows: list.rows, openRoute: openRoute)
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
        KitchenTableHeader(eyebrow: "Library", title: "Cookbooks", subtitle: list.resultCountLabel) {
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
            errorMessage = "Cookbooks unavailable."
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
        ZStack {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .fill(KitchenTableTheme.brass.opacity(0.16))
            if let imageURL = row.cover.primaryImageURL {
                RecipeCoverImage(url: imageURL, title: row.title, subtitle: row.recipeCountLabel)
            } else {
                Image(systemName: "books.vertical")
                    .foregroundStyle(KitchenTableTheme.brass)
            }
        }
    }
}

private struct CookbookCover: View {
    let row: CookbookSurfaceRowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                    .fill(KitchenTableTheme.brass.opacity(0.18))
                    .aspectRatio(3 / 4, contentMode: .fit)
                if let imageURL = row.cover.primaryImageURL {
                    RecipeCoverImage(url: imageURL, title: row.title, subtitle: row.recipeCountLabel)
                        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 120)

            Text(row.title)
                .font(.headline)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(row.recipeCountLabel)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(.secondary)
        }
        .frame(width: 132, alignment: .leading)
        .accessibilityLabel("\(row.title), \(row.recipeCountLabel)")
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
                Label(errorMessage, systemImage: "books.vertical")
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
                errorMessage = "Cookbook unavailable."
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

    let viewModel: CookbookDetailViewModel
    let openRoute: (AppRoute) -> Void
    let performCookbookAction: @MainActor @Sendable (CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation?
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var actionStatusMessage: String?
    @State private var actionErrorMessage: String?
    @State private var renameTitle: String
    @State private var selectedRecipeID: String?
    @State private var activeConfirmationDialog: CookbookConfirmationDialog?

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
        KitchenTablePage {
            header
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            CookbookCover(row: CookbookSurfaceRowViewModel(summary: CookbookSummary(cookbook: viewModel.cookbook)))

            KitchenTableHeader(
                eyebrow: "Cookbook",
                title: viewModel.title,
                subtitle: "\(viewModel.chefLine) - \(viewModel.recipeCountLabel)"
            ) {
                ShareLink(item: shareURL) {
                    Label("Share Cookbook", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            }
        }
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Recipes")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(viewModel.recipes) { recipe in
                HStack(spacing: 10) {
                    if let imageURL = recipe.coverImageURL {
                        RecipeCoverImage(
                            url: imageURL,
                            title: recipe.title,
                            subtitle: recipe.coverProvenanceLabel
                        )
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                    }

                    Button {
                        openRoute(recipe.openRoute)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(recipe.title)
                                .font(KitchenTableTheme.bodyNote)
                            if let servingsLabel = recipe.servingsLabel {
                                Text(servingsLabel)
                                    .font(KitchenTableTheme.uiLabel)
                                    .foregroundStyle(.secondary)
                            }
                            if let coverProvenanceLabel = recipe.coverProvenanceLabel {
                                Text(coverProvenanceLabel)
                                    .font(KitchenTableTheme.uiLabel)
                                    .foregroundStyle(KitchenTableTheme.brass)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if viewModel.ownerTools.isVisible {
                        Button(role: .destructive) {
                            runAction(.removeRecipe(
                                recipeID: recipe.id,
                                clientMutationID: clientMutationID(prefix: "cookbook-remove-recipe"),
                                confirmation: .required
                            ))
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder private var ownerTools: some View {
        if viewModel.ownerTools.isVisible {
            VStack(alignment: .leading, spacing: 12) {
                Text("Owner Tools")
                    .font(.title2)
                    .foregroundStyle(KitchenTableTheme.charcoal)

                HStack(alignment: .firstTextBaseline) {
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
                    .buttonStyle(.bordered)
                }

                if !viewModel.ownerTools.availableRecipes.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
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
                        .buttonStyle(.borderedProminent)
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
                .buttonStyle(.bordered)
            }
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

private struct CookbookConfirmationDialog: Identifiable {
    let id = UUID()
    let prompt: CookbookActionConfirmationPrompt
    let confirmedAction: CookbookSurfaceAction
}
