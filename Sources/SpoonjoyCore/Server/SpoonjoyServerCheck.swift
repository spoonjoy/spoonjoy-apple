import Foundation

/// Why a server address did not check out as a Spoonjoy server.
public enum SpoonjoyServerCheckError: Error, Equatable, Sendable {
    /// Nothing answered: the address is wrong, the server is down, or the network is.
    case unreachable(String)
    /// Nothing answered from a server on the local network, which the cook may first have to let Spoonjoy find.
    case unreachableOnLocalNetwork(String)
    /// Something answered, but not as a Spoonjoy server does.
    case notSpoonjoy(String)

    public var message: String {
        switch self {
        case .unreachable(let name):
            "Spoonjoy couldn't reach \(name). Check the address, and that the server is running and on this network."
        case .unreachableOnLocalNetwork(let name):
            "Spoonjoy couldn't reach \(name). If Spoonjoy asked to find devices on your local network, allow it, then try again."
        case .notSpoonjoy(let name):
            "\(name) answered, but it isn't a Spoonjoy server."
        }
    }
}

/// Asks a server whether it is Spoonjoy before the app signs in to it: `GET /api/v1/health`, which every Spoonjoy
/// server answers without credentials with `{"ok": true, "data": {"ok": true, "version": "v1", ...}}`.
public enum SpoonjoyServerCheck {
    public static let timeout: TimeInterval = 15

    private struct Health: Decodable, Equatable {
        let ok: Bool
        let version: String
    }

    public static func urlRequest(for address: SpoonjoyServerAddress) -> URLRequest {
        var request = URLRequest(
            url: address.baseURL.appending(path: "api/v1/health"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Whether reaching the server needs the system's local network permission: a local host other than this device.
    public static func needsLocalNetworkPermission(_ address: SpoonjoyServerAddress) -> Bool {
        // Every server address has a host: parsing refuses one without.
        let host = address.baseURL.host(percentEncoded: false)!.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let loopback = host == "localhost" || host == "::1" || host.hasPrefix("127.")
        return SpoonjoyServerAddress.isLocalNetworkHost(host) && !loopback
    }

    /// Whether an answer to `urlRequest(for:)` is a Spoonjoy server's.
    public static func isSpoonjoyHealth(_ data: Data, response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let health = try? APIEnvelope<Health>.decode(data).data else {
            return false
        }
        return health.ok && health.version == "v1"
    }

    public static func check(
        _ address: SpoonjoyServerAddress,
        session: any URLSessionPerforming = URLSession.shared
    ) async throws(SpoonjoyServerCheckError) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest(for: address))
        } catch {
            // The first request to a server on the local network asks the cook's permission and fails meanwhile;
            // loopback never asks.
            throw needsLocalNetworkPermission(address) ? .unreachableOnLocalNetwork(address.displayName) : .unreachable(address.displayName)
        }
        guard isSpoonjoyHealth(data, response: response) else {
            throw .notSpoonjoy(address.displayName)
        }
    }
}
