import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("SpoonjoyCore bootstrap")
struct SpoonjoyCoreBootstrapTests {
    @Test("product name is stable")
    func productName() {
        #expect(SpoonjoyCore.productName == "Spoonjoy")
    }

    @Test("bootstrap report allows only future native/app checks to remain pending")
    func bootstrapReportPendingChecks() {
        let report = ScenarioReporter.bootstrapReport()

        #expect(report.ok)
        #expect(report.stage == .bootstrap)
        #expect(report.checks.filter { $0.status == .fail }.isEmpty)
        #expect(report.checks.filter { $0.status == .pending }.map(\.name) == ["native metadata", "app surfaces"])
        #expect(report.nativeCapabilities.offlineFlows == ["fixture-offline-restore"])
    }

    @Test("fixture resources are copied into test bundle")
    func fixtureResources() throws {
        for name in SpoonjoyFixture.names {
            let data = try SpoonjoyFixture.data(named: name)
            #expect(!data.isEmpty)
        }
    }

    @Test("missing fixture reports file-not-found")
    func missingFixtureReportsFileNotFound() {
        var didThrowFileNotFound = false

        do {
            _ = try SpoonjoyFixture.data(named: "missing-fixture")
        } catch let error as CocoaError {
            didThrowFileNotFound = error.code == .fileNoSuchFile
        } catch {
            didThrowFileNotFound = false
        }

        #expect(didThrowFileNotFound)
    }
}
