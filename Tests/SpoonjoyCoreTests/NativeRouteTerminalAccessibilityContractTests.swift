import Foundation
import Testing

@Suite("Native route terminal accessibility source contract")
struct NativeRouteTerminalAccessibilityContractTests {
    @Test("every screenshot route binds a stable identifier to its visible terminal")
    func everyScreenshotRouteBindsAStableIdentifierToItsVisibleTerminal() throws {
        let contracts: [(path: String, required: [String])] = [
            (
                "Apps/Spoonjoy/Shared/Views/RecipesView.swift",
                [
                    #".accessibilityIdentifier("\(proofRoute).terminal")"#,
                    #".accessibilityIdentifier(isTerminal ? "\(proofRoute).terminal" : "recipe.row.\(row.id)")"#,
                    #".accessibilityIdentifier(isTerminal ? "chefs.terminal" : "chefs.row.\(profile.id)")"#
                ]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
                [#"terminalAccessibilityIdentifier: showsHeader ? "recipe-detail.terminal" : "cook-log.terminal""#]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift",
                [
                    #"let terminalAccessibilityIdentifier: String"#,
                    #".accessibilityIdentifier(terminalAccessibilityIdentifier)"#
                ]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift",
                [#"cover.id == data.covers.last?.id ? "recipe-covers.terminal""#]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/CookModeView.swift",
                [#"row.id == viewModel.ingredientChecklistRows.last?.id ? "cook-mode.terminal""#]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
                [
                    #"row.id == list.rows.last?.id ? "cookbooks.terminal""#,
                    #"isTerminal ? "cookbook-detail.terminal" : "cookbook-detail.recipe.\(recipe.id)""#
                ]
            ),
            (
                "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift",
                [
                    #"let terminalAccessibilityIdentifier: String?"#,
                    #"terminalAccessibilityIdentifier ?? "shopping-list.item.\(item.id)""#
                ]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift",
                [
                    #"terminalAccessibilityIdentifier: "shopping-list.terminal""#,
                    #".accessibilityIdentifier("shopping-list.terminal")"#
                ]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/SearchView.swift",
                [
                    #"terminalAccessibilityIdentifier: "search.terminal""#,
                    #"isTerminal ? "search.terminal" : "search.row.\(row.id)""#
                ]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift",
                [
                    #"terminalAccessibilityIdentifier: currentDraft == nil ? "capture.terminal" : nil"#,
                    #".accessibilityIdentifier("capture.terminal")"#
                ]
            ),
            (
                "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
                [#".accessibilityIdentifier("native sign-in settings")"#]
            ),
            (
                "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
                [#".accessibilityIdentifier("settings.terminal")"#]
            )
        ]

        for contract in contracts {
            let source = try terminalContractSource(at: contract.path)
            let missing = contract.required.filter { !source.contains($0) }
            #expect(
                missing.isEmpty,
                Comment(rawValue: "\(contract.path) is missing visible terminal bindings: \(missing.joined(separator: ", "))")
            )
        }
    }

    @Test("existing valid terminal identifiers remain source-stable")
    func existingValidTerminalIdentifiersRemainSourceStable() throws {
        let contracts: [(path: String, identifier: String)] = [
            ("Apps/Spoonjoy/Shared/Views/CookbooksView.swift", "kitchen.cookbook.\\(row.id)"),
            ("Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift", "recipe-editor.delete"),
            ("Apps/Spoonjoy/Shared/Views/ProfileView.swift", "profile.graph.kitchen-visitors"),
            ("Apps/Spoonjoy/Shared/Views/ProfileView.swift", "profile-graph.row.\\(row.id)")
        ]

        for contract in contracts {
            let source = try terminalContractSource(at: contract.path)
            #expect(
                source.contains(contract.identifier),
                Comment(rawValue: "\(contract.path) lost stable terminal identifier \(contract.identifier)")
            )
        }
    }
}

private let terminalContractRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func terminalContractSource(at relativePath: String) throws -> String {
    try String(
        contentsOf: terminalContractRepoURL.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}
