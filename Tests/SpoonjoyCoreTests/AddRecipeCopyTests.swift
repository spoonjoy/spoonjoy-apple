import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Add a recipe copy and links")
struct AddRecipeCopyTests {
    @Test("the sheet's Siri phrase is the App Shortcut phrase the capture intent declares")
    func siriPhraseMatchesAppShortcut() throws {
        #expect(AddRecipeCopy.siriPhrase == "Save a recipe to Spoonjoy")
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
            directory.deleteLastPathComponent()
        }
        let intents = try String(
            contentsOf: directory.appendingPathComponent("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift"),
            encoding: .utf8
        )
        let capture = try #require(intents.range(of: "intent: CaptureRecipeIntent(),"))
        let phrasesEnd = try #require(intents.range(of: "]", range: capture.upperBound..<intents.endIndex))
        let phrases = intents[capture.upperBound..<phrasesEnd.lowerBound]
        #expect(phrases.contains("\"\(AddRecipeCopy.siriPhraseTemplate)\""))
    }

    @Test("only http and https links with a host can be imported")
    func recipeLinkValidation() {
        #expect(AddRecipeCopy.recipeLink(from: "  https://example.com/recipes/pasta \n") == URL(string: "https://example.com/recipes/pasta"))
        #expect(AddRecipeCopy.recipeLink(from: "HTTP://example.com") == URL(string: "HTTP://example.com"))
        #expect(AddRecipeCopy.recipeLink(from: "ftp://example.com/recipe") == nil)
        #expect(AddRecipeCopy.recipeLink(from: "javascript:alert(1)") == nil)
        #expect(AddRecipeCopy.recipeLink(from: "https://") == nil)
        #expect(AddRecipeCopy.recipeLink(from: "https:///recipes/pasta") == nil)
        #expect(AddRecipeCopy.recipeLink(from: "pasta with tomatoes") == nil)
        #expect(AddRecipeCopy.recipeLink(from: "") == nil)
    }

    @Test("Add to list says what happened, and says so when it fails")
    func listAddNotice() {
        #expect(RecipeListAddNotice.added(recipeTitle: "Tomato Toast", outcome: .synced) == RecipeListAddNotice(message: "Added Tomato Toast to your list", isFailure: false))
        #expect(RecipeListAddNotice.added(recipeTitle: "Tomato Toast", outcome: .recovering).message == "Added Tomato Toast to your list")
        #expect(RecipeListAddNotice.added(recipeTitle: "Tomato Toast", outcome: .queuedForSync) == RecipeListAddNotice(message: "Tomato Toast will reach your list when you're back online", isFailure: false))
        #expect(RecipeListAddNotice.failed(recipeTitle: "Tomato Toast") == RecipeListAddNotice(message: "Couldn't add Tomato Toast to your list. Try again.", isFailure: true))
    }
}
