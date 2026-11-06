import Foundation

extension SettingsSurfaceViewModel {
    /// Sign out, Delete account, Download my data and the other server-only rows are off while the app is offline.
    public var onlineOnlyActionsDisabled: Bool {
        connectivity == .offline
    }

    /// The Delete account sheet's form for the signed-in account, or nil when the account or its sign-in proof
    /// isn't known yet.
    public func accountDeletionForm() -> AccountDeletionForm? {
        guard let username = data.account?.username, let reauthentication = accountDeletionReauthentication else {
            return nil
        }
        return AccountDeletionForm(username: username, reauthentication: reauthentication)
    }
}

extension SettingsActionPlan {
    /// What Settings does with a plan, in order: queue it when the plan or the queue says so; otherwise send its
    /// request (queueing the offline fallback when the request finds no network), run its session change, and open
    /// its secure web hand-off. `PlatformNavigationView` and Ouro Reins both run it with the live store's methods.
    @MainActor
    public func perform(
        queuedMutations: [NativeQueuedMutation],
        queueMutation: (NativeQueuedMutation) async throws -> Void,
        queueMutations: ([NativeQueuedMutation], Bool) async throws -> Void,
        execute: (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?,
        sessionOperation perform: (SettingsSessionOperation) async throws -> Void,
        openURL: (URL) -> Void
    ) async throws -> SettingsActionOutcome? {
        if let preflight = queuePreflightDecision(queuedMutations: queuedMutations) {
            switch preflight {
            case .queueMutation(let mutation, drainImmediately: false):
                try await queueMutation(mutation)
            case .queueMutation(let mutation, drainImmediately: true):
                try await queueMutations([mutation], true)
            }
            return nil
        }

        var outcome: SettingsActionOutcome?
        if let remoteRequestBuilder {
            do {
                outcome = try await execute(remoteRequestBuilder, responseHandling)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return nil
                }
                throw error
            }
        }

        if let sessionOperation {
            try await perform(sessionOperation)
        }

        if let secureHandoff {
            openURL(secureHandoff.url)
        }

        return outcome
    }
}
