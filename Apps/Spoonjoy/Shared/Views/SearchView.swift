import SpoonjoyCore
import Foundation
import SwiftUI

struct SearchView: View {
    private static let screenshotAccountIDEnvironmentKey = "SPOONJOY_SCREENSHOT_ACCOUNT_ID"
    private static let screenshotProofPathEnvironmentKey = "SPOONJOY_SCREENSHOT_PROOF_PATH"

    @Binding private var search: SearchState
    @State private var inFlightRequest: SearchSurfaceRequest?
    @FocusState private var isSearchFocused: Bool

    private let viewModel: SearchSurfaceViewModel
    private let openRoute: (AppRoute) -> Void
    private let searchTask: @MainActor @Sendable (SearchState) async -> Void
    private let onDismissOfflineIndicator: @MainActor @Sendable () -> Void
    private let debounce = SearchSurfaceDebouncePolicy(delayMilliseconds: 350, defaultLimit: 20)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    init(
        search: Binding<SearchState>,
        viewModel: SearchSurfaceViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        searchTask: @escaping @MainActor @Sendable (SearchState) async -> Void = { _ in },
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        _search = search
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.searchTask = searchTask
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
    }

    var body: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: "Kitchen Index",
                title: "Search",
                subtitle: search.query.isEmpty ? "Find something cookable." : "Results for \(search.query)"
            )

            searchControls

            if viewModel.offlineIndicator.display.isVisible {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
            }

            if let errorState = viewModel.errorState {
                SearchSurfaceMessageView(
                    title: errorState.title,
                    message: errorState.message,
                    systemImage: errorState.systemImage
                )
            }

            if viewModel.sections.isEmpty, let emptyState = viewModel.emptyState {
                SearchSurfaceMessageView(
                    title: emptyState.title,
                    message: emptyState.message,
                    systemImage: emptyState.systemImage
                )
            } else {
                ForEach(viewModel.sections) { section in
                    SearchSurfaceSectionView(section: section, openRoute: openRoute)
                }
            }
        }
        .tint(KitchenTableTheme.herb)
        .navigationTitle("Search")
        .accessibilityIdentifier(SearchSurfaceContract.typedRows)
        .accessibilityHint(SearchSurfaceContract.searchableScopes)
        .accessibilityValue(searchableScopeOrder.map(\.rawValue).joined(separator: ", "))
        .task(id: search.route.stateIdentifier) {
            await writeScreenshotProofIfNeeded()
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "search",
                source: "SearchView",
                runtimeContext: screenshotAccessibilityRuntimeContext
            )
            await debounceSearch()
        }
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(KitchenTableTheme.brass)
                TextField("tomato beans", text: searchTextBinding)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .onSubmit {
                        Task {
                            await searchTask(search)
                        }
                    }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(KitchenTableTheme.line.opacity(0.72), lineWidth: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searchableScopeOrder, id: \.rawValue) { scope in
                        Button {
                            search.update(query: search.query, scope: scope)
                            Task {
                                await searchTask(search)
                            }
                        } label: {
                            Text(scopeLabel(scope))
                                .font(KitchenTableTheme.uiLabel)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 34)
                                .foregroundStyle(scope == search.scope ? KitchenTableTheme.paper : KitchenTableTheme.charcoal)
                                .background(scope == search.scope ? KitchenTableTheme.charcoal : KitchenTableTheme.paper, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { search.query },
            set: { query in
                search.update(query: query, scope: search.scope)
            }
        )
    }

    private func scopeLabel(_ scope: SearchScope) -> String {
        switch scope {
        case .all:
            "Everything"
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

    private var searchableScopeOrder: [SearchScope] {
        viewModel.searchableScopes
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    @MainActor
    private func debounceSearch() async {
        let decision = debounce.plan(
            previous: viewModel.state,
            next: search,
            inFlight: inFlightRequest
        )
        if decision.cancelsInFlightSearch {
            inFlightRequest = nil
        }
        guard let scheduledRequest = decision.scheduledRequest else {
            return
        }

        inFlightRequest = scheduledRequest
        defer {
            if inFlightRequest == scheduledRequest {
                inFlightRequest = nil
            }
        }
        if decision.delayMilliseconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(decision.delayMilliseconds) * 1_000_000)
        }
        guard !Task.isCancelled else {
            return
        }

        await searchTask(SearchState(query: scheduledRequest.query, scope: scheduledRequest.scope))
    }

    @MainActor
    private func writeScreenshotProofIfNeeded() async {
#if DEBUG
        guard let rawPath = ProcessInfo.processInfo.environment[Self.screenshotProofPathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else {
            return
        }
        let accountID = ProcessInfo.processInfo.environment[Self.screenshotAccountIDEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let outputURL = URL(fileURLWithPath: rawPath)
        let payload: [String: Any] = [
            "route": "search",
            "routeIdentifier": search.route.stateIdentifier,
            "query": search.query,
            "scope": search.scope.rawValue,
            "searchScopes": searchableScopeOrder.map(\.rawValue),
            "accountID": accountID,
            "visibleSections": viewModel.sections.map(\.title),
            "source": "SearchView",
            "writtenAt": ISO8601DateFormatter().string(from: Date())
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: outputURL, options: [.atomic])
#endif
    }
}

private enum SearchSurfaceContract {
    static let searchableScopes = "searchable scopes"
    static let typedRows = "typed rows"
}

private struct SearchSurfaceSectionView: View {
    let section: SearchSurfaceSection
    let openRoute: (AppRoute) -> Void

    var body: some View {
        KitchenTableSection(title: section.title) {
            ForEach(section.rows) { row in
                Button {
                    openRoute(row.openRoute)
                } label: {
                    SearchSurfaceRowView(row: row)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SearchSurfaceRowView: View {
    let row: SearchSurfaceRow

    var body: some View {
        KitchenTableObjectRow(title: row.title, subtitle: row.subtitle) {
            SearchSurfaceThumbnail(row: row)
        } trailing: {
            Image(systemName: "chevron.right")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

private struct SearchSurfaceThumbnail: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let row: SearchSurfaceRow

    var body: some View {
        ZStack {
            if let imageURL = row.imageURL {
                AsyncImage(url: imageURL, transaction: imageLoadingTransaction) { phase in
                    KitchenTableImagePhaseView(phase: phase, reduceMotion: accessibilityReduceMotion) {
                        thumbnailFill
                    }
                }
            } else if let fallbackAssetName {
                Image(fallbackAssetName)
                    .resizable()
                    .scaledToFill()
                    .transition(accessibilityReduceMotion ? .identity : .opacity)
            } else {
                thumbnailFill
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
    }

    private var imageLoadingTransaction: Transaction {
        Transaction(animation: accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18))
    }

    private var thumbnailFill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .fill(accent.opacity(0.14))
            Image(systemName: row.systemImage)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
        }
    }

    private var fallbackAssetName: String? {
        guard row.result.type == .recipe else {
            return nil
        }
        return RecipeCoverImage.bundledAssetName(forRecipeID: row.result.id)
            ?? RecipeCoverImage.fallbackFoodAssetName(forTitle: row.title)
    }

    private var accent: Color {
        switch row.result.type {
        case .recipe:
            KitchenTableTheme.tomato
        case .cookbook:
            KitchenTableTheme.brass
        case .chef:
            KitchenTableTheme.herb
        case .shoppingListItem:
            KitchenTableTheme.charcoal
        }
    }
}

private struct KitchenTableImagePhaseView<Placeholder: View>: View {
    let phase: AsyncImagePhase
    let reduceMotion: Bool
    @ViewBuilder let placeholder: () -> Placeholder

    var body: some View {
        switch phase {
        case .empty:
            placeholder()
        case .success(let image):
            image
                .resizable()
                .scaledToFill()
                .transition(reduceMotion ? .identity : .opacity)
        case .failure:
            placeholder()
        @unknown default:
            placeholder()
        }
    }
}

private struct SearchSurfaceMessageView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text(message)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(KitchenTableTheme.brass)
        }
        .padding(.vertical, 8)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }
}
