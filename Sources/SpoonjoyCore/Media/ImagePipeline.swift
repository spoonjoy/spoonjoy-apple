import CoreGraphics
import Foundation
import OSLog

public protocol ImageDataFetching: Sendable {
    func fetch(_ url: URL) async throws -> Data
}

public enum ImageFetchError: Error, Equatable, Sendable {
    /// The response was not HTTP.
    case badResponse
    /// The server answered with a status outside 200-299.
    case status(Int)

    /// Whether trying again could succeed: a timeout, rate limit or server error could; a missing photo
    /// or a refused request will not.
    var isTransient: Bool {
        switch self {
        case .badResponse:
            false
        case let .status(code):
            code == 408 || code == 429 || code >= 500
        }
    }
}

public struct URLSessionImageFetcher: ImageDataFetching {
    private let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    /// A session with no URLCache of its own: the pipeline's disk cache is the single store.
    public static func standard() -> URLSessionImageFetcher {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSessionImageFetcher(session: URLSession(configuration: configuration))
    }

    public func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw ImageFetchError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageFetchError.status(http.statusCode)
        }
        return data
    }
}

private final class DecodedImageBox {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

/// Decoded, downsampled images held in memory, bounded by decoded byte cost.
public final class ImageMemoryCache: @unchecked Sendable {
    public static let defaultCostLimit = 64 * 1_024 * 1_024

    private let cache = NSCache<NSString, DecodedImageBox>()

    public init(costLimit: Int = ImageMemoryCache.defaultCostLimit) {
        cache.totalCostLimit = costLimit
    }

    public func image(url: URL, maxPixelSize: Int) -> CGImage? {
        cache.object(forKey: memoryKey(url, maxPixelSize) as NSString)?.image
    }

    /// The sharpest decode of `url` held at a size below `maxPixelSize`, to show while that size loads.
    public func image(url: URL, below maxPixelSize: Int) -> CGImage? {
        ImageDownsampleBucket.pixelSizes.reversed().lazy
            .filter { $0 < maxPixelSize }
            .compactMap { self.image(url: url, maxPixelSize: $0) }
            .first
    }

    func insert(_ image: CGImage, url: URL, maxPixelSize: Int) {
        cache.setObject(DecodedImageBox(image), forKey: memoryKey(url, maxPixelSize) as NSString, cost: image.width * image.height * 4)
    }

