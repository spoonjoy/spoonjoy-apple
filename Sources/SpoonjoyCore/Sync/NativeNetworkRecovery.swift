import Foundation

/// Turns readings of "is the network usable" into one sync request each time the network comes back.
///
/// Without it, edits made with no signal (a grocery store, a basement) waited until the app was reopened, and a
/// partner kept seeing a stale list. A reading that the network is usable only counts after a reading that it was
/// not, so launch, which syncs anyway, does not add a second sync. The network has to stay usable for the settle
/// delay before the request goes out, so a connection that flaps while walking out of a store asks once.
///
/// A network that reports usable but cannot reach the server (a captive portal) gets one attempt; the next
/// foreground, pull-to-refresh or edit syncs again after that.
public actor NativeNetworkRecoveryMonitor {
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    private let settleDelay: Duration
    private let sleep: Sleep
    private let onRecovered: @Sendable () async -> Void
    private var wasUnavailable = false
    private var pending: Task<Void, Never>?
    private var generation = 0

    public init(
        settleDelay: Duration = .seconds(2),
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        onRecovered: @escaping @Sendable () async -> Void
    ) {
        self.settleDelay = settleDelay
        self.sleep = sleep
        self.onRecovered = onRecovered
    }

    /// Records one reading. Returns the task that will ask for the sync, if this reading started one; callers only
    /// await it in tests.
    @discardableResult
    public func observe(isNetworkUsable: Bool) -> Task<Void, Never>? {
        generation += 1
        pending?.cancel()
        pending = nil
        guard isNetworkUsable else {
            wasUnavailable = true
            return nil
        }
        guard wasUnavailable else {
            return nil
        }
        let expected = generation
        let task = Task { [settleDelay, sleep] in
            do {
                try await sleep(settleDelay)
            } catch {
                return
            }
            await self.fireIfCurrent(expected)
        }
        pending = task
        return task
    }

    /// Drops a recovery that is still settling. Call it when readings stop, so no sync fires after the owner is gone.
    public func cancel() {
        generation += 1
        pending?.cancel()
        pending = nil
    }

    private func fireIfCurrent(_ expected: Int) async {
        guard generation == expected, !Task.isCancelled else {
            return
        }
        wasUnavailable = false
        pending = nil
        await onRecovered()
    }
}
