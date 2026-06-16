import Foundation
import SpoonjoyCore

let report = ScenarioReporter.bootstrapReport()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(report)

if let outputIndex = CommandLine.arguments.firstIndex(of: "--output"), outputIndex + 1 < CommandLine.arguments.count {
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[outputIndex + 1])
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: outputURL)
} else {
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}
