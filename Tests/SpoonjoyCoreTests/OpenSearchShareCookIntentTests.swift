import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Open search share and cook Siri intent contracts")
struct OpenSearchShareCookIntentTests {
    @Test("open search share and cook intents are entity backed")
    func openSearchShareCookIntentsAreEntityBacked() throws {
        var failures = openSearchShareCookSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct OpenRecipeIntent: AppIntent",
                    "struct OpenCookbookIntent: AppIntent",
                    "struct OpenProfileIntent: AppIntent",
                    "struct SearchSpoonjoyIntent: AppIntent",
                    "struct ShareRecipeIntent: AppIntent",
                    "struct ShareCookbookIntent: AppIntent",
                    "struct ShareShoppingListIntent: AppIntent",
                    "struct StartCookModeIntent: AppIntent",
                    "struct ContinueCookModeIntent: AppIntent",
                    "enum SpoonjoySearchScopeOption: String, AppEnum",
                    "var recipe: SpoonjoyRecipeEntity",
                    "var cookbook: SpoonjoyCookbookEntity",
                    "var profile: SpoonjoyChefProfileEntity",
                    "var shoppingList: SpoonjoyShoppingListEntity",
                    "var scope: SpoonjoySearchScopeOption",
                    "SpoonjoyInteractionDonor",
                    "OpenCookbookIntent()",
                    "OpenProfileIntent()",
                    "SearchSpoonjoyIntent()",
                    "ShareRecipeIntent()",
                    "ShareCookbookIntent()",
                    "ShareShoppingListIntent()",
                    "ContinueCookModeIntent()"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "NativeIntentShareValue",
                    "public func openRecipe(recipe: RecipeEntityDescriptor)",
                    "public func openCookbook(cookbook: CookbookEntityDescriptor)",
                    "public func openProfile(profile: ChefProfileEntityDescriptor)",
                    "public func searchSpoonjoy(query: String, scope: SearchScope)",
                    "public func shareRecipe(recipe: RecipeEntityDescriptor)",
                    "public func shareCookbook(cookbook: CookbookEntityDescriptor)",
                    "public func shareShoppingList(shoppingList: ShoppingListEntityDescriptor)",
                    "public func startCookMode(recipe: RecipeEntityDescriptor)",
                    "public func continueCookMode(recipe: RecipeEntityDescriptor)",
                    "NativeSharePayloadKind.publicURL",
                    "NativeSharePayloadKind.privateTransfer",
                    "privateTransferValue",
                    "DeepLinkURLBuilder.url(for:"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "OpenCookbookIntent",
                    "OpenProfileIntent",
                    "SearchSpoonjoyIntent",
                    "ShareRecipeIntent",
                    "ShareCookbookIntent",
                    "ShareShoppingListIntent",
                    "ContinueCookModeIntent"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Open/search/share/cook Siri intents",
                    "OpenCookbookIntent",
                    "OpenProfileIntent",
                    "SearchSpoonjoyIntent",
                    "ShareRecipeIntent",
                    "ShareCookbookIntent",
                    "ShareShoppingListIntent",
                    "ContinueCookModeIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Recipe ID\")",
                    "@Parameter(title: \"Cookbook ID\")",
                    "@Parameter(title: \"Profile ID\")",
                    "@Parameter(title: \"Shopping List URL\")",
                    "var recipeID: String",
                    "var cookbookID: String",
                    "var profileID: String",
                    "https://spoonjoy.app/shopping-list",
                    "NativeSharePayload.publicRoute(.shoppingList",
                    "String-only open/share/cook intent",
                    "TODO OpenSearchShareCook"
                ]
            ]
        )
        failures.append(contentsOf: openSearchShareCookShortcutBudgetFailures(
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            maximumShortcuts: 10
        ))

        failures.append(contentsOf: openSearchShareCookBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                    label: "SpoonjoyRecipeEntity",
                    pattern: #"struct\s+SpoonjoyRecipeEntity\s*:\s*AppEntity"#,
                    requiredTokens: [
                        "var displayRepresentation: DisplayRepresentation",
                        "descriptor.title",
                        "descriptor.subtitle",
                        "descriptor.disambiguationLabel"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                    label: "SpoonjoyCookbookEntity",
                    pattern: #"struct\s+SpoonjoyCookbookEntity\s*:\s*AppEntity"#,
                    requiredTokens: [
                        "var displayRepresentation: DisplayRepresentation",
                        "descriptor.title",
                        "descriptor.subtitle",
                        "descriptor.disambiguationLabel"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
                    label: "SpoonjoyShoppingListEntity",
                    pattern: #"struct\s+SpoonjoyShoppingListEntity\s*:\s*AppEntity"#,
                    requiredTokens: [
                        "var displayRepresentation: DisplayRepresentation",
                        "descriptor.title",
                        "descriptor.subtitle",
                        "descriptor.disambiguationLabel"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
                    label: "SpoonjoyChefProfileEntity",
                    pattern: #"struct\s+SpoonjoyChefProfileEntity\s*:\s*AppEntity"#,
                    requiredTokens: [
                        "var displayRepresentation: DisplayRepresentation",
                        "descriptor.title",
                        "descriptor.subtitle",
                        "descriptor.disambiguationLabel"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        failures.append(contentsOf: openSearchShareCookBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenRecipeIntent",
                    pattern: #"struct\s+OpenRecipeIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "NativeIntentActionResolver().openRecipe(recipe: recipe.descriptor)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "try recipe.resolvedRecipeID()",
                        "openRecipe(recipeID:"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenCookbookIntent",
                    pattern: #"struct\s+OpenCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Cookbook\", requestValueDialog:",
                        "var cookbook: SpoonjoyCookbookEntity",
                        "NativeIntentActionResolver().openCookbook(cookbook: cookbook.descriptor)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var cookbookID: String",
                        "openCookbook(cookbookID:"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenProfileIntent",
                    pattern: #"struct\s+OpenProfileIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Profile\", requestValueDialog:",
                        "var profile: SpoonjoyChefProfileEntity",
                        "NativeIntentActionResolver().openProfile(profile: profile.descriptor)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var profileID: String",
                        "var chefID: String",
                        "openProfile(profileID:",
                        "openProfile(chefID:"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SearchSpoonjoyIntent",
                    pattern: #"struct\s+SearchSpoonjoyIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Query\")",
                        "var scope: SpoonjoySearchScopeOption",
                        "NativeIntentActionResolver().searchSpoonjoy(query: query, scope: scope.searchScope)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var scope: String",
                        "String-only search intent"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ShareRecipeIntent",
                    pattern: #"struct\s+ShareRecipeIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "NativeIntentActionResolver().shareRecipe(recipe: recipe.descriptor)",
                        "share.publicURL"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "shareRecipe(recipeID:"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ShareCookbookIntent",
                    pattern: #"struct\s+ShareCookbookIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Cookbook\", requestValueDialog:",
                        "var cookbook: SpoonjoyCookbookEntity",
                        "NativeIntentActionResolver().shareCookbook(cookbook: cookbook.descriptor)",
                        "share.publicURL"
                    ],
                    forbiddenTokens: [
                        "var cookbookID: String",
                        "shareCookbook(cookbookID:"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ShareShoppingListIntent",
                    pattern: #"struct\s+ShareShoppingListIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Shopping List\", requestValueDialog:",
                        "var shoppingList: SpoonjoyShoppingListEntity",
                        "NativeIntentActionResolver().shareShoppingList(shoppingList: shoppingList.descriptor)",
                        "some IntentResult & ReturnsValue<String>",
                        "share.privateTransferValue",
                        "share.publicURL == nil",
                        ".result(value: privateTransferValue"
                    ],
                    forbiddenTokens: [
                        "OpenURLIntent",
                        "_ = privateTransferValue",
                        "https://spoonjoy.app/shopping-list",
                        "NativeSharePayload.publicRoute(.shoppingList"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "StartCookModeIntent",
                    pattern: #"struct\s+StartCookModeIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "NativeIntentActionResolver().startCookMode(recipe: recipe.descriptor)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "try recipe.resolvedRecipeID()",
                        "startCookMode(recipeID:"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ContinueCookModeIntent",
                    pattern: #"struct\s+ContinueCookModeIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Recipe\", requestValueDialog:",
                        "var recipe: SpoonjoyRecipeEntity",
                        "NativeIntentActionResolver().continueCookMode(recipe: recipe.descriptor)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var recipeID: String",
                        "continueCookMode(recipeID:"
                    ]
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("share intent contract keeps shopping private and avoids invented social surfaces")
    func shareIntentContractKeepsShoppingPrivateAndAvoidsInventedSocialSurfaces() throws {
        var failures = openSearchShareCookBodyContractFailures(
            contracts: [
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "shareShoppingList",
                    pattern: #"public\s+func\s+shareShoppingList\(shoppingList:\s+ShoppingListEntityDescriptor\)"#,
                    requiredTokens: [
                        "domain: .shoppingList",
                        "kind: .privateTransfer",
                        "publicURL: nil",
                        "privateTransferValue: shoppingList.transferValue.privateTransferValue"
                    ],
                    forbiddenTokens: [
                        "NativeSharePayload.publicRoute(.shoppingList",
                        "DeepLinkURLBuilder.url(for: .shoppingList)",
                        "https://spoonjoy.app/shopping-list"
                    ]
                )
            ]
        )
        failures.append(contentsOf: openSearchShareCookSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift"
            ],
            requiredTokens: [:],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "CommentRecipeIntent",
                    "RecipeCommentIntent",
                    "MessageRecipeIntent",
                    "MailRecipeIntent",
                    "SocialFeedIntent",
                    "PostSpoonIntent"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "CommentRecipeIntent",
                    "RecipeComment",
                    "SocialFeed",
                    "PostSpoon"
                ]
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("descriptor resolver validates entity route shape before opening and sharing")
    func descriptorResolverValidatesEntityRouteShapeBeforeOpeningAndSharing() throws {
        let resolver = NativeIntentActionResolver()
        let recipe = openSearchShareCookRecipeDescriptor(id: "recipe_lemon_pantry_pasta")
        let cookbook = openSearchShareCookCookbookDescriptor(id: "cookbook_weeknight")
        let profile = openSearchShareCookChefProfileDescriptor(username: "ari")
        let shoppingList = openSearchShareCookShoppingListDescriptor()

        #expect(try resolver.openRecipe(recipe: recipe).route == .recipeDetail(id: recipe.id, presentation: .detail))
        #expect(try resolver.startCookMode(recipe: recipe).route == .recipeDetail(id: recipe.id, presentation: .cook))
        #expect(try resolver.continueCookMode(recipe: recipe).route == .recipeDetail(id: recipe.id, presentation: .cook))
        #expect(try resolver.openCookbook(cookbook: cookbook).route == .cookbookDetail(id: cookbook.id))
        #expect(try resolver.openProfile(profile: profile).route == .profile(identifier: profile.username))
        #expect(resolver.searchSpoonjoy(query: " lemons ", scope: .recipes).route == .search(query: "lemons", scope: .recipes))

        let recipeShare = try resolver.shareRecipe(recipe: recipe)
        #expect(recipeShare.domain == .recipe)
        #expect(recipeShare.kind == .publicURL)
        #expect(recipeShare.isPublicURL)
        #expect(!recipeShare.isPrivateTransfer)
        #expect(recipeShare.publicURL == URL(string: "https://spoonjoy.app/recipes/\(recipe.id)"))

        let cookbookShare = try resolver.shareCookbook(cookbook: cookbook)
        #expect(cookbookShare.domain == .cookbook)
        #expect(cookbookShare.kind == .publicURL)
        #expect(cookbookShare.publicURL == URL(string: "https://spoonjoy.app/cookbooks/\(cookbook.id)"))

        let shoppingShare = try resolver.shareShoppingList(shoppingList: shoppingList)
        #expect(shoppingShare.domain == .shoppingList)
        #expect(shoppingShare.kind == .privateTransfer)
        #expect(shoppingShare.isPrivateTransfer)
        #expect(!shoppingShare.isPublicURL)
        #expect(shoppingShare.publicURL == nil)
        #expect(shoppingShare.privateTransferValue?.contains("domain=shopping-list") == true)
        #expect(NativeIntentActionError.unresolvedCookbookEntity.description.contains("cookbook"))
        #expect(NativeIntentActionError.shareUnavailable(.shoppingList).description.contains("shopping-list"))

        #expect(throws: NativeIntentActionError.unresolvedRecipeEntity) {
            try resolver.openRecipe(recipe: .placeholder)
        }
        #expect(throws: NativeIntentActionError.unresolvedCookbookEntity) {
            try resolver.openCookbook(cookbook: .placeholder)
        }
        #expect(throws: NativeIntentActionError.unresolvedChefProfileEntity) {
            try resolver.openProfile(profile: .placeholder)
        }
        #expect(throws: NativeIntentActionError.invalidRecipeID("bad/recipe")) {
            try resolver.openRecipe(recipe: openSearchShareCookRecipeDescriptor(id: "bad/recipe"))
        }
        #expect(throws: NativeIntentActionError.invalidRecipeID(recipe.id)) {
            try resolver.shareRecipe(recipe: openSearchShareCookRecipeDescriptor(
                id: recipe.id,
                route: .cookbookDetail(id: cookbook.id)
            ))
        }
        #expect(throws: NativeIntentActionError.invalidCookbookID("bad/cookbook")) {
            try resolver.openCookbook(cookbook: openSearchShareCookCookbookDescriptor(id: "bad/cookbook"))
        }
        #expect(throws: NativeIntentActionError.invalidCookbookID(cookbook.id)) {
            try resolver.shareCookbook(cookbook: openSearchShareCookCookbookDescriptor(
                id: cookbook.id,
                route: .recipeDetail(id: recipe.id, presentation: .detail)
            ))
        }
        #expect(throws: NativeIntentActionError.invalidProfileIdentifier("bad..profile")) {
            try resolver.openProfile(profile: openSearchShareCookChefProfileDescriptor(username: "bad..profile"))
        }
        #expect(throws: NativeIntentActionError.invalidProfileIdentifier(profile.username)) {
            try resolver.openProfile(profile: openSearchShareCookChefProfileDescriptor(
                username: profile.username,
                route: .profile(identifier: "other-chef")
            ))
        }
        #expect(throws: NativeIntentActionError.shareUnavailable(.shoppingList)) {
            try resolver.publicShareValue(route: .shoppingList, title: "Shopping List", subtitle: "Private")
        }
        #expect(throws: NativeIntentActionError.unresolvedShoppingListEntity) {
            try resolver.shareShoppingList(shoppingList: .placeholder)
        }
    }
}

