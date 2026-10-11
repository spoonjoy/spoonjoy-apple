import SpoonjoyCore
import Foundation
import SwiftUI

struct SearchView: View {
    private static let screenshotAccountIDEnvironmentKey = "SPOONJOY_SCREENSHOT_ACCOUNT_ID"
    private static let screenshotDisableSearchFocusEnvironmentKey = "SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS"
    private static let screenshotProofPathEnvironmentKey = "SPOONJOY_SCREENSHOT_PROOF_PATH"

    @Binding private var search: SearchState
    @State private var inFlightRequest: SearchSurfaceRequest?
    @FocusState private var isSearchFieldFocused: Bool

    private let viewModel: SearchSurfaceViewModel
    private let openRoute: (AppRoute) -> Void
    private let recipeCovers: [String: URL]
    private let cookbookCovers: [String: URL]
    private let searchTask: @MainActor @Sendable (SearchState) async -> Void
    private let onDismissOfflineIndicator: @MainActor @Sendable () -> Void
    private let debounce = SearchSurfaceDebouncePolicy(delayMilliseconds: 350, defaultLimit: 20)

    @Environment(\.spoonjoyCompactNavigation) private var usesCompactNavigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    init(
        search: Binding<SearchState>,
        viewModel: SearchSurfaceViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        recipeCovers: [String: URL] = [:],
        cookbookCovers: [String: URL] = [:],
        searchTask: @escaping @MainActor @Sendable (SearchState) async -> Void = { _ in },
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        _search = search
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.recipeCovers = recipeCovers
        self.cookbookCovers = cookbookCovers
        self.searchTask = searchTask
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
    }

    var body: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: "Kitchen Index",
                title: "Search",
                subtitle: search.query.isEmpty ? "Find something cookable." : "Results for \(search.query)",
                hidesTitleInCompactNavigation: true
            )

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
                    SearchSurfaceSectionView(section: section, recipeCovers: recipeCovers, cookbookCovers: cookbookCovers, openRoute: openRoute)
                }
            }
        }
        .tint(KitchenTableTheme.herb)
        .navigationTitle("Search")
        .modifier(SearchFieldChrome(
            ownsSearchField: !usesCompactNavigation,
            text: searchTextBinding,
            scope: searchScopeBinding,
            scopes: searchableScopeOrder,
            isFocused: $isSearchFieldFocused
        ))
        .onAppear {
            focusSearchFieldIfNeeded()
        }
        .onSubmit(of: .search) {
            Task {
                await searchTask(search)
            }
        }
        // A container keeps the page identifier off the result rows, which carry their own.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SearchSurfaceContract.typedRows)
        .accessibilityHint(SearchSurfaceContract.searchableScopes)
        .accessibilityValue(searchableScopeOrder.map(\.rawValue).joined(separator: ", "))
        .task(id: search.route.stateIdentifier) {
            focusSearchFieldIfNeeded()
            await writeScreenshotProofIfNeeded()
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "search",
                source: "SearchView",
                runtimeContext: screenshotAccessibilityRuntimeContext
            )
            await debounceSearch()
        }
    }

    private var shouldAutoFocusSearchField: Bool {
        !Self.truthy(ProcessInfo.processInfo.environment[Self.screenshotDisableSearchFocusEnvironmentKey])
    }

    private static func truthy(_ rawValue: String?) -> Bool {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["1", "true", "yes", "y", "on"].contains(value)
    }

    private func focusSearchFieldIfNeeded() {
        // On iPhone the search tab owns the field; selecting the tab activates it.
        guard shouldAutoFocusSearchField, !usesCompactNavigation else {
            isSearchFieldFocused = false
            return
        }
        isSearchFieldFocused = true
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { search.text },
            set: { text in
                search.update(query: text, scope: search.scope)
            }
        )
    }

    private var searchScopeBinding: Binding<SearchScope> {
        Binding(
            get: { search.scope },
            set: { scope in
                search.update(query: search.text, scope: scope)
                Task {
                    await searchTask(search)
                }
            }
        )
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

/// On iPhone the shell's search tab owns the search field, applied to the TabView; everywhere else this page
/// owns it, pinned in the navigation bar on iOS.
private struct SearchFieldChrome: ViewModifier {
    let ownsSearchField: Bool
    @Binding var text: String
    @Binding var scope: SearchScope
    let scopes: [SearchScope]
    let isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if ownsSearchField {
            content
#if os(iOS)
                .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Spoonjoy")
#else
                .searchable(text: $text, prompt: "Search Spoonjoy")
#endif
                .searchFocused(isFocused)
                .searchScopes($scope) {
                    ForEach(scopes, id: \.rawValue) { scope in
                        Text(SearchSurfaceNativeChrome.title(for: scope)).tag(scope)
                    }
                }
        } else {
            content
        }
    }
}

