import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Search visual determinism")
struct SearchVisualContractTests {
    @Test("scope labels use one shared native grammar")
    func scopeLabelsUseOneSharedNativeGrammar() {
        #expect(SearchSurfaceScopeGrammar.title(for: .all) == "Everything")
        #expect(SearchSurfaceScopeGrammar.title(for: .recipes) == "Recipes")
        #expect(SearchSurfaceScopeGrammar.title(for: .cookbooks) == "Cookbooks")
        #expect(SearchSurfaceScopeGrammar.title(for: .chefs) == "Chefs")
        #expect(SearchSurfaceScopeGrammar.title(for: .shoppingList) == "Shopping")
    }

    @Test("render fingerprints describe exact ordered pixels and remain deterministic")
    func renderFingerprintsDescribeExactOrderedPixelsAndRemainDeterministic() throws {
        let validatedAt = Date(timeIntervalSince1970: 1_783_100_000)
        let page = SearchSurfacePage(
            query: "weeknights",
            scope: .cookbooks,
            limit: 20,
            isAuthenticated: true,
            results: [
                SearchSurfaceResult(
                    type: .cookbook,
                    id: "cookbook_weeknights",
                    ownerID: "chef_ari",
                    ownerUsername: "ari",
                    title: "Weeknights",
                    subtitle: "1 recipe",
                    snippet: nil,
                    href: "/cookbooks/cookbook_weeknights",
                    canonicalURL: URL(string: "https://spoonjoy.app/cookbooks/cookbook_weeknights")!,
                    imageURL: nil,
                    score: 1,
                    metadata: [:]
                )
            ],
            source: .cache(serverRevision: .cursor("search-weeknights"), lastValidatedAt: validatedAt)
        )
        let state = SearchState(query: "weeknights", scope: .cookbooks)
        let first = SearchSurfaceViewModel(
            page: page,
            state: state,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { validatedAt }
        )
        let second = SearchSurfaceViewModel(
            page: page,
            state: state,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { validatedAt }
        )

        #expect(first.renderFingerprint == second.renderFingerprint)
        #expect(first.renderFingerprint.rows == [
            SearchSurfaceRenderFingerprint.Row(
                type: "cookbook",
                id: "cookbook-cookbook_weeknights",
                title: "Weeknights"
            )
        ])
        #expect(first.renderFingerprint.dataSource == .cache(serverRevision: "cursor:search-weeknights"))
        #expect(first.renderFingerprint.emptyState == nil)
        let firstEncoder = JSONEncoder()
        firstEncoder.outputFormatting = [.sortedKeys]
        let secondEncoder = JSONEncoder()
        secondEncoder.outputFormatting = [.sortedKeys]
        #expect(try firstEncoder.encode(first.renderFingerprint) == secondEncoder.encode(second.renderFingerprint))
    }

    @Test("render fingerprints preserve every transport and revision source")
    func renderFingerprintsPreserveEveryTransportAndRevisionSource() {
        let validatedAt = Date(timeIntervalSince1970: 1_783_100_000)
        let cases: [(SearchSurfaceDataSource, SearchSurfaceRenderFingerprint.DataSource)] = [
            (.live(requestID: "request-search", validatedAt: validatedAt), .live(requestID: "request-search")),
            (.cache(serverRevision: .etag("search-etag"), lastValidatedAt: validatedAt), .cache(serverRevision: "etag:search-etag")),
            (.offlineCache(serverRevision: .updatedAt("2026-07-20T12:00:00.000Z"), lastValidatedAt: validatedAt), .offlineCache(serverRevision: "updated-at:2026-07-20T12:00:00.000Z")),
            (.offlineCache(serverRevision: .localRevision("search-local"), lastValidatedAt: validatedAt), .offlineCache(serverRevision: "local:search-local")),
            (.offlineCache(serverRevision: nil, lastValidatedAt: validatedAt), .offlineCache(serverRevision: nil))
        ]

        for (source, expectedFingerprint) in cases {
            let page = SearchSurfacePage(
                query: "seasonal",
                scope: .recipes,
                limit: 20,
                isAuthenticated: true,
                results: [],
                source: source
            )
            let viewModel = SearchSurfaceViewModel(
                page: page,
                state: SearchState(query: "seasonal", scope: .recipes),
                context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
                now: { validatedAt }
            )

            #expect(viewModel.renderFingerprint.dataSource == expectedFingerprint)
        }
    }

    @Test("shell owns native search chrome and restore-only guards every live effect")
    func shellOwnsNativeSearchChromeAndRestoreOnlyGuardsEveryLiveEffect() throws {
        let searchView = try readSearchContractFile("Apps/Spoonjoy/Shared/Views/SearchView.swift")
        let shell = try readSearchContractFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")
        let root = try readSearchContractFile("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift")

        #expect(!searchView.contains(".searchable("))
        #expect(!searchView.contains(".searchScopes("))
        #expect(!searchView.contains("@FocusState"))
        #expect(!searchView.contains("SearchSurfaceNativeChrome"))
        #expect(searchView.contains(".task(id: viewModel.renderFingerprint)"))

        #expect(shell.contains("private let allowsLiveEffects: Bool"))
        #expect(shell.contains("SearchSurfaceScopeGrammar.title(for: scope)"))
        #expect(shell.contains("guard allowsLiveEffects else"))
        #expect(shell.contains("viewModel: contentState.performSearch(nextSearch)"))
        #expect(shell.contains("if !allowsLiveEffects || offlineIndicatorState.display == .offline"))
        #expect(root.contains("allowsLiveEffects: liveStore.allowsLiveEffects"))
    }

    @Test("capture lifecycle terminates before atomic per-route seed writes")
    func captureLifecycleTerminatesBeforeAtomicPerRouteSeedWrites() throws {
        let capture = try readSearchContractFile("scripts/capture-native-screenshots.sh")
        let validator = try readSearchContractFile("scripts/validate-design-review.rb")

        #expect(capture.contains("expected_search_scope=\"all\""))
        #expect(capture.contains("SIMCTL_CHILD_SPOONJOY_SCREENSHOT_STATE_DIRECTORY=\"$ios_state_directory\""))
        #expect(capture.contains("terminate_ios_app_and_confirm_stopped"))
        #expect(capture.contains("atomic_fixture_write"))
        #expect(capture.contains("renderFingerprint"))
        #expect(validator.contains("renderFingerprint"))
        #expect(validator.contains("search proof render fingerprints must match across platforms"))
        #expect(validator.contains("queued shopping connectivity must be offline"))

        let captureFunction = try #require(capture.range(of: "capture_ios_app() {"))
        let retryFunction = try #require(capture.range(of: "capture_ios_app_with_retries() {"))
        let body = capture[captureFunction.lowerBound..<retryFunction.lowerBound]
        let terminate = try #require(body.range(of: "terminate_ios_app_and_confirm_stopped"))
        let writeState = try #require(body.range(of: "write_app_state"))
        #expect(terminate.lowerBound < writeState.lowerBound)
    }
}

private func readSearchContractFile(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}
