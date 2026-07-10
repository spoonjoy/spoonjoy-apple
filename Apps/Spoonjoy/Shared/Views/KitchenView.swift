import SpoonjoyCore
import Foundation
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
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
        KitchenTablePage(maxContentWidth: pageMaxContentWidth, bottomReserve: pageBottomReserve) {
            KitchenMasthead(kitchen: kitchen, ownerName: recipes.first?.chef.username)

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
        if usesWideKitchenSpread, let leadRecipe {
            HStack(alignment: .top, spacing: 28) {
                RecipeLead(recipe: leadRecipe, openRecipe: openRecipe, startCooking: startCooking)
                    .frame(maxWidth: 640, alignment: .topLeading)

                kitchenIndexStack
                    .frame(maxWidth: 408, alignment: .topLeading)
            }
        } else {
            VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
                if let leadRecipe {
                    RecipeLead(recipe: leadRecipe, openRecipe: openRecipe, startCooking: startCooking)
                }

                kitchenIndexStack
            }
        }
    }

    @ViewBuilder private var kitchenIndexStack: some View {
        VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
            if !indexedRecipes.isEmpty {
                RecipeIndex(recipes: indexedRecipes, openRecipe: openRecipe)
            }

            if !cookbooks.isEmpty {
                CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
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
        usesWideKitchenSpread ? 56 : KitchenTableTheme.compactDockReserve
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
        VStack(alignment: .leading, spacing: 10) {
            KitchenTableHeader(eyebrow: dayLabel, title: title, subtitle: countSummary)

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
        VStack(alignment: .leading, spacing: 14) {
            coverlessNoPhotoBadge
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

    private var coverlessNoPhotoBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.brass)
                .frame(width: 22, height: 22)
                .background(KitchenTableTheme.vellum.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("Photo not added")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
        }
        .accessibilityLabel("Photo not added")
    }

    private func leadText(foreground: Color, secondary: Color, label: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest from the kitchen".uppercased())
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
        leadButton(title: "Start Cooking", systemImage: "fork.knife", prominence: .primary) {
            startCooking(recipe.id)
        }
        leadButton(title: "Open Recipe", systemImage: "book", prominence: .secondary) {
            openRecipe(recipe.id)
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
                    ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                        KitchenRecipeIndexRow(recipe: recipe, ordinal: index + 1) {
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
    let ordinal: Int
    let open: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: open) {
                KitchenTableObjectRow(
                    title: recipe.title,
                    subtitle: rowSubtitle
                ) {
                    ZStack(alignment: .topLeading) {
                        RecipeCoverImage(
                            url: recipe.displayCoverImageURL,
                            title: recipe.title,
                            subtitle: "Photo not added"
                        )
                            .aspectRatio(1, contentMode: .fill)

                        Text(ordinalLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(KitchenTableTheme.bone)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(KitchenTableTheme.charcoal.opacity(0.72))
                    }
                } trailing: {
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.brass)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recipe.title)
            .accessibilityHint("Opens recipe detail")

            ShareLink(item: shareRecipe) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .frame(width: KitchenTableTheme.minimumTouchTarget, height: KitchenTableTheme.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share \(recipe.title)")
        }
    }

    private var ordinalLabel: String {
        String(format: "%02d", ordinal)
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
