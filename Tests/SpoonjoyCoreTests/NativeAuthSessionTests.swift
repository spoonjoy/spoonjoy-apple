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
            try OAuthRedirectValidator.validate(URL(string: "https://spoonjoy.app/not-oauth")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "https://spoonjoy.app/oauth/callback/extra")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "spoonjoy://oauth/callback")!)
        }
    }

    @Test("native auth repository behavior persists client id rotates refresh tokens revokes and restores state")
    func nativeAuthRepositoryBehaviorPersistsClientIDRotatesRefreshTokensRevokesAndRestoresState() throws {
        let result = try runSwiftContractPackage(
            name: "NativeAuthBehaviorProbe",
            testSource: nativeAuthBehaviorContractSource
        )

        #expect(result.status == 0, Comment(rawValue: result.truncatedOutput))
    }

    @Test("native auth implementation is covered in process")
    func nativeAuthImplementationIsCoveredInProcess() async throws {
        let now = Date(timeIntervalSince1970: 1_781_612_800)
        let vault = InMemoryTokenVault()
        let network = CoverageAuthNetworkSpy(
            clientID: "cm_native_spoonjoy",
            exchangeResponse: coverageTokenResponse(accessToken: "sj_access_initial", refreshToken: "ort_refresh_initial", expiresIn: 300),
            refreshResponse: coverageTokenResponse(accessToken: "sj_access_rotated", refreshToken: "ort_refresh_rotated", expiresIn: 600)
        )
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            redirectURI: NativeAuthSession.redirectURI,
            scope: NativeAuthSession.defaultScope,
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke,
            now: { now }
        )

        #expect(try await repository.restoreState() == .signedOut)
        let state = try #require(OAuthState(rawValue: "state_123"))
        let start = try await repository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        #expect(start.clientID == "cm_native_spoonjoy")
        #expect(start.authorizationURL.path == "/oauth/authorize")
        let secondStart = try await repository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        #expect(secondStart.clientID == start.clientID)
        #expect(await network.registerRequests.count == 1)

        let session = try await repository.handleOAuthCallback(
            URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!,
            expectedState: state,
            codeVerifier: "pkce_verifier"
        )
        #expect(session.accessToken == "sj_access_initial")
        #expect(try await repository.restoreState() == .authenticated(session))
        #expect(await network.exchangeRequests == [
            CoverageCodeExchangeRequest(clientID: "cm_native_spoonjoy", redirectURI: "https://spoonjoy.app/oauth/callback", code: "oac_code", codeVerifier: "pkce_verifier")
        ])

        let expired = try AuthSession(
            clientID: "cm_native_spoonjoy",
            accessToken: "sj_access_expired",
            refreshToken: "ort_refresh_initial",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(-1),
            scope: NativeAuthSession.defaultScope
        )
        try await vault.saveSession(expired)
        #expect(try await repository.restoreState() == .refreshRequired(expired))
        let refreshed = try await repository.validSession()
        #expect(refreshed.accessToken == "sj_access_rotated")
        try await repository.revokeAndLogout()
        #expect(try await repository.restoreState() == .signedOut)
        #expect(await network.revokeRequests == [
            CoverageRevokeRequest(refreshToken: "ort_refresh_rotated", clientID: "cm_native_spoonjoy")
        ])
        try await repository.revokeAndLogout()

        let missingClientRepository = NativeAuthSessionRepository(
            vault: InMemoryTokenVault(),
            clientName: "Spoonjoy Apple",
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke
        )
        let defaultClockVault = InMemoryTokenVault()
        let defaultClockSession = try AuthSession(
            clientID: "cm_native_spoonjoy",
            accessToken: "sj_access_default_clock",
            refreshToken: "ort_refresh_default_clock",
            tokenType: "Bearer",
            expiresAt: Date().addingTimeInterval(300),
            scope: NativeAuthSession.defaultScope
        )
        try await defaultClockVault.saveSession(defaultClockSession)
        let defaultClockRepository = NativeAuthSessionRepository(
            vault: defaultClockVault,
            clientName: "Spoonjoy Apple",
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke
        )
        #expect(try await defaultClockRepository.restoreState() == .authenticated(defaultClockSession))
        #expect(try await coverageThrowsNativeAuthSessionError {
            _ = try await missingClientRepository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!,
                expectedState: state,
                codeVerifier: "pkce_verifier"
            )
        })
        #expect(try coverageThrowsNativeAuthSessionError {
            _ = try NativeAuthSession.code(
                from: URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=wrong")!,
                expectedState: state
            )
        })
        #expect(try coverageThrowsNativeAuthSessionError {
            _ = try NativeAuthSession.code(
                from: URL(string: "https://spoonjoy.app/oauth/callback?state=state_123")!,
                expectedState: state
            )
        })

        #expect(try OAuthRedirectValidator.validate(URL(string: "http://localhost/oauth/callback")!))
        #expect(try OAuthRedirectValidator.validate(URL(string: "http://127.0.0.1/oauth/callback")!))
        for invalid in [
            "/oauth/callback",
            "ftp://spoonjoy.app/oauth/callback",
            "http://spoonjoy.app/oauth/callback",
            "https://evil.example/oauth/callback",
            "https://user:pass@spoonjoy.app/oauth/callback",
            "https://spoonjoy.app/oauth/callback#fragment",
            "https://spoonjoy.app/oauth/callback/extra",
            "https:///oauth/callback"
        ] {
            #expect(throws: OAuthRedirectValidationError.self) {
                try OAuthRedirectValidator.validate(URL(string: invalid)!)
            }
        }
        #expect(SecureAuthWebHandoff.allCases.map(\.url).contains(URL(string: "https://spoonjoy.app/login")!))
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

    @Test("auth files are wired into generated app targets and signed out flow")
    func authFilesAreWiredIntoGeneratedAppTargetsAndSignedOutFlow() throws {
        try withTemporaryDirectory { directory in
            let generator = repoRoot().appendingPathComponent("scripts/bundle-exec.sh")
            let result = try runProcess(
                executable: generator.path,
                arguments: [
                    "ruby",
                    "scripts/generate-xcode-project.rb",
                    "--output-dir",
                    directory.path
                ]
            )
            #expect(result.status == 0, Comment(rawValue: result.output))

            let project = try String(
                contentsOf: directory
                    .appendingPathComponent("Spoonjoy.xcodeproj", isDirectory: true)
                    .appendingPathComponent("project.pbxproj"),
                encoding: .utf8
            )
            for appAuthSource in ["SpoonjoyWebAuthenticationSession.swift", "KeychainTokenVault.swift"] {
                let sourceEntries = project.components(separatedBy: "\(appAuthSource) in Sources").count - 1
                #expect(sourceEntries >= 2, "\(appAuthSource) must be in both iOS and macOS Sources phases")
            }
        }

        let signedOutSetup = try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift")
        expectContent(
            signedOutSetup,
            in: "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
            contains: [
                "SpoonjoyWebAuthenticationSession",
                "NativeAuthSessionRepository",
                "KeychainTokenVault",
                "startSignIn",
                "handleOAuthCallback",
                "restoreState",
                "https://spoonjoy.app/oauth/callback"
            ],
            forbids: [
                "spoonjoy://oauth/callback",
                "spoonjoy://oauth"
            ]
        )
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
                "ASWebAuthenticationSession.Callback.https",
                "host: \"spoonjoy.app\"",
                "path: \"/oauth/callback\"",
                "handleOAuthCallback",
                "cancel()",
                "OAuthState"
            ],
            forbids: [
                "spoonjoy://oauth/callback",
                "spoonjoy://oauth"
            ]
        )
    }

    @Test("web authentication adapter is executable with injected session factory")
    func webAuthenticationAdapterIsExecutableWithInjectedSessionFactory() throws {
        let result = try runAppAuthAdapterContractPackage(
            name: "SpoonjoyWebAuthenticationSessionProbe",
            testSource: webAuthenticationSessionAdapterContractSource
        )

        #expect(result.status == 0, Comment(rawValue: result.truncatedOutput))
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
                "FileManager.default"
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
                "MutationQueue"
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

    @Test("xcodebuild blocker wrapper behavior is executable with fake xcodebuild")
    func xcodebuildBlockerWrapperBehaviorIsExecutableWithFakeXcodebuild() throws {
        let script = repoRoot().appendingPathComponent("scripts/run-xcodebuild-with-blocker.sh")
        guard FileManager.default.fileExists(atPath: script.path) else {
            throw NativeAuthContractError.missingFile("scripts/run-xcodebuild-with-blocker.sh")
        }

        try withTemporaryDirectory { directory in
            let fakeBin = directory.appendingPathComponent("bin", isDirectory: true)
            try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
            let fakeXcodebuild = fakeBin.appendingPathComponent("xcodebuild")
            try fakeXcodebuildSource.write(to: fakeXcodebuild, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeXcodebuild.path)

            let allowed = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("allowed", isDirectory: true),
                fakeBin: fakeBin,
                mode: "missing-ios-platform"
            )
            #expect(allowed.status == 0, Comment(rawValue: allowed.output))
            let allowedBlocker = try #require(allowed.blocker)
            #expect(allowedBlocker["capability"] as? String == "XcodePlatform")
            #expect(allowedBlocker["blocked"] as? Bool == true)
            #expect(allowedBlocker["timeoutSeconds"] as? Int == 30)
            #expect((allowedBlocker["command"] as? String)?.contains("xcodebuild -project Spoonjoy.xcodeproj") == true)
            #expect((allowedBlocker["outputPath"] as? String)?.hasSuffix("xcodebuild.log") == true)

            let hardFailure = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("hard-failure", isDirectory: true),
                fakeBin: fakeBin,
                mode: "compile-failure"
            )
            #expect(hardFailure.status == 65, Comment(rawValue: hardFailure.output))
            #expect(hardFailure.blocker == nil)

            let success = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("success", isDirectory: true),
                fakeBin: fakeBin,
                mode: "success"
            )
            #expect(success.status == 0, Comment(rawValue: success.output))
            #expect(success.blocker == nil)
        }
    }

    @Test("local validation matrix executes xcodebuild wrapper for app bundle rows")
    func localValidationMatrixExecutesXcodebuildWrapperForAppBundleRows() throws {
        let success = try runValidationMatrixHarness(wrapperMode: "success")
        #expect(success.result.status == 0, Comment(rawValue: success.result.output))
        #expect(success.wrapperCalls.filter { $0.contains("matrix-xcodebuild-ios.log") }.count == 1)
        #expect(success.wrapperCalls.filter { $0.contains("matrix-xcodebuild-macos.log") }.count == 1)
        #expect(success.directXcodebuildCalls.isEmpty, Comment(rawValue: success.directXcodebuildCalls.joined(separator: "\n")))

        let blocker = try runValidationMatrixHarness(wrapperMode: "xcode-platform-blocker")
        #expect(blocker.result.status == 0, Comment(rawValue: blocker.result.output))
        #expect(blocker.matrix.contains("\"capability\": \"XcodePlatform\""))
        #expect(blocker.matrix.contains("\"status\": \"blocked\""))

        let compileFailure = try runValidationMatrixHarness(wrapperMode: "compile-failure")
        #expect(compileFailure.result.status != 0, Comment(rawValue: compileFailure.result.output))
        #expect(compileFailure.matrix.contains("\"status\": \"fail\""))
        #expect(!compileFailure.matrix.contains("\"capability\": \"XcodePlatform\""))
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

private struct ProcessResult: Equatable {
    let status: Int32
    let output: String

    var truncatedOutput: String {
        let limit = 6_000
        guard output.count > limit else {
            return output
        }

        return String(output.suffix(limit))
    }
}

private struct WrapperProbeResult: Equatable {
    let status: Int32
    let output: String
    let blocker: [String: AnyHashable]?
}

private struct ValidationMatrixHarnessResult: Equatable {
    let result: ProcessResult
    let wrapperCalls: [String]
    let directXcodebuildCalls: [String]
    let matrix: String
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

private func runSwiftContractPackage(name: String, testSource: String) throws -> ProcessResult {
    try withTemporaryDirectory { directory in
        let testsDirectory = directory
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("\(name)Tests", isDirectory: true)
        try FileManager.default.createDirectory(at: testsDirectory, withIntermediateDirectories: true)
        try packageManifest(name: name).write(
            to: directory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try testSource.write(
            to: testsDirectory.appendingPathComponent("\(name)Tests.swift"),
            atomically: true,
            encoding: .utf8
        )

    return try runProcess(
        executable: "/usr/bin/env",
        arguments: [
            "swift",
            "test",
                "--package-path",
                directory.path,
                "--disable-xctest",
                "--parallel",
                "-Xswiftc",
                "-warnings-as-errors"
            ]
        )
    }
}

private func runAppAuthAdapterContractPackage(name: String, testSource: String) throws -> ProcessResult {
    try withTemporaryDirectory { directory in
        let sourceDirectory = directory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("SpoonjoyAppAuth", isDirectory: true)
        let testsDirectory = directory
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("\(name)Tests", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testsDirectory, withIntermediateDirectories: true)
        try appAuthAdapterPackageManifest(name: name).write(
            to: directory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try readRepoFile("Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift").write(
            to: sourceDirectory.appendingPathComponent("SpoonjoyWebAuthenticationSession.swift"),
            atomically: true,
            encoding: .utf8
        )
        try testSource.write(
            to: testsDirectory.appendingPathComponent("\(name)Tests.swift"),
            atomically: true,
            encoding: .utf8
        )

        return try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "swift",
                "test",
                "--package-path",
                directory.path,
                "--disable-xctest",
                "--parallel",
                "-Xswiftc",
                "-warnings-as-errors"
            ]
        )
    }
}

private func packageManifest(name: String) -> String {
    """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
        name: "\(name)",
        platforms: [
            .iOS(.v26),
            .macOS(.v26)
        ],
        dependencies: [
            .package(path: "\(repoRoot().path)")
        ],
        targets: [
            .testTarget(
                name: "\(name)Tests",
                dependencies: [
                    .product(name: "SpoonjoyCore", package: "spoonjoy-apple")
                ]
            )
        ]
    )
    """
}

private func appAuthAdapterPackageManifest(name: String) -> String {
    """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
        name: "\(name)",
        platforms: [
            .iOS(.v26),
            .macOS(.v26)
        ],
        dependencies: [
            .package(path: "\(repoRoot().path)")
        ],
        targets: [
            .target(
                name: "SpoonjoyAppAuth",
                dependencies: [
                    .product(name: "SpoonjoyCore", package: "spoonjoy-apple")
                ]
            ),
            .testTarget(
                name: "\(name)Tests",
                dependencies: [
                    "SpoonjoyAppAuth",
                    .product(name: "SpoonjoyCore", package: "spoonjoy-apple")
                ]
            )
        ]
    )
    """
}

private func runWrapperProbe(
    script: URL,
    artifactDirectory: URL,
    fakeBin: URL,
    mode: String
) throws -> WrapperProbeResult {
    try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
    let outputURL = artifactDirectory.appendingPathComponent("xcodebuild.log")
    let blockerURL = artifactDirectory.appendingPathComponent("xcode-platform-blocker.json")
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = "\(fakeBin.path):\(environment["PATH"] ?? "")"
    environment["FAKE_XCODEBUILD_MODE"] = mode
    let result = try runProcess(
        executable: script.path,
        arguments: [
            "--output",
            outputURL.path,
            "--blocker",
            blockerURL.path,
            "--timeout-seconds",
            "30",
            "--",
            "xcodebuild",
            "-project",
            "Spoonjoy.xcodeproj",
            "-scheme",
            "Spoonjoy iOS",
            "build"
        ],
        environment: environment
    )

    let blocker: [String: AnyHashable]?
    if FileManager.default.fileExists(atPath: blockerURL.path) {
        let data = try Data(contentsOf: blockerURL)
        blocker = try #require(JSONSerialization.jsonObject(with: data) as? [String: AnyHashable])
    } else {
        blocker = nil
    }

    return WrapperProbeResult(status: result.status, output: result.output, blocker: blocker)
}

private func runValidationMatrixHarness(wrapperMode: String) throws -> ValidationMatrixHarnessResult {
    try withTemporaryDirectory { directory in
        try writeValidationMatrixHarness(at: directory)
        let artifacts = directory.appendingPathComponent("artifacts", isDirectory: true)
        let wrapperCallsURL = directory.appendingPathComponent("wrapper-calls.log")
        let directXcodebuildCallsURL = directory.appendingPathComponent("direct-xcodebuild-calls.log")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(directory.appendingPathComponent("bin", isDirectory: true).path):\(environment["PATH"] ?? "")"
        environment["FAKE_WRAPPER_MODE"] = wrapperMode
        environment["WRAPPER_CALLS"] = wrapperCallsURL.path
        environment["DIRECT_XCODEBUILD_CALLS"] = directXcodebuildCallsURL.path

        let result = try runProcess(
            executable: directory.appendingPathComponent("scripts/validate-native-local.sh").path,
            arguments: ["--artifact-root", artifacts.path],
            environment: environment,
            currentDirectory: directory
        )
        let wrapperCalls = readLinesIfPresent(wrapperCallsURL)
        let directXcodebuildCalls = readLinesIfPresent(directXcodebuildCallsURL)
        let matrixURL = artifacts.appendingPathComponent("validation-matrix.json")
        let matrix = (try? String(contentsOf: matrixURL, encoding: .utf8)) ?? ""

        return ValidationMatrixHarnessResult(
            result: result,
            wrapperCalls: wrapperCalls,
            directXcodebuildCalls: directXcodebuildCalls,
            matrix: matrix
        )
    }
}

private func writeValidationMatrixHarness(at directory: URL) throws {
    let scripts = directory.appendingPathComponent("scripts", isDirectory: true)
    let bin = directory.appendingPathComponent("bin", isDirectory: true)
    let docs = directory
        .appendingPathComponent("docs", isDirectory: true)
        .appendingPathComponent("source", isDirectory: true)
    try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    try "source design language\n".write(to: docs.appendingPathComponent("spoonjoy-v2-design-language.md"), atomically: true, encoding: .utf8)
    try "source \"https://rubygems.org\"\n".write(to: directory.appendingPathComponent("Gemfile"), atomically: true, encoding: .utf8)
    try "BUNDLED WITH\n   2.4.22\n".write(to: directory.appendingPathComponent("Gemfile.lock"), atomically: true, encoding: .utf8)

    let validate = scripts.appendingPathComponent("validate-native-local.sh")
    try readRepoFile("scripts/validate-native-local.sh").write(to: validate, atomically: true, encoding: .utf8)
    try makeExecutable(validate)

    let shellStubs = [
        "bundle-check.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
        "bundle-exec.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexec \"$@\"\n",
        "verify-native-scenarios.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
        "smoke-macos.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
        "smoke-ios-simulator.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
        "capture-native-screenshots.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n"
    ]
    for (name, source) in shellStubs {
        let url = scripts.appendingPathComponent(name)
        try source.write(to: url, atomically: true, encoding: .utf8)
        try makeExecutable(url)
    }

    let rubyStubs = [
        "fail-on-warning.rb",
        "enforce-swift-coverage.rb",
        "check-xcode-project-contract.rb",
        "check-xcode-generator-contract.rb",
        "check-native-design-language.rb",
        "check-kitchen-recipe-surfaces.rb",
        "check-cook-shopping-surfaces.rb",
        "check-search-capture-settings-surfaces.rb",
        "check-launch-screenshot-contract.rb",
        "validate-design-review.rb",
        "validate-aasa.rb"
    ]
    for name in rubyStubs {
        let url = scripts.appendingPathComponent(name)
        try "#!/usr/bin/env ruby\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
        try makeExecutable(url)
    }

    let wrapper = scripts.appendingPathComponent("run-xcodebuild-with-blocker.sh")
    try validationHarnessWrapperSource.write(to: wrapper, atomically: true, encoding: .utf8)
    try makeExecutable(wrapper)

    let fakeSwift = bin.appendingPathComponent("swift")
    try validationHarnessSwiftSource.write(to: fakeSwift, atomically: true, encoding: .utf8)
    try makeExecutable(fakeSwift)

    let fakeXcodebuild = bin.appendingPathComponent("xcodebuild")
    try validationHarnessXcodebuildSource.write(to: fakeXcodebuild, atomically: true, encoding: .utf8)
    try makeExecutable(fakeXcodebuild)
}

private func readLinesIfPresent(_ url: URL) -> [String] {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        return []
    }

    return content.split(separator: "\n").map(String.init)
}

private func makeExecutable(_ url: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

private func runProcess(
    executable: String,
    arguments: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment,
    currentDirectory: URL? = nil
) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment
    process.currentDirectoryURL = currentDirectory

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    let outputHandle = try FileHandle(forWritingTo: outputURL)
    defer {
        try? outputHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
    }
    process.standardOutput = outputHandle
    process.standardError = outputHandle
    try process.run()
    process.waitUntilExit()

    let output = String(data: try Data(contentsOf: outputURL), encoding: .utf8) ?? ""
    return ProcessResult(status: process.terminationStatus, output: output)
}

private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try body(directory)
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

private actor CoverageAuthNetworkSpy {
    let clientID: String
    let exchangeResponse: OAuthTokenResponse
    let refreshResponse: OAuthTokenResponse
    private(set) var registerRequests: [CoverageRegisterRequest] = []
    private(set) var exchangeRequests: [CoverageCodeExchangeRequest] = []
    private(set) var refreshRequests: [CoverageRefreshRequest] = []
    private(set) var revokeRequests: [CoverageRevokeRequest] = []

    init(clientID: String, exchangeResponse: OAuthTokenResponse, refreshResponse: OAuthTokenResponse) {
        self.clientID = clientID
        self.exchangeResponse = exchangeResponse
        self.refreshResponse = refreshResponse
    }

    func registerClient(clientName: String, redirectURI: URL) async throws -> String {
        registerRequests.append(CoverageRegisterRequest(clientName: clientName, redirectURI: redirectURI.absoluteString))
        return clientID
    }

    func exchangeCode(clientID: String, redirectURI: URL, code: String, codeVerifier: String) async throws -> OAuthTokenResponse {
        exchangeRequests.append(
            CoverageCodeExchangeRequest(
                clientID: clientID,
                redirectURI: redirectURI.absoluteString,
                code: code,
                codeVerifier: codeVerifier
            )
        )
        return exchangeResponse
    }

    func refresh(clientID: String, refreshToken: String) async throws -> OAuthTokenResponse {
        refreshRequests.append(CoverageRefreshRequest(clientID: clientID, refreshToken: refreshToken))
        return refreshResponse
    }

    func revoke(refreshToken: String, clientID: String) async throws {
        revokeRequests.append(CoverageRevokeRequest(refreshToken: refreshToken, clientID: clientID))
    }
}

private struct CoverageRegisterRequest: Equatable {
    let clientName: String
    let redirectURI: String
}

private struct CoverageCodeExchangeRequest: Equatable {
    let clientID: String
    let redirectURI: String
    let code: String
    let codeVerifier: String
}

private struct CoverageRefreshRequest: Equatable {
    let clientID: String
    let refreshToken: String
}

private struct CoverageRevokeRequest: Equatable {
    let refreshToken: String
    let clientID: String
}

private func coverageTokenResponse(accessToken: String, refreshToken: String, expiresIn: Int) -> OAuthTokenResponse {
    let data = Data(
        #"""
        {
          "access_token": "\#(accessToken)",
          "refresh_token": "\#(refreshToken)",
          "token_type": "Bearer",
          "expires_in": \#(expiresIn),
          "scope": "shopping_list:read shopping_list:write"
        }
        """#.utf8
    )
    return try! JSONDecoder().decode(OAuthTokenResponse.self, from: data)
}

private func coverageThrowsNativeAuthSessionError(_ operation: () async throws -> Void) async throws -> Bool {
    do {
        try await operation()
        return false
    } catch is NativeAuthSessionError {
        return true
    }
}

private func coverageThrowsNativeAuthSessionError(_ operation: () throws -> Void) throws -> Bool {
    do {
        try operation()
        return false
    } catch is NativeAuthSessionError {
        return true
    }
}

private let validationHarnessWrapperSource = #"""
#!/usr/bin/env bash
set -euo pipefail

output_path=""
blocker_path=""
timeout_seconds=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      output_path="$2"
      shift 2
      ;;
    --blocker)
      blocker_path="$2"
      shift 2
      ;;
    --timeout-seconds)
      timeout_seconds="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf 'unknown wrapper argument %s\n' "$1" >&2
      exit 64
      ;;
  esac
done

mkdir -p "$(dirname "$output_path")" "$(dirname "$blocker_path")"
printf '%s|output=%s|blocker=%s|timeout=%s|command=%s\n' \
  "${FAKE_WRAPPER_MODE:-success}" "$output_path" "$blocker_path" "$timeout_seconds" "$*" >> "${WRAPPER_CALLS:?}"
rm -f "$blocker_path"

case "${FAKE_WRAPPER_MODE:-success}" in
  success)
    printf 'Build Succeeded\n' > "$output_path"
    exit 0
    ;;
  xcode-platform-blocker)
    printf 'xcodebuild: error: iOS 26.5 is not installed\n' > "$output_path"
    cat > "$blocker_path" <<JSON
{
  "capability": "XcodePlatform",
  "blocked": true,
  "command": "$*",
  "timeoutSeconds": $timeout_seconds,
  "outputPath": "$output_path",
  "reason": "fake local platform blocker"
}
JSON
    exit 0
    ;;
  compile-failure)
    printf 'SwiftCompile failed while compiling SpoonjoyRootView.swift\n' > "$output_path"
    exit 65
    ;;
  *)
    printf 'unknown fake wrapper mode %s\n' "${FAKE_WRAPPER_MODE:-}" >&2
    exit 64
    ;;
