import Foundation

public struct ImageCacheEntry: Equatable, Sendable {
    public let key: String
    public let byteCount: Int
    public let lastAccess: Date

    public init(key: String, byteCount: Int, lastAccess: Date) {
        self.key = key
        self.byteCount = byteCount
        self.lastAccess = lastAccess
    }
}

/// Least-recently-used eviction by access date.
public enum ImageCacheEvictionPolicy {
    /// The keys to delete, oldest access first, so the remaining entries total at most `limitBytes`.
    public static func evictions(from entries: [ImageCacheEntry], limitBytes: Int) -> [String] {
        var total = entries.reduce(0) { $0 + $1.byteCount }
        var evicted: [String] = []
        let oldestFirst = entries.sorted {
            $0.lastAccess == $1.lastAccess ? $0.key < $1.key : $0.lastAccess < $1.lastAccess
        }
        for entry in oldestFirst where total > limitBytes {
            total -= entry.byteCount
            evicted.append(entry.key)
        }
        return evicted
    }
}
