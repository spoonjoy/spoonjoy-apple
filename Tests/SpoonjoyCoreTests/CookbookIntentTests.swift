import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cookbook Siri intent contracts")
struct CookbookIntentTests {
    @Test("cookbook Siri intents require entity-backed owner-safe cookbook actions")
    func cookbookSiriIntentsRequireEntityBackedOwnerSafeCookbookActions() throws {
        var failures = cookbookIntentSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "scripts/check-app-intents-contract.rb"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct CreateCookbookIntent: AppIntent",
                    "struct RenameCookbookIntent: AppIntent",
                    "struct DeleteCookbookIntent: AppIntent",
                    "struct AddRecipeToCookbookIntent: AppIntent",
                    "struct RemoveRecipeFromCookbookIntent: AppIntent",
                    "var cookbook: SpoonjoyCookbookEntity",
                    "var recipe: SpoonjoyRecipeEntity",
                    "SpoonjoyIntentStateWriter",
                    "SpoonjoyIntentClock.timestamp()",
                    "SpoonjoyInteractionDonor",
                    "String(describing: CreateCookbookIntent())",
                    "String(describing: RenameCookbookIntent())",
                    "String(describing: DeleteCookbookIntent())",
                    "String(describing: AddRecipeToCookbookIntent())",
                    "String(describing: RemoveRecipeFromCookbookIntent())"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift": [
                    "struct SpoonjoyCookbookEntity: AppEntity",
                    "struct SpoonjoyRecipeEntity: AppEntity",
                    "NativeIntentActionError.unresolvedCookbookEntity",
                    "NativeIntentActionError.unresolvedRecipeEntity"
                ],
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift": [
                    "public let chefID: String",
                    "chefID: cookbook.chef.id",
                    "chefID: \"chef-placeholder\""
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "case emptyCookbookTitle",
                    "case cookbookOwnershipRequired(cookbookID: String)",
                    "public func createCookbook(",
                    "public func renameCookbook(",
                    "public func deleteCookbook(",
                    "public func addRecipeToCookbook(",
                    "public func removeRecipeFromCookbook(",
                    "currentChefID: String",
                    ".cookbookCreate",
                    ".cookbookUpdate",
                    ".cookbookDelete",
                    ".cookbookAddRecipe",
                    ".cookbookRemoveRecipe",
                    "DeepLinkURLBuilder.url(for:"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "CreateCookbookIntent",
                    "RenameCookbookIntent",
                    "DeleteCookbookIntent",
                    "AddRecipeToCookbookIntent",
                    "RemoveRecipeFromCookbookIntent"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Cookbook Siri intents",
                    "CreateCookbookIntent",
                    "RenameCookbookIntent",
                    "DeleteCookbookIntent",
                    "AddRecipeToCookbookIntent",
                    "RemoveRecipeFromCookbookIntent"
                ],
                "scripts/check-app-intents-contract.rb": [
                    "\"cookbook-intents\"",
                    "if domain == \"cookbook-intents\"",
                    "CreateCookbookIntent",
                    "RenameCookbookIntent",
                    "DeleteCookbookIntent",
                    "AddRecipeToCookbookIntent",
                    "RemoveRecipeFromCookbookIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": cookbookIntentForbiddenProductTokens(),
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": cookbookIntentForbiddenProductTokens()
            ]
        )

        failures.append(contentsOf: cookbookIntentShortcutBudgetFailures(
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            maximumShortcuts: 10,
            libraryOnlyIntentNames: [
                "CreateCookbookIntent",
                "RenameCookbookIntent",
                "DeleteCookbookIntent",
                "AddRecipeToCookbookIntent",
                "RemoveRecipeFromCookbookIntent"
            ]
        ))

        failures.append(contentsOf: cookbookIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentShortcutBudget",
                    pattern: #"private\s+enum\s+SpoonjoyIntentShortcutBudget"#,
                    requiredTokens: [
                        "String(describing: CreateCookbookIntent())",
                        "String(describing: RenameCookbookIntent())",
                        "String(describing: DeleteCookbookIntent())",
                        "String(describing: AddRecipeToCookbookIntent())",
                        "String(describing: RemoveRecipeFromCookbookIntent())"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "CreateCookbookIntent",
                    pattern: #"struct\s+CreateCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Title\")",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().createCookbook(title: title",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["var cookbookID: String", "@Parameter(title: \"Cookbook ID\")"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "RenameCookbookIntent",
                    pattern: #"struct\s+RenameCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Cookbook\", requestValueDialog:",
                        "var cookbook: SpoonjoyCookbookEntity",
                        "@Parameter(title: \"Title\")",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().renameCookbook(cookbook: cookbook.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["var cookbookID: String", "@Parameter(title: \"Cookbook ID\")"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "DeleteCookbookIntent",
                    pattern: #"struct\s+DeleteCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Cookbook\", requestValueDialog:",
                        "var cookbook: SpoonjoyCookbookEntity",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().deleteCookbook(cookbook: cookbook.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["var cookbookID: String", "@Parameter(title: \"Cookbook ID\")"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "AddRecipeToCookbookIntent",
                    pattern: #"struct\s+AddRecipeToCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "@Parameter(title: \"Cookbook\", requestValueDialog:",
                        "var cookbook: SpoonjoyCookbookEntity",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().addRecipeToCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["var recipeID: String", "var cookbookID: String", "@Parameter(title: \"Recipe ID\")", "@Parameter(title: \"Cookbook ID\")"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "RemoveRecipeFromCookbookIntent",
                    pattern: #"struct\s+RemoveRecipeFromCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "@Parameter(title: \"Cookbook\", requestValueDialog:",
                        "var cookbook: SpoonjoyCookbookEntity",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().removeRecipeFromCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["var recipeID: String", "var cookbookID: String", "@Parameter(title: \"Recipe ID\")", "@Parameter(title: \"Cookbook ID\")"]
                )
            ]
        ))

        failures.append(contentsOf: cookbookIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "createCookbook resolver",
                    pattern: #"public\s+func\s+createCookbook\("#,
                    requiredTokens: [
                        "try canonicalObjectID(currentChefID, invalidError: .authRequired)",
                        "let title = normalizedCookbookTitle(title)",
                        "guard !title.isEmpty else",
                        "throw NativeIntentActionError.emptyCookbookTitle",
                        ".cookbookCreate(",
                        "route: .cookbooks",
                        "DeepLinkURLBuilder.url(for: .cookbooks)"
                    ],
                    forbiddenTokens: ["cookbookID: String", "recipeID: String"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "renameCookbook resolver",
                    pattern: #"public\s+func\s+renameCookbook\("#,
                    requiredTokens: [
                        "let cookbookID = try cookbookIDForMutation(cookbook)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))",
                        "guard cookbook.chefID == chefID else",
                        "throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)",
                        "let title = normalizedCookbookTitle(title)",
                        "guard !title.isEmpty else",
                        "throw NativeIntentActionError.emptyCookbookTitle",
                        ".cookbookUpdate(",
                        "route: .cookbookDetail(id: cookbookID)"
                    ],
                    forbiddenTokens: ["cookbookID: String", "recipeID: String"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "deleteCookbook resolver",
                    pattern: #"public\s+func\s+deleteCookbook\("#,
                    requiredTokens: [
                        "let cookbookID = try cookbookIDForMutation(cookbook)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))",
                        "guard cookbook.chefID == chefID else",
                        "throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)",
                        ".cookbookDelete(",
                        "route: .cookbooks",
                        "DeepLinkURLBuilder.url(for: .cookbooks)"
                    ],
                    forbiddenTokens: ["cookbookID: String", "recipeID: String"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "addRecipeToCookbook resolver",
                    pattern: #"public\s+func\s+addRecipeToCookbook\("#,
                    requiredTokens: [
                        "let recipeID = try recipeIDForMutation(recipe)",
                        "let cookbookID = try cookbookIDForMutation(cookbook)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))",
                        "guard cookbook.chefID == chefID else",
                        "throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)",
                        ".cookbookAddRecipe(",
                        "route: .cookbookDetail(id: cookbookID)"
                    ],
                    forbiddenTokens: ["recipeID: String", "cookbookID: String"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "removeRecipeFromCookbook resolver",
                    pattern: #"public\s+func\s+removeRecipeFromCookbook\("#,
                    requiredTokens: [
                        "let recipeID = try recipeIDForMutation(recipe)",
                        "let cookbookID = try cookbookIDForMutation(cookbook)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .cookbookOwnershipRequired(cookbookID: cookbookID))",
                        "guard cookbook.chefID == chefID else",
                        "throw NativeIntentActionError.cookbookOwnershipRequired(cookbookID: cookbookID)",
                        ".cookbookRemoveRecipe(",
                        "route: .cookbookDetail(id: cookbookID)"
                    ],
                    forbiddenTokens: ["recipeID: String", "cookbookID: String"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "normalizedCookbookTitle helper",
                    pattern: #"private\s+func\s+normalizedCookbookTitle\("#,
                    requiredTokens: [
                        "trimmingCharacters(in: .whitespacesAndNewlines)"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("cookbook intent resolver queues exact owner-safe REST mutations")
    func cookbookIntentResolverQueuesExactOwnerSafeRESTMutations() throws {
        let resolver = NativeIntentActionResolver()
        let recipe = cookbookIntentRecipeDescriptor()
        let cookbook = cookbookIntentCookbookDescriptor()

        let createAction = try resolver.createCookbook(
            title: " Weeknight Joy ",
            currentChefID: " chef_ari ",
            createdAt: "2026-06-16T16:00:00.000Z"
        )
        let renameAction = try resolver.renameCookbook(
            cookbook: cookbook,
            title: " Dinner Parties ",
            currentChefID: "chef_ari",
            createdAt: "2026-06-16T16:01:00.000Z"
        )
        let deleteAction = try resolver.deleteCookbook(
            cookbook: cookbook,
            currentChefID: "chef_ari",
            createdAt: "2026-06-16T16:02:00.000Z"
        )
        let addAction = try resolver.addRecipeToCookbook(
            recipe: recipe,
            cookbook: cookbook,
            currentChefID: "chef_ari",
            createdAt: "2026-06-16T16:03:00.000Z"
        )
        let removeAction = try resolver.removeRecipeFromCookbook(
            recipe: recipe,
            cookbook: cookbook,
            currentChefID: "chef_ari",
            createdAt: "2026-06-16T16:04:00.000Z"
        )
        let saveAction = try resolver.saveRecipeToCookbook(
            recipe: recipe,
            cookbook: cookbook,
            currentChefID: "chef_ari",
            createdAt: "2026-06-16T16:05:00.000Z"
        )

        let createMutation = try #require(createAction.nativeQueuedMutation)
        let renameMutation = try #require(renameAction.nativeQueuedMutation)
        let deleteMutation = try #require(deleteAction.nativeQueuedMutation)
        let addMutation = try #require(addAction.nativeQueuedMutation)
        let removeMutation = try #require(removeAction.nativeQueuedMutation)
        let saveMutation = try #require(saveAction.nativeQueuedMutation)

        #expect(createAction.route == .cookbooks)
        #expect(createAction.url == URL(string: "spoonjoy://cookbooks"))
        #expect(createMutation.queueableKind == .cookbookCreate)
        #expect(createMutation.clientMutationID == "intent-cookbook-create-Weeknight-Joy-2026-06-16T16-00-00-000Z")
        try cookbookIntentAssertJSONRequest(
            try cookbookIntentRequest(from: createMutation),
            method: .post,
            path: "/api/v1/cookbooks",
            expected: [
                "clientMutationId": "intent-cookbook-create-Weeknight-Joy-2026-06-16T16-00-00-000Z",
                "title": "Weeknight Joy"
            ]
        )

        #expect(renameAction.route == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(renameAction.url == URL(string: "spoonjoy://cookbooks/cookbook_weeknights"))
        #expect(renameMutation.queueableKind == .cookbookUpdate)
        #expect(renameMutation.clientMutationID == "intent-cookbook-rename-cookbook_weeknights-2026-06-16T16-01-00-000Z")
        try cookbookIntentAssertJSONRequest(
            try cookbookIntentRequest(from: renameMutation),
            method: .patch,
            path: "/api/v1/cookbooks/cookbook_weeknights",
            expected: [
                "clientMutationId": "intent-cookbook-rename-cookbook_weeknights-2026-06-16T16-01-00-000Z",
                "title": "Dinner Parties"
            ]
        )

        #expect(deleteAction.route == .cookbooks)
        #expect(deleteAction.url == URL(string: "spoonjoy://cookbooks"))
        #expect(deleteMutation.queueableKind == .cookbookDelete)
        #expect(deleteMutation.clientMutationID == "intent-cookbook-delete-cookbook_weeknights-2026-06-16T16-02-00-000Z")
        cookbookIntentAssertNoBodyRequest(
            try cookbookIntentRequest(from: deleteMutation),
            method: .delete,
            path: "/api/v1/cookbooks/cookbook_weeknights",
            queryItems: [
                URLQueryItem(
                    name: "clientMutationId",
                    value: "intent-cookbook-delete-cookbook_weeknights-2026-06-16T16-02-00-000Z"
                )
            ]
        )

        #expect(addAction.route == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(addAction.url == URL(string: "spoonjoy://cookbooks/cookbook_weeknights"))
        #expect(addMutation.queueableKind == .cookbookAddRecipe)
        #expect(addMutation.clientMutationID == "intent-cookbook-add-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T16-03-00-000Z")
        try cookbookIntentAssertJSONRequest(
            try cookbookIntentRequest(from: addMutation),
            method: .post,
            path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta",
            expected: [
                "clientMutationId": "intent-cookbook-add-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T16-03-00-000Z"
            ]
        )

        #expect(removeAction.route == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(removeAction.url == URL(string: "spoonjoy://cookbooks/cookbook_weeknights"))
        #expect(removeMutation.queueableKind == .cookbookRemoveRecipe)
        #expect(removeMutation.clientMutationID == "intent-cookbook-remove-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T16-04-00-000Z")
        try cookbookIntentAssertJSONRequest(
            try cookbookIntentRequest(from: removeMutation),
            method: .delete,
            path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta",
            expected: [
                "clientMutationId": "intent-cookbook-remove-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T16-04-00-000Z"
            ]
        )

        #expect(saveAction.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(saveAction.url == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta"))
        #expect(saveMutation.queueableKind == .cookbookAddRecipe)
        #expect(saveMutation.clientMutationID == "intent-cookbook-save-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T16-05-00-000Z")
        try cookbookIntentAssertJSONRequest(
            try cookbookIntentRequest(from: saveMutation),
            method: .post,
            path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta",
            expected: [
                "clientMutationId": "intent-cookbook-save-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T16-05-00-000Z"
            ]
        )
    }

    @Test("cookbook intent resolver rejects unresolved unsafe empty and non-owner mutations")
    func cookbookIntentResolverRejectsUnresolvedUnsafeEmptyAndNonOwnerMutations() throws {
        let resolver = NativeIntentActionResolver()
        let recipe = cookbookIntentRecipeDescriptor()
        let cookbook = cookbookIntentCookbookDescriptor()

        #expect(throws: NativeIntentActionError.authRequired) {
            try resolver.createCookbook(title: "Weeknights", currentChefID: "bad/chef", createdAt: "2026-06-16T16:10:00.000Z")
        }
        #expect(throws: NativeIntentActionError.emptyCookbookTitle) {
            try resolver.createCookbook(title: " \n ", currentChefID: "chef_ari", createdAt: "2026-06-16T16:11:00.000Z")
        }
        #expect(throws: NativeIntentActionError.unresolvedCookbookEntity) {
            try resolver.renameCookbook(cookbook: .placeholder, title: "Dinner", currentChefID: "chef_ari", createdAt: "2026-06-16T16:12:00.000Z")
        }
        #expect(throws: NativeIntentActionError.invalidCookbookID("cookbook_weeknights")) {
            try resolver.deleteCookbook(
                cookbook: cookbookIntentCookbookDescriptor(route: .cookbooks),
                currentChefID: "chef_ari",
                createdAt: "2026-06-16T16:13:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.invalidRecipeID("bad/recipe")) {
            try resolver.addRecipeToCookbook(
                recipe: cookbookIntentRecipeDescriptor(id: "bad/recipe", route: .recipeDetail(id: "bad/recipe", presentation: .detail)),
                cookbook: cookbook,
                currentChefID: "chef_ari",
                createdAt: "2026-06-16T16:14:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.cookbookOwnershipRequired(cookbookID: "cookbook_weeknights")) {
            try resolver.renameCookbook(cookbook: cookbook, title: "Dinner", currentChefID: "chef_jules", createdAt: "2026-06-16T16:15:00.000Z")
        }
        #expect(throws: NativeIntentActionError.cookbookOwnershipRequired(cookbookID: "cookbook_weeknights")) {
            try resolver.deleteCookbook(cookbook: cookbook, currentChefID: "chef_jules", createdAt: "2026-06-16T16:16:00.000Z")
        }
        #expect(throws: NativeIntentActionError.cookbookOwnershipRequired(cookbookID: "cookbook_weeknights")) {
            try resolver.addRecipeToCookbook(recipe: recipe, cookbook: cookbook, currentChefID: "chef_jules", createdAt: "2026-06-16T16:17:00.000Z")
        }
        #expect(throws: NativeIntentActionError.cookbookOwnershipRequired(cookbookID: "cookbook_weeknights")) {
            try resolver.removeRecipeFromCookbook(recipe: recipe, cookbook: cookbook, currentChefID: "chef_jules", createdAt: "2026-06-16T16:18:00.000Z")
        }
        #expect(throws: NativeIntentActionError.cookbookOwnershipRequired(cookbookID: "cookbook_weeknights")) {
            try resolver.saveRecipeToCookbook(recipe: recipe, cookbook: cookbook, currentChefID: "chef_jules", createdAt: "2026-06-16T16:19:00.000Z")
        }
    }
}

private let cookbookIntentConfiguration = APIClientConfiguration(
    baseURL: URL(string: "https://spoonjoy.app")!,
    bearerToken: "sj_private_token"
)

private func cookbookIntentRecipeDescriptor(
    id: String = "recipe_lemon_pantry_pasta",
    chefID: String = "chef_ari",
    route: AppRoute? = nil
) -> RecipeEntityDescriptor {
    let route = route ?? .recipeDetail(id: id, presentation: .detail)
    let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
    return RecipeEntityDescriptor(
        id: id,
        title: "Lemon Pantry Pasta",
        chefID: chefID,
        chefUsername: "ari",
        subtitle: "ari - 4 servings",
        disambiguationLabel: "Lemon Pantry Pasta by ari",
        route: route,
        canonicalURL: canonicalURL,
        imageURL: URL(string: "https://spoonjoy.app/photos/lemon-pasta.jpg"),
        transferValue: RecipeCookbookEntityTransferValue(
            kind: .recipe,
            id: id,
            title: "Lemon Pantry Pasta",
            chefUsername: "ari",
            routeIdentifier: route.stateIdentifier,
            canonicalURL: canonicalURL,
            imageURL: URL(string: "https://spoonjoy.app/photos/lemon-pasta.jpg"),
            userVisibleSummary: "Lemon Pantry Pasta by ari"
        )
    )
}

private func cookbookIntentCookbookDescriptor(
    id: String = "cookbook_weeknights",
    chefID: String = "chef_ari",
    route: AppRoute? = nil
) -> CookbookEntityDescriptor {
    let route = route ?? .cookbookDetail(id: id)
    let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)")!
    return CookbookEntityDescriptor(
        id: id,
        title: "Weeknights",
        chefID: chefID,
        chefUsername: "ari",
        subtitle: "ari - 12 recipes",
        disambiguationLabel: "Weeknights by ari",
        route: route,
        canonicalURL: canonicalURL,
        imageURL: URL(string: "https://spoonjoy.app/photos/weeknights.jpg"),
        recipeCount: 12,
        transferValue: RecipeCookbookEntityTransferValue(
            kind: .cookbook,
            id: id,
            title: "Weeknights",
            chefUsername: "ari",
            routeIdentifier: route.stateIdentifier,
            canonicalURL: canonicalURL,
            imageURL: URL(string: "https://spoonjoy.app/photos/weeknights.jpg"),
            userVisibleSummary: "Weeknights by ari"
        )
    )
}

private func cookbookIntentRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: cookbookIntentConfiguration)
}

