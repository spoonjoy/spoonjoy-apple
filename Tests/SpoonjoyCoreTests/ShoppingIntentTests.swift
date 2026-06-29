import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Shopping Siri intent contracts")
struct ShoppingIntentTests {
    @Test("shopping Siri intents require entity-backed queueable actions")
    func shoppingSiriIntentsRequireEntityBackedQueueableActions() throws {
        var failures = shoppingIntentSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct AddShoppingListItemIntent: AppIntent",
                    "struct SetShoppingListItemCheckedIntent: AppIntent",
                    "struct RemoveShoppingListItemIntent: AppIntent",
                    "struct ClearCompletedShoppingItemsIntent: AppIntent",
                    "struct ClearShoppingListIntent: AppIntent",
                    "struct AddRecipeIngredientsToShoppingListIntent: AppIntent",
                    "var item: SpoonjoyShoppingItemEntity",
                    "var recipe: SpoonjoyRecipeEntity",
                    "SpoonjoyIntentStateWriter",
                    "SpoonjoyIntentClock.timestamp()",
                    "SpoonjoyInteractionDonor",
                    "throw NativeIntentActionError.authRequired"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift": [
                    "struct SpoonjoyShoppingItemEntity: AppEntity",
                    "struct SpoonjoyShoppingItemEntityQuery: EntityQuery, EntityStringQuery",
                    "resolvedShoppingItemID() throws",
                    "NativeIntentActionError.unresolvedShoppingItemEntity"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift": [
                    "struct SpoonjoyRecipeEntity: AppEntity",
                    "resolvedRecipeID() throws",
                    "NativeIntentActionError.unresolvedRecipeEntity"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "public func addShoppingListItem(",
                    "public func setShoppingListItemChecked(",
                    "public func removeShoppingListItem(",
                    "public func clearCompletedShoppingItems(",
                    "public func clearShoppingList(",
                    "public func addRecipeIngredientsToShoppingList(",
                    ".shoppingCheckItem",
                    ".shoppingDeleteItem",
                    ".shoppingClearCompleted",
                    ".shoppingClearAll",
                    ".shoppingAddFromRecipe",
                    "DeepLinkURLBuilder.url(for: .shoppingList)"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "AddShoppingListItemIntent",
                    "SetShoppingListItemCheckedIntent",
                    "RemoveShoppingListItemIntent",
                    "ClearCompletedShoppingItemsIntent",
                    "ClearShoppingListIntent",
                    "AddRecipeIngredientsToShoppingListIntent"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Shopping Siri intents",
                    "AddShoppingListItemIntent",
                    "SetShoppingListItemCheckedIntent",
                    "RemoveShoppingListItemIntent",
                    "ClearCompletedShoppingItemsIntent",
                    "ClearShoppingListIntent",
                    "AddRecipeIngredientsToShoppingListIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Shopping Item ID\")",
                    "@Parameter(title: \"Recipe ID\")",
                    "var itemID: String",
                    "var recipeID: String",
                    "String-only shopping App Intent",
                    "TODO ShoppingIntent"
                ]
            ]
        )

        failures.append(contentsOf: shoppingIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "AddShoppingListItemIntent",
                    pattern: #"struct\s+AddShoppingListItemIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Name\")",
                        "@Parameter(title: \"Quantity\")",
                        "@Parameter(title: \"Unit\")",
                        "NativeIntentActionResolver().addShoppingListItem(",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "var itemID: String",
                        "@Parameter(title: \"Item ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SetShoppingListItemCheckedIntent",
                    pattern: #"struct\s+SetShoppingListItemCheckedIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Shopping Item\", requestValueDialog:",
                        "var item: SpoonjoyShoppingItemEntity",
                        "@Parameter(title: \"Checked\")",
                        "try item.resolvedShoppingItemID()",
                        "NativeIntentActionResolver().setShoppingListItemChecked(",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var itemID: String",
                        "@Parameter(title: \"Item ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "RemoveShoppingListItemIntent",
                    pattern: #"struct\s+RemoveShoppingListItemIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Shopping Item\", requestValueDialog:",
                        "var item: SpoonjoyShoppingItemEntity",
                        "try item.resolvedShoppingItemID()",
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().removeShoppingListItem(",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: [
                        "var itemID: String",
                        "@Parameter(title: \"Item ID\")"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ClearCompletedShoppingItemsIntent",
                    pattern: #"struct\s+ClearCompletedShoppingItemsIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().clearCompletedShoppingItems(",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ClearShoppingListIntent",
                    pattern: #"struct\s+ClearShoppingListIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().clearShoppingList(",
                        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
                    ],
                    forbiddenTokens: []
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
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("shopping intent resolver queues UI-compatible offline mutations")
    func shoppingIntentResolverQueuesUICompatibleOfflineMutations() throws {
        let resolver = NativeIntentActionResolver()
        let addAction = try resolver.addShoppingListItem(
            name: " Preserved Lemons ",
            quantity: 2,
            unit: " jar ",
            createdAt: "2026-06-16T14:00:00.000Z"
        )
        let pantryAction = try resolver.addShoppingListItem(
            name: " Flaky Salt ",
            quantity: nil,
            unit: "   ",
            createdAt: "2026-06-16T14:04:00.000Z"
        )
        let checkAction = try resolver.setShoppingListItemChecked(
            itemID: " item_lemons ",
            checked: true,
            createdAt: "2026-06-16T14:05:00.000Z"
        )
        let uncheckAction = try resolver.setShoppingListItemChecked(
            itemID: "item_lemons",
            checked: false,
            createdAt: "2026-06-16T14:06:00.000Z"
        )
        let addRecipeAction = try resolver.addRecipeIngredientsToShoppingList(
            recipeID: " recipe_lemon_pantry_pasta ",
            scaleFactor: 2,
            createdAt: "2026-06-16T14:07:00.000Z"
        )
        let clearCompletedAction = resolver.clearCompletedShoppingItems(createdAt: "2026-06-16T14:08:00.000Z")
        let clearAllAction = resolver.clearShoppingList(createdAt: "2026-06-16T14:09:00.000Z")

        let addMutation = try #require(addAction.nativeQueuedMutation)
        let pantryMutation = try #require(pantryAction.queuedMutation)
        let checkMutation = try #require(checkAction.nativeQueuedMutation)
        let uncheckMutation = try #require(uncheckAction.nativeQueuedMutation)
        let addRecipeMutation = try #require(addRecipeAction.nativeQueuedMutation)
        let clearCompletedMutation = try #require(clearCompletedAction.nativeQueuedMutation)
        let clearAllMutation = try #require(clearAllAction.nativeQueuedMutation)

        #expect(addAction.route == .shoppingList)
        #expect(addAction.url == URL(string: "spoonjoy://shopping-list"))
        #expect(addMutation.queueableKind == .shoppingAddItem)
        #expect(addMutation.clientMutationID == "intent-shopping-add-preserved-lemons-2026-06-16T14-00-00-000Z")
        #expect(pantryMutation.kind == .shoppingAdd(name: "flaky salt", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil))
        #expect(checkMutation.queueableKind == .shoppingCheckItem)
        #expect(checkMutation.clientMutationID == "intent-shopping-check-item_lemons-checked-2026-06-16T14-05-00-000Z")
        #expect(uncheckMutation.queueableKind == .shoppingCheckItem)
        #expect(uncheckMutation.clientMutationID == "intent-shopping-check-item_lemons-unchecked-2026-06-16T14-06-00-000Z")
        #expect(addRecipeMutation.queueableKind == .shoppingAddFromRecipe)
        #expect(addRecipeMutation.clientMutationID == "intent-shopping-recipe-recipe_lemon_pantry_pasta-2026-06-16T14-07-00-000Z")
        #expect(clearCompletedMutation.queueableKind == .shoppingClearCompleted)
        #expect(clearCompletedMutation.clientMutationID == "intent-shopping-clear-completed-2026-06-16T14-08-00-000Z")
        #expect(clearAllMutation.queueableKind == .shoppingClearAll)
        #expect(clearAllMutation.clientMutationID == "intent-shopping-clear-all-2026-06-16T14-09-00-000Z")

        #expect(throws: NativeIntentActionError.emptyShoppingItem) {
            try resolver.addShoppingListItem(
                name: "   ",
                quantity: nil,
                unit: nil,
                createdAt: "2026-06-16T14:10:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.invalidShoppingItemID("bad/item")) {
            try resolver.setShoppingListItemChecked(
                itemID: "bad/item",
                checked: true,
                createdAt: "2026-06-16T14:11:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.invalidScaleFactor(0)) {
            try resolver.addRecipeIngredientsToShoppingList(
                recipeID: "recipe_lemon_pantry_pasta",
                scaleFactor: 0,
                createdAt: "2026-06-16T14:12:00.000Z"
            )
        }
    }
}

private func shoppingIntentSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? shoppingIntentReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = shoppingIntentUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func shoppingIntentBodyContractFailures(
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
        guard let content = try? shoppingIntentReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = shoppingIntentUncommentedSwift(content)
        guard let body = shoppingIntentDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func shoppingIntentReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func shoppingIntentDeclarationBody(in content: String, pattern: String) -> String? {
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

private func shoppingIntentUncommentedSwift(_ content: String) -> String {
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
