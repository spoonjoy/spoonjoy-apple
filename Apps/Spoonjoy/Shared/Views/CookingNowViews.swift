import Foundation
import Observation
import SpoonjoyCore
import SwiftUI

/// Keeps the "Cooking now" list for one window: this device's cook progress, merged with the server's list of what
/// the chef is cooking on every device, and the last server list kept on disk for offline use.
@MainActor
@Observable
final class CookingNowCenter {
    private(set) var entries: [CookingNowEntry] = []
#if DEBUG
    /// Journey runs only: what the list was built from, so a journey that finds no card can say why.
    private(set) var journeySummary = "not updated"
    @ObservationIgnored private var progressSummary = ""
    @ObservationIgnored private var lastFetch = "not fetched"
    @ObservationIgnored private var lastRecorded = "nothing recorded"
    @ObservationIgnored private let instance = String(UUID().uuidString.prefix(4))
    @ObservationIgnored private var signIn = ""

    func noteRecorded(_ progress: CookModeProgress, stored: Int) {
        lastRecorded = "recorded step \(progress.activeStepIndex) at \(progress.updatedAt), store holds \(stored)"
        publish()
    }
#endif

    @ObservationIgnored private var server: [CookingNowEntry] = []
    @ObservationIgnored private var serverFetchedAt: Date?
    @ObservationIgnored private var scope: String?
    @ObservationIgnored private var local: [CookingNowEntry] = []
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
        local = CookingNowBoard.localEntries(progress: contentState.cookProgressByRecipeID, recipes: contentState.recipes)
#if DEBUG
        let recipeIDs = Set(contentState.recipes.map(\.id))
        progressSummary = contentState.cookProgressByRecipeID.values.map { progress in
            "\(recipeIDs.contains(progress.recipeID) ? "known" : "unknown") step \(progress.activeStepIndex) at \(progress.updatedAt)"
        }.sorted().joined(separator: "; ")
        signIn = "\(nextScope == nil ? "no account" : "account") \(configuration == nil ? "no token" : "token")"
#endif
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
        let merged = CookingNowBoard.merge(server: server, serverFetchedAt: serverFetchedAt, local: local, now: Date())
        if merged != entries {
            entries = merged
        }
#if DEBUG
#if os(iOS)
        let scenes = UIApplication.shared.connectedScenes.count
#else
        let scenes = 1
#endif
        let summary = "center \(instance) of \(scenes) scene(s), \(signIn); \(lastRecorded); progress [\(progressSummary)] local \(local.count) server \(server.count) fetch \(lastFetch) shown \(merged.count)"
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
    let hasToken: Bool

    init(_ contentState: NativeShellContentState) {
        progress = contentState.cookProgressByRecipeID
        recipeIDs = contentState.recipes.map(\.id)
        accountID = contentState.spotlightIndexScope?.accountID
        hasToken = contentState.configuration.bearerToken != nil
    }
}

// MARK: - Kitchen strip

/// The Kitchen's "Cooking now" strip: a card for each recipe the chef is part-way through, newest first. Each card
/// goes straight back into cook mode on the saved step.
struct CookingNowStrip: View {
    let entries: [CookingNowEntry]
    let resume: (String) -> Void
    /// A wide page shows the cards as a row of index cards; a phone page scrolls them sideways.
    let isWide: Bool

    var body: some View {
        KitchenTableSection(title: "Cooking now", subtitle: subtitle) {
            if isWide {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                    cards
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        cards
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kitchen.cookingNow")
    }

    private var cards: some View {
        ForEach(entries) { entry in
            CookingNowCard(entry: entry, isWide: isWide) {
                resume(entry.recipeID)
            }
        }
    }

    private var subtitle: String {
        entries.count == 1 ? "Pick up where you left off" : "\(entries.count) recipes on the go"
    }
}

struct CookingNowCard: View {
    let entry: CookingNowEntry
    let isWide: Bool
    let resume: () -> Void

    var body: some View {
        Button(action: resume) {
            HStack(alignment: .center, spacing: 12) {
                RecipeCoverImage(url: entry.coverURL, title: entry.title, subtitle: nil, showsFallbackLabel: false)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title)
                        .font(KitchenTableTheme.indexTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(entry.stepLabel.uppercased())
                            .font(KitchenTableTheme.runningHead)
                            .tracking(1)
                            .foregroundStyle(KitchenTableTheme.brass)
                        if let timer = entry.nextTimer(now: Date()) {
                            Text(timerInterval: Date()...max(Date(), timer.endsAt), countsDown: true)
                                .font(KitchenTableTheme.uiLabel.monospacedDigit())
                                .foregroundStyle(KitchenTableTheme.tomato)
                        }
                    }
                    CookingNowProgressRule(fraction: entry.fractionComplete)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "fork.knife")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(width: isWide ? nil : 300, alignment: .leading)
            .frame(minHeight: 88)
            .background(KitchenTableTheme.paper)
            .overlay(alignment: .top) {
                Rectangle().fill(KitchenTableTheme.brass.opacity(0.35)).frame(height: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .stroke(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .contentShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title), \(entry.stepLabel)")
        .accessibilityHint("Goes back to cooking on this step")
        .accessibilityIdentifier("kitchen.cookingNow.card")
        .openInNewWindowMenu(entry.route)
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
/// The tab bar's accessory while something is cooking: the newest recipe in progress, one tap from its step, and a
/// menu to switch to any other recipe on the go.
struct CookingNowAccessory: View {
    let entries: [CookingNowEntry]
    let resume: (String) -> Void
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let lead = entries.first {
            HStack(spacing: 10) {
                Button {
                    resume(lead.recipeID)
                } label: {
                    HStack(spacing: 10) {
                        RecipeCoverImage(url: lead.coverURL, title: lead.title, subtitle: nil, showsFallbackLabel: false)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lead.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KitchenTableTheme.charcoal)
                                .lineLimit(1)
                            if placement != .inline {
                                Text(lead.stepLabel)
                                    .font(.caption)
                                    .foregroundStyle(KitchenTableTheme.inkMuted)
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