private func cookbookIntentAssertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any]
) throws {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems.isEmpty)
    #expect(request.headers == [
        "Accept": "application/json",
        "Authorization": "Bearer sj_private_token",
        "Content-Type": "application/json"
    ])
    #expect(request.responseCachePolicy == .privateNoStore)
    #expect(NSDictionary(dictionary: try cookbookIntentJSONBody(from: request)).isEqual(to: expected))
}

private func cookbookIntentAssertNoBodyRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    queryItems: [URLQueryItem]
) {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems == queryItems)
    #expect(request.headers == [
        "Accept": "application/json",
        "Authorization": "Bearer sj_private_token"
    ])
    #expect(request.body == nil)
    #expect(request.responseCachePolicy == .privateNoStore)
}

private func cookbookIntentJSONBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private func cookbookIntentForbiddenProductTokens() -> [String] {
    [
        "@Parameter(title: \"Recipe ID\")",
        "@Parameter(title: \"Cookbook ID\")",
        "var recipeID: String",
        "var cookbookID: String",
        "String-only cookbook App Intent",
        "CommentIntent",
        "FeedIntent",
        "MessageIntent",
        "MailIntent",
        "social-feed",
        "/comments",
        "/feeds",
        "/messages",
        "mailto:",
        "MessageUI",
        "TODO CookbookIntent",
        "eventually add cookbook intents"
    ]
}

