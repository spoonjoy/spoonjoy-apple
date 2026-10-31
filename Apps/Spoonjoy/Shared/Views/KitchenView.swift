import SpoonjoyCore
import Foundation
import SwiftUI

struct KitchenView: View {
    let kitchen: KitchenFixtureState
    let recipes: [Recipe]
    let cookbooks: [Cookbook]
    /// The saved cook progress for a recipe, so the hero resumes the cook instead of restarting it.
    let cookProgress: (String) -> CookModeProgress?
    let openRecipe: (String) -> Void
    let startCooking: (String) -> Void
    let openCookbook: (String) -> Void
    let createRecipe: () -> Void
    let importRecipe: () -> Void
    let seeAllRecipes: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    /// The tab stack's cover-zoom namespace, so a tapped cover grows into its recipe; its own outside a tab stack.
    @Environment(\.recipeZoomNamespace) private var tabRecipeTransition
    @Namespace private var localRecipeTransition
    /// How far the page is pulled down past its top; the hero stretches by this much.
    @State private var heroPull: CGFloat = 0
    /// How far the page has scrolled; paper covers the status bar once the hero has gone under it.
    @State private var scrollOffset: CGFloat = 0
    @State private var heroHeight: CGFloat = 0
    /// The status bar, the bar buttons and any offline line above the page, which the photo runs under.
    @State private var chromeHeight: CGFloat = 0

    private var recipeTransition: Namespace.ID {
        tabRecipeTransition ?? localRecipeTransition
    }

    var body: some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("kitchen.root")
            .task {
                await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                    route: "kitchen",
                    source: "KitchenView",
                    runtimeContext: screenshotAccessibilityRuntimeContext
                )
            }
    }

    @ViewBuilder private var content: some View {
        if recipes.isEmpty && cookbooks.isEmpty {
            KitchenTablePage(maxContentWidth: pageMaxContentWidth, bottomReserve: pageBottomReserve) {
                KitchenMasthead(kitchen: kitchen, ownerName: recipes.first?.chef.username, chef: recipes.first?.chef)
                KitchenEmptyHero(createRecipe: createRecipe, importRecipe: importRecipe)
            }
        } else if let leadRecipe {
            heroPage(leadRecipe: leadRecipe)
        } else {
            // Only cookbooks: there is no dish to lead with, so the page opens on its masthead.
            KitchenTablePage(maxContentWidth: pageMaxContentWidth, bottomReserve: pageBottomReserve) {
                KitchenMasthead(kitchen: kitchen, ownerName: recipes.first?.chef.username, chef: recipes.first?.chef)
                kitchenIndexStack
            }
        }
    }

    /// The dish runs edge to edge under the status bar; the recipes sit on a sheet of paper over its foot.
    private func heroPage(leadRecipe: Recipe) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                RecipeLead(
                    recipe: leadRecipe,
                    counterCook: counterCook,
                    pull: heroPull,
                    chromeHeight: chromeHeight,
                    openRecipe: openRecipe,
                    startCooking: startCooking
                )
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    heroHeight = height
                }

                kitchenSheet
                    .padding(.top, -KitchenLeadMetrics.sheetOverlap)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollOffset = offset
            heroPull = CGFloat(KitchenHeroStretch.pull(contentOffsetY: Double(offset), topInset: 0))
        }
        .background(KitchenTableTheme.page.ignoresSafeArea())
