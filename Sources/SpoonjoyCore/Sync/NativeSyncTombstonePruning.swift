import Foundation

extension NativeSyncTombstone {
    /// How long a deletion is remembered after it happened, measured back from the newest deletion this store knows.
    /// Readers use tombstones to hide a deleted resource wherever a copy may linger: a stale resend in a later delta,
    /// a spoon in a recipe's recent spoons, a record that a later sync drops. Ninety days covers those; anything
    /// that can hold a copy longer is kept by the rules below instead.
    static let retentionInterval: TimeInterval = 90 * 24 * 60 * 60

    /// The tombstones still worth keeping after a sync, so the log stops growing with every deletion.
    ///
    /// Repeats of one deletion collapse to the newest. A tombstone is kept while it is inside the retention window,
    /// and for any age while the sync cache still holds a record it hides: a record of the same kind and id or, for a
    /// spoon, the recipe whose recent spoons may list it. Chef deletions are always kept: a chef can live on in the
    /// durable cache and in other chefs' pages with nothing to remove it, and such deletions are rare. A tombstone
    /// whose date cannot be read is kept.
    ///
    /// The window is measured from the newest deletion, not the clock, so a device that sees no deletions keeps what
    /// it has. That newest date is capped at the server's time for this sync (`serverTime`), because a deletion
    /// made on this device carries the device clock: a clock set a year ahead must not push every real deletion out.
    static func pruned(
        _ tombstones: [NativeSyncTombstone],
        cachedRecords: [String: NativeSyncCachedRecord],
        serverTime: String? = nil
    ) -> [NativeSyncTombstone] {
        let fractionalSeconds = ISO8601DateFormatter()
        fractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let wholeSeconds = ISO8601DateFormatter()
        let date: (String) -> Date? = { fractionalSeconds.date(from: $0) ?? wholeSeconds.date(from: $0) }
        let newestDeletion = tombstones.compactMap { date($0.deletedAt) }.max()
        let cap = serverTime.flatMap(date)
        let cutoff = newestDeletion.map { newest in
            (cap.map { min(newest, $0) } ?? newest).addingTimeInterval(-retentionInterval)
        }
        var seen = Set<String>()
        var kept: [NativeSyncTombstone] = []
        for tombstone in tombstones.reversed() {
            let key = "\(tombstone.resourceType.rawValue):\(tombstone.resourceID)"
            guard seen.insert(key).inserted else {
                continue
            }
            let isRecent: Bool
            if let deletedAt = date(tombstone.deletedAt), let cutoff {
                isRecent = deletedAt >= cutoff
            } else {
                isRecent = true
            }
            let hidesCachedRecord = cachedRecords[key] != nil
            let hidesSpoonInCachedRecipe = tombstone.resourceType == .spoon &&
                tombstone.parentResourceID.map { cachedRecords["\(NativeSyncEntryKind.recipe.rawValue):\($0)"] != nil } == true
            if isRecent || hidesCachedRecord || hidesSpoonInCachedRecipe || tombstone.resourceType == .profile {
                kept.append(tombstone)
            }
        }
        return kept.reversed()
    }
}
