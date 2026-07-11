import Foundation

public enum SettingsSurfaceConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum SettingsSurfaceSectionID: Equatable, Hashable, Sendable {
    case session
    case profile
    case security
    case notifications
    case apiTokens
    case connections
    case environment
    case offline
}

public struct SettingsSurfaceSection: Equatable, Sendable {
    public let id: SettingsSurfaceSectionID
    public let title: String

    public init(id: SettingsSurfaceSectionID, title: String) {
        self.id = id
        self.title = title
    }
}

public enum SettingsProfilePhotoDraft: Equatable, Sendable {
    case remote(URL)
    case staged(NativeStagedMediaUpload)
}

public struct SettingsProfileDraft: Equatable, Sendable {
    public let email: String
    public let username: String
    public let photo: SettingsProfilePhotoDraft?

    public init(email: String, username: String, photo: SettingsProfilePhotoDraft?) {
        self.email = email
        self.username = username
        self.photo = photo
    }
}

public enum SettingsSecurityRowID: Equatable, Hashable, Sendable {
    case password
    case passkeys
    case providerLinks
}

public struct SettingsSecurityRow: Equatable, Sendable {
    public let id: SettingsSecurityRowID
    public let title: String
    public let action: SettingsAction

    public init(id: SettingsSecurityRowID, title: String, action: SettingsAction) {
        self.id = id
        self.title = title
        self.action = action
    }
}

public struct SettingsSurfaceConflictBanner: Equatable, Sendable {
    public let localClientMutationID: String
    public let message: String
    public let actionTitle: String

    public init(localClientMutationID: String, message: String, actionTitle: String) {
        self.localClientMutationID = localClientMutationID
        self.message = message
        self.actionTitle = actionTitle
    }
}

public enum SettingsSecureHandoffTarget: Equatable, Sendable {
    case login
    case logout
    case passkeys
    case password
    case providerLink(SettingsAuthProvider)
}

public struct SettingsSecureHandoff: Equatable, Sendable {
    public let target: SettingsSecureHandoffTarget
    public let url: URL

    public init(target: SettingsSecureHandoffTarget, url: URL) {
        self.target = target
        self.url = url
    }
}

public struct SettingsSecureHandoffRoutes: Equatable, Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public static let spoonjoyApp = SettingsSecureHandoffRoutes(baseURL: URL(string: "https://spoonjoy.app")!)

    public func handoff(target: SettingsSecureHandoffTarget) -> SettingsSecureHandoff {
        SettingsSecureHandoff(target: target, url: url(for: target))
    }

    private func url(for target: SettingsSecureHandoffTarget) -> URL {
        switch target {
        case .login:
            return baseURL.appending(path: "login")
        case .logout:
            return SecureAuthWebHandoff.logout.url
        case .passkeys:
            return URL(string: "\(baseURL.absoluteString)/account/settings#passkeys")!
        case .password:
            return URL(string: "\(baseURL.absoluteString)/account/settings#password")!
        case .providerLink(let provider):
            return URL(string: "\(baseURL.absoluteString)/auth/\(provider.rawValue)?linking=true")!
        }
    }
}

public enum SettingsAction: Equatable, Sendable {
    case updateProfile(email: String, username: String, clientMutationID: String)
    case uploadProfilePhoto(photo: NativeStagedMediaUpload, clientMutationID: String)
    case removeProfilePhoto(clientMutationID: String)
    case updateNotificationPreferences(SettingsNotificationPreferences, clientMutationID: String)
    case createAPIToken(name: String, scopes: [String])
    case revokeAPIToken(credentialID: String)
    case disconnectOAuthConnection(connectionID: String)
    case managePasskeys
    case managePassword
    case linkProvider(SettingsAuthProvider)
    case logout
    case revokeSession
}

public enum SettingsOnlineOnlyReason: Equatable, Sendable {
    case apiTokenCreate
    case apiTokenRevoke
    case oauthConnectionDisconnect
    case logout
    case sessionRevoke
    case credentialHandoff

