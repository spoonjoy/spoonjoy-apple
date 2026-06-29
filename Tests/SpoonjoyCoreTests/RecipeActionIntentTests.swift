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
