import Foundation

public enum OfflineIndicatorRetryAfter: Codable, Equatable, Hashable, Sendable {
    case seconds(Int)
}

public enum OfflineIndicatorBlocker: Codable, Equatable, Hashable, Sendable {
    case providerSecret(resourceID: String)
    case appleDeveloperProgram(capability: String)
}

public enum OfflineIndicatorDismissalReason: String, Codable, Equatable, Hashable, Sendable {
    case informationalOnly
}

public indirect enum OfflineIndicatorDisplay: Codable, Equatable, Hashable, Sendable {
    case synced
    case offline
    case stale(domain: NativeCacheDomain)
    case dismissed(previous: OfflineIndicatorDisplay, reason: OfflineIndicatorDismissalReason)
    case queuedWork(count: Int, oldestClientMutationID: String?)
    case syncFailure(errorID: String, retryAfter: OfflineIndicatorRetryAfter?)
    case conflict(recordID: String, mutationID: String)
    case blocker(OfflineIndicatorBlocker)
    case destructiveConfirmation(actionID: String)

    public var informationalOnly: Bool {
        switch self {
        case .synced, .offline, .stale:
            true
        case .dismissed(let previous, _):
            previous.informationalOnly
        case .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            false
        }
    }

    public var isVisible: Bool {
        switch self {
        case .synced, .dismissed:
            false
        case .offline, .stale, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            true
        }
    }
}

public struct OfflineIndicatorState: Codable, Equatable, Hashable, Sendable {
    public let display: OfflineIndicatorDisplay
    public let dismissal: NativeIndicatorDismissal?

    public var isVisible: Bool {
        display.isVisible
    }

    public static func synced(lastSyncedAt _: Date) -> OfflineIndicatorState {
        OfflineIndicatorState(display: .synced, dismissal: nil)
    }
}

public enum OfflineIndicatorEvent: Equatable, Sendable {
    case networkUnavailable(at: Date)
    case cacheBecameStale(domain: NativeCacheDomain, at: Date, cacheFingerprint: String)
    case queuedWorkChanged(count: Int, oldestClientMutationID: String?)
    case syncFailed(errorID: String, retryAfter: OfflineIndicatorRetryAfter?)
    case conflictDetected(recordID: String, mutationID: String)
    case blockerDetected(kind: OfflineIndicatorBlocker)
    case destructiveConfirmationRequired(actionID: String)
    case dismissCurrentIndicator(at: Date, cacheFingerprint: String)
    case severeStateResolved(at: Date)
}

public struct OfflineIndicatorReducer: Equatable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment

    public init(accountID: String, environment: NativeCacheEnvironment) {
        self.accountID = accountID
        self.environment = environment
    }

    public func reduce(_ state: OfflineIndicatorState, _ event: OfflineIndicatorEvent) -> OfflineIndicatorState {
        switch event {
        case .networkUnavailable:
            return OfflineIndicatorState(display: .offline, dismissal: nil)
        case .cacheBecameStale(let domain, let date, let cacheFingerprint):
            let stale = OfflineIndicatorDisplay.stale(domain: domain)
            if let dismissal = state.dismissal,
               dismissal.hiddenDisplay == .offline,
               dismissal.accountID == accountID,
               dismissal.environment == environment {
                return dismissed(stale, at: date, cacheFingerprint: cacheFingerprint)
            }
            return OfflineIndicatorState(display: stale, dismissal: nil)
        case .queuedWorkChanged(let count, let oldestClientMutationID):
            return OfflineIndicatorState(
                display: .queuedWork(count: count, oldestClientMutationID: oldestClientMutationID),
                dismissal: nil
            )
        case .syncFailed(let errorID, let retryAfter):
            return OfflineIndicatorState(display: .syncFailure(errorID: errorID, retryAfter: retryAfter), dismissal: nil)
        case .conflictDetected(let recordID, let mutationID):
            return OfflineIndicatorState(display: .conflict(recordID: recordID, mutationID: mutationID), dismissal: nil)
        case .blockerDetected(let kind):
            return OfflineIndicatorState(display: .blocker(kind), dismissal: nil)
        case .destructiveConfirmationRequired(let actionID):
            return OfflineIndicatorState(display: .destructiveConfirmation(actionID: actionID), dismissal: nil)
        case .dismissCurrentIndicator(let date, let cacheFingerprint):
            guard state.display.informationalOnly, state.display != .synced else {
                return state
            }
            return dismissed(state.display, at: date, cacheFingerprint: cacheFingerprint)
        case .severeStateResolved:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        }
    }

    private func dismissed(
        _ previous: OfflineIndicatorDisplay,
        at date: Date,
        cacheFingerprint: String
    ) -> OfflineIndicatorState {
        let dismissal = NativeIndicatorDismissal(
            accountID: accountID,
            environment: environment,
            hiddenDisplay: previous,
            dismissedAt: date,
            cacheFingerprint: cacheFingerprint
        )
        return OfflineIndicatorState(
            display: .dismissed(previous: previous, reason: .informationalOnly),
            dismissal: dismissal
        )
    }
}
