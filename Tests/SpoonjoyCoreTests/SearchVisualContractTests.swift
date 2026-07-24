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
        #expect(searchView.contains("} else if viewModel.sections.isEmpty, let emptyState = viewModel.emptyState {"))

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
        let refreshFixturePaths = try #require(body.range(of: "refresh_ios_fixture_paths"))
        #expect(terminate.lowerBound < refreshFixturePaths.lowerBound)

        let refreshFunction = try #require(capture.range(of: "refresh_ios_fixture_paths() {"))
        let captureFunctionStart = try #require(capture.range(of: "capture_ios_app() {"))
        let refreshBody = capture[refreshFunction.lowerBound..<captureFunctionStart.lowerBound]
        #expect(refreshBody.contains("atomic_fixture_write \"$ios_state_directory/native-app-state.json\" write_app_state"))
    }

    @Test("simulator termination and stop probes are bounded")
    func simulatorTerminationAndStopProbesAreBounded() throws {
        let capture = try readSearchContractFile("scripts/capture-native-screenshots.sh")
        let start = try #require(capture.range(of: "terminate_ios_app_and_confirm_stopped() {"))
        let end = try #require(capture.range(of: "terminate_macos_app_and_confirm_stopped() {", range: start.upperBound..<capture.endIndex))
        let body = capture[start.lowerBound..<end.lowerBound]

        #expect(body.contains("run_with_timeout \"simulator app termination timeout\""))
        #expect(body.contains("run_with_timeout \"simulator stopped-process probe timeout\""))
        #expect(body.contains("xcrun simctl terminate \"$udid\" app.spoonjoy"))
        #expect(body.contains("xcrun simctl spawn -a \"$ios_simulator_spawn_arch\" \"$udid\" launchctl list"))
        #expect(body.contains("grep -Fq 'UIKitApplication:app.spoonjoy'"))
        #expect(!body.contains("if ! xcrun simctl terminate"))
        #expect(!body.contains("if ! xcrun simctl spawn"))
        #expect(!body.contains("xcrun simctl spawn \"$udid\" /bin/sh -c"))
    }

    @Test("simulator launch does not use the hanging terminate-and-launch composite")
    func simulatorLaunchAvoidsTerminateAndLaunchComposite() throws {
        let capture = try readSearchContractFile("scripts/capture-native-screenshots.sh")
        let smoke = try readSearchContractFile("scripts/smoke-ios-simulator.sh")

        #expect(capture.contains("xcrun simctl launch --stdout=\"$ios_app_stdout_log\" --stderr=\"$ios_app_stderr_log\" \"$udid\" app.spoonjoy"))
        #expect(smoke.contains("$launch_command --stdout='$app_stdout_path' --stderr='$app_stderr_path' $udid app.spoonjoy"))
        #expect(capture.contains("ios_app_stdout_log=\"$artifact_root/apple/${unit_slug}-ios-app-stdout.log\""))
        #expect(capture.contains("ios_app_stderr_log=\"$artifact_root/apple/${unit_slug}-ios-app-stderr.log\""))
        #expect(smoke.contains("app_stdout_path=\"$artifact_root/apple/${unit_slug}-app-stdout.log\""))
        #expect(smoke.contains("app_stderr_path=\"$artifact_root/apple/${unit_slug}-app-stderr.log\""))
        #expect(smoke.contains("tempfile.TemporaryFile(mode=\"w+b\")"))
        #expect(smoke.contains("exit_code = process.wait(timeout=timeout_seconds)"))
        #expect(smoke.contains("sys.stdout.buffer.write(output.read())"))
        #expect(!capture.contains("--terminate-running-process"))
        #expect(!smoke.contains("--terminate-running-process"))
        #expect(!smoke.contains("stdout=subprocess.PIPE"))
        #expect(!smoke.contains("process.communicate("))
    }
}

private func readSearchContractFile(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}
