import Foundation

/// The App Intents X-ray checks that every parameter has a description (config/xray-expected.json), so the source
/// token tests read `@Parameter` declarations as if their description were absent and keep checking titles and
/// prompts as written.
enum SourceContractText {
    private static let parameterDescription = try! NSRegularExpression(
        pattern: #"(@Parameter\([^\n]*?), description: "(?:[^"\\]|\\.)*""#
    )

    static func withoutParameterDescriptions(_ source: String) -> String {
        parameterDescription.stringByReplacingMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source),
            withTemplate: "$1"
        )
    }
}

import Testing

@Suite("Source token tests read parameters without their descriptions")
struct SourceContractTextTests {
    @Test("a description, escaped quotes and all, is dropped and the rest of the declaration kept")
    func dropsDescriptions() {
        let source = #"""
            @Parameter(title: "Recipe", description: "The \"best\" recipe, by name.", requestValueDialog: "Which recipe?")
            @Parameter(title: "Name", description: "A name.")
            @Parameter(title: "Scale Factor")
            static let description = IntentDescription("Kept.")
        """#
        #expect(SourceContractText.withoutParameterDescriptions(source) == #"""
            @Parameter(title: "Recipe", requestValueDialog: "Which recipe?")
            @Parameter(title: "Name")
            @Parameter(title: "Scale Factor")
            static let description = IntentDescription("Kept.")
        """#)
    }
}
