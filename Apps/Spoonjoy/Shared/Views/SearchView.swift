import SpoonjoyCore
import Foundation
import SwiftUI

struct SearchView: View {
    private static let screenshotAccountIDEnvironmentKey = "SPOONJOY_SCREENSHOT_ACCOUNT_ID"
    private static let screenshotProofPathEnvironmentKey = "SPOONJOY_SCREENSHOT_PROOF_PATH"

    @Binding private var search: SearchState
    @State private var inFlightRequest: SearchSurfaceRequest?

    private let viewModel: SearchSurfaceViewModel
    private let openRoute: (AppRoute) -> Void
    private let searchTask: @MainActor @Sendable (SearchState) async -> Void
    private let debounce = SearchSurfaceDebouncePolicy(delayMilliseconds: 350, defaultLimit: 20)

    init(
        search: Binding<SearchState>,
        viewModel: SearchSurfaceViewModel,
        openRoute: @escaping (AppRoute) -> Void,
        searchTask: @escaping @MainActor @Sendable (SearchState) async -> Void = { _ in }
    ) {
        _search = search
        self.viewModel = viewModel
        self.openRoute = openRoute
        self.searchTask = searchTask
    }

    var body: some View {
        List {
            if viewModel.offlineIndicator.display.isVisible {
                Section {
                    OfflineStatusView(display: viewModel.offlineIndicator.display)
                }
            }

            if let errorState = viewModel.errorState {
                Section {
                    SearchSurfaceMessageView(
                        title: errorState.title,
                        message: errorState.message,
                        systemImage: errorState.systemImage
                    )
                }
            }

            if viewModel.sections.isEmpty, let emptyState = viewModel.emptyState {
                Section {
                    SearchSurfaceMessageView(
                        title: emptyState.title,
                        message: emptyState.message,
                        systemImage: emptyState.systemImage
                    )
                }
            } else {
                ForEach(viewModel.sections) { section in
                    SearchSurfaceSectionView(section: section, openRoute: openRoute)
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .navigationTitle("Search")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(KitchenTableTheme.herb)
        .accessibilityIdentifier(SearchSurfaceContract.typedRows)
        .accessibilityHint(SearchSurfaceContract.searchableScopes)
        .accessibilityValue(searchableScopeOrder.map(\.rawValue).joined(separator: ", "))
        .task(id: search.route.stateIdentifier) {
            await writeScreenshotProofIfNeeded()
            await debounceSearch()
        }
    }

    private var searchableScopeOrder: [SearchScope] {
        viewModel.searchableScopes
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
        Section(section.title) {
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
        HStack(spacing: 12) {
            SearchSurfaceThumbnail(row: row)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

private struct SearchSurfaceThumbnail: View {
    let row: SearchSurfaceRow

    var body: some View {
        ZStack {
            if let imageURL = row.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    thumbnailFill
                }
            } else {
                thumbnailFill
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
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
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(KitchenTableTheme.brass)
        }
        .padding(.vertical, 8)
    }
}
