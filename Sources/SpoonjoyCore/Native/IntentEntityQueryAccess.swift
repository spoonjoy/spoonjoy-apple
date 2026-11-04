import Foundation

/// How App Intents entity queries behave when nobody is signed in.
///
/// Siri, Spotlight and Shortcuts call an entity query to list or find things, often with no one signed in (a fresh
/// install, after Log Out) or before the keychain will hand over the session (a locked device, an unsigned build).
/// A query that throws there reads as a broken app; a query that returns nothing reads as an empty kitchen, which is
/// the truth. So a query answers "nothing" when it can't know who is asking, and only intents that act ask the
/// person to sign in.
public enum IntentEntityQueryAccess {
    /// Runs an entity query. If it fails because no session can be read, the query has no results.
    public static func results<Entity>(_ query: () async throws -> [Entity]) async throws -> [Entity] {
        do {
            return try await query()
        } catch where meansSignedOut(error) {
            return []
        }
    }

    /// Whether an error means the query can't tell who is signed in: no session, or a keychain that won't give it up.
    public static func meansSignedOut(_ error: any Error) -> Bool {
        if let error = error as? NativeIntentActionError {
            return error == .authRequired
        }
        return error is KeychainTokenVaultError
    }
}
