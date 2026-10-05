import CoreGraphics
import Foundation

public protocol ImageDataFetching: Sendable {
    func fetch(_ url: URL) async throws -> Data
}

public enum ImageFetchError: Error, Equatable, Sendable {
    case badResponse
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
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ImageFetchError.badResponse
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

    func insert(_ image: CGImage, url: URL, maxPixelSize: Int) {
        cache.setObject(DecodedImageBox(image), forKey: memoryKey(url, maxPixelSize) as NSString, cost: image.width * image.height * 4)
    }

    private func memoryKey(_ url: URL, _ maxPixelSize: Int) -> String {
        ImageCacheKey.memoryKey(key: ImageCacheKey.key(for: url), maxPixelSize: maxPixelSize)
    }
}

/// Loads remote images through memory, then disk, then network. Concurrent requests for one URL share a
/// single download; a download is cancelled only when every caller waiting on it has gone, and a cancelled
/// or failed download stores nothing.
public actor ImagePipeline {
    private struct Download {
        let task: Task<Data?, Never>
        var waiters: Int
    }

    public nonisolated let memory: ImageMemoryCache
    private let disk: ImageDiskCache
    private let fetcher: any ImageDataFetching
    private var downloads: [String: Download] = [:]

    public init(disk: ImageDiskCache, fetcher: any ImageDataFetching, memory: ImageMemoryCache = ImageMemoryCache()) {
        self.disk = disk
        self.fetcher = fetcher
        self.memory = memory
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
        if let cached = memory.image(url: url, maxPixelSize: maxPixelSize) {
            return cached
        }
        let key = ImageCacheKey.key(for: url)
        guard let data = await data(for: url, key: key), !Task.isCancelled else {
            return nil
        }
        guard let image = ImageDownsampler.downsample(data, maxPixelSize: maxPixelSize) else {
            await disk.remove(key)
            return nil
        }
        memory.insert(image, url: url, maxPixelSize: maxPixelSize)
        return image
    }

    /// Downloads `urls` to disk (not memory) so later views open instantly, in the background.
    public nonisolated func prefetch(_ urls: [URL]) {
        Task(priority: .utility) {
            for url in urls {
                await self.warm(url)
            }
        }
    }

    func warm(_ url: URL) async {
        let key = ImageCacheKey.key(for: url)
        if await disk.contains(key) {
            return
        }
        _ = await data(for: url, key: key)
    }

    private func data(for url: URL, key: String) async -> Data? {
        if let stored = await disk.read(key) {
            return stored
        }
        let task: Task<Data?, Never>
        if var existing = downloads[key] {
            existing.waiters += 1
            downloads[key] = existing
            task = existing.task
        } else {
            task = Task { [fetcher, disk] in
                guard let data = try? await fetcher.fetch(url), !Task.isCancelled else {
                    return nil
                }
                await disk.write(data, key: key)
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
        return data
    }

    private func release(key: String, task: Task<Data?, Never>) {
        if var download = downloads[key], download.task == task {
            download.waiters -= 1
            if download.waiters == 0 {
                download.task.cancel()
                downloads[key] = nil
            } else {
                downloads[key] = download
            }
        }
    }
}
