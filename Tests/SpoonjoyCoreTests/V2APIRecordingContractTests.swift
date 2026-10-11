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

    static func envelope<Value: Decodable & Equatable>(_ type: Value.Type, _ data: Data) throws {
        _ = try APIEnvelope<Value>.decode(data)
    }

    /// OAuth responses go through the app's `sendDecoded`, which tries the envelope and then the bare body.
    static func envelopeOrBare<Value: Decodable & Equatable>(_ type: Value.Type, _ data: Data) throws {
        if (try? APIEnvelope<Value>.decode(data)) != nil {
            return
        }
        _ = try JSONDecoder().decode(Value.self, from: data)
    }

    static func json(_ data: Data) throws -> JSONValue {
        try APIEnvelope<JSONValue>.decode(data).data
    }

    /// The recordings `decode(_:_:)` knows, one per endpoint response the app reads.
    static let decodedNames: Set<String> = [
        "auth-password-native",
        "auth-apple-native",
        "oauth-token-refresh",
        "oauth-register",
        "recipe-create",
        "recipe-step-create",
        "recipe-step-update",
        "recipe-ingredient-create",
        "recipe-ingredient-delete",
        "recipe-output-uses-replace",
        "recipe-step-reorder",
        "recipe-step-delete",
        "recipe-update",
        "recipe-image-upload",
        "recipe-image-upload-spoon",
        "recipe-covers-list",
        "recipe-cover-activate",
        "recipe-cover-from-spoon",
        "recipe-cover-set-no-cover",
        "recipe-cover-archive",
        "recipe-spoon-create",
        "recipe-spoon-create-photo",
        "recipe-spoon-update",
        "recipe-spoon-delete",
        "recipe-spoons-list",
        "recipe-fork",
        "recipe-delete",
        "cookbook-create",
        "cookbook-update",
        "cookbook-add-recipe",
        "cookbook-remove-recipe",
        "cookbook-delete",
        "cookbooks-list",
        "cookbook-detail",
        "shopping-list-read",
        "shopping-list-read-full",
        "shopping-item-add",
        "shopping-item-check",
        "shopping-item-delete",
        "shopping-add-from-recipe",
        "shopping-clear-completed",
        "shopping-clear-all",
        "recipes-list",
        "recipe-detail",
        "search",
        "user-profile",
        "user-kitchen-visitors",
        "user-fellow-chefs",
        "me-chefs",
        "me-sync",
        "recipe-import-blocked",
        "recipe-import",
        "me",
        "me-update",
        "me-photo-upload",
        "me-photo-remove",
        "notification-preferences",
        "notification-preferences-update",
        "apns-device-register",
        "apns-device-revoke",
        "tokens-list",
        "token-create",
        "token-revoke",
        "native-telemetry",
        "me-export",
        "connections-list",
        "connection-disconnect",
        "account-delete",
        "cook-session-read-empty",
        "cook-session-start",
        "cook-session-start-resume",
        "cook-session-patch",
        "cook-session-read",
        "cook-session-patch-stale-revision"
    ]

    /// The cook-session answers are not the envelope. The app reads them with `URLSessionCookSessionClient.classify`,
    /// which turns a state it cannot decode into a retry, so this also decodes the state into `CookServerSnapshot`
    /// itself and checks that `classify` gives the result the app acts on.
    @discardableResult
    static func cookSession(_ data: Data, status: Int) throws -> CookSyncResult {
        let result = URLSessionCookSessionClient.classify(status: status, body: data, retryAfter: nil)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let state = status == 409 ? (object?["error"] as? [String: Any])?["state"] : object?["state"]
        if state is NSNull {
            guard result == .state(nil) else {
                throw RecordingError(description: "A null cook-session state classifies as \(result)")
            }
            return result
        }
        guard let state else {
            throw RecordingError(description: "The cook-session answer has no state")
        }
        let snapshot = try JSONDecoder().decode(CookServerSnapshot.self, from: JSONSerialization.data(withJSONObject: state))
        let expected: CookSyncResult = status == 409 ? .conflict(snapshot) : .state(snapshot)
        guard result == expected else {
            throw RecordingError(description: "The cook-session answer classifies as \(result), expected \(expected)")
        }
        return result
    }

    /// Decodes a recording with the model the app decodes that endpoint's response into.
    /// Returns false for a recording this suite does not know yet.
    static func decode(_ name: String, _ data: Data, status: Int = 200) throws -> Bool {
        if name.hasPrefix("cook-session-") {
            try cookSession(data, status: status)
            return true
        }
        switch name {
        case "auth-password-native": try envelopeOrBare(OAuthTokenResponse.self, data)
        case "auth-apple-native": try envelopeOrBare(OAuthTokenResponse.self, data)
        case "oauth-token-refresh": try envelopeOrBare(OAuthTokenResponse.self, data)
        case "oauth-register": try envelopeOrBare(OAuthRegisterResponse.self, data)
        case "recipe-create": try envelope(JSONValue.self, data)
        case "recipe-step-create": try envelope(JSONValue.self, data)
        case "recipe-step-update": try envelope(JSONValue.self, data)
        case "recipe-ingredient-create": try envelope(JSONValue.self, data)
        case "recipe-ingredient-delete": try envelope(JSONValue.self, data)
        case "recipe-output-uses-replace": try envelope(JSONValue.self, data)
        case "recipe-step-reorder": try envelope(JSONValue.self, data)
        case "recipe-step-delete": try envelope(JSONValue.self, data)
        case "recipe-update": try envelope(JSONValue.self, data)
        case "recipe-image-upload": try envelope(JSONValue.self, data)
        case "recipe-image-upload-spoon": try envelope(JSONValue.self, data)
        case "recipe-covers-list": try envelope(RecipeCoverListData.self, data)
        case "recipe-cover-activate": try envelope(JSONValue.self, data)
        case "recipe-cover-from-spoon": try envelope(JSONValue.self, data)
        case "recipe-cover-set-no-cover": try envelope(JSONValue.self, data)
        case "recipe-cover-archive": try envelope(JSONValue.self, data)
        case "recipe-spoon-create": try envelope(JSONValue.self, data)
        case "recipe-spoon-create-photo": try envelope(JSONValue.self, data)
        case "recipe-spoon-update": try envelope(JSONValue.self, data)
        case "recipe-spoon-delete": try envelope(JSONValue.self, data)
        case "recipe-spoons-list": try envelope(SpoonCookLogListData.self, data)
        case "recipe-fork": try envelope(JSONValue.self, data)
        case "recipe-delete": try envelope(JSONValue.self, data)
        case "cookbook-create": try envelope(JSONValue.self, data)
        case "cookbook-update": try envelope(JSONValue.self, data)
        case "cookbook-add-recipe": try envelope(JSONValue.self, data)
        case "cookbook-remove-recipe": try envelope(JSONValue.self, data)
        case "cookbook-delete": try envelope(JSONValue.self, data)
        case "cookbooks-list": try envelope(CookbookListData.self, data)
        case "cookbook-detail": try envelope(CookbookDetailData.self, data)
        case "shopping-list-read": try envelope(ShoppingListReadData.self, data)
        case "shopping-list-read-full": try envelope(ShoppingListReadData.self, data)
        case "shopping-item-add": try envelope(ShoppingItemMutationData.self, data)
        case "shopping-item-check": try envelope(ShoppingItemMutationData.self, data)
        case "shopping-item-delete": try envelope(ShoppingItemMutationData.self, data)
        case "shopping-add-from-recipe": try envelope(JSONValue.self, data)
        case "shopping-clear-completed": try envelope(JSONValue.self, data)
        case "shopping-clear-all": try envelope(JSONValue.self, data)
        case "recipes-list": try envelope(RecipeListData.self, data)
        case "recipe-detail": try envelope(RecipeDetailData.self, data)
        case "search": try envelope(SearchSurfaceData.self, data)
        case "user-profile": try envelope(ProfileSurfaceData.self, data)
        case "user-kitchen-visitors": try envelope(ProfileGraphPage.self, data)
        case "user-fellow-chefs": try envelope(ProfileGraphPage.self, data)
        case "me-chefs": try envelope(NativeChefsData.self, data)
        case "me-sync": try envelope(NativeSyncData.self, data)
        case "recipe-import-blocked": try envelope(RecipeImportResponse.self, data)
        case "recipe-import": try envelope(RecipeImportResponse.self, data)
        case "me": try envelope(SettingsAccountProfile.self, data)
        case "me-update": try envelope(SettingsAccountProfile.self, data)
        case "me-photo-upload": try envelope(SettingsAccountProfile.self, data)
        case "me-photo-remove": try envelope(SettingsAccountProfile.self, data)
        case "notification-preferences": try envelope(SettingsNotificationPreferences.self, data)
        case "notification-preferences-update": try envelope(SettingsNotificationPreferences.self, data)
        case "apns-device-register": try envelope(JSONValue.self, data)
        case "apns-device-revoke": try envelope(JSONValue.self, data)
        case "tokens-list": try envelope(SettingsAPITokenListResponse.self, data)
        case "token-create": try envelope(SettingsCreatedAPIToken.self, data)
        case "token-revoke": try envelope(JSONValue.self, data)
        case "native-telemetry": try envelope(NativeTelemetryResponse.self, data)
        case "me-export": try envelope(JSONValue.self, data)
        case "connections-list": try envelope(SettingsOAuthConnectionListResponse.self, data)
        case "connection-disconnect": try envelope(JSONValue.self, data)
        case "account-delete": try envelope(AccountDeletionResult.self, data)
        default: return false
        }
        return true
    }

    @Test("every recording has a decoder and every decoder has a recording")
    func everyRecordingHasADecoder() throws {
        let names = try Self.index().map(\.name)
        #expect(Set(names).count == names.count)
        #expect(Set(names) == Self.decodedNames)
    }

    @Test("every recorded v2 response decodes into the app's model")
    func everyRecordingDecodes() throws {
        let entries = try Self.index()
        #expect(!entries.isEmpty)
        for entry in entries {
            do {
                if try !Self.decode(entry.name, Self.body(entry.name), status: entry.status) {
                    Issue.record("No decoder for \(entry.name) (\(entry.endpoint))")
                }
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

    static func cookResult(_ name: String) throws -> CookSyncResult {
        guard let entry = try index().first(where: { $0.name == name }) else {
            throw RecordingError(description: "\(name) is not in the index")
        }
        return try cookSession(body(name), status: entry.status)
    }

    static func snapshot(_ result: CookSyncResult) throws -> CookServerSnapshot {
        switch result {
        case .state(let snapshot?), .conflict(let snapshot):
            return snapshot
        default:
            throw RecordingError(description: "\(result) carries no cook-session state")
        }
    }

    @Test("cook-session recordings give the app the states its sync reconciles")
    func cookSessionRecordingsDriveSync() throws {
        #expect(try Self.cookResult("cook-session-read-empty") == .state(nil))

        let started = try Self.snapshot(Self.cookResult("cook-session-start"))
        #expect(started.revision == 0)
        #expect(started.progress == .initial)
        #expect(try Self.cookResult("cook-session-start-resume") == .state(started))

        // The app sends the step by index (CookSyncChanges has no step id); the server answers with the step's
        // id as well, which the app ignores, and drops a checked ingredient the recipe no longer has.
        let written = try Self.snapshot(Self.cookResult("cook-session-patch"))
        #expect(written.attemptID == started.attemptID)
        #expect(written.revision == 1)
        #expect(written.progress.activeStepIndex == 1)
        #expect(written.progress.scaleFactor == 2)
        #expect(written.progress.checkedIngredientIDs.count == 1)
        #expect(written.progress.checkedStepOutputIDs.count == 1)
        let progress = try #require(
            (JSONSerialization.jsonObject(with: Self.body("cook-session-patch")) as? [String: Any])
                .flatMap { $0["state"] as? [String: Any] }
                .flatMap { $0["progress"] as? [String: Any] }
        )
        #expect(progress["activeStepId"] is String)

        #expect(try Self.cookResult("cook-session-read") == .state(written))
        // A write against an older revision is refused with the newer state, which the app merges its changes onto.
        #expect(try Self.cookResult("cook-session-patch-stale-revision") == .conflict(written))
    }

    @Test("signed-in profile recordings say the chef owns their own profile")
    func signedInProfileRecordingsAreOwned() throws {
        #expect(try APIEnvelope<ProfileSurfaceData>.decode(Self.body("user-profile")).data.isOwner)
    }
}
