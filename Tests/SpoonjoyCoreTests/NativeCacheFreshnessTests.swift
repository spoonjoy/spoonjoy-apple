import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native cache schema and freshness")
struct NativeCacheFreshnessTests {
    @Test("expanded native cache behavior contract is executable")
    func expandedNativeCacheBehaviorContractIsExecutable() throws {
        let result = try runSwiftContractPackage(
            name: "NativeCacheBehaviorProbe",
            testSource: nativeCacheBehaviorContractSource
        )

        #expect(result.status == 0, Comment(rawValue: result.truncatedOutput))
    }

    @Test("durable schema version 2 covers every Offline Product Contract domain with record metadata")
    func durableSchemaVersionTwoCoversOfflineProductContractDomainsWithRecordMetadata() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/NativeDurableCache.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/NativeDurableCache.swift",
            contains: [
                "NativeDurableCacheSnapshot",
                "currentSchemaVersion = 2",
                "NativeCacheRecord",
                "NativeCacheRecordMetadata",
                "NativeCacheDomain",
                "NativeCacheServerRevision",
                "accountID",
                "environment",
                "schemaVersion",
                "fetchedAt",
                "lastValidatedAt",
                "sourceEndpoint",
                "serverRevision",
                "record(for:",
                "validatedForRestore",
                "unsupportedSchemaVersion",
                "recipeCatalog",
                "recipeDetail",
                "cookbookList",
                "cookbookDetail",
                "shoppingList",
                "cookProgress",
                "captureDraft",
                "profile",
                "notificationPreferences",
                "tokenMetadata",
                "connectionStatus",
                "apnsStatus",
                "/api/v1/recipes",
                "/api/v1/cookbooks",
                "/api/v1/shopping-list",
                "/api/v1/me/notification-preferences",
                "/api/v1/tokens",
                "/api/v1/me/connections",
                "/api/v1/me/apns-devices",
                "local://cook-progress",
                "local://capture-drafts"
            ],
            forbids: [
                "schemaVersion == 1",
                "OfflineSnapshot("
            ]
        )
    }

    @Test("freshness policy uses exact Offline Product Contract thresholds without wall clock flake")
    func freshnessPolicyUsesExactOfflineProductContractThresholds() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/NativeCacheFreshnessPolicy.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/NativeCacheFreshnessPolicy.swift",
            contains: [
                "NativeCacheFreshnessPolicy",
                "offlineProductContract",
                "accountBootstrap",
                "settings",
                "shoppingList",
                ".minutes(15)",
                "recipeDetail",
                "cookbookDetail",
                "spoonList",
                "profile",
                "cookModeBackingData",
                ".hours(6)",
                "recipeCatalog",
                "searchResults",
                ".hours(24)",
                "cookProgress",
                "captureDraft",
                "stagedMedia",
                "locallyAuthoritative",
                "secondsOverThreshold",
                "launch",
                "foreground",
                "accountChanged",
                "environmentChanged",
                "networkRecovered",
                "visibleSurfaceOpened"
            ],
            forbids: [
                "Date()",
                "ProcessInfo.processInfo.systemUptime"
            ]
        )
    }

    @Test("indicator transitions preserve queued failed conflict blocker destructive and dismissed states")
    func indicatorTransitionsPreserveSevereStatesAndDismissOnlyInformationalStates() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/OfflineFreshnessIndicator.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/OfflineFreshnessIndicator.swift",
            contains: [
                "OfflineIndicatorState",
                "OfflineIndicatorReducer",
                "OfflineIndicatorDisplay",
                "synced",
                "offline",
                "stale",
                "dismissed",
                "informationalOnly",
                "queuedWork",
                "syncFailure",
                "conflict",
                "blocker",
                "providerSecret",
                "destructiveConfirmation",
                "isVisible",
                "dismissCurrentIndicator",
                "severeStateResolved",
                "oldestClientMutationID",
                "retryAfter",
                "mutationID"
            ],
            forbids: [
                "case queuedWork = false",
                "case syncFailure = false",
                "case conflict = false",
                "case blocker = false",
                "case destructiveConfirmation = false"
            ]
        )
    }

    @Test("dismissal persistence is scoped by account environment and freshness change")
    func dismissalPersistenceIsScopedByAccountEnvironmentAndFreshnessChange() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/NativeIndicatorDismissalStore.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/NativeIndicatorDismissalStore.swift",
            contains: [
                "NativeIndicatorDismissalStore",
                "NativeIndicatorDismissal",
                "NativeIndicatorDismissalError",
                "accountID",
                "environment",
                "hiddenDisplay",
                "dismissedAt",
                "cacheFingerprint",
                "isHidden",
                "informationalOnly",
                "queuedWork",
                "syncFailure",
                "conflict",
                "blocker",
                "destructiveConfirmation"
            ],
            forbids: [
                "UserDefaults.standard",
                "hiddenDisplay: .queuedWork",
                "hiddenDisplay: .syncFailure",
                "hiddenDisplay: .conflict",
                "hiddenDisplay: .blocker",
                "hiddenDisplay: .destructiveConfirmation"
            ]
        )
    }

    @Test("intelligent prefetch policy includes signed-in bootstrap recent surfaces and excludes online-only credential work")
    func intelligentPrefetchPolicyIncludesBootstrapAndExcludesOnlineOnlyCredentialWork() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/NativeCachePrefetchPolicy.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/NativeCachePrefetchPolicy.swift",
            contains: [
                "NativeCachePrefetchPolicy",
                "offlineProductContract",
                "signedInLaunch",
                "currentAccount",
                "kitchen",
                "notificationPreferences",
                "tokenMetadata",
                "connectionStatus",
                "apnsStatus",
                "cookbookList",
                "shoppingList",
                "recipeDetail",
                "cookModeBackingData",
                "profile",
                "revalidateOn",
                "launch",
                "foreground",
                "networkRecovered",
                "visibleSurfaceOpened",
                "onlineOnlyActions",
                "tokenCreate",
                "tokenRevoke",
                "oauthDisconnect",
                "logout",
                "apnsPermissionPrompt",
                "apnsDeviceTokenAcquisition",
                "containsOnlineOnlyActions"
            ],
            forbids: [
                "queueOnlineOnlyActions = true",
                "MutationQueue"
            ]
        )
    }

    @Test("media staging metadata is privacy safe and enforces exact size and count thresholds")
    func mediaStagingMetadataIsPrivacySafeAndEnforcesExactThresholds() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/NativeMediaStagingPolicy.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/NativeMediaStagingPolicy.swift",
            contains: [
                "NativeMediaStagingPolicy",
                "NativeMediaStagingMetadata",
                "maxIndividualUserSelectedBytes",
                "25 * 1_024 * 1_024",
                "maxGeneratedPreviewBytesPerAccount",
                "128 * 1_024 * 1_024",
                "maxUnsyncedUserSelectedBytesPerAccount",
                "512 * 1_024 * 1_024",
                "maxUnsyncedUserSelectedFilesPerAccount",
                "100",
                "allowsSilentEvictionOfUnsyncedUserMedia",
                "false",
                "privacySafeRelativePath",
                "durableMetadata",
                "originalFilename",
                "rawLocalFileURL",
                "individualFileTooLarge",
                "accountByteCapReached",
                "accountFileCapReached",
                "generatedPreviewCapReached",
                "silentEvictionAllowed: false"
            ],
            forbids: [
                "removeItem",
                "originalFilename: originalFilename",
                "rawLocalFileURL: fileURL"
            ]
        )
    }

    @Test("cache store rejects secret material and never serializes tokens provider secrets signed URLs or raw media paths")
    func cacheStoreRejectsSecretMaterialAndNeverSerializesSecrets() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/NativeDurableCacheStore.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/NativeDurableCacheStore.swift",
            contains: [
                "NativeDurableCacheStore",
                "NativeCacheSecurityError",
                "rejectSecretMaterial",
                "bearerToken",
                "refreshToken",
                "oneTimeTokenValue",
                "providerSecret",
                "passkey",
                "rawMediaPath",
                "signedURL",
                "JSONFileStore",
                "NativeDurableCacheSnapshot"
            ],
            forbids: [
                "sj_access",
                "ort_refresh",
                "provider-secret",
                "passkey-private-key",
                "https://signed.example",
                "/Users/arimendelow/Pictures/private.jpg"
            ]
        )
    }

    @Test("corrupt cache recovery quarantines bad JSON and restores deterministic fallback without overwriting")
    func corruptCacheRecoveryQuarantinesBadJSONAndRestoresFallbackWithoutOverwriting() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Cache/NativeDurableCacheStore.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Cache/NativeDurableCacheStore.swift",
            contains: [
                "loadOrRecover",
                "fallbackAfterCorruption",
                "corruptCacheQuarantined",
                "quarantineSuffix",
                "appendingPathExtension",
                "corrupt.",
                "NativeCacheRecovery",
                "NativeCacheClock",
                "fixed"
            ],
            forbids: [
                "try? store.save(fallback)",
                "write(to: fileURL"
            ]
        )
    }

    @Test("app indicator source exposes labels icons dismissal and non-dismissable severity")
    func appIndicatorSourceExposesLabelsIconsDismissalAndNonDismissableSeverity() throws {
        let content = try readRepoFile("Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift")

        expectContent(
            content,
            in: "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift",
            contains: [
                "OfflineStatusView",
                "OfflineIndicatorDisplay",
                "synced",
                "offline",
                "stale",
                "queuedWork",
                "syncFailure",
                "conflict",
                "blocker",
                "destructiveConfirmation",
                "dismissed",
                "Button",
                "xmark.circle",
                "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                "externaldrive.badge.checkmark",
                "wifi.slash",
                "clock.badge.exclamationmark",
                "tray.and.arrow.up.fill",
                "exclamationmark.triangle.fill",
                "lock.shield.fill",
                "trash.slash.fill",
                "accessibilityLabel"
            ],
            forbids: [
                "Button(\"Dismiss\")",
                "case queuedWork: EmptyView()",
                "case syncFailure: EmptyView()",
                "case conflict: EmptyView()",
                "case blocker: EmptyView()",
                "case destructiveConfirmation: EmptyView()"
            ]
        )
    }
}

