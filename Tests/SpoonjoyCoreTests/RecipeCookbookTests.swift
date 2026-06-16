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
        #expect(
            recipeValidationMessage(
                title: "",
                stepsJSON: validRecipeStepsJSON
            ) == "Recipe recipe_validation must have a non-empty title."
        )
        #expect(
            recipeValidationMessage(
                stepsJSON: "[]"
            ) == "Recipe recipe_validation must include at least one step."
        )
        #expect(
            recipeValidationMessage(
                stepsJSON: """
                [
                  {
                    "id": "step_empty_description",
                    "stepNum": 1,
                    "stepTitle": null,
                    "description": "  ",
                    "duration": null,
                    "ingredients": []
                  }
                ]
                """
            ) == "Recipe recipe_validation step step_empty_description must have a non-empty description."
        )
        #expect(
            recipeValidationMessage(
                stepsJSON: """
                [
                  {
                    "id": "step_duplicate_1",
                    "stepNum": 1,
                    "stepTitle": null,
                    "description": "Stir.",
                    "duration": null,
                    "ingredients": []
                  },
                  {
                    "id": "step_duplicate_2",
                    "stepNum": 1,
                    "stepTitle": null,
                    "description": "Serve.",
                    "duration": null,
                    "ingredients": []
                  }
                ]
                """
            ) == "Recipe recipe_validation must not repeat step number 1."
        )
        #expect(
            recipeValidationMessage(
                stepsJSON: """
                [
                  {
                    "id": "step_negative_quantity",
                    "stepNum": 1,
                    "stepTitle": null,
                    "description": "Stir.",
                    "duration": null,
                    "ingredients": [
                      {
                        "id": "ingredient_negative_quantity",
                        "name": "salt",
                        "quantity": -1,
                        "unit": null
                      }
                    ]
                  }
                ]
                """
            ) == "Recipe recipe_validation ingredient ingredient_negative_quantity must not have a negative quantity."
        )
    }

    @Test("recipe search summary exposes public navigation fields")
    func recipeSearchSummaryExposesPublicNavigationFields() throws {
        let catalog = try RecipeFixtureCatalog.decodeFromBundle()
        let recipe = try #require(catalog.recipe(id: "recipe_lemon_pantry_pasta"))
        let summary = RecipeSearchSummary(recipe: recipe)

        #expect(summary.id == "recipe_lemon_pantry_pasta")
        #expect(summary.kind == .recipe)
        #expect(summary.title == "Lemon Pantry Pasta")
        #expect(summary.subtitle == "ari - 4")
        #expect(summary.href == "/recipes/recipe_lemon_pantry_pasta")
        #expect(summary.canonicalURL == URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta"))
        #expect(summary.imageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))
        #expect(summary.accessibilityLabel == "Recipe, Lemon Pantry Pasta by ari")
    }

    @Test("recipe search summary falls back when serving text is absent")
    func recipeSearchSummaryFallsBackWithoutServings() throws {
        let catalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData(servingsJSON: "null"))
        let recipe = try #require(catalog.recipe(id: "recipe_validation"))
        let summary = RecipeSearchSummary(recipe: recipe)

        #expect(summary.subtitle == "ari")
    }

    @Test("recipe search summary preserves free-form serving text")
    func recipeSearchSummaryPreservesFreeFormServings() throws {
        let catalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData(servingsJSON: "\"  4 servings  \""))
        let recipe = try #require(catalog.recipe(id: "recipe_validation"))
        let summary = RecipeSearchSummary(recipe: recipe)

        #expect(summary.subtitle == "ari - 4 servings")
    }

    @Test("recipe attribution exposes only safe source links")
    func recipeAttributionExposesOnlySafeSourceLinks() throws {
        let safeCatalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData(sourceURLJSON: "\"https://example.com/path\""))
        let javascriptCatalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData(sourceURLJSON: "\"javascript:alert(1)\""))
        let fileCatalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData(sourceURLJSON: "\"file:///private/etc/passwd\""))
        let malformedCatalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData(sourceURLJSON: "\"not a url\""))
        let nullCatalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData(sourceURLJSON: "null"))

        #expect(safeCatalog.recipe(id: "recipe_validation")?.attribution.sourceURL == URL(string: "https://example.com/path"))
        #expect(safeCatalog.recipe(id: "recipe_validation")?.attribution.hasUnsafeSourceURL == false)

        for catalog in [javascriptCatalog, fileCatalog, malformedCatalog] {
            #expect(catalog.recipe(id: "recipe_validation")?.attribution.sourceURL == nil)
            #expect(catalog.recipe(id: "recipe_validation")?.attribution.hasUnsafeSourceURL == true)
        }

        #expect(nullCatalog.recipe(id: "recipe_validation")?.attribution.sourceURL == nil)
        #expect(nullCatalog.recipe(id: "recipe_validation")?.attribution.hasUnsafeSourceURL == false)
    }

    @Test("deleted source recipes do not expose safe navigation links")
    func deletedSourceRecipesDoNotExposeSafeNavigationLinks() throws {
        let liveSourceCatalog = try RecipeFixtureCatalog.decode(data: recipeCatalogData())
        let deletedSourceCatalog = try RecipeFixtureCatalog.decode(
            data: recipeCatalogData(
                sourceRecipeJSON: """
                {
                  "id": "recipe_source",
                  "title": "Source",
                  "chef": { "id": "chef_source", "username": "source" },
                  "href": "/recipes/recipe_source",
                  "canonicalUrl": "https://spoonjoy.app/recipes/recipe_source",
                  "deleted": true
                }
                """
            )
        )

        #expect(liveSourceCatalog.recipe(id: "recipe_validation")?.attribution.sourceRecipe?.safeCanonicalURL == URL(string: "https://spoonjoy.app/recipes/recipe_source"))
        #expect(deletedSourceCatalog.recipe(id: "recipe_validation")?.attribution.sourceRecipe?.safeCanonicalURL == nil)
    }

    @Test("recipe catalog returns nil for missing ids")
    func recipeCatalogReturnsNilForMissingIDs() throws {
        let catalog = try RecipeFixtureCatalog.decodeFromBundle()

        #expect(catalog.recipe(id: "recipe_missing") == nil)
    }

    @Test("cookbook fixture decodes cover, recipe summaries, and attribution")
    func cookbookFixtureDecodesCoverRecipeSummariesAndAttribution() throws {
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

        let recipeSummary = try #require(cookbook.recipes.first)
        #expect(recipeSummary.description == "Bright pantry pasta with lemon, garlic, and parmesan.")
        #expect(recipeSummary.servings == "4")
        #expect(recipeSummary.chef == ChefSummary(id: "chef_ari", username: "ari"))
        #expect(recipeSummary.coverImageURL == URL(string: "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"))
        #expect(recipeSummary.coverProvenanceLabel == "Chef photo")
        #expect(recipeSummary.coverSourceType == .chefUpload)
        #expect(recipeSummary.coverVariant == .image)
        #expect(recipeSummary.attribution.creditText == "Lemon Pantry Pasta by ari on Spoonjoy")
        #expect(recipeSummary.createdAt == "2026-06-01T00:00:00.000Z")
        #expect(recipeSummary.updatedAt == "2026-06-01T00:00:00.000Z")
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

    @Test("cookbook search summary uses singular recipe text")
    func cookbookSearchSummaryUsesSingularRecipeText() throws {
        let catalog = try CookbookFixtureCatalog.decode(data: cookbookCatalogData(recipeCount: 1))
        let cookbook = try #require(catalog.cookbook(id: "cookbook_validation"))
        let summary = CookbookSearchSummary(cookbook: cookbook)

        #expect(summary.subtitle == "ari - 1 recipe")
        #expect(summary.accessibilityLabel == "Cookbook, Validation by ari, 1 recipe")
    }

    @Test("cookbook cover falls back cleanly when no images are available")
    func cookbookCoverFallsBackWithoutImages() {
        let cover = CookbookCover(imageURLs: [])

        #expect(cover.primaryImageURL == nil)
        #expect(cover.presentation == .textOnly)
    }

    @Test("cookbook validation rejects malformed public payloads")
    func cookbookValidationRejectsMalformedPayloads() {
        #expect(
            cookbookValidationMessage(title: "") ==
                "Cookbook cookbook_validation must have a non-empty title."
        )
        #expect(
            cookbookValidationMessage(recipeCount: 2) ==
                "Cookbook cookbook_validation declares 2 recipes but contains 1."
        )
    }

    @Test("cookbook catalog returns nil for missing ids")
    func cookbookCatalogReturnsNilForMissingIDs() throws {
        let catalog = try CookbookFixtureCatalog.decodeFromBundle()

        #expect(catalog.cookbook(id: "cookbook_missing") == nil)
    }

    @Test("cookbook encoding preserves the API v1 field names")
    func cookbookEncodingPreservesAPIFieldNames() throws {
        let catalog = try CookbookFixtureCatalog.decodeFromBundle()
        let cookbook = try #require(catalog.cookbook(id: "cookbook_weeknights"))
        let encoded = try JSONEncoder().encode(cookbook)
        let decoded = try JSONDecoder().decode(Cookbook.self, from: encoded)
        let payload = String(decoding: encoded, as: UTF8.self)

        #expect(decoded == cookbook)
        #expect(payload.contains("\"canonicalUrl\""))
        #expect(payload.contains("\"coverImageUrls\""))
    }

    @Test("manual step and ingredient initializers preserve values")
    func manualStepAndIngredientInitializersPreserveValues() {
        let chef = ChefSummary(id: "chef_manual", username: "manual")
        let ingredient = RecipeIngredient(id: "ingredient_manual", name: "pepper", quantity: 0.25, unit: nil)
        let step = RecipeStep(
            id: "step_manual",
            stepNum: 1,
            stepTitle: nil,
            description: "Season to taste.",
            duration: nil,
            ingredients: [ingredient]
        )

        #expect(chef.username == "manual")
        #expect(ingredient.unit == nil)
        #expect(step.ingredients == [ingredient])
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private let validRecipeStepsJSON = """
[
  {
    "id": "step_validation",
    "stepNum": 1,
    "stepTitle": null,
    "description": "Stir.",
    "duration": null,
    "ingredients": [
      {
        "id": "ingredient_validation",
        "name": "salt",
        "quantity": 1,
        "unit": null
      }
    ]
  }
]
"""

private func recipeCatalogData(
    title: String = "Validation Recipe",
    servingsJSON: String = "\"2\"",
    sourceURLJSON: String = "null",
    sourceRecipeJSON: String = """
    {
      "id": "recipe_source",
      "title": "Source",
      "chef": { "id": "chef_source", "username": "source" },
      "href": "/recipes/recipe_source",
      "canonicalUrl": "https://spoonjoy.app/recipes/recipe_source",
      "deleted": false
    }
    """,
    stepsJSON: String = validRecipeStepsJSON
) -> Data {
    Data(
        """
        {
          "recipes": [
            {
              "id": "recipe_validation",
              "title": "\(title)",
              "description": null,
              "servings": \(servingsJSON),
              "chef": { "id": "chef_ari", "username": "ari" },
              "coverImageUrl": null,
              "coverProvenanceLabel": null,
              "coverSourceType": null,
              "coverVariant": null,
              "href": "/recipes/recipe_validation",
              "canonicalUrl": "https://spoonjoy.app/recipes/recipe_validation",
              "attribution": {
                "creditText": "Validation Recipe by ari on Spoonjoy",
                "canonicalUrl": "https://spoonjoy.app/recipes/recipe_validation",
                "sourceUrl": \(sourceURLJSON),
                "sourceHost": null,
                "sourceRecipe": \(sourceRecipeJSON)
              },
              "createdAt": "2026-06-01T00:00:00.000Z",
              "updatedAt": "2026-06-01T00:00:00.000Z",
              "steps": \(stepsJSON),
              "cookbooks": []
            }
          ]
        }
        """.utf8
    )
}

private func recipeValidationMessage(title: String = "Validation Recipe", stepsJSON: String) -> String? {
    do {
        _ = try RecipeFixtureCatalog.decode(data: recipeCatalogData(title: title, stepsJSON: stepsJSON))
        return nil
    } catch let error as RecipeCookbookValidationError {
        return error.description
    } catch {
        return String(describing: error)
    }
}

private func cookbookCatalogData(title: String = "Validation", recipeCount: Int = 1) -> Data {
    Data(
        """
        {
          "cookbooks": [
            {
              "id": "cookbook_validation",
              "title": "\(title)",
              "chef": { "id": "chef_ari", "username": "ari" },
              "recipeCount": \(recipeCount),
              "coverImageUrls": [],
              "href": "/cookbooks/cookbook_validation",
              "canonicalUrl": "https://spoonjoy.app/cookbooks/cookbook_validation",
              "attribution": {
                "creditText": "Validation by ari on Spoonjoy",
                "canonicalUrl": "https://spoonjoy.app/cookbooks/cookbook_validation"
              },
              "createdAt": "2026-06-01T00:00:00.000Z",
              "updatedAt": "2026-06-01T00:00:00.000Z",
              "recipes": [
                {
                  "id": "recipe_validation",
                  "title": "Validation Recipe",
                  "description": null,
                  "servings": "2",
                  "chef": { "id": "chef_ari", "username": "ari" },
                  "coverImageUrl": null,
                  "coverProvenanceLabel": null,
                  "coverSourceType": null,
                  "coverVariant": null,
                  "href": "/recipes/recipe_validation",
                  "canonicalUrl": "https://spoonjoy.app/recipes/recipe_validation",
                  "attribution": {
                    "creditText": "Validation Recipe by ari on Spoonjoy",
                    "canonicalUrl": "https://spoonjoy.app/recipes/recipe_validation",
                    "sourceUrl": null,
                    "sourceHost": null,
                    "sourceRecipe": null
                  },
                  "createdAt": "2026-06-01T00:00:00.000Z",
                  "updatedAt": "2026-06-01T00:00:00.000Z"
                }
              ]
            }
          ]
        }
        """.utf8
    )
}

private func cookbookValidationMessage(title: String = "Validation", recipeCount: Int = 1) -> String? {
    do {
        _ = try CookbookFixtureCatalog.decode(data: cookbookCatalogData(title: title, recipeCount: recipeCount))
        return nil
    } catch let error as RecipeCookbookValidationError {
        return error.description
    } catch {
        return String(describing: error)
    }
}
