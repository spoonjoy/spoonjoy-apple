import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// SPIKE (W13, Ouro Reins). Kitchen → recipe → cook → next step → previous step → back → back, headless over the fixture kitchen, with
/// the network blocked. Its XCUITest twin is `Apps/Spoonjoy/UITests/ReinsComparisonUITests.swift`.
@MainActor
@Suite("Ouro Reins spike: Kitchen to cook and back", .serialized)
struct KitchenToCookJourneyTests {
    static let pasta = "recipe_lemon_pantry_pasta"

    private func freshSession() async throws -> (ReinsSession, SpoonjoyReinsShell) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-reins-\(UUID().uuidString)")
        try SpoonjoyFixtureKitchen.copy(to: directory)
        let store = try SpoonjoyFixtureKitchen.store(in: directory)
        await store.bootstrap()
        let shell = SpoonjoyReinsShell(store: store)
        return (ReinsSession(shell), shell)
    }

    /// The journey, as an agent or a behavior test drives it.
    private func journey(_ session: ReinsSession) async throws {
        let journey = ReinsJourney(session)
        try await journey.expect("kitchen", describing: "the lead recipe is the pasta") { $0.state["lead"]?["id"] == .string(Self.pasta) }
        try await journey.do("openRecipe", ["id": .string(Self.pasta)], until: { $0.focus == "recipe" && $0.state["title"] == "Lemon Pantry Pasta" })
        try await journey.do("startCooking", until: { $0.focus == "cook" && $0.state["step"] == "Step 1 of 3" })
        try await journey.do("nextStep", until: { $0.state["step"] == "Step 2 of 3" && $0.actionNames.contains("previousStep") })
        try await journey.do("previousStep", until: { $0.state["step"] == "Step 1 of 3" })
        try await journey.do("goBack", until: { $0.focus == "recipe" && $0.context["tabs"]?["selected"] == "kitchen" })
        try await journey.do("goBack", until: { $0.focus == "kitchen" && $0.context["stack"]?["depth"] == 0 })
    }

    @Test("the journey runs headless, with no network")
    func journeyRuns() async throws {
        try await ReinsNetworkGuard.withNetworkBlocked {
            let (session, shell) = try await freshSession()
            try await journey(session)
            #expect(shell.navigation.route == .kitchen)
            // The cook session's push waits 800 ms for more changes; wait it out so a late request is caught too.
            try await Task.sleep(for: .seconds(1))
        }
    }

    @Test("a step the screen doesn't offer is refused with the valid ones, and the progress is the store's")
    func refusalsAndProgress() async throws {
        try await ReinsNetworkGuard.withNetworkBlocked {
            let (session, shell) = try await freshSession()
            let back = await session.perform("goBack")
            #expect(back.error?.code == "action-unavailable")
            #expect(back.error?.fix == "use one of: openRecipe, startCooking, selectTab")
            let stranger = await session.perform("openRecipe", input: ["id": "recipe_nope"])
            #expect(stranger.error?.code == "input-invalid", "only recipes in the kitchen can be opened")
            _ = await session.perform("startCooking", input: ["id": .string(Self.pasta)])
            let first = session.ls()
            #expect(first.focus == "cook")
            #expect(!first.actionNames.contains("previousStep"), "step 1 has no previous step")
            #expect(!first.actionNames.contains("selectTab"), "cook mode covers the tab bar")
            let salt = try #require(first.state["ingredients"]?[0]?["id"])
            let checked = await session.perform("checkIngredient", input: ["id": salt, "checked": true])
            #expect(checked.ok)
            #expect(checked.screen.state["page"] == "1 of 2 checked")
            #expect(shell.content.cookProgress(for: Self.pasta)?.checkedIngredientIDs.contains(salt.stringValue ?? "") == true,
                    "the check went through the live store, as the view's binding does")
            try await Task.sleep(for: .seconds(1))
        }
    }

    @Test("the guard catches Spoonjoy's real network path: a live-first launch tries to sync")
    func guardSeesLiveTraffic() async throws {
        let guardrail = await ReinsNetworkGuard.begin()
        defer { guardrail.end() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-reins-\(UUID().uuidString)")
        try SpoonjoyFixtureKitchen.copy(to: directory)
        let store = try SpoonjoyFixtureKitchen.store(in: directory, bootstrapMode: .liveFirst)
        await store.bootstrap()
        let attempts = guardrail.attempts
        #expect(!attempts.isEmpty)
        #expect(attempts.allSatisfy { $0.url.hasPrefix(APIClientConfiguration.spoonjoyProduction.baseURL.absoluteString) })
        print("[reins-spike] live-first attempts blocked: \(attempts.map(\.description))")
        #expect(throws: (any Error).self) { try guardrail.check() }
    }

    /// Times the journey `REINS_RUNS` times (default 50), each from a fresh copy of the fixtures and a fresh store, and
    /// writes the times to `REINS_TIMING_OUT` when set.
    @Test("timing: one journey from a fresh store, many times")
    func timing() async throws {
        let runs = Int(ProcessInfo.processInfo.environment["REINS_RUNS"] ?? "") ?? 50
        let clock = ContinuousClock()
        var times: [Double] = []
        try await ReinsNetworkGuard.withNetworkBlocked {
            for _ in 0..<runs {
                let start = clock.now
                let (session, _) = try await freshSession()
                try await journey(session)
                let elapsed = clock.now - start
                times.append(Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15)
            }
            try await Task.sleep(for: .seconds(1))
        }
        let sorted = times.sorted()
        let median = sorted[sorted.count / 2]
        let p90 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]
        let summary = String(format: "[reins-spike] %d journeys: first %.1f ms, median %.1f ms, p90 %.1f ms, max %.1f ms", runs, times[0], median, p90, sorted.last!)
        print(summary)
        if let out = ProcessInfo.processInfo.environment["REINS_TIMING_OUT"] {
            let report: [String: Any] = ["runs": runs, "ms": times, "firstMs": times[0], "medianMs": median, "p90Ms": p90, "maxMs": sorted.last!,
                                         "includes": "copy fixtures, build store, bootstrap from cache, 7 journey steps with polling assertions"]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: out))
        }
        #expect(median < 2000)
    }
}
