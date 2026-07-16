import Foundation

public struct ScreenshotVisualReadinessSnapshot: Equatable, Sendable {
    public static let settledEmpty = ScreenshotVisualReadinessSnapshot(
        expectedMediaCount: 0,
        loadedMediaCount: 0,
        pendingMediaCount: 0,
        failedMediaCount: 0,
        blockingIndicatorCount: 0,
        isSettled: true
    )

    public let expectedMediaCount: Int
    public let loadedMediaCount: Int
    public let pendingMediaCount: Int
    public let failedMediaCount: Int
    public let blockingIndicatorCount: Int
    public let isSettled: Bool

    public init(
        expectedMediaCount: Int,
        loadedMediaCount: Int,
        pendingMediaCount: Int,
        failedMediaCount: Int,
        blockingIndicatorCount: Int,
        isSettled: Bool
    ) {
        self.expectedMediaCount = expectedMediaCount
        self.loadedMediaCount = loadedMediaCount
        self.pendingMediaCount = pendingMediaCount
        self.failedMediaCount = failedMediaCount
        self.blockingIndicatorCount = blockingIndicatorCount
        self.isSettled = isSettled
    }
}

public struct ScreenshotVisualReadinessState: Equatable, Sendable {
    private var expectedMediaIDs: Set<String> = []
    private var loadedMediaIDs: Set<String> = []
    private var failedMediaIDs: Set<String> = []
    private var blockingIndicatorIDs: Set<String> = []

    public init() {}

    public mutating func beginMedia(_ id: String) {
        expectedMediaIDs.insert(id)
        loadedMediaIDs.remove(id)
        failedMediaIDs.remove(id)
    }

    public mutating func finishMedia(_ id: String, succeeded: Bool) {
        expectedMediaIDs.insert(id)
        if succeeded {
            loadedMediaIDs.insert(id)
            failedMediaIDs.remove(id)
        } else {
            loadedMediaIDs.remove(id)
            failedMediaIDs.insert(id)
        }
    }

    public mutating func removeMedia(_ id: String) {
        expectedMediaIDs.remove(id)
        loadedMediaIDs.remove(id)
        failedMediaIDs.remove(id)
    }

    public mutating func beginBlockingIndicator(_ id: String) {
        blockingIndicatorIDs.insert(id)
    }

    public mutating func endBlockingIndicator(_ id: String) {
        blockingIndicatorIDs.remove(id)
    }

    public var snapshot: ScreenshotVisualReadinessSnapshot {
        let pendingMediaIDs = expectedMediaIDs.subtracting(loadedMediaIDs).subtracting(failedMediaIDs)
        let isSettled = pendingMediaIDs.isEmpty && failedMediaIDs.isEmpty && blockingIndicatorIDs.isEmpty
        return ScreenshotVisualReadinessSnapshot(
            expectedMediaCount: expectedMediaIDs.count,
            loadedMediaCount: loadedMediaIDs.count,
            pendingMediaCount: pendingMediaIDs.count,
            failedMediaCount: failedMediaIDs.count,
            blockingIndicatorCount: blockingIndicatorIDs.count,
            isSettled: isSettled
        )
    }
}
