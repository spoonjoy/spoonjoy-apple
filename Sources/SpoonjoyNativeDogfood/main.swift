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
        let configuration = APIClientConfiguration(baseURL: arguments.baseURL)
        let vault = FileBackedTokenVault(fileURL: arguments.vaultURL)
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
                password: arguments.password
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
            baseURL: arguments.baseURL.absoluteString,
            vaultFile: arguments.vaultURL.path,
            clientID: boundSession.clientID,
            accountID: syncEnvelope.data.freshness.accountID,
            tokenType: boundSession.tokenType,
            scopeCount: boundSession.scope.split(separator: " ").count,
            syncEnvironment: syncEnvelope.data.freshness.environment.rawValue,
            syncEntryCount: syncEnvelope.data.entries.count,
            syncHasMore: syncEnvelope.data.hasMore,
            wroteVault: FileManager.default.fileExists(atPath: arguments.vaultURL.path)
        )
    }
}

private struct DogfoodArguments: Equatable {
    let baseURL: URL
    let identifier: String
    let password: String
    let vaultURL: URL
    let reportURL: URL?

    static func parse(_ arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) throws -> DogfoodArguments {
        var baseURLString = environment["SPOONJOY_API_BASE_URL"] ?? "http://localhost:5173"
        var identifier = environment["SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER"] ?? ""
        let password = try passwordFromEnvironment(environment)
        var vaultPath = environment["SPOONJOY_NATIVE_DOGFOOD_VAULT"] ?? ""
        var reportPath = environment["SPOONJOY_NATIVE_DOGFOOD_REPORT"]

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
        guard !trimmedIdentifier.isEmpty else {
            throw DogfoodArgumentError.missingIdentifier
        }
        guard !password.isEmpty else {
            throw DogfoodArgumentError.missingPassword
        }
        let trimmedVaultPath = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVaultPath.isEmpty else {
            throw DogfoodArgumentError.missingVault
        }

        return DogfoodArguments(
            baseURL: baseURL,
            identifier: trimmedIdentifier,
            password: password,
            vaultURL: URL(fileURLWithPath: (trimmedVaultPath as NSString).expandingTildeInPath),
            reportURL: reportPath.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        )
    }

    private static func passwordFromEnvironment(_ environment: [String: String]) throws -> String {
        if let passwordFile = environment["SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !passwordFile.isEmpty {
            let rawPassword = try String(contentsOfFile: (passwordFile as NSString).expandingTildeInPath, encoding: .utf8)
            return rawPassword.trimmingCharacters(in: .newlines)
        }
        return environment["SPOONJOY_NATIVE_DOGFOOD_PASSWORD"] ?? ""
    }
}

private enum DogfoodArgumentError: Error, CustomStringConvertible {
    case missingValue(String)
    case unknownArgument(String)
    case invalidBaseURL(String)
    case missingIdentifier
    case missingPassword
    case missingVault

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
        }
    }
}

private struct DogfoodReport: Codable, Equatable {
    let ok: Bool
    let baseURL: String
    let vaultFile: String
    let clientID: String
    let accountID: String
    let tokenType: String
    let scopeCount: Int
    let syncEnvironment: String
    let syncEntryCount: Int
    let syncHasMore: Bool
    let wroteVault: Bool
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
