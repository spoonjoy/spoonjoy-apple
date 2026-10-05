import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native sync diagnostics")
struct NativeSyncDiagnosticsTests {
    @Test("records nothing until enabled, then keeps the latest lines")
    func recordsOnlyWhenEnabled() {
        let log = NativeSyncDiagnostics()
        log.record("ignored")
        #expect(log.enabled == false)
        #expect(log.summary == "no sync requests")

        log.enable()
        #expect(log.enabled)
        log.recordSend(method: "PATCH", path: "/api/v1/recipes/r1", outcome: "422 invalid: Bad step")
        #expect(log.summary == "PATCH /api/v1/recipes/r1 -> 422 invalid: Bad step")

        for index in 0..<20 {
            log.record("line \(index)")
        }
        #expect(log.summary.hasPrefix("line 8"))
        #expect(log.summary.hasSuffix("line 19"))
    }

    @Test("the journey environment key is read as a truthy flag")
    func environmentKey() {
        #expect(NativeSyncDiagnostics.isRequested(environment: [NativeSyncDiagnostics.environmentKey: "1"]))
        #expect(NativeSyncDiagnostics.isRequested(environment: [NativeSyncDiagnostics.environmentKey: " TRUE "]))
        #expect(NativeSyncDiagnostics.isRequested(environment: [NativeSyncDiagnostics.environmentKey: "no"]) == false)
        #expect(NativeSyncDiagnostics.isRequested(environment: [:]) == false)
    }
}
