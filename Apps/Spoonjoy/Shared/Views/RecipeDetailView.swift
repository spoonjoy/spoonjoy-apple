import SpoonjoyCore
import SwiftUI

struct RecipeDetailView: View {
    let viewModel: RecipeDetailViewModel
    let startCooking: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                cookbookSpread
                ingredientReceipt
                method
            }
            .padding()
        }
        .background(KitchenTableTheme.bone)
    }

    private var recipe: Recipe {
        viewModel.recipe
    }

    private var provenance: String {
        recipe.coverProvenanceLabel ?? recipe.attribution.creditText
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecipeCoverImage(url: recipe.coverImageURL)
            .frame(maxWidth: .infinity, minHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            .overlay(alignment: .bottomLeading) {
                Text(provenance)
                    .font(KitchenTableTheme.uiLabel)
                    .padding(8)
                    .background(KitchenTableTheme.photoOverlay)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("\(recipe.title) cover image")

            Text(recipe.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(recipe.description ?? recipe.attribution.creditText)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.secondary)

            HStack {
                Button("Start Cooking") { startCooking(recipe.id) }
                    .buttonStyle(.borderedProminent)
                ShareLink(item: recipe.canonicalURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var ingredientReceipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredient Receipt")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(recipe.steps.flatMap(\.ingredients), id: \.id) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Text(quantityText(for: ingredient))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var cookbookSpread: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cookbook Spread")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(recipe.cookbooks, id: \.id) { cookbook in
                HStack {
                    Label(cookbook.title, systemImage: "book.closed")
                    Spacer()
                    Text(cookbook.canonicalURL.host() ?? "spoonjoy.app")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.brass)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method")
                .font(.title2)
            ForEach(viewModel.methodSections, id: \.step.id) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(section.stepNumber). \(section.step.stepTitle ?? "Step")")
                        .font(.headline)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                    Text(section.step.description)
                        .font(KitchenTableTheme.bodyNote)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func quantityText(for ingredient: RecipeIngredient) -> String {
        let quantity = ingredient.quantity.formatted(.number.precision(.fractionLength(0...2)))
        return [quantity, ingredient.unit].compactMap { $0 }.joined(separator: " ")
    }
}
