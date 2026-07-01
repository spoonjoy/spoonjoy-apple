import Foundation

public actor FileBackedTokenVault: TokenVault {
    private struct Snapshot: Codable, Equatable {
        var clientID: String?
        var session: AuthSession?
    }

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadClientID() async throws -> String? {
        try snapshot().clientID
    }

    public func saveClientID(_ clientID: String) async throws {
        var snapshot = try snapshot()
        snapshot.clientID = clientID
        try save(snapshot)
    }

    public func clearClientID() async throws {
        var snapshot = try snapshot()
        snapshot.clientID = nil
        try save(snapshot)
    }

    public func loadSession() async throws -> AuthSession? {
        try snapshot().session
    }

    public func saveSession(_ session: AuthSession) async throws {
        var snapshot = try snapshot()
        snapshot.session = session
        try save(snapshot)
    }

    public func clearSession() async throws {
        var snapshot = try snapshot()
        snapshot.session = nil
        try save(snapshot)
    }

    private func snapshot() throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Snapshot()
        }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty {
            return Snapshot()
        }
        return try decoder.decode(Snapshot.self, from: data)
    }

    private func save(_ snapshot: Snapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
