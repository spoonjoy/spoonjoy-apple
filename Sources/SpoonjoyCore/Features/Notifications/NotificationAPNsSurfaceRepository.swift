import Foundation

public enum NotificationAPNsSurfaceDataSource: Equatable, Sendable {
    case live(requestID: String, validatedAt: Date)
    case cache(serverRevision: NativeCacheServerRevision?, lastValidatedAt: Date)
}

public enum APNsPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized(lastCheckedAt: Date)
    case denied(lastCheckedAt: Date)
}

public struct APNsRegistrationSummary: Equatable, Sendable {
    public let deviceID: String
    public let platform: NativeAPNSPlatform
    public let environment: APNSEnvironment
    public let registrationState: NativeAPNSRegistrationState
    public let lastValidatedAt: Date

    public init(
        deviceID: String,
        platform: NativeAPNSPlatform,
        environment: APNSEnvironment,
        registrationState: NativeAPNSRegistrationState,
        lastValidatedAt: Date
    ) {
        self.deviceID = deviceID
        self.platform = platform
        self.environment = environment
        self.registrationState = registrationState
        self.lastValidatedAt = lastValidatedAt
    }
}

public struct AppleDeveloperProgramBlocker: Codable, Equatable, Sendable {
    public let blocked: Bool
    public let capability: String
    public let command: String
    public let outputPath: String
    public let reason: String
    public let ownerAction: String

    public init(
        blocked: Bool,
        capability: String,
        command: String,
        outputPath: String,
        reason: String,
        ownerAction: String
    ) {
        self.blocked = blocked
        self.capability = capability
        self.command = command
        self.outputPath = outputPath
        self.reason = reason
        self.ownerAction = ownerAction
    }

    public static let capabilityName = "AppleDeveloperProgram"
    public static let artifactFileName = "apple-developer-program-blocker-apns.json"

    public static let localValidation = AppleDeveloperProgramBlocker(
        blocked: true,
        capability: capabilityName,
        command: "validate APNs production entitlement and Apple Developer Program team before enabling production push delivery",
        outputPath: "apple/apple-developer-program-blocker-apns.json",
        reason: "Production APNs delivery requires an Apple Developer Program team, signing entitlement, push capability, and production device-token validation. This local build intentionally models notification preferences and APNs registration state without claiming production delivery.",
        ownerAction: "Enroll or attach the Spoonjoy Apple team to a paid Apple Developer Program account, then enable Push Notifications/App Groups signing and rerun the APNs validation matrix."
    )
}

public enum APNsDeliveryBlockerState: Equatable, Sendable {
    case developmentOnly(AppleDeveloperProgramBlocker)
    case blocked(AppleDeveloperProgramBlocker)
}

public enum APNsDeliveryCapability: Equatable, Sendable {
    case developmentOnly(blocker: AppleDeveloperProgramBlocker)
    case blocked(AppleDeveloperProgramBlocker)

    public var blockerState: APNsDeliveryBlockerState {
        switch self {
        case .developmentOnly(let blocker):
            return .developmentOnly(blocker)
        case .blocked(let blocker):
            return .blocked(blocker)
        }
    }

    public var productionBlocker: AppleDeveloperProgramBlocker? {
        switch self {
        case .developmentOnly(let blocker), .blocked(let blocker):
            return blocker
        }
    }

    public func blocker(for environment: APNSEnvironment) -> AppleDeveloperProgramBlocker? {
        switch (self, environment) {
        case (.developmentOnly(let blocker), .production):
            return blocker
        case (.developmentOnly, .development):
            return nil
        case (.blocked(let blocker), _):
            return blocker
        }
    }
}

public enum NativeAPNSRuntimeDefaults {
    public static var currentPlatform: NativeAPNSPlatform {
#if os(macOS)
        .macos
#else
        .ios
#endif
    }

    public static var currentEnvironment: APNSEnvironment {
        .development
    }
}

public struct NotificationAPNsSurfaceData: Equatable, Sendable {
    public let preferences: SettingsNotificationPreferences
    public let apnsRegistration: APNsRegistrationSummary?
    public let permissionState: APNsPermissionState
    public let deliveryCapability: APNsDeliveryCapability
    public let source: NotificationAPNsSurfaceDataSource

