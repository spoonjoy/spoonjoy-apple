import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Sync when the network comes back")
struct NativeNetworkRecoveryTests {
    private actor Counter {
        private(set) var value = 0
        func increment() { value += 1 }
    }

    /// A sleep the test releases by hand, so a reading can arrive while the settle delay is still running. Like
    /// `Task.sleep`, it throws when its task is cancelled, so a cancelled wait never hangs the test.
    private actor Gate {
        private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
        private(set) var requestedDelays: [Duration] = []

        func wait(_ delay: Duration) async throws {
            requestedDelays.append(delay)
            let id = UUID()
            try await withTaskCancellationHandler {
                try await suspend(id)
            } onCancel: {
                Task { await self.cancel(id) }
            }
        }

        private func suspend(_ id: UUID) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters[id] = continuation
                }
            }
        }

        private func cancel(_ id: UUID) {
            waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
        }

        func releaseAll() {
            let current = waiters
            waiters = [:]
            current.values.forEach { $0.resume() }
        }

        var waitingCount: Int { waiters.count }
    }

    private static func waitUntil(_ what: String, _ condition: @Sendable () async -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while !(await condition()) {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting until \(what)")
                return
            }
            await Task.yield()
        }
    }

    @Test("coming back online asks for one sync; staying online or launching online asks for none")
    func recoveryAsksOnce() async {
        let syncs = Counter()
        let monitor = NativeNetworkRecoveryMonitor(sleep: { _ in }, onRecovered: { await syncs.increment() })

        #expect(await monitor.observe(isNetworkUsable: true) == nil)
        #expect(await monitor.observe(isNetworkUsable: true) == nil)
        #expect(await syncs.value == 0)

        #expect(await monitor.observe(isNetworkUsable: false) == nil)
        await monitor.observe(isNetworkUsable: true)?.value
        #expect(await syncs.value == 1)

        #expect(await monitor.observe(isNetworkUsable: true) == nil)
        #expect(await syncs.value == 1)
    }

    @Test("a connection that drops again before it settles does not ask; a steady recovery asks once")
    func flappingAsksOnceAfterItSettles() async {
        let syncs = Counter()
        let gate = Gate()
        let monitor = NativeNetworkRecoveryMonitor(
            settleDelay: .seconds(2),
            sleep: { try await gate.wait($0) },
            onRecovered: { await syncs.increment() }
        )

        await monitor.observe(isNetworkUsable: false)
        let firstTry = await monitor.observe(isNetworkUsable: true)
        await Self.waitUntil("one delay is running") { await gate.waitingCount == 1 }
        await monitor.observe(isNetworkUsable: false)
        await gate.releaseAll()
        await firstTry?.value
        #expect(await syncs.value == 0)

        let steady = await monitor.observe(isNetworkUsable: true)
        await Self.waitUntil("one delay is running") { await gate.waitingCount == 1 }
        // Another usable reading (Wi-Fi to cellular, say) restarts the delay instead of asking twice.
        let restarted = await monitor.observe(isNetworkUsable: true)
        #expect(restarted != nil)
        await Self.waitUntil("the restarted delay is the only one running") {
            let requested = await gate.requestedDelays.count
            let waiting = await gate.waitingCount
            return requested == 3 && waiting == 1
        }
        await gate.releaseAll()
        await steady?.value
        await restarted?.value
        #expect(await syncs.value == 1)
        #expect(await gate.requestedDelays == [.seconds(2), .seconds(2), .seconds(2)])
    }

    @Test("a cancelled settle delay never asks")
    func cancelledDelayNeverAsks() async {
        let syncs = Counter()
        let monitor = NativeNetworkRecoveryMonitor(
            sleep: { _ in throw CancellationError() },
            onRecovered: { await syncs.increment() }
        )
        await monitor.observe(isNetworkUsable: false)
        await monitor.observe(isNetworkUsable: true)?.value
        #expect(await syncs.value == 0)
    }

    @Test("with the real clock, recovery asks once the settle delay has passed")
    func realClockAsksAfterDelay() async {
        let syncs = Counter()
        let monitor = NativeNetworkRecoveryMonitor(settleDelay: .milliseconds(1), onRecovered: { await syncs.increment() })
        await monitor.observe(isNetworkUsable: false)
        await monitor.observe(isNetworkUsable: true)?.value
        #expect(await syncs.value == 1)
    }

    @Test("cancelling drops a recovery that is still settling")
    func cancelDropsSettlingRecovery() async {
        let syncs = Counter()
        let gate = Gate()
        let monitor = NativeNetworkRecoveryMonitor(sleep: { try await gate.wait($0) }, onRecovered: { await syncs.increment() })
        await monitor.observe(isNetworkUsable: false)
        let settling = await monitor.observe(isNetworkUsable: true)
        await Self.waitUntil("the delay is running") { await gate.waitingCount == 1 }
        await monitor.cancel()
        // Release the delay before waiting, so a cancel that stopped working fails here instead of hanging.
        await gate.releaseAll()
        await settling?.value
        #expect(await syncs.value == 0)
    }
}
