import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native auth session contract")
struct NativeAuthSessionTests {
    @Test("OAuth callback contract uses universal links and rejects custom schemes")
    func oauthCallbackContractUsesUniversalLinksAndRejectsCustomSchemes() throws {
        #expect(try OAuthRedirectValidator.validate(URL(string: "https://spoonjoy.app/oauth/callback")!))
        #expect(DeepLinkRouter.spoonjoy.route(for: URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!) == .unknownLink)
        #expect(DeepLinkRouter.spoonjoy.route(for: URL(string: "spoonjoy://oauth/callback?code=oac_code&state=state_123")!) == .unknownLink)

        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "spoonjoy://oauth/callback")!)
        }
    }

    @Test("app bundle declares associated domains without treating custom scheme as OAuth redirect")
    func appBundleDeclaresAssociatedDomainsWithoutTreatingCustomSchemeAsOAuthRedirect() throws {
        let infoPlist = try propertyListDictionary("Apps/Spoonjoy/Shared/Info.plist")
        let entitlements = try propertyListDictionary("Apps/Spoonjoy/Shared/Spoonjoy.entitlements")
        let urlTypes = try #require(infoPlist["CFBundleURLTypes"] as? [[String: Any]])
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        let associatedDomains = try #require(entitlements["com.apple.developer.associated-domains"] as? [String])

        #expect(schemes == ["spoonjoy"])
        #expect(associatedDomains.contains("applinks:spoonjoy.app"))
        #expect(!schemes.contains("spoonjoy://oauth/callback"))
        #expect(!associatedDomains.contains("applinks:oauth/callback"))
    }

    @Test("native auth session source defines launch callback and restoration contract")
    func nativeAuthSessionSourceDefinesLaunchCallbackAndRestorationContract() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Auth/NativeAuthSession.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Auth/NativeAuthSession.swift",
            contains: [
                "NativeAuthSession",
                "NativeAuthSessionState",
                "NativeAuthSessionError",
                "startSignIn",
                "handleOAuthCallback",
                "restoreState",
                "revokeAndLogout",
                "https://spoonjoy.app/oauth/callback",
                "OAuthRedirectValidator",
                "OAuthRequests.authorize",
                "OAuthRequests.exchangeCode",
                "OAuthRequests.revoke",
                "RefreshCoordinator"
            ],
            forbids: [
                "spoonjoy://oauth/callback",
                "spoonjoy://oauth"
            ]
        )
    }

    @Test("ASWebAuthenticationSession adapter launches exact HTTPS callback route")
    func authenticationSessionAdapterLaunchesExactHTTPSCallbackRoute() throws {
        let content = try readRepoFile("Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift")

        expectContent(
            content,
            in: "Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift",
            contains: [
                "AuthenticationServices",
                "ASWebAuthenticationSession",
                "SpoonjoyWebAuthenticationSession",
                "presentationContextProvider",
                "prefersEphemeralWebBrowserSession",
                "https://spoonjoy.app/oauth/callback",
                "callbackURLScheme",
                "handleOAuthCallback",
                "OAuthState"
            ],
            forbids: [
                "spoonjoy://oauth/callback",
                "spoonjoy://oauth"
            ]
        )
    }

    @Test("Keychain token vault stores auth material outside general cache")
    func keychainTokenVaultStoresAuthMaterialOutsideGeneralCache() throws {
        let content = try readRepoFile("Apps/Spoonjoy/Shared/Auth/KeychainTokenVault.swift")

        expectContent(
            content,
            in: "Apps/Spoonjoy/Shared/Auth/KeychainTokenVault.swift",
            contains: [
                "Security",
                "KeychainTokenVault",
                "TokenVault",
                "loadClientID",
                "saveClientID",
                "loadSession",
                "saveSession",
                "clearSession",
                "clearClientID",
                "kSecClassGenericPassword",
                "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly",
                "kSecAttrService",
                "spoonjoy.auth.client-id",
                "spoonjoy.auth.session"
            ],
            forbids: [
                "UserDefaults",
                "JSONFileStore",
                "FileManager.default",
                ".json"
            ]
        )
    }

    @Test("refresh rotation revoke logout and restoration persist through native repository")
    func refreshRotationRevokeLogoutAndRestorationPersistThroughNativeRepository() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Auth/NativeAuthSessionRepository.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Auth/NativeAuthSessionRepository.swift",
            contains: [
                "NativeAuthSessionRepository",
                "TokenVault",
                "RefreshCoordinator",
                "restoreState",
                "validSession",
                "saveClientID",
                "saveSession",
                "OAuthRequests.refreshToken",
                "OAuthRequests.revoke",
                "clearSession",
                "clearClientID",
                "revokeAndLogout"
            ],
            forbids: [
                "UserDefaults",
                "MutationQueue",
                "queue"
            ]
        )
    }

    @Test("secure web handoff URLs are exact and separate from native OAuth redirects")
    func secureWebHandoffURLsAreExactAndSeparateFromNativeOAuthRedirects() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Auth/SecureAuthWebHandoff.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Auth/SecureAuthWebHandoff.swift",
            contains: [
                "SecureAuthWebHandoff",
                "https://spoonjoy.app/login",
                "https://spoonjoy.app/signup",
                "https://spoonjoy.app/logout",
                "https://spoonjoy.app/auth/google",
                "https://spoonjoy.app/auth/github",
                "https://spoonjoy.app/auth/apple",
                "https://spoonjoy.app/agent/connect",
                "https://spoonjoy.app/oauth/authorize"
            ],
            forbids: [
                "spoonjoy://login",
                "spoonjoy://signup",
                "spoonjoy://logout",
                "spoonjoy://oauth"
            ]
        )
    }

    @Test("xcodebuild blocker wrapper classifies only local pre-parse platform faults")
    func xcodebuildBlockerWrapperClassifiesOnlyLocalPreParsePlatformFaults() throws {
        let content = try readRepoFile("scripts/run-xcodebuild-with-blocker.sh")

        expectContent(
            content,
            in: "scripts/run-xcodebuild-with-blocker.sh",
            contains: [
                "set -euo pipefail",
                "xcodebuild -version",
                "xcode-select -p",
                "xcodebuild -checkFirstLaunchStatus",
                "XcodePlatform",
                "timeoutSeconds",
                "outputPath",
                "iOS 26.5 is not installed",
                "Unable to find a destination",
                "CoreSimulator",
                "DVTPlugIn",
                "IDEDistribution",
                "command_status",
                "exit \"$command_status\""
            ],
            forbids: [
                "|| true",
                "2>/dev/null",
                "grep -q warning"
            ]
        )
    }

    @Test("local validation matrix delegates xcodebuild classification to wrapper")
    func localValidationMatrixDelegatesXcodebuildClassificationToWrapper() throws {
        let content = try readRepoFile("scripts/validate-native-local.sh")

        expectContent(
            content,
            in: "scripts/validate-native-local.sh",
            contains: [
                "scripts/run-xcodebuild-with-blocker.sh",
                "matrix-xcodebuild-ios.log",
                "matrix-xcodebuild-macos.log",
                "ios-app-bundle-blocker.json",
                "macos-app-bundle-blocker.json",
                "XcodePlatform"
            ],
            forbids: [
                "run_blockable",
                "allowed_blocker_pattern"
            ]
        )
    }
}

private enum NativeAuthContractError: Error, CustomStringConvertible {
    case missingFile(String)
    case unreadablePropertyList(String)

    var description: String {
        switch self {
        case .missingFile(let path):
            return "Missing required native auth contract file: \(path)"
        case .unreadablePropertyList(let path):
            return "Could not read property list contract file: \(path)"
        }
    }
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRoot().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeAuthContractError.missingFile(relativePath)
    }

    return try String(contentsOf: url, encoding: .utf8)
}

private func propertyListDictionary(_ relativePath: String) throws -> [String: Any] {
    let url = repoRoot().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeAuthContractError.missingFile(relativePath)
    }

    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    guard let dictionary = plist as? [String: Any] else {
        throw NativeAuthContractError.unreadablePropertyList(relativePath)
    }

    return dictionary
}

private func repoRoot() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func expectContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String],
    forbids forbiddenTokens: [String]
) {
    for token in requiredTokens {
        let hasToken = content.contains(token)
        #expect(hasToken, "\(relativePath) missing required token \(token)")
    }

    for token in forbiddenTokens {
        let doesNotHaveForbiddenToken = !content.contains(token)
        #expect(doesNotHaveForbiddenToken, "\(relativePath) must not contain forbidden token \(token)")
    }
}
