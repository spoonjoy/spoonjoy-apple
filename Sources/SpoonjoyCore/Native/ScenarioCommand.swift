import Foundation

public struct ScenarioCommand: Equatable {
    public let stage: ScenarioStage
    public let outputPath: String?

    public init(stage: ScenarioStage, outputPath: String?) {
        self.stage = stage
        self.outputPath = outputPath
    }

    public static func parse(arguments: [String]) throws -> ScenarioCommand {
        var stage = ScenarioStage.bootstrap
        var outputPath: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--stage":
                let rawStage = try value(after: argument, in: arguments, at: index)
                guard let parsedStage = ScenarioStage(rawValue: rawStage) else {
                    throw ScenarioCommandError.unknownStage(rawStage)
                }
                stage = parsedStage
                index += 2
            case "--output":
                outputPath = try value(after: argument, in: arguments, at: index)
                index += 2
            default:
                throw ScenarioCommandError.unknownArgument(argument)
            }
        }

        return ScenarioCommand(stage: stage, outputPath: outputPath)
    }

    @discardableResult
    public static func run(arguments: [String]) throws -> ScenarioReport {
        let command = try parse(arguments: arguments)
        let report = try ScenarioReporter.report(for: command.stage)
        let data = try reportData(report)

        if let outputPath = command.outputPath {
            let outputURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL)
        } else {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }

        return report
    }

    public static func main(arguments: [String]) -> Never {
        do {
            try run(arguments: arguments)
            exit(EXIT_SUCCESS)
        } catch {
            FileHandle.standardError.write(Data("Scenario verifier failed: \(error)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    public static func reportData(_ report: ScenarioReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    private static func value(after argument: String, in arguments: [String], at index: Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw ScenarioCommandError.missingValue(argument)
        }

        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else {
            throw ScenarioCommandError.missingValue(argument)
        }

        return value
    }
}