#if os(iOS)
        .ignoresSafeArea(edges: .top)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.top
        } action: { inset in
            chromeHeight = inset
        }
        .scrollEdgeEffectHidden(!KitchenHeroStretch.showsTopEdgeEffect(scrollOffset: Double(scrollOffset)), for: .top)
        // A soft edge fades only a sliver at the top; at large text the dish's title would still sit under the buttons.
        .scrollEdgeEffectStyle(.hard, for: .top)
        // The dish is the title. The status bar follows what is under it, light over the photo and dark on paper,
        // and the bar's glass keeps its own glyph color; forcing a bar scheme left the glyphs white on the paper.
        .toolbar(removing: .title)
        // Over the photo the bar draws nothing of its own.
        .toolbarBackground(Color.clear, for: .navigationBar)
        .toolbarBackgroundVisibility(isHeroUnderBar ? .visible : .automatic, for: .navigationBar)
        .overlay(alignment: .top) {
            // Once the photo has scrolled away, paper covers the status bar so text never runs under the clock.
            Color.clear
                .frame(height: 0)
                .background(KitchenTableTheme.page.ignoresSafeArea(edges: .top))
                .opacity(scrollOffset > heroHeight - KitchenLeadMetrics.sheetOverlap ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
#else
        .scrollEdgeEffectStyle(.hard, for: .top)
#endif
    }

    private var isHeroUnderBar: Bool {
        scrollOffset < heroHeight - KitchenLeadMetrics.sheetOverlap - KitchenLeadMetrics.lightBarPhotoMargin
    }

    private var kitchenSheet: some View {
        Group {
            if usesWideKitchenSpread {
                HStack(alignment: .top, spacing: 28) {
                    recipeIndex
                        .frame(maxWidth: 640, alignment: .topLeading)
                    if !cookbooks.isEmpty {
                        CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
                            .frame(maxWidth: 408, alignment: .topLeading)
                    }
                }
            } else {
                kitchenIndexStack
            }
        }
        .padding(.horizontal, KitchenTableTheme.pagePadding)
        .padding(.top, 26)
        .padding(.bottom, pageBottomReserve)
        .frame(maxWidth: pageMaxContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            KitchenTableTheme.page,
            in: UnevenRoundedRectangle(
                topLeadingRadius: KitchenLeadMetrics.sheetRadius,
                topTrailingRadius: KitchenLeadMetrics.sheetRadius,
                style: .continuous
            )
        )
    }

    private var leadObject: KitchenLeadObject {
        kitchen.leadObject
    }

    /// The cook to resume, if one is unfinished; its recipe leads the page.
    private var counterCook: KitchenCounterCook? {
        KitchenCounterCook.resolve(recipeIDs: recipes.map(\.id), progress: cookProgress)
    }

    private var leadRecipe: Recipe? {
        if let counterCook, let cooking = recipes.first(where: { $0.id == counterCook.recipeID }) {
            return cooking
        }
        guard case .recipe(let id, _) = leadObject else {
            return nil
        }

        return recipes.first { $0.id == id }
    }

    @ViewBuilder private var kitchenIndexStack: some View {
        VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
            recipeIndex

            if !cookbooks.isEmpty {
                CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
            }
        }
    }

    @ViewBuilder private var recipeIndex: some View {
        if !indexedRecipes.isEmpty {
            RecipeIndex(
                recipes: indexedRecipes,
                summary: countSummary,
                namespace: recipeTransition,
                openRecipe: openRecipe,
                seeAll: seeAllRecipes
            )
        }
    }

    private var usesWideKitchenSpread: Bool {
#if os(iOS)
        horizontalSizeClass == .regular
#else
        true
#endif
    }

    private var indexedRecipes: [Recipe] {
        guard let leadRecipe else {
            return recipes
        }

        return recipes.filter { recipe in
            recipe.id != leadRecipe.id
        }
    }

    /// "9 recipes · 3 cookbooks", counting every saved recipe, the one leading the page included.
    private var countSummary: String {
        KitchenMasthead.countSummary(recipes: kitchen.counts.recipes, cookbooks: kitchen.counts.cookbooks)
    }

    private var pageMaxContentWidth: CGFloat {
        usesWideKitchenSpread ? 1120 : 720
    }

    private var pageBottomReserve: CGFloat {
        usesWideKitchenSpread ? 56 : KitchenTableTheme.compactDockReserve
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }
}

