import Foundation

public struct NativeDiagnosticFlushResult: Equatable, Sendable {
    public let sent: Int
    public let dropped: Int
    public let remaining: Int
}

/// Crash and hang reports waiting to reach the server, in a JSON file written atomically, so a report survives being
/// offline or the app being killed. It holds the newest 50; older ones fall off.
public actor NativeDiagnosticQueue {
    public static let defaultCapacity = 50
    public static let fileName = "native-diagnostics-queue.json"

    private let fileURL: URL
    private let capacity: Int
    private var loaded: [NativeDiagnosticReport]?

    public init(fileURL: URL, capacity: Int = NativeDiagnosticQueue.defaultCapacity) {
        self.fileURL = fileURL
        self.capacity = capacity
    }

    /// Beside the app's other state in Application Support.
    public static func defaultFileURL(appStateFileURL: URL = NativeAppStateLocation.defaultFileURL()) -> URL {
        appStateFileURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    public func pending() -> [NativeDiagnosticReport] {
        items
    }

    /// Adds reports the queue does not already hold, then drops the oldest past capacity.
    public func enqueue(_ reports: [NativeDiagnosticReport]) {
        var next = items
        let known = Set(next.map(\.diagnosticID))
        next.append(contentsOf: reports.filter { !known.contains($0.diagnosticID) })
        if next.count > capacity {
            next.removeFirst(next.count - capacity)
        }
        save(next)
    }

    /// Sends oldest first. A report the server took or refused for good leaves the queue; the first one to fail
    /// for now stops the flush, and it and everything after wait for the next one. Two flushes at once may send the
    /// same report twice; the server keeps one by `diagnosticId`.
    @discardableResult
    public func flush(
        using send: @Sendable (NativeDiagnosticReport) async -> NativeDiagnosticSendOutcome
    ) async -> NativeDiagnosticFlushResult {
        var sent = 0
        var dropped = 0
        for report in items {
            let outcome = await send(report)
            if outcome == .retryLater {
                break
            }
            if outcome == .accepted {
                sent += 1
            } else {
                dropped += 1
            }
            save(items.filter { $0.diagnosticID != report.diagnosticID })
        }
        return NativeDiagnosticFlushResult(sent: sent, dropped: dropped, remaining: items.count)
    }

    private var items: [NativeDiagnosticReport] {
        if let loaded {
            return loaded
        }
        // A missing or unreadable file is an empty queue; the next save replaces it.
        let decoded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([NativeDiagnosticReport].self, from: $0) } ?? []
        loaded = decoded
        return decoded
    }

    private func save(_ reports: [NativeDiagnosticReport]) {
        loaded = reports
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(reports) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