private enum NativeCacheContractError: Error, CustomStringConvertible {
    case missingFile(String)

    var description: String {
        switch self {
        case .missingFile(let path):
            return "Missing required native cache contract file: \(path)"
        }
    }
}

private struct ProcessResult: Equatable {
    let status: Int32
    let output: String

    var truncatedOutput: String {
        let limit = 6_000
        guard output.count > limit else {
            return output
        }

        return String(output.suffix(limit))
    }
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRoot().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeCacheContractError.missingFile(relativePath)
    }

    return try String(contentsOf: url, encoding: .utf8)
}

private func runSwiftContractPackage(name: String, testSource: String) throws -> ProcessResult {
    try withTemporaryDirectory { directory in
        let testsDirectory = directory
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("\(name)Tests", isDirectory: true)
        try FileManager.default.createDirectory(at: testsDirectory, withIntermediateDirectories: true)
        try packageManifest(name: name).write(
            to: directory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try testSource.write(
            to: testsDirectory.appendingPathComponent("\(name)Tests.swift"),
            atomically: true,
            encoding: .utf8
        )

        return try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "swift",
                "test",
                "--package-path",
                directory.path,
                "--disable-xctest",
                "--parallel",
                "-Xswiftc",
                "-warnings-as-errors"
            ]
        )
    }
}

