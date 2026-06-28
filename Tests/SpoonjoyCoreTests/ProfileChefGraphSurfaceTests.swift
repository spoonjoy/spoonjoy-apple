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

        let profile = try await repository.profile(identifier: "ari")
        let fellowChefs = try await repository.graph(identifier: "ari", direction: .fellowChefs, page: 1, limit: 50)
        let kitchenVisitors = try await repository.graph(identifier: "ari", direction: .kitchenVisitors, page: 1, limit: 50)

        #expect(profile.source == .live(requestID: "req_profile", validatedAt: Self.now))
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
            now: { Self.now },
            timestamp: { Self.createdAt }
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
            now: { Self.now },
            timestamp: { Self.createdAt }
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

    private static func profileData(isOwner: Bool = true) throws -> ProfileSurfaceData {
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