esac
"""#

private let validationHarnessSwiftSource = #"""
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"--show-codecov-path"* ]]; then
  printf '%s\n' "$PWD/fake-coverage.json"
  exit 0
fi

if [[ "${1:-}" == "test" ]]; then
  exit 0
fi

printf 'unexpected swift invocation: %s\n' "$*" >&2
exit 64
"""#

private let validationHarnessXcodebuildSource = #"""
#!/usr/bin/env bash
set -euo pipefail

case "${*:-}" in
  "-version")
    printf 'Xcode 26.5\nBuild version 17F76\n'
    exit 0
    ;;
  "-checkFirstLaunchStatus")
    exit 0
    ;;
esac

printf '%s\n' "$*" >> "${DIRECT_XCODEBUILD_CALLS:?}"
printf 'direct xcodebuild invocation should be delegated through wrapper: %s\n' "$*" >&2
exit 64
"""#

private let fakeXcodebuildSource = #"""
#!/usr/bin/env bash
set -euo pipefail

case "${*:-}" in
  "-version")
    printf 'Xcode 26.5\nBuild version 17F76\n'
    exit 0
    ;;
  "-checkFirstLaunchStatus")
    exit 0
    ;;
esac

case "${FAKE_XCODEBUILD_MODE:-success}" in
  missing-ios-platform)
    printf 'xcodebuild: error: iOS 26.5 is not installed. To use with Xcode, first download and install the platform.\n' >&2
    exit 70
    ;;
  compile-failure)
    printf 'SwiftCompile failed while compiling SpoonjoyRootView.swift\n' >&2
    exit 65
    ;;
  success)
    printf 'Build Succeeded\n'
    exit 0
    ;;
  *)
    printf 'unknown fake mode %s\n' "${FAKE_XCODEBUILD_MODE:-}" >&2
    exit 64
    ;;
