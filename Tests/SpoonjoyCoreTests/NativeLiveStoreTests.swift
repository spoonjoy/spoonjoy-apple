import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native live store and shell wiring")
struct NativeLiveStoreTests {
    @Test("core declares live app bootstrap state and repository dependencies")
    func coreDeclaresLiveAppBootstrapStateAndRepositoryDependencies() throws {
        let relativePath = "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift"
        let content = try? readRepoFile(relativePath)
        #expect(content != nil, Comment(rawValue: "\(relativePath) should define the live app store contract."))
        guard let content else { return }

        expectContent(
            uncommentedSwift(content),
            in: relativePath,
            contains: [
                "NativeLiveAppStore",
                "public struct NativeLiveAppStoreDependencies",
                "public enum NativeAppBootstrapState",
                "public enum NativeShellContentState",
                "case signedOut",
                "case restoringCache",
                "case liveSynced",
                "case offlineStale",
                "case queuedWork",
                "case conflict",
                "case blocker",
                "case destructiveConfirmation",
                "case syncFailed",
                "NativeAuthSessionRepository",
                "NativeDurableCacheStore",
                "NativeSyncEngine",
                "NativeSyncTriggerCoordinator",
                "APIClientConfiguration",
                "loadOrCreate",
                "restoreFromCache",
                "bootstrapFromLiveAPI",
                "switchEnvironment",
                "offlineIndicatorState",
                "settingsViewModel"
            ],
            forbids: [
                "RecipeFixtureCatalog.decodeFromBundle()",
                "CookbookFixtureCatalog.decodeFromBundle()",
                "KitchenFixtureState.decodeFromBundle()",
                "ShoppingListState.decodeFromBundle()"
            ]
        )
    }

    @Test("root view bootstraps through live store instead of fixture first run")
    func rootViewBootstrapsThroughLiveStoreInsteadOfFixtureFirstRun() throws {
        let relativePath = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"
        let content = uncommentedSwift(try readRepoFile(relativePath))

        expectContent(
            content,
            in: relativePath,
            contains: [
                "liveStore",
                "NativeLiveAppStore",
                "NativeLiveAppStoreDependencies",
                "bootstrap()",
                "bootstrapState",
                "case .signedOut",
                "case .restoringCache",
                "case .liveSynced",
                "case .offlineStale",
                "case .queuedWork",
                "case .conflict",
                "case .blocker",
                "case .destructiveConfirmation",
                "case .syncFailed",
                "PlatformNavigationView(",
                "contentState:",
                "offlineIndicatorState:",
                "dismissOfflineIndicator"
            ],
            forbids: [
                "NativeAppStateStore",
                "NativeAppSnapshot.bootstrap",
                "ShoppingListState.decodeFromBundle()",
                "hasCompletedFirstRun",
                "completeFirstRun(opening:",
                "openKitchen: { completeFirstRun"
            ]
        )
    }

    @Test("platform navigation consumes live content state and never decodes production fixtures")
    func platformNavigationConsumesLiveContentStateAndNeverDecodesProductionFixtures() throws {
        let relativePath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let content = uncommentedSwift(try readRepoFile(relativePath))

        expectContent(
            content,
            in: relativePath,
            contains: [
                "NativeShellContentState",
                "contentState.recipes",
                "contentState.cookbooks",
                "contentState.kitchen",
                "contentState.shoppingList",
                "contentState.searchResults",
                "contentState.captureDraft",
                "NativeQueuedMutation",
                "queueMutation",
                "syncTriggerCoordinator",
                "OfflineStatusView(display:",
                "offlineIndicatorState",
                "dismissOfflineIndicator",
                "SettingsView(",
                "settingsViewModel"
            ],
            forbids: [
                "RecipeFixtureCatalog.decodeFromBundle()",
                "CookbookFixtureCatalog.decodeFromBundle()",
                "KitchenFixtureState.decodeFromBundle()",
                "KitchenFixtureState.bootstrapFallback",
                "SettingsState(\n                auth: .signedOut",
                "QueuedMutation(",
                "startedAt: \"2026-06-16T11:45:00.000Z\""
            ]
        )
    }

    @Test("live store contract covers global search scopes and environment rebinding")
    func liveStoreContractCoversGlobalSearchScopesAndEnvironmentRebinding() throws {
        let relativePath = "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift"
        let content = try? readRepoFile(relativePath)
        #expect(content != nil, Comment(rawValue: "\(relativePath) should define live search and environment rebinding."))
        guard let content else { return }

        expectContent(
            uncommentedSwift(content),
            in: relativePath,
            contains: [
                "SearchScope.allCases",
                ".all",
                ".recipes",
                ".cookbooks",
                ".chefs",
                ".shoppingList",
                "searchResultsByScope",
                "switchEnvironment",
                "APIClientConfiguration",
                "NativeCacheEnvironment",
                "NativeDurableCacheStore",
                "NativeSyncTriggerEvent.environmentChanged",
                "NativeSyncTriggerCoordinator"
            ]
        )
    }