enum SearchSurfaceNativeChrome {
    static func title(for scope: SearchScope) -> String {
        scope.compactTitle
    }
}

private struct SearchSurfaceSectionView: View {
    let section: SearchSurfaceSection
    let recipeCovers: [String: URL]
    let cookbookCovers: [String: URL]
    let openRoute: (AppRoute) -> Void

    var body: some View {
        KitchenTableSection(title: section.title) {
            ForEach(section.rows) { row in
                Button {
                    openRoute(row.openRoute)
                } label: {
                    SearchSurfaceRowView(row: row, imageURL: row.imageURL(recipeCovers: recipeCovers, cookbookCovers: cookbookCovers))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.result")
            }
        }
    }
}

private struct SearchSurfaceRowView: View {
    let row: SearchSurfaceRow
    let imageURL: URL?

    var body: some View {
        KitchenTableObjectRow(title: row.title, subtitle: row.subtitle, detail: row.snippetText, titleFont: KitchenTableTheme.indexTitle) {
            SearchSurfaceThumbnail(row: row, imageURL: imageURL)
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
    let imageURL: URL?
    @State private var readinessInstanceID = UUID().uuidString

    var body: some View {
        ZStack {
            if let imageURL {
                CachedAsyncImage(url: imageURL, animation: imageLoadingAnimation) { phase in
                    let readinessPhase = readinessPhase(for: phase)
                    KitchenTableImagePhaseView(phase: phase, reduceMotion: accessibilityReduceMotion) {
                        thumbnailFill
                    }
                    .task(id: readinessPhase) {
                        await record(readinessPhase, token: readinessToken(for: imageURL))
                    }
                }
                .id(imageURL.absoluteString)
                .onDisappear {
                    let token = readinessToken(for: imageURL)
                    Task {
                        await ScreenshotVisualReadiness.removeMedia(token)
                    }
                }
            } else {
                thumbnailFill
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
    }

    private var imageLoadingAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18)
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

    private func readinessPhase(for phase: CachedImagePhase) -> SearchImageReadinessPhase {
        switch phase {
        case .empty:
            .pending
        case .success:
            .loaded
        case .failure:
            .failed
        }
    }

    private func readinessToken(for url: URL) -> ScreenshotVisualReadinessMediaToken {
        ScreenshotVisualReadinessMediaToken(
            resourceID: "search-thumbnail:\(url.absoluteString)",
            instanceID: readinessInstanceID
        )
    }

    private func record(
        _ phase: SearchImageReadinessPhase,
        token: ScreenshotVisualReadinessMediaToken
    ) async {
        switch phase {
        case .pending:
            await ScreenshotVisualReadiness.beginMedia(token)
        case .loaded:
            await ScreenshotVisualReadiness.finishMedia(token, succeeded: true)
        case .failed:
            await ScreenshotVisualReadiness.finishMedia(token, succeeded: false)
        }
    }
}

private enum SearchImageReadinessPhase: Hashable {
    case pending
    case loaded
    case failed
}

private struct KitchenTableImagePhaseView<Placeholder: View>: View {
    let phase: CachedImagePhase
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
