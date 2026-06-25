import Foundation

public enum NativeCacheFreshnessThreshold: Equatable, Sendable {
    case minutes(Int)
    case hours(Int)
    case locallyAuthoritative

    var seconds: TimeInterval? {
        switch self {
        case .minutes(let minutes):
            TimeInterval(minutes * 60)
        case .hours(let hours):
            TimeInterval(hours * 60 * 60)
        case .locallyAuthoritative:
            nil
        }
    }
}

public enum NativeCacheFreshness: Equatable, Sendable {
    case fresh
    case stale(secondsOverThreshold: Int)
    case locallyAuthoritative
}

public enum NativeCacheRevalidationTrigger: String, Equatable, Sendable {
    case launch
    case foreground
    case accountChanged
    case environmentChanged
    case networkRecovered
    case visibleSurfaceOpened
}

public struct NativeCacheFreshnessPolicy: Equatable, Sendable {
    public static let offlineProductContract = NativeCacheFreshnessPolicy()

    public init() {}

    public func threshold(for domain: NativeCacheDomain) -> NativeCacheFreshnessThreshold {
        switch domain {
        case .accountBootstrap, .settings, .shoppingList:
            .minutes(15)
        case .recipeDetail, .cookbookDetail, .spoonList, .profile, .cookModeBackingData:
            .hours(6)
        case .recipeCatalog, .cookbookList, .searchResults, .notificationPreferences, .tokenMetadata, .connectionStatus, .apnsStatus:
            .hours(24)
        case .cookProgress, .captureDraft, .stagedMedia:
            .locallyAuthoritative
        }
    }

    public func freshness(for record: NativeCacheRecord, now: Date) -> NativeCacheFreshness {
        let threshold = threshold(for: record.metadata.domain)
        guard let thresholdSeconds = threshold.seconds else {
            return .locallyAuthoritative
        }

        let age = now.timeIntervalSince(record.metadata.lastValidatedAt)
        guard age > thresholdSeconds else {
            return .fresh
        }

        return .stale(secondsOverThreshold: Int(age - thresholdSeconds))
    }

    public func revalidationTriggers(for freshness: NativeCacheFreshness) -> [NativeCacheRevalidationTrigger] {
        switch freshness {
        case .stale:
            [.launch, .foreground, .accountChanged, .environmentChanged, .networkRecovered, .visibleSurfaceOpened]
        case .fresh, .locallyAuthoritative:
            []
        }
    }
}
