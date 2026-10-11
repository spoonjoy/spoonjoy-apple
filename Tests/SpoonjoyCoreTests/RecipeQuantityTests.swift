import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe quantity display and parsing")
struct RecipeQuantityTests {
    @Test func formatShowsWholeNumbersAndFractionGlyphs() {
        #expect(RecipeQuantity.format(2) == "2")
        #expect(RecipeQuantity.format(0.25) == "¼")
        #expect(RecipeQuantity.format(0.5) == "½")
        #expect(RecipeQuantity.format(1.5) == "1 ½")
        #expect(RecipeQuantity.format(2.75) == "2 ¾")
        #expect(RecipeQuantity.format(1.0 / 3.0) == "⅓")
        #expect(RecipeQuantity.format(2.0 / 3.0 + 3) == "3 ⅔")
        #expect(RecipeQuantity.format(0.875) == "⅞")
    }

    @Test func formatRoundsNearWholeAndKeepsOtherDecimalsExact() {
        #expect(RecipeQuantity.format(0.9999) == "1")
        #expect(RecipeQuantity.format(3.0001) == "3")
        #expect(RecipeQuantity.format(0.3) == "0.3")
        #expect(RecipeQuantity.format(1.125 + 0.01) == "1.135")
        #expect(RecipeQuantity.format(1234.5) == "1234 ½")
        #expect(RecipeQuantity.format(-0.5) == "-½")
        #expect(RecipeQuantity.format(.nan) == "")
        #expect(RecipeQuantity.format(.infinity) == "")
    }

    @Test func parseReadsEveryTypedShape() {
        #expect(RecipeQuantity.parse("2") == 2)
        #expect(RecipeQuantity.parse(" 0.25 ") == 0.25)
        #expect(RecipeQuantity.parse(".5") == 0.5)
        #expect(RecipeQuantity.parse("3/4") == 0.75)
        #expect(RecipeQuantity.parse("1 1/2") == 1.5)
        #expect(RecipeQuantity.parse("¼") == 0.25)
        #expect(RecipeQuantity.parse("1½") == 1.5)
        #expect(RecipeQuantity.parse("1 ½") == 1.5)
        #expect(RecipeQuantity.parse("2 ¾") == 2.75)
    }

    @Test func parseRejectsEverythingElse() {
        for text in ["", "   ", "abc", "1/0", "1/", "/2", "1.2.3", ".", "1 2 3", "1.5 1/2", "1 x", "1.5½", "-1", "1e3", "1/2/3", "x ½"] {
            #expect(RecipeQuantity.parse(text) == nil, "\(text)")
        }
    }

    @Test func parseThenFormatRoundTrips() throws {
        for text in ["¼", "1 ½", "2", "⅔", "3 ⅞", "0.3"] {
            let value = try #require(RecipeQuantity.parse(text))
            #expect(RecipeQuantity.format(value) == text)
        }
    }

    @Test func validationMessage() {
        #expect(RecipeQuantity.validationMessage(for: "1 1/2") == nil)
        #expect(RecipeQuantity.validationMessage(for: "lots") != nil)
        #expect(RecipeQuantity.validationMessage(for: "0") != nil)
        #expect(RecipeQuantity.validationMessage(for: "100000") != nil)
        #expect(RecipeQuantity.validationMessage(for: "99999") == nil)
    }
}