/// The first thing a new kitchen shows: an empty table with the two ways to put a recipe on it.
struct KitchenEmptyHero: View {
    let createRecipe: () -> Void
    let importRecipe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(KitchenTableTheme.brass)
                .accessibilityHidden(true)
            Text("The table is set")
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Bring in your first recipe with a link, Siri or Claude. Everything you cook lives here.")
                .font(KitchenTableTheme.instructionBody)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    createButton
                    importButton
                }
                VStack(spacing: 12) {
                    createButton
                    importButton
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(KitchenTableTheme.lineStrong).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kitchen.emptyHero")
    }

    private var createButton: some View {
        Button(action: createRecipe) {
            Label("Add a recipe", systemImage: "plus")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
        .accessibilityIdentifier("kitchen.emptyHero.create")
    }

    private var importButton: some View {
        Button(action: importRecipe) {
            Label("Import", systemImage: "tray.and.arrow.down")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        .accessibilityIdentifier("kitchen.emptyHero.import")
    }
}

struct KitchenMasthead: View {
    let kitchen: KitchenFixtureState
    let ownerName: String?
    var chef: ChefSummary? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let chef {
                KitchenIdentityLine(chef: chef)
            }

            KitchenTableHeader(eyebrow: dayLabel, title: title, subtitle: countSummary, hidesTitleInCompactNavigation: true)

            // "Ready" is the normal state, so it stays quiet; only the preparing state needs a badge.
            if kitchen.status != .ready {
                statusBadge
            }
        }
    }

    private var statusBadge: some View {
        Label(statusLabel, systemImage: statusSymbol)
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(statusColor)
    }

    private var statusLabel: String {
        switch kitchen.status {
        case .bootstrap:
            "Preparing"
        case .ready:
            "Ready"
        }
    }

    private var statusSymbol: String {
        switch kitchen.status {
        case .bootstrap:
            "hourglass"
        case .ready:
            "checkmark.seal"
        }
    }

    private var statusColor: Color {
        switch kitchen.status {
        case .bootstrap:
            KitchenTableTheme.brass
        case .ready:
            KitchenTableTheme.herb
        }
    }

    private var countSummary: String {
        Self.countSummary(recipes: kitchen.counts.recipes, cookbooks: kitchen.counts.cookbooks)
    }

    static func countSummary(recipes: Int, cookbooks: Int) -> String {
        [
            countLabel(recipes, singular: "recipe"),
            countLabel(cookbooks, singular: "cookbook")
        ].joined(separator: " · ")
    }

    private static func countLabel(_ count: Int, singular: String) -> String {
        let noun = count == 1 ? singular : "\(singular)s"
        return "\(count) \(noun)"
    }

    private var dayLabel: String {
        switch kitchen.status {
        case .bootstrap:
            "Setting the table"
        case .ready:
            "Kitchen table"
        }
    }

    private var title: String {
        guard let ownerName, !ownerName.isEmpty else {
            return "Spoonjoy kitchen"
        }
        return "\(ownerName)'s kitchen"
    }
}

/// Whose kitchen this is: the chef's avatar and handle, as the web's kitchen page leads with.
struct KitchenIdentityLine: View {
    let chef: ChefSummary

    var body: some View {
        HStack(spacing: 10) {
            avatar
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(KitchenTableTheme.hairline, lineWidth: 1))
                .accessibilityHidden(true)
            Text("@\(chef.username)")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chef \(chef.username)")
        .accessibilityIdentifier("kitchen.identity")
    }

    @ViewBuilder private var avatar: some View {
        if let url = chef.photoURL {
            CachedAsyncImage(url: url, animation: nil) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty, .failure:
                    initial
                }
            }
        } else {
            initial
        }
    }

    private var initial: some View {
        ZStack {
            KitchenTableTheme.vellum
            Text(String(chef.username.prefix(1)).uppercased())
                .font(.system(.subheadline, design: .serif).weight(.bold))
                .foregroundStyle(KitchenTableTheme.ink)
        }
    }
}

private enum KitchenLeadMetrics {
    /// How far the paper sheet rides up over the foot of the photo.
    static let sheetOverlap: CGFloat = 30
    static let sheetRadius: CGFloat = 28
    /// How much photo must still sit under the bar for its clock and buttons to stay light; past that the bar
    /// turns dark before the paper reaches it.
    static let lightBarPhotoMargin: CGFloat = 100
}

