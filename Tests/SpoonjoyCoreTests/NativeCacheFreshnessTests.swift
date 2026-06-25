import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native cache schema and freshness")
struct NativeCacheFreshnessTests {
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

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRoot().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeCacheContractError.missingFile(relativePath)
    }

    return try String(contentsOf: url, encoding: .utf8)
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
