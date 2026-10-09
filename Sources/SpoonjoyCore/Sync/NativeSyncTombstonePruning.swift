import Foundation

extension NativeSyncTombstone {
    /// How long a deletion is remembered after it happened, measured against the newest deletion this store knows.
    /// Readers use tombstones to hide a deleted resource wherever a copy may linger: a stale resend in a later delta,
    /// a chef embedded in someone else's graph page or a recipe, a spoon in a recipe's recent spoons, a record in the
    /// durable cache file. Those copies are replaced long before this window closes.
    static let retentionInterval: TimeInterval = 90 * 24 * 60 * 60

    /// The tombstones still worth keeping after a sync, so the log stops growing with every deletion.
    ///
    /// Repeats of one deletion collapse to the newest. A tombstone is kept while it is inside the retention window,
    /// and for any age while the sync cache still holds a record it hides: a record of the same kind and id or, for a
    /// spoon, the recipe whose recent spoons may list it. A tombstone whose date cannot be read is kept. The window is
    /// measured from the newest deletion, not the clock, so a device that sees no deletions keeps what it has.
    static func pruned(_ tombstones: [NativeSyncTombstone], cachedRecords: [String: NativeSyncCachedRecord]) -> [NativeSyncTombstone] {
        let deletionDates = tombstones.compactMap { NativeSyncTombstone.date(from: $0.deletedAt) }
        let cutoff = deletionDates.max().map { $0.addingTimeInterval(-retentionInterval) }
        var seen = Set<String>()
        var kept: [NativeSyncTombstone] = []
        for tombstone in tombstones.reversed() {
            let key = "\(tombstone.resourceType.rawValue):\(tombstone.resourceID)"
            guard seen.insert(key).inserted else {
                continue
            }
            let isRecent: Bool
            if let deletedAt = NativeSyncTombstone.date(from: tombstone.deletedAt), let cutoff {
                isRecent = deletedAt >= cutoff
            } else {
                isRecent = true
            }
            let hidesCachedRecord = cachedRecords[key] != nil
            let hidesSpoonInCachedRecipe = tombstone.resourceType == .spoon &&
                tombstone.parentResourceID.map { cachedRecords["\(NativeSyncEntryKind.recipe.rawValue):\($0)"] != nil } == true
            if isRecent || hidesCachedRecord || hidesSpoonInCachedRecipe {
                kept.append(tombstone)
            }
        }
        return kept.reversed()
    }

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
