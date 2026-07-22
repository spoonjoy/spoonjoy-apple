import SpoonjoyCore
import Foundation
import SwiftUI

struct KitchenView: View {
    let kitchen: KitchenFixtureState
    let recipes: [Recipe]
    let cookbooks: [Cookbook]
    let ownerUsername: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
        KitchenTablePage(maxContentWidth: pageMaxContentWidth, bottomReserve: pageBottomReserve) {
            KitchenMasthead(kitchen: kitchen, ownerUsername: ownerUsername)

            kitchenContent
        }
        .task {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "kitchen",
                source: "KitchenView",
                runtimeContext: screenshotAccessibilityRuntimeContext
            )
        }
    }

    private var leadObject: KitchenLeadObject {
        kitchen.leadObject
    }

    private var leadRecipe: Recipe? {
        guard case .recipe(let id, _) = leadObject else {
            return nil
        }

        return recipes.first { $0.id == id }
    }

    @ViewBuilder private var kitchenContent: some View {
        if let leadRecipe {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 28) {
                    RecipeLead(recipe: leadRecipe)
                        .frame(width: 540, alignment: .topLeading)

                    kitchenIndexStack
                        .frame(width: 360, alignment: .topLeading)
                }
                .frame(minWidth: 928, alignment: .leading)

                VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
                    RecipeLead(recipe: leadRecipe)
                    kitchenIndexStack
                }
            }
        } else {
            kitchenIndexStack
        }
    }

    @ViewBuilder private var kitchenIndexStack: some View {
        VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
            if !indexedRecipes.isEmpty {
                RecipeIndex(recipes: indexedRecipes)
            }

            if !cookbooks.isEmpty {
                CookbookShelf(cookbooks: cookbooks)
            }
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

    private var pageMaxContentWidth: CGFloat {
        usesWideKitchenSpread ? 1120 : 720
    }

    private var pageBottomReserve: CGFloat {
        usesWideKitchenSpread ? 56 : KitchenTableTheme.pageBottomSpacing
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }
}

struct KitchenMasthead: View {
    let kitchen: KitchenFixtureState
    let ownerUsername: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KitchenTableHeader(eyebrow: identityLabel, title: "My Kitchen", subtitle: countSummary)

            if case .bootstrap = kitchen.status {
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
        "Preparing"
    }

    private var statusSymbol: String {
        "hourglass"
    }

    private var statusColor: Color {
        KitchenTableTheme.brass
    }

    private var countSummary: String {
        [
            countLabel(kitchen.counts.recipes, singular: "recipe"),
            countLabel(kitchen.counts.cookbooks, singular: "cookbook")
        ].joined(separator: " and ")
    }

    private func countLabel(_ count: Int, singular: String) -> String {
        let noun = count == 1 ? singular : "\(singular)s"
        return "\(count) \(noun)"
    }

    private var identityLabel: String {
        guard let ownerUsername, !ownerUsername.isEmpty else {
            return "Kitchen"
        }
        return "@\(ownerUsername)"
    }
}

struct RecipeLead: View {
    let recipe: Recipe

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasRealCover {
                if dynamicTypeSize.isAccessibilitySize {
                    accessiblePhotoLead
                } else {
                    photoLead
                }
            } else {
                coverlessLead
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    leadButtons
                }

                VStack(spacing: 10) {
                    leadButtons
                }
            }
        }
    }

    private var hasRealCover: Bool {
        recipe.displayCoverImageURL != nil
    }

    private var photoLead: some View {
        ZStack(alignment: .bottomLeading) {
            RecipeCoverImage(
                url: recipe.displayCoverImageURL,
                title: recipe.title,
                subtitle: "Cover",
                showsFallbackLabel: false
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityLabel("\(recipe.title) cover image")

            leadText(foreground: .white, secondary: .white, label: .white)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KitchenTableTheme.photoCharcoal)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var accessiblePhotoLead: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeCoverImage(
                url: recipe.displayCoverImageURL,
                title: recipe.title,
                subtitle: "Cover",
                showsFallbackLabel: false
            )
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            .clipped()
            .accessibilityLabel("\(recipe.title) cover image")

            leadText(
                foreground: KitchenTableTheme.charcoal,
                secondary: KitchenTableTheme.charcoal,
                label: KitchenTableTheme.charcoal
            )
            .padding(18)
        }
        .background(KitchenTableTheme.paper)
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .stroke(KitchenTableTheme.lineStrong, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var coverlessLead: some View {
        VStack(alignment: .leading, spacing: 14) {
            leadText(foreground: KitchenTableTheme.charcoal, secondary: KitchenTableTheme.inkMuted, label: KitchenTableTheme.brass)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(KitchenTableTheme.brass.opacity(0.22))
                .frame(height: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .stroke(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private func leadText(foreground: Color, secondary: Color, label: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest from the kitchen".uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(label)
            Text(recipe.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(foreground)
            Text("by @\(recipe.chef.username)")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(secondary)
        }
    }

    @ViewBuilder private var leadButtons: some View {
        leadLink(
            title: "Start Cooking",
            systemImage: "fork.knife",
            prominence: .primary,
            route: .recipeDetail(id: recipe.id, presentation: .cook)
        )
        leadLink(
            title: "Open Recipe",
            systemImage: "book",
            prominence: .secondary,
            route: .recipeDetail(id: recipe.id, presentation: .detail)
        )
    }

    @ViewBuilder
    private func leadLink(
        title: String,
        systemImage: String,
        prominence: KitchenTableActionButtonStyle.Prominence,
        route: AppRoute
    ) -> some View {
        NavigationLink(value: route) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: prominence))
    }
}

struct RecipeIndex: View {
    let recipes: [Recipe]

    var body: some View {
        KitchenTableSection(
            title: "Recipe Index",
            subtitle: "\(recipes.count) saved \(recipes.count == 1 ? "recipe" : "recipes")",
            accessibilitySubtitleIdentifier: "kitchen.recipe-index.count"
        ) {
            if recipes.isEmpty {
                KitchenEmptySection(
                    title: "No recipes saved yet",
                    systemImage: "book.closed",
                    tint: KitchenTableTheme.brass
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(recipes, id: \.id) { recipe in
                        KitchenRecipeIndexRow(recipe: recipe)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }
}

struct KitchenRecipeIndexRow: View {
    let recipe: Recipe

    var body: some View {
        NavigationLink(value: recipeRoute) {
            KitchenTableObjectRow(
                title: recipe.title,
                subtitle: rowSubtitle,
                showsLeading: recipe.displayCoverImageURL != nil
            ) {
                RecipeCoverImage(
                    url: recipe.displayCoverImageURL,
                    title: recipe.title,
                    subtitle: "Photo not added"
                )
                .aspectRatio(1, contentMode: .fill)
            } trailing: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipe.title)
        .accessibilityHint("Opens recipe detail")
        .contextMenu {
            ShareLink(item: shareRecipe) {
                Label("Share \(recipe.title)", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var recipeRoute: AppRoute {
        .recipeDetail(id: recipe.id, presentation: .detail)
    }

    private var rowSubtitle: String {
        [
            recipe.description,
            recipe.displayCoverProvenanceLabel,
            recipe.servings.map { "Serves \($0)" }
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " - ")
    }

    private var shareRecipe: URL {
        recipe.attribution.canonicalURL
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
                .foregroundStyle(KitchenTableTheme.charcoal.opacity(0.72))
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(KitchenTableTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }
}
