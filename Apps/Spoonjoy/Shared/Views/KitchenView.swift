import SpoonjoyCore
import SwiftUI

struct KitchenView: View {
    let kitchen: KitchenFixtureState
    let recipes: [Recipe]
    let cookbooks: [Cookbook]
    let openRecipe: (String) -> Void
    let startCooking: (String) -> Void
    let openCookbook: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        KitchenTablePage {
            KitchenMasthead(kitchen: kitchen, ownerName: recipes.first?.chef.username)

            if let leadRecipe {
                RecipeLead(recipe: leadRecipe, openRecipe: openRecipe, startCooking: startCooking)
            }

            RecipeIndex(recipes: recipes, openRecipe: openRecipe)
            CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
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

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }
}

struct KitchenMasthead: View {
    let kitchen: KitchenFixtureState
    let ownerName: String?

    var body: some View {
        KitchenTableHeader(
            eyebrow: dayLabel,
            title: title,
            subtitle: "Recipes \(kitchen.counts.recipes) - Cookbooks \(kitchen.counts.cookbooks) - Market \(kitchen.counts.shoppingItems)"
        ) {
            statusBadge
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

    private var dayLabel: String {
        switch kitchen.status {
        case .bootstrap:
            "Setting the table"
        case .ready:
            "Kitchen"
        }
    }

    private var title: String {
        guard let ownerName, !ownerName.isEmpty else {
            return "Spoonjoy kitchen"
        }
        return "\(ownerName.capitalized)'s kitchen"
    }
}

struct RecipeLead: View {
    let recipe: Recipe
    let openRecipe: (String) -> Void
    let startCooking: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasRealCover {
                photoLead
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
        recipe.displayCoverImageURL != nil || coverAssetName != nil
    }

    private var coverAssetName: String? {
        RecipeCoverImage.bundledAssetName(forRecipeID: recipe.id)
    }

    private var photoLead: some View {
        ZStack(alignment: .bottomLeading) {
            RecipeCoverImage(
                url: recipe.displayCoverImageURL,
                title: recipe.title,
                subtitle: "Cover",
                assetName: coverAssetName,
                showsFallbackLabel: false
            )
                .frame(maxWidth: .infinity, minHeight: coverHeight, maxHeight: coverHeight)
                .clipped()
                .overlay {
                    KitchenTableTheme.photoOverlay
                }
                .accessibilityLabel("\(recipe.title) cover image")

            leadText(foreground: .white, secondary: .white.opacity(0.82), label: .white.opacity(0.72))
                .padding()
        }
    }

    private var coverlessLead: some View {
        VStack(alignment: .leading, spacing: 10) {
            leadText(foreground: KitchenTableTheme.charcoal, secondary: KitchenTableTheme.inkMuted, label: KitchenTableTheme.brass)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .bottomLeading)
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
            Text("From your kitchen".uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(label)
            Text(recipe.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(foreground)
                .lineLimit(4)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
            Text(recipe.attribution.creditText)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder private var leadButtons: some View {
        leadButton(title: "Open Recipe", systemImage: "book", prominence: .primary) {
            openRecipe(recipe.id)
        }
        leadButton(title: "Start Cooking", systemImage: "fork.knife", prominence: .secondary) {
            startCooking(recipe.id)
        }
    }

    @ViewBuilder
    private func leadButton(
        title: String,
        systemImage: String,
        prominence: KitchenTableActionButtonStyle.Prominence,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: prominence))
    }

    private var coverHeight: CGFloat {
#if os(macOS)
        220
#else
        260
#endif
    }
}

struct RecipeIndex: View {
    let recipes: [Recipe]
    let openRecipe: (String) -> Void

    var body: some View {
        KitchenTableSection(title: "Recipe Index", subtitle: "\(recipes.count) saved \(recipes.count == 1 ? "recipe" : "recipes")") {
            if recipes.isEmpty {
                KitchenEmptySection(
                    title: "No recipes saved yet",
                    systemImage: "book.closed",
                    tint: KitchenTableTheme.brass
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(recipes, id: \.id) { recipe in
                        KitchenRecipeIndexRow(recipe: recipe) {
                            openRecipe(recipe.id)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }
}

struct KitchenRecipeIndexRow: View {
    let recipe: Recipe
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            KitchenTableObjectRow(
                title: recipe.title,
                subtitle: recipe.displayCoverProvenanceLabel ?? recipe.chef.username
            ) {
                RecipeCoverImage(
                    url: recipe.displayCoverImageURL,
                    title: recipe.title,
                    subtitle: recipe.displayCoverProvenanceLabel,
                    assetName: RecipeCoverImage.bundledAssetName(forRecipeID: recipe.id)
                )
                    .aspectRatio(1, contentMode: .fill)
            } trailing: {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipe.title)
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
