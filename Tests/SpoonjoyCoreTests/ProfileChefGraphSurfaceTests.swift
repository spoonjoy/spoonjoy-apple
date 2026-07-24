import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native profile and chef graph surface parity")
struct ProfileChefGraphSurfaceTests {
    private static let now = Date(timeIntervalSince1970: 1_780_124_400)
    private static let staleValidatedAt = Date(timeIntervalSince1970: 1_779_950_000)
    private static let createdAt = "2026-06-27T23:00:00.000Z"
    private static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("profile repository loads live profile and derived graph pages from public API v1")
    @MainActor
    func profileRepositoryLoadsLiveProfileAndDerivedGraphPages() async throws {
        let profileEnvelope = try APIEnvelope(requestID: "req_profile", data: Self.profileData())
        let fellowChefsEnvelope = try APIEnvelope(requestID: "req_fellow_chefs", data: Self.graphPage(direction: .fellowChefs))
        let kitchenVisitorsEnvelope = try APIEnvelope(requestID: "req_kitchen_visitors", data: Self.graphPage(direction: .kitchenVisitors))
        let transport = RecordingProfileAPITransport(
            profileEnvelope: profileEnvelope,
            fellowChefsEnvelope: fellowChefsEnvelope,
            kitchenVisitorsEnvelope: kitchenVisitorsEnvelope
        )
        let repository = LiveProfileChefGraphSurfaceRepository(
            transport: transport,
            configuration: Self.configuration,
            now: { Self.now }
        )
        let defaultNowTransport = RecordingProfileAPITransport(
            profileEnvelope: profileEnvelope,
            fellowChefsEnvelope: fellowChefsEnvelope,
            kitchenVisitorsEnvelope: kitchenVisitorsEnvelope
        )
        let defaultNowRepository = LiveProfileChefGraphSurfaceRepository(
            transport: defaultNowTransport,
            configuration: Self.configuration
        )

        let profile = try await repository.profile(identifier: "ari")
        let defaultNowProfile = try await defaultNowRepository.profile(identifier: "ari")
        let fellowChefs = try await repository.graph(identifier: "ari", direction: .fellowChefs, page: 1, limit: 50)
        let kitchenVisitors = try await repository.graph(identifier: "ari", direction: .kitchenVisitors, page: 1, limit: 50)

        #expect(profile.source == .live(requestID: "req_profile", validatedAt: Self.now))
        #expect(defaultNowProfile.data.profile.id == "chef_ari")
        #expect(profile.data.profile.username == "ari")
        #expect(profile.data.profile.href == "/users/ari")
        #expect(profile.data.profile.canonicalURL == URL(string: "https://spoonjoy.app/users/ari"))
        #expect(profile.data.isOwner)
        #expect(profile.data.recipes.map(\.id) == ["recipe_profile_tart"])
        #expect(profile.data.recipes.first?.openRoute == .recipeDetail(id: "recipe_profile_tart", presentation: .detail))
        #expect(profile.data.cookbooks.map(\.id) == ["cookbook_profile_weeknights"])
        #expect(profile.data.cookbooks.first?.recipePreviews.map(\.id) == ["recipe_profile_tart"])
        #expect(profile.data.recentSpoons.map(\.id) == ["spoon_profile_origin_cook"])
        #expect(profile.data.recentSpoons.first?.recipe.openRoute == .recipeDetail(id: "recipe_fellow_soup", presentation: .detail))
        #expect(profile.data.fellowChefsCount == 1)
        #expect(profile.data.kitchenVisitorsCount == 1)

        #expect(fellowChefs.direction == .fellowChefs)
        #expect(fellowChefs.rows.map(\.username) == ["jules"])
        #expect(fellowChefs.rows.first?.interactionCounts == ProfileGraphInteractionCounts(spoons: 1, forks: 1, cookbookSaves: 1))
        #expect(fellowChefs.rows.first?.interactionSummary == "1 spoon, 1 fork, 1 cookbook save")
        #expect(fellowChefs.rows.first?.openRoute == .profile(identifier: "jules"))
        #expect(fellowChefs.nextCursor == nil)
        #expect(kitchenVisitors.direction == .kitchenVisitors)
        #expect(kitchenVisitors.rows.first?.username == "mika")

        #expect(transport.requests.map(\.url.path) == [
            "/api/v1/users/ari",
            "/api/v1/users/ari/fellow-chefs",
            "/api/v1/users/ari/kitchen-visitors"
        ])
        #expect(transport.requests[1].queryItems == [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "50")
        ])
    }

    @Test("live profile recipes hide AI placeholder covers and preserve authored cover provenance")
    func liveProfileRecipesHideAIPlaceholderCoversAndPreserveAuthoredCoverProvenance() throws {
        let summaries = try JSONDecoder().decode(
            [ProfileRecipeSummary].self,
            from: Data(
                """
                [
                  {
                    "id": "recipe_ai_placeholder",
                    "title": "Placeholder Soup",
                    "description": null,
                    "servings": "2",
                    "coverImageUrl": "https://spoonjoy.app/photos/recipes/placeholder.jpg",
                    "coverProvenanceLabel": "Generated placeholder",
                    "coverSourceType": "ai-placeholder",
                    "href": "/recipes/recipe_ai_placeholder",
                    "canonicalUrl": "https://spoonjoy.app/recipes/recipe_ai_placeholder"
                  },
                  {
                    "id": "recipe_chef_upload",
                    "title": "Chef Pasta",
                    "description": null,
                    "servings": "4",
                    "coverImageUrl": "https://spoonjoy.app/photos/recipes/chef-upload.jpg",
                    "coverProvenanceLabel": "Chef photo",
                    "coverSourceType": "chef-upload",
                    "href": "/recipes/recipe_chef_upload",
                    "canonicalUrl": "https://spoonjoy.app/recipes/recipe_chef_upload"
                  },
                  {
                    "id": "recipe_editorialized",
                    "title": "Editorial Tart",
                    "description": null,
                    "servings": "6",
                    "coverImageUrl": "https://spoonjoy.app/photos/recipes/editorialized.jpg",
                    "coverProvenanceLabel": "Editorialized chef photo",
                    "coverSourceType": "editorialized-chef-photo",
                    "href": "/recipes/recipe_editorialized",
                    "canonicalUrl": "https://spoonjoy.app/recipes/recipe_editorialized"
                  }
                ]
                """.utf8
            )
        )

        let placeholder = try #require(summaries.first { $0.id == "recipe_ai_placeholder" })
        let chefUpload = try #require(summaries.first { $0.id == "recipe_chef_upload" })
        let editorialized = try #require(summaries.first { $0.id == "recipe_editorialized" })

        #expect(placeholder.coverImageURL == nil)
        #expect(placeholder.coverProvenanceLabel == nil)
        #expect(placeholder.coverSourceType == .aiPlaceholder)
        #expect(chefUpload.coverImageURL == URL(string: "https://spoonjoy.app/photos/recipes/chef-upload.jpg"))
        #expect(chefUpload.coverProvenanceLabel == "Chef photo")
        #expect(chefUpload.coverSourceType == .chefUpload)
        #expect(editorialized.coverImageURL == URL(string: "https://spoonjoy.app/photos/recipes/editorialized.jpg"))
        #expect(editorialized.coverProvenanceLabel == "Editorialized chef photo")
        #expect(editorialized.coverSourceType == .editorializedChefPhoto)
    }

    @Test("local profile recipe projection reuses the recipe cover display policy")
    func localProfileRecipeProjectionReusesRecipeCoverDisplayPolicy() throws {
        let placeholderURL = try #require(URL(string: "https://spoonjoy.app/photos/recipes/placeholder.jpg"))
        let chefUploadURL = try #require(URL(string: "https://spoonjoy.app/photos/recipes/chef-upload.jpg"))
        let placeholder = ProfileRecipeSummary(
            recipe: Self.profileRecipe(
                id: "recipe_ai_placeholder",
                coverImageURL: placeholderURL,
                coverProvenanceLabel: "Generated placeholder",
                coverSourceType: .aiPlaceholder
            )
        )
        let chefUpload = ProfileRecipeSummary(
            recipe: Self.profileRecipe(
                id: "recipe_chef_upload",
                coverImageURL: chefUploadURL,
                coverProvenanceLabel: "Chef photo",
                coverSourceType: .chefUpload
            )
        )

        #expect(placeholder.coverImageURL == nil)
        #expect(placeholder.coverProvenanceLabel == nil)
        #expect(placeholder.coverSourceType == .aiPlaceholder)
        #expect(chefUpload.coverImageURL == chefUploadURL)
        #expect(chefUpload.coverProvenanceLabel == "Chef photo")
        #expect(chefUpload.coverSourceType == .chefUpload)
    }

    @Test("profile repository normalizes server profile links for encoded identifiers")
    @MainActor
    func profileRepositoryNormalizesServerProfileLinksForEncodedIdentifiers() async throws {
        let rawProfile = ProfileSummary(
            id: "chef_alpha",
            username: "alpha space",
            photoURL: nil,
            joinedLabel: "Joined Jun 2026",
            href: "/users/alpha space",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/users/alpha%20space"))
        )
        let rawGraphProfile = ProfileGraphProfile(
            id: rawProfile.id,
            username: rawProfile.username,
            href: rawProfile.href,
            canonicalURL: rawProfile.canonicalURL
        )
        let rawGraphRow = ProfileGraphRow(
            chefID: "chef_beta",
            username: "beta/chef",
            photoURL: nil,
            href: "/users/beta/chef",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/users/beta/chef")),
            interactionCounts: ProfileGraphInteractionCounts(spoons: 1, forks: 0, cookbookSaves: 0),
            latestInteractionAt: "2026-06-04T10:00:00.000Z"
        )
        let profileEnvelope = APIEnvelope(
            requestID: "req_profile_encoded",
            data: ProfileSurfaceData(
                profile: rawProfile,
                isOwner: false,
                recipes: [],
                cookbooks: [],
                recentSpoons: [],
                fellowChefsCount: 1,
                kitchenVisitorsCount: 1
            )
        )
        let graphEnvelope = APIEnvelope(
            requestID: "req_graph_encoded",
            data: ProfileGraphPage(
                profile: rawGraphProfile,
                direction: .fellowChefs,
                page: 1,
                pageSize: 50,
                total: 1,
                nextCursor: nil,
                rows: [rawGraphRow],
                source: .live(requestID: "server_source", validatedAt: Self.now)
            )
        )
        let repository = LiveProfileChefGraphSurfaceRepository(
            transport: RecordingProfileAPITransport(
                profileEnvelope: profileEnvelope,
                fellowChefsEnvelope: graphEnvelope,
                kitchenVisitorsEnvelope: graphEnvelope
            ),
            configuration: Self.configuration,
            now: { Self.now }
        )

        let profile = try await repository.profile(identifier: "alpha space")
        let graph = try await repository.graph(identifier: "alpha space", direction: .fellowChefs, page: 1, limit: 50)
        let row = try #require(graph.rows.first)

        #expect(profile.data.profile.href == "/users/alpha%20space")
        #expect(profile.data.profile.canonicalURL == URL(string: "https://spoonjoy.app/users/alpha%20space"))
        #expect(graph.profile.href == "/users/alpha%20space")
        #expect(graph.profile.canonicalURL == URL(string: "https://spoonjoy.app/users/alpha%20space"))
        #expect(row.href == "/users/beta%2Fchef")
        #expect(row.canonicalURL == URL(string: "https://spoonjoy.app/users/beta%2Fchef"))
        #expect(DeepLinkRouter.spoonjoy.route(for: row.canonicalURL) == .profile(identifier: "beta/chef"))
    }

    @Test("profile view models expose current product surfaces and owner personalization without follows")
    func profileViewModelsExposeCurrentProductSurfacesAndOwnerPersonalization() throws {
        let queuedProfileUpdate = NativeQueuedMutation.profileDisplayUpdate(
            email: "ari@example.com",
            username: "ari",
            clientMutationID: "cm_profile_display",
            createdAt: Self.createdAt
        )
        let conflict = NativeSyncConflict(
            clientMutationID: "cm_profile_display",
            kind: .validation,
            serverRevision: .updatedAt("2026-06-27T22:55:00.000Z"),
            message: "Profile changed elsewhere."
        )

        let owner = ProfileViewModel(
            result: ProfileSurfaceResult(
                data: try Self.profileData(),
                source: .cache(serverRevision: .updatedAt("2026-06-27T22:45:00.000Z"), lastValidatedAt: Self.staleValidatedAt)
            ),
            context: ProfileSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [queuedProfileUpdate],
            conflicts: [conflict],
            connectivity: .offline,
            now: { Self.now }
        )
        let visitor = ProfileViewModel(
            result: ProfileSurfaceResult(
                data: try Self.profileData(isOwner: false),
                source: .live(requestID: "req_profile_visitor", validatedAt: Self.now)
            ),
            context: ProfileSurfaceContext(currentChefID: "chef_jules"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now }
        )

        #expect(owner.header.username == "ari")
        #expect(owner.header.joinedLabel == "Joined Jun 2026")
        #expect(owner.openRoute == .profile(identifier: "ari"))
        #expect(owner.ownerActions.isVisible)
        #expect(owner.ownerActions.editProfileRoute == .settings)
        #expect(owner.offlineIndicator.display == .conflict(recordID: "cm_profile_display", mutationID: "cm_profile_display"))
        #expect(owner.conflictBanner == ProfileSurfaceConflictBanner(
            localClientMutationID: "cm_profile_display",
            message: "Profile changed elsewhere.",
            actionTitle: "Review profile conflict"
        ))
        #expect(owner.sectionIDs == [.recipes, .cookbooks, .recentSpoons, .fellowChefs, .kitchenVisitors])
        #expect(owner.unsupportedSocialSurfaces.isEmpty)
        #expect(owner.recipes.first?.coverProvenanceLabel == "Editorialized chef photo")
        #expect(owner.cookbooks.first?.recipeCountLabel == "1 recipe")
        #expect(owner.graphLinks == [
            ProfileSurfaceGraphLink(direction: .fellowChefs, title: "Fellow chefs", count: 1, route: .profileGraph(identifier: "ari", direction: .fellowChefs, page: 1)),
            ProfileSurfaceGraphLink(direction: .kitchenVisitors, title: "Kitchen visitors", count: 1, route: .profileGraph(identifier: "ari", direction: .kitchenVisitors, page: 1))
        ])
        #expect(visitor.ownerActions.isVisible == false)
        #expect(visitor.availableActionIDs == [.share])
    }

    @Test("snapshot repository restores public profile cache and graph pagination honestly")
    @MainActor
    func snapshotRepositoryRestoresPublicProfileCacheAndGraphPaginationHonestly() async throws {
        let repository = SnapshotProfileChefGraphSurfaceRepository(
            profileResult: ProfileSurfaceResult(
                data: try Self.profileData(),
                source: .cache(serverRevision: nil, lastValidatedAt: Self.staleValidatedAt)
            ),
            graphPages: [
                try Self.graphPage(direction: .fellowChefs, page: 1, nextCursor: "2"),
                try Self.graphPage(direction: .kitchenVisitors)
            ]
        )

        let profile = try await repository.profile(identifier: "chef_ari")
        let fellowChefs = try await repository.graph(identifier: "ari", direction: .fellowChefs, page: 1, limit: 1)
        let missing = try await repository.graph(identifier: "ari", direction: .fellowChefs, page: 2, limit: 1)

        #expect(profile.data.profile.username == "ari")
        #expect(profile.offlineIndicator.display == .stale(domain: .profile(id: "chef_ari")))
        #expect(fellowChefs.nextCursor == "2")
        #expect(fellowChefs.emptyState == nil)
        #expect(missing.rows.isEmpty)
        #expect(missing.emptyState == ProfileSurfaceEmptyState(
            title: "No fellow chefs yet",
            message: "Fellow chefs appear after this chef cooks, forks, or saves recipes from other chefs.",
            systemImage: "person.2"
        ))
    }

    @Test("fallback profile repository refuses to invent unknown cached profiles")
    @MainActor
    func fallbackProfileRepositoryRefusesToInventUnknownCachedProfiles() async throws {
        let snapshot = SnapshotProfileChefGraphSurfaceRepository(
            profileResult: ProfileSurfaceResult(
                data: try Self.profileData(),
                source: .cache(serverRevision: nil, lastValidatedAt: Self.staleValidatedAt)
            ),
            graphPages: [try Self.graphPage(direction: .fellowChefs)]
        )
        let repository = FallbackProfileChefGraphSurfaceRepository(
            primary: ThrowingProfileChefGraphSurfaceRepository(),
            fallback: snapshot
        )

        var profileDidThrow = false
        do {
            _ = try await repository.profile(identifier: "not-real")
        } catch let error as ProfileSurfaceSnapshotError {
            profileDidThrow = true
            #expect(error == .profileNotCached(identifier: "not-real"))
        }
        #expect(profileDidThrow)

        var graphDidThrow = false
        do {
            _ = try await repository.graph(identifier: "not-real", direction: .fellowChefs, page: 1, limit: 50)
        } catch let error as ProfileSurfaceSnapshotError {
            graphDidThrow = true
            #expect(error == .profileNotCached(identifier: "not-real"))
        }
        #expect(graphDidThrow)
    }

    @Test("profile coverage edges keep filtered and empty product states honest")
    func profileCoverageEdgesKeepFilteredAndEmptyProductStatesHonest() throws {
        let profile = try Self.profileData()
        let freshCache = ProfileSurfaceResult(
            data: profile,
            source: .cache(serverRevision: nil, lastValidatedAt: Self.now.addingTimeInterval(-60))
        )
        let live = ProfileSurfaceResult(
            data: profile,
            source: .live(requestID: "req_profile_fresh", validatedAt: Self.now)
        )
        let zeroInteractionRow = ProfileGraphRow(
            chefID: "chef_quiet",
            username: "quiet",
            photoURL: nil,
            href: "/users/quiet",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/users/quiet")),
            interactionCounts: ProfileGraphInteractionCounts(spoons: 0, forks: 0, cookbookSaves: 0),
            latestInteractionAt: nil
        )
        let pluralCookbook = ProfileCookbookSummary(
            id: "cookbook_plural",
            title: "Plural",
            recipeCount: 2,
            recipePreviews: [],
            href: "/cookbooks/cookbook_plural",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/cookbooks/cookbook_plural"))
        )
        let decodedGraph = try JSONDecoder().decode(ProfileGraphPage.self, from: Data(
            """
            {
              "profile": {
                "id": "chef_ari",
                "username": "ari",
                "href": "/users/ari",
                "canonicalUrl": "https://spoonjoy.app/users/ari"
              },
              "page": 2,
              "pageSize": 25,
              "total": 0,
              "nextCursor": null,
              "rows": []
            }
            """.utf8
        ))
        let filteredEmptyProfile = ProfileViewModel(
            result: ProfileSurfaceResult(
                data: try Self.profileData(recipes: [], cookbooks: [], recentSpoons: [], fellowChefsCount: 0, kitchenVisitorsCount: 0),
                source: .live(requestID: "req_filtered_profile", validatedAt: Self.now)
            ),
            context: ProfileSurfaceContext(currentChefID: "chef_other"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now }
        )

        #expect(ProfileSurfaceRequest(identifier: "  ari \n").identifier == "ari")
        #expect(live.offlineIndicator.display == .synced)
        #expect(freshCache.offlineIndicator(now: Self.now).display == .synced)
        #expect(ProfileSurfaceResult.offlineIndicator(
            domain: .profile(id: "chef_ari"),
            payload: .profile(id: "chef_other", username: "other"),
            accountID: "chef_ari",
            sourceEndpoint: "/api/v1/users/ari",
            serverRevision: nil,
            lastValidatedAt: Self.now,
            now: Self.now,
            freshnessPolicy: .offlineProductContract
        ).display == .stale(domain: .profile(id: "chef_ari")))
        #expect(profile.cookbooks.first?.openRoute == .cookbookDetail(id: "cookbook_profile_weeknights"))
        #expect(profile.cookbooks.first?.recipePreviews.first?.openRoute == .recipeDetail(id: "recipe_profile_tart", presentation: .detail))
        #expect(pluralCookbook.recipeCountLabel == "2 recipes")
        #expect(zeroInteractionRow.id == "chef_quiet")
        #expect(zeroInteractionRow.interactionSummary == "No interactions yet")
        #expect(ProfileGraphPage.emptyState(for: .kitchenVisitors) == ProfileSurfaceEmptyState(
            title: "No kitchen visitors yet",
            message: "Kitchen visitors appear after other chefs cook, fork, or save this chef's recipes.",
            systemImage: "person.crop.circle.badge.clock"
        ))
        #expect(decodedGraph.direction == .fellowChefs)
        #expect(decodedGraph.source == .cache(serverRevision: nil, lastValidatedAt: .distantPast))
        #expect(decodedGraph.emptyState == nil)
        #expect(decodedGraph.with(direction: .kitchenVisitors, source: freshCache.source).emptyState == ProfileSurfaceEmptyState(
            title: "No kitchen visitors yet",
            message: "Kitchen visitors appear after other chefs cook, fork, or save this chef's recipes.",
            systemImage: "person.crop.circle.badge.clock"
        ))
        #expect(String(describing: ProfileSurfaceSnapshotError.profileNotCached(identifier: "missing")) == "No cached profile exists for missing.")
        #expect(filteredEmptyProfile.recipes.isEmpty)
        #expect(filteredEmptyProfile.cookbooks.isEmpty)
        #expect(filteredEmptyProfile.recentSpoons.isEmpty)
        #expect(filteredEmptyProfile.graphLinks.map(\.count) == [0, 0])
        #expect(filteredEmptyProfile.unsupportedSocialSurfaces.isEmpty)
    }

    @Test("profile view model loader covers queued offline cached and unavailable states")
    @MainActor
    func profileViewModelLoaderCoversQueuedOfflineCachedAndUnavailableStates() async throws {
        let profileResult = ProfileSurfaceResult(
            data: try Self.profileData(),
            source: .cache(serverRevision: .updatedAt("2026-06-27T22:45:00.000Z"), lastValidatedAt: Self.staleValidatedAt)
        )
        let repository = SnapshotProfileChefGraphSurfaceRepository(
            profileResult: profileResult,
            graphPages: [
                ProfileGraphPage.empty(
                    profile: ProfileGraphProfile(
                        id: "chef_ari",
                        username: "ari",
                        href: "/users/ari",
                        canonicalURL: try #require(URL(string: "https://spoonjoy.app/users/ari"))
                    ),
                    direction: .kitchenVisitors,
                    page: 1,
                    pageSize: 50,
                    source: profileResult.source
                )
            ]
        )
        let queuedProfilePhoto = NativeQueuedMutation.profilePhotoRemove(
            clientMutationID: "cm_profile_photo_remove",
            createdAt: Self.createdAt
        )
        let queuedShopping = NativeQueuedMutation.shoppingAddItem(
            name: "lemons",
            quantity: nil,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_not_profile",
            createdAt: Self.createdAt
        )
        let queuedViewModel = ProfileViewModel(
            result: profileResult,
            context: ProfileSurfaceContext(currentChefID: nil),
            queuedMutations: [queuedProfilePhoto, queuedShopping],
            conflicts: [],
            connectivity: .online,
            now: { Self.now }
        )
        let offlineViewModel = ProfileViewModel(
            result: ProfileSurfaceResult(data: try Self.profileData(), source: .live(requestID: "req_offline_profile", validatedAt: Self.now)),
            context: ProfileSurfaceContext(currentChefID: nil),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.now }
        )
        let loader = ProfileChefGraphSurfaceViewModel(
            repository: repository,
            context: ProfileSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online
        )
        let unavailable = UnavailableProfileChefGraphSurfaceRepository()

        try await loader.loadProfile(identifier: "ari")
        try await loader.loadGraph(identifier: "ari", direction: .kitchenVisitors)

        #expect(queuedViewModel.offlineIndicator.display == .queuedWork(count: 1, oldestClientMutationID: "cm_profile_photo_remove"))
        #expect(offlineViewModel.offlineIndicator.display == .offline)
        #expect(ProfileViewModel.queueableProfileSurfaceKinds(createdAt: Self.createdAt) == [
            .profileDisplayUpdate,
            .profilePhotoUpload,
            .profilePhotoRemove
        ])
        #expect(loader.profile?.header.username == "ari")
        #expect(loader.graph?.title == "Kitchen visitors")
        #expect(loader.graph?.offlineIndicator.display == .stale(domain: .profile(id: "chef_ari")))

        var unavailableProfileDidThrow = false
        do {
            _ = try await unavailable.profile(identifier: "  missing  ")
        } catch let error as ProfileSurfaceSnapshotError {
            unavailableProfileDidThrow = true
            #expect(error == .profileNotCached(identifier: "missing"))
        }
        #expect(unavailableProfileDidThrow)

        var unavailableGraphDidThrow = false
        do {
            _ = try await unavailable.graph(identifier: "missing", direction: .kitchenVisitors, page: 1, limit: 50)
        } catch let error as ProfileSurfaceSnapshotError {
            unavailableGraphDidThrow = true
            #expect(error == .profileNotCached(identifier: "missing"))
        }
        #expect(unavailableGraphDidThrow)
    }

    private static func profileData(isOwner: Bool = true) throws -> ProfileSurfaceData {
        try profileData(
            isOwner: isOwner,
            recipes: [
                ProfileRecipeSummary(
                    id: "recipe_profile_tart",
                    title: "Tomato Tart",
                    description: "A profile route fixture",
                    servings: "4",
                    coverImageURL: URL(string: "https://spoonjoy.app/photos/profile-tart-editorial.jpg"),
                    coverProvenanceLabel: "Editorialized chef photo",
                    href: "/recipes/recipe_profile_tart",
                    canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_profile_tart"))
                )
            ],
            cookbooks: [
                ProfileCookbookSummary(
                    id: "cookbook_profile_weeknights",
                    title: "Weeknights",
                    recipeCount: 1,
                    recipePreviews: [
                        ProfileCookbookRecipePreview(
                            id: "recipe_profile_tart",
                            title: "Tomato Tart",
                            coverImageURL: URL(string: "https://spoonjoy.app/photos/profile-tart-editorial.jpg"),
                            coverProvenanceLabel: "Editorialized chef photo",
                            href: "/recipes/recipe_profile_tart",
                            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_profile_tart"))
                        )
                    ],
                    href: "/cookbooks/cookbook_profile_weeknights",
                    canonicalURL: try #require(URL(string: "https://spoonjoy.app/cookbooks/cookbook_profile_weeknights"))
                )
            ],
            recentSpoons: [
                ProfileRecentSpoon(
                    id: "spoon_profile_origin_cook",
                    cookedAt: "2026-06-04T10:00:00.000Z",
                    photoURL: nil,
                    note: "profile chef spoon",
                    nextTime: nil,
                    chef: ChefSummary(id: "chef_ari", username: "ari", photoURL: URL(string: "https://spoonjoy.app/photos/profiles/chef_ari/avatar.gif")),
                    recipe: ProfileRecentSpoonRecipe(id: "recipe_fellow_soup", title: "Fellow Soup", chefID: "chef_jules"),
                    coverImageURL: nil,
                    coverProvenanceLabel: nil
                )
            ],
            fellowChefsCount: 1,
            kitchenVisitorsCount: 1
        )
    }

    private static func profileRecipe(
        id: String,
        coverImageURL: URL?,
        coverProvenanceLabel: String?,
        coverSourceType: RecipeCoverSourceType?
    ) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        return Recipe(
            id: id,
            title: "Profile Recipe",
            description: nil,
            servings: "2",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: coverImageURL,
            coverProvenanceLabel: coverProvenanceLabel,
            coverSourceType: coverSourceType,
            coverVariant: .image,
            href: "/recipes/\(id)",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "Profile Recipe by ari on Spoonjoy",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: "2026-07-01T00:00:00.000Z",
            updatedAt: "2026-07-01T00:00:00.000Z",
            steps: [],
            cookbooks: []
        )
    }

    private static func profileData(
        isOwner: Bool = true,
        recipes: [ProfileRecipeSummary],
        cookbooks: [ProfileCookbookSummary],
        recentSpoons: [ProfileRecentSpoon],
        fellowChefsCount: Int,
        kitchenVisitorsCount: Int
    ) throws -> ProfileSurfaceData {
        ProfileSurfaceData(
            profile: ProfileSummary(
                id: "chef_ari",
                username: "ari",
                photoURL: URL(string: "https://spoonjoy.app/photos/profiles/chef_ari/avatar.gif"),
                joinedLabel: "Joined Jun 2026",
                href: "/users/ari",
                canonicalURL: try #require(URL(string: "https://spoonjoy.app/users/ari"))
            ),
            isOwner: isOwner,
            recipes: recipes,
            cookbooks: cookbooks,
            recentSpoons: recentSpoons,
            fellowChefsCount: fellowChefsCount,
            kitchenVisitorsCount: kitchenVisitorsCount
        )
    }

    private static func graphPage(
        direction: ProfileGraphDirection,
        page: Int = 1,
        nextCursor: String? = nil
    ) throws -> ProfileGraphPage {
        let username = direction == .fellowChefs ? "jules" : "mika"
        let chefID = direction == .fellowChefs ? "chef_jules" : "chef_mika"
        return ProfileGraphPage(
            profile: ProfileGraphProfile(
                id: "chef_ari",
                username: "ari",
                href: "/users/ari",
                canonicalURL: try #require(URL(string: "https://spoonjoy.app/users/ari"))
            ),
            direction: direction,
            page: page,
            pageSize: 50,
            total: 1,
            nextCursor: nextCursor,
            rows: [
                ProfileGraphRow(
                    chefID: chefID,
                    username: username,
                    photoURL: nil,
                    href: "/users/\(username)",
                    canonicalURL: try #require(URL(string: "https://spoonjoy.app/users/\(username)")),
                    interactionCounts: ProfileGraphInteractionCounts(spoons: 1, forks: 1, cookbookSaves: 1),
                    latestInteractionAt: "2026-06-04T10:00:00.000Z"
                )
            ],
            source: .live(requestID: direction == .fellowChefs ? "req_fellow_chefs" : "req_kitchen_visitors", validatedAt: Self.now)
        )
    }
}

