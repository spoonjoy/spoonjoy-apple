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
                        "share.privateTransferValue",
                        "share.publicURL == nil"
                    ],
                    forbiddenTokens: [
                        "OpenURLIntent",
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
