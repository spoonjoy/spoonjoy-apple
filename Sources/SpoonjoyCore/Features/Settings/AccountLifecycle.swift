import Foundation

// Download my data and Delete account, in the account screen. The server contract is
// spoonjoy-v2 docs/account-deletion.md: GET /api/v1/me/export and DELETE /api/v1/me.

/// Proof, sent with DELETE /api/v1/me, that the person deleting the account owns it right now.
public enum AccountDeletionProof: Equatable, Sendable {
    /// The current password, for an account that has one.
    case password(String)
    /// A fresh Sign in with Apple credential for the Apple ID linked to a passwordless account.
    case signInWithApple(identityToken: String, rawNonce: String)
}

/// How the delete sheet asks the person to prove it is them.
public enum AccountDeletionReauthentication: Equatable, Sendable {
    /// The account has a password: type it.
    case password
    /// No password, but an Apple ID is linked: sign in with Apple again.
    case signInWithApple
    /// Neither (GitHub or Google only): the app has no way to prove it is them, so deletion happens on the web.
    case web(URL)

    public init(account: SettingsAccountProfile, routes: SettingsSecureHandoffRoutes) {
        if account.hasPassword {
            self = .password
        } else if account.linkedProviders.contains(where: { $0.provider == .apple }) {
            self = .signInWithApple
        } else {
            self = .web(routes.handoff(target: .deleteAccount).url)
        }
    }
}

/// What the server did, from DELETE /api/v1/me.
public struct AccountDeletionResult: Codable, Equatable, Sendable {
    public let deleted: Bool
    /// Recipes other cooks built on, now credited to the "Deleted chef" placeholder.
    public let reassignedRecipes: Int
    public let deletedRecipes: Int

    public init(deleted: Bool, reassignedRecipes: Int, deletedRecipes: Int) {
        self.deleted = deleted
        self.reassignedRecipes = reassignedRecipes
        self.deletedRecipes = deletedRecipes
    }
}

/// Why the server refused to delete the account. None of these sign the person out: the server answers
/// re-authentication failures with 400, not 401, and the account is still there.
public enum AccountDeletionFailure: Equatable, Sendable {
    case usernameMismatch
    case passwordRequired
    case passwordIncorrect
    case appleAccountMismatch
    case appleCredentialInvalid
    case appleConfirmationRequired
    case rateLimited
    case offline
    case unexpected(code: String)

    public init(error: Error) {
        guard let transportError = error as? APITransportError else {
            self = .unexpected(code: "account_delete_unexpected")
            return
        }
        if transportError.isOffline {
            self = .offline
            return
        }
        guard let apiError = transportError.apiError else {
            self = .unexpected(code: "account_delete_transport")
            return
        }
        if apiError.code == "rate_limited" {
            self = .rateLimited
            return
        }
        switch apiError.details["reason"] {
        case .string("confirmation_mismatch"):
            self = .usernameMismatch
        case .string("password_required"):
            self = .passwordRequired
        case .string("password_incorrect"):
            self = .passwordIncorrect
        case .string("apple_account_mismatch"):
            self = .appleAccountMismatch
        case .string("apple_credential_invalid"):
            self = .appleCredentialInvalid
        case .string("recent_sign_in_required"):
            self = .appleConfirmationRequired
        default:
            self = .unexpected(code: "account_delete_api_\(apiError.code)_\(apiError.status)")
        }
    }

    public var message: String {
        switch self {
        case .usernameMismatch:
            "That username doesn't match. Type it exactly as it appears on your account."
        case .passwordRequired:
            "Enter your current password to confirm it's you."
        case .passwordIncorrect:
            "That password isn't right. Your account was not deleted."
        case .appleAccountMismatch:
            "That Apple ID isn't the one linked to this account. Sign in with the Apple ID you use for Spoonjoy."
        case .appleCredentialInvalid:
            "Apple couldn't confirm it's you. Sign in with Apple again."
        case .appleConfirmationRequired:
            "Sign in with Apple to confirm it's you."
        case .rateLimited:
            "Too many attempts. Wait a few minutes, then try again."
        case .offline:
            SettingsOnlineOnlyReason.accountDeletion.message
        case .unexpected(let code):
            "Your account was not deleted. Try again. Code: \(code)."
        }
    }

    /// True when the Apple credential that was sent can't be used again, so the sheet asks for a new one.
    public var invalidatesAppleCredential: Bool {
        switch self {
        case .appleAccountMismatch, .appleCredentialInvalid, .appleConfirmationRequired:
            true
        default:
            false
        }
    }
}

/// What the person has filled in on the delete sheet, and whether it is enough to send.
public struct AccountDeletionForm: Equatable, Sendable {
    public let username: String
    public let reauthentication: AccountDeletionReauthentication
    public var typedUsername: String
    public var password: String
    public var appleCredential: NativeAppleSignInCredential?
    public private(set) var failure: AccountDeletionFailure?

    public init(username: String, reauthentication: AccountDeletionReauthentication) {
        self.username = username
        self.reauthentication = reauthentication
        typedUsername = ""
        password = ""
        appleCredential = nil
        failure = nil
    }

    /// The server trims the typed username and then compares it exactly, so the app does the same.
    public var usernameMatches: Bool {
        typedUsername.trimmingCharacters(in: .whitespacesAndNewlines) == username
    }

    public var proof: AccountDeletionProof? {
        switch reauthentication {
        case .password:
            password.isEmpty ? nil : .password(password)
        case .signInWithApple:
            appleCredential.map { .signInWithApple(identityToken: $0.identityToken, rawNonce: $0.rawNonce) }
        case .web:
            nil
        }
    }

    /// The delete action to plan, or nil while the username does not match or the proof is missing.
    public var action: SettingsAction? {
        guard usernameMatches, let proof else {
            return nil
        }
        return .deleteAccount(confirmUsername: username, proof: proof)
    }

    public mutating func record(_ failure: AccountDeletionFailure) {
        self.failure = failure
        if failure == .passwordIncorrect {
            password = ""
        }
        if failure.invalidatesAppleCredential {
            appleCredential = nil
        }
    }

    public mutating func clearFailure() {
        failure = nil
    }
}

/// The JSON file "Download my data" hands to the share sheet.
public struct AccountExportFile: Equatable, Sendable {
    public let fileName: String
    public let contents: Data

    public init(username: String, exportedAt: Date, export: JSONValue) throws {
        fileName = Self.fileName(username: username, exportedAt: exportedAt)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        contents = try encoder.encode(export)
    }

    /// The web's name for the same download: `spoonjoy-<username>-YYYY-MM-DD.json`, in UTC, with anything
    /// outside letters, digits, dot, underscore and dash replaced by a dash.
    public static func fileName(username: String, exportedAt: Date) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let safeUsername = String(String.UnicodeScalarView(username.unicodeScalars.map { allowed.contains($0) ? $0 : "-" }))
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withFullDate]
        return "spoonjoy-\(safeUsername)-\(formatter.string(from: exportedAt)).json"
    }
}
