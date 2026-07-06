import Foundation
import SpoonjoyCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main
struct SpoonjoyNativeDogfood {
    static func main() async {
        do {
            try await runMain()
        } catch {
            FileHandle.standardError.write(Data("Spoonjoy native dogfood failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func runMain() async throws {
        let arguments = try DogfoodArguments.parse(Array(CommandLine.arguments.dropFirst()))
        let report = try await run(arguments: arguments)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)

        if let outputURL = arguments.reportURL {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL, options: [.atomic])
        } else {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    private static func run(arguments: DogfoodArguments) async throws -> DogfoodReport {
        if let bearerTokenFileURL = arguments.bearerTokenFileURL {
            return try await runBearerToken(arguments: arguments, bearerTokenFileURL: bearerTokenFileURL)
        }

        guard let password = arguments.password,
              let vaultURL = arguments.vaultURL else {
            throw DogfoodArgumentError.missingPassword
        }

        let configuration = APIClientConfiguration(baseURL: arguments.baseURL)
        let vault = FileBackedTokenVault(fileURL: vaultURL)
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Dogfood",
            redirectURI: NativeAuthSession.localDogfoodRedirectURI,
            registerClient: { _, _ in NativeAuthSession.nativeAppClientID },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            exchangePasswordCredential: { credential in
                try await DogfoodOAuthTransport.sendDecoded(
                    try NativePasswordSignInRequests.exchangeCredential(credential),
                    configuration: configuration,
                    decode: OAuthTokenResponse.self
                )
            },
            refresh: { _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            revoke: { _, _ in },
            reusesSavedClientID: false
        )

        let session = try await repository.handlePasswordSignInCredential(
            NativePasswordSignInCredential(
                emailOrUsername: arguments.identifier,
                password: password
            )
        )
        let syncEnvelope = try await URLSessionAPITransport().send(
            NativeSyncBootstrapRequest.defaultRequest(cursor: nil),
            configuration: APIClientConfiguration(baseURL: arguments.baseURL, bearerToken: session.accessToken),
            decode: NativeSyncData.self
        )
        let boundSession = try await repository.bindAccountID(syncEnvelope.data.freshness.accountID)

        return DogfoodReport(
            ok: true,
            mode: "password",
            baseURL: arguments.baseURL.absoluteString,
            vaultFile: vaultURL.path,
            clientID: boundSession.clientID,
            accountID: syncEnvelope.data.freshness.accountID,
            tokenType: boundSession.tokenType,
            scopeCount: boundSession.scope.split(separator: " ").count,
            syncEnvironment: syncEnvelope.data.freshness.environment.rawValue,
            syncEntryCount: syncEnvelope.data.entries.count,
            syncHasMore: syncEnvelope.data.hasMore,
            syncCachedRecordCount: nil,
            settingsFetched: nil,
            tokenManagementAvailability: nil,
            wroteVault: FileManager.default.fileExists(atPath: vaultURL.path)
        )
    }

    private static func runBearerToken(arguments: DogfoodArguments, bearerTokenFileURL: URL) async throws -> DogfoodReport {
        let rawToken = try String(contentsOf: bearerTokenFileURL, encoding: .utf8)
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw DogfoodArgumentError.missingBearerToken
        }

        let configuration = APIClientConfiguration(baseURL: arguments.baseURL, bearerToken: token)
        let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
        let syncEngine = NativeSyncEngine(store: syncStore, transport: URLSessionNativeSyncTransport())
        let syncReport = try await syncEngine.bootstrapAndDrain(
            configuration: configuration,
            trigger: .launch,
            scope: .unbound
        )
        let snapshot = await syncStore.loadSnapshot()
        let accountID = try require(syncReport.accountID ?? snapshot.accountID, DogfoodArgumentError.missingSyncedAccount)
        let environment = syncReport.environment ?? snapshot.environment ?? .production
        let settings = try await LiveSettingsSurfaceRepository(
            cache: NativeDurableCache(),
            configuration: configuration
        ).fetchSettingsSurface(
            accountID: accountID,
            environment: environment,
            grantedScopes: arguments.grantedScopes
        )

        return DogfoodReport(
            ok: true,
            mode: "bearer",
            baseURL: arguments.baseURL.absoluteString,
            vaultFile: nil,
            clientID: NativeAuthSession.nativeAppClientID,
            accountID: accountID,
            tokenType: "Bearer",
            scopeCount: arguments.grantedScopes.count,
            syncEnvironment: environment.rawValue,
            syncEntryCount: snapshot.cachedRecords.count,
            syncHasMore: false,
            syncCachedRecordCount: snapshot.cachedRecords.count,
            settingsFetched: settings.data.account != nil || settings.data.notifications != nil,
            tokenManagementAvailability: "\(settings.data.tokenManagementAvailability)",
            wroteVault: false
        )
    }
}

private struct DogfoodArguments: Equatable {
    let baseURL: URL
    let identifier: String
    let password: String?
    let vaultURL: URL?
    let reportURL: URL?
    let bearerTokenFileURL: URL?
    let grantedScopes: Set<String>

    static func parse(_ arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) throws -> DogfoodArguments {
        var baseURLString = environment["SPOONJOY_API_BASE_URL"] ?? "http://localhost:5173"
        var identifier = environment["SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER"] ?? ""
        let password = try passwordFromEnvironment(environment)
        var vaultPath = environment["SPOONJOY_NATIVE_DOGFOOD_VAULT"] ?? ""
        var reportPath = environment["SPOONJOY_NATIVE_DOGFOOD_REPORT"]
        var bearerTokenFilePath = environment["SPOONJOY_NATIVE_DOGFOOD_BEARER_TOKEN_FILE"] ?? ""
        var grantedScope = environment["SPOONJOY_NATIVE_DOGFOOD_SCOPE"] ?? NativeAuthSession.defaultScope

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard index + 1 < arguments.count else {
                throw DogfoodArgumentError.missingValue(argument)
            }
            let value = arguments[index + 1]
            switch argument {
            case "--base-url":
                baseURLString = value
            case "--identifier":
                identifier = value
            case "--vault-file":
                vaultPath = value
            case "--report":
                reportPath = value
            case "--bearer-token-file":
                bearerTokenFilePath = value
            case "--scope":
                grantedScope = value
            default:
                throw DogfoodArgumentError.unknownArgument(argument)
            }
            index += 2
        }

        guard let baseURL = URL(string: baseURLString),
              let scheme = baseURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              baseURL.host?.isEmpty == false else {
            throw DogfoodArgumentError.invalidBaseURL(baseURLString)
        }
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBearerTokenFilePath = bearerTokenFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let usesBearerToken = !trimmedBearerTokenFilePath.isEmpty
        guard usesBearerToken || !trimmedIdentifier.isEmpty else {
            throw DogfoodArgumentError.missingIdentifier
        }
        guard usesBearerToken || !(password?.isEmpty ?? true) else {
            throw DogfoodArgumentError.missingPassword
        }
        let trimmedVaultPath = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard usesBearerToken || !trimmedVaultPath.isEmpty else {
            throw DogfoodArgumentError.missingVault
        }
        let scopes = Set(grantedScope.split(separator: " ").map(String.init))

        return DogfoodArguments(
            baseURL: baseURL,
            identifier: trimmedIdentifier,
            password: password,
            vaultURL: trimmedVaultPath.isEmpty ? nil : URL(fileURLWithPath: (trimmedVaultPath as NSString).expandingTildeInPath),
            reportURL: reportPath.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) },
            bearerTokenFileURL: usesBearerToken ? URL(fileURLWithPath: (trimmedBearerTokenFilePath as NSString).expandingTildeInPath) : nil,
            grantedScopes: scopes
        )
    }

    private static func passwordFromEnvironment(_ environment: [String: String]) throws -> String? {
        if let passwordFile = environment["SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !passwordFile.isEmpty {
            let rawPassword = try String(contentsOfFile: (passwordFile as NSString).expandingTildeInPath, encoding: .utf8)
            return rawPassword.trimmingCharacters(in: .newlines)
        }
        return environment["SPOONJOY_NATIVE_DOGFOOD_PASSWORD"]
    }
}