    public init(
        preferences: SettingsNotificationPreferences,
        apnsRegistration: APNsRegistrationSummary?,
        permissionState: APNsPermissionState,
        deliveryCapability: APNsDeliveryCapability = .developmentOnly(blocker: .localValidation),
        source: NotificationAPNsSurfaceDataSource
    ) {
        self.preferences = preferences
        self.apnsRegistration = apnsRegistration
        self.permissionState = permissionState
        self.deliveryCapability = deliveryCapability
        self.source = source
    }
}

public protocol NotificationAPNsSurfaceRepository: Sendable {
    func restore() async throws -> NotificationAPNsSurfaceData
}

public struct LiveNotificationAPNsSurfaceRepository: NotificationAPNsSurfaceRepository {
    private let transport: any SettingsSurfaceTransport
    private let configuration: APIClientConfiguration
    private let permissionState: APNsPermissionState
    private let deliveryCapability: APNsDeliveryCapability

    public init(
        transport: any SettingsSurfaceTransport = URLSessionSettingsSurfaceTransport(),
        configuration: APIClientConfiguration,
        permissionState: APNsPermissionState = .notDetermined,
        deliveryCapability: APNsDeliveryCapability = .developmentOnly(blocker: .localValidation)
    ) {
        self.transport = transport
        self.configuration = configuration
        self.permissionState = permissionState
        self.deliveryCapability = deliveryCapability
    }

    public func restore() async throws -> NotificationAPNsSurfaceData {
        let preferences = try await transport.fetchNotificationPreferences(
            PrivateAccountRequests.notificationPreferences(),
            configuration: configuration
        )
        return NotificationAPNsSurfaceData(
            preferences: preferences.data,
            apnsRegistration: nil,
            permissionState: permissionState,
            deliveryCapability: deliveryCapability,
            source: .live(requestID: preferences.requestID, validatedAt: preferences.validatedAt)
        )
    }
}

public struct SnapshotNotificationAPNsSurfaceRepository: NotificationAPNsSurfaceRepository {
    private let cache: NativeDurableCache
    private let environment: NativeCacheEnvironment
    private let platform: NativeAPNSPlatform
    private let apnsEnvironment: APNSEnvironment
    private let permissionState: APNsPermissionState
    private let deliveryCapability: APNsDeliveryCapability
    private let fallbackValidatedAt: Date
    private static let notificationPreferenceDomainToken = NativeCacheDomain.notificationPreferences
    private static let apnsStatusDomainToken = NativeCacheDomain.apnsStatus
    private static let notificationPreferencePayloadToken = NativeCachePayload.notificationPreferenceState(.disabled)
    private static let apnsStatusPayloadToken = NativeCachePayload.apnsStatus(deviceID: "device-token-source", registrationState: .unregistered)

    public init(
        cache: NativeDurableCache,
        environment: NativeCacheEnvironment,
        platform: NativeAPNSPlatform = NativeAPNSRuntimeDefaults.currentPlatform,
        apnsEnvironment: APNSEnvironment = NativeAPNSRuntimeDefaults.currentEnvironment,
        permissionState: APNsPermissionState = .notDetermined,
        deliveryCapability: APNsDeliveryCapability = .developmentOnly(blocker: .localValidation),
        fallbackValidatedAt: Date
    ) {
        self.cache = cache
        self.environment = environment
        self.platform = platform
        self.apnsEnvironment = apnsEnvironment
        self.permissionState = permissionState
        self.deliveryCapability = deliveryCapability
        self.fallbackValidatedAt = fallbackValidatedAt
    }

    public func restoreSynchronously() -> NotificationAPNsSurfaceData {
        _ = Self.notificationPreferenceDomainToken
        _ = Self.apnsStatusDomainToken
        _ = Self.notificationPreferencePayloadToken
        _ = Self.apnsStatusPayloadToken
        let notificationRecord = cache.record(for: .notificationPreferences)
        let apnsRecord = cache.record(for: .apnsStatus)
        let preferences = notificationRecord.flatMap(Self.preferences(from:)) ?? .disabled
        let registration = apnsRecord.flatMap {
            Self.registration(from: $0, platform: platform, apnsEnvironment: apnsEnvironment)
        }
        let sourceRecord = apnsRecord ?? notificationRecord

        return NotificationAPNsSurfaceData(
            preferences: preferences,
            apnsRegistration: registration,
            permissionState: permissionState,
            deliveryCapability: deliveryCapability,
            source: .cache(
                serverRevision: sourceRecord?.metadata.serverRevision,
                lastValidatedAt: sourceRecord?.metadata.lastValidatedAt ?? fallbackValidatedAt
            )
        )
    }

    public func restore() async throws -> NotificationAPNsSurfaceData {
        restoreSynchronously()
    }

