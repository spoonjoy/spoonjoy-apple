import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Spoon cook-log Siri intent contracts")
struct SpoonIntentTests {
    @Test("spoon Siri intents require entity-backed queueable actions")
    func spoonSiriIntentsRequireEntityBackedQueueableActions() throws {
        var failures = spoonIntentSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                "Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift",
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct LogCookIntent: AppIntent",
                    "struct EditCookLogIntent: AppIntent",
                    "struct DeleteCookLogIntent: AppIntent",
                    "struct CreateCoverFromSpoonIntent: AppIntent",
                    "var recipe: SpoonjoyRecipeEntity",
                    "var spoon: SpoonjoySpoonEntity",
                    "SpoonjoyIntentStateWriter",
                    "SpoonjoyIntentClock.timestamp()",
                    "SpoonjoyInteractionDonor",
                    "throw NativeIntentActionError.authRequired",
                    "String(describing: LogCookIntent())",
                    "String(describing: EditCookLogIntent())",
                    "String(describing: DeleteCookLogIntent())",
                    "String(describing: CreateCoverFromSpoonIntent())"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift": [
                    "struct SpoonjoySpoonEntity: AppEntity",
                    "struct SpoonjoySpoonEntityQuery: EntityQuery, EntityStringQuery",
                    "resolvedSpoonID() throws",
                    "NativeIntentActionError.unresolvedSpoonEntity"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift": [
                    "struct SpoonjoyRecipeEntity: AppEntity",
                    "resolvedRecipeID() throws",
                    "NativeIntentActionError.unresolvedRecipeEntity"
                ],
                "Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift": [
                    "public let chefID: String",
                    "chefID: spoon.chefID",
                    "chefID: \"chef-placeholder\""
                ],
                "Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift": [
                    "public let chefID: String",
                    "chefID: recipe.chef.id"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "public func logCook(",
                    "public func editCookLog(",
                    "public func deleteCookLog(",
                    "public func createCoverFromSpoon(",
                    "currentChefID: String",
                    "NativeIntentActionError.spoonOwnershipRequired",
                    "NativeIntentActionError.recipeOwnershipRequired",
                    ".spoonCreate",
                    ".spoonUpdate",
                    ".spoonDelete",
                    ".coverFromSpoon",
                    "DeepLinkURLBuilder.url(for:"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "LogCookIntent",
                    "EditCookLogIntent",
                    "DeleteCookLogIntent",
                    "CreateCoverFromSpoonIntent"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Spoon cook-log Siri intents",
                    "LogCookIntent",
                    "EditCookLogIntent",
                    "DeleteCookLogIntent",
                    "CreateCoverFromSpoonIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Spoon ID\")",
                    "@Parameter(title: \"Recipe ID\")",
                    "var spoonID: String",
                    "var recipeID: String",
                    "String-only spoon App Intent",
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
                    "TODO SpoonIntent",
                    "eventually add spoon intents"
                ]
            ]
        )

        failures.append(contentsOf: spoonIntentShortcutBudgetFailures(
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            maximumShortcuts: 10,
            libraryOnlyIntentNames: [
                "LogCookIntent",
                "EditCookLogIntent",
                "DeleteCookLogIntent",
                "CreateCoverFromSpoonIntent"
            ]
        ))

        failures.append(contentsOf: spoonIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentShortcutBudget",
                    pattern: #"private\s+enum\s+SpoonjoyIntentShortcutBudget"#,
                    requiredTokens: [
                        "String(describing: LogCookIntent())",
                        "String(describing: EditCookLogIntent())",
                        "String(describing: DeleteCookLogIntent())",
                        "String(describing: CreateCoverFromSpoonIntent())"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "LogCookIntent",
                    pattern: #"struct\s+LogCookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "@Parameter(title: \"Note\")",
                        "@Parameter(title: \"Next Time\")",
                        "@Parameter(title: \"Cooked At\")",
                        "NativeIntentActionResolver().logCook(recipe: recipe.descriptor",
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
                    label: "EditCookLogIntent",
                    pattern: #"struct\s+EditCookLogIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Cook Log\", requestValueDialog:",
                        "var spoon: SpoonjoySpoonEntity",
                        "@Parameter(title: \"Note\")",
                        "@Parameter(title: \"Next Time\")",
                        "@Parameter(title: \"Cooked At\")",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "NativeIntentActionResolver().editCookLog(spoon: spoon.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var spoonID: String",
                        "@Parameter(title: \"Spoon ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "DeleteCookLogIntent",
                    pattern: #"struct\s+DeleteCookLogIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Cook Log\", requestValueDialog:",
                        "var spoon: SpoonjoySpoonEntity",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "NativeIntentActionResolver().deleteCookLog(spoon: spoon.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var spoonID: String",
                        "@Parameter(title: \"Spoon ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "CreateCoverFromSpoonIntent",
                    pattern: #"struct\s+CreateCoverFromSpoonIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "@Parameter(title: \"Cook Log\", requestValueDialog:",
                        "var spoon: SpoonjoySpoonEntity",
                        "@Parameter(title: \"Activate\")",
                        "@Parameter(title: \"Generate Editorial\")",
                        "try await requestConfirmation(",
                        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
                        "NativeIntentActionResolver().createCoverFromSpoon(recipe: recipe.descriptor, spoon: spoon.descriptor",
                        "currentChefID: currentChefID",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "var spoonID: String",
                        "@Parameter(title: \"Recipe ID\")",
                        "@Parameter(title: \"Spoon ID\")"
                    ]
                )
            ]
        ))

        failures.append(contentsOf: spoonIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "logCook resolver",
                    pattern: #"public\s+func\s+logCook\("#,
                    requiredTokens: [
                        "let recipeID = try recipeIDForMutation(recipe)",
                        ".spoonCreate(",
                        "route: .recipeDetail(id: recipeID, presentation: .detail)",
                        "DeepLinkURLBuilder.url(for: route)"
                    ],
                    forbiddenTokens: [
                        "recipeID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "editCookLog resolver",
                    pattern: #"public\s+func\s+editCookLog\("#,
                    requiredTokens: [
                        "let spoonID = try spoonIDForMutation(spoon)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .spoonOwnershipRequired(spoonID: spoonID))",
                        "guard spoon.chefID == chefID else",
                        "throw NativeIntentActionError.spoonOwnershipRequired(spoonID: spoonID)",
                        ".spoonUpdate("
                    ],
                    forbiddenTokens: [
                        "spoonID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "deleteCookLog resolver",
                    pattern: #"public\s+func\s+deleteCookLog\("#,
                    requiredTokens: [
                        "let spoonID = try spoonIDForMutation(spoon)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .spoonOwnershipRequired(spoonID: spoonID))",
                        "guard spoon.chefID == chefID else",
                        "throw NativeIntentActionError.spoonOwnershipRequired(spoonID: spoonID)",
                        ".spoonDelete("
                    ],
                    forbiddenTokens: [
                        "spoonID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "createCoverFromSpoon resolver",
                    pattern: #"public\s+func\s+createCoverFromSpoon\("#,
                    requiredTokens: [
                        "let recipeID = try recipeIDForMutation(recipe)",
                        "let spoonID = try spoonIDForMutation(spoon)",
                        "let chefID = try canonicalObjectID(currentChefID, invalidError: .recipeOwnershipRequired(recipeID: recipeID))",
                        "guard recipe.chefID == chefID else",
                        "throw NativeIntentActionError.recipeOwnershipRequired(recipeID: recipeID)",
                        "guard spoon.recipeID == recipeID else",
                        "throw NativeIntentActionError.invalidRecipeID(spoon.recipeID)",
                        ".coverFromSpoon("
                    ],
                    forbiddenTokens: [
                        "recipeID: String",
                        "spoonID: String"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "spoonIDForMutation helper",
                    pattern: #"private\s+func\s+spoonIDForMutation\("#,
                    requiredTokens: [
                        "guard !spoon.isPlaceholder else",
                        "throw NativeIntentActionError.unresolvedSpoonEntity",
                        "let spoonID = try canonicalObjectID(spoon.spoonID, invalidError: .invalidSpoonID(spoon.spoonID))",
                        "let recipeID = try canonicalRecipeID(spoon.recipeID)",
                        "guard spoon.route == .recipeDetail(id: recipeID, presentation: .detail) else",
                        "return spoonID"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("spoon intent resolver preserves cook-log fields and requires cover photos")
    func spoonIntentResolverPreservesCookLogFieldsAndRequiresCoverPhotos() throws {
        let resolver = NativeIntentActionResolver()
        let recipe = spoonIntentRecipeDescriptor()
        let photographedSpoon = spoonIntentSpoonDescriptor()
        let coverlessSpoon = spoonIntentSpoonDescriptor(photoURL: nil)

        let logAction = try resolver.logCook(
            recipe: recipe,
            note: nil,
            nextTime: nil,
            cookedAt: nil,
            createdAt: "2026-06-29T15:00:00.000Z"
        )
        let logMutation = try #require(logAction.nativeQueuedMutation)
        #expect(logMutation.queueableKind == .spoonCreate)
        #expect(logAction.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        try spoonIntentAssertJSONRequest(
            try spoonIntentRequest(from: logMutation),
            method: .post,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta/spoons",
            expected: [
                "clientMutationId": "intent-spoon-log-recipe_lemon_pantry_pasta-2026-06-29T15-00-00-000Z",
                "note": NSNull(),
                "nextTime": NSNull(),
                "cookedAt": "2026-06-29T15:00:00.000Z",
                "photoUrl": NSNull(),
                "useAsRecipeCover": false
            ]
        )

        let editAction = try resolver.editCookLog(
            spoon: photographedSpoon,
            note: "  Updated after Siri  ",
            nextTime: nil,
            cookedAt: nil,
            currentChefID: " chef_ari ",
            createdAt: "2026-06-29T15:01:00.000Z"
        )
        let editMutation = try #require(editAction.nativeQueuedMutation)
        #expect(editMutation.queueableKind == .spoonUpdate)
        try spoonIntentAssertJSONRequest(
            try spoonIntentRequest(from: editMutation),
            method: .patch,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta/spoons/spoon_ari_lemon",
            expected: [
                "clientMutationId": "intent-spoon-edit-spoon_ari_lemon-2026-06-29T15-01-00-000Z",
                "note": "Updated after Siri",
                "nextTime": "Use more lemon zest.",
                "cookedAt": "2026-06-01T10:00:00.000Z",
                "photoUrl": "https://spoonjoy.app/photos/spoons/spoon_ari_lemon.jpg"
            ]
        )

        #expect(throws: NativeIntentActionError.spoonPhotoRequired(spoonID: "spoon_ari_lemon")) {
            try resolver.createCoverFromSpoon(
                recipe: recipe,
                spoon: coverlessSpoon,
                activate: true,
                generateEditorial: false,
                currentChefID: "chef_ari",
                createdAt: "2026-06-29T15:02:00.000Z"
            )
        }

        let coverAction = try resolver.createCoverFromSpoon(
            recipe: recipe,
            spoon: photographedSpoon,
            activate: true,
            generateEditorial: false,
            currentChefID: "chef_ari",
            createdAt: "2026-06-29T15:03:00.000Z"
        )
        let coverMutation = try #require(coverAction.nativeQueuedMutation)
        #expect(coverMutation.queueableKind == .coverFromSpoon)
        #expect(coverAction.url == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta"))
        try spoonIntentAssertJSONRequest(
            try spoonIntentRequest(from: coverMutation),
            method: .post,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta/covers/from-spoon/spoon_ari_lemon",
            expected: [
                "clientMutationId": "intent-cover-spoon-recipe_lemon_pantry_pasta-spoon_ari_lemon-2026-06-29T15-03-00-000Z",
                "activate": true,
                "generateEditorial": false
            ]
        )
    }
}

private let spoonIntentConfiguration = APIClientConfiguration(
    baseURL: URL(string: "https://spoonjoy.app")!,
    bearerToken: "sj_private_token"
)

private func spoonIntentRecipeDescriptor() -> RecipeEntityDescriptor {
    let route = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)
    let canonicalURL = URL(string: "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")!
    return RecipeEntityDescriptor(
        id: "recipe_lemon_pantry_pasta",
        title: "Lemon Pantry Pasta",
        chefID: "chef_ari",
        chefUsername: "ari",
        subtitle: "ari - 2 servings",
        disambiguationLabel: "Lemon Pantry Pasta by ari",
        route: route,
        canonicalURL: canonicalURL,
        imageURL: URL(string: "https://spoonjoy.app/photos/recipes/lemon.jpg"),
        transferValue: RecipeCookbookEntityTransferValue(
            kind: .recipe,
            id: "recipe_lemon_pantry_pasta",
            title: "Lemon Pantry Pasta",
            chefUsername: "ari",
            routeIdentifier: route.stateIdentifier,
            canonicalURL: canonicalURL,
            imageURL: URL(string: "https://spoonjoy.app/photos/recipes/lemon.jpg"),
            userVisibleSummary: "Lemon Pantry Pasta by ari"
        )
    )
}

private func spoonIntentSpoonDescriptor(photoURL: URL? = URL(string: "https://spoonjoy.app/photos/spoons/spoon_ari_lemon.jpg")) -> SpoonEntityDescriptor {
    let route = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)
    return SpoonEntityDescriptor(
        id: "production|account_ari|spoon|spoon_ari_lemon",
        spoonID: "spoon_ari_lemon",
        recipeID: "recipe_lemon_pantry_pasta",
        recipeTitle: "Lemon Pantry Pasta",
        chefID: "chef_ari",
        chefUsername: "ari",
        title: "Lemon Pantry Pasta cook log",
        subtitle: "Loved this with extra lemon.",
        disambiguationLabel: "Lemon Pantry Pasta by ari",
        route: route,
        photoURL: photoURL,
        note: "Loved this with extra lemon.",
        nextTime: "Use more lemon zest.",
        cookedAt: "2026-06-01T10:00:00.000Z",
        transferValue: SpoonEntityTransferValue(
            kind: .spoon,
            rawResourceID: "spoon_ari_lemon",
            recipeID: "recipe_lemon_pantry_pasta",
            recipeTitle: "Lemon Pantry Pasta",
            title: "Lemon Pantry Pasta cook log",
            routeIdentifier: route.stateIdentifier,
            publicURL: nil,
            privateTransferValue: "schema=app.spoonjoy.spoon-entity.v1;domain=spoon;title=Lemon Pantry Pasta cook log",
            userVisibleSummary: "Lemon Pantry Pasta: Loved this with extra lemon."
        )
    )
}

private func spoonIntentRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: spoonIntentConfiguration)
}

