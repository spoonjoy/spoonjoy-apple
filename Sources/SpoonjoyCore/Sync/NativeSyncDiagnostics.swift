import Foundation

/// A short log of the sync requests the app sent and what the server answered, for journey runs only.
/// A journey launches the app with the environment key set; the app shows the log through one hidden
/// accessibility element so a failed journey can say which request the server turned down. When the key is
/// not set, nothing is recorded.
public final class NativeSyncDiagnostics: @unchecked Sendable {
    public static let environmentKey = "SPOONJOY_JOURNEY_SYNC_LOG"
    public static let shared = NativeSyncDiagnostics()

    private let lock = NSLock()
    private var isEnabled = false
    private var lines: [String] = []
    private let capacity = 12

    public init() {}

    public static func isRequested(environment: [String: String]) -> Bool {
        switch environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            true
        default:
            false
        }
    }

    public var enabled: Bool {
        lock.withLock { isEnabled }
    }

    public func enable() {
        lock.withLock { isEnabled = true }
    }

    public func record(_ line: String) {
        lock.withLock {
            guard isEnabled else {
                return
            }
            lines.append(line)
            if lines.count > capacity {
                lines.removeFirst(lines.count - capacity)
            }
        }
    }

    public func recordSend(method: String, path: String, outcome: String) {
        record("\(method) \(path) -> \(outcome)")
    }

    public var summary: String {
        lock.withLock { lines.isEmpty ? "no sync requests" : lines.joined(separator: " | ") }
    }
}
