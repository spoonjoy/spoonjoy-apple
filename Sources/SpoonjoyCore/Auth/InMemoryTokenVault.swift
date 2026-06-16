import Foundation

public actor InMemoryTokenVault: TokenVault {
    private var clientID: String?
    private var session: AuthSession?

    public init() {}

    public func loadClientID() async throws -> String? {
        clientID
    }

    public func saveClientID(_ clientID: String) async throws {
        let clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            throw AuthSessionError.invalidClientID
        }

        self.clientID = clientID
    }

    public func clearClientID() async throws {
        clientID = nil
    }

    public func loadSession() async throws -> AuthSession? {
        session
    }

    public func saveSession(_ session: AuthSession) async throws {
        self.session = session
    }

    public func clearSession() async throws {
        session = nil
    }
}
