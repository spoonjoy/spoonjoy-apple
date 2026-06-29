import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Spotlight, App Shortcuts, and transfer integration contracts")
struct SpotlightShortcutTransferTests {
    @Test("native metadata advertises every shipped entity as Spotlight indexed")
    func nativeMetadataAdvertisesEveryShippedEntityAsSpotlightIndexed() {
        let expectedTypes = [
            "recipe",
            "cookbook",
            "shopping-list-item",
            "spoon",
            "capture-draft",
            "chef-profile"
        ]

        #expect(
            NativeCapabilityMetadata.spoonjoy.spotlightIndexedTypes == expectedTypes,
            Comment(rawValue: "Spotlight must cover every shipped entity domain: \(expectedTypes.joined(separator: ", ")).")
        )

        for appIntent in [
            "SpoonjoyAppShortcuts",
            "SpoonjoyInteractionDonor"
        ] {
            #expect(
                NativeCapabilityMetadata.spoonjoy.appIntents.contains(appIntent),
                Comment(rawValue: "Native capability metadata missing \(appIntent).")
            )
        }
    }

    @Test("source contracts wire semantic Spotlight, App Shortcuts, donations, on-screen annotations, and transfers")
    func sourceContractsWireSemanticSpotlightShortcutsDonationsOnScreenAnnotationsAndTransfers() throws {
        var failures = spotlightShortcutSourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Native/SpotlightIndexPlan.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Native/SpotlightIndexPlan.swift": [
                    "case chefProfile = \"chef-profile\"",
                    "public static let searchableTypes",
                    "public static func documents(",
                    "spoons:",
                    "captureDrafts:",
                    "chefProfiles:",
                    "public static func document(spoon:",
                    "public static func document(captureDraft:",
                    "public static func document(chefProfile:",
                    "public static func chefProfileUniqueIdentifier",
                    "public static func chefProfileDomainIdentifier",
                    "userVisibleSummary",
                    "contentDescription"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift": [
                    ".spoon",
                    ".captureDraft",
                    ".chefProfile",
                    "CSSearchableIndex.isIndexingAvailable()",
                    "indexAppEntities",
                    "deleteAppEntities",
                    "deleteSearchableItems(withIdentifiers:",
                    "deleteSearchableItems(withDomainIdentifiers:"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct SpoonjoyAppShortcuts: AppShortcutsProvider",
                    "static var appShortcuts",
                    "AppShortcut(",
                    "\\(.applicationName)",
                    "OpenRecipeIntent()",
                    "StartCookModeIntent()",
                    "AddShoppingListItemIntent()",
                    "SetShoppingListItemCheckedIntent()",
                    "AddRecipeIngredientsToShoppingListIntent()",
                    "ClearCompletedShoppingItemsIntent()",
                    "ClearShoppingListIntent()",
                    "CaptureRecipeIntent()",
                    "struct SpoonjoyInteractionDonor",
                    "IntentDonationManager.shared",
                    ".donate(intent:",
                    "deleteDonations(matching:",
                    "IntentDonationMatchingPredicate"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift": [
                    "struct SpoonjoyRecipeEntity",
                    "struct SpoonjoyCookbookEntity",
                    "AppEntity",
                    "IndexedEntity",
                    "Transferable",
                    "attributeSet",
                    "defaultAttributeSet",
                    "TransferRepresentation",
                    "userVisibleSummary"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift": [
                    "struct SpoonjoyShoppingListEntity",
                    "struct SpoonjoyShoppingItemEntity",
                    "AppEntity",
                    "IndexedEntity",
                    "Transferable",
                    "attributeSet",
                    "defaultAttributeSet",
                    "TransferRepresentation",
                    "userVisibleSummary"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift": [
                    "struct SpoonjoySpoonEntity",
                    "AppEntity",
                    "IndexedEntity",
                    "Transferable",
                    "attributeSet",
                    "defaultAttributeSet",
                    "TransferRepresentation",
                    "userVisibleSummary"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift": [
                    "struct SpoonjoyCaptureDraftEntity",
                    "AppEntity",
                    "IndexedEntity",
                    "Transferable",
                    "attributeSet",
                    "defaultAttributeSet",
                    "TransferRepresentation",
                    "userVisibleSummary"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift": [
                    "struct SpoonjoyChefProfileEntity",
                    "AppEntity",
                    "IndexedEntity",
                    "Transferable",
                    "attributeSet",
                    "defaultAttributeSet",
                    "TransferRepresentation",
                    "userVisibleSummary"
                ],
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift": [
                    "spotlightIndexDocuments",
                    "contentState.cachedProfiles",
                    "contentState.captureDraft",
                    "recentSpoons",
                    "SpoonjoySpotlightIndexer().replaceAll("
                ],
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift": [
                    "NativeShoppingEntityIndexPurgeOperation",
                    "NativeSpoonEntityIndexPurgeOperation",
                    "NativeCaptureDraftEntityIndexPurgeOperation",
                    "NativeChefProfileEntityIndexPurgeOperation",
                    "ShoppingEntityIndexPurgePlan.accountScopePurge",
                    "SpoonEntityIndexPurgePlan.accountScopePurge",
                    "CaptureDraftEntityIndexPurgePlan.accountScopePurge",
                    "ChefProfileEntityIndexPurgePlan.accountScopePurge",
                    "purgeShoppingEntityIdentifiers",
                    "purgeSpoonEntityIdentifiers",
                    "purgeCaptureDraftEntityIdentifiers",
                    "purgeChefProfileEntityIdentifiers"
                ],
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift": [
                    "ShoppingEntityIndexPurgePlan.tombstonePurge",
                    "SpoonEntityIndexPurgePlan.tombstonePurge",
                    "CaptureDraftEntityIndexPurgePlan.cacheDeletePurge",
                    "ChefProfileEntityIndexPurgePlan.tombstonePurge",
                    "shoppingEntityPurgeIdentifiers",
                    "spoonEntityPurgeIdentifiers",
                    "captureDraftEntityPurgeIdentifiers",
                    "chefProfileEntityPurgeIdentifiers",
                    "removedCacheKeys",
                    "tombstones"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "\"spoon\"",
                    "\"capture-draft\"",
                    "\"chef-profile\"",
                    "SpoonjoyAppShortcuts",
                    "SpoonjoyInteractionDonor"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Spotlight semantic App Entities",
                    "AppShortcutsProvider",
                    "IntentDonationManager",
                    "on-screen AppEntity annotations",
                    "AppEntityAnnotatable",
                    "appEntityIdentifier",
                    "IndexedEntity",
                    "indexAppEntities"
                ]
            ],
            forbiddenTokens: [
                "Sources/SpoonjoyCore/Native/SpotlightIndexPlan.swift": [
                    "privateTransferValue",
                    "debugFields",
                    "captureImportProviderBlocker",
                    "imageAssetIdentifier",
                    "rawText",
                    "providerSecret"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift": [
                    "deleteAllSearchableItems",
                    "replaceAll(documents: [SpotlightIndexDocument])"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "@Parameter(title: \"Recipe ID\")",
                    "@Parameter(title: \"Cookbook ID\")",
                    "@Parameter(title: \"Shopping Item ID\")",
                    "@Parameter(title: \"Spoon ID\")",
                    "@Parameter(title: \"Capture Draft ID\")",
                    "@Parameter(title: \"Chef ID\")",
                    "String-only",
                    "eventually"
                ]
            ]
        )
        failures.append(contentsOf: spotlightShortcutSharedSourceTokenFailures(
            label: "on-screen AppEntity annotations",
            requiredTokens: [
                "appEntityIdentifier",
                "EntityIdentifier"
            ]
        ))
        failures.append(contentsOf: spotlightShortcutSourcePatternFailures(
            patterns: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                    label: "recipe IndexedEntity conformance",
                    pattern: #"(?:struct|extension)\s+SpoonjoyRecipeEntity\s*:\s*[^\{\n]*\bIndexedEntity\b"#
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
                    label: "cookbook IndexedEntity conformance",
                    pattern: #"(?:struct|extension)\s+SpoonjoyCookbookEntity\s*:\s*[^\{\n]*\bIndexedEntity\b"#
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
                    label: "shopping list IndexedEntity conformance",
                    pattern: #"(?:struct|extension)\s+SpoonjoyShoppingListEntity\s*:\s*[^\{\n]*\bIndexedEntity\b"#
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
                    label: "shopping item IndexedEntity conformance",
                    pattern: #"(?:struct|extension)\s+SpoonjoyShoppingItemEntity\s*:\s*[^\{\n]*\bIndexedEntity\b"#
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift",
                    label: "spoon IndexedEntity conformance",
                    pattern: #"(?:struct|extension)\s+SpoonjoySpoonEntity\s*:\s*[^\{\n]*\bIndexedEntity\b"#
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift",
                    label: "capture draft IndexedEntity conformance",
                    pattern: #"(?:struct|extension)\s+SpoonjoyCaptureDraftEntity\s*:\s*[^\{\n]*\bIndexedEntity\b"#
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
                    label: "chef profile IndexedEntity conformance",
                    pattern: #"(?:struct|extension)\s+SpoonjoyChefProfileEntity\s*:\s*[^\{\n]*\bIndexedEntity\b"#
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("Spotlight identifiers stay scoped and reject malformed private routes")
    func spotlightIdentifiersStayScopedAndRejectMalformedPrivateRoutes() {
        let scope = SpotlightIndexScope(accountID: "account.ari@example.com", environment: .production)
        let shoppingIdentifier = SpotlightIndexPlan.shoppingListItemUniqueIdentifier(itemID: "item_lemons", scope: scope)
        let spoonIdentifier = SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: "spoon_lemon", scope: scope)
        let captureIdentifier = SpotlightIndexPlan.captureDraftUniqueIdentifier(draftID: "draft_url", scope: scope)

        #expect(shoppingIdentifier == "production|account-ari-example-com|shopping-list-item|item_lemons")
        #expect(spoonIdentifier == "production|account-ari-example-com|spoon|spoon_lemon")
        #expect(captureIdentifier == "production|account-ari-example-com|capture-draft|draft_url")
        #expect(SpotlightIndexPlan.shoppingListItemDomainIdentifier(scope: scope) == "app.spoonjoy.production.account-ari-example-com.shopping-list-item")
        #expect(SpotlightIndexPlan.spoonDomainIdentifier(scope: scope) == "app.spoonjoy.production.account-ari-example-com.spoon")
        #expect(SpotlightIndexPlan.captureDraftDomainIdentifier(scope: scope) == "app.spoonjoy.production.account-ari-example-com.capture-draft")
        #expect(!shoppingIdentifier.contains("@"))
        #expect(!spoonIdentifier.contains("@"))
        #expect(!captureIdentifier.contains("@"))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|account-ari-example-com|shopping-list-item|../secret") == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|account-ari-example-com|capture-draft|draft_url") == .capture)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|account-ari-example-com|chef-profile|chef_jules") == .profile(identifier: "chef_jules"))
    }
}