private func openSearchShareCookRecipeDescriptor(
    id: String,
    route: AppRoute? = nil
) -> RecipeEntityDescriptor {
    let route = route ?? .recipeDetail(id: id, presentation: .detail)
    let title = "Recipe \(id)"
    let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)") ?? URL(string: "https://spoonjoy.app/recipes/fallback")!
    return RecipeEntityDescriptor(
        id: id,
        title: title,
        chefID: "chef_ari",
        chefUsername: "ari",
        subtitle: "ari",
        disambiguationLabel: "\(title) by ari",
        route: route,
        canonicalURL: canonicalURL,
        imageURL: nil,
        transferValue: RecipeCookbookEntityTransferValue(
            kind: .recipe,
            id: id,
            title: title,
            chefUsername: "ari",
            routeIdentifier: route.stateIdentifier,
            canonicalURL: canonicalURL,
            imageURL: nil,
            userVisibleSummary: "\(title) by ari"
        )
    )
}

private func openSearchShareCookCookbookDescriptor(
    id: String,
    route: AppRoute? = nil
) -> CookbookEntityDescriptor {
    let route = route ?? .cookbookDetail(id: id)
    let title = "Cookbook \(id)"
    let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)") ?? URL(string: "https://spoonjoy.app/cookbooks/fallback")!
    return CookbookEntityDescriptor(
        id: id,
        title: title,
        chefID: "chef_ari",
        chefUsername: "ari",
        subtitle: "ari - 2 recipes",
        disambiguationLabel: "\(title) by ari",
        route: route,
        canonicalURL: canonicalURL,
        imageURL: nil,
        recipeCount: 2,
        transferValue: RecipeCookbookEntityTransferValue(
            kind: .cookbook,
            id: id,
            title: title,
            chefUsername: "ari",
            routeIdentifier: route.stateIdentifier,
            canonicalURL: canonicalURL,
            imageURL: nil,
            userVisibleSummary: "\(title) by ari"
        )
    )
}

