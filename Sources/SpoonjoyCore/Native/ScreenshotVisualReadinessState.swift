import Foundation

public struct ScreenshotVisualReadinessSnapshot: Equatable, Sendable {
    public static let settledEmpty = ScreenshotVisualReadinessSnapshot(
        generation: 0,
        expectedMediaCount: 0,
        loadedMediaCount: 0,
        pendingMediaCount: 0,
        failedMediaCount: 0,
        blockingIndicatorCount: 0,
        isSettled: true
    )

    public let generation: Int
    public let expectedMediaCount: Int
    public let loadedMediaCount: Int
    public let pendingMediaCount: Int
    public let failedMediaCount: Int
    public let blockingIndicatorCount: Int
    public let isSettled: Bool

    public init(
        generation: Int = 0,
        expectedMediaCount: Int,
        loadedMediaCount: Int,
        pendingMediaCount: Int,
        failedMediaCount: Int,
        blockingIndicatorCount: Int,
        isSettled: Bool
    ) {
        self.generation = generation
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

public struct ScreenshotVisualReadinessBlockingToken: Hashable, Sendable {
    public let resourceID: String
    public let instanceID: String

    public init(resourceID: String, instanceID: String = UUID().uuidString) {
        self.resourceID = resourceID
        self.instanceID = instanceID
    }
}

public struct ScreenshotVisualReadinessState: Equatable, Sendable {
    private var generation = 0
    private var expectedMediaTokens: Set<ScreenshotVisualReadinessMediaToken> = []
    private var loadedMediaTokens: Set<ScreenshotVisualReadinessMediaToken> = []
    private var failedMediaTokens: Set<ScreenshotVisualReadinessMediaToken> = []
    private var blockingIndicatorTokens: Set<ScreenshotVisualReadinessBlockingToken> = []

    public init() {}

    public mutating func beginMedia(_ token: ScreenshotVisualReadinessMediaToken) {
        var changed = expectedMediaTokens.insert(token).inserted
        changed = loadedMediaTokens.remove(token) != nil || changed
        changed = failedMediaTokens.remove(token) != nil || changed
        advanceGeneration(if: changed)
    }

    public mutating func finishMedia(_ token: ScreenshotVisualReadinessMediaToken, succeeded: Bool) {
        var changed = expectedMediaTokens.insert(token).inserted
        if succeeded {
            changed = loadedMediaTokens.insert(token).inserted || changed
            changed = failedMediaTokens.remove(token) != nil || changed
        } else {
            changed = loadedMediaTokens.remove(token) != nil || changed
            changed = failedMediaTokens.insert(token).inserted || changed
        }
        advanceGeneration(if: changed)
    }

    public mutating func removeMedia(_ token: ScreenshotVisualReadinessMediaToken) {
        var changed = expectedMediaTokens.remove(token) != nil
        changed = loadedMediaTokens.remove(token) != nil || changed
        changed = failedMediaTokens.remove(token) != nil || changed
        advanceGeneration(if: changed)
    }

    public mutating func beginBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) {
        advanceGeneration(if: blockingIndicatorTokens.insert(token).inserted)
    }

    public mutating func endBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) {
        advanceGeneration(if: blockingIndicatorTokens.remove(token) != nil)
    }

    public var snapshot: ScreenshotVisualReadinessSnapshot {
        let pendingMediaTokens = expectedMediaTokens.subtracting(loadedMediaTokens).subtracting(failedMediaTokens)
        let isSettled = pendingMediaTokens.isEmpty && failedMediaTokens.isEmpty && blockingIndicatorTokens.isEmpty
        return ScreenshotVisualReadinessSnapshot(
            generation: generation,
            expectedMediaCount: expectedMediaTokens.count,
            loadedMediaCount: loadedMediaTokens.count,
            pendingMediaCount: pendingMediaTokens.count,
            failedMediaCount: failedMediaTokens.count,
            blockingIndicatorCount: blockingIndicatorTokens.count,
            isSettled: isSettled
        )
    }

    private mutating func advanceGeneration(if changed: Bool) {
        if changed {
            generation += 1
        }
    }
}
