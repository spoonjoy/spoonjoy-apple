import Foundation
import Testing
@testable import SpoonjoyCore

/// A preview build's environment is "preview:<host>", so its entity identifiers carry one more colon than the parsers
/// once split on. Every lookup by identifier then failed, and Siri asked again for a recipe it had just been given.
@Suite("Scoped entity identifiers")
struct ScopedEntityIdentifierTests {
    private static let qa = NativeCacheEnvironment.previewHost("spoonjoy-v2-qa.mendelow-studio.workers.dev")
    private static let environments: [NativeCacheEnvironment] = [.production, .preview, .local, qa]

    @Test("every entity kind resolves its own identifier in every environment, preview hosts included")
    func everyKindRoundTripsInEveryEnvironment() throws {
        for environment in Self.environments {
            let recipe = RecipeCookbookEntityCatalog.recipeEntityIdentifier(recipeID: "recipe_1", accountID: "acct", environment: environment)
            #expect(try RecipeCookbookEntityCatalog.resolvedRecipeID(from: recipe, accountID: "acct", environment: environment) == "recipe_1")
            #expect(try RecipeCookbookEntityCatalog.resolvedRecipeID(from: "  \(recipe) ", accountID: "acct", environment: environment) == "recipe_1")

            let cookbook = RecipeCookbookEntityCatalog.cookbookEntityIdentifier(cookbookID: "cookbook_1", accountID: "acct", environment: environment)
            #expect(try RecipeCookbookEntityCatalog.resolvedCookbookID(from: cookbook, accountID: "acct", environment: environment) == "cookbook_1")

            let item = ShoppingEntityCatalog.shoppingItemEntityIdentifier(itemID: "item_1", accountID: "acct", environment: environment)
            #expect(try ShoppingEntityCatalog.resolvedShoppingItemID(from: item, accountID: "acct", environment: environment) == "item_1")

            let draft = CaptureDraftEntityCatalog.captureDraftEntityIdentifier(draftID: "draft_1", accountID: "acct", environment: environment)
            #expect(try CaptureDraftEntityCatalog.resolvedCaptureDraftID(from: draft, accountID: "acct", environment: environment) == "draft_1")

            let spoon = SpoonEntityCatalog.spoonEntityIdentifier(spoonID: "spoon_1", accountID: "acct", environment: environment)
            #expect(try SpoonEntityCatalog.resolvedSpoonID(from: spoon, accountID: "acct", environment: environment) == "spoon_1")
        }
    }

    @Test("an identifier from another environment, account, kind or schema, or with a bad id, never resolves")
    func foreignOrMalformedIdentifiersNeverResolve() {
        let schema = "schema\(NativeDurableCacheSnapshot.currentSchemaVersion)"
        let rejected = [
            RecipeCookbookEntityCatalog.recipeEntityIdentifier(recipeID: "recipe_1", accountID: "acct", environment: .production),
            RecipeCookbookEntityCatalog.recipeEntityIdentifier(recipeID: "recipe_1", accountID: "other", environment: Self.qa),
            RecipeCookbookEntityCatalog.recipeEntityIdentifier(recipeID: "recipe_1", accountID: "acct", environment: .previewHost("other.example")),
            RecipeCookbookEntityCatalog.cookbookEntityIdentifier(cookbookID: "recipe_1", accountID: "acct", environment: Self.qa),
            "recipe:\(Self.qa.rawValue):schema0:acct:recipe_1",
            "recipe:\(Self.qa.rawValue):\(schema):acct:",
            "recipe:\(Self.qa.rawValue):\(schema):acct:recipe:1",
            "recipe:\(Self.qa.rawValue):\(schema):acct",
            ""
        ]
        for identifier in rejected {
            #expect(throws: RecipeCookbookEntityCatalogError.self) {
                _ = try RecipeCookbookEntityCatalog.resolvedRecipeID(from: identifier, accountID: "acct", environment: Self.qa)
            }
        }
        #expect(throws: RecipeCookbookEntityCatalogError.self) {
            _ = try RecipeCookbookEntityCatalog.resolvedCookbookID(from: "cookbook:production:\(schema):acct:c", accountID: "acct", environment: Self.qa)
        }
        #expect(throws: ShoppingEntityCatalogError.self) {
            _ = try ShoppingEntityCatalog.resolvedShoppingItemID(from: "shopping-item:production:\(schema):acct:i", accountID: "acct", environment: Self.qa)
        }
        #expect(throws: CaptureDraftEntityCatalogError.self) {
            _ = try CaptureDraftEntityCatalog.resolvedCaptureDraftID(from: "capture-draft:production:\(schema):acct:d", accountID: "acct", environment: Self.qa)
        }
        #expect(throws: SpoonEntityCatalogError.self) {
            _ = try SpoonEntityCatalog.resolvedSpoonID(from: "spoon:production:\(schema):acct:s", accountID: "acct", environment: Self.qa)
        }
    }
}