private func openSearchShareCookChefProfileDescriptor(
    username: String,
    route: AppRoute? = nil
) -> ChefProfileEntityDescriptor {
    let route = route ?? AppRoute.profile(identifier: username)
    let canonicalURL = URL(string: "https://spoonjoy.app/users/\(AppRoute.encodedProfileIdentifier(username))")!
    return ChefProfileEntityDescriptor(
        id: "profile_\(username)",
        profileID: "profile_\(username)",
        username: username,
        title: username,
        subtitle: "Chef",
        disambiguationLabel: "\(username) on Spoonjoy",
        route: route,
        canonicalURL: canonicalURL,
        photoURL: nil,
        fellowChefsCount: 0,
        kitchenVisitorsCount: 0,
        interactionSummary: nil,
        transferValue: ChefProfileEntityTransferValue(
            kind: .chefProfile,
            profileID: "profile_\(username)",
            username: username,
            title: username,
            routeIdentifier: route.stateIdentifier,
            canonicalURL: canonicalURL,
            photoURL: nil,
            userVisibleSummary: "\(username) on Spoonjoy"
        )
    )
}

private func openSearchShareCookShoppingListDescriptor() -> ShoppingListEntityDescriptor {
    let scope = ShoppingEntityScope(accountID: "account_ari", environment: .production)
    return ShoppingListEntityDescriptor(
        id: ShoppingEntityCatalog.shoppingListEntityIdentifier(accountID: scope.accountID, environment: scope.environment),
        scope: scope,
        title: "Shopping List",
        subtitle: "1 active item",
        disambiguationLabel: "Shopping List for ari",
        route: .shoppingList,
        activeItemCount: 1,
        transferValue: ShoppingEntityTransferValue(
            kind: .shoppingList,
            rawResourceID: "shopping-list",
            title: "Shopping List",
            routeIdentifier: AppRoute.shoppingList.stateIdentifier,
            publicURL: nil,
            privateTransferValue: "schema=app.spoonjoy.shopping-entity.v1;domain=shopping-list;title=Shopping List",
            userVisibleSummary: "1 active item"
        )
    )
}