private enum RecordingProfileAPITransportError: Error, Equatable {
    case unsupportedValueType(String)
}

private enum ThrowingProfileChefGraphSurfaceRepositoryError: Error {
    case liveUnavailable
}

private struct ThrowingProfileChefGraphSurfaceRepository: ProfileChefGraphSurfaceRepository {
    func profile(identifier _: String) async throws -> ProfileSurfaceResult {
        throw ThrowingProfileChefGraphSurfaceRepositoryError.liveUnavailable
    }

    func graph(identifier _: String, direction _: ProfileGraphDirection, page _: Int, limit _: Int) async throws -> ProfileGraphPage {
        throw ThrowingProfileChefGraphSurfaceRepositoryError.liveUnavailable
    }
}

private final class RecordingProfileAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    private let profileEnvelope: APIEnvelope<ProfileSurfaceData>
    private let fellowChefsEnvelope: APIEnvelope<ProfileGraphPage>
    private let kitchenVisitorsEnvelope: APIEnvelope<ProfileGraphPage>
    private var sentRequests: [APIRequest] = []

    init(
        profileEnvelope: APIEnvelope<ProfileSurfaceData>,
        fellowChefsEnvelope: APIEnvelope<ProfileGraphPage>,
        kitchenVisitorsEnvelope: APIEnvelope<ProfileGraphPage>
    ) {
        self.profileEnvelope = profileEnvelope
        self.fellowChefsEnvelope = fellowChefsEnvelope
        self.kitchenVisitorsEnvelope = kitchenVisitorsEnvelope
    }

    var requests: [APIRequest] {
        sentRequests
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let builtRequest = try request.urlRequest(configuration: configuration)
        sentRequests.append(builtRequest)

        if valueType == ProfileSurfaceData.self {
            return profileEnvelope as! APIEnvelope<Value>
        }
        if valueType == ProfileGraphPage.self, builtRequest.url.path.hasSuffix("/fellow-chefs") {
            return fellowChefsEnvelope as! APIEnvelope<Value>
        }
        if valueType == ProfileGraphPage.self, builtRequest.url.path.hasSuffix("/kitchen-visitors") {
            return kitchenVisitorsEnvelope as! APIEnvelope<Value>
        }
        throw RecordingProfileAPITransportError.unsupportedValueType(String(describing: valueType))
    }
}
