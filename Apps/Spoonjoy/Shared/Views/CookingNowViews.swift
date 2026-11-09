import Foundation
import Observation
import SpoonjoyCore
import SwiftUI

/// Keeps the "Cooking now" list for every window: this device's cook progress, merged with the server's list of what
/// the chef is cooking on every device, and the last server list kept on disk for offline use.
@MainActor
@Observable
final class CookingNowCenter {
    private(set) var entries: [CookingNowEntry] = []
#if DEBUG
    /// Journey runs only: what the list was built from, so a journey that finds no row can say why.
    private(set) var journeySummary = "not updated"
    @ObservationIgnored private var lastFetch = "not fetched"
#endif

    @ObservationIgnored private var server: [CookingNowEntry] = []
    @ObservationIgnored private var serverFetchedAt: Date?
    @ObservationIgnored private var scope: String?
    @ObservationIgnored private var local: [CookingNowEntry] = []
    @ObservationIgnored private var recipes: [Recipe] = []
    @ObservationIgnored private var configuration: APIClientConfiguration?
    @ObservationIgnored private var isFetching = false
    @ObservationIgnored private let cacheStore: CookingNowCacheStore

    init(cacheStore: CookingNowCacheStore = CookingNowCacheStore(
        directory: NativeAppStateLocation.defaultFileURL().deletingLastPathComponent()
    )) {
        self.cacheStore = cacheStore
    }

    /// Takes this device's latest content: its cook progress, the recipes it knows and the signed-in account.
    func update(contentState: NativeShellContentState) {
        let nextScope = contentState.spotlightIndexScope.map {
            CookingNowCache.scope(accountID: $0.accountID, environment: $0.environment)
        }
        let previousSignIn = [scope, configuration?.bearerToken]
        if nextScope != scope {
            scope = nextScope
            let cache = nextScope.flatMap(cacheStore.load(scope:))
            server = cache?.entries ?? []
            serverFetchedAt = cache?.fetchedAt
        }
        configuration = contentState.configuration.bearerToken == nil ? nil : contentState.configuration
        recipes = contentState.recipes
        local = CookingNowBoard.localEntries(progress: contentState.cookProgressByRecipeID, recipes: recipes)
        publish()
        // The Kitchen asks for the list when it appears, which can be before the saved sign-in is read; the list is
        // read again once the account and its token are known.
        if [scope, configuration?.bearerToken] != previousSignIn, scope != nil, configuration != nil {
            Task { await refresh() }
        }
    }

    /// Reads the server's list. Offline, signed out or on a server without the list, the saved list stays.
    func refresh() async {
        guard let scope, let configuration, !isFetching else {
            return
        }
        isFetching = true
        defer { isFetching = false }
        let fetched: [CookingNowEntry]
        do {
            fetched = try await LiveCookingNowRepository(configuration: configuration).fetchCookingNow()
        } catch {
#if DEBUG
            lastFetch = "failed: \(error)"
            publish()
#endif
            return
        }
        guard scope == self.scope else {
            return
        }
#if DEBUG
        lastFetch = "\(fetched.count) from the server"
#endif
        let fetchedAt = Date()
        server = fetched
        serverFetchedAt = fetchedAt
        cacheStore.save(CookingNowCache(scope: scope, fetchedAt: fetchedAt, entries: fetched))
        publish()
    }

    private func publish() {
        let merged = CookingNowBoard.board(server: server, serverFetchedAt: serverFetchedAt, local: local, recipes: recipes, now: Date())
        if merged != entries {
            entries = merged
        }
#if DEBUG
        let summary = "local \(local.count) server \(server.count) fetch \(lastFetch) shown \(merged.map(\.stepLabel))"
        if summary != journeySummary {
            journeySummary = summary
        }
#endif
    }
}

/// What the center listens to, so it recomputes only when progress, the recipe list or the account changes.
struct CookingNowInputs: Equatable {
    let progress: [String: CookModeProgress]
    let recipeIDs: [String]
    let accountID: String?
    let token: String?

    init(_ contentState: NativeShellContentState) {
        progress = contentState.cookProgressByRecipeID
        recipeIDs = contentState.recipes.map(\.id)
        accountID = contentState.spotlightIndexScope?.accountID
        token = contentState.configuration.bearerToken
    }
}

extension CookingNowEntry {
    /// "Step 2 of 5 · 3 of 9 checked", the line under the title.
    var progressLine: String {
        totalCount == 0 ? stepLabel : "\(stepLabel) · \(checkedCount) of \(totalCount) checked"
    }
}

// MARK: - Kitchen section

/// The Kitchen's "Cooking now": every recipe the chef is part-way through, newest first, each one tap from cook mode
/// on its saved step. On a phone the recipes are index rows like the rest of the page; on a wide page they are open
/// plates, photo over title, with no box around them.
struct CookingNowSection: View {
    let entries: [CookingNowEntry]
    let isWide: Bool
    let resume: (String) -> Void
    /// Its own namespace: a recipe on the stove is also in "Your recipes", and one cover can lead only one zoom.
    @Namespace private var transition