    public var message: String {
        switch self {
        case .apiTokenCreate:
            "Connect to the internet to create an access key."
        case .apiTokenRevoke:
            "Connect to the internet to revoke this access key."
        case .oauthConnectionDisconnect:
            "Connect to the internet to disconnect this OAuth app."
        case .logout:
            "Connect to the internet to sign out securely."
        case .sessionRevoke:
            "Connect to the internet to revoke this session."
        case .credentialHandoff:
            "Connect to the internet to manage credentials securely."
        }
    }
}

public enum SettingsSessionOperation: Equatable, Sendable {
    case logout
    case revokeAndLogout
}

public enum SettingsActionPlanningError: Error, Equatable, Sendable {
    case offlinePolicyRejectedQueueableMutation(NativeQueuedMutationKind)
    case offlinePolicyAllowedOnlineOnlyAction(SettingsOnlineOnlyReason)
}

public typealias SettingsOfflinePolicyDecision = @Sendable (NativeOfflineAction) throws -> NativeOfflineMutationDecision

public struct SettingsActionPlan: Equatable, Sendable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?
    public let secureHandoff: SettingsSecureHandoff?
    public let onlineOnlyReason: SettingsOnlineOnlyReason?
    public let sessionOperation: SettingsSessionOperation?
    public let responseHandling: SettingsActionResponseHandling
    public let userFacingMessage: String?

    public init(
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        offlineFallbackMutation: NativeQueuedMutation? = nil,
        secureHandoff: SettingsSecureHandoff? = nil,
        onlineOnlyReason: SettingsOnlineOnlyReason? = nil,
        sessionOperation: SettingsSessionOperation? = nil,
        responseHandling: SettingsActionResponseHandling = .refreshOnly,
        userFacingMessage: String? = nil
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
        self.secureHandoff = secureHandoff
        self.onlineOnlyReason = onlineOnlyReason
        self.sessionOperation = sessionOperation
        self.responseHandling = responseHandling
        self.userFacingMessage = userFacingMessage
    }
}

public enum SettingsActionQueuePreflightDecision: Equatable, Sendable {
    case queueMutation(NativeQueuedMutation, drainImmediately: Bool)
}

public extension SettingsActionPlan {
    func queuePreflightDecision(queuedMutations: [NativeQueuedMutation]) -> SettingsActionQueuePreflightDecision? {
        if let queuedMutation {
            return .queueMutation(queuedMutation, drainImmediately: false)
        }

        guard let offlineFallbackMutation,
              queuedMutations.contains(where: { $0.blocksDependencyKey(offlineFallbackMutation.dependencyKey) }) else {
            return nil
        }

        return .queueMutation(offlineFallbackMutation, drainImmediately: true)
    }
}

public enum SettingsActionResponseHandling: Equatable, Sendable {
    case refreshOnly
    case captureCreatedAPIToken
}

public enum SettingsActionOutcome: Equatable, Sendable {
    case createdAPIToken(SettingsCreatedAPIToken)
}

public struct SettingsActionPlanner: Sendable {
    private let connectivity: SettingsSurfaceConnectivity
    private let secureHandoffRoutes: SettingsSecureHandoffRoutes
    private let offlinePolicyDecision: SettingsOfflinePolicyDecision
    private let now: (@Sendable () -> String)?

    public init(
        connectivity: SettingsSurfaceConnectivity,
        secureHandoffRoutes: SettingsSecureHandoffRoutes,
        offlinePolicyDecision: @escaping SettingsOfflinePolicyDecision = NativeOfflineMutationPolicy.decision(for:),
        now: (@Sendable () -> String)? = nil
    ) {
        self.connectivity = connectivity
        self.secureHandoffRoutes = secureHandoffRoutes
        self.offlinePolicyDecision = offlinePolicyDecision
        self.now = now
    }

