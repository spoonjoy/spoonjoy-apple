import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Sync when the network comes back")
struct NativeNetworkRecoveryTests {
    private actor Counter {
        private(set) var value = 0
        func increment() { value += 1 }
    }

    /// A sleep the test releases by hand, so a reading can arrive while the settle delay is still running.
    private actor Gate {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private(set) var requestedDelays: [Duration] = []

        func wait(_ delay: Duration) async {
            requestedDelays.append(delay)
            await withCheckedContinuation { waiters.append($0) }
        }

        func releaseAll() {
            let current = waiters
            waiters = []
            current.forEach { $0.resume() }
        }

        var waitingCount: Int { waiters.count }
    }

    private static func waitUntil(_ condition: @Sendable () async -> Bool) async {
        for _ in 0..<1000 where !(await condition()) {
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
            sleep: { await gate.wait($0) },
            onRecovered: { await syncs.increment() }
        )

        await monitor.observe(isNetworkUsable: false)
        let firstTry = await monitor.observe(isNetworkUsable: true)
        await Self.waitUntil { await gate.waitingCount == 1 }
        await monitor.observe(isNetworkUsable: false)
        await gate.releaseAll()
        await firstTry?.value
        #expect(await syncs.value == 0)

        let steady = await monitor.observe(isNetworkUsable: true)
        await Self.waitUntil { await gate.waitingCount == 1 }
        // Another usable reading (Wi-Fi to cellular, say) restarts the delay instead of asking twice.
        let restarted = await monitor.observe(isNetworkUsable: true)
        #expect(restarted != nil)
        await Self.waitUntil { await gate.waitingCount == 2 }
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
}