    var body: some View {
        KitchenTableSection(eyebrow: "On the stove", title: "Cooking now", meta: meta) {
            if isWide {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 24, alignment: .top)],
                    alignment: .leading,
                    spacing: 24
                ) {
                    ForEach(entries) { entry in
                        CookingNowPlate(entry: entry) {
                            resume(entry.recipeID)
                        }
                    }
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        if entry.id != entries.first?.id {
                            RecipeIndexRowSeparator()
                        }
                        RecipeIndexRow(
                            id: entry.recipeID,
                            title: entry.title,
                            detail: entry.progressLine,
                            coverURL: entry.coverURL,
                            namespace: transition
                        ) {
                            resume(entry.recipeID)
                        }
                        .opensNewWindowInCookMode()
                        .accessibilityHint("Goes back to cooking on this step")
                        .accessibilityIdentifier("kitchen.cookingNow.card")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kitchen.cookingNow")
    }

    /// Web's count: "1 recipe", "3 recipes".
    private var meta: String {
        entries.count == 1 ? "1 recipe" : "\(entries.count) recipes"
    }
}

/// One recipe on the stove, on a wide page: its photo (or the warm initial plate) above the step, the title and a
/// brass rule that fills as the steps go by.
struct CookingNowPlate: View {
    let entry: CookingNowEntry
    let resume: () -> Void

    var body: some View {
        Button(action: resume) {
            plate
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title), \(entry.progressLine)")
        .accessibilityHint("Goes back to cooking on this step")
        .accessibilityIdentifier("kitchen.cookingNow.card")
        .contextMenu {
            OpenInNewWindowButton(route: entry.route)
        } preview: {
            // The plate sits open on the page, so lifted on its own it needs the page under it; without it the text
            // floated over the dimmed Kitchen.
            plate
                .frame(width: 300)
                .padding(18)
                .background(KitchenTableTheme.page)
        }
    }

    private var plate: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The column sets the width and the photo fills it; a filled photo laid out directly widens the plate.
            Color.clear
                .aspectRatio(3 / 2, contentMode: .fit)
                .overlay {
                    if let coverURL = entry.coverURL {
                        RecipeCoverImage(url: coverURL, title: entry.title, subtitle: nil, showsFallbackLabel: false)
                            .scaledToFill()
                    } else {
                        RecipeInitialTile(title: entry.title)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.photo))
                .accessibilityHidden(true)
            Text(entry.stepLabel)
                .kitchenEyebrow()
            Text(entry.title)
                .font(KitchenTableTheme.indexTitle)
                .foregroundStyle(KitchenTableTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            CookingNowProgressRule(fraction: entry.fractionComplete)
            if entry.totalCount > 0 {
                Text("\(entry.checkedCount) of \(entry.totalCount) checked")
                    .font(KitchenTableTheme.meta)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
        }
    }
}

/// A hairline that fills with brass as the chef works through the steps.
struct CookingNowProgressRule: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(KitchenTableTheme.vellum)
                Capsule().fill(KitchenTableTheme.brass)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

// MARK: - Tab bar switcher

#if os(iOS)
/// The tab bar's accessory while something is cooking: the newest recipe on the stove, one tap from its step, and a
/// menu to switch to any other recipe on the go.
struct CookingNowAccessory: View {
    let entries: [CookingNowEntry]
    let resume: (String) -> Void
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let lead = CookingNowBoard.switcherLead(entries) {
            HStack(spacing: 10) {
                Button {
                    resume(lead.recipeID)
                } label: {
                    HStack(spacing: 10) {
                        Color.clear
                            .frame(width: 30, height: 30)
                            .overlay {
                                if let coverURL = lead.coverURL {
                                    RecipeCoverImage(url: coverURL, title: lead.title, subtitle: nil, showsFallbackLabel: false)
                                        .scaledToFill()
                                } else {
                                    RecipeInitialTile(title: lead.title)
                                }
                            }
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lead.title)
                                .font(KitchenTypeRole.objectTitle.font(relativeTo: .subheadline))
                                .foregroundStyle(KitchenTableTheme.ink)
                                .lineLimit(1)
                            if placement != .inline {
                                Text(lead.stepLabel)
                                    .font(KitchenTableTheme.uiLabel)
                                    .foregroundStyle(KitchenTableTheme.ink2)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cooking \(lead.title), \(lead.stepLabel)")
                .accessibilityHint("Goes back to cooking on this step")
                .accessibilityIdentifier("cookingNow.accessory.resume")

                if entries.count > 1 {
                    Menu {
                        ForEach(entries) { entry in
                            Button {
                                resume(entry.recipeID)
                            } label: {
                                Label("\(entry.title), \(entry.stepLabel)", systemImage: "fork.knife")
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KitchenTableTheme.brass)
                            .frame(width: KitchenTableTheme.minimumTouchTarget, height: 30)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Switch recipe")
                    .accessibilityIdentifier("cookingNow.accessory.switch")
                }
            }
            .padding(.horizontal, 14)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cookingNow.accessory")
        }
    }
}
#endif