    public func plan(_ action: SettingsAction) throws -> SettingsActionPlan {
        switch action {
        case .updateProfile(let email, let username, let clientMutationID):
            let mutation = NativeQueuedMutation.profileDisplayUpdate(
                email: email,
                username: username,
                clientMutationID: clientMutationID,
                createdAt: timestamp()
            )
            return try queueablePlan(
                online: PrivateAccountRequests.updateProfile(email: email, username: username),
                mutation: mutation
            )
        case .uploadProfilePhoto(let photo, let clientMutationID):
            let mutation = NativeQueuedMutation.profilePhotoUpload(
                photo: photo,
                clientMutationID: clientMutationID,
                createdAt: timestamp()
            )
            return try queueablePlan(
                online: PrivateAccountRequests.uploadProfilePhoto(
                    photo: UploadFile(fileName: photo.fileName, contentType: photo.contentType, data: photo.data)
                ),
                mutation: mutation
            )
        case .removeProfilePhoto(let clientMutationID):
            let mutation = NativeQueuedMutation.profilePhotoRemove(clientMutationID: clientMutationID, createdAt: timestamp())
            return try queueablePlan(online: PrivateAccountRequests.removeProfilePhoto(), mutation: mutation)
        case .updateNotificationPreferences(let preferences, let clientMutationID):
            let mutation = NativeQueuedMutation.notificationPreferenceUpdate(
                notifySpoonOnMyRecipe: preferences.notifySpoonOnMyRecipe,
                notifyForkOfMyRecipe: preferences.notifyForkOfMyRecipe,
                notifyCookbookSaveOfMine: preferences.notifyCookbookSaveOfMine,
                notifyFellowChefOriginCook: preferences.notifyFellowChefOriginCook,
                clientMutationID: clientMutationID,
                createdAt: timestamp()
            )
            return try queueablePlan(
                online: PrivateAccountRequests.updateNotificationPreferences(
                    notifySpoonOnMyRecipe: preferences.notifySpoonOnMyRecipe,
                    notifyForkOfMyRecipe: preferences.notifyForkOfMyRecipe,
                    notifyCookbookSaveOfMine: preferences.notifyCookbookSaveOfMine,
                    notifyFellowChefOriginCook: preferences.notifyFellowChefOriginCook
                ),
                mutation: mutation
            )
        case .createAPIToken(let name, let scopes):
            return try onlineOnlyPlan(
                reason: .apiTokenCreate,
                offlineAction: .apiTokenCreate,
                request: TokenCredentialRequests.createToken(name: name, scopes: scopes),
                responseHandling: .captureCreatedAPIToken
            )
        case .revokeAPIToken(let credentialID):
            return try onlineOnlyPlan(
                reason: .apiTokenRevoke,
                offlineAction: .apiTokenRevoke,
                request: TokenCredentialRequests.revokeToken(credentialID: credentialID)
            )
        case .disconnectOAuthConnection(let connectionID):
            return try onlineOnlyPlan(
                reason: .oauthConnectionDisconnect,
                offlineAction: .providerConnectionDisconnect,
                request: PrivateAccountRequests.disconnectConnection(connectionID: connectionID)
            )
        case .managePasskeys:
            return try credentialHandoff(.passkeys, offlineAction: .passkeyOrPasswordChange)
        case .managePassword:
            return try credentialHandoff(.password, offlineAction: .passkeyOrPasswordChange)
        case .linkProvider(let provider):
            return try credentialHandoff(.providerLink(provider), offlineAction: .providerLink)
        case .logout:
            return try onlineOnlyPlan(
                reason: .logout,
                offlineAction: .logout,
                secureHandoff: secureHandoffRoutes.handoff(target: .logout),
                sessionOperation: .logout
            )
        case .revokeSession:
            return try onlineOnlyPlan(
                reason: .sessionRevoke,
                offlineAction: .sessionRevoke,
                sessionOperation: .revokeAndLogout
            )
        }
    }

