import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe and cookbook domain")
struct RecipeCookbookTests {
    @Test("recipe fixture decodes API v1 recipe detail shape")
    func recipeFixtureDecodesDetailShape() throws {
        let catalog = try RecipeFixtureCatalog.decodeFromBundle()

        #expect(catalog.recipes.count == 2)

        let recipe = try #require(catalog.recipe(id: "recipe_lemon_pantry_pasta"))
        #expect(recipe.id == "recipe_lemon_pantry_pasta")
        #expect(recipe.title == "Lemon Pantry Pasta")
        #expect(recipe.description == "Bright pantry pasta with lemon, garlic, and parmesan.")
        #expect(recipe.servings == "4")
        #expect(recipe.chef == ChefSummary(id: "chef_ari", username: "ari"))
        #expect(recipe.coverImageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))
        #expect(recipe.coverProvenanceLabel == "Chef photo")
        #expect(recipe.coverSourceType == RecipeCoverSourceType.chefUpload)
        #expect(recipe.coverVariant == RecipeCoverVariant.image)
        #expect(recipe.href == "/recipes/recipe_lemon_pantry_pasta")
        #expect(recipe.canonicalURL == URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta"))
        #expect(recipe.attribution.creditText == "Lemon Pantry Pasta by ari on Spoonjoy")
        #expect(recipe.attribution.sourceURL == URL(string: "https://example.com/lemon-pantry-pasta"))
        #expect(recipe.attribution.sourceHost == "example.com")
        #expect(recipe.attribution.sourceRecipe == nil)
    }

    @Test("recipe steps and ingredients preserve display-safe API data")
    func recipeStepsAndIngredientsPreserveDisplayData() throws {
        let catalog = try RecipeFixtureCatalog.decodeFromBundle()
        let recipe = try #require(catalog.recipe(id: "recipe_lemon_pantry_pasta"))

        #expect(recipe.steps.map(\.stepNum) == [1, 2, 3])
        #expect(recipe.steps.map(\.stepTitle) == ["Boil Pasta", "Build Sauce", "Finish"])

        let firstStep = try #require(recipe.steps.first)
        #expect(firstStep.description == "Boil the pasta until just shy of al dente.")
        #expect(firstStep.duration == 10)
        #expect(firstStep.ingredients.map(\.name) == ["kosher salt", "spaghetti"])
        #expect(firstStep.ingredients.map(\.quantity) == [1, 12])
        #expect(firstStep.ingredients.map(\.unit) == ["tbsp", "oz"])

        let sauceStep = try #require(recipe.steps[safe: 1])
        #expect(sauceStep.ingredients.map(\.name) == ["garlic", "lemon", "olive oil"])
        #expect(sauceStep.ingredients.map(\.unit) == ["clove", "each", "tbsp"])
    }

