import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native search surface parity")
struct NativeSearchSurfaceTests {
    private static let now = Date(timeIntervalSince1970: 1_780_140_000)
    private static let staleValidatedAt = Date(timeIntervalSince1970: 1_779_950_000)
    private static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("search surface exists as a first-class native feature")
    func searchSurfaceExistsAsFirstClassNativeFeature() throws {
        let failures = sourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Features/Search/SearchSurfaceRepository.swift",
                "Sources/SpoonjoyCore/Features/Search/SearchSurfaceViewModel.swift",
                "Apps/Spoonjoy/Shared/Views/SearchView.swift",
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                "Sources/SpoonjoyCore/Cache/NativeDurableCache.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Features/Search/SearchSurfaceRepository.swift": [
                    "SearchSurfaceRepository",
                    "LiveSearchSurfaceRepository",
                    "SnapshotSearchSurfaceRepository",
                    "FallbackSearchSurfaceRepository",
                    "SearchSurfaceRequest",
                    "SearchSurfacePage",
                    "SearchSurfaceData",
                    "SearchSurfaceResult",
                    "SearchSurfaceResultType",
                    "SearchSurfaceCacheSnapshot",
                    "SearchSurfaceRecentQuery",
                    "SearchSurfaceRepositoryError",
                    "normalizedLimit",
                    "APITransportError",
                    "recentSearches",
                    "SearchRequests.search",
                    "NativeCacheDomain.searchResults",
                    "shopping_list:read"
                ],
                "Sources/SpoonjoyCore/Features/Search/SearchSurfaceViewModel.swift": [
                    "SearchSurfaceViewModel",
                    "SearchSurfaceContext",
                    "SearchSurfaceSection",
                    "SearchSurfaceRow",
                    "SearchSurfaceEmptyState",
                    "SearchSurfaceErrorState",
                    "SearchSurfaceDebouncePolicy",
                    "SearchSurfaceDebounceDecision",
                    "cancelsInFlightSearch",
                    "previous != next",
                    "OfflineIndicatorState",
                    "SearchScope.allCases",
                    "AppRoute.recipeDetail",
                    "AppRoute.cookbookDetail",
                    "AppRoute.profile",
                    "AppRoute.shoppingList"
                ],
                "Apps/Spoonjoy/Shared/Views/SearchView.swift": [
                    "SearchSurfaceViewModel",
                    "SearchSurfaceSection",
                    "SearchSurfaceRow",
                    "OfflineStatusView",
                    "searchTask",
                    "debounce"
                ],
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift": [
                    "@FocusState private var isSearchFieldFocused",
                    "contentState.searchSurfaceViewModel",
                    "performSearch(",
                    "SearchView(",
                    ".searchFocused($isSearchFieldFocused)",
                    "isSearchFieldFocused = true",
                    "search.apply(route: routeSearch.route)",
                    "ActiveSearchSurfaceState",
                    "recordSearchSurfacePageHandler(page, identity)",
                    "contentState.searchSurfaceIdentity",
                    "normalizedSearch(",
                    "canApplySearchResult(identity: identity, state: nextSearch)",
                    "LiveSearchRequestMarker",
                    "liveSearchRequestMarker(for: routeSearch)",
                    "liveSearchTaskIdentity(for: routeSearch)",
                    "refreshRouteSearchIfNeeded(routeSearch)",
                    "guard liveSearchRequestMarker != requestMarker else",
                    "clearLiveSearchRequestMarker(requestMarker)",
                    "routeOwnsOfflineStatus",
                    "routeKeepsSearchFocus",
                    "searchSurfaceRepositoryHandler(context)",
                    "isSearchFieldFocused = false"
                ],
                "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift": [
                    "recordSearchSurfacePage: { page, identity in",
                    "recordSearchSurfacePage(page, expectedIdentity: identity)",
                    "searchSurfaceRepository: { context in",
                    "liveStore.searchSurfaceRepository(context: context)",
                    "signedOutRouteUsesNativeShell"
                ],
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift": [
                    "searchSurfaceViewModel",
                    "SearchSurfaceViewModel",
                    "SearchSurfaceCacheSnapshot",
                    "restoreSearchSurfaceSnapshot",
                    "performSearch(",
                    "searchSurfaceRepository(context: SearchSurfaceContext)",
                    "dependencies.recipeEditorAPITransport(refresher)",
                    "currentSearchSurfaceIdentity",
                    "searchSurfaceAccountID",
                    "searchSurfaceSevereOfflineIndicator",
                    "searchSurfaceSeverityIdentity",
                    "recordSearchSurfacePage(_ page: SearchSurfacePage, expectedIdentity: String)",
                    "canSaveDurableSnapshot",
                    "currentSnapshot.value.accountID == snapshot.accountID",
                    "sourceEndpoint: \"/api/v1/search\"",
                    ".searchResults(query: snapshot.query, scope: snapshot.scope)"
                ],
                "Sources/SpoonjoyCore/Cache/NativeDurableCache.swift": [
                    "case searchResults(SearchSurfaceCacheSnapshot)",
                    "/api/v1/search",
                    "case searchResults(query: String, scope: SearchScope)"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "search surface view model",
                    "SearchSurfaceViewModel",
                    "shopping-list search auth",
                    "cached search results",
                    "SearchSurfaceRequest"
                ]
            ],
            forbiddenTokens: [
                "Search is next.",
                "capture/import scope",
                "social-feed scope",
                "comments scope",
                "WKWebView",
                "MailCompose",
                "MessageComposer",
                "SearchResultRow.recipe(RecipeSearchSummary(recipe:",
                "recipes.map { recipe in"
            ]
        )

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("live search repository uses API v1 search and gates private shopping-list results")
    @MainActor
    func liveSearchRepositoryUsesAPIV1SearchAndGatesPrivateShoppingListResults() async throws {
        let privateData = SearchSurfaceData(
            query: "tomato",
            scope: .shoppingList,
            limit: 12,
            isAuthenticated: true,
            results: [Self.shoppingResult()]
        )
        let privateTransport = RecordingSearchAPITransport(envelope: APIEnvelope(requestID: "req_search_private", data: privateData))
        let privateRepository = LiveSearchSurfaceRepository(
            transport: privateTransport,
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )

        let page = try await privateRepository.search(
            request: SearchSurfaceRequest(query: "  tomato  ", scope: .shoppingList, limit: 12)
        )

        #expect(page.query == "tomato")
        #expect(page.scope == .shoppingList)
        #expect(page.limit == 12)
        #expect(page.isAuthenticated)
        #expect(page.results.map(\.id) == ["item_tomato_paste"])
        #expect(page.results.first?.type == .shoppingListItem)
        #expect(page.results.first?.openRoute == .shoppingList)
        #expect(page.source == .live(requestID: "req_search_private", validatedAt: Self.now))
        #expect(privateTransport.requests == [
            RecordedSearchRequest(
                method: .get,
                path: "/api/v1/search",
                queryItems: [
                    URLQueryItem(name: "q", value: "tomato"),
                    URLQueryItem(name: "scope", value: "shopping-list"),
                    URLQueryItem(name: "limit", value: "12")
                ],
                authorizationPolicy: .includeBearerToken,
                authorization: "Bearer sj_private_token",
                responseCachePolicy: .privateNoStore
            )
        ])

        let scopeSpecs: [(scope: SearchScope, expectedScope: String, result: SearchSurfaceResult, authorizationPolicy: APIAuthorizationPolicy, authorization: String?, responseCachePolicy: APIResponseCachePolicy?)] = [
            (.all, "all", Self.recipeResult(), .includeBearerToken, "Bearer sj_private_token", .privateNoStore),
            (.recipes, "recipes", Self.recipeResult(), .omit, nil, .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)),
            (.cookbooks, "cookbooks", Self.cookbookResult(), .omit, nil, .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300)),
            (.chefs, "chefs", Self.chefResult(), .omit, nil, .publicCache(maxAgeSeconds: 60, staleWhileRevalidateSeconds: 300))
        ]
        for spec in scopeSpecs {
            let transport = RecordingSearchAPITransport(envelope: APIEnvelope(
                requestID: "req_search_\(spec.expectedScope)",
                data: SearchSurfaceData(
                    query: "tomato",
                    scope: spec.scope,
                    limit: 7,
                    isAuthenticated: spec.authorization != nil,
                    results: [spec.result]
                )
            ))
            let repository = LiveSearchSurfaceRepository(
                transport: transport,
                configuration: Self.configuration,
                context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
                now: { Self.now }
            )

            let scopedPage = try await repository.search(
                request: SearchSurfaceRequest(query: "\n tomato\t", scope: spec.scope, limit: 7)
            )

            #expect(scopedPage.scope == spec.scope)
            #expect(scopedPage.results.map(\.id) == [spec.result.id])
            #expect(transport.requests == [
                RecordedSearchRequest(
                    method: .get,
                    path: "/api/v1/search",
                    queryItems: [
                        URLQueryItem(name: "q", value: "tomato"),
                        URLQueryItem(name: "scope", value: spec.expectedScope),
                        URLQueryItem(name: "limit", value: "7")
                    ],
                    authorizationPolicy: spec.authorizationPolicy,
                    authorization: spec.authorization,
                    responseCachePolicy: spec.responseCachePolicy
                )
            ])
        }

        let anonymousTransport = RecordingSearchAPITransport(envelope: APIEnvelope(requestID: "req_unused", data: privateData))
        let anonymousRepository = LiveSearchSurfaceRepository(
            transport: anonymousTransport,
            configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!),
            context: SearchSurfaceContext(isAuthenticated: false, canReadShoppingList: false),
            now: { Self.now }
        )
        do {
            _ = try await anonymousRepository.search(
                request: SearchSurfaceRequest(query: "tomato", scope: .shoppingList, limit: 20)
            )
            Issue.record("Expected anonymous shopping-list search to require authentication")
        } catch let error as SearchSurfaceRepositoryError {
            #expect(error == .authenticationRequired(scope: .shoppingList))
        }
        #expect(anonymousTransport.requests.isEmpty)

        let missingScopeTransport = RecordingSearchAPITransport(envelope: APIEnvelope(requestID: "req_unused", data: privateData))
        let missingScopeRepository = LiveSearchSurfaceRepository(
            transport: missingScopeTransport,
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: false),
            now: { Self.now }
        )
        do {
            _ = try await missingScopeRepository.search(
                request: SearchSurfaceRequest(query: "tomato", scope: .shoppingList, limit: 20)
            )
            Issue.record("Expected shopping-list search to require shopping_list:read")
        } catch let error as SearchSurfaceRepositoryError {
            #expect(error == .authorizationRequired(scope: .shoppingList, requiredScope: "shopping_list:read"))
        }
        #expect(missingScopeTransport.requests.isEmpty)

        let authFailureTransport = ThrowingSearchAPITransport(error: APITransportError(
            kind: .apiError,
            requestID: "req_invalid_token",
            statusCode: 401,
            apiError: APIError(
                requestID: "req_invalid_token",
                code: "invalid_token",
                message: "Invalid API token",
                status: 401
            ),
            retryDecision: .refreshAuthentication
        ))
        let authFailureRepository = LiveSearchSurfaceRepository(
            transport: authFailureTransport,
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        do {
            _ = try await authFailureRepository.search(
                request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 999)
            )
            Issue.record("Expected invalid token search to surface authentication state")
        } catch let error as SearchSurfaceRepositoryError {
            #expect(error == .authenticationRequired(scope: .all))
        }
        #expect(authFailureTransport.requests.map(\.queryItems).first?.contains(URLQueryItem(name: "limit", value: "50")) == true)
    }

    @Test("search debounce cancels stale requests and does not schedule blank queries")
    func searchDebounceCancelsStaleRequestsAndDoesNotScheduleBlankQueries() {
        let policy = SearchSurfaceDebouncePolicy(delayMilliseconds: 350, defaultLimit: 20)
        let staleRequest = SearchSurfaceRequest(query: "tom", scope: .all, limit: 20)

        let decision = policy.plan(
            previous: SearchState(query: "tom", scope: .all),
            next: SearchState(query: "tomato", scope: .recipes),
            inFlight: staleRequest
        )

        #expect(decision == SearchSurfaceDebounceDecision(
            cancelsInFlightSearch: true,
            scheduledRequest: SearchSurfaceRequest(query: "tomato", scope: .recipes, limit: 20),
            delayMilliseconds: 350
        ))

        #expect(policy.plan(
            previous: SearchState(query: "tomato", scope: .recipes),
            next: SearchState(query: "tomato", scope: .recipes),
            inFlight: nil
        ) == SearchSurfaceDebounceDecision(
            cancelsInFlightSearch: false,
            scheduledRequest: nil,
            delayMilliseconds: 0
        ))

        let cappedPolicy = SearchSurfaceDebouncePolicy(delayMilliseconds: 350, defaultLimit: 999)
        #expect(cappedPolicy.plan(
            previous: SearchState(query: "tom", scope: .all),
            next: SearchState(query: "tomato", scope: .all),
            inFlight: nil
        ).scheduledRequest?.limit == 50)

        let blank = policy.plan(
            previous: SearchState(query: "tomato", scope: .recipes),
            next: SearchState(query: "   ", scope: .recipes),
            inFlight: decision.scheduledRequest
        )

        #expect(blank.cancelsInFlightSearch)
        #expect(blank.scheduledRequest == nil)
        #expect(blank.delayMilliseconds == 0)
    }

    @Test("search view model groups route outputs and keeps unsupported scopes out")
    func searchViewModelGroupsRouteOutputsAndKeepsUnsupportedScopesOut() throws {
        let page = SearchSurfacePage(
            query: "tomato",
            scope: .all,
            limit: 20,
            isAuthenticated: true,
            results: [
                Self.recipeResult(),
                Self.cookbookResult(),
                Self.chefResult(),
                Self.shoppingResult()
            ],
            source: .cache(serverRevision: .cursor("search-v1"), lastValidatedAt: Self.staleValidatedAt)
        )
        let viewModel = SearchSurfaceViewModel(
            page: page,
            state: SearchState(query: "tomato", scope: .all),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )

        #expect(viewModel.searchableScopes == [.all, .recipes, .cookbooks, .chefs, .shoppingList])
        #expect(viewModel.unsupportedScopes.isEmpty)
        #expect(viewModel.sections.map(\.kind) == [.recipes, .cookbooks, .chefs, .shoppingList])
        #expect(viewModel.sections.flatMap(\.rows).map(\.openRoute) == [
            .recipeDetail(id: "recipe_tomato_tart", presentation: .detail),
            .cookbookDetail(id: "cookbook_tomato"),
            .profile(identifier: "ari"),
            .shoppingList
        ])
        #expect(viewModel.offlineIndicator.display == .stale(domain: .searchResults(query: "tomato", scope: .all)))
        #expect(viewModel.emptyState == nil)

        let unauthenticatedShopping = SearchSurfaceViewModel(
            page: SearchSurfacePage(
                query: "tomato",
                scope: .shoppingList,
                limit: 20,
                isAuthenticated: false,
                results: [],
                source: .live(requestID: "req_search_empty", validatedAt: Self.now)
            ),
            state: SearchState(query: "tomato", scope: .shoppingList),
            context: SearchSurfaceContext(isAuthenticated: false, canReadShoppingList: false),
            now: { Self.now }
        )
        #expect(unauthenticatedShopping.emptyState == SearchSurfaceEmptyState(
            title: "Sign in to search your shopping list",
            message: "Shopping-list matches are private to your Spoonjoy account.",
            systemImage: "lock"
        ))

        let failedSearch = SearchSurfaceViewModel(
            error: .searchFailed(message: "Spoonjoy search is offline."),
            state: SearchState(query: "tomato", scope: .all),
            cachedPage: nil,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        #expect(failedSearch.errorState == SearchSurfaceErrorState(
            title: "Search could not load",
            message: "Spoonjoy search is offline.",
            systemImage: "wifi.exclamationmark"
        ))
        #expect(failedSearch.offlineIndicator.display == .syncFailure(errorID: "search-all", retryAfter: nil))

        let offlineSearch = SearchSurfaceViewModel(
            error: .offline,
            state: SearchState(query: "tomato", scope: .all),
            cachedPage: nil,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        #expect(offlineSearch.offlineIndicator.display == .offline)

        let cancelledSearch = SearchSurfaceViewModel(
            error: .cancelled,
            state: SearchState(query: "tomato", scope: .all),
            cachedPage: nil,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        #expect(cancelledSearch.offlineIndicator.display == .synced)

        let liveCachedOfflineSearch = SearchSurfaceViewModel(
            error: .offline,
            state: SearchState(query: "tomato", scope: .all),
            cachedPage: SearchSurfacePage(
                query: "tomato",
                scope: .all,
                limit: 20,
                isAuthenticated: true,
                results: [Self.recipeResult()],
                source: .live(requestID: "req_previous_search", validatedAt: Self.now)
            ),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        #expect(liveCachedOfflineSearch.sections.flatMap(\.rows).map(\.result.id) == ["recipe_tomato_tart"])
        #expect(liveCachedOfflineSearch.offlineIndicator.display == .offline)
    }

    @Test("snapshot and fallback search restore cached results without leaking private shopping rows")
    @MainActor
    func snapshotAndFallbackSearchRestoreCachedResultsWithoutLeakingPrivateShoppingRows() async throws {
        let snapshot = SearchSurfaceCacheSnapshot(
            accountID: "chef_ari",
            environment: .production,
            query: "tomato",
            scope: .all,
            limit: 20,
            results: [Self.recipeResult(), Self.shoppingResult()],
            recentSearches: [
                SearchSurfaceRecentQuery(query: "tomato", scope: .all, lastSearchedAt: Self.staleValidatedAt)
            ],
            serverRevision: .cursor("search-v1"),
            lastValidatedAt: Self.staleValidatedAt
        )
        let repository = SnapshotSearchSurfaceRepository(
            snapshot: snapshot,
            currentAccountID: "chef_jules",
            environment: .production,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )

        let restored = try await repository.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))

        #expect(restored.results.map(\.id) == ["recipe_tomato_tart"])
        #expect(restored.results.contains { $0.type == .shoppingListItem } == false)
        #expect(restored.offlineIndicator(now: Self.now).display == .stale(domain: .searchResults(query: "tomato", scope: .all)))

        #expect(try await repository.recentSearches(limit: 5) == [
            SearchSurfaceRecentQuery(query: "tomato", scope: .all, lastSearchedAt: Self.staleValidatedAt)
        ])

        let fallback = FallbackSearchSurfaceRepository(
            primary: StubSearchSurfaceRepository(result: .failure(SearchSurfaceRepositoryError.offline)),
            fallback: StubSearchSurfaceRepository(result: .success(restored))
        )
        let fallbackPage = try await fallback.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
        #expect(fallbackPage.results.map(\.id) == ["recipe_tomato_tart"])
        #expect(fallbackPage.offlineIndicator(now: Self.now).display == .offline)
    }

    @Test("shell search state preserves severe indicators and unbound session identity")
    func shellSearchStatePreservesSevereIndicatorsAndUnboundSessionIdentity() throws {
        let unboundSession = try AuthSession(
            clientID: "client_unbound_a",
            accessToken: "sj_access_unbound_a",
            refreshToken: "sj_refresh_unbound_a",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope
        )
        let otherUnboundSession = try AuthSession(
            clientID: "client_unbound_b",
            accessToken: "sj_access_unbound_b",
            refreshToken: "sj_refresh_unbound_b",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope
        )
        let severeContent = NativeShellContentState.empty(
            authSessionState: .authenticated(unboundSession),
            environment: .production,
            configuration: Self.configuration,
            offlineIndicatorState: OfflineIndicatorState(
                display: .queuedWork(count: 1, oldestClientMutationID: "cm_search"),
                dismissal: nil
            )
        ).copy(searchSurfaceSnapshots: [
            SearchSurfaceCacheSnapshot(
                accountID: "unbound:client_unbound_a",
                environment: .production,
                query: "tomato",
                scope: .all,
                limit: 20,
                results: [Self.recipeResult(), Self.shoppingResult()],
                recentSearches: [],
                serverRevision: .cursor("search-unbound"),
                lastValidatedAt: Self.staleValidatedAt
            )
        ])
        let otherContent = NativeShellContentState.empty(
            authSessionState: .authenticated(otherUnboundSession),
            environment: .production,
            configuration: Self.configuration,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        let syncedSameAccount = severeContent.copy(offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil))

        #expect(severeContent.searchSurfaceIdentity.contains("unbound:client_unbound_a"))
        #expect(otherContent.searchSurfaceIdentity.contains("unbound:client_unbound_b"))
        #expect(severeContent.searchSurfaceIdentity != otherContent.searchSurfaceIdentity)
        #expect(severeContent.searchSurfaceIdentity != syncedSameAccount.searchSurfaceIdentity)

        let viewModel = severeContent.performSearch(SearchState(query: "tomato", scope: .all))
        #expect(viewModel.sections.flatMap(\.rows).map(\.result.id) == ["recipe_tomato_tart"])
        #expect(viewModel.offlineIndicator.display == .queuedWork(count: 1, oldestClientMutationID: "cm_search"))
    }

    private static func recipeResult() -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: .recipe,
            id: "recipe_tomato_tart",
            ownerID: "chef_ari",
            ownerUsername: "ari",
            title: "Tomato Tart",
            subtitle: "Recipe by ari",
            snippet: "tomato tart with herbs",
            href: "/recipes/recipe_tomato_tart",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_tomato_tart")!,
            imageURL: URL(string: "https://spoonjoy.app/photos/tomato-tart.jpg"),
            score: -1.25,
            metadata: [
                "servings": .string("Serves 4"),
                "chefUsername": .string("ari")
            ]
        )
    }

    private static func cookbookResult() -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: .cookbook,
            id: "cookbook_tomato",
            ownerID: "chef_ari",
            ownerUsername: "ari",
            title: "Tomato Weeknights",
            subtitle: "Cookbook by ari",
            snippet: "tomato dinners",
            href: "/cookbooks/cookbook_tomato",
            canonicalURL: URL(string: "https://spoonjoy.app/cookbooks/cookbook_tomato")!,
            imageURL: nil,
            score: -0.75,
            metadata: ["recipeCount": .number(3)]
        )
    }

    private static func chefResult() -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: .chef,
            id: "chef_ari",
            ownerID: "chef_ari",
            ownerUsername: "ari",
            title: "ari",
            subtitle: "Chef",
            snippet: "ari cooks tomato dinners",
            href: "/users/ari",
            canonicalURL: URL(string: "https://spoonjoy.app/users/ari")!,
            imageURL: nil,
            score: -0.5,
            metadata: [:]
        )
    }

    private static func shoppingResult() -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: .shoppingListItem,
            id: "item_tomato_paste",
            ownerID: "chef_ari",
            ownerUsername: "ari",
            title: "tomato paste",
            subtitle: "Shopping list",
            snippet: "tomato paste in pantry",
            href: "/shopping-list",
            canonicalURL: URL(string: "https://spoonjoy.app/shopping-list")!,
            imageURL: nil,
            score: -0.25,
            metadata: [
                "checked": .bool(false),
                "categoryKey": .string("pantry")
            ]
        )
    }
}

