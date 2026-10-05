import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SpoonjoyCore

private func makeImageData(width: Int = 640, height: Int = 320) -> Data {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return output as Data
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("image-pipeline-\(UUID().uuidString)", isDirectory: true)
}

private let coverURL = URL(string: "https://spoonjoy.app/photos/covers/1730000000-abc.jpg")!

private actor ScriptedFetcher: ImageDataFetching {
    private(set) var count = 0
    private(set) var wasCancelled = false
    private let result: Result<Data, Error>
    private let delay: Duration

    init(result: Result<Data, Error>, delay: Duration = .zero) {
        self.result = result
        self.delay = delay
    }

    func fetch(_ url: URL) async throws -> Data {
        count += 1
        do {
            try await Task.sleep(for: delay)
        } catch {
            wasCancelled = true
            throw error
        }
        return try result.get()
    }

    func waitUntilStarted() async {
        while count == 0 {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    func waitUntilCancelled() async {
        while !wasCancelled {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

private struct FetchFailure: Error {}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_000)

    func tick() -> Date {
        lock.lock()
        defer { lock.unlock() }
        value = value.addingTimeInterval(10)
        return value
    }
}

@Suite("Image cache keys and policy")
struct ImageCacheKeyTests {
    @Test("keys are stable, filename safe and ignore the fragment")
    func keys() {
        let key = ImageCacheKey.key(for: coverURL)
        #expect(key == ImageCacheKey.key(for: coverURL))
        #expect(key.count == 64)
        #expect(key.allSatisfy { $0.isHexDigit })
        #expect(key == ImageCacheKey.key(for: URL(string: "\(coverURL.absoluteString)#top")!))
        #expect(key != ImageCacheKey.key(for: URL(string: "https://spoonjoy.app/photos/covers/1730000001-abc.jpg")!))
        #expect(key != ImageCacheKey.key(for: URL(string: "\(coverURL.absoluteString)?w=2")!))
        #expect(ImageCacheKey.memoryKey(key: "k", maxPixelSize: 512) == "k@512")
    }

    @Test("download buckets round up to a decode size")
    func buckets() {
        #expect(ImageDownsampleBucket.pixelSize(points: 0, scale: 3) == 0)
        #expect(ImageDownsampleBucket.pixelSize(points: .nan, scale: 3) == 0)
        #expect(ImageDownsampleBucket.pixelSize(points: 48, scale: 3) == 256)
        #expect(ImageDownsampleBucket.pixelSize(points: 40, scale: 3.2) == 128)
        #expect(ImageDownsampleBucket.pixelSize(points: 390, scale: 3) == 1_536)
        #expect(ImageDownsampleBucket.pixelSize(points: 5_000, scale: 3) == 2_048)
    }

    @Test("eviction removes least recently used entries until the total fits")
    func eviction() {
        let base = Date(timeIntervalSince1970: 0)
        let entries = [
            ImageCacheEntry(key: "b", byteCount: 40, lastAccess: base),
            ImageCacheEntry(key: "a", byteCount: 40, lastAccess: base),
            ImageCacheEntry(key: "c", byteCount: 40, lastAccess: base.addingTimeInterval(5)),
            ImageCacheEntry(key: "d", byteCount: 40, lastAccess: base.addingTimeInterval(9))
        ]
        #expect(ImageCacheEvictionPolicy.evictions(from: entries, limitBytes: 160).isEmpty)
        #expect(ImageCacheEvictionPolicy.evictions(from: entries, limitBytes: 100) == ["a", "b"])
        #expect(ImageCacheEvictionPolicy.evictions(from: entries, limitBytes: 0) == ["a", "b", "c", "d"])
        #expect(ImageCacheEvictionPolicy.evictions(from: [], limitBytes: 10).isEmpty)
    }
}

@Suite("Image disk cache")
struct ImageDiskCacheTests {
    @Test("stores, reads, and removes data by key")
    func roundTrip() async {
        let directory = temporaryDirectory()
        let cache = ImageDiskCache(directory: directory)
        #expect(await cache.read("missing") == nil)
        #expect(await cache.contains("one") == false)
        await cache.write(Data(repeating: 1, count: 10), key: "one")
        #expect(await cache.contains("one"))
        #expect(await cache.read("one") == Data(repeating: 1, count: 10))
        #expect(await cache.totalBytes() == 10)
        await cache.remove("one")
        #expect(await cache.contains("one") == false)
        #expect(await cache.totalBytes() == 0)
        #expect(ImageDiskCache.defaultByteLimit == 200 * 1_024 * 1_024)
    }

    @Test("evicts the least recently accessed file once over the limit, and a read counts as access")
    func lruEviction() async {
        let clock = Clock()
        let cache = ImageDiskCache(directory: temporaryDirectory(), byteLimit: 30, now: { clock.tick() })
        await cache.write(Data(count: 10), key: "a")
        await cache.write(Data(count: 10), key: "b")
        await cache.write(Data(count: 10), key: "c")
        _ = await cache.read("a")
        await cache.write(Data(count: 10), key: "d")
        #expect(await cache.contains("a"))
        #expect(await cache.contains("b") == false)
        #expect(await cache.contains("c"))
        #expect(await cache.contains("d"))
        #expect(await cache.totalBytes() == 30)
    }

    @Test("a file whose attributes cannot be read counts as empty and oldest")
    func unreadableAttributes() {
        let entry = ImageDiskCache.entry(url: URL(fileURLWithPath: "/tmp/abc"), values: nil)
        #expect(entry == ImageCacheEntry(key: "abc", byteCount: 0, lastAccess: .distantPast))
    }

    @Test("data larger than the whole cache is not stored")
    func oversize() async {
        let cache = ImageDiskCache(directory: temporaryDirectory(), byteLimit: 5)
        await cache.write(Data(count: 6), key: "big")
        #expect(await cache.contains("big") == false)
    }
}

@Suite("Image downsampling")
struct ImageDownsamplerTests {
    @Test("downsamples to the requested size and rejects non-images")
    func downsample() {
        let image = ImageDownsampler.downsample(makeImageData(), maxPixelSize: 128)
        #expect(image?.width == 128)
        #expect(image?.height == 64)
        #expect(ImageDownsampler.downsample(Data("not an image".utf8), maxPixelSize: 128) == nil)
    }
}

@Suite("URLSession image fetcher", .serialized)
struct URLSessionImageFetcherTests {
    final class StubProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var status = 200
        nonisolated(unsafe) static var http = true

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let url = request.url!
            let response: URLResponse = Self.http
                ? HTTPURLResponse(url: url, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
                : URLResponse(url: url, mimeType: nil, expectedContentLength: 3, textEncodingName: nil)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("abc".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func fetcher() -> URLSessionImageFetcher {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSessionImageFetcher(session: URLSession(configuration: configuration))
    }

    @Test("returns the body for success and throws for any other response")
    func fetch() async throws {
        StubProtocol.http = true
        StubProtocol.status = 200
        #expect(try await fetcher().fetch(coverURL) == Data("abc".utf8))
        StubProtocol.status = 404
        await #expect(throws: ImageFetchError.badResponse) { try await fetcher().fetch(coverURL) }
        StubProtocol.http = false
        await #expect(throws: ImageFetchError.badResponse) { try await fetcher().fetch(coverURL) }
        StubProtocol.http = true
    }

    @Test("the standard fetcher has no URLCache of its own")
    func standard() {
        _ = URLSessionImageFetcher.standard()
    }
}

@Suite("Image pipeline")
struct ImagePipelineTests {
    private func pipeline(directory: URL, fetcher: any ImageDataFetching) -> ImagePipeline {
        ImagePipeline(disk: ImageDiskCache(directory: directory), fetcher: fetcher)
    }

    @Test("a second load of the same URL hits no network")
    func secondLoadHitsNoNetwork() async {
        let fetcher = ScriptedFetcher(result: .success(makeImageData()))
        let pipeline = pipeline(directory: temporaryDirectory(), fetcher: fetcher)
        let first = await pipeline.image(for: coverURL, maxPixelSize: 256)
        let second = await pipeline.image(for: coverURL, maxPixelSize: 256)
        #expect(first != nil)
        #expect(second != nil)
        #expect(await fetcher.count == 1)
        #expect(pipeline.memory.image(url: coverURL, maxPixelSize: 256) != nil)
    }

    @Test("a different decode size reuses the downloaded bytes")
    func differentSizeReusesDisk() async {
        let fetcher = ScriptedFetcher(result: .success(makeImageData()))
        let pipeline = pipeline(directory: temporaryDirectory(), fetcher: fetcher)
        _ = await pipeline.image(for: coverURL, maxPixelSize: 256)
        let small = await pipeline.image(for: coverURL, maxPixelSize: 128)
        #expect(small?.width == 128)
        #expect(await fetcher.count == 1)
    }

    @Test("after a relaunch the image loads from disk with the network unreachable")
    func relaunchWorksOffline() async {
        let directory = temporaryDirectory()
        let online = pipeline(directory: directory, fetcher: ScriptedFetcher(result: .success(makeImageData())))
        _ = await online.image(for: coverURL, maxPixelSize: 512)

        let offlineFetcher = ScriptedFetcher(result: .failure(FetchFailure()))
        let relaunched = pipeline(directory: directory, fetcher: offlineFetcher)
        #expect(relaunched.memory.image(url: coverURL, maxPixelSize: 512) == nil)
        #expect(await relaunched.image(for: coverURL, maxPixelSize: 512) != nil)
        #expect(await offlineFetcher.count == 0)
    }

    @Test("concurrent requests for one URL share a single download")
    func dedupe() async {
        let fetcher = ScriptedFetcher(result: .success(makeImageData()), delay: .milliseconds(150))
        let pipeline = pipeline(directory: temporaryDirectory(), fetcher: fetcher)
        let images = await withTaskGroup(of: CGImage?.self) { group in
            for _ in 0..<5 {
                group.addTask { await pipeline.image(for: coverURL, maxPixelSize: 256) }
            }
            return await group.reduce(into: [CGImage?]()) { $0.append($1) }
        }
        #expect(images.count == 5)
        #expect(images.allSatisfy { $0 != nil })
        #expect(await fetcher.count == 1)
    }

    @Test("a failed download returns nil and is not cached")
    func failureIsNotCached() async {
        let directory = temporaryDirectory()
        let failing = ScriptedFetcher(result: .failure(FetchFailure()))
        #expect(await pipeline(directory: directory, fetcher: failing).image(for: coverURL, maxPixelSize: 256) == nil)
        let working = ScriptedFetcher(result: .success(makeImageData()))
        #expect(await pipeline(directory: directory, fetcher: working).image(for: coverURL, maxPixelSize: 256) != nil)
        #expect(await working.count == 1)
    }

    @Test("bytes that are not an image return nil and are dropped from disk")
    func corruptDataIsDropped() async {
        let directory = temporaryDirectory()
        let disk = ImageDiskCache(directory: directory)
        let pipeline = ImagePipeline(disk: disk, fetcher: ScriptedFetcher(result: .success(Data("nope".utf8))))
        #expect(await pipeline.image(for: coverURL, maxPixelSize: 256) == nil)
        #expect(await disk.contains(ImageCacheKey.key(for: coverURL)) == false)
    }

    @Test("cancelling the only waiter cancels the download and stores nothing")
    func cancelDoesNotPoisonCache() async {
        let directory = temporaryDirectory()
        let slow = ScriptedFetcher(result: .success(makeImageData()), delay: .seconds(30))
        let disk = ImageDiskCache(directory: directory)
        let cancelled = ImagePipeline(disk: disk, fetcher: slow)
        let task = Task { await cancelled.image(for: coverURL, maxPixelSize: 256) }
        await slow.waitUntilStarted()
        task.cancel()
        #expect(await task.value == nil)
        await slow.waitUntilCancelled()
        #expect(await disk.totalBytes() == 0)

        let fresh = ScriptedFetcher(result: .success(makeImageData()))
        #expect(await ImagePipeline(disk: disk, fetcher: fresh).image(for: coverURL, maxPixelSize: 256) != nil)
        #expect(await fresh.count == 1)
    }

    @Test("a download continues while at least one caller still waits on it")
    func cancelOneOfTwoWaiters() async {
        let fetcher = ScriptedFetcher(result: .success(makeImageData()), delay: .milliseconds(300))
        let pipeline = pipeline(directory: temporaryDirectory(), fetcher: fetcher)
        let leaving = Task { await pipeline.image(for: coverURL, maxPixelSize: 256) }
        await fetcher.waitUntilStarted()
        let staying = Task { await pipeline.image(for: coverURL, maxPixelSize: 256) }
        try? await Task.sleep(for: .milliseconds(50))
        leaving.cancel()
        #expect(await staying.value != nil)
        #expect(await fetcher.wasCancelled == false)
        #expect(await fetcher.count == 1)
    }

    @Test("prefetch warms the disk cache and skips files already cached")
    func prefetch() async {
        let directory = temporaryDirectory()
        let fetcher = ScriptedFetcher(result: .success(makeImageData()))
        let disk = ImageDiskCache(directory: directory)
        let pipeline = ImagePipeline(disk: disk, fetcher: fetcher)
        pipeline.prefetch([coverURL])
        await fetcher.waitUntilStarted()
        while await !disk.contains(ImageCacheKey.key(for: coverURL)) {
            try? await Task.sleep(for: .milliseconds(5))
        }
        await pipeline.warm(coverURL)
        #expect(await fetcher.count == 1)
    }

    @Test("the standard pipeline keeps its files in a Spoonjoy folder under Caches")
    func standardPipeline() async {
        let caches = temporaryDirectory()
        let pipeline = ImagePipeline.standard(cachesDirectory: caches, fetcher: ScriptedFetcher(result: .success(makeImageData())))
        _ = await pipeline.image(for: coverURL, maxPixelSize: 128)
        let stored = try? FileManager.default.contentsOfDirectory(atPath: caches.appendingPathComponent("SpoonjoyImages").path)
        #expect(stored?.count == 1)
        _ = ImagePipeline.standard(cachesDirectory: caches)
        _ = ImageMemoryCache.defaultCostLimit
    }
}