    @Test("recipe validation rejects malformed public payloads")
    func recipeValidationRejectsMalformedPayloads() {
        let invalidData = Data(
            #"""
            {
              "recipes": [
                {
                  "id": "recipe_invalid_title",
                  "title": "",
                  "description": null,
                  "servings": "2",
                  "chef": { "id": "chef_ari", "username": "ari" },
                  "coverImageUrl": null,
                  "coverProvenanceLabel": null,
                  "coverSourceType": null,
                  "coverVariant": null,
                  "href": "/recipes/recipe_invalid_title",
                  "canonicalUrl": "https://spoonjoy.app/recipes/recipe_invalid_title",
                  "attribution": {
                    "creditText": "Broken by ari on Spoonjoy",
                    "canonicalUrl": "https://spoonjoy.app/recipes/recipe_invalid_title",
                    "sourceUrl": null,
                    "sourceHost": null,
                    "sourceRecipe": null
                  },
                  "createdAt": "2026-06-01T00:00:00.000Z",
                  "updatedAt": "2026-06-01T00:00:00.000Z",
                  "steps": [],
                  "cookbooks": []
                }
              ]
            }
            """#.utf8
        )

        var validationMessage: String?

        do {
            _ = try RecipeFixtureCatalog.decode(data: invalidData)
        } catch let error as RecipeCookbookValidationError {
            validationMessage = error.description
        } catch {
            validationMessage = String(describing: error)
        }

        #expect(validationMessage == "Recipe recipe_invalid_title must have a non-empty title.")
    }

    @Test("recipe search summary exposes public navigation fields")
    func recipeSearchSummaryExposesPublicNavigationFields() throws {
        let catalog = try RecipeFixtureCatalog.decodeFromBundle()
        let recipe = try #require(catalog.recipe(id: "recipe_lemon_pantry_pasta"))
        let summary = RecipeSearchSummary(recipe: recipe)

        #expect(summary.id == "recipe_lemon_pantry_pasta")
        #expect(summary.kind == .recipe)
        #expect(summary.title == "Lemon Pantry Pasta")
        #expect(summary.subtitle == "ari - 4 servings")
        #expect(summary.href == "/recipes/recipe_lemon_pantry_pasta")
        #expect(summary.canonicalURL == URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta"))
        #expect(summary.imageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))
        #expect(summary.accessibilityLabel == "Recipe, Lemon Pantry Pasta by ari")
    }

    @Test("cookbook fixture decodes cover, recipe links, and attribution")
    func cookbookFixtureDecodesCoverLinksAndAttribution() throws {
        let catalog = try CookbookFixtureCatalog.decodeFromBundle()

        #expect(catalog.cookbooks.count == 2)

        let cookbook = try #require(catalog.cookbook(id: "cookbook_weeknights"))
        #expect(cookbook.id == "cookbook_weeknights")
        #expect(cookbook.title == "Weeknights")
        #expect(cookbook.chef == ChefSummary(id: "chef_ari", username: "ari"))
        #expect(cookbook.recipeCount == 2)
        #expect(cookbook.cover.imageURLs == [
            URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"),
            URL(string: "https://spoonjoy.app/photos/recipes/recipe_tomato_toast/cover.jpg")
        ])
        #expect(cookbook.cover.primaryImageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))
        #expect(cookbook.cover.presentation == .collage)
        #expect(cookbook.href == "/cookbooks/cookbook_weeknights")
        #expect(cookbook.canonicalURL == URL(string: "https://spoonjoy.app/cookbooks/cookbook_weeknights"))
        #expect(cookbook.attribution.creditText == "Weeknights by ari on Spoonjoy")
        #expect(cookbook.recipes.map(\.id) == ["recipe_lemon_pantry_pasta", "recipe_tomato_toast"])
    }

    @Test("cookbook search summary exposes cover-aware navigation fields")
    func cookbookSearchSummaryExposesCoverAwareNavigationFields() throws {
        let catalog = try CookbookFixtureCatalog.decodeFromBundle()
        let cookbook = try #require(catalog.cookbook(id: "cookbook_weeknights"))
        let summary = CookbookSearchSummary(cookbook: cookbook)

        #expect(summary.id == "cookbook_weeknights")
        #expect(summary.kind == .cookbook)
        #expect(summary.title == "Weeknights")
        #expect(summary.subtitle == "ari - 2 recipes")
        #expect(summary.href == "/cookbooks/cookbook_weeknights")
        #expect(summary.canonicalURL == URL(string: "https://spoonjoy.app/cookbooks/cookbook_weeknights"))
        #expect(summary.imageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))
        #expect(summary.accessibilityLabel == "Cookbook, Weeknights by ari, 2 recipes")
    }

    @Test("cookbook cover falls back cleanly when no images are available")
    func cookbookCoverFallsBackWithoutImages() {
        let cover = CookbookCover(imageURLs: [])

        #expect(cover.primaryImageURL == nil)
        #expect(cover.presentation == .textOnly)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
