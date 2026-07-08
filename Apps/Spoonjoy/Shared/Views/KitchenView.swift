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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KitchenMasthead(kitchen: kitchen)

                if let leadRecipe {
                    RecipeLead(recipe: leadRecipe, openRecipe: openRecipe, startCooking: startCooking)
                }

                RecipeIndex(recipes: recipes, openRecipe: openRecipe)
                CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
            }
            .padding()
        }
        .background(KitchenTableTheme.bone)
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

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                titleBlock
                Spacer()
                statusBadge
            }

            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                statusBadge
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spoonjoy Kitchen")
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text("Recipes \(kitchen.counts.recipes) - Cookbooks \(kitchen.counts.cookbooks) - Shopping \(kitchen.counts.shoppingItems)")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
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
}

struct RecipeLead: View {
    let recipe: Recipe
    let openRecipe: (String) -> Void
    let startCooking: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                RecipeCoverImage(url: recipe.coverImageURL)
                .frame(maxWidth: .infinity, minHeight: coverHeight, maxHeight: coverHeight)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                .overlay(KitchenTableTheme.photoOverlay)
                .accessibilityLabel("\(recipe.title) cover image")

                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title)
                        .font(KitchenTableTheme.displayTitle)
                        .foregroundStyle(.white)
                    Text(recipe.attribution.creditText)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding()
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    leadButton(title: "Open Recipe", systemImage: "book", prominent: true) {
                        openRecipe(recipe.id)
                    }
                    leadButton(title: "Start Cooking", systemImage: "fork.knife", prominent: false) {
                        startCooking(recipe.id)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    leadButton(title: "Open Recipe", systemImage: "book", prominent: true) {
                        openRecipe(recipe.id)
                    }
                    leadButton(title: "Start Cooking", systemImage: "fork.knife", prominent: false) {
                        startCooking(recipe.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func leadButton(title: String, systemImage: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        if prominent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Recipe Index")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

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
            HStack(alignment: .center, spacing: 12) {
                RecipeCoverImage(url: recipe.coverImageURL)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    Text(recipe.coverProvenanceLabel ?? recipe.chef.username)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KitchenTableTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
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