    private func queueablePlan(online: APIRequestBuilder, mutation: NativeQueuedMutation) throws -> SettingsActionPlan {
        let policyDecision = try offlinePolicyDecision(.queuedMutation(mutation))
        guard policyDecision.queueableKind == mutation.queueableKind else {
            throw SettingsActionPlanningError.offlinePolicyRejectedQueueableMutation(mutation.queueableKind)
        }

        switch connectivity {
        case .online:
            return SettingsActionPlan(remoteRequestBuilder: online, offlineFallbackMutation: mutation)
        case .offline:
            return SettingsActionPlan(queuedMutation: mutation)
        }
    }

    private func timestamp() -> String {
        if let now {
            return now()
        }
        return ISO8601DateFormatter().string(from: Date())
    }

    private func credentialHandoff(_ target: SettingsSecureHandoffTarget, offlineAction: NativeOfflineAction) throws -> SettingsActionPlan {
        try onlineOnlyPlan(
            reason: .credentialHandoff,
            offlineAction: offlineAction,
            secureHandoff: secureHandoffRoutes.handoff(target: target)
        )
    }

    private func onlineOnlyPlan(
        reason: SettingsOnlineOnlyReason,
        offlineAction: NativeOfflineAction,
        request: APIRequestBuilder? = nil,
        secureHandoff: SettingsSecureHandoff? = nil,
        sessionOperation: SettingsSessionOperation? = nil,
        responseHandling: SettingsActionResponseHandling = .refreshOnly
    ) throws -> SettingsActionPlan {
        let policyDecision = try offlinePolicyDecision(offlineAction)
        guard policyDecision.queueableKind == nil else {
            throw SettingsActionPlanningError.offlinePolicyAllowedOnlineOnlyAction(reason)
        }

        switch connectivity {
        case .online:
            return SettingsActionPlan(
                remoteRequestBuilder: request,
                secureHandoff: secureHandoff,
                sessionOperation: sessionOperation,
                responseHandling: responseHandling
            )
        case .offline:
            return SettingsActionPlan(
                onlineOnlyReason: reason,
                userFacingMessage: reason.message
            )
        }
    }
}

public enum SettingsProfilePhotoStagingRejection: Equatable, Sendable {
    case unsupportedContentType(String)
    case fileTooLarge(maxBytes: Int)
}

public struct SettingsProfilePhotoStagingResult: Equatable, Sendable {
    public let stagedPhoto: NativeStagedMediaUpload?
    public let rejection: SettingsProfilePhotoStagingRejection?

    public init(stagedPhoto: NativeStagedMediaUpload?, rejection: SettingsProfilePhotoStagingRejection?) {
        self.stagedPhoto = stagedPhoto
        self.rejection = rejection
    }
}

public struct SettingsProfilePhotoStagingPolicy: Equatable, Sendable {
    public let acceptedContentTypes: [String]
    public let maxBytes: Int
    public let allowsSilentEvictionOfUnsyncedPhoto: Bool

    public static let webProfileParity = SettingsProfilePhotoStagingPolicy(
        acceptedContentTypes: ["image/jpeg", "image/png", "image/gif", "image/webp"],
        maxBytes: 5 * 1_024 * 1_024,
        allowsSilentEvictionOfUnsyncedPhoto: false
    )

    public init(acceptedContentTypes: [String], maxBytes: Int, allowsSilentEvictionOfUnsyncedPhoto: Bool) {
        self.acceptedContentTypes = acceptedContentTypes
        self.maxBytes = maxBytes
        self.allowsSilentEvictionOfUnsyncedPhoto = allowsSilentEvictionOfUnsyncedPhoto
    }