esac
"""#

private let webAuthenticationSessionAdapterContractSource = #"""
import Foundation
import Testing
@testable import SpoonjoyCore
@testable import SpoonjoyAppAuth

@MainActor
@Suite("Web authentication session adapter contract")
struct WebAuthenticationSessionAdapterContract {
    @Test("adapter configures exact HTTPS callback forwards callback and cancels")
    func adapterConfiguresExactHTTPSCallbackForwardsCallbackAndCancels() throws {
        let factory = FakeSessionFactory()
        var forwardedCallbacks: [URL] = []
        let adapter = SpoonjoyWebAuthenticationSession(
            sessionFactory: factory.makeSession,
            callbackHandler: { callbackURL in
                forwardedCallbacks.append(callbackURL)
            }
        )
        let authorizationURL = URL(string: "https://spoonjoy.app/oauth/authorize?client_id=cm_native_spoonjoy&state=state_123")!
        let state = try #require(OAuthState(rawValue: "state_123"))

        #expect(try adapter.start(authorizationURL: authorizationURL, oauthState: state))
        #expect(factory.requests == [
            FakeSessionRequest(
                authorizationURL: authorizationURL,
                callback: .https(host: "spoonjoy.app", path: "/oauth/callback")
            )
        ])
        let session = try #require(factory.sessions.first)
        #expect(session.prefersEphemeralWebBrowserSession)
        #expect(session.startCount == 1)

        let callbackURL = URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!
        factory.complete(with: callbackURL)
        #expect(forwardedCallbacks == [callbackURL])

        adapter.cancel()
        #expect(session.cancelCount == 1)
    }
}