private func packageManifest(name: String) -> String {
    """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
        name: "\(name)",
        platforms: [
            .iOS(.v26),
            .macOS(.v26)
        ],
        dependencies: [
            .package(path: "\(repoRoot().path)")
        ],
        targets: [
            .testTarget(
                name: "\(name)Tests",
                dependencies: [
                    .product(name: "SpoonjoyCore", package: "spoonjoy-apple")
                ]
            )
        ]
    )
    """
}

private func runProcess(
    executable: String,
    arguments: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment
) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    let outputHandle = try FileHandle(forWritingTo: outputURL)
    defer {
        try? outputHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
    }
    process.standardOutput = outputHandle
    process.standardError = outputHandle
    try process.run()
    process.waitUntilExit()

    let output = String(data: try Data(contentsOf: outputURL), encoding: .utf8) ?? ""
    return ProcessResult(status: process.terminationStatus, output: output)
}

private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try body(directory)
}

private func repoRoot() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func expectContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String],
    forbids forbiddenTokens: [String]
) {
    for token in requiredTokens {
        let hasToken = content.contains(token)
        #expect(hasToken, "\(relativePath) missing required token \(token)")
    }

    for token in forbiddenTokens {
        let doesNotHaveForbiddenToken = !content.contains(token)
        #expect(doesNotHaveForbiddenToken, "\(relativePath) must not contain forbidden token \(token)")
    }
}

