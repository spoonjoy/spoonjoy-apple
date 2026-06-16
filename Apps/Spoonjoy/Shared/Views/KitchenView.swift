import SpoonjoyCore
import SwiftUI

struct KitchenView: View {
    let kitchen: KitchenFixtureState
    let recipes: [Recipe]
    let cookbooks: [Cookbook]
    let openRecipe: (String) -> Void
    let startCooking: (String) -> Void
    let openCookbook: (String) -> Void

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
}

struct KitchenMasthead: View {
    let kitchen: KitchenFixtureState

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spoonjoy Kitchen")
                    .font(KitchenTableTheme.displayTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text("Recipes \(kitchen.counts.recipes) - Cookbooks \(kitchen.counts.cookbooks) - Shopping \(kitchen.counts.shoppingItems)")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }
            Spacer()
            Label(kitchen.status.rawValue.capitalized, systemImage: "checkmark.seal")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
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
                AsyncImage(url: recipe.coverImageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(KitchenTableTheme.brass.opacity(0.18))
                }
                .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                .overlay(KitchenTableTheme.photoOverlay)

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

            HStack {
                Button("Open Recipe") { openRecipe(recipe.id) }
                    .buttonStyle(.borderedProminent)
                Button("Start Cooking") { startCooking(recipe.id) }
                    .buttonStyle(.bordered)
                NavigationLink("Recipe Page", value: AppRoute.recipeDetail(id: recipe.id, presentation: .detail))
            }
        }
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

            List(recipes, id: \.id) { recipe in
                Button {
                    openRecipe(recipe.id)
                } label: {
                    HStack {
                        AsyncImage(url: recipe.coverImageURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(KitchenTableTheme.brass.opacity(0.12))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))

                        VStack(alignment: .leading) {
                            Text(recipe.title)
                                .foregroundStyle(KitchenTableTheme.charcoal)
                            Text(recipe.coverProvenanceLabel ?? recipe.chef.username)
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 160)
        }
    }
}