private func cookbookIntentSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? cookbookIntentReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = cookbookIntentUncommentedSource(content, relativePath: relativePath)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func cookbookIntentShortcutBudgetFailures(
    relativePath: String,
    maximumShortcuts: Int,
    libraryOnlyIntentNames: [String]
) -> [String] {
    guard let content = try? cookbookIntentReadRepoFile(relativePath) else {
        return ["missing \(relativePath)"]
    }
    let uncommented = cookbookIntentUncommentedSwift(content)
    let shortcutCount = uncommented.components(separatedBy: "AppShortcut(").count - 1
    var failures: [String] = []
    if shortcutCount > maximumShortcuts {
        failures.append("\(relativePath) declares \(shortcutCount) App Shortcuts, above Apple limit \(maximumShortcuts)")
    }

    if let body = cookbookIntentDeclarationBody(in: uncommented, pattern: #"struct\s+SpoonjoyAppShortcuts\s*:\s*AppShortcutsProvider"#) {
        for intentName in libraryOnlyIntentNames where body.contains("\(intentName)(") {
            failures.append("\(relativePath) promotes library-only \(intentName) into AppShortcuts")
        }
    } else {
        failures.append("\(relativePath) missing body for SpoonjoyAppShortcuts")
    }
    return failures
}

private func cookbookIntentBodyContractFailures(
    contracts: [(
        relativePath: String,
        label: String,
        pattern: String,
        requiredTokens: [String],
        forbiddenTokens: [String]
    )]
) -> [String] {
    var failures: [String] = []
    for contract in contracts {
        guard let content = try? cookbookIntentReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = cookbookIntentUncommentedSource(content, relativePath: contract.relativePath)
        guard let body = cookbookIntentDeclarationBody(in: uncommented, pattern: contract.pattern) else {
            failures.append("\(contract.relativePath) missing body for \(contract.label)")
            continue
        }
        for token in contract.requiredTokens where !body.contains(token) {
            failures.append("\(contract.relativePath) \(contract.label) missing \(token)")
        }
        for token in contract.forbiddenTokens where body.contains(token) {
            failures.append("\(contract.relativePath) \(contract.label) contains forbidden \(token)")
        }
    }
    return failures
}