private let nativeCacheBehaviorContractSource = #"""
import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native cache behavior contract")
struct NativeCacheBehaviorContract {
    @Test("schema version 2 records metadata and migrates schema version 1 app state")
    func schemaVersionTwoRecordsMetadataAndMigratesSchemaVersionOneAppState() throws {
        let fetchedAt = try instant("2026-06-16T12:00:00.000Z")
        let lastValidatedAt = try instant("2026-06-16T12:05:00.000Z")
        let snapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "chef_ari",
            environment: .production,
            createdAt: fetchedAt,
            records: productContractRecords(fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
            dismissedIndicators: []
        )
        let restored = try snapshot.validatedForRestore()

        #expect(NativeDurableCacheSnapshot.currentSchemaVersion == 2)
        #expect(restored.schemaVersion == 2)
        #expect(restored.accountID == "chef_ari")
        #expect(restored.environment == .production)
        #expect(restored.records.map(\.metadata.domain) == expectedDomains)
        #expect(restored.record(for: .recipeDetail(id: "recipe_lemon_pantry_pasta"))?.metadata.serverRevision == .etag("\"recipe-detail-v7\""))
        #expect(restored.record(for: .shoppingList)?.metadata.serverRevision == .cursor("shopping-sync-cursor-v3"))
        for record in restored.records {
            #expect(record.metadata.accountID == "chef_ari")
            #expect(record.metadata.environment == .production)
            #expect(record.metadata.schemaVersion == 2)
            #expect(record.metadata.fetchedAt == fetchedAt)
            #expect(record.metadata.lastValidatedAt == lastValidatedAt)
            #expect(!record.metadata.sourceEndpoint.isEmpty)
            #expect(record.metadata.serverRevision != nil)
        }
        #expect(throws: NativeCacheRecoveryError.self) {
            try snapshot.copy(schemaVersion: 1).validatedForRestore()
        }