private func spotlightShortcutSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for path in requiredFiles {
        if (try? spotlightShortcutReadRepoFile(path)) == nil {
            failures.append("\(path) missing")
        }
    }

    for (path, tokens) in requiredTokens {
        guard let source = try? spotlightShortcutReadRepoFile(path) else {
            continue
        }
        let uncommented = spotlightShortcutUncommentedSwift(source)
        for token in tokens where !uncommented.contains(token) {
            failures.append("\(path) missing \(token)")
        }
    }

    for (path, tokens) in forbiddenTokens {
        guard let source = try? spotlightShortcutReadRepoFile(path) else {
            continue
        }
        let uncommented = spotlightShortcutUncommentedSwift(source)
        for token in tokens where uncommented.contains(token) {
            failures.append("\(path) must not contain \(token)")
        }
    }

    return failures.sorted()
}

private func spotlightShortcutSourcePatternFailures(
    patterns: [(relativePath: String, label: String, pattern: String)]
) -> [String] {
    patterns.compactMap { contract in
        guard let source = try? spotlightShortcutReadRepoFile(contract.relativePath) else {
            return nil
        }
        let uncommented = spotlightShortcutUncommentedSwift(source)
        let range = uncommented.range(of: contract.pattern, options: .regularExpression)
        return range == nil ? "\(contract.relativePath) missing \(contract.label)" : nil
    }
}

