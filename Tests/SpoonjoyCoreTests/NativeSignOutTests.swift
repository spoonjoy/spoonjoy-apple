import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native sign-out")
struct NativeSignOutTests {
    private let now = Date(timeIntervalSince1970: 1_781_612_800)

    private actor RevokeAttempts {
        private(set) var requests: [String] = []
        func record(_ refreshToken: String, _ clientID: String) {
            requests.append("\(clientID):\(refreshToken)")
        }
    }

    private func signedInVault() async throws -> InMemoryTokenVault {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID("cm_native_spoonjoy")
        try await vault.saveSession(try AuthSession(
            clientID: "cm_native_spoonjoy",
            accessToken: "sj_access_current",
            refreshToken: "ort_refresh_current",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        ))
        return vault
    }

    private func repository(
        vault: InMemoryTokenVault,
        revoke: @escaping NativeRevokeOperation
    ) -> NativeAuthSessionRepository {
        let now = self.now
        return NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "cm_native_spoonjoy" },
            exchangeCode: { _, _, _, _ in throw URLError(.badServerResponse) },
            refresh: { _, _ in throw URLError(.badServerResponse) },
            revoke: revoke,
            now: { now }
        )
    }

    @Test("sign-out clears the local session when the revoke fails", arguments: [
        URLError(.notConnectedToInternet),
        URLError(.timedOut),
        URLError(.badServerResponse)
    ])
    func signOutClearsLocalSessionWhenRevokeFails(failure: URLError) async throws {
        let vault = try await signedInVault()
        let attempts = RevokeAttempts()
        let repository = repository(vault: vault) { refreshToken, clientID in
            await attempts.record(refreshToken, clientID)
            throw failure
        }

        try await repository.revokeAndLogout()

        #expect(await attempts.requests == ["cm_native_spoonjoy:ort_refresh_current"])
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == nil)
        #expect(try await repository.restoreState() == .signedOut)
    }

    @Test("sign-out still revokes on the server when the network is available")
    func signOutRevokesOnServerWhenAvailable() async throws {
        let vault = try await signedInVault()
        let attempts = RevokeAttempts()
        let repository = repository(vault: vault) { refreshToken, clientID in
            await attempts.record(refreshToken, clientID)
        }

        try await repository.revokeAndLogout()

        #expect(await attempts.requests == ["cm_native_spoonjoy:ort_refresh_current"])
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == nil)
        #expect(try await repository.restoreState() == .signedOut)
    }
}
