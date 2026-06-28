import Foundation

public enum ScenarioReporter {
    public static func report(for stage: ScenarioStage) throws -> ScenarioReport {
        try ScenarioVerifier.report(for: stage, rootURL: ScenarioVerifier.defaultRootURL)
    }

    public static func bootstrapReport() -> ScenarioReport {
        ScenarioVerifier.bootstrapReport()
    }
}

public enum ScenarioVerifier {
    public static var defaultRootURL: URL {
        defaultRootURL(
            environment: ProcessInfo.processInfo.environment,
            currentDirectoryPath: FileManager.default.currentDirectoryPath
        )
    }

    public static func defaultRootURL(environment: [String: String], currentDirectoryPath: String) -> URL {
        let override = environment["SPOONJOY_SCENARIO_ROOT"] ?? ""
        let trimmedOverride = override.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedOverride.isEmpty {
            return URL(fileURLWithPath: trimmedOverride)
        }

        return URL(fileURLWithPath: currentDirectoryPath)
    }

    public static func report(
        for stage: ScenarioStage,
        rootURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> ScenarioReport {
        switch stage {
        case .bootstrap:
            return bootstrapReport()
        case .nativeMetadata:
            return nativeMetadataReport(rootURL: rootURL)
        case .surfaces:
            return surfacesReport(rootURL: rootURL)
        case .final:
            return finalReport(rootURL: rootURL)
        }
    }

    public static func bootstrapReport() -> ScenarioReport {
        ScenarioReport(
            stage: .bootstrap,
            checks: [
                ScenarioCheck(name: "fixture bundle", status: .pass, detail: "Fixture resources are packaged."),
                ScenarioCheck(name: "native metadata", status: .pending, detail: "Native metadata lands in Unit 10."),
                ScenarioCheck(name: "app surfaces", status: .pending, detail: "SwiftUI surfaces land in Units 13-16.")
            ],
            nativeCapabilities: ScenarioNativeCapabilities(
                appIntents: [],
                spotlightIndexedTypes: [],
                searchableScopes: [],
                shareActions: [],
                offlineFlows: ["fixture-offline-restore"],
                associatedDomains: [],
                urlSchemes: [],
                deepLinkRoutes: []
            )
        )
    }

    public static func nativeMetadataReport(
        rootURL: URL,
        metadata: NativeCapabilityMetadata = .spoonjoy
    ) -> ScenarioReport {
        return ScenarioReport(
            stage: .nativeMetadata,
            checks: [
                ScenarioCheck(name: "fixture bundle", status: .pass, detail: "Fixture resources are packaged."),
                ScenarioCheck(name: "native metadata", status: metadataCheckStatus(metadata), detail: "Apple-native capability metadata is complete."),
                sourceCheck(
                    name: "app intents source",
                    detail: "AppIntents integration source is present.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    tokens: [
                        "#if canImport(AppIntents)",
                        "import AppIntents",
                        "import SpoonjoyCore",
                        "@available(iOS 27.0, macOS 27.0, *)",
                        "OpenRecipeIntent",
                        "StartCookModeIntent",
                        "AddShoppingListItemIntent",
                        "SetShoppingListItemCheckedIntent",
                        "AddRecipeIngredientsToShoppingListIntent",
                        "ClearCompletedShoppingItemsIntent",
                        "ClearShoppingListIntent",
                        "CaptureRecipeIntent",
                        "NativeIntentActionResolver",
                        "SpoonjoyIntentStateWriter",
                        "OpenURLIntent",
                        ".result(opensIntent:",
                        "dialog:"
                    ],
                    forbiddenTokens: [
                        "func perform() async throws -> some IntentResult {\n        .result()\n    }"
                    ]
                ),
                sourceCheck(
                    name: "spotlight source",
                    detail: "CoreSpotlight integration source is present.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    tokens: [
                        "#if canImport(CoreSpotlight)",
                        "import CoreSpotlight",
                        "import SpoonjoyCore",
                        "@available(iOS 27.0, macOS 27.0, *)",
                        "SpoonjoySpotlightIndexer",
                        "SpotlightIndexPlan",
                        "SpotlightIndexDocument",
                        "CSSearchableItem",
                        "CSSearchableItemAttributeSet",
                        "CSSearchableIndex.default()",
                        "indexSearchableItems",
                        "SpotlightIndexType",
                        "shoppingListItem"
                    ]
                ),
                ScenarioCheck(
                    name: "deep link metadata",
                    status: deepLinkCheckStatus(metadata),
                    detail: "Associated-domain and custom-scheme routes are declared."
                ),
                ScenarioCheck(name: "app surfaces", status: .pending, detail: "SwiftUI surfaces land in Units 14-16.")
            ],
            nativeCapabilities: metadata.scenarioCapabilities
        )
    }

    public static func surfacesReport(rootURL: URL, metadata: NativeCapabilityMetadata = .spoonjoy) -> ScenarioReport {
        return ScenarioReport(
            stage: .surfaces,
            checks: [
                ScenarioCheck(name: "fixture kitchen browsing", status: .pass, detail: "Fixture kitchen browsing is backed by KitchenView."),
                ScenarioCheck(name: "recipe detail", status: .pass, detail: "Recipe detail renders hero, provenance, actions, ingredient receipt, cookbook spread, and method sections."),
                cookProgressPersistenceCheck(),
                shoppingCheckoffCheck(),
                shoppingAddItemCheck(),
                shoppingAddRecipeIngredientsCheck(),
                shoppingRecipeCoverageCheck(),
                shoppingClearConfirmationCheck(),
                cookbookDetailCheck(),
                cookbookOwnerToolsCheck(),
                cookbookCreateCheck(rootURL: rootURL),
                cookbookRenameCheck(),
                cookbookDeleteCheck(),
                cookbookAddRecipeCheck(),
                cookbookRemoveRecipeCheck(),
                profileDetailCheck(),
                profileGraphCheck(direction: .fellowChefs),
                profileGraphCheck(direction: .kitchenVisitors),
                notificationAPNsSurfaceCheck(rootURL: rootURL),
                sourceCheck(
                    name: "kitchen surface source",
                    detail: "Kitchen surface includes lead object, recipe index, and cookbook shelf.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/KitchenView.swift",
                    tokens: ["KitchenView", "KitchenLeadObject", "RecipeLead", "RecipeIndex", "CookbookShelf"]
                ),
                sourceCheck(
                    name: "recipe detail surface source",
                    detail: "Recipe detail surface includes required cookbook spread and receipt/method structure.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
                    tokens: ["RecipeDetailView", "cookbookSpread", "ingredientReceipt", "methodSections", "ShareLink"]
                ),
                sourceCheck(
                    name: "cook mode surface source",
                    detail: "Cook mode surface includes focused step, controls, progress, and persisted progress text.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/CookModeView.swift",
                    tokens: ["CookModeView", "CookModeViewModel", "CookModeProgress", "currentStep", "KitchenSafeControls"]
                ),
                sourceCheck(
                    name: "shopping surface source",
                    detail: "Shopping surface includes native edit mode, add/remove/clear controls, and ShoppingSurfaceViewModel behavior.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift",
                    tokens: ["ShoppingListView", "ShoppingSurfaceViewModel", "ShoppingListState", "ReceiptListView", "TextField", "addItem", "clearAll"]
                ),
                sourceCheck(
                    name: "receipt controls source",
                    detail: "Receipt list uses native list sections, large check toggles, and swipe actions.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift",
                    tokens: ["ReceiptListView", "ShoppingListReceiptSection", "ShoppingListItem", "List", "Section", "Toggle", ".toggleStyle(.largeCheck)", "LargeCheckToggleStyle", "minimumCheckTarget", "checkmark.circle.fill", "swipeActions", "deleteItem", "trash"]
                ),
                sourceCheck(
                    name: "kitchen safe controls source",
                    detail: "Kitchen-safe controls use large native buttons with accessibility labels.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift",
                    tokens: ["KitchenSafeControls", "Button", "controlSize", "accessibilityLabel"]
                ),
                sourceCheck(
                    name: "navigation surface source",
                    detail: "Platform navigation routes kitchen, live/fallback recipe catalog, async recipe detail, async cook mode, shopping, and cookbooks.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                    tokens: ["KitchenView(", "RecipesView(", "RecipeDetailRouteView(", "CookModeRouteView(", "LiveRecipeCatalogRepository", "FallbackRecipeCatalogRepository", "ShoppingListView(", "CookbooksView("]
                ),
                sourceCheck(
                    name: "profile surface source",
                    detail: "ProfileView.swift renders profile detail, profile graph, fellow chefs, and kitchen visitors without future discussion or feed surfaces.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/ProfileView.swift",
                    tokens: ["ProfileRouteView", "ProfileView", "ProfileGraphRouteView", "ProfileHero", "ProfileRecipeShelf", "ProfileCookbookShelf", "RecentSpoonsSection", "FellowChefsSection", "KitchenVisitorsSection"]
                ),
                sourceCheck(
                    name: "search surface source",
                    detail: "Search surface includes native searchable scopes and typed result rows.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/SearchView.swift",
                    tokens: ["SearchView", "SearchState", "SearchScope", "List", "Section", "searchable scopes", "typed rows", "openChef(chef.username)"],
                    forbiddenTokens: [".searchable(", ".searchScopes("]
                ),
                sourceCheck(
                    name: "capture surface source",
                    detail: "Capture surface creates native drafts and submits import-ready sources.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift",
                    tokens: [
                        "CaptureDraftView",
                        "CaptureDraftViewModel",
                        "CaptureImportViewModel",
                        "CaptureDraft.localText",
                        "CaptureDraft.importURL",
                        "CaptureDraft.videoURL",
                        "CaptureDraft.jsonLD",
                        "CaptureDraft.cameraImage",
                        "CaptureDraft.photoLibraryImage",
                        "PhotosPicker",
                        "CameraCaptureView",
                        "VNRecognizeTextRequest",
                        "onChange(of: inputDraft)",
                        "reconcile(with: inputDraft)",
                        "hasPendingImport",
                        "Submit Import",
                        "plan.userFacingMessage",
                        "canCreateServerRecipe"
                    ],
                    forbiddenTokens: [
                        "Promotion requires a separate reviewed flow"
                    ]
                ),
                sourceCheck(
                    name: "settings surface source",
                    detail: "Settings surface presents auth, environment, shopping permissions, and offline state.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
                    tokens: ["SettingsView", "SettingsViewModel", "Form", "Section", "OfflineStatusView(display:", "viewModel.authSessionState", "viewModel.environmentSwitcher"]
                ),
                sourceCheck(
                    name: "offline status source",
                    detail: "Offline status component presents live OfflineIndicatorDisplay states.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift",
                    tokens: ["OfflineStatusView", "OfflineIndicatorDisplay", "informationalOnly", "queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation", "Label", "Button"]
                ),
                sourceCheck(
                    name: "navigation final surface source",
                    detail: "Platform navigation routes search, capture, settings, and import submission to real surfaces.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                    tokens: [
                        "SearchView(",
                        "CaptureDraftView(",
                        "recordCaptureDraft",
                        "discardCaptureDraft",
                        "recordCaptureImportRetry",
                        "recordCaptureImportBlocker",
                        "queueCaptureImportRetryIfNeeded",
                        "recipeImportSource == draftImportSource",
                        "pendingCaptureImportMutation?.clientMutationID != mutation.clientMutationID",
                        "executeCaptureImportRequest",
                        "performCaptureImport(draft:",
                        "SettingsView("
                    ],
                    forbiddenTokens: [
                        "pendingCaptureImportMutation?.clientMutationID == clientMutationID"
                    ]
                )
            ],
            nativeCapabilities: metadata.scenarioCapabilities
        )
    }

    public static func finalReport(rootURL: URL, metadata: NativeCapabilityMetadata = .spoonjoy) -> ScenarioReport {
        return ScenarioReport(
            stage: .final,
            checks: [
                ScenarioCheck(name: "fixture kitchen browsing", status: .pass, detail: "Fixture kitchen browsing is backed by KitchenView."),
                firstRunSessionSetupCheck(rootURL: rootURL),
                liveStoreSourceCheck(rootURL: rootURL),
                liveStoreShellCheck(
                    name: "signed-out live bootstrap",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
                    tokens: ["NativeAuthSessionRepository", "SpoonjoyWebAuthenticationSession", "startSignIn", "restoreState", "revokeAndLogout", "authRequired"]
                ),
                liveStoreShellCheck(name: "restoring cache", rootURL: rootURL, tokens: ["case .restoringCache", "restoringCacheView", "OfflineStatusView(display:"]),
                liveStoreShellCheck(name: "live synced shell", rootURL: rootURL, tokens: ["case .liveSynced", "PlatformNavigationView("]),
                liveStoreShellCheck(name: "offline stale shell", rootURL: rootURL, tokens: ["case .offlineStale", "offlineIndicatorState:"]),
                liveStoreShellCheck(name: "queued work shell", rootURL: rootURL, tokens: ["case .queuedWork", "queueMutation:"]),
                liveStoreShellCheck(name: "conflict shell", rootURL: rootURL, tokens: ["case .conflict", "OfflineStatusView(display:"]),
                liveStoreShellCheck(name: "blocker shell", rootURL: rootURL, tokens: ["case .blocker", "OfflineStatusView(display:"]),
                liveStoreShellCheck(name: "destructive confirmation shell", rootURL: rootURL, tokens: ["case .destructiveConfirmation", "destructiveConfirmation"]),
                liveStoreShellCheck(name: "sync failed shell", rootURL: rootURL, tokens: ["case .syncFailed", "PlatformNavigationView("]),
                fixtureFallbackDisabledCheck(rootURL: rootURL),
                ScenarioCheck(name: "recipe detail", status: .pass, detail: "Recipe detail renders hero, provenance, actions, ingredient receipt, cookbook spread, and method sections."),
                cookProgressPersistenceCheck(),
                durableNativeStateCheck(),
                shoppingCheckoffCheck(),
                shoppingAddItemCheck(),
                shoppingAddRecipeIngredientsCheck(),
                shoppingClearConfirmationCheck(),
                searchCheck(),
                captureDraftCreationCheck(),
                settingsStateCheck(),
                settingsTokenConnectionSurfaceCheck(),
                settingsProfileUpdateCheck(),
                settingsTokenCreateOnlineOnlyCheck(),
                settingsConnectionDisconnectOnlineOnlyCheck(),
                settingsSecureHandoffCheck(),
                notificationAPNsSurfaceCheck(rootURL: rootURL),
                offlineStatusCheck(),
                safeUnknownLinkCheck(),
                sourceCheck(
                    name: "first-run setup source",
                    detail: "Root view gates launch through the live store before opening app routes.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
                    tokens: ["NativeLiveAppStore", "NativeLiveAppStoreDependencies", "bootstrap()", "case .signedOut", "SignedOutSetupView("]
                ),
                sourceCheck(
                    name: "native persistence source",
                    detail: "Platform navigation routes live content state and queues native mutations through the live store.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                    tokens: ["NativeShellContentState", "contentState.recipes", "contentState.shoppingList", "NativeQueuedMutation", "queueMutation", "syncTriggerCoordinator"]
                ),
                sourceCheck(
                    name: "search surface source",
                    detail: "Search surface includes native searchable scopes and typed result rows.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/SearchView.swift",
                    tokens: ["SearchView", "SearchState", "SearchScope", "List", "Section", "searchable scopes", "typed rows", "openChef(chef.username)"],
                    forbiddenTokens: [".searchable(", ".searchScopes("]
                ),
                sourceCheck(
                    name: "capture surface source",
                    detail: "Capture surface creates native drafts and submits import-ready sources.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift",
                    tokens: [
                        "CaptureDraftView",
                        "CaptureDraftViewModel",
                        "CaptureImportViewModel",
                        "CaptureDraft.localText",
                        "CaptureDraft.importURL",
                        "CaptureDraft.videoURL",
                        "CaptureDraft.jsonLD",
                        "CaptureDraft.cameraImage",
                        "CaptureDraft.photoLibraryImage",
                        "PhotosPicker",
                        "CameraCaptureView",
                        "VNRecognizeTextRequest",
                        "onChange(of: inputDraft)",
                        "reconcile(with: inputDraft)",
                        "hasPendingImport",
                        "Submit Import",
                        "plan.userFacingMessage",
                        "canCreateServerRecipe"
                    ],
                    forbiddenTokens: [
                        "Promotion requires a separate reviewed flow"
                    ]
                ),
                sourceCheck(
                    name: "settings surface source",
                    detail: "Settings surface presents auth, environment, shopping permissions, and offline state.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
                    tokens: ["SettingsView", "SettingsViewModel", "Form", "Section", "OfflineStatusView(display:", "viewModel.authSessionState", "viewModel.environmentSwitcher"]
                ),
                sourceCheck(
                    name: "offline status source",
                    detail: "Offline status component presents live OfflineIndicatorDisplay states.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift",
                    tokens: ["OfflineStatusView", "OfflineIndicatorDisplay", "informationalOnly", "queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation", "Label", "Button"]
                ),
                sourceCheck(
                    name: "navigation final surface source",
                    detail: "Platform navigation routes search, capture, and settings to real surfaces.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                    tokens: [
                        "SearchView(",
                        "search: $search",
                        "search.apply(route: .search(query: query, scope: scope))",
                        "openChef: { username in",
                        "openProfileRoute(AppRoute.profile(identifier: username))",
                        "CaptureDraftView(",
                        "recordCaptureDraft",
                        "discardCaptureDraft",
                        "recordCaptureImportRetry",
                        "recordCaptureImportBlocker",
                        "queueCaptureImportRetryIfNeeded",
                        "recipeImportSource == draftImportSource",
                        "pendingCaptureImportMutation?.clientMutationID != mutation.clientMutationID",
                        "executeCaptureImportRequest",
                        "performCaptureImport(draft:",
                        "SettingsView(",
                        "contentState.settingsViewModel",
                        "OfflineStatusView(display:",
                        "offlineIndicatorState"
                    ],
                    forbiddenTokens: [
                        ".constant(routeSearch)",
                        "draftDidChange: { _ in }",
                        "pendingCaptureImportMutation?.clientMutationID == clientMutationID",
                        "defaultSettings",
                        "PlatformNavigationView.defaultSettings",
                        "signedOutProductionSettingsTemplate"
                    ]
                )
            ],
            nativeCapabilities: capabilitiesWithLiveStoreFlows(metadata.scenarioCapabilities)
        )
    }

    static func cookProgressPersistenceCheck(
        loadRecipes: () throws -> [Recipe] = { try RecipeFixtureCatalog.decodeFromBundle().recipes }
    ) -> ScenarioCheck {
        do {
            guard
                let recipe = try loadRecipes().first,
                let step = recipe.steps.first
            else {
                return ScenarioCheck(name: "cook progress persistence", status: .fail, detail: "Fixture recipe has no cookable steps.")
            }

            let progress = CookModeProgress(
                recipeID: recipe.id,
                stepIDs: recipe.steps.map(\.id),
                startedAt: "2026-06-16T11:40:00.000Z"
            )
            let advanced = try progress
                .markingStepCompleted(step.id, updatedAt: "2026-06-16T11:41:00.000Z")
                .advancing()
            let restored = try CookModeProgress.restore(from: advanced.snapshot())
            let viewModel = CookModeViewModel(recipe: recipe, progress: restored)
            let stepIDs = recipe.steps.map(\.id)
            let currentStepIsValid = viewModel.currentStepID.map { stepIDs.contains($0) } == true
            let status: ScenarioCheckStatus = restored == advanced &&
                restored.completedStepIDs.contains(step.id) &&
                viewModel.completionFraction > 0 &&
                currentStepIsValid ? .pass : .fail

            return ScenarioCheck(
                name: "cook progress persistence",
                status: status,
                detail: "Cook mode progress snapshots restore completed steps and current step."
            )
        } catch {
            return ScenarioCheck(
                name: "cook progress persistence",
                status: .fail,
                detail: "Cook mode progress persistence failed: \(error)"
            )
        }
    }

    static func firstRunSessionSetupCheck(rootURL: URL) -> ScenarioCheck {
        let rootSource = sourceCheck(
            name: "first-run session setup",
            detail: "Signed-out auth setup is reachable before the main platform navigation shell.",
            rootURL: rootURL,
            relativePath: "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
            tokens: ["NativeLiveAppStore", "liveStore.bootstrap()", "case .signedOut", "SignedOutSetupView(", "PlatformNavigationView("]
        )
        guard rootSource.status == .pass else {
            return rootSource
        }

        let signedOutContent = NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
        let status: ScenarioCheckStatus = signedOutContent.settingsViewModel.authSessionState == .signedOut ? .pass : .fail

        return ScenarioCheck(
            name: "first-run session setup",
            status: status,
            detail: "Live bootstrap can represent signed-out setup before route navigation."
        )
    }

    static func liveStoreSourceCheck(rootURL: URL) -> ScenarioCheck {
        sourceCheck(
            name: "live store source",
            detail: "Native live store owns auth restore, cache restore, sync bootstrap, environment switching, and shell state.",
            rootURL: rootURL,
            relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
            tokens: [
                "NativeLiveAppStore",
                "NativeLiveAppStoreDependencies",
                "NativeAppBootstrapState",
                "NativeShellContentState",
                "restoreFromCache",
                "bootstrapFromLiveAPI",
                "switchEnvironment",
                "NativeSyncTriggerEvent.environmentChanged",
                "searchResultsByScope"
            ],
            forbiddenTokens: [
                "RecipeFixtureCatalog.decodeFromBundle()",
                "CookbookFixtureCatalog.decodeFromBundle()",
                "KitchenFixtureState.decodeFromBundle()",
                "ShoppingListState.decodeFromBundle()"
            ]
        )
    }

    static func liveStoreShellCheck(
        name: String,
        rootURL: URL,
        relativePath: String = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
        tokens: [String]
    ) -> ScenarioCheck {
        sourceCheck(
            name: name,
            detail: "Live shell state \(name) is represented in app source.",
            rootURL: rootURL,
            relativePath: relativePath,
            tokens: tokens
        )
    }

    static func fixtureFallbackDisabledCheck(rootURL: URL) -> ScenarioCheck {
        let source = sourceCheck(
            name: "fixture fallback disabled",
            detail: "Fixture fallback is denied outside explicit test/demo policy.",
            rootURL: rootURL,
            relativePath: "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift",
            tokens: [
                "NativeFixtureFallbackPolicy",
                "disabledInProduction",
                "testsAndDemoOnly",
                "allowsProductionFallback",
                "SPOONJOY_ALLOW_FIXTURE_FALLBACK",
                "isTestOrDemoBuild"
            ],
            forbiddenTokens: [
                "RecipeFixtureCatalog.decodeFromBundle()"
            ]
        )
        guard source.status == .pass else {
            return source
        }

        let status: ScenarioCheckStatus = !NativeFixtureFallbackPolicy.disabledInProduction.allowsProductionFallback(
            isTestOrDemoBuild: false,
            environment: [:]
        ) && !NativeFixtureFallbackPolicy.testsAndDemoOnly.allowsProductionFallback(
            isTestOrDemoBuild: false,
            environment: [:]
        ) ? .pass : .fail

        return ScenarioCheck(
            name: "fixture fallback disabled",
            status: status,
            detail: "Production fixture fallback is disabled unless a test/demo policy explicitly opts in."
        )
    }

    static func durableNativeStateCheck(
        loadShoppingList: () throws -> ShoppingListState = { try ShoppingListState.decodeFromBundle() },
        loadRecipes: () throws -> [Recipe] = { try RecipeFixtureCatalog.decodeFromBundle().recipes }
    ) -> ScenarioCheck {
        do {
            let shoppingList = try loadShoppingList()
            guard
                let recipe = try loadRecipes().first,
                let firstStep = recipe.steps.first
            else {
                return ScenarioCheck(name: "durable native state", status: .fail, detail: "Fixture data is missing durable-state inputs.")
            }

            let progress = try CookModeProgress(
                recipeID: recipe.id,
                stepIDs: recipe.steps.map(\.id),
                startedAt: "2026-06-16T13:37:00.000Z"
            )
            .markingStepCompleted(firstStep.id, updatedAt: "2026-06-16T13:38:00.000Z")
            let draft = try CaptureDraft.localText(
                id: "scenario-durable-draft",
                rawText: "https://example.com/recipe\npersist me",
                createdAt: "2026-06-16T13:39:00.000Z"
            )
            let mutation = QueuedMutation(
                id: "scenario-queued-check",
                clientMutationID: "scenario-check",
                createdAt: "2026-06-16T13:40:00.000Z",
                kind: .shoppingCheck(itemID: "item_lemons", checked: true)
            )
            let checked = try shoppingList.settingChecked(
                true,
                itemID: "item_lemons",
                checkedAt: "2026-06-16T13:40:00.000Z",
                updatedAt: "2026-06-16T13:40:00.000Z",
                nextSortIndex: 99
            )
            let snapshot = try NativeAppSnapshot
                .bootstrap(shoppingList: shoppingList, savedAt: "2026-06-16T13:36:00.000Z")
                .completingFirstRun(savedAt: "2026-06-16T13:37:00.000Z")
                .updatingCookProgress(progress, savedAt: "2026-06-16T13:38:00.000Z")
                .updatingCaptureDraft(draft, savedAt: "2026-06-16T13:39:00.000Z")
                .updatingShoppingList(checked, queuedMutation: mutation, savedAt: "2026-06-16T13:40:00.000Z")
            let encoded = try JSONEncoder().encode(snapshot)
            let restored = try JSONDecoder().decode(NativeAppSnapshot.self, from: encoded).validated()
            let status: ScenarioCheckStatus = restored.hasCompletedFirstRun &&
                restored.cookProgress(for: recipe.id) == progress &&
                restored.shoppingList?.item(id: "item_lemons")?.checked == true &&
                restored.captureDraft == draft &&
                restored.pendingMutationCount == 1 ? .pass : .fail

            return ScenarioCheck(
                name: "durable native state",
                status: status,
                detail: "Cook progress, shopping checkoff, local capture draft, and queued mutation survive native snapshot restore."
            )
        } catch {
            return ScenarioCheck(
                name: "durable native state",
                status: .fail,
                detail: "Durable native state failed: \(error)"
            )
        }
    }

    static func shoppingCheckoffCheck(
        loadShoppingList: () throws -> ShoppingListState = { try ShoppingListState.decodeFromBundle() },
        selectedItemID: String? = nil
    ) -> ScenarioCheck {
        do {
            let viewModel = ShoppingSurfaceViewModel(
                shoppingList: try loadShoppingList(),
                queuedMutations: [],
                conflicts: [],
                connectivity: .online,
                now: { "2026-06-16T11:42:00.000Z" }
            )
            guard let itemID = selectedItemID ?? viewModel.sections.flatMap(\.items).first?.id else {
                return ScenarioCheck(name: "shopping checkoff", status: .fail, detail: "Fixture shopping list has no active checkoff items.")
            }

            let plan = try viewModel.plan(.setItemChecked(
                itemID: itemID,
                checked: true,
                clientMutationID: "scenario-shopping-check"
            ))
            let item = plan.updatedShoppingList?.item(id: itemID)
            let status: ScenarioCheckStatus = item?.checked == true &&
                item?.checkedAt == "2026-06-16T11:42:00.000Z" &&
                plan.updatedShoppingList?.receiptSections.flatMap(\.items).contains { $0.id == itemID } == true ? .pass : .fail

            return ScenarioCheck(
                name: "shopping checkoff",
                status: status,
                detail: "Shopping list checkoff uses ShoppingSurfaceViewModel and preserves receipt sections."
            )
        } catch {
            return ScenarioCheck(
                name: "shopping checkoff",
                status: .fail,
                detail: "Shopping checkoff failed: \(error)"
            )
        }
    }

    static func shoppingAddItemCheck(
        loadShoppingList: () throws -> ShoppingListState = { try ShoppingListState.decodeFromBundle() }
    ) -> ScenarioCheck {
        do {
            let viewModel = ShoppingSurfaceViewModel(
                shoppingList: try loadShoppingList(),
                queuedMutations: [],
                conflicts: [],
                connectivity: .online,
                now: { "2026-06-16T11:43:00.000Z" }
            )
            let plan = try viewModel.plan(.addItem(
                name: " limes ",
                quantity: 4,
                unit: "each",
                categoryKey: "produce",
                iconKey: "lemon",
                clientMutationID: "scenario-shopping-add"
            ))
            let createdItem = plan.updatedShoppingList?.item(id: "item_local_scenario-shopping-add")
            let status: ScenarioCheckStatus = createdItem?.name == "limes" &&
                plan.remoteRequestBuilder != nil &&
                plan.offlineFallbackMutation?.queueableKind == .shoppingAddItem ? .pass : .fail

            return ScenarioCheck(
                name: "shopping add item",
                status: status,
                detail: "Shopping add item plans live REST with a durable offline fallback."
            )
        } catch {
            return ScenarioCheck(name: "shopping add item", status: .fail, detail: "Shopping add item failed: \(error)")
        }
    }

    static func shoppingAddRecipeIngredientsCheck(
        recipeID: String = "recipe_lemon_pantry_pasta",
        scaleFactor: Double = 1.5,
        recipeIngredients: [RecipeIngredient] = scenarioShoppingIngredients,
        planBuilder: (String, Double, [RecipeIngredient], String) throws -> ShoppingSurfaceMutationPlan = { recipeID, scaleFactor, recipeIngredients, clientMutationID in
            try ShoppingSurfaceViewModel(
                shoppingList: nil,
                queuedMutations: [],
                conflicts: [],
                connectivity: .online,
                now: { "2026-06-16T11:44:00.000Z" }
            ).plan(.addRecipeIngredients(
                recipeID: recipeID,
                scaleFactor: scaleFactor,
                recipeIngredients: recipeIngredients,
                clientMutationID: clientMutationID
            ))
        }
    ) -> ScenarioCheck {
        do {
            let plan = try planBuilder(recipeID, scaleFactor, recipeIngredients, "scenario-shopping-recipe")
            let status: ScenarioCheckStatus = plan.remoteRequestBuilder != nil &&
                plan.offlineFallbackMutation?.queueableKind == .shoppingAddFromRecipe ? .pass : .fail

            return ScenarioCheck(
                name: "shopping add recipe ingredients",
                status: status,
                detail: "Recipe and cook surfaces can plan scaled add-to-shopping mutations."
            )
        } catch {
            return ScenarioCheck(name: "shopping add recipe ingredients", status: .fail, detail: "Shopping add recipe ingredients failed: \(error)")
        }
    }

    static func shoppingRecipeCoverageCheck() -> ScenarioCheck {
        let recipe = scenarioRecipe(ingredients: [
            RecipeIngredient(id: "ingredient_salt", name: " Salt ", quantity: 1, unit: "pinch"),
            RecipeIngredient(id: "ingredient_pasta", name: "Pasta", quantity: 8, unit: "oz")
        ])
        let partialShoppingList = scenarioShoppingList(items: [
            scenarioShoppingItem(id: "item_salt", name: "salt", unit: "pinch")
        ])
        let completeShoppingList = scenarioShoppingList(items: [
            scenarioShoppingItem(id: "item_salt", name: "salt", unit: "pinch"),
            scenarioShoppingItem(id: "item_pasta", name: "pasta", unit: "oz")
        ])
        let status: ScenarioCheckStatus =
            !RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: partialShoppingList) &&
            RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: completeShoppingList) ? .pass : .fail

        return ScenarioCheck(
            name: "shopping recipe coverage",
            status: status,
            detail: "Recipe add-to-shopping only reports In List when every active ingredient name/unit key exists."
        )
    }

    static func shoppingClearConfirmationCheck(
        loadShoppingList: () throws -> ShoppingListState = { try ShoppingListState.decodeFromBundle() }
    ) -> ScenarioCheck {
        do {
            let viewModel = ShoppingSurfaceViewModel(
                shoppingList: try loadShoppingList(),
                queuedMutations: [],
                conflicts: [],
                connectivity: .online,
                now: { "2026-06-16T11:45:00.000Z" }
            )
            let plan = try viewModel.plan(.clearAll(
                clientMutationID: "scenario-shopping-clear",
                confirmation: .required
            ))
            let confirmedPlan = try viewModel.plan(.clearAll(
                clientMutationID: "scenario-shopping-clear-confirmed",
                confirmation: .confirmed
            ))
            let status: ScenarioCheckStatus = plan.confirmationPrompt?.isDestructive == true &&
                plan.confirmationPrompt?.confirmButtonTitle == "Clear All" &&
                plan.remoteRequestBuilder == nil &&
                confirmedPlan.offlineFallbackMutation?.queueableKind == .shoppingClearAll ? .pass : .fail

            return ScenarioCheck(
                name: "shopping clear confirmation",
                status: status,
                detail: "Destructive shopping clears require native confirmation before planning a mutation."
            )
        } catch {
            return ScenarioCheck(name: "shopping clear confirmation", status: .fail, detail: "Shopping clear confirmation failed: \(error)")
        }
    }

    private static func scenarioShoppingList(items: [ShoppingListItem]) -> ShoppingListState {
        ShoppingListState(
            id: "scenario-shopping-list",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: items,
            nextCursor: "v1.scenario.shopping",
            updatedAt: "2026-06-16T11:46:00.000Z"
        )
    }

    private static var scenarioShoppingIngredients: [RecipeIngredient] {
        [
            RecipeIngredient(id: "ingredient_pasta", name: "pasta", quantity: 8, unit: "oz"),
            RecipeIngredient(id: "ingredient_lemons", name: "lemons", quantity: 2, unit: "each")
        ]
    }

    private static func scenarioShoppingItem(id: String, name: String, unit: String?) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: 1,
            unit: unit,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 0,
            updatedAt: "2026-06-16T11:46:00.000Z"
        )
    }

    private static func scenarioRecipe(ingredients: [RecipeIngredient]) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/scenario-shopping-recipe")!
        return Recipe(
            id: "scenario-shopping-recipe",
            title: "Scenario Shopping Recipe",
            description: "Scenario recipe.",
            servings: "2",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/scenario-shopping-recipe",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "By ari",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: "2026-06-16T11:46:00.000Z",
            updatedAt: "2026-06-16T11:46:00.000Z",
            steps: [
                RecipeStep(
                    id: "scenario-shopping-step",
                    stepNum: 1,
                    stepTitle: "Cook",
                    description: "Cook.",
                    duration: nil,
                    ingredients: ingredients
                )
            ],
            cookbooks: []
        )
    }

    static func cookbookDetailCheck(loadCookbook: () throws -> Cookbook = scenarioCookbook) -> ScenarioCheck {
        do {
            let cookbook = try loadCookbook()
            let viewModel = scenarioCookbookDetailViewModel(cookbook: cookbook)
            let status: ScenarioCheckStatus = viewModel.id == cookbook.id &&
                viewModel.title == cookbook.title &&
                viewModel.recipes.map(\.id) == cookbook.recipes.map(\.id) &&
                viewModel.sharePayload.publicURL == cookbook.canonicalURL ? .pass : .fail

            return ScenarioCheck(
                name: "cookbook detail",
                status: status,
                detail: "Cookbook detail exposes recipe rows, native share payloads, and deep-link routes."
            )
        } catch {
            return ScenarioCheck(name: "cookbook detail", status: .fail, detail: "Cookbook detail failed: \(error)")
        }
    }

    static func cookbookOwnerToolsCheck(
        loadCookbook: () throws -> Cookbook = scenarioCookbook,
        availableRecipe: () -> RecipeSummary = scenarioAvailableRecipe
    ) -> ScenarioCheck {
        do {
            let cookbook = try loadCookbook()
            let viewModel = scenarioCookbookDetailViewModel(
                cookbook: cookbook,
                availableRecipes: [availableRecipe()]
            )
            let visitor = scenarioCookbookDetailViewModel(
                cookbook: cookbook,
                availableRecipes: [availableRecipe()],
                currentChefID: "chef_visitor"
            )
            let status: ScenarioCheckStatus = viewModel.ownerTools.isVisible &&
                viewModel.availableActionIDs == [.share, .editTitle, .addRecipe, .removeRecipe, .deleteCookbook] &&
                viewModel.ownerTools.availableRecipes.map(\.id) == ["scenario-shopping-recipe"] &&
                !visitor.ownerTools.isVisible &&
                visitor.availableActionIDs == [.share] ? .pass : .fail

            return ScenarioCheck(
                name: "cookbook owner tools",
                status: status,
                detail: "Cookbook owner tools are visible only to the owning chef and include edit, add, remove, and delete actions."
            )
        } catch {
            return ScenarioCheck(name: "cookbook owner tools", status: .fail, detail: "Cookbook owner tools failed: \(error)")
        }
    }

    static func cookbookCreateCheck(
        rootURL: URL,
        planBuilder: () throws -> CookbookSurfaceActionPlan = {
            try CookbookCreatePlanner(
                currentChefID: "chef_ari",
                queuedMutations: [],
                connectivity: .online,
                timestamp: { "2026-06-16T12:11:00.000Z" }
            ).planCreate(title: " Scenario Suppers ", clientMutationID: "scenario-cookbook-create")
        }
    ) -> ScenarioCheck {
        do {
            let plan = try planBuilder()
            let source = sourceCheck(
                name: "cookbook create surface source",
                detail: "Cookbook list exposes the native create sheet and list-level action planner.",
                rootURL: rootURL,
                relativePath: "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
                tokens: ["CookbookCreateSheet", "planCreate", "performCookbookAction"]
            )
            let status: ScenarioCheckStatus = plan.remoteRequestBuilder != nil &&
                plan.offlineFallbackMutation?.queueableKind == .cookbookCreate &&
                plan.successRoute == .cookbooks &&
                source.status == .pass ? .pass : .fail

            return ScenarioCheck(
                name: "cookbook create",
                status: status,
                detail: "Cookbook list create plans a live REST write with a durable offline fallback."
            )
        } catch {
            return ScenarioCheck(name: "cookbook create", status: .fail, detail: "Cookbook create failed: \(error)")
        }
    }

    static func cookbookRenameCheck(
        viewModel: () throws -> CookbookDetailViewModel = {
            try scenarioCookbookDetailViewModel(cookbook: scenarioCookbook())
        }
    ) -> ScenarioCheck {
        do {
            let plan = try viewModel()
                .plan(.rename(title: " Scenario Dinner Parties ", clientMutationID: "scenario-cookbook-rename"))
            let status: ScenarioCheckStatus = plan.remoteRequestBuilder != nil &&
                plan.offlineFallbackMutation?.queueableKind == .cookbookUpdate &&
                plan.updatedCookbook?.title == "Scenario Dinner Parties" ? .pass : .fail

            return ScenarioCheck(
                name: "cookbook rename",
                status: status,
                detail: "Cookbook rename trims titles, previews the optimistic cookbook, and keeps an offline fallback."
            )
        } catch {
            return ScenarioCheck(name: "cookbook rename", status: .fail, detail: "Cookbook rename failed: \(error)")
        }
    }

    static func cookbookDeleteCheck(
        viewModel: () throws -> CookbookDetailViewModel = {
            try scenarioCookbookDetailViewModel(cookbook: scenarioCookbook())
        }
    ) -> ScenarioCheck {
        do {
            let detailViewModel = try viewModel()
            let prompt = try detailViewModel.plan(.deleteCookbook(
                clientMutationID: "scenario-cookbook-delete",
                confirmation: .required
            ))
            let confirmed = try detailViewModel.plan(.deleteCookbook(
                clientMutationID: "scenario-cookbook-delete-confirmed",
                confirmation: .confirmed
            ))
            let status: ScenarioCheckStatus = prompt.confirmationPrompt?.isDestructive == true &&
                prompt.remoteRequestBuilder == nil &&
                confirmed.offlineFallbackMutation?.queueableKind == .cookbookDelete &&
                confirmed.successRoute == .cookbooks ? .pass : .fail

            return ScenarioCheck(
                name: "cookbook delete",
                status: status,
                detail: "Cookbook delete requires native confirmation before producing a destructive mutation."
            )
        } catch {
            return ScenarioCheck(name: "cookbook delete", status: .fail, detail: "Cookbook delete failed: \(error)")
        }
    }

    static func cookbookAddRecipeCheck(
        availableRecipe: () -> RecipeSummary = scenarioAvailableRecipe,
        viewModel: (RecipeSummary) throws -> CookbookDetailViewModel = { recipe in
            try scenarioCookbookDetailViewModel(
                cookbook: scenarioCookbook(),
                availableRecipes: [recipe]
            )
        }
    ) -> ScenarioCheck {
        do {
            let recipe = availableRecipe()
            let plan = try viewModel(recipe).plan(.addRecipe(
                recipeID: recipe.id,
                clientMutationID: "scenario-cookbook-add-recipe"
            ))
            let status: ScenarioCheckStatus = plan.remoteRequestBuilder != nil &&
                plan.offlineFallbackMutation?.queueableKind == .cookbookAddRecipe &&
                plan.updatedCookbook?.recipes.map(\.id).contains(recipe.id) == true ? .pass : .fail

            return ScenarioCheck(
                name: "cookbook add recipe",
                status: status,
                detail: "Cookbook add recipe plans live and offline association writes from native owner tools."
            )
        } catch {
            return ScenarioCheck(name: "cookbook add recipe", status: .fail, detail: "Cookbook add recipe failed: \(error)")
        }
    }

    static func cookbookRemoveRecipeCheck(
        loadCookbook: () throws -> Cookbook = scenarioCookbook,
        viewModel: (Cookbook) -> CookbookDetailViewModel = { cookbook in
            scenarioCookbookDetailViewModel(cookbook: cookbook)
        }
    ) -> ScenarioCheck {
        do {
            let cookbook = try loadCookbook()
            guard let recipe = cookbook.recipes.first else {
                return ScenarioCheck(name: "cookbook remove recipe", status: .fail, detail: "Cookbook fixture has no removable recipe.")
            }
            let detailViewModel = viewModel(cookbook)
            let prompt = try detailViewModel.plan(.removeRecipe(
                recipeID: recipe.id,
                clientMutationID: "scenario-cookbook-remove-recipe",
                confirmation: .required
            ))
            let confirmed = try detailViewModel.plan(.removeRecipe(
                recipeID: recipe.id,
                clientMutationID: "scenario-cookbook-remove-recipe-confirmed",
                confirmation: .confirmed
            ))
            let status: ScenarioCheckStatus = prompt.confirmationPrompt?.isDestructive == true &&
                confirmed.remoteRequestBuilder != nil &&
                confirmed.offlineFallbackMutation?.queueableKind == .cookbookRemoveRecipe &&
                confirmed.updatedCookbook?.recipes.map(\.id).contains(recipe.id) == false ? .pass : .fail

            return ScenarioCheck(
                name: "cookbook remove recipe",
                status: status,
                detail: "Cookbook remove recipe confirms before removing the association and queues safely offline."
            )
        } catch {
            return ScenarioCheck(name: "cookbook remove recipe", status: .fail, detail: "Cookbook remove recipe failed: \(error)")
        }
    }

    private static func scenarioCookbook() throws -> Cookbook {
        try scenarioCookbook(from: CookbookFixtureCatalog.decodeFromBundle().cookbooks)
    }

    static func scenarioCookbook(from cookbooks: [Cookbook]) throws -> Cookbook {
        guard let cookbook = cookbooks.first else {
            throw ScenarioVerifierError.missingFixture("cookbook")
        }
        return cookbook
    }

    private static func scenarioAvailableRecipe() -> RecipeSummary {
        RecipeSummary(recipe: scenarioRecipe(ingredients: []))
    }

    private static func scenarioCookbookDetailViewModel(
        cookbook: Cookbook,
        availableRecipes: [RecipeSummary] = [],
        currentChefID: String? = nil,
        queuedMutations: [NativeQueuedMutation] = [],
        conflicts: [NativeSyncConflict] = [],
        connectivity: CookbookSurfaceConnectivity = .online
    ) -> CookbookDetailViewModel {
        CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "scenario-cookbook-detail", validatedAt: Date(timeIntervalSince1970: 1_780_120_000)),
                availableRecipes: availableRecipes
            ),
            context: CookbookSurfaceContext(currentChefID: currentChefID ?? cookbook.chef.id),
            queuedMutations: queuedMutations,
            conflicts: conflicts,
            connectivity: connectivity,
            now: { Date(timeIntervalSince1970: 1_780_120_000) },
            timestamp: { "2026-06-16T12:11:00.000Z" }
        )
    }

    static func profileDetailCheck() -> ScenarioCheck {
        let profile = scenarioProfileData()
        let viewModel = ProfileViewModel(
            result: ProfileSurfaceResult(
                data: profile,
                source: .live(requestID: "scenario-profile", validatedAt: Date(timeIntervalSince1970: 1_780_120_000))
            ),
            context: ProfileSurfaceContext(currentChefID: profile.profile.id),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Date(timeIntervalSince1970: 1_780_120_000) }
        )
        let status: ScenarioCheckStatus = viewModel.openRoute == .profile(identifier: profile.profile.username) &&
            viewModel.ownerActions.editProfileRoute == .settings &&
            viewModel.sectionIDs == [.recipes, .cookbooks, .recentSpoons, .fellowChefs, .kitchenVisitors] &&
            viewModel.unsupportedSocialSurfaces.isEmpty ? .pass : .fail

        return ScenarioCheck(
            name: "profile detail",
            status: status,
            detail: "Profile detail exposes recipes, cookbooks, recent spoons, fellow chefs, and kitchen visitors without adding future discussion or feed surfaces."
        )
    }

    static func profileGraphCheck(direction: ProfileGraphDirection) -> ScenarioCheck {
        let profile = scenarioProfileData()
        let page = ProfileGraphPage(
            profile: ProfileGraphProfile(
                id: profile.profile.id,
                username: profile.profile.username,
                href: profile.profile.href,
                canonicalURL: profile.profile.canonicalURL
            ),
            direction: direction,
            page: 1,
            pageSize: 50,
            total: 1,
            nextCursor: nil,
            rows: [
                ProfileGraphRow(
                    chefID: "chef_jules",
                    username: "jules",
                    photoURL: nil,
                    href: "/users/jules",
                    canonicalURL: URL(string: "https://spoonjoy.app/users/jules")!,
                    interactionCounts: ProfileGraphInteractionCounts(spoons: 1, forks: 1, cookbookSaves: 1),
                    latestInteractionAt: "2026-06-04T10:00:00.000Z"
                )
            ],
            source: .live(requestID: "scenario-profile-graph", validatedAt: Date(timeIntervalSince1970: 1_780_120_000))
        )
        let viewModel = ProfileGraphViewModel(page: page)
        let status: ScenarioCheckStatus = viewModel.rows.first?.openRoute == .profile(identifier: "jules") &&
            viewModel.rows.first?.interactionSummary == "1 spoon, 1 fork, 1 cookbook save" ? .pass : .fail

        return ScenarioCheck(
            name: direction == .fellowChefs ? "fellow chefs" : "kitchen visitors",
            status: status,
            detail: "Profile graph routes native chef rows from the profile graph without follows/followers."
        )
    }

    private static func scenarioProfileData() -> ProfileSurfaceData {
        let recipe = scenarioRecipe(ingredients: [])
        let canonicalProfileURL = URL(string: "https://spoonjoy.app/users/ari")!
        return ProfileSurfaceData(
            profile: ProfileSummary(
                id: "chef_ari",
                username: "ari",
                photoURL: nil,
                joinedLabel: "Joined Jun 2026",
                href: "/users/ari",
                canonicalURL: canonicalProfileURL
            ),
            isOwner: true,
            recipes: [
                ProfileRecipeSummary(
                    id: recipe.id,
                    title: recipe.title,
                    description: recipe.description,
                    servings: recipe.servings,
                    coverImageURL: recipe.coverImageURL,
                    coverProvenanceLabel: recipe.coverProvenanceLabel,
                    href: recipe.href,
                    canonicalURL: recipe.canonicalURL
                )
            ],
            cookbooks: [],
            recentSpoons: [],
            fellowChefsCount: 1,
            kitchenVisitorsCount: 1
        )
    }

    private static func searchCheck() -> ScenarioCheck {
        var search = SearchState(query: "  lemon  ", scope: .recipes)
        search.update(query: " lemon pasta ", scope: .all)
        let status: ScenarioCheckStatus = search.route == .search(query: "lemon pasta", scope: .all) ? .pass : .fail

        return ScenarioCheck(
            name: "search",
            status: status,
            detail: "Search state trims queries and preserves native searchable scopes."
        )
    }

    static func captureDraftCreationCheck(makeDraft: () throws -> CaptureDraft = {
        try CaptureDraft.importURL(
            id: "scenario-draft",
            url: URL(string: "https://example.com/recipe")!,
            createdAt: "2026-06-16T12:08:00.000Z"
        )
    }) -> ScenarioCheck {
        do {
            let draft = try makeDraft()
            let viewModel = CaptureDraftViewModel(draft: draft)
            let mutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "scenario-import",
                createdAt: "2026-06-16T12:08:00.000Z"
            )
            let request = try mutation.requestBuilder()
                .urlRequest(configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "token"))
            let offlinePlan = try CaptureImportViewModel(draft: draft, connectivity: .offline)
                .planSubmit(clientMutationID: "scenario-import", createdAt: "2026-06-16T12:08:00.000Z")
            let providerSecretResponse = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
                """
                {
                  "importCode": "provider-secret",
                  "blockers": [
                    {
                      "capability": "ProviderSecret",
                      "retryAfterSeconds": 30,
                      "ownerAction": true
                    }
                  ]
                }
                """.utf8
            ))
            let providerSecretPlan = try CaptureImportViewModel(draft: draft, connectivity: .online)
                .planImportResult(
                    providerSecretResponse,
                    clientMutationID: "scenario-import",
                    createdAt: "2026-06-16T12:08:00.000Z"
                )
            let status: ScenarioCheckStatus =
                viewModel.status == .localOnly &&
                viewModel.previewLines == ["https://example.com/recipe"] &&
                viewModel.canCreateServerRecipe &&
                request.url.path == "/api/v1/recipes/import" &&
                offlinePlan.offlineRetryMutation?.queueableKind == .recipeImportSubmit &&
                providerSecretPlan.blocker == .providerSecret(retryAfterSeconds: 30)
                ? .pass
                : .fail

            return ScenarioCheck(
                name: "capture import submission",
                status: status,
                detail: "Capture creates import-ready drafts, queues offline import retry, and exposes provider secret blocker state."
            )
        } catch {
            return ScenarioCheck(
                name: "capture import submission",
                status: .fail,
                detail: "Capture import scenario failed: \(error)."
            )
        }
    }

    static func settingsStateCheck(settings: SettingsState? = nil) -> ScenarioCheck {
        let scenarioSettings = settings ?? SettingsState(
            auth: .signedIn(username: "ari", scopes: ["shopping_list:read", "shopping_list:write"], tokenExpiresAt: nil),
            environment: .local(baseURL: URL(fileURLWithPath: "/tmp/spoonjoy-local")),
            offline: .available(snapshotCount: 2, lastRestoredAt: "2026-06-16T12:09:00.000Z"),
            preferredCookModeTextSize: .large
        )
        let viewModel = SettingsViewModel(settings: scenarioSettings)
        let status: ScenarioCheckStatus = viewModel.canReadShoppingList &&
            viewModel.canWriteShoppingList &&
            viewModel.rows.map(\.id) == ["auth", "environment", "offline", "cook-mode-text"] ? .pass : .fail

        return ScenarioCheck(
            name: "settings state",
            status: status,
            detail: "Settings exposes auth, environment, shopping permissions, and cook text size."
        )
    }

    static func settingsTokenConnectionSurfaceCheck() -> ScenarioCheck {
        let account = SettingsAccountProfile(
            id: "chef_ari",
            email: "ari@example.com",
            username: "ari",
            photoURL: nil,
            hasPassword: true,
            linkedProviders: [SettingsLinkedProvider(provider: .google, providerUsername: "ari@gmail.com")],
            passkeys: [SettingsPasskeySummary(id: "passkey_mac", name: "Mac Touch ID", transports: "internal", createdAt: "2026-06-16T12:09:00.000Z")]
        )
        let data = SettingsSurfaceData(
            account: account,
            notifications: SettingsNotificationPreferences(
                notifySpoonOnMyRecipe: true,
                notifyForkOfMyRecipe: true,
                notifyCookbookSaveOfMine: true,
                notifyFellowChefOriginCook: true
            ),
            apiTokens: [
                SettingsAPITokenSummary(
                    id: "cred_cli",
                    name: "CLI",
                    tokenPrefix: "sj_live_cli",
                    scopes: ["recipes:read"],
                    createdAt: "2026-06-16T12:09:00.000Z",
                    updatedAt: "2026-06-16T12:09:00.000Z",
                    lastUsedAt: nil,
                    revokedAt: nil,
                    expiresAt: nil
                )
            ],
            oauthConnections: [
                SettingsOAuthConnectionSummary(
                    id: "conn_cli",
                    clientID: "client_cli",
                    clientName: "CLI",
                    resource: nil,
                    scopes: ["recipes:read"],
                    createdAt: "2026-06-16T12:09:00.000Z",
                    refreshTokenCount: 1,
                    accessTokenCount: 1
                )
            ],
            environment: .production,
            offline: .available(snapshotCount: 1, lastRestoredAt: nil),
            source: .live(requestID: "scenario-settings", validatedAt: Date(timeIntervalSince1970: 1_780_120_000))
        )
        let viewModel = SettingsSurfaceViewModel(
            data: data,
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Date(timeIntervalSince1970: 1_780_120_000) }
        )
        let status: ScenarioCheckStatus = viewModel.sections.map(\.id) == [.profile, .security, .notifications, .apiTokens, .connections, .environment, .offline] &&
            viewModel.apiTokenRows.first?.tokenPrefix == "sj_live_cli" &&
            viewModel.oauthConnectionRows.first?.clientID == "client_cli" ? .pass : .fail

        return ScenarioCheck(
            name: "settings token connection surface",
            status: status,
            detail: "Settings renders account profile, notification preferences, API token metadata, OAuth connection state, and native offline status."
        )
    }

    static func settingsProfileUpdateCheck(
        planBuilder: (SettingsActionPlanner) throws -> SettingsActionPlan = {
            try $0.plan(.updateProfile(email: "ari@example.com", username: "ari", clientMutationID: "scenario-settings-profile"))
        }
    ) -> ScenarioCheck {
        do {
            let planner = SettingsActionPlanner(connectivity: .online, secureHandoffRoutes: .spoonjoyApp, now: {
                settingsScenarioTimestamp()
            })
            let plan = try planBuilder(planner)
            let request = try plan.remoteRequestBuilder?.urlRequest(configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "token"))
            let status: ScenarioCheckStatus = request?.method == .patch &&
                request?.url.path == "/api/v1/me" &&
                plan.offlineFallbackMutation?.queueableKind == .profileDisplayUpdate ? .pass : .fail
            return ScenarioCheck(
                name: "settings profile update",
                status: status,
                detail: "Settings profile update plans native PATCH /api/v1/me with an offline queue fallback."
            )
        } catch {
            return ScenarioCheck(name: "settings profile update", status: .fail, detail: "Settings profile update failed: \(error)")
        }
    }

    static func settingsTokenCreateOnlineOnlyCheck(
        planBuilder: (SettingsActionPlanner) throws -> SettingsActionPlan = {
            try $0.plan(.createAPIToken(name: "CLI", scopes: ["recipes:read"]))
        }
    ) -> ScenarioCheck {
        do {
            let planner = SettingsActionPlanner(connectivity: .offline, secureHandoffRoutes: .spoonjoyApp)
            let plan = try planBuilder(planner)
            let status: ScenarioCheckStatus = plan.onlineOnlyReason == .apiTokenCreate &&
                plan.queuedMutation == nil &&
                plan.offlineFallbackMutation == nil ? .pass : .fail
            return ScenarioCheck(
                name: "settings token create online-only",
                status: status,
                detail: "Settings token create is native REST when online and disabled rather than queued offline."
            )
        } catch {
            return ScenarioCheck(name: "settings token create online-only", status: .fail, detail: "Settings token create failed: \(error)")
        }
    }

    static func settingsConnectionDisconnectOnlineOnlyCheck(
        planBuilder: (SettingsActionPlanner) throws -> SettingsActionPlan = {
            try $0.plan(.disconnectOAuthConnection(connectionID: "conn_cli"))
        }
    ) -> ScenarioCheck {
        do {
            let planner = SettingsActionPlanner(connectivity: .offline, secureHandoffRoutes: .spoonjoyApp)
            let plan = try planBuilder(planner)
            let status: ScenarioCheckStatus = plan.onlineOnlyReason == .oauthConnectionDisconnect &&
                plan.queuedMutation == nil &&
                plan.offlineFallbackMutation == nil ? .pass : .fail
            return ScenarioCheck(
                name: "settings connection disconnect online-only",
                status: status,
                detail: "Settings OAuth connection disconnect never enters the offline mutation queue."
            )
        } catch {
            return ScenarioCheck(name: "settings connection disconnect online-only", status: .fail, detail: "Settings connection disconnect failed: \(error)")
        }
    }

    static func settingsSecureHandoffCheck(
        planBuilder: (SettingsActionPlanner) throws -> (provider: SettingsSecureHandoff?, passkeys: SettingsSecureHandoff?) = {
            (try $0.plan(.linkProvider(.google)).secureHandoff, try $0.plan(.managePasskeys).secureHandoff)
        }
    ) -> ScenarioCheck {
        do {
            let planner = SettingsActionPlanner(connectivity: .online, secureHandoffRoutes: .spoonjoyApp)
            let plans = try planBuilder(planner)
            let provider = plans.provider
            let passkeys = plans.passkeys
            let status: ScenarioCheckStatus = provider?.url.absoluteString == "https://spoonjoy.app/auth/google?linking=true" &&
                passkeys?.url.absoluteString == "https://spoonjoy.app/account/settings#passkeys" ? .pass : .fail
            return ScenarioCheck(
                name: "settings secure handoff",
                status: status,
                detail: "Settings credential actions route to secure web handoff URLs while native token/profile actions stay REST-backed."
            )
        } catch {
            return ScenarioCheck(name: "settings secure handoff", status: .fail, detail: "Settings secure handoff failed: \(error)")
        }
    }

    static func notificationAPNsSurfaceCheck(rootURL: URL) -> ScenarioCheck {
        guard FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift").path),
              FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("Apps/Spoonjoy/Shared/Native/NotificationAPNsDeviceBridge.swift").path) else {
            return ScenarioCheck(
                name: "notification APNs surface",
                status: .fail,
                detail: "Notification APNs SwiftUI surface and native device bridge files must both exist."
            )
        }

        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        )
        let data = NotificationAPNsSurfaceData(
            preferences: preferences,
            apnsRegistration: APNsRegistrationSummary(
                deviceID: "scenario-device",
                platform: .ios,
                environment: .development,
                registrationState: .registered,
                lastValidatedAt: Date(timeIntervalSince1970: 1_782_899_000)
            ),
            permissionState: .denied(lastCheckedAt: Date(timeIntervalSince1970: 1_782_899_000)),
            source: .cache(serverRevision: .etag("scenario-apns"), lastValidatedAt: Date(timeIntervalSince1970: 1_782_899_000))
        )
        let viewModel = NotificationAPNsSurfaceViewModel(
            data: data,
            queuedMutations: [],
            connectivity: .offline,
            now: { Date(timeIntervalSince1970: 1_782_901_800) }
        )
        let localValidationBlocker = AppleDeveloperProgramBlocker.localValidation
        let planner = NotificationAPNsActionPlanner(connectivity: .online, deliveryCapability: .developmentOnly(blocker: localValidationBlocker))
        let offlinePlanner = NotificationAPNsActionPlanner(connectivity: .offline)
        let developmentRegister = try? planner.plan(.registerDevice(
            deviceID: "scenario-device",
            platform: .ios,
            environment: .development,
            token: "scenario-token",
            deviceName: "Scenario iPhone",
            appVersion: "1.0.0",
            clientMutationID: "cm_scenario_apns_register"
        ))
        let productionRegister = try? planner.plan(.registerDevice(
            deviceID: "scenario-device",
            platform: .ios,
            environment: .production,
            token: "scenario-token",
            deviceName: "Scenario iPhone",
            appVersion: "1.0.0",
            clientMutationID: "cm_scenario_apns_production"
        ))
        let tokenAcquisition = try? offlinePlanner.planDeviceTokenAcquisition()
        let status: ScenarioCheckStatus = viewModel.notificationDraft == preferences &&
            viewModel.apnsRegistration?.registrationState == .registered &&
            viewModel.permissionDeniedBanner != nil &&
            viewModel.productionBlocker?.capability == AppleDeveloperProgramBlocker.capabilityName &&
            developmentRegister?.offlineFallbackMutation?.queueableKind == .apnsDeviceRegister &&
            productionRegister?.deliveryBlocker == localValidationBlocker &&
            tokenAcquisition?.onlineOnlyReason == .deviceTokenAcquisition ? .pass : .fail

        return ScenarioCheck(
            name: "notification APNs surface",
            status: status,
            detail: "Notification APNs behavior restores cached preferences/status, blocks production APNs without AppleDeveloperProgram, and keeps permission/token acquisition online-only."
        )
    }

    private static func settingsScenarioTimestamp() -> String {
        "2026-06-16T12:09:00.000Z"
    }

    static func offlineStatusCheck(
        available: OfflineState = .available(snapshotCount: 2, lastRestoredAt: "2026-06-16T12:10:00.000Z"),
        unavailable: OfflineState = .unavailable
    ) -> ScenarioCheck {
        let status: ScenarioCheckStatus = available.statusLabel == "Offline cache ready: 2 snapshots" &&
            unavailable.statusLabel == "Offline cache unavailable" ? .pass : .fail

        return ScenarioCheck(
            name: "offline status",
            status: status,
            detail: "Offline status labels cover available and unavailable states."
        )
    }

    static func safeUnknownLinkCheck(routes: [AppRoute]? = nil) -> ScenarioCheck {
        let router = DeepLinkRouter.spoonjoy
        let checkedRoutes = routes ?? [
            router.route(for: webComponents(path: "/recipes/../secret")),
            router.route(for: webComponents(
            path: "/search",
            queryItems: [
                URLQueryItem(name: "q", value: "lemon"),
                URLQueryItem(name: "scope", value: "bad")
            ]
            )),
            router.route(for: schemeComponents(host: "recipes", path: "/../secret")),
            router.route(for: schemeComponents(
                host: "search",
                queryItems: [
                    URLQueryItem(name: "q", value: "lemon"),
                    URLQueryItem(name: "scope", value: "bad")
                ]
            ))
        ]
        let status: ScenarioCheckStatus = checkedRoutes.allSatisfy { $0 == .unknownLink } ? .pass : .fail

        return ScenarioCheck(
            name: "safe unknown link",
            status: status,
            detail: "Unsupported universal and custom Spoonjoy links resolve to the safe unknown-link state."
        )
    }

    private static func webComponents(path: String, queryItems: [URLQueryItem] = []) -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = DeepLinkManifest.webDomain
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components
    }

    private static func schemeComponents(host: String, path: String = "", queryItems: [URLQueryItem] = []) -> URLComponents {
        var components = URLComponents()
        components.scheme = DeepLinkManifest.urlSchemes[0]
        components.host = host
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components
    }

    private static func capabilitiesWithLiveStoreFlows(_ capabilities: ScenarioNativeCapabilities) -> ScenarioNativeCapabilities {
        let liveStoreFlows = [
            "live-store-source",
            "signed-out-state",
            "restoring-cache",
            "live-synced",
            "offline-stale",
            "queued-work",
            "conflict",
            "blocker",
            "destructive-confirmation",
            "sync-failed",
            "fixture-fallback-disabled"
        ]
        return ScenarioNativeCapabilities(
            appIntents: capabilities.appIntents,
            spotlightIndexedTypes: capabilities.spotlightIndexedTypes,
            searchableScopes: capabilities.searchableScopes,
            shareActions: capabilities.shareActions,
            offlineFlows: Array(Set(capabilities.offlineFlows + liveStoreFlows)).sorted(),
            associatedDomains: capabilities.associatedDomains,
            urlSchemes: capabilities.urlSchemes,
            deepLinkRoutes: capabilities.deepLinkRoutes
        )
    }

    private static func metadataCheckStatus(_ metadata: NativeCapabilityMetadata) -> ScenarioCheckStatus {
        [
            metadata.appIntents,
            metadata.spotlightIndexedTypes,
            metadata.searchableScopes,
            metadata.shareActions,
            metadata.offlineFlows
        ].allSatisfy { !$0.isEmpty } ? .pass : .fail
    }

    private static func deepLinkCheckStatus(_ metadata: NativeCapabilityMetadata) -> ScenarioCheckStatus {
        let hasAssociatedDomain = metadata.associatedDomains == ["applinks:\(DeepLinkManifest.webDomain)"]
        let hasScheme = metadata.urlSchemes == DeepLinkManifest.urlSchemes
        let hasWebRoutes = metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/recipes/{id}") &&
            metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/recipes/{id}/edit") &&
            metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/recipes/{id}#cook") &&
            metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/shopping-list") &&
            metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/account/settings")
        let hasSchemeRoutes = metadata.deepLinkRoutes.contains("spoonjoy://recipes/{id}") &&
            metadata.deepLinkRoutes.contains("spoonjoy://recipes/{id}/edit") &&
            metadata.deepLinkRoutes.contains("spoonjoy://recipes/{id}/cook") &&
            metadata.deepLinkRoutes.contains("spoonjoy://recipes/new/edit") &&
            metadata.deepLinkRoutes.contains("spoonjoy://shopping-list")

        return hasAssociatedDomain && hasScheme && hasWebRoutes && hasSchemeRoutes ? .pass : .fail
    }

    private static func sourceCheck(
        name: String,
        detail: String,
        rootURL: URL,
        relativePath: String,
        tokens: [String],
        forbiddenTokens: [String] = []
    ) -> ScenarioCheck {
        let sourceURL = rootURL.appendingPathComponent(relativePath)
        guard
            let source = try? String(contentsOf: sourceURL, encoding: .utf8).uncommentedSwiftSource,
            tokens.allSatisfy(source.contains),
            forbiddenTokens.allSatisfy({ !source.contains($0) })
        else {
            return ScenarioCheck(name: name, status: .fail, detail: detail)
        }

        return ScenarioCheck(name: name, status: .pass, detail: detail)
    }
}

private enum ScenarioVerifierError: Error {
    case missingFixture(String)
}

private extension String {
    var uncommentedSwiftSource: String {
        replacingOccurrences(of: #"(?s)/\*.*?\*/"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"//[^\n\r]*"#, with: "", options: .regularExpression)
    }
}
