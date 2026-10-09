import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("A sync never sends an accepted edit twice")
struct NativeDrainProgressTests {
    private static let configuration = APIClientConfiguration.spoonjoyProduction
    private static let now = Date(timeIntervalSince1970: 1_781_600_000)
    private static let scope = NativeSyncExecutionScope(expectedAccountID: "chef_ari", environment: .production)

    @Test("an edit the server accepted is not sent again when the same sync then fails")
    func acceptedEditIsNotResentAfterALaterFailure() async throws {
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [Self.edit("cm_accepted"), Self.edit("cm_cut_off")])
        )
        let transport = ProgressTransport(failingClientMutationIDs: ["cm_cut_off"])
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { Self.now })

        await #expect(throws: URLError.self) {
            _ = try await engine.bootstrapAndDrain(configuration: Self.configuration, trigger: .launch, scope: Self.scope)
        }
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_cut_off"])

        await transport.stopFailing()
        _ = try await engine.bootstrapAndDrain(configuration: Self.configuration, trigger: .foreground, scope: Self.scope)

        #expect(await transport.sentClientMutationIDs() == ["cm_accepted", "cm_cut_off", "cm_cut_off"])
        #expect(try await store.loadQueue().mutations.isEmpty)
    }

    @Test("an edit that names a recipe created earlier in the same sync points at the server id once the create is accepted")
    func remainingEditsFollowAcceptedCreates() async throws {
        let create = try NativeQueuedMutation.recipeCreate(clientMutationID: "cm_create", title: "Soup", description: nil, servings: nil, steps: [], createdAt: "2026-10-09T08:00:00.000Z")
        let localRecipeID = try #require(create.optimisticRecipeID)
        let rename = NativeQueuedMutation.recipeUpdate(recipeID: localRecipeID, clientMutationID: "cm_rename", title: "Better soup", description: nil, servings: nil, createdAt: "2026-10-09T08:00:01.000Z")
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: try NativeMutationQueue(mutations: [create, rename]))
        let transport = ProgressTransport(
            failingClientMutationIDs: ["cm_rename"],
            idRemaps: ["cm_create": [NativeSyncIDRemap(localID: localRecipeID, serverID: "recipe_server_soup")]]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { Self.now })

        await #expect(throws: URLError.self) {
            _ = try await engine.bootstrapAndDrain(configuration: Self.configuration, trigger: .launch, scope: Self.scope)
        }

        let left = try await store.loadQueue().mutations
        #expect(left.map(\.clientMutationID) == ["cm_rename"])
        #expect(left.first?.recipeID == "recipe_server_soup")
    }

    @Test("a cached recipe this build cannot read does not undo the sync's progress, and is left as it was")
    func undecodableCachedRecordDoesNotUndoProgress() async throws {
        let unreadable = NativeSyncCachedRecord(kind: .recipe, resourceID: "recipe_future", payload: .object(["title": .string("From a newer server")]), serverRevision: .updatedAt("2026-10-09T07:00:00.000Z"))
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [
                .recipeUpdate(recipeID: "recipe_soup", clientMutationID: "cm_recipe", title: "Soup", description: nil, servings: nil, createdAt: "2026-10-09T08:00:00.000Z"),
                Self.edit("cm_shopping"),
                .cookbookCreate(clientMutationID: "cm_cookbook", title: "Weeknights", createdAt: "2026-10-09T08:00:02.000Z")
            ]),
            cachedRecords: [unreadable]
        )
        let transport = ProgressTransport()
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { Self.now })

        _ = try await engine.bootstrapAndDrain(configuration: Self.configuration, trigger: .launch, scope: Self.scope)
        _ = try await engine.bootstrapAndDrain(configuration: Self.configuration, trigger: .foreground, scope: Self.scope)

        #expect(await transport.sentClientMutationIDs() == ["cm_recipe", "cm_shopping", "cm_cookbook"])
        #expect(try await store.loadQueue().mutations.isEmpty)
        #expect(try await store.cachedRecord(kind: .recipe, resourceID: "recipe_future") == unreadable)
    }

    @Test("a recipe with a cover kind this build does not know still opens, with no cover kind")
    func unknownCoverKindsDecode() throws {
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(#"""
        {
          "id": "recipe_soup",
          "title": "Soup",
          "chef": { "id": "chef_ari", "username": "ari" },
          "coverSourceType": "hologram",
          "coverVariant": "spinning",
          "href": "/recipes/recipe_soup",
          "canonicalUrl": "https://spoonjoy.app/recipes/recipe_soup",
          "attribution": { "creditText": "ari", "canonicalUrl": "https://spoonjoy.app/recipes/recipe_soup" },
          "createdAt": "2026-10-09T08:00:00.000Z",
          "updatedAt": "2026-10-09T08:00:00.000Z",
          "steps": [],
          "cookbooks": []
        }
        """#.utf8))
        #expect(recipe.coverSourceType == nil)
        #expect(recipe.coverVariant == nil)
    }

    private static func edit(_ clientMutationID: String) -> NativeQueuedMutation {
        .shoppingAddItem(name: "milk", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: clientMutationID, createdAt: "2026-10-09T08:00:00.000Z")
    }
}

/// Accepts every edit, except that sends of `failingClientMutationIDs` fail as a dropped connection would.
private actor ProgressTransport: NativeSyncTransport {
    private var failingClientMutationIDs: Set<String>
    private let idRemaps: [String: [NativeSyncIDRemap]]
    private var sent: [String] = []

    init(failingClientMutationIDs: Set<String> = [], idRemaps: [String: [NativeSyncIDRemap]] = [:]) {
        self.failingClientMutationIDs = failingClientMutationIDs
        self.idRemaps = idRemaps
    }

    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        .success(cursor: nil, tombstones: [])
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        sent.append(mutation.clientMutationID)
        if failingClientMutationIDs.contains(mutation.clientMutationID) {
            throw URLError(.networkConnectionLost)
        }
        return .success(serverRevision: nil, idRemaps: idRemaps[mutation.clientMutationID] ?? [])
    }

    func stopFailing() {
        failingClientMutationIDs = []
    }

    func sentClientMutationIDs() -> [String] {
        sent
    }
}