    @Test("production sources cannot silently use fixture bundles")
    func productionSourcesCannotSilentlyUseFixtureBundles() throws {
        let forbiddenTokens = [
            "RecipeFixtureCatalog.decodeFromBundle()",
            "CookbookFixtureCatalog.decodeFromBundle()",
            "KitchenFixtureState.decodeFromBundle()",
            "ShoppingListState.decodeFromBundle()"
        ]
        let allowedRelativePaths: Set<String> = [
            "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
            "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift"
        ]
        let roots = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Apps/Spoonjoy"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/SpoonjoyCore")
        ]
        let productionSwiftFiles = try roots.flatMap { try collectSwiftFiles(under: $0) }
        var violations: [String] = []

        for file in productionSwiftFiles {
            let relativePath = file.path.replacingOccurrences(
                of: FileManager.default.currentDirectoryPath + "/",
                with: ""
            )
            guard !allowedRelativePaths.contains(relativePath) else { continue }
            let content = uncommentedSwift(try String(contentsOf: file, encoding: .utf8))
            for token in forbiddenTokens where content.contains(token) {
                violations.append("\(relativePath) contains \(token)")
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: "Fixture fallback must be test/demo/policy gated only: \(violations.joined(separator: "; "))"))
    }

    @Test("signed out settings and offline indicator cover every live shell state")
    func signedOutSettingsAndOfflineIndicatorCoverEveryLiveShellState() throws {
        let signedOut = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift"))
        let settings = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Views/SettingsView.swift"))
        let offline = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift"))

        expectContent(
            signedOut,
            in: "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
            contains: [
                "NativeAuthSessionRepository",
                "SpoonjoyWebAuthenticationSession",
                "startSignIn",
                "restoreState",
                "revokeAndLogout",
                "SecureAuthWebHandoff.login",
                "authRequired"
            ],
            forbids: [
                "Open Kitchen",
                "keep offline fixtures nearby",
                ".disabled(true)"
            ]
        )
        expectContent(
            settings,
            in: "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
            contains: [
                "OfflineStatusView(display:",
                "viewModel.offlineIndicatorDisplay",
                "viewModel.dismissOfflineIndicator",
                "viewModel.authSessionState",
                "viewModel.environmentSwitcher"
            ],
            forbids: [
                "OfflineStatusView(state:",
                "settings.offline"
            ]
        )
        expectContent(
            offline,
            in: "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift",
            contains: [
                "queuedWork",
                "syncFailure",
                "conflict",
                "blocker",
                "destructiveConfirmation",
                "informationalOnly",
                "Button",
                "onDismiss"
            ],
            forbids: [
                "legacyStatusLabel"
            ]
        )
    }

    @Test("scenario verifier reports live store as structured checks and capabilities")
    func scenarioVerifierReportsLiveStoreAsStructuredChecksAndCapabilities() throws {
        let report = ScenarioVerifier.finalReport(rootURL: repoRootURL())
        let checksByName = report.checks.reduce(into: [String: ScenarioCheckStatus]()) { result, check in
            result[check.name] = check.status
        }
        let requiredPassingChecks = [
            "live store source",
            "signed-out live bootstrap",
            "restoring cache",
            "live synced shell",
            "offline stale shell",
            "queued work shell",
            "conflict shell",
            "blocker shell",
            "destructive confirmation shell",
            "sync failed shell",
            "fixture fallback disabled"
        ]

        for checkName in requiredPassingChecks {
            #expect(
                checksByName[checkName] == .pass,
                Comment(rawValue: "ScenarioVerifier.finalReport should pass structured check \(checkName).")
            )
        }

        let requiredOfflineFlows: Set<String> = [
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
        let reportedOfflineFlows = Set(report.nativeCapabilities.offlineFlows)
        #expect(
            requiredOfflineFlows.isSubset(of: reportedOfflineFlows),
            Comment(rawValue: "ScenarioVerifier.finalReport should expose live-store offline flows: \(requiredOfflineFlows.subtracting(reportedOfflineFlows).sorted().joined(separator: ", "))")
        )
    }

    @Test("shell contract gate live store instead of fixture parity")
    func shellContractGatesLiveStoreInsteadOfFixtureParity() throws {
        let shellContract = try readRepoFile("scripts/check-native-shell-contract.rb")

        expectContent(
            shellContract,
            in: "scripts/check-native-shell-contract.rb",
            contains: [
                "NativeLiveAppStore",
                "NativeShellContentState",
                "NativeLiveAppStoreDependencies",
                "OfflineStatusView(display:",
                "fixture fallback disabled"
            ]
        )
    }

    @Test("production fixture fallback is an explicit test and demo only policy")
    func productionFixtureFallbackIsAnExplicitTestAndDemoOnlyPolicy() throws {
        let relativePath = "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift"
        let content = try? readRepoFile(relativePath)
        #expect(content != nil, Comment(rawValue: "\(relativePath) should define fixture fallback policy."))
        guard let content else { return }

        expectContent(
            uncommentedSwift(content),
            in: relativePath,
            contains: [
                "public enum NativeFixtureFallbackPolicy",
                "case disabledInProduction",
                "case testsAndDemoOnly",
                "allowsProductionFallback",
                "SPOONJOY_ALLOW_FIXTURE_FALLBACK",
                "isTestOrDemoBuild"
            ],
            forbids: [
                "RecipeFixtureCatalog.decodeFromBundle()"
            ]
        )

        let executableURL = try compileFixtureFallbackPolicyHarness(policySource: content)
        let run = try runProcess(executableURL.path, [])
        #expect(run.status == 0, Comment(rawValue: "NativeFixtureFallbackPolicy runtime contract failed:\n\(run.output)"))
    }
}

