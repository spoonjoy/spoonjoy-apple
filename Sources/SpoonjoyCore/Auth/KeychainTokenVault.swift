import Foundation
import Security

public actor KeychainTokenVault: TokenVault {
    private enum Item: String {
        case clientID = "spoonjoy.auth.client-id"
        case session = "spoonjoy.auth.session"
    }

    private let accessGroup: String?
    private let keychain: KeychainTokenVaultClient
    private let allowsUnsignedLocalFallback: Bool
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(accessGroup: String? = nil) {
        self.init(accessGroup: accessGroup, keychain: SystemKeychainTokenVaultClient())
    }

    public init(accessGroup: String? = nil, allowsUnsignedLocalFallback: Bool) {
        self.init(
            accessGroup: accessGroup,
            keychain: SystemKeychainTokenVaultClient(),
            allowsUnsignedLocalFallback: allowsUnsignedLocalFallback
        )
    }

    init(
        accessGroup: String? = nil,
        keychain: KeychainTokenVaultClient,
        allowsUnsignedLocalFallback: Bool = false
    ) {
        self.accessGroup = accessGroup
        self.keychain = keychain
        self.allowsUnsignedLocalFallback = allowsUnsignedLocalFallback
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
        let status = keychain.copyMatching(query, &result)
        if status == errSecItemNotFound || isAllowedUnsignedLocalFallback(status) {
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
        let updateStatus = keychain.update(query, attributes)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainTokenVaultError.unhandledStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        let addStatus = keychain.add(query)
        guard addStatus == errSecSuccess else {
            throw KeychainTokenVaultError.unhandledStatus(addStatus)
        }
    }

    private func deleteData(for item: Item) throws {
        let status = keychain.delete(baseQuery(for: item))
        guard status == errSecSuccess || status == errSecItemNotFound || isAllowedUnsignedLocalFallback(status) else {
            throw KeychainTokenVaultError.unhandledStatus(status)
        }
    }

    private func isAllowedUnsignedLocalFallback(_ status: OSStatus) -> Bool {
        allowsUnsignedLocalFallback && status == errSecMissingEntitlement
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

protocol KeychainTokenVaultClient {
    func copyMatching(_ query: [String: Any], _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
    func add(_ query: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

struct SystemKeychainTokenVaultClient: KeychainTokenVaultClient {
    func copyMatching(_ query: [String: Any], _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        SecItemCopyMatching(query as CFDictionary, result)
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func add(_ query: [String: Any]) -> OSStatus {
        SecItemAdd(query as CFDictionary, nil)
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}
