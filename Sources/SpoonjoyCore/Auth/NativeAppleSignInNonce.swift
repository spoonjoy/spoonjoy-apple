import CryptoKit
import Foundation

/// The nonce for a Sign in with Apple request: the app keeps the raw value and hands Apple its SHA-256, so the
/// identity token Apple returns is bound to this one request. Sign-in and the delete-account confirmation use it.
public enum NativeAppleSignInNonce {
    static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    public static func random(length: Int = 32) -> String {
        var generator = SystemRandomNumberGenerator()
        return random(length: length, using: &generator)
    }

    static func random<Generator: RandomNumberGenerator>(length: Int, using generator: inout Generator) -> String {
        precondition(length > 0)
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count, using: &generator)] })
    }

    /// Lowercase hex SHA-256, the form `ASAuthorizationAppleIDRequest.nonce` expects.
    public static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