private enum NativeLiveStoreTestError: Error, CustomStringConvertible {
    case missingFile(String)
    case processFailed(String)

    var description: String {
        switch self {
        case .missingFile(let path):
            "Missing repo file: \(path)"
        case .processFailed(let output):
            output
        }
    }
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRootURL().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeLiveStoreTestError.missingFile(relativePath)
    }

    return try String(contentsOf: url, encoding: .utf8)
}

private func repoRootURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func collectSwiftFiles(under root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return try enumerator.compactMap { item in
        guard let url = item as? URL, url.pathExtension == "swift" else {
            return nil
        }
        let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
        return resourceValues.isRegularFile == true ? url : nil
    }
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(
            of: #"/\*.*?\*/"#,
            with: "",
            options: [.regularExpression]
        )
        .replacingOccurrences(
            of: #"(?m)//.*$"#,
            with: "",
            options: [.regularExpression]
        )
}

private func expectContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String],
    forbids forbiddenTokens: [String] = []
) {
    for token in requiredTokens {
        let isPresent = content.contains(token)
        #expect(isPresent, Comment(rawValue: "\(relativePath) missing token: \(token)"))
    }

    for token in forbiddenTokens {
        let isAbsent = !content.contains(token)
        #expect(isAbsent, Comment(rawValue: "\(relativePath) should not contain token: \(token)"))
    }
}

private struct ProcessRunResult: Equatable {
    let status: Int32
    let output: String
}

private func compileFixtureFallbackPolicyHarness(policySource: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("spoonjoy-fixture-policy-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let policyURL = directory.appendingPathComponent("NativeFixtureFallbackPolicy.swift")
    let harnessURL = directory.appendingPathComponent("main.swift")
    let executableURL = directory.appendingPathComponent("fixture-policy-check")
    try policySource.write(to: policyURL, atomically: true, encoding: .utf8)
    try fixtureFallbackPolicyHarnessSource.write(to: harnessURL, atomically: true, encoding: .utf8)

    let compile = try runProcess(
        "/usr/bin/xcrun",
        [
            "swiftc",
            policyURL.path,
            harnessURL.path,
            "-o",
            executableURL.path
        ]
    )
    #expect(compile.status == 0, Comment(rawValue: "NativeFixtureFallbackPolicy should compile in isolation:\n\(compile.output)"))
    guard compile.status == 0 else {
        throw NativeLiveStoreTestError.processFailed(compile.output)
    }
    return executableURL
}

private func runProcess(_ executablePath: String, _ arguments: [String]) throws -> ProcessRunResult {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return ProcessRunResult(status: process.terminationStatus, output: output)
}

private let fixtureFallbackPolicyHarnessSource = """
import Foundation

func require(_ condition: Bool, _ message: String) {
    if !condition {
        FileHandle.standardError.write(Data((message + "\\n").utf8))
        exit(1)
    }
}

let disabled = NativeFixtureFallbackPolicy.disabledInProduction
require(!disabled.allowsProductionFallback(isTestOrDemoBuild: false, environment: [:]), "production fallback must be denied by default")
require(!disabled.allowsProductionFallback(isTestOrDemoBuild: true, environment: ["SPOONJOY_ALLOW_FIXTURE_FALLBACK": "1"]), "disabled policy must deny even explicit test/demo opt-in")

let testsAndDemo = NativeFixtureFallbackPolicy.testsAndDemoOnly
require(!testsAndDemo.allowsProductionFallback(isTestOrDemoBuild: false, environment: [:]), "tests/demo policy must deny production by default")
require(testsAndDemo.allowsProductionFallback(isTestOrDemoBuild: true, environment: [:]), "tests/demo policy must allow test builds")
require(testsAndDemo.allowsProductionFallback(isTestOrDemoBuild: false, environment: ["SPOONJOY_ALLOW_FIXTURE_FALLBACK": "1"]), "tests/demo policy must allow explicit environment opt-in")
require(NativeFixtureFallbackPolicy.isTestOrDemoBuild(environment: ["XCTestConfigurationFilePath": "/tmp/test.xctest"]), "XCTest environment should be recognized")
require(NativeFixtureFallbackPolicy.isTestOrDemoBuild(environment: ["SPOONJOY_DEMO_MODE": "1"]), "demo environment should be recognized")
require(!NativeFixtureFallbackPolicy.isTestOrDemoBuild(environment: [:]), "empty environment should not be treated as test/demo")
"""
