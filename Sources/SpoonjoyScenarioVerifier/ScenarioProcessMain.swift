import Foundation
import SpoonjoyCore

enum ScenarioProcessMain {
    static func main(arguments: [String]) -> Never {
        do {
            try ScenarioCommand.run(arguments: arguments)
            exit(EXIT_SUCCESS)
        } catch {
            FileHandle.standardError.write(Data("Scenario verifier failed: \(error)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }
}
