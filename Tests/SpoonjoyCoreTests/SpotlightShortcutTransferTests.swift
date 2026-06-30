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
                    "public static func domainIdentifiers(scope:",
                    "userVisibleSummary",
                    "contentDescription"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift": [
                    ".spoon",
                    ".captureDraft",
                    ".chefProfile",
                    "CSSearchableIndex.isIndexingAvailable()",
                    "indexAppEntities",
                    "replaceAllAppEntities",
                    "deleteAppEntities",
                    "deleteAppEntities(ofType:",
                    "ShoppingEntityCatalog.shoppingItemEntityIdentifier",
                    "SpoonEntityCatalog.spoonEntityIdentifier",
                    "CaptureDraftEntityCatalog.captureDraftEntityIdentifier",
                    "SpoonjoyShoppingListEntity.self",
                    "SpoonjoyInteractionDonor()",
                    ".deleteDonations(matching:",
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
                    "donateBestEffort(self)",
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
                    "chefProfileEntityIdentifier(for:",
                    "cachedProfile.profile.id == routeIdentifier || cachedProfile.profile.username == routeIdentifier",
                    "replaceAll(payload.documents, scope: payload.scope)",
                    "replaceAllAppEntities"
                ],
                "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift": [
                    "accountID: request.accountID",
                    "environment: request.environment"
                ],
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift": [
                    "NativeShoppingEntityIndexPurgeOperation",
                    "NativeSpoonEntityIndexPurgeOperation",
                    "NativeCaptureDraftEntityIndexPurgeOperation",
                    "NativeChefProfileEntityIndexPurgeOperation",
                    "ShoppingEntityIndexPurgePlan.accountScopePurge",
                    "SpoonEntityIndexPurgePlan.accountScopePurge",
                    "CaptureDraftEntityIndexPurgePlan.accountScopePurge",
                    "CaptureDraftEntityIndexPurgePlan.cacheDeletePurge",
                    "ChefProfileEntityIndexPurgePlan.accountScopePurge",
                    "purgeShoppingEntityIdentifiers",
                    "purgeSpoonEntityIdentifiers",
                    "purgeCaptureDraftEntityIdentifiers",
                    "purgeChefProfileEntityIdentifiers",
                    "report.captureDraftEntityPurgeRequests"
                ],
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift": [
                    "ShoppingEntityIndexPurgePlan.tombstonePurge",
                    "SpoonEntityIndexPurgePlan.tombstonePurge",
                    "ChefProfileEntityIndexPurgePlan.tombstonePurge",
                    "ChefProfileEntityIndexPurgePlan.cacheDeletePurge",
                    "shoppingEntityPurgeIdentifiers",
                    "spoonEntityPurgeIdentifiers",
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
        failures.append(contentsOf: spotlightShortcutBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    label: "deleteDonations domain dispatch",
                    pattern: #"private\s+func\s+deleteDonations\("#,
                    requiredTokens: [
                        "if domainTypes.contains(.recipe)",
                        "try await deleteRecipeDomainDonations(using: donor)",
                        "if domainTypes.contains(.cookbook)",
                        "try await deleteCookbookDomainDonations(using: donor)",
                        "if domainTypes.contains(.shoppingListItem)",
                        "try await deleteShoppingDomainDonations(using: donor)",
                        "if domainTypes.contains(.spoon)",
                        "try await deleteSpoonDomainDonations(using: donor)",
                        "if domainTypes.contains(.captureDraft)",
                        "try await deleteCaptureDraftDomainDonations(using: donor)",
                        "if domainTypes.contains(.chefProfile)",
                        "try await deleteChefProfileDomainDonations(using: donor)"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    label: "deleteRecipeDomainDonations",
                    pattern: #"private\s+func\s+deleteRecipeDomainDonations\("#,
                    requiredTokens: [
                        "OpenRecipeIntent.self",
                        "SearchSpoonjoyIntent.self",
                        "ShareRecipeIntent.self",
                        "StartCookModeIntent.self",
                        "ContinueCookModeIntent.self",
                        "ForkRecipeIntent.self",
                        "SaveRecipeToCookbookIntent.self",
                        "RemoveRecipeFromCookbookIntent.self",
                        "DeleteRecipeIntent.self",
                        "AddRecipeToCookbookIntent.self",
                        "AddRecipeIngredientsToShoppingListIntent.self",
                        "LogCookIntent.self",
                        "EditCookLogIntent.self",
                        "DeleteCookLogIntent.self",
                        "CreateCoverFromSpoonIntent.self"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    label: "deleteCookbookDomainDonations",
                    pattern: #"private\s+func\s+deleteCookbookDomainDonations\("#,
                    requiredTokens: [
                        "OpenCookbookIntent.self",
                        "SearchSpoonjoyIntent.self",
                        "ShareCookbookIntent.self",
                        "SaveRecipeToCookbookIntent.self",
                        "CreateCookbookIntent.self",
                        "RenameCookbookIntent.self",
                        "DeleteCookbookIntent.self",
                        "AddRecipeToCookbookIntent.self",
                        "RemoveRecipeFromCookbookIntent.self"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    label: "deleteShoppingDomainDonations",
                    pattern: #"private\s+func\s+deleteShoppingDomainDonations\("#,
                    requiredTokens: [
                        "SearchSpoonjoyIntent.self",
                        "ShareShoppingListIntent.self",
                        "AddShoppingListItemIntent.self",
                        "SetShoppingListItemCheckedIntent.self",
                        "RemoveShoppingListItemIntent.self",
                        "AddRecipeIngredientsToShoppingListIntent.self",
                        "ClearCompletedShoppingItemsIntent.self",
                        "ClearShoppingListIntent.self"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    label: "deleteSpoonDomainDonations",
                    pattern: #"private\s+func\s+deleteSpoonDomainDonations\("#,
                    requiredTokens: [
                        "LogCookIntent.self",
                        "EditCookLogIntent.self",
                        "DeleteCookLogIntent.self",
                        "CreateCoverFromSpoonIntent.self"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    label: "deleteCaptureDraftDomainDonations",
                    pattern: #"private\s+func\s+deleteCaptureDraftDomainDonations\("#,
                    requiredTokens: [
                        "CaptureRecipeIntent.self",
                        "SubmitCaptureImportIntent.self",
                        "OpenCaptureDraftIntent.self",
                        "DiscardCaptureDraftIntent.self"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    label: "deleteChefProfileDomainDonations",
                    pattern: #"private\s+func\s+deleteChefProfileDomainDonations\("#,
                    requiredTokens: [
                        "OpenProfileIntent.self",
                        "SearchSpoonjoyIntent.self",
                        "OpenSettingsIntent.self",
                        "ReadNotificationPreferencesIntent.self",
                        "UpdateNotificationPreferencesIntent.self",
                        "OpenNotificationAPNsStatusIntent.self",
                        "UpdateProfileDisplayIntent.self",
                        "UpdateProfilePhotoIntent.self",
                        "RemoveProfilePhotoIntent.self",
                        "OpenAPITokensIntent.self",
                        "CreateAPITokenIntent.self",
                        "RevokeAPITokenIntent.self",
                        "OpenAccountConnectionsIntent.self",
                        "DisconnectAccountConnectionIntent.self",
                        "OpenPasskeysIntent.self",
                        "OpenPasswordIntent.self",
                        "LinkProviderIntent.self",
                        "LogoutIntent.self",
                        "RevokeCurrentSessionIntent.self"
                    ]
                )
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
        let schemaComponent = "schema\(NativeDurableCacheSnapshot.currentSchemaVersion)"
        let shoppingIdentifier = SpotlightIndexPlan.shoppingListItemUniqueIdentifier(itemID: "item_lemons", scope: scope)
        let spoonIdentifier = SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: "spoon_lemon", recipeID: "recipe_pasta", scope: scope)
        let captureIdentifier = SpotlightIndexPlan.captureDraftUniqueIdentifier(draftID: "draft_url", scope: scope)
        let chefProfileIdentifier = SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: "chef_jules", scope: scope)

        #expect(shoppingIdentifier == "production|\(schemaComponent)|account-ari-example-com|shopping-list-item|item_lemons")
        #expect(spoonIdentifier == "production|\(schemaComponent)|account-ari-example-com|spoon|spoon_lemon~recipe_pasta")
        #expect(captureIdentifier == "production|\(schemaComponent)|account-ari-example-com|capture-draft|draft_url")
        #expect(chefProfileIdentifier == "production|\(schemaComponent)|account-ari-example-com|chef-profile|chef_jules")
        #expect(SpotlightIndexPlan.domainIdentifiers(scope: scope) == [
            "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.recipe",
            "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.cookbook",
            "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.shopping-list-item",
            "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.spoon",
            "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.capture-draft",
            "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.chef-profile"
        ])
        #expect(SpotlightIndexPlan.shoppingListItemDomainIdentifier(scope: scope) == "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.shopping-list-item")
        #expect(SpotlightIndexPlan.spoonDomainIdentifier(scope: scope) == "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.spoon")
        #expect(SpotlightIndexPlan.captureDraftDomainIdentifier(scope: scope) == "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.capture-draft")
        #expect(SpotlightIndexPlan.chefProfileDomainIdentifier(scope: scope) == "app.spoonjoy.\(schemaComponent).production.account-ari-example-com.chef-profile")
        #expect(!shoppingIdentifier.contains("@"))
        #expect(!spoonIdentifier.contains("@"))
        #expect(!captureIdentifier.contains("@"))
        #expect(!chefProfileIdentifier.contains("@"))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|shopping-list-item|../secret", scope: scope) == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|spoon|spoon_lemon~recipe_pasta", scope: scope) == .recipeDetail(id: "recipe_pasta", presentation: .detail))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|spoon|spoon_lemon", scope: scope) == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|capture-draft|draft_url", scope: scope) == .capture)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|chef-profile|chef_jules", scope: scope) == .profile(identifier: "chef_jules"))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|chef-profile|chef..secret", scope: scope) == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|shopping-list-item|item_lemons", scope: SpotlightIndexScope(accountID: "account-other-example-com", environment: .production)) == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|\(schemaComponent)|account-ari-example-com|shopping-list-item|item_lemons", scope: SpotlightIndexScope(accountID: "account.ari@example.com", environment: .local)) == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|schema1|account-ari-example-com|shopping-list-item|item_lemons", scope: scope) == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|account-ari-example-com|shopping-list-item|item_lemons", scope: scope) == .unknownLink)
    }

    @Test("Spotlight documents include semantic spoon capture draft and chef profile entities")
    func spotlightDocumentsIncludeSemanticSpoonCaptureDraftAndChefProfileEntities() {
        let scope = SpotlightIndexScope(accountID: "account_ari", environment: .local)
        let shoppingList = ShoppingListState(
            id: "shopping_empty",
            chef: ChefSummary(id: "account_ari", username: "ari"),
            items: [],
            nextCursor: "",
            updatedAt: "2026-06-29T11:00:00.000Z"
        )

        let documents = SpotlightIndexPlan.documents(
            recipes: [],
            cookbooks: [],
            shoppingList: shoppingList,
            spoons: [SpoonEntityDescriptor.placeholder],
            captureDrafts: [CaptureDraftEntityDescriptor.placeholder],
            chefProfiles: [ChefProfileEntityDescriptor.placeholder],
            scope: scope
        )

        #expect(documents.map(\.type) == [.spoon, .captureDraft, .chefProfile])
        #expect(documents.map(\.route) == [
            .recipeDetail(id: "recipe-placeholder", presentation: .detail),
            .capture,
            .profile(identifier: "Spoonjoy")
        ])
        #expect(documents.map(\.domainIdentifier) == [
            SpotlightIndexPlan.spoonDomainIdentifier(scope: scope),
            SpotlightIndexPlan.captureDraftDomainIdentifier(scope: scope),
            SpotlightIndexPlan.chefProfileDomainIdentifier(scope: scope)
        ])

        let spoon = documents[0]
        #expect(spoon.uniqueIdentifier == SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: "spoon-placeholder", recipeID: "recipe-placeholder", scope: scope))
        #expect(spoon.keywords.contains("Recipe"))

        let captureDraft = documents[1]
        #expect(captureDraft.uniqueIdentifier == SpotlightIndexPlan.captureDraftUniqueIdentifier(draftID: "capture-draft-placeholder", scope: scope))
        #expect(captureDraft.keywords.contains(CaptureDraftImportReadiness.ready.rawValue))

        let chefProfile = documents[2]
        #expect(chefProfile.uniqueIdentifier == SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: "chef-profile-placeholder", scope: scope))
        #expect(chefProfile.keywords == [
            "Spoonjoy",
            SpotlightIndexType.chefProfile.rawValue,
            "Chef Profile",
            "Spoonjoy chef profile"
        ])
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

private func spotlightShortcutBodyContractFailures(
    contracts: [(relativePath: String, label: String, pattern: String, requiredTokens: [String])]
) -> [String] {
    var failures: [String] = []
    for contract in contracts {
        guard let source = try? spotlightShortcutReadRepoFile(contract.relativePath) else {
            failures.append("\(contract.relativePath) missing")
            continue
        }
        let uncommented = spotlightShortcutUncommentedSwift(source)
        guard let body = spotlightShortcutDeclarationBody(in: uncommented, pattern: contract.pattern) else {
            failures.append("\(contract.relativePath) missing body for \(contract.label)")
            continue
        }
        for token in contract.requiredTokens where !body.contains(token) {
            failures.append("\(contract.relativePath) \(contract.label) missing \(token)")
        }
    }
    return failures.sorted()
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

private func spotlightShortcutDeclarationBody(in content: String, pattern: String) -> String? {
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
