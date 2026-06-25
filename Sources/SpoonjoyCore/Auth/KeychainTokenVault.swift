import Foundation
import Security

public actor KeychainTokenVault: TokenVault {
    private enum Item: String {
        case clientID = "spoonjoy.auth.client-id"
        case session = "spoonjoy.auth.session"
    }

    private let accessGroup: String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    public func loadClientID() async throws -> String? {
        guard let data = try readData(for: .clientID) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    public func saveClientID(_ clientID: String) async throws {
        try writeData(Data(clientID.utf8), for: .clientID)
    }

    public func clearClientID() async throws {
        try deleteData(for: .clientID)
    }

    public func loadSession() async throws -> AuthSession? {
        guard let data = try readData(for: .session) else {
            return nil
        }

        return try decoder.decode(AuthSession.self, from: data)
    }

    public func saveSession(_ session: AuthSession) async throws {
        try writeData(try encoder.encode(session), for: .session)
    }

    public func clearSession() async throws {
        try deleteData(for: .session)
    }

    private func readData(for item: Item) throws -> Data? {
        var query = baseQuery(for: item)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainTokenVaultError.unhandledStatus(status)
        }

        return result as? Data
    }

    private func writeData(_ data: Data, for item: Item) throws {
        var query = baseQuery(for: item)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainTokenVaultError.unhandledStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainTokenVaultError.unhandledStatus(addStatus)
        }
    }

    private func deleteData(for item: Item) throws {
        let status = SecItemDelete(baseQuery(for: item) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainTokenVaultError.unhandledStatus(status)
        }
    }

    private func baseQuery(for item: Item) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrService as String: item.rawValue,
            kSecAttrAccount as String: "Spoonjoy"
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

public enum KeychainTokenVaultError: Error, Equatable {
    case unhandledStatus(OSStatus)
}
