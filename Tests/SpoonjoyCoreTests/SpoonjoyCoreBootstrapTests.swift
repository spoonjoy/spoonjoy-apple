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
    func bootstrapReportPendingChecks() throws {
        let report = try ScenarioReporter.report(for: .bootstrap)

        #expect(report.ok)
        #expect(report.stage == .bootstrap)
        #expect(report.checks.filter { $0.status == .fail }.isEmpty)
        #expect(report.checks.filter { $0.status == .pending }.map(\.name) == ["native metadata", "app surfaces"])
        #expect(report.nativeCapabilities.offlineFlows == ["offline-cache-restore"])
        #expect(report.nativeCapabilities.associatedDomains.isEmpty)
        #expect(report.nativeCapabilities.urlSchemes.isEmpty)
        #expect(report.nativeCapabilities.deepLinkRoutes.isEmpty)
    }

    @Test("scenario command parses bootstrap stage and output")
    func scenarioCommandParsesBootstrapStageAndOutput() throws {
        let defaultCommand = try ScenarioCommand.parse(arguments: [])
        let command = try ScenarioCommand.parse(arguments: [
            "--stage", "bootstrap",
            "--output", "/tmp/spoonjoy-bootstrap.json"
        ])

        #expect(defaultCommand == ScenarioCommand(stage: .bootstrap, outputPath: nil))
        #expect(command == ScenarioCommand(stage: .bootstrap, outputPath: "/tmp/spoonjoy-bootstrap.json"))
    }

    @Test("scenario command parses final stage")
    func scenarioCommandParsesFinalStage() throws {
        let command = try ScenarioCommand.parse(arguments: ["--stage", "final"])
        let report = try ScenarioReporter.report(for: command.stage)

        #expect(command.stage == .final)
        #expect(report.stage == .final)
        #expect(report.checks.filter { $0.status == .pending }.isEmpty)
    }

    @Test("scenario command rejects malformed arguments")
    func scenarioCommandRejectsMalformedArguments() {
        var rejectedUnknownStage = false
        var rejectedMissingStage = false
        var rejectedMissingOutput = false
        var rejectedUnknownArgument = false

        do {
            _ = try ScenarioCommand.parse(arguments: ["--stage", "tomorrow"])
        } catch let error as ScenarioCommandError {
            rejectedUnknownStage = error == .unknownStage("tomorrow")
        } catch {
            rejectedUnknownStage = false
        }

        do {
            _ = try ScenarioCommand.parse(arguments: ["--stage"])
        } catch let error as ScenarioCommandError {
            rejectedMissingStage = error == .missingValue("--stage")
        } catch {
            rejectedMissingStage = false
        }

        do {
            _ = try ScenarioCommand.parse(arguments: ["--output", "--stage"])
        } catch let error as ScenarioCommandError {
            rejectedMissingOutput = error == .missingValue("--output")
        } catch {
            rejectedMissingOutput = false
        }

        do {
            _ = try ScenarioCommand.parse(arguments: ["--unexpected"])
        } catch let error as ScenarioCommandError {
            rejectedUnknownArgument = error == .unknownArgument("--unexpected")
        } catch {
            rejectedUnknownArgument = false
        }

        #expect(rejectedUnknownStage)
        #expect(rejectedMissingStage)
        #expect(rejectedMissingOutput)
        #expect(rejectedUnknownArgument)
    }

    @Test("scenario command errors have useful descriptions")
    func scenarioCommandErrorsHaveUsefulDescriptions() {
        #expect(ScenarioCommandError.missingValue("--output").description == "Missing value for --output.")
        #expect(ScenarioCommandError.unknownArgument("--wat").description == "Unknown argument --wat.")
        #expect(ScenarioCommandError.unknownStage("tomorrow").description == "Unknown scenario stage tomorrow.")
        #expect(
            ScenarioCommandError.unsupportedStage(.final).description ==
                "Scenario stage final is not implemented in bootstrap."
        )
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