private func cookbookIntentReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func cookbookIntentDeclarationBody(in content: String, pattern: String) -> String? {
    guard let declarationRange = content.range(of: pattern, options: .regularExpression),
          let openBrace = content[declarationRange.upperBound...].firstIndex(of: "{")
    else {
        return nil
    }

    var depth = 0
    var index = openBrace
    while index < content.endIndex {
        let character = content[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return String(content[content.index(after: openBrace)..<index])
            }
        }
        index = content.index(after: index)
    }

    return nil
}

private func cookbookIntentUncommentedSource(_ content: String, relativePath: String) -> String {
    relativePath.hasSuffix(".swift") ? cookbookIntentUncommentedSwift(content) : content
}

private func cookbookIntentUncommentedSwift(_ content: String) -> String {
    var output = ""
    var index = content.startIndex
    var inString = false
    var escaping = false

    while index < content.endIndex {
        let character = content[index]
        let nextIndex = content.index(after: index)

        if inString {
            output.append(character)
            if escaping {
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                inString = false
            }
            index = nextIndex
            continue
        }

        if character == "\"" {
            inString = true
            output.append(character)
            index = nextIndex
            continue
        }

        if character == "/", nextIndex < content.endIndex {
            let nextCharacter = content[nextIndex]
            if nextCharacter == "/" {
                index = nextIndex
                while index < content.endIndex, content[index] != "\n" {
                    index = content.index(after: index)
                }
                if index < content.endIndex {
                    output.append(content[index])
                    index = content.index(after: index)
                }
                continue
            }
            if nextCharacter == "*" {
                index = content.index(after: nextIndex)
                while index < content.endIndex {
                    let maybeEnd = content[index]
                    let afterMaybeEnd = content.index(after: index)
                    if maybeEnd == "*", afterMaybeEnd < content.endIndex, content[afterMaybeEnd] == "/" {
                        index = content.index(after: afterMaybeEnd)
                        break
                    }
                    index = afterMaybeEnd
                }
                continue
            }
        }

        output.append(character)
        index = nextIndex
    }

    return output
}