    public func stageReplacement(existing: NativeStagedMediaUpload?, candidate: NativeStagedMediaUpload) -> SettingsProfilePhotoStagingResult {
        guard acceptedContentTypes.contains(candidate.contentType) else {
            return SettingsProfilePhotoStagingResult(
                stagedPhoto: existing,
                rejection: .unsupportedContentType(candidate.contentType)
            )
        }
        guard candidate.byteCount <= maxBytes else {
            return SettingsProfilePhotoStagingResult(
                stagedPhoto: existing,
                rejection: .fileTooLarge(maxBytes: maxBytes)
            )
        }
        return SettingsProfilePhotoStagingResult(stagedPhoto: candidate, rejection: nil)
    }

    public func clear(existing: NativeStagedMediaUpload?) -> SettingsProfilePhotoStagingResult {
        SettingsProfilePhotoStagingResult(stagedPhoto: nil, rejection: nil)
    }
}

public struct SettingsSurfaceViewModel: Sendable {
    public let data: SettingsSurfaceData
    public let sections: [SettingsSurfaceSection]
    public let profileDraft: SettingsProfileDraft?
    public let notificationDraft: SettingsNotificationPreferences?
    public let apiTokenRows: [SettingsAPITokenSummary]
    public let oauthConnectionRows: [SettingsOAuthConnectionSummary]
    public let securityRows: [SettingsSecurityRow]
    public let partialFailureSummary: String?
    public let queuedWorkSummary: String?
    public let conflictBanner: SettingsSurfaceConflictBanner?
    public let offlineIndicator: OfflineIndicatorState
    public let primaryAuthAction: SettingsSecureHandoff?
    public let actionPlanner: SettingsActionPlanner
    public let connectivity: SettingsSurfaceConnectivity

    public init(
        data: SettingsSurfaceData,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: SettingsSurfaceConnectivity,
        secureHandoffRoutes: SettingsSecureHandoffRoutes,
        now: @escaping @Sendable () -> Date,
        showsPrimaryAuthActionWhenSignedOut: Bool = true
    ) {
        self.data = data
        let hasAccount = data.account != nil
        let tokenManagementSections = data.tokenManagementAvailability == .available ? [
            SettingsSurfaceSection(id: .apiTokens, title: "Agent access"),
            SettingsSurfaceSection(id: .connections, title: "Connections")
        ] : []
        sections = hasAccount ? [
            SettingsSurfaceSection(id: .profile, title: "Profile"),
            SettingsSurfaceSection(id: .security, title: "Security"),
            SettingsSurfaceSection(id: .notifications, title: "Notifications")
        ] + tokenManagementSections + [
            SettingsSurfaceSection(id: .environment, title: "Environment"),
            SettingsSurfaceSection(id: .offline, title: "Offline")
        ] : showsPrimaryAuthActionWhenSignedOut ? [
            SettingsSurfaceSection(id: .session, title: "Session"),
            SettingsSurfaceSection(id: .environment, title: "Environment"),
            SettingsSurfaceSection(id: .offline, title: "Offline")
        ] : [
            SettingsSurfaceSection(id: .environment, title: "Environment"),
            SettingsSurfaceSection(id: .offline, title: "Offline")
        ]
        profileDraft = data.account.map {
            SettingsProfileDraft(
                email: $0.email,
                username: $0.username,
                photo: $0.photoURL.map(SettingsProfilePhotoDraft.remote)
            )
        }
        notificationDraft = data.notifications
        apiTokenRows = data.apiTokens
        oauthConnectionRows = data.oauthConnections
        securityRows = [
            SettingsSecurityRow(id: .password, title: "Password", action: .managePassword),
            SettingsSecurityRow(id: .passkeys, title: "Passkeys", action: .managePasskeys),
            SettingsSecurityRow(id: .providerLinks, title: "Provider Links", action: .linkProvider(.google))
        ]
        partialFailureSummary = Self.partialFailureSummary(data.partialFailures)
        let accountMutations = Self.accountMutations(queuedMutations)
        queuedWorkSummary = Self.queuedWorkSummary(count: accountMutations.count)
        let accountConflicts = Self.accountConflicts(conflicts, queuedMutations: accountMutations)
        conflictBanner = accountConflicts.first.map {
            SettingsSurfaceConflictBanner(
                localClientMutationID: $0.clientMutationID,
                message: $0.message,
                actionTitle: "Review account conflict"
            )
        }
        if let conflict = accountConflicts.first {
            offlineIndicator = OfflineIndicatorState(
                display: .conflict(recordID: conflict.clientMutationID, mutationID: conflict.clientMutationID),
                dismissal: nil
            )
        } else if !accountMutations.isEmpty {
            offlineIndicator = OfflineIndicatorState(
                display: .queuedWork(count: accountMutations.count, oldestClientMutationID: accountMutations.first?.clientMutationID),
                dismissal: nil
            )
        } else if connectivity == .offline {
            offlineIndicator = OfflineIndicatorState(display: .offline, dismissal: nil)
        } else if let partialFailure = data.partialFailures.first {
            offlineIndicator = OfflineIndicatorState(
                display: .syncFailure(errorID: "settings.\(partialFailure.component.rawValue)", retryAfter: nil),
                dismissal: nil
            )
        } else {
            offlineIndicator = Self.offlineIndicator(source: data.source, now: now())
        }
        primaryAuthAction = hasAccount || !showsPrimaryAuthActionWhenSignedOut ? nil : secureHandoffRoutes.handoff(target: .login)
        self.connectivity = connectivity
        actionPlanner = SettingsActionPlanner(
            connectivity: connectivity,
            secureHandoffRoutes: secureHandoffRoutes,
            now: { ISO8601DateFormatter().string(from: now()) }
        )
    }

