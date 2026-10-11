import Foundation

/// Downloaded image bytes on disk (in Caches), bounded by `byteLimit` and trimmed least-recently-used.
/// A read refreshes the file's modification date, which serves as its access date.
///
/// The cache lists its folder once, on first use, and then keeps sizes and access dates in memory, so a
/// write costs one file write rather than a scan of every cached file.
public actor ImageDiskCache {
    public static let defaultByteLimit = 200 * 1_024 * 1_024

    private let directory: URL
    private let byteLimit: Int
    private let now: @Sendable () -> Date
    private var index: [String: ImageCacheEntry]?

    public init(directory: URL, byteLimit: Int = ImageDiskCache.defaultByteLimit, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.byteLimit = byteLimit
        self.now = now
    }

    public func contains(_ key: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(key).path)
    }

    public func read(_ key: String) -> Data? {
        let url = fileURL(key)
        guard let data = try? Data(contentsOf: url) else {
            forget(key)
            return nil
        }
        let accessed = now()
        try? FileManager.default.setAttributes([.modificationDate: accessed], ofItemAtPath: url.path)
        record(ImageCacheEntry(key: key, byteCount: data.count, lastAccess: accessed))
        return data
    }

    /// Stores `data`, then evicts the least recently used files until the cache fits. Data larger than the
    /// whole cache is not stored.
    public func write(_ data: Data, key: String) {
        guard data.count <= byteLimit else {
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = fileURL(key)
        guard (try? data.write(to: url, options: .atomic)) != nil else {
            return
        }
        let written = now()
        try? FileManager.default.setAttributes([.modificationDate: written], ofItemAtPath: url.path)
        record(ImageCacheEntry(key: key, byteCount: data.count, lastAccess: written))
        trim()
    }

    public func remove(_ key: String) {
        try? FileManager.default.removeItem(at: fileURL(key))
        forget(key)
    }

    public func totalBytes() -> Int {
        loadedIndex().values.reduce(0) { $0 + $1.byteCount }
    }

    private func trim() {
        let entries = loadedIndex()
        guard entries.values.reduce(0, { $0 + $1.byteCount }) > byteLimit else {
            return
        }
        for key in ImageCacheEvictionPolicy.evictions(from: Array(entries.values), limitBytes: byteLimit) {
            remove(key)
        }
    }

    /// The in-memory listing, read from the folder the first time it is needed.
    private func loadedIndex() -> [String: ImageCacheEntry] {
        if let index {
            return index
        }
        let listed = Dictionary(uniqueKeysWithValues: entries().map { ($0.key, $0) })
        index = listed
        return listed
    }

    private func record(_ entry: ImageCacheEntry) {
        _ = loadedIndex()
        index?[entry.key] = entry
    }

    /// Drops `key` from the listing; a listing not read yet will not contain it.
    private func forget(_ key: String) {
        index?[key] = nil
    }

    private func entries() -> [ImageCacheEntry] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return urls.map { Self.entry(url: $0, values: try? $0.resourceValues(forKeys: Set(keys))) }
    }

    /// A file whose size or date cannot be read counts as empty and oldest, so it is evicted first.
    static func entry(url: URL, values: URLResourceValues?) -> ImageCacheEntry {
        ImageCacheEntry(
            key: url.lastPathComponent,
            byteCount: values?.fileSize ?? 0,
            lastAccess: values?.contentModificationDate ?? .distantPast
        )
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent(key, isDirectory: false)
    }
}
