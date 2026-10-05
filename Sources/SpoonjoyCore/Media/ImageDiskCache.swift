import Foundation

/// Original image bytes on disk (in Caches), bounded by `byteLimit` and trimmed least-recently-used.
/// A read refreshes the file's modification date, which serves as its access date.
public actor ImageDiskCache {
    public static let defaultByteLimit = 200 * 1_024 * 1_024

    private let directory: URL
    private let byteLimit: Int
    private let now: @Sendable () -> Date

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
            return nil
        }
        try? FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: url.path)
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
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: url.path)
        trim()
    }

    public func remove(_ key: String) {
        try? FileManager.default.removeItem(at: fileURL(key))
    }

    public func totalBytes() -> Int {
        entries().reduce(0) { $0 + $1.byteCount }
    }

    private func trim() {
        for key in ImageCacheEvictionPolicy.evictions(from: entries(), limitBytes: byteLimit) {
            remove(key)
        }
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