        let shoppingList = try ShoppingListState.decodeFromBundle()
        let queue = try MutationQueue().appending(
            QueuedMutation(
                id: "queued-add-lemons",
                clientMutationID: "mutation-add-lemons",
                createdAt: "2026-06-16T11:57:00.000Z",
                kind: .shoppingAdd(name: "lemons", quantity: 2, unit: nil, categoryKey: "produce", iconKey: "lemon")
            )
        )
        let v1 = try NativeAppSnapshot.bootstrap(shoppingList: shoppingList, savedAt: "2026-06-16T11:58:00.000Z")
            .updatingCookProgress(
                CookModeProgress(recipeID: "recipe_lemon_pantry_pasta", completedStepIDs: ["step_1"], currentStepID: "step_2"),
                savedAt: "2026-06-16T11:59:00.000Z"
            )
            .updatingCaptureDraft(
                CaptureDraft.localText(id: "capture_1", text: "grandma sauce", createdAt: "2026-06-16T11:59:30.000Z"),
                savedAt: "2026-06-16T12:00:00.000Z"
            )
            .copyForCacheMigration(pendingMutations: queue)
        let migrated = try NativeDurableCacheSnapshot.migratingSchemaVersionOne(
            v1,
            accountID: "chef_ari",
            environment: .production,
            migratedAt: fetchedAt
        )
        #expect(migrated.schemaVersion == 2)
        #expect(migrated.record(for: .shoppingList) != nil)
        #expect(migrated.record(for: .cookProgress(recipeID: "recipe_lemon_pantry_pasta")) != nil)
        #expect(migrated.record(for: .captureDraft(id: "capture_1")) != nil)
        #expect(migrated.pendingMutationQueue == queue)
    }

    @Test("freshness policy boundaries and triggers are exact")
    func freshnessPolicyBoundariesAndTriggersAreExact() throws {
        let now = try instant("2026-06-16T12:00:00.000Z")
        let policy = NativeCacheFreshnessPolicy.offlineProductContract

        #expect(policy.threshold(for: .accountBootstrap) == .minutes(15))
        #expect(policy.threshold(for: .settings) == .minutes(15))
        #expect(policy.threshold(for: .shoppingList) == .minutes(15))
        #expect(policy.threshold(for: .recipeDetail(id: "recipe_lemon_pantry_pasta")) == .hours(6))
        #expect(policy.threshold(for: .cookbookDetail(id: "cookbook_weeknight")) == .hours(6))
        #expect(policy.threshold(for: .spoonList(recipeID: "recipe_lemon_pantry_pasta")) == .hours(6))
        #expect(policy.threshold(for: .profile(id: "chef_ari")) == .hours(6))
        #expect(policy.threshold(for: .cookModeBackingData(recipeID: "recipe_lemon_pantry_pasta")) == .hours(6))
        #expect(policy.threshold(for: .recipeCatalog) == .hours(24))
        #expect(policy.threshold(for: .searchResults(query: "lemon")) == .hours(24))
        #expect(policy.threshold(for: .cookProgress(recipeID: "recipe_lemon_pantry_pasta")) == .locallyAuthoritative)
        #expect(policy.threshold(for: .captureDraft(id: "capture_1")) == .locallyAuthoritative)
        #expect(policy.threshold(for: .stagedMedia(id: "stage_photo_1")) == .locallyAuthoritative)

        #expect(policy.freshness(for: record(domain: .accountBootstrap, lastValidatedAt: now.addingTimeInterval(-15 * 60)), now: now) == .fresh)
        #expect(policy.freshness(for: record(domain: .accountBootstrap, lastValidatedAt: now.addingTimeInterval(-(15 * 60 + 1))), now: now) == .stale(secondsOverThreshold: 1))
        #expect(policy.freshness(for: record(domain: .recipeDetail(id: "recipe_lemon_pantry_pasta"), lastValidatedAt: now.addingTimeInterval(-6 * 60 * 60)), now: now) == .fresh)
        #expect(policy.freshness(for: record(domain: .recipeDetail(id: "recipe_lemon_pantry_pasta"), lastValidatedAt: now.addingTimeInterval(-(6 * 60 * 60 + 1))), now: now) == .stale(secondsOverThreshold: 1))
        #expect(policy.freshness(for: record(domain: .recipeCatalog, lastValidatedAt: now.addingTimeInterval(-24 * 60 * 60)), now: now) == .fresh)
        #expect(policy.freshness(for: record(domain: .recipeCatalog, lastValidatedAt: now.addingTimeInterval(-(24 * 60 * 60 + 1))), now: now) == .stale(secondsOverThreshold: 1))
        #expect(policy.freshness(for: record(domain: .cookProgress(recipeID: "recipe_lemon_pantry_pasta"), lastValidatedAt: now.addingTimeInterval(-30 * 24 * 60 * 60)), now: now) == .locallyAuthoritative)
        #expect(policy.revalidationTriggers(for: .stale(secondsOverThreshold: 1)) == [.launch, .foreground, .accountChanged, .environmentChanged, .networkRecovered, .visibleSurfaceOpened])
    }

    @Test("indicator reducer dismissal store and prefetch policy obey offline contract")
    func indicatorReducerDismissalStoreAndPrefetchPolicyObeyOfflineContract() throws {
        let now = try instant("2026-06-16T12:00:00.000Z")
        let reducer = OfflineIndicatorReducer(accountID: "chef_ari", environment: .production)
        var state = OfflineIndicatorState.synced(lastSyncedAt: now)

        state = reducer.reduce(state, .networkUnavailable(at: now))
        #expect(state.display == .offline)
        #expect(state.isVisible)
        state = reducer.reduce(state, .dismissCurrentIndicator(at: now, cacheFingerprint: "offline-v1"))
        #expect(state.display == .dismissed(previous: .offline, reason: .informationalOnly))
        #expect(!state.isVisible)
        #expect(state.dismissal?.accountID == "chef_ari")

        state = reducer.reduce(state, .cacheBecameStale(domain: .recipeCatalog, at: now.addingTimeInterval(24 * 60 * 60 + 1), cacheFingerprint: "recipe-catalog-v1"))
        #expect(state.display == .dismissed(previous: .stale(domain: .recipeCatalog), reason: .informationalOnly))
        #expect(!state.isVisible)
        state = reducer.reduce(state, .queuedWorkChanged(count: 2, oldestClientMutationID: "mutation_recipe_update_1"))
        #expect(state.display == .queuedWork(count: 2, oldestClientMutationID: "mutation_recipe_update_1"))
        #expect(state.isVisible)
        state = reducer.reduce(state, .dismissCurrentIndicator(at: now, cacheFingerprint: "queued-v1"))
        #expect(state.display == .queuedWork(count: 2, oldestClientMutationID: "mutation_recipe_update_1"))
        #expect(state.isVisible)
        state = reducer.reduce(state, .syncFailed(errorID: "offline-timeout", retryAfter: .seconds(30)))
        #expect(state.display == .syncFailure(errorID: "offline-timeout", retryAfter: .seconds(30)))
        state = reducer.reduce(state, .conflictDetected(recordID: "recipe_lemon_pantry_pasta", mutationID: "mutation_recipe_update_1"))
        #expect(state.display == .conflict(recordID: "recipe_lemon_pantry_pasta", mutationID: "mutation_recipe_update_1"))
        state = reducer.reduce(state, .blockerDetected(kind: .providerSecret(resourceID: "cover_regen_1")))
        #expect(state.display == .blocker(.providerSecret(resourceID: "cover_regen_1")))
        state = reducer.reduce(state, .destructiveConfirmationRequired(actionID: "clear_all_shopping"))
        #expect(state.display == .destructiveConfirmation(actionID: "clear_all_shopping"))
        #expect(state.isVisible)
        state = reducer.reduce(state, .severeStateResolved(at: now.addingTimeInterval(60)))
        #expect(state.display == .synced)

        var dismissalStore = NativeIndicatorDismissalStore()
        let dismissal = NativeIndicatorDismissal(
            accountID: "chef_ari",
            environment: .production,
            hiddenDisplay: .stale(domain: .recipeCatalog),
            dismissedAt: now,
            cacheFingerprint: "recipe-catalog-v1"
        )
        try dismissalStore.persist(dismissal)
        #expect(dismissalStore.isHidden(.stale(domain: .recipeCatalog), accountID: "chef_ari", environment: .production, cacheFingerprint: "recipe-catalog-v1"))
        #expect(!dismissalStore.isHidden(.stale(domain: .recipeCatalog), accountID: "chef_other", environment: .production, cacheFingerprint: "recipe-catalog-v1"))
        #expect(!dismissalStore.isHidden(.stale(domain: .recipeCatalog), accountID: "chef_ari", environment: .local, cacheFingerprint: "recipe-catalog-v1"))
        #expect(!dismissalStore.isHidden(.stale(domain: .recipeCatalog), accountID: "chef_ari", environment: .production, cacheFingerprint: "recipe-catalog-v2"))
        #expect(throws: NativeIndicatorDismissalError.self) {
            try dismissalStore.persist(dismissal.copy(hiddenDisplay: .syncFailure(errorID: "offline-timeout", retryAfter: .seconds(30))))
        }

        let plan = NativeCachePrefetchPolicy.offlineProductContract.plan(
            for: .signedInLaunch(
                accountID: "chef_ari",
                environment: .production,
                recentlyViewedRecipeIDs: ["recipe_lemon_pantry_pasta", "recipe_tomato_soup"],
                activeCookModeRecipeIDs: ["recipe_lemon_pantry_pasta"],
                viewedProfileIDs: ["chef_jules"]
            )
        )
        #expect(plan.requiredReads == [.currentAccount, .kitchen, .notificationPreferences, .tokenMetadata, .connectionStatus, .apnsStatus, .cookbookList, .shoppingList, .recipeDetail(id: "recipe_lemon_pantry_pasta"), .recipeDetail(id: "recipe_tomato_soup"), .cookModeBackingData(recipeID: "recipe_lemon_pantry_pasta"), .profile(id: "chef_jules")])
        #expect(plan.revalidateOn == [.launch, .foreground, .networkRecovered, .visibleSurfaceOpened])
        #expect(!plan.containsOnlineOnlyActions)
        #expect(plan.onlineOnlyActionsQueued.isEmpty)
    }

    @Test("media staging caps secret rejection and corrupt cache recovery are enforced")
    func mediaStagingCapsSecretRejectionAndCorruptCacheRecoveryAreEnforced() throws {
        let policy = NativeMediaStagingPolicy.offlineProductContract
        let oneMiB = 1_024 * 1_024
        #expect(policy.maxIndividualUserSelectedBytes == 25 * oneMiB)
        #expect(policy.maxGeneratedPreviewBytesPerAccount == 128 * oneMiB)
        #expect(policy.maxUnsyncedUserSelectedBytesPerAccount == 512 * oneMiB)
        #expect(policy.maxUnsyncedUserSelectedFilesPerAccount == 100)
        #expect(!policy.allowsSilentEvictionOfUnsyncedUserMedia)

        let metadata = try NativeMediaStagingMetadata(
            accountID: "chef_ari",
            environment: .production,
            localStageID: "stage_photo_1",
            originalFilename: "Ari Kitchen / Private Photo.JPG",
            contentType: "image/jpeg",
            byteCount: 25 * oneMiB,
            createdAt: try instant("2026-06-16T12:00:00.000Z")
        )
        #expect(metadata.privacySafeRelativePath == "chef_ari/production/v2/stage_photo_1.jpeg")
        #expect(metadata.durableMetadata.originalFilename == nil)
        #expect(metadata.durableMetadata.rawLocalFileURL == nil)
        #expect(policy.evaluateNewUserSelectedMedia(byteCount: 25 * oneMiB, existingUnsyncedBytes: 512 * oneMiB - 25 * oneMiB, existingUnsyncedFileCount: 99) == .accepted)
        #expect(policy.evaluateNewUserSelectedMedia(byteCount: 25 * oneMiB + 1, existingUnsyncedBytes: 0, existingUnsyncedFileCount: 0) == .rejected(.individualFileTooLarge(limitBytes: 25 * oneMiB)))
        #expect(policy.evaluateNewUserSelectedMedia(byteCount: 1, existingUnsyncedBytes: 512 * oneMiB, existingUnsyncedFileCount: 1) == .rejected(.accountByteCapReached(limitBytes: 512 * oneMiB, silentEvictionAllowed: false)))
        #expect(policy.evaluateNewUserSelectedMedia(byteCount: 1, existingUnsyncedBytes: 1, existingUnsyncedFileCount: 100) == .rejected(.accountFileCapReached(limitFiles: 100, silentEvictionAllowed: false)))
        #expect(policy.evaluateGeneratedPreview(bytesAfterWrite: 128 * oneMiB + 1) == .rejected(.generatedPreviewCapReached(limitBytes: 128 * oneMiB)))

        try withTemporaryDirectory { directory in
            let fetchedAt = try instant("2026-06-16T12:00:00.000Z")
            let safeSnapshot = try NativeDurableCacheSnapshot(
                schemaVersion: 2,
                accountID: "chef_ari",
                environment: .production,
                createdAt: fetchedAt,
                records: productContractRecords(fetchedAt: fetchedAt, lastValidatedAt: try instant("2026-06-16T12:05:00.000Z")),
                dismissedIndicators: []
            )
            let fileURL = directory.appendingPathComponent("native-cache.json")
            let store = NativeDurableCacheStore(fileURL: fileURL, clock: .fixed(try instant("2026-06-16T12:10:00.000Z")))
            try store.save(safeSnapshot)
            let raw = try String(contentsOf: fileURL, encoding: .utf8)
            for forbidden in ["sj_access", "ort_refresh", "one-time-token-value", "provider-secret", "passkey-private-key", "https://signed.example", "/Users/arimendelow/Pictures/private.jpg"] {
                #expect(!raw.contains(forbidden))
            }
            #expect(throws: NativeCacheSecurityError.self) { try store.save(safeSnapshot.copy(insertingSecret: .bearerToken("sj_access"))) }
            #expect(throws: NativeCacheSecurityError.self) { try store.save(safeSnapshot.copy(insertingSecret: .refreshToken("ort_refresh"))) }
            #expect(throws: NativeCacheSecurityError.self) { try store.save(safeSnapshot.copy(insertingSecret: .oneTimeTokenValue("one-time-token-value"))) }
            #expect(throws: NativeCacheSecurityError.self) { try store.save(safeSnapshot.copy(insertingSecret: .providerSecret("provider-secret"))) }
            #expect(throws: NativeCacheSecurityError.self) { try store.save(safeSnapshot.copy(insertingSecret: .rawMediaPath("/Users/arimendelow/Pictures/private.jpg"))) }
            #expect(throws: NativeCacheSecurityError.self) { try store.save(safeSnapshot.copy(insertingSecret: .signedURL("https://signed.example/photo.jpg?token=sj_access"))) }

            try Data("{ nope".utf8).write(to: fileURL)
            let recovered = try store.loadOrRecover(fallback: safeSnapshot)
            #expect(recovered.value == safeSnapshot)
            #expect(recovered.source == .fallbackAfterCorruption)
            #expect(recovered.recovery == .corruptCacheQuarantined(originalURL: fileURL, quarantineSuffix: "2026-06-16T121000Z"))
            #expect(try String(contentsOf: fileURL, encoding: .utf8) == "{ nope")
            #expect(FileManager.default.fileExists(atPath: fileURL.appendingPathExtension("corrupt.2026-06-16T121000Z").path))
        }
    }
}

