@testable import SpoonjoyCore
import XCTest

final class RecipeIndexColumnsTests: XCTestCase {
    func testAPhoneAndTheIPadMiniKeepOneColumn() {
        XCTAssertEqual(RecipeIndexColumns.count(width: 353, rows: 12), 1)
        // The iPad mini upright, or an 11" iPad beside its sidebar.
        XCTAssertEqual(RecipeIndexColumns.count(width: 680, rows: 12), 1)
    }

    func testAWideIPadPageSetsTwoColumnsAndNeverMore() {
        // The 13" iPad held sideways beside its sidebar: about 1,016 pt of list.
        XCTAssertEqual(RecipeIndexColumns.count(width: 1016, rows: 12), 2)
        XCTAssertEqual(RecipeIndexColumns.count(width: RecipeIndexColumns.widePageWidth - 40, rows: 12), 2)
        XCTAssertEqual(RecipeIndexColumns.count(width: 3000, rows: 12), RecipeIndexColumns.maximumColumns)
    }

    func testOneRowOrNoRoomKeepsOneColumn() {
        XCTAssertEqual(RecipeIndexColumns.count(width: 1016, rows: 1), 1)
        XCTAssertEqual(RecipeIndexColumns.count(width: 0, rows: 12), 1)
    }

    func testSeparatorsRunBetweenRowsOfEachColumnOnly() {
        XCTAssertFalse(RecipeIndexColumns.hasRowAbove(index: 0, columns: 2))
        XCTAssertFalse(RecipeIndexColumns.hasRowAbove(index: 1, columns: 2))
        XCTAssertTrue(RecipeIndexColumns.hasRowAbove(index: 2, columns: 2))
        XCTAssertFalse(RecipeIndexColumns.hasRowAbove(index: 0, columns: 1))
        XCTAssertTrue(RecipeIndexColumns.hasRowAbove(index: 1, columns: 1))
    }
}