private func openSearchShareCookSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? openSearchShareCookReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = openSearchShareCookUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func openSearchShareCookShortcutBudgetFailures(
    relativePath: String,
    maximumShortcuts: Int
) -> [String] {
    guard let content = try? openSearchShareCookReadRepoFile(relativePath) else {
        return ["missing \(relativePath)"]
    }
    let uncommented = openSearchShareCookUncommentedSwift(content)
    let shortcutCount = uncommented.components(separatedBy: "AppShortcut(").count - 1
    guard shortcutCount <= maximumShortcuts else {
        return ["\(relativePath) declares \(shortcutCount) App Shortcuts, above Apple limit \(maximumShortcuts)"]
    }
    return []
}

private func openSearchShareCookBodyContractFailures(
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
        guard let content = try? openSearchShareCookReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = openSearchShareCookUncommentedSwift(content)
        guard let body = openSearchShareCookDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func openSearchShareCookReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func openSearchShareCookUncommentedSwift(_ content: String) -> String {
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
                index = content.index(after: nextIndex)
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
                var previous: Character?
                while index < content.endIndex {
                    let current = content[index]
                    let afterCurrent = content.index(after: index)
                    if previous == "*", current == "/" {
                        index = afterCurrent
                        break
                    }
                    previous = current
                    index = afterCurrent
                }
                continue
            }
        }

        output.append(character)
        index = nextIndex
    }

    return output
}

private func openSearchShareCookDeclarationBody(in content: String, pattern: String) -> String? {
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
