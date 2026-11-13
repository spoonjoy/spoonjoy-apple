import Foundation

/// Reads the resource id back out of an entity identifier of the form `<kind>:<environment>:schema<n>:<account>:<id>`.
/// A preview build's environment is itself `preview:<host>`, so the identifier is matched against its expected prefix
/// rather than split on colons; splitting failed for every preview build, and Siri asked again for a recipe it had just
/// been handed. The id may not hold a colon, as before.
enum NativeScopedEntityIdentifier {
    static func resourceID(
        from identifier: String,
        kind: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) -> String? {
        let prefix = "\(kind):\(environment.rawValue):schema\(NativeDurableCacheSnapshot.currentSchemaVersion):\(accountID):"
        guard identifier.hasPrefix(prefix) else {
            return nil
        }
        let resourceID = String(identifier.dropFirst(prefix.count))
        guard !resourceID.isEmpty, !resourceID.contains(":") else {
            return nil
        }
        return resourceID
    }
}
