import Foundation
import Testing

@Suite("Kitchen navigation documentation and screenshot contract")
struct KitchenNavigationDocumentationContractTests {
    @Test("native design language mirrors the kitchen drawer model")
    func nativeDesignLanguageMirrorsKitchenDrawerModel() throws {
        let docPath = "docs/native-design-language.md"
        let doc = try readKitchenNavigationRepoFile(docPath)

        expectKitchenNavigationContent(
            doc,
            in: docPath,
            contains: [
                "Main Kitchen Navigation",
                "`Kitchen` -> `/`",
                "`My Recipes` -> `/recipes`",
                "`Saved Recipes` -> `/saved-recipes`",
                "`Cookbooks` -> `/cookbooks`",
                "`Shopping List` -> `/shopping-list`",
                "`Chefs` -> `/chefs`",
                "`Kitchen Search` -> `/search`",
                "compact iPhone tabs are exactly `Kitchen`, `Recipes`, `Saved`, `Cookbooks`, and `Shopping`",
                "Search stays in the trailing `More` menu",
                "Saved Recipes derive from cookbooks owned by the current chef",
                "route matrix covers `kitchen`, `recipes`, `saved-recipes`, `cookbooks`, `shopping-list`, `chefs`, and `search`"
            ],
            forbids: [
                "Latest from the kitchen"
            ]
        )
    }

    @Test("native screenshot harness covers saved recipes and chefs routes")
    func nativeScreenshotHarnessCoversSavedRecipesAndChefsRoutes() throws {
        let matrixPath = "scripts/capture-native-screenshot-matrix.sh"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let matrix = try readKitchenNavigationRepoFile(matrixPath)
        let capture = try readKitchenNavigationRepoFile(capturePath)
        let validator = try readKitchenNavigationRepoFile(validatorPath)

        expectKitchenNavigationContent(
            matrix,
            in: matrixPath,
            contains: [
                "\"saved-recipes|saved-recipes|$routes_dir/saved-recipes|$unit_slug-saved-recipes\"",
                "\"chefs|chefs|$routes_dir/chefs|$unit_slug-chefs\""
            ]
        )

        expectKitchenNavigationContent(
            capture,
            in: capturePath,
            contains: [
                "*saved-recipes*",
                "*chefs*",
                "saved-recipes)",
                "expected_recorded_route=\"saved-recipes\"",
                "deep_link_path=\"saved-recipes\"",
                "macos_window_title=\"Saved Recipes\"",
                "chefs)",
                "expected_recorded_route=\"chefs\"",
                "deep_link_path=\"chefs\"",
                "macos_window_title=\"Chefs\""
            ]
        )

        expectKitchenNavigationContent(
            validator,
            in: validatorPath,
            contains: [
                "\"saved-recipes\"",
                "\"chefs\"",
                "\"Saved Recipes\"",
                "\"ChefsView\""
            ]
        )
    }
}

private let kitchenNavigationRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func readKitchenNavigationRepoFile(_ relativePath: String) throws -> String {
    try String(
        contentsOf: kitchenNavigationRepoURL.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func uncommentedKitchenNavigationSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: .regularExpression)
}

private func expectKitchenNavigationContent(
    _ content: String,
    in path: String,
    contains requiredTokens: [String] = [],
    forbids forbiddenTokens: [String] = []
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    let presentForbidden = forbiddenTokens.filter { content.contains($0) }

    #expect(
        missing.isEmpty,
        Comment(rawValue: "\(path) missing required tokens: \(missing.joined(separator: ", "))")
    )
    #expect(
        presentForbidden.isEmpty,
        Comment(rawValue: "\(path) contains forbidden tokens: \(presentForbidden.joined(separator: ", "))")
    )
}
