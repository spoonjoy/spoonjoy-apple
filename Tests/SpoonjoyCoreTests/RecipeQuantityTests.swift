import XCTest
@testable import SpoonjoyCore

final class RecipeQuantityTests: XCTestCase {
    func testFormatShowsWholeNumbersAndFractionGlyphs() {
        XCTAssertEqual(RecipeQuantity.format(2), "2")
        XCTAssertEqual(RecipeQuantity.format(0.25), "¼")
        XCTAssertEqual(RecipeQuantity.format(0.5), "½")
        XCTAssertEqual(RecipeQuantity.format(1.5), "1 ½")
        XCTAssertEqual(RecipeQuantity.format(2.75), "2 ¾")
        XCTAssertEqual(RecipeQuantity.format(1.0 / 3.0), "⅓")
        XCTAssertEqual(RecipeQuantity.format(2.0 / 3.0 + 3), "3 ⅔")
        XCTAssertEqual(RecipeQuantity.format(0.875), "⅞")
    }

    func testFormatRoundsNearWholeAndKeepsOtherDecimalsExact() {
        XCTAssertEqual(RecipeQuantity.format(0.9999), "1")
        XCTAssertEqual(RecipeQuantity.format(3.0001), "3")
        XCTAssertEqual(RecipeQuantity.format(0.3), "0.3")
        XCTAssertEqual(RecipeQuantity.format(1.125 + 0.01), "1.135")
        XCTAssertEqual(RecipeQuantity.format(1234.5), "1234 ½")
        XCTAssertEqual(RecipeQuantity.format(-0.5), "-½")
        XCTAssertEqual(RecipeQuantity.format(.nan), "")
        XCTAssertEqual(RecipeQuantity.format(.infinity), "")
    }

    func testParseReadsEveryTypedShape() {
        XCTAssertEqual(RecipeQuantity.parse("2"), 2)
        XCTAssertEqual(RecipeQuantity.parse(" 0.25 "), 0.25)
        XCTAssertEqual(RecipeQuantity.parse(".5"), 0.5)
        XCTAssertEqual(RecipeQuantity.parse("3/4"), 0.75)
        XCTAssertEqual(RecipeQuantity.parse("1 1/2"), 1.5)
        XCTAssertEqual(RecipeQuantity.parse("¼"), 0.25)
        XCTAssertEqual(RecipeQuantity.parse("1½"), 1.5)
        XCTAssertEqual(RecipeQuantity.parse("1 ½"), 1.5)
        XCTAssertEqual(RecipeQuantity.parse("2 ¾"), 2.75)
    }

    func testParseRejectsEverythingElse() {
        for text in ["", "   ", "abc", "1/0", "1/", "/2", "1.2.3", ".", "1 2 3", "1.5 1/2", "1 x", "1.5½", "-1", "1e3", "1/2/3", "x ½"] {
            XCTAssertNil(RecipeQuantity.parse(text), text)
        }
    }

    func testParseThenFormatRoundTrips() {
        for text in ["¼", "1 ½", "2", "⅔", "3 ⅞", "0.3"] {
            let value = try? XCTUnwrap(RecipeQuantity.parse(text))
            XCTAssertEqual(RecipeQuantity.format(value ?? .nan), text)
        }
    }

    func testValidationMessage() {
        XCTAssertNil(RecipeQuantity.validationMessage(for: "1 1/2"))
        XCTAssertNotNil(RecipeQuantity.validationMessage(for: "lots"))
        XCTAssertNotNil(RecipeQuantity.validationMessage(for: "0"))
        XCTAssertNotNil(RecipeQuantity.validationMessage(for: "100000"))
        XCTAssertNil(RecipeQuantity.validationMessage(for: "99999"))
    }
}