private struct FakeSessionRequest: Equatable {
    let authorizationURL: URL
    let callback: SpoonjoyWebAuthenticationCallback
}

@MainActor
private final class FakeSessionFactory {
    private(set) var requests: [FakeSessionRequest] = []
    private(set) var sessions: [FakeWebAuthenticationSession] = []
    private var completionHandler: (@MainActor (URL?, Error?) -> Void)?

    func makeSession(
        authorizationURL: URL,
        callback: SpoonjoyWebAuthenticationCallback,
        completionHandler: @escaping @MainActor (URL?, Error?) -> Void
    ) -> any SpoonjoyWebAuthenticationSessionProtocol {
        requests.append(FakeSessionRequest(authorizationURL: authorizationURL, callback: callback))
        self.completionHandler = completionHandler
        let session = FakeWebAuthenticationSession()
        sessions.append(session)
        return session
    }

    func complete(with url: URL) {
        completionHandler?(url, nil)
    }
}

@MainActor
private final class FakeWebAuthenticationSession: SpoonjoyWebAuthenticationSessionProtocol {
    var prefersEphemeralWebBrowserSession = false
    private(set) var startCount = 0
    private(set) var cancelCount = 0

    func start() -> Bool {
        startCount += 1
        return true
    }

    func cancel() {
        cancelCount += 1
    }
}
"""#

private let nativeAuthBehaviorContractSource = ##"""
import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native auth behavior contract")
struct NativeAuthBehaviorContract {
    private let now = Date(timeIntervalSince1970: 1_781_612_800)

