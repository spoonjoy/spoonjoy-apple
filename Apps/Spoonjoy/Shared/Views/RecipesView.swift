import SpoonjoyCore
import SwiftUI

struct RecipesView: View {
    let recipes: [Recipe]
    let openRecipe: (String) -> Void

    var body: some View {
        List(recipeSummaries, id: \.id) { recipe in
            Button {
                openRecipe(recipe.id)
            } label: {
                RecipeIndexRow(recipe: recipe)
            }
            .buttonStyle(.plain)
        }
        .background(KitchenTableTheme.bone)
    }

    private var recipeSummaries: [RecipeSummary] {
        recipes.map(RecipeSummary.init(recipe:))
    }
}

private struct RecipeIndexRow: View {
    let recipe: RecipeSummary

    init(recipe: RecipeSummary) {
        self.recipe = recipe
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: recipe.coverImageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(KitchenTableTheme.brass.opacity(0.12))
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text(recipe.attribution.creditText)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