private func spoonIntentAssertJSONRequest(
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
    #expect(NSDictionary(dictionary: try spoonIntentJSONBody(from: request)).isEqual(to: expected))
}

private func spoonIntentJSONBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private func spoonIntentSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? spoonIntentReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = spoonIntentUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func spoonIntentShortcutBudgetFailures(
    relativePath: String,
    maximumShortcuts: Int,
    libraryOnlyIntentNames: [String]
) -> [String] {
    guard let content = try? spoonIntentReadRepoFile(relativePath) else {
        return ["missing \(relativePath)"]
    }
    let uncommented = spoonIntentUncommentedSwift(content)
    let shortcutCount = uncommented.components(separatedBy: "AppShortcut(").count - 1
    var failures: [String] = []
    if shortcutCount > maximumShortcuts {
        failures.append("\(relativePath) declares \(shortcutCount) App Shortcuts, above Apple limit \(maximumShortcuts)")
    }

    if let body = spoonIntentDeclarationBody(in: uncommented, pattern: #"struct\s+SpoonjoyAppShortcuts\s*:\s*AppShortcutsProvider"#) {
        for intentName in libraryOnlyIntentNames where body.contains("\(intentName)(") {
            failures.append("\(relativePath) promotes library-only \(intentName) into AppShortcuts")
        }
    } else {
        failures.append("\(relativePath) missing body for SpoonjoyAppShortcuts")
    }
    return failures
}

private func spoonIntentBodyContractFailures(
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
        guard let content = try? spoonIntentReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = spoonIntentUncommentedSwift(content)
        guard let body = spoonIntentDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func spoonIntentReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func spoonIntentDeclarationBody(in content: String, pattern: String) -> String? {
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

private func spoonIntentUncommentedSwift(_ content: String) -> String {
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
