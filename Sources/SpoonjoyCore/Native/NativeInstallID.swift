import Foundation
import Synchronization

/// A random ID made the first time the app runs and kept in UserDefaults until it is deleted. Telemetry and crash
/// reports carry it so the server can tell installs apart before anyone signs in, and link them to the account after.
/// It names this install only: nothing about the device or the person is in it.
public enum NativeInstallID {
    public static let defaultsKey = "spoonjoy.installId"

    /// What the server accepts: `^[A-Za-z0-9-]{8,64}$`. A UUID string fits.
    public static func isValid(_ id: String) -> Bool {
        (8...64).contains(id.utf8.count) && id.unicodeScalars.allSatisfy { scalar in
            scalar == "-" || (scalar.isASCII && CharacterSet.alphanumerics.contains(scalar))
        }
    }

    public static func current(
        defaults: UserDefaults = .standard,
        makeID: () -> String = { UUID().uuidString.lowercased() }
    ) -> String {
        if let stored = defaults.string(forKey: defaultsKey), isValid(stored) {
            return stored
        }
        let id = makeID()
        defaults.set(id, forKey: defaultsKey)
        return id
    }
}

/// Launch has settled when the shell has bootstrapped and stayed up for `settleDelay`. It happens once per process;
/// the app sends `launch_completed` then. Launch safe mode (spoonjoy-apple#365) counts a launch as finished at the same
/// moment, so it can mark the launch here instead of keeping its own clock.
public final class NativeLaunchSettlement: Sendable {
    public static let process = NativeLaunchSettlement()
    public static let settleDelay: Duration = .seconds(3)

    private let settled = Mutex(false)

    public init() {}

    public var isSettled: Bool {
        settled.withLock { $0 }
    }

    /// True only for the first call, so whoever gets true does the once-per-launch work.
    public func markSettled() -> Bool {
        settled.withLock { settled in
            guard !settled else {
                return false
            }
            settled = true
            return true
        }
    }
}
