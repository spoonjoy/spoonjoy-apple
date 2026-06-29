import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe action Siri intent contracts")
struct RecipeActionIntentTests {
    @Test("recipe action Siri intents require entity-backed queueable actions")
    func recipeActionSiriIntentsRequireEntityBackedQueueableActions() throws {
        var failures = recipeActionIntentSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct ForkRecipeIntent: AppIntent",
                    "struct SaveRecipeToCookbookIntent: AppIntent",
                    "struct RemoveRecipeFromCookbookIntent: AppIntent",
                    "struct DeleteRecipeIntent: AppIntent",
                    "struct AddRecipeIngredientsToShoppingListIntent: AppIntent",
                    "var recipe: SpoonjoyRecipeEntity",
                    "var cookbook: SpoonjoyCookbookEntity",
                    "SpoonjoyIntentStateWriter",
                    "SpoonjoyIntentClock.timestamp()",
                    "SpoonjoyInteractionDonor",
                    "throw NativeIntentActionError.authRequired",
                    "String(describing: ForkRecipeIntent())",
                    "String(describing: SaveRecipeToCookbookIntent())",
                    "String(describing: RemoveRecipeFromCookbookIntent())",
                    "String(describing: DeleteRecipeIntent())"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift": [
                    "struct SpoonjoyRecipeEntity: AppEntity",
                    "struct SpoonjoyCookbookEntity: AppEntity",
                    "resolvedRecipeID() throws",
                    "NativeIntentActionError.unresolvedRecipeEntity"
                ],
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift": [
                    "public let chefID: String",
                    "chefID: recipe.chef.id",
                    "chefID: \"chef-placeholder\""
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "public func forkRecipe(",
                    "public func saveRecipeToCookbook(",
                    "public func removeRecipeFromCookbook(",
                    "public func deleteRecipe(",
                    "currentChefID: String",
                    "NativeIntentActionError.recipeOwnershipRequired",
                    ".recipeFork",
                    ".cookbookAddRecipe",
                    ".cookbookRemoveRecipe",
                    ".recipeDelete",
                    ".shoppingAddFromRecipe",
                    "DeepLinkURLBuilder.url(for:"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "ForkRecipeIntent",
                    "SaveRecipeToCookbookIntent",
                    "RemoveRecipeFromCookbookIntent",
                    "DeleteRecipeIntent",
                    "AddRecipeIngredientsToShoppingListIntent"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Recipe action Siri intents",
                    "ForkRecipeIntent",
                    "SaveRecipeToCookbookIntent",
                    "RemoveRecipeFromCookbookIntent",
                    "DeleteRecipeIntent",
                    "AddRecipeIngredientsToShoppingListIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Recipe ID\")",
                    "@Parameter(title: \"Cookbook ID\")",
                    "var recipeID: String",
                    "var cookbookID: String",
                    "String-only recipe action App Intent",
                    "CommentIntent",
                    "MessageIntent",
                    "MailIntent",
                    "social-feed",
                    "/comments",
                    "/messages",
                    "TODO RecipeActionIntent"
                ]
            ]
        )

        failures.append(contentsOf: recipeActionIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ForkRecipeIntent",
                    pattern: #"struct\s+ForkRecipeIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "@Parameter(title: \"Title\")",
                        "NativeIntentActionResolver().forkRecipe(recipe: recipe.descriptor",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "@Parameter(title: \"Recipe ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SaveRecipeToCookbookIntent",
                    pattern: #"struct\s+SaveRecipeToCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "@Parameter(title: \"Cookbook\", requestValueDialog:",
                        "var cookbook: SpoonjoyCookbookEntity",
                        "NativeIntentActionResolver().saveRecipeToCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "var cookbookID: String",
                        "@Parameter(title: \"Cookbook ID\")"
                    ]
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
                        "NativeIntentActionResolver().removeRecipeFromCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "var cookbookID: String",
                        "@Parameter(title: \"Recipe ID\")",
                        "@Parameter(title: \"Cookbook ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "AddRecipeIngredientsToShoppingListIntent",
                    pattern: #"struct\s+AddRecipeIngredientsToShoppingListIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "@Parameter(title: \"Scale Factor\")",
                        "try recipe.resolvedRecipeID()",
                        "NativeIntentActionResolver().addRecipeIngredientsToShoppingList(",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "@Parameter(title: \"Recipe ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "DeleteRecipeIntent",
                    pattern: #"struct\s+DeleteRecipeIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "NativeIntentActionResolver().deleteRecipe(recipe: recipe.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "@Parameter(title: \"Recipe ID\")"
                    ]
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("recipe action intent resolver queues UI-compatible offline mutations")
    func recipeActionIntentResolverQueuesUICompatibleOfflineMutations() throws {
        let resolver = NativeIntentActionResolver()
        let recipe = recipeActionIntentRecipeDescriptor()
        let cookbook = recipeActionIntentCookbookDescriptor()

        let forkAction = try resolver.forkRecipe(
            recipe: recipe,
            title: "   ",
            createdAt: "2026-06-16T15:00:00.000Z"
        )
        let titledForkAction = try resolver.forkRecipe(
            recipe: recipe,
            title: " My Weeknight Version ",
            createdAt: "2026-06-16T15:01:00.000Z"
        )
        let saveAction = try resolver.saveRecipeToCookbook(
            recipe: recipe,
            cookbook: cookbook,
            createdAt: "2026-06-16T15:02:00.000Z"
        )
        let removeAction = try resolver.removeRecipeFromCookbook(
            recipe: recipe,
            cookbook: cookbook,
            createdAt: "2026-06-16T15:03:00.000Z"
        )
        let deleteAction = try resolver.deleteRecipe(
            recipe: recipe,
            currentChefID: " chef_ari ",
            createdAt: "2026-06-16T15:04:00.000Z"
        )

        let forkMutation = try #require(forkAction.nativeQueuedMutation)
        let titledForkMutation = try #require(titledForkAction.nativeQueuedMutation)
        let saveMutation = try #require(saveAction.nativeQueuedMutation)
        let removeMutation = try #require(removeAction.nativeQueuedMutation)
        let deleteMutation = try #require(deleteAction.nativeQueuedMutation)

        #expect(forkAction.queuedMutation == nil)
        #expect(forkAction.route == .recipes)
        #expect(forkAction.url == URL(string: "spoonjoy://recipes"))
        #expect(forkMutation.queueableKind == .recipeFork)
        #expect(forkMutation.clientMutationID == "intent-recipe-fork-recipe_lemon_pantry_pasta-2026-06-16T15-00-00-000Z")
        #expect(forkMutation.createdAt == "2026-06-16T15:00:00.000Z")
        try recipeActionIntentAssertJSONRequest(
            try recipeActionIntentRequest(from: forkMutation),
            method: .post,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta/fork",
            expected: [
                "clientMutationId": "intent-recipe-fork-recipe_lemon_pantry_pasta-2026-06-16T15-00-00-000Z",
                "title": "Lemon Pantry Pasta, my version"
            ]
        )

        #expect(titledForkMutation.queueableKind == .recipeFork)
        try recipeActionIntentAssertJSONRequest(
            try recipeActionIntentRequest(from: titledForkMutation),
            method: .post,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta/fork",
            expected: [
                "clientMutationId": "intent-recipe-fork-recipe_lemon_pantry_pasta-2026-06-16T15-01-00-000Z",
                "title": "My Weeknight Version"
            ]
        )

        #expect(saveAction.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(saveAction.url == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta"))
        #expect(saveMutation.queueableKind == .cookbookAddRecipe)
        #expect(saveMutation.clientMutationID == "intent-cookbook-save-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T15-02-00-000Z")
        try recipeActionIntentAssertJSONRequest(
            try recipeActionIntentRequest(from: saveMutation),
            method: .post,
            path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta",
            expected: [
                "clientMutationId": "intent-cookbook-save-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T15-02-00-000Z"
            ]
        )

        #expect(removeAction.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(removeAction.url == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta"))
        #expect(removeMutation.queueableKind == .cookbookRemoveRecipe)
        #expect(removeMutation.clientMutationID == "intent-cookbook-remove-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T15-03-00-000Z")
        try recipeActionIntentAssertJSONRequest(
            try recipeActionIntentRequest(from: removeMutation),
            method: .delete,
            path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta",
            expected: [
                "clientMutationId": "intent-cookbook-remove-cookbook_weeknights-recipe_lemon_pantry_pasta-2026-06-16T15-03-00-000Z"
            ]
        )

        #expect(deleteAction.route == .recipes)
        #expect(deleteAction.url == URL(string: "spoonjoy://recipes"))
        #expect(deleteMutation.queueableKind == .recipeDelete)
        #expect(deleteMutation.clientMutationID == "intent-recipe-delete-recipe_lemon_pantry_pasta-2026-06-16T15-04-00-000Z")
        recipeActionIntentAssertNoBodyRequest(
            try recipeActionIntentRequest(from: deleteMutation),
            method: .delete,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta",
            queryItems: [
                URLQueryItem(
                    name: "clientMutationId",
                    value: "intent-recipe-delete-recipe_lemon_pantry_pasta-2026-06-16T15-04-00-000Z"
                )
            ]
        )
    }

    @Test("recipe action intent resolver rejects unresolved unsafe and non-owner entities")
    func recipeActionIntentResolverRejectsUnresolvedUnsafeAndNonOwnerEntities() throws {
        let resolver = NativeIntentActionResolver()
        let recipe = recipeActionIntentRecipeDescriptor()
        let cookbook = recipeActionIntentCookbookDescriptor()

        #expect(throws: NativeIntentActionError.unresolvedRecipeEntity) {
            try resolver.forkRecipe(recipe: .placeholder, title: "Draft", createdAt: "2026-06-16T15:10:00.000Z")
        }
        #expect(throws: NativeIntentActionError.unresolvedCookbookEntity) {
            try resolver.saveRecipeToCookbook(recipe: recipe, cookbook: .placeholder, createdAt: "2026-06-16T15:11:00.000Z")
        }
        #expect(throws: NativeIntentActionError.invalidRecipeID("recipe_lemon_pantry_pasta")) {
            try resolver.saveRecipeToCookbook(
                recipe: recipeActionIntentRecipeDescriptor(route: .recipes),
                cookbook: cookbook,
                createdAt: "2026-06-16T15:12:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.invalidRecipeID("bad/recipe")) {
            try resolver.removeRecipeFromCookbook(
                recipe: recipeActionIntentRecipeDescriptor(id: "bad/recipe", route: .recipeDetail(id: "bad/recipe", presentation: .detail)),
                cookbook: cookbook,
                createdAt: "2026-06-16T15:13:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.invalidCookbookID("cookbook_weeknights")) {
            try resolver.saveRecipeToCookbook(
                recipe: recipe,
                cookbook: recipeActionIntentCookbookDescriptor(route: .cookbooks),
                createdAt: "2026-06-16T15:14:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.invalidCookbookID("bad/cookbook")) {
            try resolver.removeRecipeFromCookbook(
                recipe: recipe,
                cookbook: recipeActionIntentCookbookDescriptor(id: "bad/cookbook", route: .cookbookDetail(id: "bad/cookbook")),
                createdAt: "2026-06-16T15:15:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.recipeOwnershipRequired(recipeID: "recipe_lemon_pantry_pasta")) {
            try resolver.deleteRecipe(
                recipe: recipe,
                currentChefID: "chef_jules",
                createdAt: "2026-06-16T15:16:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.recipeOwnershipRequired(recipeID: "recipe_lemon_pantry_pasta")) {
            try resolver.deleteRecipe(
                recipe: recipe,
                currentChefID: "bad/chef",
                createdAt: "2026-06-16T15:17:00.000Z"
            )
        }
    }
}

private let recipeActionIntentConfiguration = APIClientConfiguration(
    baseURL: URL(string: "https://spoonjoy.app")!,
    bearerToken: "sj_private_token"
)

private func recipeActionIntentRecipeDescriptor(
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

private func recipeActionIntentCookbookDescriptor(
    id: String = "cookbook_weeknights",
    route: AppRoute? = nil
) -> CookbookEntityDescriptor {
    let route = route ?? .cookbookDetail(id: id)
    let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)")!
    return CookbookEntityDescriptor(
        id: id,
        title: "Weeknights",
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

private func recipeActionIntentRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: recipeActionIntentConfiguration)
}

private func recipeActionIntentAssertJSONRequest(
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
    #expect(NSDictionary(dictionary: try recipeActionIntentJSONBody(from: request)).isEqual(to: expected))
}

private func recipeActionIntentAssertNoBodyRequest(
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

private func recipeActionIntentJSONBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private func recipeActionIntentSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? recipeActionIntentReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = recipeActionIntentUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func recipeActionIntentBodyContractFailures(
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
        guard let content = try? recipeActionIntentReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = recipeActionIntentUncommentedSwift(content)
        guard let body = recipeActionIntentDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func recipeActionIntentReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func recipeActionIntentDeclarationBody(in content: String, pattern: String) -> String? {
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

private func recipeActionIntentUncommentedSwift(_ content: String) -> String {
    var output = ""
    var index = content.startIndex
    var inString = false
    var escaping = false

    while index < content.endIndex {
        let character = content[index]
        let next = content.index(after: index)
        let nextCharacter = next < content.endIndex ? content[next] : nil

        if inString {
            output.append(character)
            if escaping {
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                inString = false
            }
            index = next
            continue
        }

        if character == "\"" {
            inString = true
            output.append(character)
            index = next
            continue
        }

        if character == "/", nextCharacter == "/" {
            index = next
            while index < content.endIndex, content[index] != "\n" {
                index = content.index(after: index)
            }
            if index < content.endIndex {
                output.append(content[index])
                index = content.index(after: index)
            }
            continue
        }

        if character == "/", nextCharacter == "*" {
            index = content.index(after: next)
            while index < content.endIndex {
                let blockNext = content.index(after: index)
                if content[index] == "*", blockNext < content.endIndex, content[blockNext] == "/" {
                    index = content.index(after: blockNext)
                    break
                }
                index = blockNext
            }
            continue
        }

        output.append(character)
        index = next
    }

    return output
}