    private static func preferences(from record: NativeCacheRecord) -> SettingsNotificationPreferences? {
        switch record.payload {
        case .notificationPreferenceState(let preferences):
            return preferences
        case .notificationPreferences(let marketingEnabled, let cookingRemindersEnabled):
            return SettingsNotificationPreferences(
                notifySpoonOnMyRecipe: marketingEnabled,
                notifyForkOfMyRecipe: cookingRemindersEnabled,
                notifyCookbookSaveOfMine: marketingEnabled,
                notifyFellowChefOriginCook: cookingRemindersEnabled
            )
        default:
            return nil
        }
    }

    private static func registration(
        from record: NativeCacheRecord,
        platform: NativeAPNSPlatform,
        apnsEnvironment: APNSEnvironment
    ) -> APNsRegistrationSummary? {
        switch record.payload {
        case .apnsStatus(let deviceID, let registrationState):
            return APNsRegistrationSummary(
                deviceID: deviceID,
                platform: platform,
                environment: apnsEnvironment,
                registrationState: registrationState,
                lastValidatedAt: record.metadata.lastValidatedAt
            )
        default:
            return nil
        }
    }

    public static func registerRequest(
        deviceID: String,
        platform: NativeAPNSPlatform,
        environment: APNSEnvironment,
        token: String,
        deviceName: String,
        appVersion: String
    ) throws -> APIRequestBuilder {
        try PrivateAccountRequests.registerAPNSDevice(
            deviceID: deviceID,
            platform: platform,
            environment: environment,
            token: token,
            deviceName: deviceName,
            appVersion: appVersion
        )
    }

    public static func revokeRequest(deviceID: String) -> APIRequestBuilder {
        PrivateAccountRequests.revokeAPNSDevice(deviceID: deviceID)
    }
}

public struct FallbackNotificationAPNsSurfaceRepository: NotificationAPNsSurfaceRepository {
    private let primary: any NotificationAPNsSurfaceRepository
    private let fallback: any NotificationAPNsSurfaceRepository

    public init(primary: any NotificationAPNsSurfaceRepository, fallback: any NotificationAPNsSurfaceRepository) {
        self.primary = primary
        self.fallback = fallback
    }

    public func restore() async throws -> NotificationAPNsSurfaceData {
        do {
            return try await primary.restore()
        } catch {
            return try await fallback.restore()
        }
    }
}

public extension NotificationAPNsSurfaceData {
    static func restoredFromCacheSnapshot(
        _ snapshot: NativeDurableCacheSnapshot,
        platform: NativeAPNSPlatform = NativeAPNSRuntimeDefaults.currentPlatform,
        apnsEnvironment: APNSEnvironment = NativeAPNSRuntimeDefaults.currentEnvironment,
        permissionState: APNsPermissionState = .notDetermined,
        deliveryCapability: APNsDeliveryCapability = .developmentOnly(blocker: .localValidation),
        fallbackValidatedAt: Date
    ) -> NotificationAPNsSurfaceData? {
        let relevantRecords = snapshot.records.filter { record in
            switch record.metadata.domain {
            case .notificationPreferences, .apnsStatus:
                return true
            default:
                return false
            }
        }
        guard !relevantRecords.isEmpty else {
            return nil
        }
        return SnapshotNotificationAPNsSurfaceRepository(
            cache: NativeDurableCache(records: relevantRecords),
            environment: snapshot.environment,
            platform: platform,
            apnsEnvironment: apnsEnvironment,
            permissionState: permissionState,
            deliveryCapability: deliveryCapability,
            fallbackValidatedAt: fallbackValidatedAt
        )
        .restoreSynchronously()
    }

    static func restoredFromSettingsSurface(
        _ settings: SettingsSurfaceData?,
        environment: NativeCacheEnvironment,
        source: NotificationAPNsSurfaceDataSource? = nil
    ) -> NotificationAPNsSurfaceData? {
        _ = environment
        guard let settings,
              let preferences = settings.notifications else {
            return nil
        }
        let lastValidatedAt: Date
        switch settings.source {
        case .live(_, let validatedAt):
            lastValidatedAt = validatedAt
        case .cache(let cachedAt):
            lastValidatedAt = cachedAt
        }
        return NotificationAPNsSurfaceData(
            preferences: preferences,
            apnsRegistration: nil,
            permissionState: .notDetermined,
            source: source ?? .cache(serverRevision: nil, lastValidatedAt: lastValidatedAt)
        )
    }
}
