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
                    ".navigationTitle(\"Search\")",
                    "searchTask",
                    "debounce",
                    "SPOONJOY_SCREENSHOT_PROOF_PATH",
                    "SPOONJOY_SCREENSHOT_ACCOUNT_ID",
                    "writeScreenshotProofIfNeeded",
                    "\"source\": \"SearchView\"",
                    "\"routeIdentifier\"",
                    "\"searchScopes\"",
                    "ISO8601DateFormatter"
                ],
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift": [
                    "@FocusState private var isSearchFieldFocused",
                    "contentState.searchSurfaceViewModel",
                    "performSearch(",
                    "SearchView(",
                    ".searchFocused($isSearchFieldFocused)",
                    "isSearchFieldFocused = true",
                    "SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS",
                    "shouldAutoFocusSearchField",
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

        let cachedOfflineSearch = SearchSurfaceViewModel(
            error: .offline,
            state: SearchState(query: "tomato", scope: .all),
            cachedPage: SearchSurfacePage(
                query: "tomato",
                scope: .all,
                limit: 20,
                isAuthenticated: true,
                results: [Self.recipeResult()],
                source: .cache(serverRevision: .cursor("cached-search"), lastValidatedAt: Self.staleValidatedAt)
            ),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        #expect(cachedOfflineSearch.offlineIndicator.display == .offline)

        let authenticationFailure = SearchSurfaceViewModel(
            error: .authenticationRequired(scope: .shoppingList),
            state: SearchState(query: "tomato", scope: .shoppingList),
            cachedPage: nil,
            context: SearchSurfaceContext(isAuthenticated: false, canReadShoppingList: false),
            now: { Self.now }
        )
        #expect(authenticationFailure.errorState?.message == "Sign in to search private Spoonjoy results.")

        let authorizationFailure = SearchSurfaceViewModel(
            error: .authorizationRequired(scope: .shoppingList, requiredScope: "shopping_list:read"),
            state: SearchState(query: "tomato", scope: .shoppingList),
            cachedPage: nil,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: false),
            now: { Self.now }
        )
        #expect(authorizationFailure.errorState?.message == "Your token needs shopping_list:read to search private shopping-list matches.")

        let noQueryEmpty = SearchSurfaceViewModel(
            page: SearchSurfacePage(
                query: "",
                scope: .all,
                limit: 20,
                isAuthenticated: true,
                results: [],
                source: .live(requestID: "req_search_empty_start", validatedAt: Self.now)
            ),
            state: SearchState(),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        #expect(noQueryEmpty.emptyState == SearchSurfaceEmptyState(
            title: "Search Spoonjoy",
            message: "Recipes, cookbooks, chefs, and shopping list items will gather here.",
            systemImage: "magnifyingglass"
        ))

        let noMatches = SearchSurfaceViewModel(
            page: SearchSurfacePage(
                query: "kumquat",
                scope: .recipes,
                limit: 20,
                isAuthenticated: true,
                results: [],
                source: .live(requestID: "req_search_no_matches", validatedAt: Self.now)
            ),
            state: SearchState(query: "kumquat", scope: .recipes),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            now: { Self.now }
        )
        #expect(noMatches.emptyState == SearchSurfaceEmptyState(
            title: "No matches",
            message: "Try another recipe, cookbook, chef, or shopping item.",
            systemImage: "magnifyingglass"
        ))

        let scopedRecipesWithDefaultClock = SearchSurfaceViewModel(
            page: page,
            state: SearchState(query: "tomato", scope: .recipes),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        #expect(scopedRecipesWithDefaultClock.sections.flatMap(\.rows).map(\.result.type) == [.recipe])

        let authorizedButMissingShoppingScope = SearchSurfaceViewModel(
            page: SearchSurfacePage(
                query: "tomato",
                scope: .shoppingList,
                limit: 20,
                isAuthenticated: true,
                results: [],
                source: .live(requestID: "req_search_forbidden", validatedAt: Self.now)
            ),
            state: SearchState(query: "tomato", scope: .shoppingList),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: false)
        )
        #expect(authorizedButMissingShoppingScope.emptyState?.systemImage == "lock")

        let failedWithDefaultClock = SearchSurfaceViewModel(
            error: .searchFailed(message: "default clock failure"),
            state: SearchState(query: "tomato", scope: .all),
            cachedPage: nil,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        #expect(failedWithDefaultClock.errorState?.message == "default clock failure")

        let cachedOfflineWithDefaultClock = SearchSurfaceViewModel(
            error: .offline,
            state: SearchState(query: "tomato", scope: .all),
            cachedPage: SearchSurfacePage(
                query: "tomato",
                scope: .all,
                limit: 20,
                isAuthenticated: true,
                results: [Self.recipeResult()],
                source: .cache(serverRevision: .cursor("cached-default-clock"), lastValidatedAt: Self.staleValidatedAt)
            ),
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        #expect(cachedOfflineWithDefaultClock.offlineIndicator.display == .offline)
    }

    @Test("search rows expose stable native labels icons and fallback subtitles")
    func searchRowsExposeStableNativeLabelsIconsAndFallbackSubtitles() {
        let sections = SearchScope.allCases.map { SearchSurfaceSection(kind: $0, rows: []) }
        #expect(sections.map(\.id) == SearchScope.allCases)
        #expect(sections.map(\.title) == ["All", "Recipes", "Cookbooks", "Chefs", "Shopping"])

        let sparseRecipe = SearchSurfaceResult(
            type: .recipe,
            id: "recipe_sparse",
            ownerID: "chef_sparse",
            ownerUsername: nil,
            title: "Sparse Toast",
            subtitle: nil,
            snippet: "crisp bread",
            href: "/recipes/recipe_sparse",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_sparse")!,
            imageURL: URL(string: "https://spoonjoy.app/photos/sparse-toast.jpg"),
            score: 0,
            metadata: [:]
        )
        let rows = [
            SearchSurfaceRow(result: sparseRecipe),
            SearchSurfaceRow(result: Self.cookbookResult()),
            SearchSurfaceRow(result: SearchSurfaceResult(
                type: .chef,
                id: "chef_no_username",
                ownerID: "chef_no_username",
                ownerUsername: nil,
                title: "Guest Chef",
                subtitle: nil,
                snippet: nil,
                href: "/users/guest-chef",
                canonicalURL: URL(string: "https://spoonjoy.app/users/guest-chef")!,
                imageURL: nil,
                score: 0,
                metadata: [:]
            )),
            SearchSurfaceRow(result: Self.shoppingResult())
        ]

        #expect(rows.map(\.id) == ["recipe-recipe_sparse", "cookbook-cookbook_tomato", "chef-chef_no_username", "shopping-list-item-item_tomato_paste"])
        #expect(rows.map(\.subtitle) == ["crisp bread", "Cookbook by ari", "", "Shopping list"])
        #expect(rows.map(\.systemImage) == ["book.closed", "books.vertical", "person.crop.circle", "cart"])
        #expect(rows[0].imageURL == URL(string: "https://spoonjoy.app/photos/sparse-toast.jpg"))
        #expect(rows[0].accessibilityLabel == "Recipe, Sparse Toast, crisp bread")
        #expect(rows[1].accessibilityLabel == "Cookbook, Tomato Weeknights, Cookbook by ari")
        #expect(rows[2].accessibilityLabel == "Chef, Guest Chef")
        #expect(rows[3].accessibilityLabel == "Shopping item, tomato paste, Shopping list")
        #expect(rows.map(\.openRoute) == [
            .recipeDetail(id: "recipe_sparse", presentation: .detail),
            .cookbookDetail(id: "cookbook_tomato"),
            .profile(identifier: "Guest Chef"),
            .shoppingList
        ])
        #expect(rows.map(\.result.openRoute) == rows.map(\.openRoute))
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
        #expect(snapshot.page(
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            currentAccountID: "chef_ari"
        ).source == .cache(serverRevision: .cursor("search-v1"), lastValidatedAt: Self.staleValidatedAt))

        #expect(try await repository.recentSearches(limit: 5) == [
            SearchSurfaceRecentQuery(query: "tomato", scope: .all, lastSearchedAt: Self.staleValidatedAt)
        ])

        let fallback = FallbackSearchSurfaceRepository(
            primary: StubSearchSurfaceRepository(
                result: .failure(SearchSurfaceRepositoryError.offline),
                recentSearchResult: .failure(.offline)
            ),
            fallback: StubSearchSurfaceRepository(
                result: .success(restored),
                recentSearchResult: .success(snapshot.recentSearches)
            )
        )
        let fallbackPage = try await fallback.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
        #expect(fallbackPage.results.map(\.id) == ["recipe_tomato_tart"])
        #expect(fallbackPage.offlineIndicator(now: Self.now).display == .offline)

        #expect(try await fallback.recentSearches(limit: 1) == snapshot.recentSearches)

        let primaryRecent = FallbackSearchSurfaceRepository(
            primary: StubSearchSurfaceRepository(
                result: .success(restored),
                recentSearchResult: .success([SearchSurfaceRecentQuery(query: "primary", scope: .recipes, lastSearchedAt: Self.now)])
            ),
            fallback: StubSearchSurfaceRepository(
                result: .success(restored),
                recentSearchResult: .success(snapshot.recentSearches)
            )
        )
        #expect(try await primaryRecent.recentSearches(limit: 1).map(\.query) == ["primary"])

        do {
            _ = try await repository.search(request: SearchSurfaceRequest(query: "wrong", scope: .all, limit: 20))
            Issue.record("Expected mismatched snapshot query to fail offline")
        } catch let error as SearchSurfaceRepositoryError {
            #expect(error == .offline)
        }

        let matchingSnapshotRepository = SnapshotSearchSurfaceRepository(
            snapshot: snapshot,
            currentAccountID: "chef_ari",
            environment: .production,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        let matching = try await matchingSnapshotRepository.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
        #expect(matching.results.map(\.id) == ["recipe_tomato_tart", "item_tomato_paste"])
        #expect(try await matchingSnapshotRepository.recentSearches(limit: -1).isEmpty)
    }

    @Test("search repositories preserve recent queries and map every API error shape")
    @MainActor
    func searchRepositoriesPreserveRecentQueriesAndMapEveryAPIErrorShape() async throws {
        let memory = SearchSurfaceRecentSearchMemory()
        let repository = LiveSearchSurfaceRepository(
            transport: RecordingSearchAPITransport(envelope: APIEnvelope(
                requestID: "req_recent",
                data: SearchSurfaceData(
                    query: "tomato",
                    scope: .recipes,
                    limit: 20,
                    isAuthenticated: false,
                    results: [Self.recipeResult()]
                )
            )),
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true),
            recentSearchMemory: memory,
            now: { Self.now }
        )
        _ = try await repository.search(request: SearchSurfaceRequest(query: "tomato", scope: .recipes, limit: 20))
        #expect(try await repository.recentSearches(limit: 2) == [
            SearchSurfaceRecentQuery(query: "tomato", scope: .recipes, lastSearchedAt: Self.now)
        ])
        await memory.record(SearchSurfaceRecentQuery(query: "tomato", scope: .recipes, lastSearchedAt: Self.now.addingTimeInterval(10)))
        await memory.record(SearchSurfaceRecentQuery(query: "beans", scope: .all, lastSearchedAt: Self.now.addingTimeInterval(20)))
        #expect(await memory.recentSearches(limit: 5).map(\.query) == ["beans", "tomato"])

        let defaultClockRepository = LiveSearchSurfaceRepository(
            transport: RecordingSearchAPITransport(envelope: APIEnvelope(
                requestID: "req_default_clock",
                data: SearchSurfaceData(
                    query: "tomato",
                    scope: .recipes,
                    limit: 20,
                    isAuthenticated: false,
                    results: [Self.recipeResult()]
                )
            )),
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        #expect(try await defaultClockRepository.search(
            request: SearchSurfaceRequest(query: "tomato", scope: .recipes, limit: 20)
        ).results.map(\.id) == ["recipe_tomato_tart"])

        let passthroughRepository = LiveSearchSurfaceRepository(
            transport: RepositoryErrorSearchAPITransport(error: SearchSurfaceRepositoryError.cancelled),
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        do {
            _ = try await passthroughRepository.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
            Issue.record("Expected repository errors to pass through")
        } catch let error as SearchSurfaceRepositoryError {
            #expect(error == .cancelled)
        }

        let transportErrorCases: [(kind: APITransportErrorKind, expected: SearchSurfaceRepositoryError)] = [
            (.offline, .offline),
            (.cancelled, .cancelled)
        ]
        for errorCase in transportErrorCases {
            let failingRepository = LiveSearchSurfaceRepository(
                transport: ThrowingSearchAPITransport(error: APITransportError(
                    kind: errorCase.kind,
                    requestID: nil,
                    statusCode: nil,
                    apiError: nil,
                    retryDecision: .doNotRetry
                )),
                configuration: Self.configuration,
                context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
            )

            do {
                _ = try await failingRepository.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
                Issue.record("Expected \(errorCase.kind) to map to a search error")
            } catch let error as SearchSurfaceRepositoryError {
                #expect(error == errorCase.expected)
            }
        }

        let transportFailureRepository = LiveSearchSurfaceRepository(
            transport: ThrowingSearchAPITransport(error: APITransportError(
                kind: .networkFailure,
                requestID: "req_network_failure",
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            )),
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        do {
            _ = try await transportFailureRepository.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
            Issue.record("Expected network transport failures to map to search failure")
        } catch let error as SearchSurfaceRepositoryError {
            guard case .searchFailed(let message) = error else {
                Issue.record("Expected searchFailed for network failure; got \(error)")
                return
            }
            #expect(message.contains("networkFailure"))
        }

        let apiErrorCases: [(code: String, message: String, expected: SearchSurfaceRepositoryError)] = [
            ("authentication_required", "Sign in", .authenticationRequired(scope: .all)),
            ("invalid_token", "Invalid token", .authenticationRequired(scope: .all)),
            ("insufficient_scope", "Missing scope", .authorizationRequired(scope: .all, requiredScope: "shopping_list:read")),
            ("search_backend_down", "Search backend down", .searchFailed(message: "Search backend down"))
        ]
        for apiCase in apiErrorCases {
            let transport = ThrowingSearchAPITransport(error: APITransportError(
                kind: .apiError,
                requestID: "req_\(apiCase.code)",
                statusCode: apiCase.code == "insufficient_scope" ? 403 : 500,
                apiError: APIError(
                    requestID: "req_\(apiCase.code)",
                    code: apiCase.code,
                    message: apiCase.message,
                    status: apiCase.code == "insufficient_scope" ? 403 : 500
                ),
                retryDecision: .doNotRetry
            ))
            let failingRepository = LiveSearchSurfaceRepository(
                transport: transport,
                configuration: Self.configuration,
                context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
            )

            do {
                _ = try await failingRepository.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
                Issue.record("Expected \(apiCase.code) to map to a search error")
            } catch let error as SearchSurfaceRepositoryError {
                #expect(error == apiCase.expected)
            }
        }

        let genericFailureRepository = LiveSearchSurfaceRepository(
            transport: UnexpectedSearchFailureTransport(),
            configuration: Self.configuration,
            context: SearchSurfaceContext(isAuthenticated: true, canReadShoppingList: true)
        )
        do {
            _ = try await genericFailureRepository.search(request: SearchSurfaceRequest(query: "tomato", scope: .all, limit: 20))
            Issue.record("Expected generic failures to map to a search failure")
        } catch let error as SearchSurfaceRepositoryError {
            #expect(error == .searchFailed(message: "unexpected"))
        }
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

    @Test("shell search state covers live cache scopes and severe identity branches")
    func shellSearchStateCoversLiveCacheScopesAndSevereIdentityBranches() throws {
        let session = try AuthSession(
            clientID: "client_search",
            accessToken: "sj_access_search",
            refreshToken: "sj_refresh_search",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        )
        let emptyAccountSession = try AuthSession(
            clientID: "client_empty_account",
            accessToken: "sj_access_empty",
            refreshToken: "sj_refresh_empty",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope,
            accountID: ""
        )
        let recipe = try #require(RecipeFixtureCatalog.decodeFromBundle().recipes.first)
        let cookbook = try #require(CookbookFixtureCatalog.decodeFromBundle().cookbooks.first)
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let content = NativeShellContentState.empty(
            authSessionState: .authenticated(session),
            environment: .production,
            configuration: Self.configuration,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        ).copy(
            recipes: [recipe],
            cookbooks: [cookbook],
            shoppingList: shoppingList
        )

        #expect(emptyAccountSession.accountID == nil)
        #expect(content.searchSurfaceContext.canReadShoppingList)
        #expect(content.searchSurfaceViewModel.sections.flatMap(\.rows).contains { $0.result.type == .shoppingListItem })
        let livePage = content.searchSurfacePage(for: SearchState(query: "lemon", scope: .recipes))
        #expect(livePage.source == .live(
            requestID: "native-shell-search",
            validatedAt: livePage.source.validatedAtForTesting
        ))

        let recipeOnly = content.performSearch(SearchState(query: "", scope: .recipes))
        #expect(recipeOnly.sections.map(\.kind) == [.recipes])
        let cookbookOnly = content.performSearch(SearchState(query: "weeknight", scope: .cookbooks))
        #expect(cookbookOnly.sections.map(\.kind) == [.cookbooks])
        let shoppingOnly = content.performSearch(SearchState(query: "lemon", scope: .shoppingList))
        #expect(shoppingOnly.sections.flatMap(\.rows).allSatisfy { $0.result.type == .shoppingListItem })

        let recipeWithoutDescription = Recipe(
            id: "recipe_no_description",
            title: "No Description Pasta",
            description: nil,
            servings: recipe.servings,
            chef: recipe.chef,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: "/recipes/recipe_no_description",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_no_description")!,
            attribution: recipe.attribution,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            steps: recipe.steps,
            cookbooks: recipe.cookbooks
        )
        let oneRecipeCookbook = Cookbook(
            id: "cookbook_one_recipe",
            title: "One Recipe",
            chef: cookbook.chef,
            recipeCount: 1,
            cover: cookbook.cover,
            href: "/cookbooks/cookbook_one_recipe",
            canonicalURL: URL(string: "https://spoonjoy.app/cookbooks/cookbook_one_recipe")!,
            attribution: cookbook.attribution,
            createdAt: cookbook.createdAt,
            updatedAt: cookbook.updatedAt,
            recipes: Array(cookbook.recipes.prefix(1))
        )
        let sparseShoppingList = ShoppingListState(
            id: "shopping_sparse",
            chef: shoppingList.chef,
            items: [
                ShoppingListItem(
                    id: "item_sparse",
                    name: "salt",
                    quantity: nil,
                    unit: nil,
                    checked: false,
                    checkedAt: nil,
                    deletedAt: nil,
                    categoryKey: nil,
                    iconKey: nil,
                    sortIndex: 0,
                    updatedAt: "2026-06-16T15:00:00.000Z"
                )
            ],
            nextCursor: "",
            updatedAt: "2026-06-16T15:00:00.000Z"
        )
        let sparseContent = NativeShellContentState.empty(
            authSessionState: .authenticated(session),
            environment: .production,
            configuration: Self.configuration,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        ).copy(
            recipes: [recipeWithoutDescription],
            cookbooks: [oneRecipeCookbook],
            shoppingList: sparseShoppingList
        )
        let sparseRows = sparseContent.performSearch(SearchState(query: "", scope: .all)).sections.flatMap { $0.rows }
        #expect(sparseRows.first { $0.result.id == "recipe_no_description" }?.subtitle == "Recipe by \(recipe.chef.username)")
        #expect(sparseRows.first { $0.result.id == "cookbook_one_recipe" }?.subtitle == "1 recipe")
        #expect(sparseRows.first { $0.result.id == "item_sparse" }?.subtitle == "Shopping list")
        #expect(sparseRows.first { $0.result.id == "item_sparse" }?.result.metadata["categoryKey"] == JSONValue.null)

        let noShoppingContent = NativeShellContentState.empty(
            authSessionState: .authenticated(session),
            environment: .production,
            configuration: Self.configuration,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        ).copy(recipes: [recipe], cookbooks: [cookbook])
        #expect(noShoppingContent.performSearch(SearchState(query: "", scope: .shoppingList)).sections.isEmpty)
        let signedOutContent = NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: Self.configuration,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        #expect(signedOutContent.performSearch(SearchState(query: "", scope: .shoppingList)).sections.isEmpty)

        let offlineContent = content.copy(offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil))
        #expect(offlineContent.searchSurfacePage(for: SearchState(query: "lemon", scope: .all)).offlineIndicator(now: Self.now).display == .stale(
            domain: .searchResults(query: "lemon", scope: .all)
        ))

        let explicitPage = SearchSurfacePage(
            query: "lemon",
            scope: .all,
            limit: 20,
            isAuthenticated: true,
            results: [Self.recipeResult()],
            source: .cache(serverRevision: .cursor("explicit"), lastValidatedAt: Self.staleValidatedAt)
        )
        #expect(content.performSearch(page: explicitPage, state: SearchState(query: "lemon", scope: .all)).sections.flatMap(\.rows).map(\.result.id) == ["recipe_tomato_tart"])
        #expect(content.performSearch(error: .searchFailed(message: "boom"), state: SearchState(query: "lemon", scope: .all), cachedPage: explicitPage).errorState?.message == "boom")

        let severeDisplays: [OfflineIndicatorDisplay] = [
            .queuedWork(count: 2, oldestClientMutationID: nil),
            .syncFailure(errorID: "search-failed", retryAfter: .seconds(5)),
            .conflict(recordID: "recipe_1", mutationID: "cm_conflict"),
            .blocker(.providerSecret(resourceID: "import_1")),
            .destructiveConfirmation(actionID: "clear-all")
        ]
        for display in severeDisplays {
            let severe = content.copy(offlineIndicatorState: OfflineIndicatorState(display: display, dismissal: nil))
            #expect(severe.searchSurfaceIdentity != content.searchSurfaceIdentity)
        }

        let restoredSearchSnapshot = SearchSurfaceCacheSnapshot(
            accountID: "chef_ari",
            environment: .production,
            query: "lemon",
            scope: .recipes,
            limit: 20,
            results: [Self.recipeResult()],
            recentSearches: [SearchSurfaceRecentQuery(query: "lemon", scope: .recipes, lastSearchedAt: Self.staleValidatedAt)],
            serverRevision: .cursor("search-restore"),
            lastValidatedAt: Self.staleValidatedAt
        )
        let restoredDomain = NativeCacheDomain.searchResults(query: "lemon", scope: .recipes)
        let restoredRecord = try NativeCacheRecord(
            id: restoredDomain.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: "chef_ari",
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: restoredDomain,
                fetchedAt: Self.staleValidatedAt,
                lastValidatedAt: Self.staleValidatedAt,
                sourceEndpoint: "/api/v1/search",
                serverRevision: .cursor("search-restore")
            ),
            payload: .searchResults(restoredSearchSnapshot)
        )
        let restoredContent = try NativeShellContentState.restored(
            cacheSnapshot: NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_ari",
                environment: .production,
                createdAt: Self.staleValidatedAt,
                records: [restoredRecord],
                dismissedIndicators: []
            ),
            syncSnapshot: .empty,
            appSnapshot: nil,
            authSessionState: .authenticated(session),
            configuration: Self.configuration,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
        #expect(restoredContent.performSearch(SearchState(query: "lemon", scope: .recipes)).sections.flatMap(\.rows).map(\.result.id) == ["recipe_tomato_tart"])
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
    var recentSearchResult: Result<[SearchSurfaceRecentQuery], SearchSurfaceRepositoryError> = .success([])

    func search(request _: SearchSurfaceRequest) async throws -> SearchSurfacePage {
        try result.get()
    }

    func recentSearches(limit _: Int) async throws -> [SearchSurfaceRecentQuery] {
        try recentSearchResult.get()
    }
}

private struct RepositoryErrorSearchAPITransport: SpoonjoyAPITransport {
    let error: SearchSurfaceRepositoryError

    func send<Value: Decodable & Equatable>(
        _: APIRequestBuilder,
        configuration _: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        throw error
    }
}

private struct UnexpectedSearchFailureTransport: SpoonjoyAPITransport {
    func send<Value: Decodable & Equatable>(
        _: APIRequestBuilder,
        configuration _: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        throw SearchTestError.unexpected
    }
}

private enum SearchTestError: Error, CustomStringConvertible {
    case unexpected

    var description: String {
        "unexpected"
    }
}

private extension SearchSurfaceDataSource {
    var validatedAtForTesting: Date {
        switch self {
        case .live(_, let validatedAt), .cache(_, let validatedAt), .offlineCache(_, let validatedAt):
            validatedAt
        }
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