    @Test("repository starts sign in restores sessions refreshes rotates revokes and logs out")
    func repositoryStartsSignInRestoresRefreshesRotatesRevokesAndLogsOut() async throws {
        let vault = InMemoryTokenVault()
        let network = AuthNetworkSpy(
            clientID: "cm_native_spoonjoy",
            exchangeResponse: tokenResponse(accessToken: "sj_access_initial", refreshToken: "ort_refresh_initial", expiresIn: 300),
            refreshResponse: tokenResponse(accessToken: "sj_access_rotated", refreshToken: "ort_refresh_rotated", expiresIn: 600)
        )
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            redirectURI: URL(string: "https://spoonjoy.app/oauth/callback")!,
            scope: "shopping_list:read shopping_list:write",
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke,
            now: { now }
        )

        #expect(try await repository.restoreState() == .signedOut)

        let state = try #require(OAuthState(rawValue: "state_123"))
        let start = try await repository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        #expect(start.clientID == "cm_native_spoonjoy")
        #expect(start.redirectURI == URL(string: "https://spoonjoy.app/oauth/callback")!)
        #expect(start.authorizationURL.path == "/oauth/authorize")
        #expect(start.authorizationURL.query?.contains("client_id=cm_native_spoonjoy") == true)
        #expect(try await vault.loadClientID() == "cm_native_spoonjoy")

