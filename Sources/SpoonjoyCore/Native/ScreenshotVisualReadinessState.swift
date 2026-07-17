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

public struct ScreenshotVisualReadinessMediaToken: Hashable, Sendable {
    public let resourceID: String
    public let instanceID: String

    public init(resourceID: String, instanceID: String = UUID().uuidString) {
        self.resourceID = resourceID
        self.instanceID = instanceID
    }
}

public struct ScreenshotVisualReadinessState: Equatable, Sendable {
    private var expectedMediaTokens: Set<ScreenshotVisualReadinessMediaToken> = []
    private var loadedMediaTokens: Set<ScreenshotVisualReadinessMediaToken> = []
    private var failedMediaTokens: Set<ScreenshotVisualReadinessMediaToken> = []
    private var blockingIndicatorIDs: Set<String> = []

    public init() {}

    public mutating func beginMedia(_ token: ScreenshotVisualReadinessMediaToken) {
        expectedMediaTokens.insert(token)
        loadedMediaTokens.remove(token)
        failedMediaTokens.remove(token)
    }

    public mutating func finishMedia(_ token: ScreenshotVisualReadinessMediaToken, succeeded: Bool) {
        expectedMediaTokens.insert(token)
        if succeeded {
            loadedMediaTokens.insert(token)
            failedMediaTokens.remove(token)
        } else {
            loadedMediaTokens.remove(token)
            failedMediaTokens.insert(token)
        }
    }

    public mutating func removeMedia(_ token: ScreenshotVisualReadinessMediaToken) {
        expectedMediaTokens.remove(token)
        loadedMediaTokens.remove(token)
        failedMediaTokens.remove(token)
    }

    public mutating func beginBlockingIndicator(_ id: String) {
        blockingIndicatorIDs.insert(id)
    }

    public mutating func endBlockingIndicator(_ id: String) {
        blockingIndicatorIDs.remove(id)
    }

    public var snapshot: ScreenshotVisualReadinessSnapshot {
        let pendingMediaTokens = expectedMediaTokens.subtracting(loadedMediaTokens).subtracting(failedMediaTokens)
        let isSettled = pendingMediaTokens.isEmpty && failedMediaTokens.isEmpty && blockingIndicatorIDs.isEmpty
        return ScreenshotVisualReadinessSnapshot(
            expectedMediaCount: expectedMediaTokens.count,
            loadedMediaCount: loadedMediaTokens.count,
            pendingMediaCount: pendingMediaTokens.count,
            failedMediaCount: failedMediaTokens.count,
            blockingIndicatorCount: blockingIndicatorIDs.count,
            isSettled: isSettled
        )
    }
}
