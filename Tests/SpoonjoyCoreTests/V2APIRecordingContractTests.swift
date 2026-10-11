import Foundation
import Testing
@testable import SpoonjoyCore

/// Decodes real spoonjoy-v2 responses with the models the app uses for each endpoint it calls.
///
/// spoonjoy-v2 records these responses in `test/contracts/native-api-recordings.test.ts`, which drives
/// v2's own route handlers with the request bodies this app sends. The copies in
/// `docs/source/spoonjoy-v2-api-recordings` must match v2's main branch; `scripts/check-v2-api-recordings.rb`
/// checks that in CI, and `ruby scripts/check-v2-api-recordings.rb --update` refreshes them.
@Suite("spoonjoy-v2 API recordings")
struct V2APIRecordingContractTests {
    struct IndexEntry: Decodable, Equatable, Sendable {
        let name: String
        let endpoint: String
        let status: Int
    }

    struct RecordingError: Error, CustomStringConvertible {
        let description: String
    }

    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/source/spoonjoy-v2-api-recordings")

    static func index() throws -> [IndexEntry] {
        try JSONDecoder().decode([IndexEntry].self, from: Data(contentsOf: directory.appendingPathComponent("index.json")))
    }

    /// The recorded response body, exactly as v2 sent it apart from normalized IDs and timestamps.
    static func body(_ name: String) throws -> Data {
        let file = try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
        guard let recording = try JSONSerialization.jsonObject(with: file) as? [String: Any],
              let body = recording["body"] else {
            throw RecordingError(description: "\(name).json has no body")
        }
        return try JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed])
    }

    /// The `data` member of an enveloped recording, for reading the IDs the app should find in it.
    static func data(_ name: String) throws -> [String: Any] {
        guard let body = try JSONSerialization.jsonObject(with: body(name)) as? [String: Any],
              let data = body["data"] as? [String: Any] else {
            throw RecordingError(description: "\(name) has no data object")
        }
        return data
    }

    static func string(_ object: Any?, _ path: String...) -> String? {
        var current = object
        for key in path {
            current = (current as? [String: Any])?[key]
        }
        return current as? String
    }

    static func envelope<Value: Decodable & Equatable>(_ type: Value.Type) -> @Sendable (Data) throws -> Void {
        { data in _ = try APIEnvelope<Value>.decode(data) }
    }

    /// OAuth responses go through the app's `sendDecoded`, which tries the envelope and then the bare body.
    static func envelopeOrBare<Value: Decodable & Equatable>(_ type: Value.Type) -> @Sendable (Data) throws -> Void {
        { data in
            if (try? APIEnvelope<Value>.decode(data)) != nil {
                return
            }
            _ = try JSONDecoder().decode(Value.self, from: data)
        }
    }

    static func json(_ data: Data) throws -> JSONValue {
        try APIEnvelope<JSONValue>.decode(data).data
    }

    /// Each recording's decoder, matching what the app decodes that endpoint's response into.
    static let decoders: [String: @Sendable (Data) throws -> Void] = [
        "auth-password-native": envelopeOrBare(OAuthTokenResponse.self),
        "auth-apple-native": envelopeOrBare(OAuthTokenResponse.self),
        "oauth-token-refresh": envelopeOrBare(OAuthTokenResponse.self),
        "oauth-register": envelopeOrBare(OAuthRegisterResponse.self),
        "recipe-create": envelope(JSONValue.self),
        "recipe-step-create": envelope(JSONValue.self),
        "recipe-step-update": envelope(JSONValue.self),
        "recipe-ingredient-create": envelope(JSONValue.self),
        "recipe-ingredient-delete": envelope(JSONValue.self),
        "recipe-output-uses-replace": envelope(JSONValue.self),
        "recipe-step-reorder": envelope(JSONValue.self),
        "recipe-step-delete": envelope(JSONValue.self),
        "recipe-update": envelope(JSONValue.self),
        "recipe-image-upload": envelope(JSONValue.self),
        "recipe-image-upload-spoon": envelope(JSONValue.self),
        "recipe-covers-list": envelope(RecipeCoverListData.self),
        "recipe-cover-activate": envelope(JSONValue.self),
        "recipe-cover-from-spoon": envelope(JSONValue.self),
        "recipe-cover-set-no-cover": envelope(JSONValue.self),
        "recipe-cover-archive": envelope(JSONValue.self),
        "recipe-spoon-create": envelope(JSONValue.self),
        "recipe-spoon-create-photo": envelope(JSONValue.self),
        "recipe-spoon-update": envelope(JSONValue.self),
        "recipe-spoon-delete": envelope(JSONValue.self),
        "recipe-spoons-list": envelope(SpoonCookLogListData.self),
        "recipe-fork": envelope(JSONValue.self),
        "recipe-delete": envelope(JSONValue.self),
        "cookbook-create": envelope(JSONValue.self),
        "cookbook-update": envelope(JSONValue.self),
        "cookbook-add-recipe": envelope(JSONValue.self),
        "cookbook-remove-recipe": envelope(JSONValue.self),
        "cookbook-delete": envelope(JSONValue.self),
        "cookbooks-list": envelope(CookbookListData.self),
        "cookbook-detail": envelope(CookbookDetailData.self),
        "shopping-list-read": envelope(ShoppingListReadData.self),
        "shopping-list-read-full": envelope(ShoppingListReadData.self),
        "shopping-item-add": envelope(ShoppingItemMutationData.self),
        "shopping-item-check": envelope(ShoppingItemMutationData.self),
        "shopping-item-delete": envelope(ShoppingItemMutationData.self),
        "shopping-add-from-recipe": envelope(JSONValue.self),
        "shopping-clear-completed": envelope(JSONValue.self),
        "shopping-clear-all": envelope(JSONValue.self),
        "recipes-list": envelope(RecipeListData.self),
        "recipe-detail": envelope(RecipeDetailData.self),
        "search": envelope(SearchSurfaceData.self),
        "user-profile": envelope(ProfileSurfaceData.self),
        "user-kitchen-visitors": envelope(ProfileGraphPage.self),
        "user-fellow-chefs": envelope(ProfileGraphPage.self),
        "me-chefs": envelope(NativeChefsData.self),
        "me-sync": envelope(NativeSyncData.self),
        "recipe-import-blocked": envelope(RecipeImportResponse.self),
        "recipe-import": envelope(RecipeImportResponse.self),
        "me": envelope(SettingsAccountProfile.self),
        "me-update": envelope(SettingsAccountProfile.self),
        "me-photo-upload": envelope(SettingsAccountProfile.self),
        "me-photo-remove": envelope(SettingsAccountProfile.self),
        "notification-preferences": envelope(SettingsNotificationPreferences.self),
        "notification-preferences-update": envelope(SettingsNotificationPreferences.self),
        "apns-device-register": envelope(JSONValue.self),
        "apns-device-revoke": envelope(JSONValue.self),
        "tokens-list": envelope(SettingsAPITokenListResponse.self),
        "token-create": envelope(SettingsCreatedAPIToken.self),
        "token-revoke": envelope(JSONValue.self),
        "native-telemetry": envelope(NativeTelemetryResponse.self),
        "me-export": envelope(JSONValue.self),
        "connections-list": envelope(SettingsOAuthConnectionListResponse.self),
        "connection-disconnect": envelope(JSONValue.self),
        "account-delete": envelope(AccountDeletionResult.self)
    ]

    @Test("every recording has a decoder and every decoder has a recording")
    func everyRecordingHasADecoder() throws {
        let names = try Self.index().map(\.name)
        #expect(Set(names).count == names.count)
        #expect(Set(names) == Set(Self.decoders.keys))
    }

    @Test("every recorded v2 response decodes into the app's model")
    func everyRecordingDecodes() throws {
        let entries = try Self.index()
        #expect(!entries.isEmpty)
        for entry in entries {
            guard let decode = Self.decoders[entry.name] else {
                Issue.record("No decoder for \(entry.name) (\(entry.endpoint))")
                continue
            }
            do {
                try decode(Self.body(entry.name))
            } catch {
                Issue.record("\(entry.name) (\(entry.endpoint)) does not decode: \(error)")
            }
        }
    }

    static func id(_ value: String?, _ what: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw RecordingError(description: "The recording has no \(what)")
        }
        return value
    }

    static let createdAt = "2026-01-01T00:00:00.000Z"

    @Test("recipe create response gives the app the recipe, step and ingredient IDs it remaps")
    func recipeCreateRemaps() throws {
        let response = try Self.json(Self.body("recipe-create"))
        let recipe = try Self.data("recipe-create")["recipe"] as? [String: Any]
        let step = (recipe?["steps"] as? [[String: Any]])?.first
        let ingredients = step?["ingredients"] as? [[String: Any]] ?? []
        func ingredientID(_ name: String) throws -> String {
            try Self.id(ingredients.first { $0["name"] as? String == name }?["id"] as? String, "\(name) ingredient id")
        }
        let expected = [
            NativeSyncIDRemap(localID: "recipe_local_cm_recipe_create", serverID: try Self.id(recipe?["id"] as? String, "recipe id")),
            NativeSyncIDRemap(localID: "step_local_cm_recipe_create_1", serverID: try Self.id(step?["id"] as? String, "step id")),
            NativeSyncIDRemap(localID: "ingredient_local_cm_recipe_create_1_1", serverID: try ingredientID("spaghetti")),
            NativeSyncIDRemap(localID: "ingredient_local_cm_recipe_create_1_2", serverID: try ingredientID("salt"))
        ]
        let mutation = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_create",
            title: "Lemon Pantry Pasta",
            description: "Bright weeknight pasta from the pantry.",
            servings: "4",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Boil",
                    description: "Cook the spaghetti in salted water.",
                    duration: 10,
                    ingredients: [
                        RecipeIngredientDraft(quantity: 200, unit: "g", name: "spaghetti"),
                        RecipeIngredientDraft(quantity: 1, unit: "tsp", name: "salt")
                    ],
                    outputStepNums: []
                )
            ],
            createdAt: Self.createdAt
        )

        #expect(RecipeCreateResponse.recipeID(from: response) == expected[0].serverID)
        #expect(mutation.idRemaps(from: response) == expected)
    }

    @Test("step and ingredient create responses give the app the IDs it remaps")
    func stepAndIngredientCreateRemaps() throws {
        let stepResponse = try Self.json(Self.body("recipe-step-create"))
        let step = try Self.data("recipe-step-create")["step"] as? [String: Any]
        let stepIngredient = (step?["ingredients"] as? [[String: Any]])?.first
        let expectedStepRemaps = [
            NativeSyncIDRemap(localID: "step_local_cm_step_create", serverID: try Self.id(step?["id"] as? String, "step id")),
            NativeSyncIDRemap(localID: "ingredient_local_cm_step_create_1", serverID: try Self.id(stepIngredient?["id"] as? String, "step ingredient id"))
        ]
        let stepCreate = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_lemon",
            clientMutationID: "cm_step_create",
            stepNum: 2,
            stepTitle: "Toss",
            description: "Toss the pasta with lemon and olive oil.",
            duration: 2,
            ingredients: [RecipeIngredientDraft(quantity: 1, unit: "whole", name: "lemon")],
            outputStepNums: [1],
            createdAt: Self.createdAt
        )
        #expect(stepCreate.idRemaps(from: stepResponse) == expectedStepRemaps)

        let ingredientResponse = try Self.json(Self.body("recipe-ingredient-create"))
        let expectedIngredientRemaps = [
            NativeSyncIDRemap(
                localID: "ingredient_local_cm_ingredient_create",
                serverID: try Self.id(Self.string(Self.data("recipe-ingredient-create"), "ingredient", "id"), "ingredient id")
            )
        ]
        let ingredientAdd = try NativeQueuedMutation.recipeIngredientAdd(
            recipeID: "recipe_lemon",
            stepID: "step_toss",
            clientMutationID: "cm_ingredient_create",
            quantity: 2,
            unit: "tbsp",
            name: "olive oil",
            createdAt: Self.createdAt
        )
        #expect(ingredientAdd.idRemaps(from: ingredientResponse) == expectedIngredientRemaps)
    }

    @Test("cookbook, spoon and shopping create responses give the app the IDs it remaps")
    func collectionCreateRemaps() throws {
        let cookbookResponse = try Self.json(Self.body("cookbook-create"))
        let expectedCookbookRemaps = [
            NativeSyncIDRemap(
                localID: "cookbook_local_cm_cookbook_create",
                serverID: try Self.id(Self.string(Self.data("cookbook-create"), "cookbook", "id"), "cookbook id")
            )
        ]
        let cookbookCreate = NativeQueuedMutation.cookbookCreate(clientMutationID: "cm_cookbook_create", title: "Weeknights", createdAt: Self.createdAt)
        #expect(cookbookCreate.idRemaps(from: cookbookResponse) == expectedCookbookRemaps)

        for name in ["recipe-spoon-create", "recipe-spoon-create-photo"] {
            let spoonResponse = try Self.json(Self.body(name))
            let expectedSpoonRemaps = [
                NativeSyncIDRemap(localID: "spoon_local_cm_\(name)", serverID: try Self.id(Self.string(Self.data(name), "spoon", "id"), "\(name) spoon id"))
            ]
            let spoonCreate = NativeQueuedMutation.spoonCreate(
                recipeID: "recipe_lemon",
                clientMutationID: "cm_\(name)",
                note: nil,
                nextTime: nil,
                cookedAt: nil,
                photoURL: nil,
                useAsRecipeCover: false,
                createdAt: Self.createdAt
            )
            #expect(spoonCreate.idRemaps(from: spoonResponse) == expectedSpoonRemaps)
        }

        let itemResponse = try Self.json(Self.body("shopping-item-add"))
        let expectedItemRemaps = [
            NativeSyncIDRemap(localID: "item_local_cm_shopping_add", serverID: try Self.id(Self.string(Self.data("shopping-item-add"), "item", "id"), "item id"))
        ]
        let itemAdd = NativeQueuedMutation.shoppingAddItem(
            name: "parmesan",
            quantity: 50,
            unit: "g",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_shopping_add",
            createdAt: Self.createdAt
        )
        #expect(itemAdd.idRemaps(from: itemResponse) == expectedItemRemaps)

        let fromRecipeResponse = try Self.json(Self.body("shopping-add-from-recipe"))
        let fromRecipeItems = try Self.data("shopping-add-from-recipe")["items"] as? [[String: Any]] ?? []
        let expectedFromRecipeRemaps = try fromRecipeItems.enumerated().map { index, item in
            NativeSyncIDRemap(
                localID: "item_local_cm_shopping_from_recipe-ingredient-\(index + 1)",
                serverID: try Self.id(item["id"] as? String, "shopping item id")
            )
        }
        let addFromRecipe = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_lemon",
            scaleFactor: 1,
            clientMutationID: "cm_shopping_from_recipe",
            createdAt: Self.createdAt
        )
        #expect(!expectedFromRecipeRemaps.isEmpty)
        #expect(addFromRecipe.idRemaps(from: fromRecipeResponse) == expectedFromRecipeRemaps)
    }
}
