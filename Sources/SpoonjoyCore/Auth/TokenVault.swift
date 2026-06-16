public protocol TokenVault: Sendable {
    func loadClientID() async throws -> String?
    func saveClientID(_ clientID: String) async throws
    func clearClientID() async throws
    func loadSession() async throws -> AuthSession?
    func saveSession(_ session: AuthSession) async throws
    func clearSession() async throws
}
