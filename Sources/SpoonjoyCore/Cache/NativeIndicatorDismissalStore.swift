import Foundation

public enum NativeIndicatorDismissalError: Error, Equatable, Sendable {
    case severeDisplayCannotBePersisted(OfflineIndicatorDisplay)
}

public struct NativeIndicatorDismissal: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let hiddenDisplay: OfflineIndicatorDisplay
    public let dismissedAt: Date
    public let cacheFingerprint: String

    public init(
        accountID: String,
        environment: NativeCacheEnvironment,
        hiddenDisplay: OfflineIndicatorDisplay,
        dismissedAt: Date,
        cacheFingerprint: String
    ) {
        self.accountID = accountID
        self.environment = environment
        self.hiddenDisplay = hiddenDisplay
        self.dismissedAt = dismissedAt
        self.cacheFingerprint = cacheFingerprint
    }

    public func copy(hiddenDisplay: OfflineIndicatorDisplay? = nil) -> NativeIndicatorDismissal {
        NativeIndicatorDismissal(
            accountID: accountID,
            environment: environment,
            hiddenDisplay: hiddenDisplay ?? self.hiddenDisplay,
            dismissedAt: dismissedAt,
            cacheFingerprint: cacheFingerprint
        )
    }
}

public struct NativeIndicatorDismissalStore: Equatable, Sendable {
    public static let nonPersistableDisplayKinds = [
        "queuedWork",
        "syncFailure",
        "conflict",
        "blocker",
        "destructiveConfirmation"
    ]

    private var dismissals: [NativeIndicatorDismissal]

    public init(dismissals: [NativeIndicatorDismissal] = []) {
        self.dismissals = dismissals
    }

    public mutating func persist(_ dismissal: NativeIndicatorDismissal) throws {
        guard dismissal.hiddenDisplay.informationalOnly else {
            throw NativeIndicatorDismissalError.severeDisplayCannotBePersisted(dismissal.hiddenDisplay)
        }

        dismissals.removeAll {
            $0.accountID == dismissal.accountID &&
                $0.environment == dismissal.environment &&
                $0.hiddenDisplay == dismissal.hiddenDisplay
        }
        dismissals.append(dismissal)
    }

    public func isHidden(
        _ display: OfflineIndicatorDisplay,
        accountID: String,
        environment: NativeCacheEnvironment,
        cacheFingerprint: String
    ) -> Bool {
        guard display.informationalOnly else {
            return false
        }

        return dismissals.contains {
            $0.accountID == accountID &&
                $0.environment == environment &&
                $0.hiddenDisplay == display &&
                $0.cacheFingerprint == cacheFingerprint
        }
    }
}