private struct RecordedSearchRequest: Equatable {
    let method: APIRequestMethod
    let path: String
    let queryItems: [URLQueryItem]
    let authorizationPolicy: APIAuthorizationPolicy
    let authorization: String?
    let responseCachePolicy: APIResponseCachePolicy?
}

private final class RecordingSearchAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    private let envelope: APIEnvelope<SearchSurfaceData>
    private(set) var requests: [RecordedSearchRequest] = []

    init(envelope: APIEnvelope<SearchSurfaceData>) {
        self.envelope = envelope
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let apiRequest = try request.urlRequest(configuration: configuration)
        requests.append(RecordedSearchRequest(
            method: apiRequest.method,
            path: apiRequest.url.path,
            queryItems: apiRequest.url.queryItems,
            authorizationPolicy: request.defaultAuthorization,
            authorization: apiRequest.headers["Authorization"],
            responseCachePolicy: apiRequest.responseCachePolicy
        ))
        return APIEnvelope(requestID: envelope.requestID, data: try #require(envelope.data as? Value))
    }
}

private final class ThrowingSearchAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    let error: APITransportError
    private(set) var requests: [RecordedSearchRequest] = []

    init(error: APITransportError) {
        self.error = error
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let apiRequest = try request.urlRequest(configuration: configuration)
        requests.append(RecordedSearchRequest(
            method: apiRequest.method,
            path: apiRequest.url.path,
            queryItems: apiRequest.url.queryItems,
            authorizationPolicy: request.defaultAuthorization,
            authorization: apiRequest.headers["Authorization"],
            responseCachePolicy: apiRequest.responseCachePolicy
        ))
        throw error
    }
}

private struct StubSearchSurfaceRepository: SearchSurfaceRepository {
    let result: Result<SearchSurfacePage, SearchSurfaceRepositoryError>

    func search(request _: SearchSurfaceRequest) async throws -> SearchSurfacePage {
        try result.get()
    }

    func recentSearches(limit _: Int) async throws -> [SearchSurfaceRecentQuery] {
        []
    }
}

private func sourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? readRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = uncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: [.regularExpression])
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: [.regularExpression])
}