        let session = try await repository.handleOAuthCallback(
            URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!,
            expectedState: state,
            codeVerifier: "pkce_verifier"
        )
        #expect(session.accessToken == "sj_access_initial")
        #expect(session.refreshToken == "ort_refresh_initial")
        #expect(try await vault.loadSession() == session)
        #expect(try await repository.restoreState() == .authenticated(session))
        #expect(await network.exchangeRequests == [
            CodeExchangeRequest(clientID: "cm_native_spoonjoy", redirectURI: "https://spoonjoy.app/oauth/callback", code: "oac_code", codeVerifier: "pkce_verifier")
        ])

        let expired = try AuthSession(
            clientID: "cm_native_spoonjoy",
            accessToken: "sj_access_expired",
            refreshToken: "ort_refresh_initial",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(-1),
            scope: "shopping_list:read shopping_list:write"
        )
        try await vault.saveSession(expired)
        #expect(try await repository.restoreState() == .refreshRequired(expired))

        let valid = try await repository.validSession()
        #expect(valid.accessToken == "sj_access_rotated")
        #expect(valid.refreshToken == "ort_refresh_rotated")
        #expect(try await vault.loadSession() == valid)
        #expect(await network.refreshRequests == [
            RefreshRequest(clientID: "cm_native_spoonjoy", refreshToken: "ort_refresh_initial")
        ])

        try await repository.revokeAndLogout()
        #expect(try await repository.restoreState() == .signedOut)
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == nil)
        #expect(await network.revokeRequests == [
            RevokeRequest(refreshToken: "ort_refresh_rotated", clientID: "cm_native_spoonjoy")
        ])
    }

    @Test("repository rejects callback state mismatch missing code and wrong callback route")
    func repositoryRejectsCallbackStateMismatchMissingCodeAndWrongCallbackRoute() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID("cm_native_spoonjoy")
        let network = AuthNetworkSpy(
            clientID: "cm_native_spoonjoy",
            exchangeResponse: tokenResponse(accessToken: "sj_access", refreshToken: "ort_refresh", expiresIn: 300),
            refreshResponse: tokenResponse(accessToken: "sj_access_rotated", refreshToken: "ort_refresh_rotated", expiresIn: 600)
        )
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            redirectURI: URL(string: "https://spoonjoy.app/oauth/callback")!,
            scope: "shopping_list:read shopping_list:write",
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke,
            now: { now }
        )
        let expected = try #require(OAuthState(rawValue: "state_123"))

        #expect(
            try await throwsNativeAuthSessionError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_other")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsNativeAuthSessionError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/oauth/callback?state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsOAuthRedirectValidationError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "spoonjoy://oauth/callback?code=oac_code&state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsOAuthRedirectValidationError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/not-oauth?code=oac_code&state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(await network.exchangeRequests.isEmpty)
    }
}

