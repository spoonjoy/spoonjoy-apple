import Foundation
import OuroReins
import SpoonjoyCore

struct AddRecipeLink: ReinsInput { let link: String }

extension SpoonjoyReinsShell {
    /// `PlatformNavigationView.createRecipe()`: every create entry (the empty kitchen's hero, Shopping's Add a recipe,
    /// the Kitchen and Recipes toolbars) opens Add a recipe. The sheet's link field starts empty each time.
    func presentAddRecipe() {
        page.addRecipeLink = ""
        sheet = .addRecipe
    }

    /// `AddRecipeSheet`: the ways a recipe comes in, and a pasted link.
    var addRecipeNode: ReinsNode {
        let link = AddRecipeCopy.recipeLink(from: page.addRecipeLink)
        var actions = [
            ReinsAction("close", "Close") { [unowned self] in self.sheet = nil },
            ReinsAction("typeLink", "Paste a recipe link", input: AddRecipeLink.self) { [unowned self] in self.page.addRecipeLink = $0.link },
        ]
        if let link {
            actions.append(ReinsAction("importLink", "Import the link") { [unowned self] in
                // `AddRecipeSheet.importLink()`: the sheet dismisses, then the shell takes the link.
                self.sheet = nil
                self.importPastedLink(link)
            })
        }
        return ReinsNode("addRecipe", state: [
            "title": "Add a recipe",
            "ways": ["Tell Siri", "Ask Claude", "Share from Safari"],
            "siriPhrase": .string(AddRecipeCopy.siriPhrase),
            "link": .string(page.addRecipeLink),
        ], actions: actions)
    }

    /// `PlatformNavigationView.importPastedLink(_:)`: the link becomes a capture draft, and Imports opens on it.
    func importPastedLink(_ url: URL) {
        guard let draft = CaptureDraft.pastedLink(url, createdAt: fixtures.now()) else {
            return
        }
        store.recordCaptureDraft(draft)
        navigate(to: .capture)
    }
}