/// The dish on the counter: the photo edge to edge, its title in the serif, and the way back into the cook.
struct RecipeLead: View {
    let recipe: Recipe
    let counterCook: KitchenCounterCook?
    /// How far the page is pulled down past its top.
    let pull: CGFloat
    /// What sits over the top of the photo; the text starts below it, so a large text size never runs under it.
    var chromeHeight: CGFloat = 0
    let openRecipe: (String) -> Void
    let startCooking: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            leadText
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    leadButtons
                }
                .frame(maxWidth: 420)

                VStack(spacing: 10) {
                    leadButtons
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, max(120, chromeHeight + 16))
        .padding(.bottom, 24 + KitchenLeadMetrics.sheetOverlap)
        .frame(maxWidth: .infinity, minHeight: heroHeight, alignment: .bottomLeading)
        .background(alignment: .top) {
            heroPhoto
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(recipe.title)
        .accessibilityIdentifier("kitchen.recipe")
    }

    /// The photo, or a designed tile for a recipe without one, stretched from its top edge while the page is pulled.
    private var heroPhoto: some View {
        GeometryReader { proxy in
            let scale = KitchenHeroStretch.scale(
                pull: Double(pull),
                heroHeight: Double(proxy.size.height),
                reduceMotion: accessibilityReduceMotion
            )
            ZStack {
                if let coverURL = recipe.displayCoverImageURL {
                    RecipeCoverImage(url: coverURL, title: recipe.title, subtitle: nil, showsFallbackLabel: false)
                        .scaledToFill()
                } else {
                    KitchenTableTheme.photoCharcoal
                    RecipeInitialTile(title: recipe.title)
                        .opacity(0.5)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .overlay { scrim }
            .scaleEffect(scale, anchor: .top)
            // Pulled down, the page moves; the photo stays pinned to the top of the screen and grows instead.
            .offset(y: accessibilityReduceMotion ? 0 : -pull)
            .background(alignment: .top) {
                // Under Reduce Motion the photo moves down with the page; its dark ground fills the space above it.
                let fill = CGFloat(KitchenHeroStretch.stillPhotoFill(pull: Double(pull), reduceMotion: accessibilityReduceMotion))
                KitchenTableTheme.photoCharcoal
                    .frame(height: fill + 1)
                    .offset(y: -fill)
            }
        }
        .recipeZoomSource(id: recipe.id)
        .accessibilityHidden(true)
    }

    /// Darkens the top for the status bar and the foot for the title, as the web's hero does.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: KitchenTableTheme.photoCharcoal.opacity(0.32), location: 0),
                .init(color: KitchenTableTheme.photoCharcoal.opacity(0), location: 0.2),
                .init(color: KitchenTableTheme.photoCharcoal.opacity(0), location: 0.4),
                .init(color: KitchenTableTheme.photoCharcoal.opacity(0.84), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var leadText: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text((counterCook?.label ?? KitchenCounterCook.idleLabel).uppercased())
                .font(KitchenTableTheme.uiLabel)
                .tracking(1.6)
                .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(counterCook?.label ?? KitchenCounterCook.idleLabel)
            Text(recipe.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.onPhoto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let meta {
                Text(meta)
                    .font(KitchenTableTheme.meta)
                    .foregroundStyle(KitchenTableTheme.onPhotoMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
    }

    /// "23 min · Serves 4 · by maya"; the time is the timed steps added up, and is left out when none is timed.
    private var meta: String? {
        let parts = [
            RecipeCookTime.label(stepDurations: recipe.steps.map(\.duration)),
            recipe.servings.map { "Serves \($0)" },
            "by \(recipe.chef.username)"
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder private var leadButtons: some View {
        Button {
            startCooking(recipe.id)
        } label: {
            Label(counterCook == nil ? "Start cooking" : "Keep cooking", systemImage: "play.fill")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
        .accessibilityIdentifier("kitchen.recipe.cook")

        Button {
            openRecipe(recipe.id)
        } label: {
            Label("Recipe", systemImage: "book")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        .accessibilityIdentifier("kitchen.recipe.open")
    }

    /// Most of a phone's height, so the dish fills the top; shorter on the Mac, where the window is wide.
    private var heroHeight: CGFloat {
#if os(macOS)
        420
#else
        horizontalSizeClass == .regular ? 480 : 540
#endif
    }
}

/// "Your recipes": every saved recipe but the one on the counter, newest first.
struct RecipeIndex: View {
    let recipes: [Recipe]
    /// "9 recipes · 3 cookbooks", so the count agrees with the whole kitchen.
    let summary: String
    let namespace: Namespace.ID
    let openRecipe: (String) -> Void
    let seeAll: () -> Void

    var body: some View {
        KitchenTableSection(title: "Your recipes", subtitle: summary) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(recipes, id: \.id) { recipe in
                    if recipe.id != recipes.first?.id {
                        RecipeIndexRowSeparator()
                    }
                    RecipeIndexRow(recipe: recipe, namespace: namespace) {
                        openRecipe(recipe.id)
                    }
                    .accessibilityIdentifier("kitchen.recipe")
                }
            }
        } accessory: {
            Button("See all", action: seeAll)
                .font(KitchenTableTheme.control)
                .foregroundStyle(KitchenTableTheme.brass)
                .buttonStyle(.plain)
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .accessibilityIdentifier("kitchen.recipes.seeAll")
        }
    }
}

struct KitchenEmptySection: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(title)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.ink.opacity(0.72))
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(KitchenTableTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }
}
