// TASK6-DIAG: temporary journey diagnostics for the Tabletop relaunch failure. Remove before merge.
import Foundation
import SpoonjoyCore

enum Task6Diag {
    static let isOn: Bool = {
#if DEBUG
        NativeSyncDiagnostics.isRequested(environment: ProcessInfo.processInfo.environment)
#else
        false
#endif
    }()

    static func log(_ message: @autoclosure () -> String) {
        guard isOn else { return }
        print("TASK6-DIAG \(Date().timeIntervalSince1970) \(message())")
    }

    static func timed<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
        let start = Date()
        defer { log("\(label) took \(Int(Date().timeIntervalSince(start) * 1000))ms") }
        return try body()
    }

    static func describe(_ progress: CookModeProgress) -> String {
        "recipe=\(progress.recipeID) step=\(progress.activeStepIndex) checked=\(progress.checkedIngredientIDs.count) updatedAt=\(progress.updatedAt)"
    }

    /// Prints what the saved app state holds at launch.
    static func logSavedState() {
        guard isOn else { return }
        let url = NativeAppStateLocation.defaultFileURL()
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log("launch: no readable app state at \(url.lastPathComponent)")
            return
        }
        let progress = (json["cookProgressByRecipeID"] as? [String: [String: Any]] ?? [:]).map { key, value in
            "\(key):step=\(value["activeStepIndex"] ?? "?"),checked=\((value["checkedIngredientIDs"] as? [Any])?.count ?? -1)"
        }
        log("launch: bytes=\(data.count) savedAt=\(json["savedAt"] ?? "?") route=\(json["lastOpenedRoute"] ?? "nil") progress=\(progress)")
    }

    /// Prints the sync log a few times after a change, so the run shows whether the cook push went out before a kill.
    @MainActor static func watchSync() {
        guard isOn else { return }
        Task { @MainActor in
            for _ in 0..<8 {
                try? await Task.sleep(for: .milliseconds(400))
                log("sync: \(NativeSyncDiagnostics.shared.summary)")
            }
        }
    }
}
