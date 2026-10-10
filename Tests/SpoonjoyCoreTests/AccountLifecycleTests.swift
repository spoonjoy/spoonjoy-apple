import Foundation
import Testing
@testable import SpoonjoyCore

// Download my data, Delete account, the read-only email, and "Deleted chef" bylines.
// Server contract: spoonjoy-v2 docs/account-deletion.md (GET /api/v1/me/export, DELETE /api/v1/me).
@Suite("Account lifecycle: export, deletion, email and bylines")
struct AccountLifecycleTests {
    fileprivate static let now = Date(timeIntervalSince1970: 1_791_590_400) // 2026-10-10T00:00:00Z

    // MARK: - Requests

    @Test("export is a private GET of /api/v1/me/export")
    func exportRequest() throws {
        let request = try PrivateAccountRequests.exportAccount().urlRequest(configuration: .spoonjoyProduction)

        #expect(request.method == .get)
        #expect(request.url.path == "/api/v1/me/export")
        #expect(request.body == nil)
        #expect(request.responseCachePolicy == .privateNoStore)
    }

    @Test("delete sends the typed username with only the proof that applies, because the server rejects unknown fields")
    func deleteRequestBodies() throws {
        let password = try PrivateAccountRequests.deleteAccount(confirmUsername: "ari", proof: .password("hunter22"))
            .urlRequest(configuration: .spoonjoyProduction)
        #expect(password.method == .delete)
        #expect(password.url.path == "/api/v1/me")
        #expect(try Self.jsonObject(password.body) == ["confirmUsername": "ari", "password": "hunter22"])

        let apple = try PrivateAccountRequests.deleteAccount(
            confirmUsername: "ari",
            proof: .signInWithApple(identityToken: "apple.jwt", rawNonce: "raw-nonce")
        ).urlRequest(configuration: .spoonjoyProduction)
        #expect(apple.method == .delete)
        #expect(try Self.jsonObject(apple.body) == [
            "confirmUsername": "ari",
            "appleIdentityToken": "apple.jwt",
            "appleRawNonce": "raw-nonce"
        ])
    }

    // MARK: - Planner

    @Test("online, export and delete plan their requests; offline, both are refused with the online-only message")
    func plannerOnlineAndOffline() throws {
        let online = SettingsActionPlanner(connectivity: .online, secureHandoffRoutes: .spoonjoyApp)
        let exportPlan = try online.plan(.exportAccountData(username: "ari"))
        #expect(try exportPlan.remoteRequestBuilder?.urlRequest(configuration: .spoonjoyProduction).url.path == "/api/v1/me/export")
        #expect(exportPlan.responseHandling == .captureAccountExport(username: "ari"))
        #expect(exportPlan.sessionOperation == nil)
        #expect(exportPlan.queuedMutation == nil)
        #expect(exportPlan.offlineFallbackMutation == nil)

        let deletePlan = try online.plan(.deleteAccount(confirmUsername: "ari", proof: .password("pw")))
        let deleteRequest = try #require(try deletePlan.remoteRequestBuilder?.urlRequest(configuration: .spoonjoyProduction))
        #expect(deleteRequest.method == .delete)
        #expect(deletePlan.responseHandling == .deleteAccountThenSignOutLocally)
        // The store signs out locally after a successful delete; the plan must not also ask for a server revoke.
        #expect(deletePlan.sessionOperation == nil)
        #expect(deletePlan.offlineFallbackMutation == nil)

        let offline = SettingsActionPlanner(connectivity: .offline, secureHandoffRoutes: .spoonjoyApp)
        let offlineExport = try offline.plan(.exportAccountData(username: "ari"))
        #expect(offlineExport.remoteRequestBuilder == nil)
        #expect(offlineExport.onlineOnlyReason == .accountExport)
        #expect(offlineExport.userFacingMessage == "Connect to the internet to download your data.")
        let offlineDelete = try offline.plan(.deleteAccount(confirmUsername: "ari", proof: .password("pw")))
        #expect(offlineDelete.remoteRequestBuilder == nil)
        #expect(offlineDelete.onlineOnlyReason == .accountDeletion)
        #expect(offlineDelete.userFacingMessage == "Connect to the internet to delete your account.")
    }

    @Test("export and delete are online-only in the offline mutation policy")
    func offlinePolicy() throws {
        #expect(try NativeOfflineMutationPolicy.decision(for: .accountExport) == NativeOfflineMutationDecision(
            queueableKind: nil,
            onlineOnlyReason: "Downloading your data is online-only and was not queued."
        ))
        #expect(try NativeOfflineMutationPolicy.decision(for: .accountDeletion) == NativeOfflineMutationDecision(
            queueableKind: nil,
            onlineOnlyReason: "Deleting your account is online-only and was not queued."
        ))
    }

    // MARK: - How the sheet confirms it is the owner

    @Test("a password wins, then a linked Apple ID; with neither, deletion links to the web on the configured base URL")
    func reauthenticationChoice() {
        let qa = SettingsSecureHandoffRoutes(baseURL: URL(string: "https://qa.spoonjoy.app")!)
        #expect(AccountDeletionReauthentication(account: Self.account(hasPassword: true, providers: [.apple]), routes: qa) == .password)
        #expect(AccountDeletionReauthentication(account: Self.account(hasPassword: false, providers: [.google, .apple]), routes: qa) == .signInWithApple)
        #expect(AccountDeletionReauthentication(account: Self.account(hasPassword: false, providers: [.github, .google]), routes: qa)
            == .web(URL(string: "https://qa.spoonjoy.app/account/settings#delete-account")!))
        #expect(SettingsSecureHandoffRoutes.spoonjoyApp.handoff(target: .deleteAccount).url.absoluteString
            == "https://spoonjoy.app/account/settings#delete-account")
    }

    // MARK: - The delete form

    @Test("delete stays disabled until the trimmed username matches exactly and the proof is there")
    func formGating() {
        var form = AccountDeletionForm(username: "Ari_M", reauthentication: .password)
        #expect(form.action == nil)

        form.password = "pw"
        form.typedUsername = "ari_m"
        #expect(!form.usernameMatches, "The server compares exactly, so case matters")
        #expect(form.action == nil)

        form.typedUsername = "  Ari_M \n"
        #expect(form.usernameMatches)
        #expect(form.action == .deleteAccount(confirmUsername: "Ari_M", proof: .password("pw")))

        form.password = ""
        #expect(form.proof == nil)
        #expect(form.action == nil)

        var apple = AccountDeletionForm(username: "ari", reauthentication: .signInWithApple)
        apple.typedUsername = "ari"
        #expect(apple.action == nil)
        apple.appleCredential = NativeAppleSignInCredential(identityToken: "jwt", rawNonce: "nonce")
        #expect(apple.action == .deleteAccount(confirmUsername: "ari", proof: .signInWithApple(identityToken: "jwt", rawNonce: "nonce")))

        var web = AccountDeletionForm(username: "ari", reauthentication: .web(URL(string: "https://spoonjoy.app/account/settings#delete-account")!))
        web.typedUsername = "ari"
        web.password = "ignored"
        #expect(web.proof == nil)
        #expect(web.action == nil)
    }

    @Test("a wrong password clears the password field; a refused Apple credential asks for a fresh one; neither signs out")
    func formRecordsFailures() {
        var form = AccountDeletionForm(username: "ari", reauthentication: .password)
        form.typedUsername = "ari"
        form.password = "wrong"
        form.record(.passwordIncorrect)
        #expect(form.failure == .passwordIncorrect)
        #expect(form.password.isEmpty)
        #expect(form.typedUsername == "ari")
        form.clearFailure()
        #expect(form.failure == nil)

        form.password = "kept"
        form.record(.rateLimited)
        #expect(form.password == "kept")

        for failure in [AccountDeletionFailure.appleAccountMismatch, .appleCredentialInvalid, .appleConfirmationRequired] {
            var apple = AccountDeletionForm(username: "ari", reauthentication: .signInWithApple)
            apple.appleCredential = NativeAppleSignInCredential(identityToken: "jwt", rawNonce: "nonce")
            apple.record(failure)
            #expect(apple.appleCredential == nil)
            #expect(failure.invalidatesAppleCredential)
        }
        var apple = AccountDeletionForm(username: "ari", reauthentication: .signInWithApple)
        apple.appleCredential = NativeAppleSignInCredential(identityToken: "jwt", rawNonce: "nonce")
        apple.record(.usernameMismatch)
        #expect(apple.appleCredential != nil)
    }

    @Test("every refusal reason from the server maps to its own message")
    func failureMapping() {
        let cases: [(String, AccountDeletionFailure, String)] = [
            ("confirmation_mismatch", .usernameMismatch, "That username doesn't match. Type it exactly as it appears on your account."),
            ("password_required", .passwordRequired, "Enter your current password to confirm it's you."),
            ("password_incorrect", .passwordIncorrect, "That password isn't right. Your account was not deleted."),
            ("apple_account_mismatch", .appleAccountMismatch, "That Apple ID isn't the one linked to this account. Sign in with the Apple ID you use for Spoonjoy."),
            ("apple_credential_invalid", .appleCredentialInvalid, "Apple couldn't confirm it's you. Sign in with Apple again."),
            ("recent_sign_in_required", .appleConfirmationRequired, "Sign in with Apple to confirm it's you.")
        ]
        for (reason, failure, message) in cases {
            let error = Self.apiError(status: 400, code: "validation_error", details: ["reason": .string(reason)])
            #expect(AccountDeletionFailure(error: error) == failure)
            #expect(failure.message == message)
        }

        let rateLimited = AccountDeletionFailure(error: Self.apiError(status: 429, code: "rate_limited", retryAfterSeconds: 60))
        #expect(rateLimited == .rateLimited)
        #expect(rateLimited.message == "Too many attempts. Wait a few minutes, then try again.")

        let offline = AccountDeletionFailure(error: APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry))
        #expect(offline == .offline)
        #expect(offline.message == "Connect to the internet to delete your account.")

        let unconfigured = AccountDeletionFailure(error: Self.apiError(status: 400, code: "validation_error", details: ["providerCode": .string("apple_native_unconfigured")]))
        #expect(unconfigured == .unexpected(code: "account_delete_api_validation_error_400"))
        #expect(unconfigured.message == "Your account was not deleted. Try again. Code: account_delete_api_validation_error_400.")
        #expect(!unconfigured.invalidatesAppleCredential)

        let transportOnly = APITransportError(kind: .nonJSONResponse, requestID: nil, statusCode: 502, apiError: nil, retryDecision: .doNotRetry)
        #expect(AccountDeletionFailure(error: transportOnly) == .unexpected(code: "account_delete_transport"))
        #expect(AccountDeletionFailure(error: AccountLifecycleTestError.unexpected) == .unexpected(code: "account_delete_unexpected"))
    }

    // MARK: - Export file

    @Test("the export file takes the web's name, in UTC, and holds the export as sorted, pretty JSON")
    func exportFile() throws {
        let lateEvening = ISO8601DateFormatter().date(from: "2026-10-09T23:30:00Z")!
        #expect(AccountExportFile.fileName(username: "ada.lovelace", exportedAt: lateEvening) == "spoonjoy-ada.lovelace-2026-10-09.json")
        #expect(AccountExportFile.fileName(username: "a/b c", exportedAt: lateEvening) == "spoonjoy-a-b-c-2026-10-09.json")
        #expect(AccountExportFile.fileName(username: "chef_é", exportedAt: lateEvening) == "spoonjoy-chef_--2026-10-09.json")

        let file = try AccountExportFile(
            username: "ari",
            exportedAt: Self.now,
            export: .object(["format": .string("spoonjoy.account-export.v1"), "account": .object(["username": .string("ari")])])
        )
        #expect(file.fileName == "spoonjoy-ari-2026-10-10.json")
        #expect(String(decoding: file.contents, as: UTF8.self) == """
        {
          "account" : {
            "username" : "ari"
          },
          "format" : "spoonjoy.account-export.v1"
        }
        """)
    }

    // MARK: - Settings surface

    @Test("signed in, the settings screen has a Your data section, a read-only email note and both web links")
    func settingsSurface() {
        let qa = SettingsSecureHandoffRoutes(baseURL: URL(string: "https://qa.spoonjoy.app")!)
        let viewModel = SettingsSurfaceViewModel(
            data: Self.surfaceData(account: Self.account(hasPassword: false, providers: [.apple])),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: qa,
            now: { Self.now }
        )

        #expect(viewModel.sections.map(\.id) == [.profile, .security, .notifications, .apiTokens, .connections, .yourData, .environment, .offline])
        #expect(viewModel.accountDeletionReauthentication == .signInWithApple)
        #expect(viewModel.accountSettingsHandoff.url.absoluteString == "https://qa.spoonjoy.app/account/settings")
        #expect(viewModel.accountDeletionWebHandoff.url.absoluteString == "https://qa.spoonjoy.app/account/settings#delete-account")
        #expect(viewModel.emailChangeNote == "Change your email in Account settings on qa.spoonjoy.app")

        let production = SettingsSurfaceViewModel(
            data: Self.surfaceData(account: Self.account(hasPassword: true, providers: [])),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.now }
        )
        #expect(production.emailChangeNote == "Change your email in Account settings on spoonjoy.app")

        let hostless = SettingsSurfaceViewModel(
            data: Self.surfaceData(account: Self.account(hasPassword: true, providers: [])),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: SettingsSecureHandoffRoutes(baseURL: URL(fileURLWithPath: "/spoonjoy")),
            now: { Self.now }
        )
        #expect(hostless.emailChangeNote == "Change your email in Account settings on file:///spoonjoy/account/settings")

        let signedOut = SettingsSurfaceViewModel.signedOut(environment: .production, offline: .unavailable, secureHandoffRoutes: .spoonjoyApp)
        #expect(!signedOut.sections.map(\.id).contains(.yourData))
        #expect(signedOut.accountDeletionReauthentication == nil)
    }

    @Test("a username save sends the account's current email unchanged and trims the username")
    func usernameSaveKeepsEmail() throws {
        let draft = SettingsProfileDraft(email: "ari@example.com", username: "ari", photo: nil)
        let action = draft.updateUsernameAction(username: "  ari_new ", clientMutationID: "cm_profile")
        #expect(action == .updateProfile(email: "ari@example.com", username: "ari_new", clientMutationID: "cm_profile"))

        let plan = try SettingsActionPlanner(connectivity: .online, secureHandoffRoutes: .spoonjoyApp).plan(action)
        let request = try #require(try plan.remoteRequestBuilder?.urlRequest(configuration: .spoonjoyProduction))
        #expect(try Self.jsonObject(request.body)["email"] == "ari@example.com")
        #expect(try Self.jsonObject(request.body)["username"] == "ari_new")
    }

    @Test("a 4xx answer shows the server's message; 401, 5xx and transport failures keep the generic message and code")
    func settingsFailureMessage() {
        let emailOnWeb = Self.apiError(status: 403, code: "forbidden", message: "Change your email in Account settings on spoonjoy.app.")
        #expect(SettingsActionFailureMessage.serverMessage(for: emailOnWeb) == "Change your email in Account settings on spoonjoy.app.")
        #expect(SettingsActionFailureMessage.serverMessage(for: Self.apiError(status: 422, code: "validation_error", message: "Username is taken.")) == "Username is taken.")
        #expect(SettingsActionFailureMessage.serverMessage(for: Self.apiError(status: 401, code: "unauthorized", message: "Sign in again.")) == nil)
        #expect(SettingsActionFailureMessage.serverMessage(for: Self.apiError(status: 500, code: "internal_error", message: "Boom")) == nil)
        #expect(SettingsActionFailureMessage.serverMessage(for: Self.apiError(status: 400, code: "validation_error", message: "  ")) == nil)
        #expect(SettingsActionFailureMessage.serverMessage(for: AccountLifecycleTestError.unexpected) == nil)

        #expect(SettingsActionFailureMessage.diagnosticCode(for: emailOnWeb) == "settings_api_forbidden_403")
        #expect(SettingsActionFailureMessage.diagnosticCode(for: APITransportError(kind: .nonJSONResponse, requestID: nil, statusCode: 502, apiError: nil, retryDecision: .doNotRetry)) == "settings_http_502")
        #expect(SettingsActionFailureMessage.diagnosticCode(for: APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)) == "settings_transport")
        #expect(SettingsActionFailureMessage.diagnosticCode(for: SettingsActionPlanningError.offlinePolicyAllowedOnlineOnlyAction(.accountDeletion)) == "settings_plan")
        #expect(SettingsActionFailureMessage.diagnosticCode(for: AccountLifecycleTestError.unexpected) == "settings_unexpected")
    }

    // MARK: - Bylines

    @Test("the deleted-chef placeholder reads as Deleted chef on cards, recipe headers, fork credits and chef lists")
    func deletedChefBylines() {
        #expect(ChefDisplayName.forUsername("deleted-chef") == "Deleted chef")
        #expect(ChefDisplayName.forUsername("Deleted-Chef") == "Deleted chef")
        #expect(ChefDisplayName.forUsername("ari") == "ari")
        #expect(ChefDisplayName.forUsername("deleted-chef-fan") == "deleted-chef-fan")

        let placeholder = ChefSummary(id: "chef_deleted", username: "deleted-chef")
        let fork = RecipeAttribution(
            creditText: "Lemon Rice by ari on Spoonjoy",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_fork")!,
            sourceURLRaw: nil,
            sourceHost: nil,
            sourceRecipe: SourceRecipeAttribution(id: "recipe_source", title: "Lemon Herb Rice", chef: placeholder, href: nil, canonicalURL: nil, deleted: false)
        )
        let recipe = Self.recipe(chef: placeholder, attribution: fork)

        #expect(RecipeCatalogRowViewModel(summary: RecipeSummary(recipe: recipe)).chefLine == "By Deleted chef")
        let detail = RecipeDetailScreenViewModel(recipe: recipe)
        #expect(detail.chefAttribution == "By Deleted chef")
        #expect(detail.sourceAttribution?.creditLine == "forked from Deleted chef · Lemon Herb Rice")
        #expect(NativeChefRef(id: "chef_deleted", username: "deleted-chef", photoURL: nil).displayName == "Deleted chef")
        #expect(NativeChefRef(id: "chef_ari", username: "ari", photoURL: nil).displayName == "ari")

        let ordinary = Self.recipe(chef: ChefSummary(id: "chef_ari", username: "ari"), attribution: nil)
        #expect(RecipeDetailScreenViewModel(recipe: ordinary).chefAttribution == "By ari")
    }

    // MARK: - Sign in with Apple nonce

    @Test("the Apple nonce uses the sign-in alphabet and hashes to lowercase hex SHA-256")
    func appleNonce() {
        let nonce = NativeAppleSignInNonce.random()
        #expect(nonce.count == 32)
        #expect(nonce.allSatisfy { NativeAppleSignInNonce.charset.contains($0) })
        #expect(NativeAppleSignInNonce.random(length: 8).count == 8)
        #expect(NativeAppleSignInNonce.random() != NativeAppleSignInNonce.random())

        var generator = AccountLifecycleCountingGenerator()
        #expect(NativeAppleSignInNonce.random(length: 4, using: &generator) == "0000")

        #expect(NativeAppleSignInNonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    // MARK: - Store

    @MainActor
    @Test("a successful delete signs out on this device without a server revoke and wipes the queue and caches")
    func storeDeletesThenSignsOutLocally() async throws {
        try await Self.withDirectory { directory in
            let revokes = AccountLifecycleRevokeRecorder()
            let vault = try await Self.signedInVault()
            let queued = NativeQueuedMutation.cookbookCreate(clientMutationID: "cm_never_sent", title: "Weeknights", createdAt: "2026-10-09T00:00:00.000Z")
            let syncStore = try InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: NativeSyncCheckpoint(globalCursor: nil, shoppingCursor: nil, updatedAt: "2026-10-09T00:00:00.000Z"),
                queue: try NativeMutationQueue(mutations: [queued])
            )
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            try cacheStore.save(NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_ari",
                environment: .production,
                createdAt: Self.now,
                records: [],
                dismissedIndicators: []
            ))
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("app-state.json"))
            try appStateStore.save(NativeAppSnapshot.bootstrap(shoppingList: nil, accountID: "chef_ari", environment: .production, savedAt: "2026-10-09T00:00:00.000Z"))
            let api = AccountLifecycleAPITransport(response: .deleted(AccountDeletionResult(deleted: true, reassignedRecipes: 2, deletedRecipes: 5)))
            let store = Self.liveStore(
                directory: directory,
                vault: vault,
                revokes: revokes,
                cacheStore: cacheStore,
                syncStore: syncStore,
                appStateStore: appStateStore,
                api: api
            )

            let outcome = try await store.executeSettingsActionRequest(
                PrivateAccountRequests.deleteAccount(confirmUsername: "ari", proof: .password("pw")),
                responseHandling: .deleteAccountThenSignOutLocally
            )

            #expect(outcome == .deletedAccount(AccountDeletionResult(deleted: true, reassignedRecipes: 2, deletedRecipes: 5)))
            #expect(await api.requests() == [AccountLifecycleRecordedRequest(method: .delete, path: "/api/v1/me", body: ["confirmUsername": "ari", "password": "pw"])])
            #expect(await revokes.count() == 0)
            #expect(try await vault.loadSession() == nil)
            #expect(try await store.authSessionRepository.restoreState() == .signedOut)
            #expect(try await syncStore.loadQueue().mutations.isEmpty)
            await #expect(throws: NativeSyncStoreError.missingCheckpoint) { try await syncStore.loadCheckpoint() }
            let cache = try cacheStore.loadOrRecover(fallback: NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "fallback",
                environment: .production,
                createdAt: Self.now,
                records: [],
                dismissedIndicators: []
            ))
            #expect(cache.value.accountID == "signed-out")
            #expect(cache.value.records.isEmpty)
            #expect(try appStateStore.loadOrCreate(fallback: NativeAppSnapshot.bootstrap(shoppingList: nil, savedAt: "x")).value.accountID == nil)
        }
    }

    @MainActor
    @Test("a refused delete keeps the person signed in, keeps their queue, and never calls revoke")
    func storeRefusedDeleteKeepsSession() async throws {
        try await Self.withDirectory { directory in
            let revokes = AccountLifecycleRevokeRecorder()
            let vault = try await Self.signedInVault()
            let queued = NativeQueuedMutation.cookbookCreate(clientMutationID: "cm_waiting", title: "Weeknights", createdAt: "2026-10-09T00:00:00.000Z")
            let syncStore = try InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue(mutations: [queued]))
            let refusal = Self.apiError(status: 400, code: "validation_error", details: ["reason": .string("password_incorrect")])
            let store = Self.liveStore(
                directory: directory,
                vault: vault,
                revokes: revokes,
                syncStore: syncStore,
                api: AccountLifecycleAPITransport(response: .failure(refusal))
            )

            await #expect(throws: refusal) {
                try await store.executeSettingsActionRequest(
                    PrivateAccountRequests.deleteAccount(confirmUsername: "ari", proof: .password("wrong")),
                    responseHandling: .deleteAccountThenSignOutLocally
                )
            }

            #expect(await revokes.count() == 0)
            #expect(try await vault.loadSession()?.accessToken == "sj_access_current")
            #expect(try await syncStore.loadQueue().mutations.map(\.clientMutationID) == ["cm_waiting"])
        }
    }

    @MainActor
    @Test("export returns the JSON as a named file and leaves the session alone")
    func storeExports() async throws {
        try await Self.withDirectory { directory in
            let revokes = AccountLifecycleRevokeRecorder()
            let vault = try await Self.signedInVault()
            let export = JSONValue.object(["format": .string("spoonjoy.account-export.v1")])
            let api = AccountLifecycleAPITransport(response: .export(export))
            let store = Self.liveStore(
                directory: directory,
                vault: vault,
                revokes: revokes,
                syncStore: InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue()),
                api: api
            )

            let outcome = try await store.executeSettingsActionRequest(
                PrivateAccountRequests.exportAccount(),
                responseHandling: .captureAccountExport(username: "ari")
            )

            #expect(outcome == .exportedAccountData(try AccountExportFile(username: "ari", exportedAt: Self.now, export: export)))
            #expect(await api.requests() == [AccountLifecycleRecordedRequest(method: .get, path: "/api/v1/me/export", body: nil)])
            #expect(try await vault.loadSession()?.accessToken == "sj_access_current")
            #expect(await revokes.count() == 0)
        }
    }

    @MainActor
    @Test("sign out locally clears the session without a revoke; the ordinary sign-out still revokes")
    func storeSignOutLocallyVersusRevoke() async throws {
        for (operation, expectedRevokes) in [(SettingsSessionOperation.signOutLocally, 0), (.revokeAndLogout, 1)] {
            try await Self.withDirectory { directory in
                let revokes = AccountLifecycleRevokeRecorder()
                let vault = try await Self.signedInVault()
                let store = Self.liveStore(
                    directory: directory,
                    vault: vault,
                    revokes: revokes,
                    syncStore: InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue()),
                    api: AccountLifecycleAPITransport(response: .export(.null))
                )

                try await store.performSettingsSessionOperation(operation)

                #expect(await revokes.count() == expectedRevokes)
                #expect(try await vault.loadSession() == nil)
                #expect(try await store.authSessionRepository.restoreState() == .signedOut)
            }
        }
    }
}

// MARK: - Helpers

private extension AccountLifecycleTests {
    static func jsonObject(_ body: Data?) throws -> [String: String] {
        let body = try #require(body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
    }

    static func apiError(
        status: Int,
        code: String,
        message: String = "Request failed.",
        retryAfterSeconds: Int? = nil,
        details: [String: JSONValue] = [:]
    ) -> APITransportError {
        APITransportError(
            kind: .apiError,
            requestID: "req_account_lifecycle",
            statusCode: status,
            apiError: APIError(
                requestID: "req_account_lifecycle",
                code: code,
                message: message,
                status: status,
                retryAfterSeconds: retryAfterSeconds,
                details: details
            ),
            retryDecision: .doNotRetry
        )
    }

    static func account(hasPassword: Bool, providers: [SettingsAuthProvider]) -> SettingsAccountProfile {
        SettingsAccountProfile(
            id: "chef_ari",
            email: "ari@example.com",
            username: "ari",
            photoURL: nil,
            hasPassword: hasPassword,
            linkedProviders: providers.map { SettingsLinkedProvider(provider: $0, providerUsername: nil) },
            passkeys: []
        )
    }

    static func surfaceData(account: SettingsAccountProfile) -> SettingsSurfaceData {
        SettingsSurfaceData(
            account: account,
            notifications: SettingsNotificationPreferences(
                notifySpoonOnMyRecipe: true,
                notifyForkOfMyRecipe: true,
                notifyCookbookSaveOfMine: true,
                notifyFellowChefOriginCook: true
            ),
            apiTokens: [],
            oauthConnections: [],
            environment: .production,
            offline: .unavailable,
            source: .live(requestID: "req_settings", validatedAt: now)
        )
    }

    static func recipe(chef: ChefSummary, attribution: RecipeAttribution?) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/recipe_fork")!
        return Recipe(
            id: "recipe_fork",
            title: "Lemon Rice",
            description: nil,
            servings: nil,
            chef: chef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/recipe_fork",
            canonicalURL: canonicalURL,
            attribution: attribution ?? RecipeAttribution(
                creditText: "Lemon Rice by \(chef.username) on Spoonjoy",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: "2026-10-01T00:00:00.000Z",
            updatedAt: "2026-10-01T00:00:00.000Z",
            steps: [],
            cookbooks: []
        )
    }

    static func signedInVault() async throws -> InMemoryTokenVault {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID("client_live")
        try await vault.saveSession(try AuthSession(
            clientID: "client_live",
            accessToken: "sj_access_current",
            refreshToken: "sj_refresh_current",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        ))
        return vault
    }

    @MainActor
    static func withDirectory(_ body: @MainActor (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-account-lifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await body(directory)
    }

    @MainActor
    static func liveStore(
        directory: URL,
        vault: InMemoryTokenVault,
        revokes: AccountLifecycleRevokeRecorder,
        cacheStore: NativeDurableCacheStore? = nil,
        syncStore: any NativeSyncStore,
        appStateStore: NativeAppStateStore? = nil,
        api: AccountLifecycleAPITransport
    ) -> NativeLiveAppStore {
        let engine = NativeSyncEngine(store: syncStore, transport: AccountLifecycleSyncTransport(), clock: { now })
        let authRepository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Account Lifecycle Tests",
            registerClient: { _, _ in "client_live" },
            exchangeCode: { _, _, _, _ in
                OAuthTokenResponse(accessToken: "sj_access_exchanged", refreshToken: "sj_refresh_exchanged", tokenType: "Bearer", expiresIn: 3_600, scope: NativeAuthSession.defaultScope)
            },
            refresh: { _, _ in
                OAuthTokenResponse(accessToken: "sj_access_refreshed", refreshToken: "sj_refresh_refreshed", tokenType: "Bearer", expiresIn: 3_600, scope: NativeAuthSession.defaultScope)
            },
            revoke: { _, _ in await revokes.record() },
            now: { now }
        )
        return NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
            authSessionRepository: authRepository,
            cacheStore: cacheStore ?? NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: .spoonjoyProduction),
            appStateStoreProvider: { appStateStore },
            configuration: .spoonjoyProduction,
            cacheEnvironment: .production,
            recipeEditorAPITransport: { _ in api },
            bootstrapMode: .liveFirst,
            cookSessionClient: { _ in OffCookSessionClient() },
            cookSessionPushDelay: .seconds(3_600),
            now: { now }
        ))
    }
}

private enum AccountLifecycleTestError: Error {
    case unexpected
}

private struct AccountLifecycleCountingGenerator: RandomNumberGenerator {
    mutating func next() -> UInt64 { 0 }
}

private actor AccountLifecycleRevokeRecorder {
    private var revokes = 0

    func record() {
        revokes += 1
    }

    func count() -> Int {
        revokes
    }
}

private struct AccountLifecycleRecordedRequest: Equatable, Sendable {
    let method: APIRequestMethod
    let path: String
    let body: [String: String]?
}

private actor AccountLifecycleRequestRecorder {
    private var recorded: [AccountLifecycleRecordedRequest] = []

    func record(_ request: AccountLifecycleRecordedRequest) {
        recorded.append(request)
    }

    func requests() -> [AccountLifecycleRecordedRequest] {
        recorded
    }
}

private struct AccountLifecycleAPITransport: SpoonjoyAPITransport {
    enum Response: Sendable {
        case deleted(AccountDeletionResult)
        case export(JSONValue)
        case failure(APITransportError)
    }

    private let response: Response
    private let recorder = AccountLifecycleRequestRecorder()

    init(response: Response) {
        self.response = response
    }

    func requests() async -> [AccountLifecycleRecordedRequest] {
        await recorder.requests()
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let apiRequest = try request.urlRequest(configuration: configuration)
        let body = try apiRequest.body.map { try JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? nil
        await recorder.record(AccountLifecycleRecordedRequest(method: apiRequest.method, path: apiRequest.url.path, body: body))
        switch response {
        case .deleted(let result):
            if let data = result as? Value {
                return APIEnvelope(requestID: "req_deleted", data: data)
            }
        case .export(let export):
            if let data = export as? Value {
                return APIEnvelope(requestID: "req_export", data: data)
            }
        case .failure(let error):
            throw error
        }
        throw AccountLifecycleTestError.unexpected
    }
}

private struct AccountLifecycleSyncTransport: NativeSyncTransport {
    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        .success(cursor: nil, tombstones: [])
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        .success(serverRevision: .updatedAt(mutation.createdAt))
    }
}
