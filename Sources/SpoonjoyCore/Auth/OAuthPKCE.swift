import CryptoKit
import Foundation

public enum OAuthPKCEError: Error, Equatable, Sendable {
    case invalidVerifier
}

public enum OAuthPKCE {
    private static let verifierCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
    )

    public static func isValidVerifier(_ verifier: String) -> Bool {
        guard (43...128).contains(verifier.count) else {
            return false
        }

        return verifier.unicodeScalars.allSatisfy { verifierCharacters.contains($0) }
    }

    public static func codeChallenge(for verifier: String) throws -> String {
        guard isValidVerifier(verifier) else {
            throw OAuthPKCEError.invalidVerifier
        }

        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncoded(Data(digest))
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public struct OAuthState: RawRepresentable, Equatable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.rawValue = trimmed
    }

    public func matches(returnedState: String?) -> Bool {
        rawValue == returnedState
    }
}
