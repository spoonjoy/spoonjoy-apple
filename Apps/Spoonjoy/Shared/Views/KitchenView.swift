import SpoonjoyCore
import Foundation
import SwiftUI

struct KitchenView: View {
    let kitchen: KitchenFixtureState
    let recipes: [Recipe]
    let cookbooks: [Cookbook]
    /// The signed-in chef, for the identity header; nil until the account is known.
    let chef: ChefSummary?
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
    /// What the chef is part-way through on every device; absent in previews and fixtures.
    @Environment(CookingNowCenter.self) private var cookingNow: CookingNowCenter?
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    /// The tab stack's cover-zoom namespace, so a tapped cover grows into its recipe; its own outside a tab stack.
    @Environment(\.recipeZoomNamespace) private var tabRecipeTransition
    @Namespace private var localRecipeTransition
    private var recipeTransition: Namespace.ID {
        tabRecipeTransition ?? localRecipeTransition
    }

    var body: some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("kitchen.root")
            .task {
                await cookingNow?.refresh()
            }
            .task {
                await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                    route: "kitchen",
                    source: "KitchenView",
                    runtimeContext: screenshotAccessibilityRuntimeContext
                )
            }
    }

    /// As web's kitchen: whose kitchen it is first, then the dish on the counter, then the recipes and the shelf.
    private var content: some View {
        KitchenTablePage(maxContentWidth: pageMaxContentWidth, bottomReserve: pageBottomReserve) {
            KitchenMasthead(kitchen: kitchen, chef: chef)
            if recipes.isEmpty && cookbooks.isEmpty {
                KitchenEmptyHero(createRecipe: createRecipe, importRecipe: importRecipe)
            } else {
                if let leadRecipe {
                    RecipeLead(
                        recipe: leadRecipe,
                        counterCook: counterCook,
                        openRecipe: openRecipe,
                        startCooking: startCooking
                    )
                }
                kitchenSections
            }
        }
#if os(iOS)
        // The page's own "My Kitchen" is the title; the bar keeps only its buttons.
        .toolbar(removing: .title)
#endif
    }

    @ViewBuilder private var kitchenSections: some View {
        if usesWideKitchenSpread {
            VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing + 8) {
                cookingNowSection
                HStack(alignment: .top, spacing: 28) {
                    recipeIndex
                        .frame(maxWidth: 640, alignment: .topLeading)
                    if !cookbooks.isEmpty {
                        CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
                            .frame(maxWidth: 408, alignment: .topLeading)
                    }
                }
            }
        } else {
            kitchenIndexStack
        }
    }

    private var leadObject: KitchenLeadObject {
        kitchen.leadObject
    }

    /// Where the page puts each recipe: the hero, Cooking now and the index (`KitchenPageLayout`, in SpoonjoyCore).
    private var layout: KitchenPageLayout {
        KitchenPageLayout(recipes: recipes, leadObject: leadObject, cookProgress: cookProgress, cookingNow: cookingNow?.entries ?? [])
    }

    /// The cook to resume, if one is unfinished; its recipe leads the page.
    private var counterCook: KitchenCounterCook? {
        layout.counterCook
    }

    private var leadRecipe: Recipe? {
        layout.leadRecipe
    }

    @ViewBuilder private var kitchenIndexStack: some View {
        VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
            cookingNowSection

            recipeIndex

            if !cookbooks.isEmpty {
                CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
            }
        }
    }

    /// The recipes on the stove, on this device and others, less the one the hero already leads with: the page never
    /// names the same cook twice.
    @ViewBuilder private var cookingNowSection: some View {
        let entries = layout.cookingNow
        if !entries.isEmpty {
            CookingNowSection(entries: entries, isWide: usesWideKitchenSpread, resume: startCooking)
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
        layout.indexedRecipes
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

/// Whose kitchen this is, as web's kitchen leads: the chef's photo and handle, "My Kitchen" at display size and a
/// serif count of what is in it.
struct KitchenMasthead: View {
    let kitchen: KitchenFixtureState
    var chef: ChefSummary? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let chef {
                KitchenIdentityLine(chef: chef)
            }

            Text(title)
                .font(KitchenTypeRole.displayTitle.font(scaledBy: 1.2))
                .foregroundStyle(KitchenTableTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(countSentence)
                .font(KitchenTableTheme.story)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            // "Ready" is the normal state, so it stays quiet; only the preparing state needs a badge.
            if kitchen.status != .ready {
                statusBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kitchen.masthead")
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

    /// "2 recipes and 2 cookbooks", as web's kitchen says it.
    private var countSentence: String {
        Self.countSentence(recipes: kitchen.counts.recipes, cookbooks: kitchen.counts.cookbooks)
    }

    static func countSentence(recipes: Int, cookbooks: Int) -> String {
        "\(countLabel(recipes, singular: "recipe")) and \(countLabel(cookbooks, singular: "cookbook"))"
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

    private var title: String {
        switch kitchen.status {
        case .bootstrap:
            "Setting the table"
        case .ready:
            "My Kitchen"
        }
    }
}

/// Whose kitchen this is: the chef's photo and brass handle, as the web's kitchen page leads with.
struct KitchenIdentityLine: View {
    let chef: ChefSummary

    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            avatar
                .frame(width: avatarSide, height: avatarSide)
                .clipShape(RoundedRectangle(cornerRadius: KitchenIdentityMetrics.avatarRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KitchenIdentityMetrics.avatarRadius, style: .continuous)
                        .strokeBorder(KitchenTableTheme.hairline, lineWidth: 1)
                )
                .accessibilityHidden(true)
            Text(ChefHandle.breakingAnywhere(chef.username))
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chef \(chef.username)")
        .accessibilityIdentifier("kitchen.identity")
    }

    private var avatarSide: CGFloat {
        min(avatarSize, 96)
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
                // Sized to the photo square, which stops growing at 96 pt, so the letter never outgrows it.
                .font(KitchenTypeRole.recipeTitle.fixedFont(size: Double(avatarSide) * 0.45))
                .foregroundStyle(KitchenTableTheme.ink)
        }
    }
}

private enum KitchenIdentityMetrics {
    /// Web's rounded-square chef photo.
    static let avatarRadius: CGFloat = 18
}

private enum KitchenLeadMetrics {
    /// The counter card's corners, as the page's other rounded media.
    static let cardRadius: CGFloat = 24
}

/// The dish on the counter: a card under the kitchen's header with the photo, or the recipe's initial tile, its
/// title in the serif and the way back into the cook.
struct RecipeLead: View {
    let recipe: Recipe
    let counterCook: KitchenCounterCook?
    let openRecipe: (String) -> Void
    let startCooking: (String) -> Void

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            leadText
            // The cap goes on the whole choice: on the row alone it hid the row's overflow from ViewThatFits, so at
            // accessibility sizes the row won and both labels truncated.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    leadButtons
                }

                VStack(spacing: 10) {
                    leadButtons
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 120)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, minHeight: heroHeight, alignment: .bottomLeading)
        .background {
            heroPhoto
        }
        .clipShape(RoundedRectangle(cornerRadius: KitchenLeadMetrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(recipe.title)
        .accessibilityIdentifier("kitchen.recipe")
    }

    /// The photo, or a designed tile for a recipe without one, filling the card and clipped to it, so the scrim and
    /// the zoom start from the card's own shape.
    private var heroPhoto: some View {
        Color.clear
            .overlay {
                if let coverURL = recipe.displayCoverImageURL {
                    RecipeCoverImage(url: coverURL, title: recipe.title, subtitle: nil, showsFallbackLabel: false)
                        .scaledToFill()
                } else {
                    ZStack {
                        KitchenTableTheme.photoCharcoal
                        RecipeInitialTile(title: recipe.title)
                            .opacity(0.5)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: KitchenLeadMetrics.cardRadius, style: .continuous))
            .overlay { scrim }
            .allowsHitTesting(false)
        .recipeZoomSource(id: recipe.id)
        .accessibilityHidden(true)
    }

    /// Darkens the foot for the title, as the web's hero does.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: KitchenTableTheme.photoCharcoal.opacity(0), location: 0),
                .init(color: KitchenTableTheme.photoCharcoal.opacity(0), location: 0.3),
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
                .kitchenEyebrowTracking()
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
                    // The handle's break points are for layout; VoiceOver reads the plain text.
                    .accessibilityLabel(meta.replacingOccurrences(of: "\u{200B}", with: ""))
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
    }

    /// "23 min · Serves 4 · by maya"; the time is the timed steps added up, and is left out when none is timed.
    private var meta: String? {
        let parts = [
            RecipeCookTime.label(stepDurations: recipe.steps.map(\.duration)),
            RecipeServingsLabel.label(recipe.servings),
            "by \(ChefHandle.wrapping(recipe.chef.username))"
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

    /// Tall enough for the dish to read under the header; shorter on the Mac, where the window is wide.
    private var heroHeight: CGFloat {
#if os(macOS)
        360
#else
        horizontalSizeClass == .regular ? 400 : 440
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
        KitchenTableSection(title: "Your recipes", meta: summary) {
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
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous))
    }
}
