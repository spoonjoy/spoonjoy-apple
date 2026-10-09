import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Tombstones stop piling up")
struct NativeTombstonePruningTests {
    private static let validatedAt = Date(timeIntervalSince1970: 1_781_600_000)

    private static func tombstone(_ type: NativeSyncResourceType, _ id: String, parent: String? = nil, at: String = "2026-10-09T08:00:00.000Z") -> NativeSyncTombstone {
        NativeSyncTombstone(resourceType: type, resourceID: id, parentResourceID: parent, title: nil, deletedAt: at, updatedAt: at)
    }

    private static func record(_ kind: NativeSyncEntryKind, _ id: String) -> NativeSyncCachedRecord {
        NativeSyncCachedRecord(kind: kind, resourceID: id, payload: .object([:]), serverRevision: .updatedAt("2026-10-09T08:00:00.000Z"))
    }

    private static func syncData(_ entries: [NativeSyncEntry], serverTime: String = "2026-10-09T08:00:00.000Z") -> NativeSyncData {
        NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: "chef_ari",
                environment: .production,
                schemaVersion: 1,
                sourceEndpoint: "/api/v1/me/sync",
                generatedAt: serverTime,
                lastValidatedAt: "2026-10-09T08:00:00.000Z"
            ),
            entries: entries,
            nextCursor: nil,
            hasMore: false
        )
    }

    private static func day(_ n: Int) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: 1_780_000_000 + Double(n) * 86_400))
    }

    @Test("old tombstones are dropped unless they still hide something cached or name a chef; recent ones always stay")
    func dropsOnlyOldTombstonesThatHideNothing() {
        let records = Dictionary(uniqueKeysWithValues: [
            Self.record(.recipe, "recipe_cached"),
            Self.record(.shoppingItem, "item_still_cached")
        ].map { ($0.cacheKey, $0) })
        let pruned = NativeSyncTombstone.pruned([
            Self.tombstone(.recipe, "recipe_old_gone", at: Self.day(0)),
            Self.tombstone(.profile, "chef_old_gone", at: Self.day(0)),
            Self.tombstone(.shoppingItem, "item_still_cached", at: Self.day(0)),
            Self.tombstone(.spoon, "spoon_in_cached_recipe", parent: "recipe_cached", at: Self.day(0)),
            Self.tombstone(.spoon, "spoon_in_gone_recipe", parent: "recipe_old_gone", at: Self.day(0)),
            Self.tombstone(.spoon, "spoon_without_recipe", at: Self.day(0)),
            Self.tombstone(.cookbook, "cookbook_unreadable_date", at: "yesterday"),
            Self.tombstone(.profile, "chef_recent_gone", at: Self.day(20)),
            Self.tombstone(.recipe, "recipe_edge_of_window", at: Self.day(10)),
            Self.tombstone(.shoppingItem, "item_still_cached", at: Self.day(100))
        ], cachedRecords: records)

        #expect(pruned.map(\.resourceID) == [
            "chef_old_gone",
            "spoon_in_cached_recipe",
            "cookbook_unreadable_date",
            "chef_recent_gone",
            "recipe_edge_of_window",
            "item_still_cached"
        ])
        #expect(pruned.last?.deletedAt == Self.day(100))
        #expect(NativeSyncTombstone.pruned([], cachedRecords: records).isEmpty)
        let undated = [Self.tombstone(.recipe, "recipe_undated", at: "unknown")]
        #expect(NativeSyncTombstone.pruned(undated, cachedRecords: [:]) == undated)
    }

    @Test("deletions spread over many months do not grow the stored tombstones, in either store")
    func storedTombstonesDoNotGrow() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("tombstones-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stores: [any NativeSyncStore] = [
            InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue()),
            try FileBackedNativeSyncStore(fileURL: directory.appendingPathComponent("sync.json"))
        ]
        for store in stores {
            for round in 0..<20 {
                let id = "item_\(round)"
                let deletedAt = Self.day(round * 30)
                _ = try await store.apply(syncData: Self.syncData([
                    NativeSyncEntry(action: .upsert, kind: .shoppingItem, resourceID: id, updatedAt: deletedAt, payload: .object(["name": .string("milk")]), tombstone: nil)
                ], serverTime: deletedAt), validatedAt: Self.validatedAt)
                _ = try await store.apply(syncData: Self.syncData([
                    NativeSyncEntry(action: .delete, kind: .shoppingItem, resourceID: id, updatedAt: deletedAt, payload: nil, tombstone: Self.tombstone(.shoppingItem, id, at: deletedAt))
                ], serverTime: deletedAt), validatedAt: Self.validatedAt)
            }
            // Deletions 30 days apart: only those within 90 days of the newest are still remembered.
            #expect(try await store.loadSnapshot().tombstones.map(\.resourceID) == ["item_16", "item_17", "item_18", "item_19"])
        }
    }

    @Test("a deleted chef stays hidden right after the sync that deletes it")
    func deletedChefTombstoneSurvivesItsOwnSync() async throws {
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
        _ = try await store.apply(syncData: Self.syncData([
            NativeSyncEntry(action: .upsert, kind: .profile, resourceID: "chef_peer", updatedAt: Self.day(0), payload: .object(["username": .string("peer")]), tombstone: nil)
        ]), validatedAt: Self.validatedAt)
        _ = try await store.apply(syncData: Self.syncData([
            NativeSyncEntry(action: .delete, kind: .profile, resourceID: "chef_peer", updatedAt: Self.day(1), payload: nil, tombstone: Self.tombstone(.profile, "chef_peer", at: Self.day(1)))
        ]), validatedAt: Self.validatedAt)

        #expect(try await store.cachedRecord(kind: .profile, resourceID: "chef_peer") == nil)
        #expect(await store.loadSnapshot().tombstones.map(\.resourceID) == ["chef_peer"])
    }

    @Test("a deletion stamped by a device clock set far ahead does not push real deletions out")
    func futureDatedLocalDeletionDoesNotMoveTheWindow() {
        let pruned = NativeSyncTombstone.pruned([
            Self.tombstone(.recipe, "recipe_deleted_last_week", at: Self.day(93)),
            Self.tombstone(.shoppingItem, "item_deleted_on_device", at: Self.day(465)),
            Self.tombstone(.cookbook, "cookbook_deleted_long_ago", at: Self.day(0))
        ], cachedRecords: [:], serverTime: Self.day(100))

        #expect(pruned.map(\.resourceID) == ["recipe_deleted_last_week", "item_deleted_on_device"])
        // Without a readable server time, the newest deletion sets the window.
        let uncapped = NativeSyncTombstone.pruned([
            Self.tombstone(.recipe, "recipe_deleted_last_week", at: Self.day(93)),
            Self.tombstone(.shoppingItem, "item_deleted_on_device", at: Self.day(465))
        ], cachedRecords: [:], serverTime: "not a date")
        #expect(uncapped.map(\.resourceID) == ["item_deleted_on_device"])
    }
}