private let expectedDomains: [NativeCacheDomain] = [
    .recipeCatalog,
    .recipeDetail(id: "recipe_lemon_pantry_pasta"),
    .cookbookList,
    .cookbookDetail(id: "cookbook_weeknight"),
    .shoppingList,
    .cookProgress(recipeID: "recipe_lemon_pantry_pasta"),
    .captureDraft(id: "capture_share_sheet_1"),
    .profile(id: "chef_ari"),
    .notificationPreferences,
    .tokenMetadata,
    .connectionStatus,
    .apnsStatus
]

private func productContractRecords(fetchedAt: Date, lastValidatedAt: Date) throws -> [NativeCacheRecord] {
    [
        try record(domain: .recipeCatalog, sourceEndpoint: "/api/v1/recipes", serverRevision: .cursor("recipe-catalog-cursor-v1"), payload: .recipeCatalog(recipeIDs: ["recipe_lemon_pantry_pasta"]), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .recipeDetail(id: "recipe_lemon_pantry_pasta"), sourceEndpoint: "/api/v1/recipes/recipe_lemon_pantry_pasta", serverRevision: .etag("\"recipe-detail-v7\""), payload: .recipeDetail(id: "recipe_lemon_pantry_pasta", title: "Lemon Pantry Pasta"), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .cookbookList, sourceEndpoint: "/api/v1/cookbooks", serverRevision: .cursor("cookbook-list-cursor-v1"), payload: .cookbookList(cookbookIDs: ["cookbook_weeknight"]), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .cookbookDetail(id: "cookbook_weeknight"), sourceEndpoint: "/api/v1/cookbooks/cookbook_weeknight", serverRevision: .updatedAt("2026-06-16T11:58:00.000Z"), payload: .cookbookDetail(id: "cookbook_weeknight", title: "Weeknight"), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .shoppingList, sourceEndpoint: "/api/v1/shopping-list", serverRevision: .cursor("shopping-sync-cursor-v3"), payload: .shoppingList(itemIDs: ["item_lemons"], syncCursor: "shopping-sync-cursor-v3"), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .cookProgress(recipeID: "recipe_lemon_pantry_pasta"), sourceEndpoint: "local://cook-progress/recipe_lemon_pantry_pasta", serverRevision: .localRevision("cook-progress-local-v1"), payload: .cookProgress(recipeID: "recipe_lemon_pantry_pasta", completedStepIDs: ["step_1"], currentStepID: "step_2"), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .captureDraft(id: "capture_share_sheet_1"), sourceEndpoint: "local://capture-drafts/capture_share_sheet_1", serverRevision: .localRevision("capture-draft-local-v1"), payload: .captureDraft(id: "capture_share_sheet_1", source: .shareSheetURL("https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .profile(id: "chef_ari"), sourceEndpoint: "/api/v1/users/chef_ari", serverRevision: .updatedAt("2026-06-16T11:55:00.000Z"), payload: .profile(id: "chef_ari", username: "ari"), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .notificationPreferences, sourceEndpoint: "/api/v1/me/notification-preferences", serverRevision: .etag("\"notification-preferences-v1\""), payload: .notificationPreferences(marketingEnabled: false, cookingRemindersEnabled: true), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .tokenMetadata, sourceEndpoint: "/api/v1/tokens", serverRevision: .etag("\"token-metadata-v2\""), payload: .tokenMetadata(credentials: [NativeTokenMetadata(id: "cred_1", name: "Kitchen iPad", scopes: ["recipes:read"])]), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .connectionStatus, sourceEndpoint: "/api/v1/me/connections", serverRevision: .etag("\"connections-v1\""), payload: .connectionStatus(connections: [NativeConnectionStatus(id: "conn_google", provider: "google", status: .connected)]), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt),
        try record(domain: .apnsStatus, sourceEndpoint: "/api/v1/me/apns-devices", serverRevision: .etag("\"apns-v1\""), payload: .apnsStatus(deviceID: "device_ios_1", registrationState: .registered), fetchedAt: fetchedAt, lastValidatedAt: lastValidatedAt)
    ]
}

private func record(
    domain: NativeCacheDomain,
    sourceEndpoint: String = "/api/v1/test",
    serverRevision: NativeCacheServerRevision = .etag("\"test\""),
    payload: NativeCachePayload = .empty,
    fetchedAt: Date = Date(timeIntervalSince1970: 1_781_612_800),
    lastValidatedAt: Date
) throws -> NativeCacheRecord {
    try NativeCacheRecord(
        id: domain.stableRecordID,
        metadata: NativeCacheRecordMetadata(
            accountID: "chef_ari",
            environment: .production,
            schemaVersion: 2,
            domain: domain,
            fetchedAt: fetchedAt,
            lastValidatedAt: lastValidatedAt,
            sourceEndpoint: sourceEndpoint,
            serverRevision: serverRevision
        ),
        payload: payload
    )
}

private func instant(_ value: String) throws -> Date {
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: value) {
        return date
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return try #require(formatter.date(from: value))
}

private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try body(directory)
}
"""#