    private func memoryKey(_ url: URL, _ maxPixelSize: Int) -> String {
        ImageCacheKey.memoryKey(key: ImageCacheKey.key(for: url), maxPixelSize: maxPixelSize)
    }
}

/// Loads remote images through memory, then disk, then network.
///
/// - A Spoonjoy photo is downloaded at the stored width that covers the decode size, not as the original.
/// - Concurrent requests for one download share it. When its last caller goes away, the download keeps
///   running for `abandonGrace`, counted from the last caller to leave, so a view that re-renders and asks
///   again picks it up instead of starting over; after that it is cancelled. A cancelled or failed download
///   stores nothing.
/// - A download that fails for a reason that could pass (a dropped connection, a timeout, a server error)
///   is tried again after each of `retryDelays`.
/// - Decoding runs off the pipeline, several at once, so one large image never holds up the others.
public actor ImagePipeline {
    private struct Download {
        let task: Task<Data?, Never>
        var waiters: Int
        /// Counts the times the download lost its last caller, so only the newest grace period can cancel it.
        var abandonments = 0
    }

    public static let defaultRetryDelays: [Duration] = [.milliseconds(500), .seconds(2)]
    public static let defaultAbandonGrace: Duration = .seconds(2)

    public nonisolated let memory: ImageMemoryCache
    private let disk: ImageDiskCache
    private let fetcher: any ImageDataFetching
    private let retryDelays: [Duration]
    private let abandonGrace: Duration
    private var downloads: [String: Download] = [:]

    public init(
        disk: ImageDiskCache,
        fetcher: any ImageDataFetching,
        memory: ImageMemoryCache = ImageMemoryCache(),
        retryDelays: [Duration] = ImagePipeline.defaultRetryDelays,
        abandonGrace: Duration = ImagePipeline.defaultAbandonGrace
    ) {
        self.disk = disk
        self.fetcher = fetcher
        self.memory = memory
        self.retryDelays = retryDelays
        self.abandonGrace = abandonGrace
    }

    /// The production pipeline: a bounded disk cache under `cachesDirectory`.
    public static func standard(
        cachesDirectory: URL,
        fetcher: any ImageDataFetching = URLSessionImageFetcher.standard()
    ) -> ImagePipeline {
        ImagePipeline(
            disk: ImageDiskCache(directory: cachesDirectory.appendingPathComponent("SpoonjoyImages", isDirectory: true)),
            fetcher: fetcher
        )
    }

    /// The image for `url` decoded to at most `maxPixelSize`, or nil when it cannot be loaded or the caller
    /// was cancelled.
    public func image(for url: URL, maxPixelSize: Int) async -> CGImage? {
        let started = ContinuousClock.now
        if let cached = memory.image(url: url, maxPixelSize: maxPixelSize) {
            Self.log(url: url, maxPixelSize: maxPixelSize, outcome: "memory", bytes: 0, started: started, decode: .zero)
            return cached
        }
        let source = ImageVariant.url(for: url, maxPixelSize: maxPixelSize)
        let key = ImageCacheKey.key(for: source)
        guard let loaded = await data(for: source, key: key), !Task.isCancelled else {
            Self.log(url: source, maxPixelSize: maxPixelSize, outcome: Task.isCancelled ? "cancelled" : "failed", bytes: 0, started: started, decode: .zero)
            return nil
        }
        let decodeStarted = ContinuousClock.now
        guard let image = await Self.decode(loaded.data, maxPixelSize: maxPixelSize) else {
            await disk.remove(key)
            Self.log(url: source, maxPixelSize: maxPixelSize, outcome: "undecodable", bytes: loaded.data.count, started: started, decode: .zero)
            return nil
        }
        memory.insert(image, url: url, maxPixelSize: maxPixelSize)
        Self.log(url: source, maxPixelSize: maxPixelSize, outcome: loaded.source, bytes: loaded.data.count, started: started, decode: ContinuousClock.now - decodeStarted)
        return image
    }

    @concurrent
    private static func decode(_ data: Data, maxPixelSize: Int) async -> CGImage? {
        ImageDownsampler.downsample(data, maxPixelSize: maxPixelSize)
    }

    private static let logger = Logger(subsystem: "app.spoonjoy", category: "image-pipeline")

    /// One line per load, so image loading can be measured from the unified log.
    private static func log(url: URL, maxPixelSize: Int, outcome: String, bytes: Int, started: ContinuousClock.Instant, decode: Duration) {
        let path = logPath(url)
        let total = (ContinuousClock.now - started).milliseconds
        logger.info("image-load path=\(path, privacy: .public) px=\(maxPixelSize) outcome=\(outcome, privacy: .public) bytes=\(bytes) ms=\(total) decodeMs=\(decode.milliseconds)")
    }

    /// The path and query of `url`, without its host.
    private static func logPath(_ url: URL) -> String {
        url.query.map { "\(url.path)?\($0)" } ?? url.path
    }

    /// One line per network transfer: `complete`, `failed`, or `aborted` (cancelled after its grace period;
    /// `bytes` counts any body received and then thrown away). `image-load` lines are per caller instead, so a
    /// caller that leaves logs `cancelled` there while the transfer it was waiting on may still complete.
    private static func logDownload(url: URL, outcome: String, bytes: Int, started: ContinuousClock.Instant) {
        let path = logPath(url)
        logger.info("image-download path=\(path, privacy: .public) outcome=\(outcome, privacy: .public) bytes=\(bytes) ms=\((ContinuousClock.now - started).milliseconds)")
    }

    /// Downloads `urls`, at the size they will be shown at, to disk (not memory) so later views open
    /// instantly, in the background.
    public nonisolated func prefetch(_ urls: [URL], maxPixelSize: Int) {
        Task(priority: .utility) {
            for url in urls {
                await self.warm(url, maxPixelSize: maxPixelSize)
            }
        }
    }

    func warm(_ url: URL, maxPixelSize: Int) async {
        let source = ImageVariant.url(for: url, maxPixelSize: maxPixelSize)
        let key = ImageCacheKey.key(for: source)
        if await disk.contains(key) {
            return
        }
        _ = await data(for: source, key: key)
    }

    private func data(for url: URL, key: String) async -> (data: Data, source: String)? {
        if let stored = await disk.read(key) {
            return (stored, "disk")
        }
        let task: Task<Data?, Never>
        if var existing = downloads[key] {
            existing.waiters += 1
            downloads[key] = existing
            task = existing.task
        } else {
            task = Task { [fetcher, disk, retryDelays] in
                let started = ContinuousClock.now
                let data = await Self.fetch(url, with: fetcher, retryDelays: retryDelays)
                guard let data, !Task.isCancelled else {
                    Self.logDownload(url: url, outcome: Task.isCancelled ? "aborted" : "failed", bytes: data?.count ?? 0, started: started)
                    return nil
                }
                await disk.write(data, key: key)
                Self.logDownload(url: url, outcome: "complete", bytes: data.count, started: started)
                return data
            }
            downloads[key] = Download(task: task, waiters: 1)
        }
        let data = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { await self.release(key: key, task: task) }
        }
        if downloads[key]?.task == task {
            downloads[key] = nil
        }
        return data.map { ($0, "network") }
    }

    /// The bytes at `url`, trying again after each delay while the failure could pass.
    private static func fetch(_ url: URL, with fetcher: any ImageDataFetching, retryDelays: [Duration]) async -> Data? {
        do {
            return try await fetcher.fetch(url)
        } catch {
            guard
                !Task.isCancelled,
                (error as? ImageFetchError)?.isTransient ?? true,
                let delay = retryDelays.first,
                (try? await Task.sleep(for: delay)) != nil
            else {
                return nil
            }
            return await fetch(url, with: fetcher, retryDelays: Array(retryDelays.dropFirst()))
        }
    }

    /// One caller stopped waiting. The download may already have finished and been cleared.
    private func release(key: String, task: Task<Data?, Never>) {
        if var download = downloads[key], download.task == task {
            download.waiters -= 1
            if download.waiters == 0 {
                download.abandonments += 1
                let abandonment = download.abandonments
                Task { [abandonGrace] in
                    try? await Task.sleep(for: abandonGrace)
                    self.cancelIfAbandoned(key: key, task: task, abandonment: abandonment)
                }
            }
            downloads[key] = download
        }
    }

    /// Cancels a download nobody has asked for again during the grace period, unless it already finished
    /// or a caller joined and left since, which started a newer grace period.
    private func cancelIfAbandoned(key: String, task: Task<Data?, Never>, abandonment: Int) {
        if let download = downloads[key], download.task == task, download.waiters == 0, download.abandonments == abandonment {
            task.cancel()
            downloads[key] = nil
        }
    }
}

extension Duration {
    var milliseconds: Int {
        Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000)
    }
}