private func spotlightShortcutSharedSourceTokenFailures(label: String, requiredTokens: [String]) -> [String] {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/Spoonjoy/Shared")
    guard let enumerator = FileManager.default.enumerator(
        at: rootURL,
        includingPropertiesForKeys: nil
    ) else {
        return ["Apps/Spoonjoy/Shared missing \(label) sources"]
    }

    let source = enumerator.compactMap { item -> String? in
        guard let url = item as? URL, url.pathExtension == "swift" else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }.joined(separator: "\n")
    let uncommented = spotlightShortcutUncommentedSwift(source)
    return requiredTokens.compactMap { token in
        uncommented.contains(token) ? nil : "Apps/Spoonjoy/Shared missing \(label) token \(token)"
    }
}

private func spotlightShortcutReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let fileURL = rootURL.appendingPathComponent(relativePath)
    return try String(contentsOf: fileURL, encoding: .utf8)
}

private func spotlightShortcutUncommentedSwift(_ content: String) -> String {
    let withoutBlockComments = content.replacingOccurrences(
        of: #"/\*.*?\*/"#,
        with: "",
        options: .regularExpression
    )
    return withoutBlockComments
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line in
            guard let commentRange = line.range(of: "//") else {
                return String(line)
            }
            return String(line[..<commentRange.lowerBound])
        }
        .joined(separator: "\n")
}
