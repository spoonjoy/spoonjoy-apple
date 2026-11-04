import Foundation
import OuroAXTesting
import Testing

/// `config/xray-expected.json` says which Ouro AX for Apple claims the App Intents X-ray must find holding in CI, and
/// why each other claim is still open. `scripts/check-xray.rb` holds a report to it; these tests hold it to the claim
/// set of the ouro-ui-apple release that Package.swift pins, so a claim set bump can't leave it naming stale claims.
@Suite("The X-ray's expected claims match the pinned Ouro AX claim set")
struct XrayExpectationTests {
    private struct Expected: Decodable {
        var hold: [String]
        var failing: [String: String]
        var open: [String: String]

        /// Every claim the file names, with the reason for each one that isn't held.
        var reasons: [String: String] { failing.merging(open) { first, _ in first } }
    }

    private static func expected() throws -> Expected {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("config/xray-expected.json"))
        return try JSONDecoder().decode(Expected.self, from: data)
    }

    @Test("every claim the expected file names is in the pinned claim set")
    func namesOnlyKnownClaims() throws {
        let expected = try Self.expected()
        let known = Set(try AXXray.ClaimSet.bundled().claims.map(\.id))
        let named = Set(expected.hold).union(expected.reasons.keys)
        #expect(named.subtracting(known).isEmpty, "not in the claim set: \(named.subtracting(known).sorted())")
    }

    @Test("every claim in the pinned set is listed exactly once, and every claim not held says why")
    func listsEveryClaimOnce() throws {
        let expected = try Self.expected()
        let known = Set(try AXXray.ClaimSet.bundled().claims.map(\.id))
        let held = Set(expected.hold)
        #expect(held.count == expected.hold.count, "a claim is listed twice under hold")
        #expect(held.isDisjoint(with: expected.reasons.keys), "listed twice: \(held.intersection(expected.reasons.keys).sorted())")
        #expect(Set(expected.failing.keys).isDisjoint(with: expected.open.keys), "under both failing and open")
        #expect(known.subtracting(held.union(expected.reasons.keys)).isEmpty, "not listed: \(known.subtracting(held.union(expected.reasons.keys)).sorted())")
        for (claim, reason) in expected.reasons {
            #expect(!reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(claim) is open with no reason")
        }
    }

    @Test("the fixes this repository made hold, and stay holding")
    func fixedClaimsAreHeld() throws {
        let held = Set(try Self.expected().hold)
        for claim in ["intent.title", "intent.description", "intent.parameter-title", "intent.parameter-description", "entity.findable"] {
            #expect(held.contains(claim), "\(claim) must be under hold")
        }
    }
}
