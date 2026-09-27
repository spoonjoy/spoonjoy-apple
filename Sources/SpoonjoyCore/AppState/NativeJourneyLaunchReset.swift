import Foundation

/// Clears the app's on-disk state when a journey asks for a fresh launch.
///
/// The app calls this only from its DEBUG dependency wiring, so release builds never
/// honour the launch environment key.
public enum NativeJourneyLaunchReset {
    public static let environmentKey = "SPOONJOY_JOURNEY_RESET_STATE"

    public static func isRequested(environment: [String: String]) -> Bool {
        switch environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            true
        default:
            false
        }
    }

    /// Removes every child of `appDirectory` and keeps the directory itself.
    /// Returns true when it removed anything. A missing directory is not an error.
    @discardableResult
    public static func resetIfRequested(
        environment: [String: String],
        appDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard isRequested(environment: environment),
              fileManager.fileExists(atPath: appDirectory.path) else {
            return false
        }

        let children = try fileManager.contentsOfDirectory(
            at: appDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )
        try children.forEach { try fileManager.removeItem(at: $0) }
        return !children.isEmpty
    }
}