    public static func signedOut(
        environment: NativeCacheEnvironment,
        offline: OfflineState,
        secureHandoffRoutes: SettingsSecureHandoffRoutes
    ) -> SettingsSurfaceViewModel {
        SettingsSurfaceViewModel(
            data: SettingsSurfaceData(
                account: nil,
                notifications: nil,
                apiTokens: [],
                oauthConnections: [],
                environment: environment,
                offline: offline,
                source: .cache(lastValidatedAt: .distantPast)
            ),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: secureHandoffRoutes,
            now: Date.init
        )
    }

    private static func accountMutations(_ mutations: [NativeQueuedMutation]) -> [NativeQueuedMutation] {
        mutations.filter { mutation in
            switch mutation.queueableKind {
            case .profileDisplayUpdate, .profilePhotoUpload, .profilePhotoRemove, .notificationPreferenceUpdate:
                true
            default:
                false
            }
        }
    }

    private static func accountConflicts(
        _ conflicts: [NativeSyncConflict],
        queuedMutations: [NativeQueuedMutation]
    ) -> [NativeSyncConflict] {
        let mutationIDs = Set(queuedMutations.map(\.clientMutationID))
        return conflicts.filter { mutationIDs.contains($0.clientMutationID) }
    }

    private static func queuedWorkSummary(count: Int) -> String? {
        guard count > 0 else {
            return nil
        }
        return "\(count) account \(count == 1 ? "change" : "changes") waiting to sync"
    }

    private static func partialFailureSummary(_ failures: [SettingsSurfacePartialFailure]) -> String? {
        let names = failures.map(\.component.userFacingName)
        guard !names.isEmpty else {
            return nil
        }
        return "Some account settings could not load: \(names.joined(separator: ", "))."
    }

    private static func offlineIndicator(source: SettingsSurfaceDataSource, now: Date) -> OfflineIndicatorState {
        switch source {
        case .live:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache(let lastValidatedAt):
            if now.timeIntervalSince(lastValidatedAt) > 300 {
                return OfflineIndicatorState(display: .stale(domain: .settings), dismissal: nil)
            }
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        }
    }
}
