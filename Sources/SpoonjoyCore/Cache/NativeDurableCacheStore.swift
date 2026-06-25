import Foundation

public enum NativeCacheSecurityError: Error, Equatable, Sendable {
    case bearerToken
    case refreshToken
    case oneTimeTokenValue
    case providerSecret
    case passkey
    case rawMediaPath
    case signedURL
}

public enum NativeCacheRecovery: Equatable, Sendable {
    case corruptCacheQuarantined(originalURL: URL, quarantineSuffix: String)
}

public struct NativeDurableCacheStoreRecord: Equatable, Sendable {
    public let value: NativeDurableCacheSnapshot
    public let source: JSONFileStoreSource
    public let recovery: NativeCacheRecovery?
}

public struct NativeCacheClock: Equatable, Sendable {
    private let currentDate: Date

    public static func fixed(_ date: Date) -> NativeCacheClock {
        NativeCacheClock(currentDate: date)
    }

    public static var system: NativeCacheClock {
        NativeCacheClock(currentDate: Date())
    }

    public var now: Date {
        currentDate
    }
}

public struct NativeDurableCacheStore {
    private let fileURL: URL
    private let clock: NativeCacheClock
    private let store: JSONFileStore<NativeDurableCacheSnapshot>

    public init(fileURL: URL, clock: NativeCacheClock = .system) {
        self.fileURL = fileURL
        self.clock = clock
        self.store = JSONFileStore<NativeDurableCacheSnapshot>(fileURL: fileURL)
    }

    public func save(_ snapshot: NativeDurableCacheSnapshot) throws {
        try rejectSecretMaterial(snapshot)
        try store.save(try snapshot.validatedForRestore())
    }

    public func loadOrRecover(fallback: NativeDurableCacheSnapshot) throws -> NativeDurableCacheStoreRecord {
        do {
            if let record = try store.load() {
                return NativeDurableCacheStoreRecord(
                    value: try record.value.validatedForRestore(),
                    source: record.source,
                    recovery: nil
                )
            }
            return NativeDurableCacheStoreRecord(value: fallback, source: .fallback, recovery: nil)
        } catch {
            let recovery = try corruptCacheQuarantined()
            return NativeDurableCacheStoreRecord(
                value: fallback,
                source: .fallbackAfterCorruption,
                recovery: recovery
            )
        }
    }

    private func rejectSecretMaterial(_ snapshot: NativeDurableCacheSnapshot) throws {
        guard let secret = snapshot.secretMaterial else {
            return
        }

        switch secret {
        case .bearerToken:
            throw NativeCacheSecurityError.bearerToken
        case .refreshToken:
            throw NativeCacheSecurityError.refreshToken
        case .oneTimeTokenValue:
            throw NativeCacheSecurityError.oneTimeTokenValue
        case .providerSecret:
            throw NativeCacheSecurityError.providerSecret
        case .passkey:
            throw NativeCacheSecurityError.passkey
        case .rawMediaPath:
            throw NativeCacheSecurityError.rawMediaPath
        case .signedURL:
            throw NativeCacheSecurityError.signedURL
        }
    }

    private func corruptCacheQuarantined() throws -> NativeCacheRecovery {
        let quarantineSuffix = Self.quarantineSuffix(for: clock.now)
        let quarantineURL = fileURL.appendingPathExtension("corrupt.\(quarantineSuffix)")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.copyItem(at: fileURL, to: quarantineURL)
        }

        return .corruptCacheQuarantined(originalURL: fileURL, quarantineSuffix: quarantineSuffix)
    }

    private static func quarantineSuffix(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
            .string(from: date)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".000", with: "")
    }
}
