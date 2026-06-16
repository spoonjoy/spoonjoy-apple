import Foundation
import SpoonjoyCore

do {
    let command = try ScenarioCommand.parse(arguments: Array(CommandLine.arguments.dropFirst()))
    let report = try ScenarioReporter.report(for: command.stage)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)

    if let outputPath = command.outputPath {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: outputURL)
    } else {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
} catch {
    FileHandle.standardError.write(Data("Scenario verifier failed: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