private actor AuthNetworkSpy {
    let clientID: String
    let exchangeResponse: OAuthTokenResponse
    let refreshResponse: OAuthTokenResponse
    private(set) var exchangeRequests: [CodeExchangeRequest] = []
    private(set) var refreshRequests: [RefreshRequest] = []
    private(set) var revokeRequests: [RevokeRequest] = []

    init(clientID: String, exchangeResponse: OAuthTokenResponse, refreshResponse: OAuthTokenResponse) {
        self.clientID = clientID
        self.exchangeResponse = exchangeResponse
        self.refreshResponse = refreshResponse
    }

    func registerClient(clientName: String, redirectURI: URL) async throws -> String {
        #expect(clientName == "Spoonjoy Apple")
        #expect(redirectURI.absoluteString == "https://spoonjoy.app/oauth/callback")
        return clientID
    }

    func exchangeCode(clientID: String, redirectURI: URL, code: String, codeVerifier: String) async throws -> OAuthTokenResponse {
        exchangeRequests.append(
            CodeExchangeRequest(
                clientID: clientID,
                redirectURI: redirectURI.absoluteString,
                code: code,
                codeVerifier: codeVerifier
            )
        )
        return exchangeResponse
    }

    func refresh(clientID: String, refreshToken: String) async throws -> OAuthTokenResponse {
        refreshRequests.append(RefreshRequest(clientID: clientID, refreshToken: refreshToken))
        return refreshResponse
    }

    func revoke(refreshToken: String, clientID: String) async throws {
        revokeRequests.append(RevokeRequest(refreshToken: refreshToken, clientID: clientID))
    }
}

private struct CodeExchangeRequest: Equatable {
    let clientID: String
    let redirectURI: String
    let code: String
    let codeVerifier: String
}

private struct RefreshRequest: Equatable {
    let clientID: String
    let refreshToken: String
}

private struct RevokeRequest: Equatable {
    let refreshToken: String
    let clientID: String
}

private func tokenResponse(accessToken: String, refreshToken: String, expiresIn: Int) -> OAuthTokenResponse {
    let data = Data(
        #"""
        {
          "access_token": "\#(accessToken)",
          "refresh_token": "\#(refreshToken)",
          "token_type": "Bearer",
          "expires_in": \#(expiresIn),
          "scope": "shopping_list:read shopping_list:write"
        }
        """#.utf8
    )
    return try! JSONDecoder().decode(OAuthTokenResponse.self, from: data)
}

private func throwsNativeAuthSessionError(_ operation: () async throws -> Void) async throws -> Bool {
    do {
        try await operation()
        return false
    } catch is NativeAuthSessionError {
        return true
    }
}

private func throwsOAuthRedirectValidationError(_ operation: () async throws -> Void) async throws -> Bool {
    do {
        try await operation()
        return false
    } catch is OAuthRedirectValidationError {
        return true
    }
}
"""##