private enum DogfoodArgumentError: Error, CustomStringConvertible {
    case missingValue(String)
    case unknownArgument(String)
    case invalidBaseURL(String)
    case missingIdentifier
    case missingPassword
    case missingVault
    case missingBearerToken
    case missingSyncedAccount

    var description: String {
        switch self {
        case .missingValue(let argument):
            return "\(argument) requires a value."
        case .unknownArgument(let argument):
            return "Unknown argument \(argument)."
        case .invalidBaseURL(let value):
            return "Invalid --base-url \(value)."
        case .missingIdentifier:
            return "Provide --identifier or SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER."
        case .missingPassword:
            return "Set SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE or SPOONJOY_NATIVE_DOGFOOD_PASSWORD in the environment; CLI password arguments are intentionally unsupported."
        case .missingVault:
            return "Set SPOONJOY_NATIVE_DOGFOOD_VAULT or pass --vault-file so dogfood auth material stays in an explicit artifact path."
        case .missingBearerToken:
            return "The bearer token file is empty."
        case .missingSyncedAccount:
            return "Native sync completed without an account id."
        }
    }
}

private struct DogfoodReport: Codable, Equatable {
    let ok: Bool
    let mode: String
    let baseURL: String
    let vaultFile: String?
    let clientID: String
    let accountID: String
    let tokenType: String
    let scopeCount: Int
    let syncEnvironment: String
    let syncEntryCount: Int
    let syncHasMore: Bool
    let syncCachedRecordCount: Int?
    let settingsFetched: Bool?
    let tokenManagementAvailability: String?
    let wroteVault: Bool
}

private func require<Value>(_ value: Value?, _ error: Error) throws -> Value {
    guard let value else {
        throw error
    }
    return value
}


private enum DogfoodOAuthTransport {
    static func sendDecoded<Value: Decodable & Equatable>(
        _ builder: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> Value {
        let data = try await send(builder, configuration: configuration)
        if let envelope = try? APIEnvelope<Value>.decode(data) {
            return envelope.data
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    private static func send(_ builder: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> Data {
        let request = try builder.urlRequest(configuration: configuration)
        guard var components = URLComponents(url: request.url.baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.percentEncodedPath = request.url.path
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APITransportError(
                kind: .nonHTTPResponse,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw APITransportError(
                kind: .apiError,
                requestID: nil,
                statusCode: httpResponse.statusCode,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        }
        return data
    }
}
