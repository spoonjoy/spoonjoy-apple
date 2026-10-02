import SpoonjoyCore
import SwiftUI

/// On a wide screen, the shopping list sits beside the recipes its items came from, the way a cook writes the
/// list with the cookbook open beside it. Compact width and narrow windows show the list alone.
struct ShoppingWithRecipeSources<ListContent: View>: View {
    let sources: [ShoppingRecipeSource]
    let openRecipe: (String) -> Void
    @ViewBuilder let list: () -> ListContent

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    /// The narrowest container that shows the recipes pane beside the list.
    private static var minimumTwoPaneWidth: CGFloat { 740 }

    var body: some View {
        if isCompact {
            list()
        } else {
            GeometryReader { proxy in
                if proxy.size.width >= Self.minimumTwoPaneWidth {
                    HStack(spacing: 0) {
                        list()
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(KitchenTableTheme.spreadGutterRule)
                            .frame(width: 1)
                            .ignoresSafeArea(edges: .bottom)
                            .accessibilityHidden(true)
                        ShoppingRecipeSourcesPane(sources: sources, openRecipe: openRecipe)
                            .frame(width: min(360, proxy.size.width * 0.4))
                    }
                } else {
                    list()
                }
            }
        }
    }

    private var isCompact: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }
}

/// The recipes the shopping list's items came from, matched by ingredient name.
struct ShoppingRecipeSourcesPane: View {
    let sources: [ShoppingRecipeSource]
    let openRecipe: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("From the list")
                        .spreadRunningHead()
                    Text("For these recipes")
                        .font(KitchenTableTheme.sectionTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .accessibilityAddTraits(.isHeader)
                    Text("Recipes that call for what you are buying.")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if sources.isEmpty {
                    Text("Add a recipe's ingredients to the list and the recipe shows up here.")
                        .font(KitchenTableTheme.instructionBody)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sources) { source in
                            sourceRow(source)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KitchenTableTheme.bone.ignoresSafeArea())
        .accessibilityIdentifier("shopping.recipeSources")
    }

    private func sourceRow(_ source: ShoppingRecipeSource) -> some View {
        Button {
            openRecipe(source.id)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                RecipeCoverImage(url: source.coverImageURL, title: source.title, showsFallbackLabel: false)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.title)
                        .font(KitchenTableTheme.instructionBody.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(source.summary)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(source.remainingItemIDs.isEmpty ? KitchenTableTheme.herb : KitchenTableTheme.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(KitchenTableTheme.line.opacity(0.5))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.title), \(source.summary)")
        .accessibilityHint("Opens the recipe.")
    }
}
