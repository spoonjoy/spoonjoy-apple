@testable import SpoonjoyCore
import XCTest

final class RecipeIndexColumnsTests: XCTestCase {
    func testAPhoneAndTheIPadMiniKeepOneColumn() {
        XCTAssertEqual(RecipeIndexColumns.count(width: 353, rows: 12), 1)
        // The iPad mini upright: 744 pt less its 20 pt sides.
        XCTAssertEqual(RecipeIndexColumns.count(width: 704, rows: 12), 1)
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

    func testTwoColumnsNeedTwo380PointColumnsAndTheirGap() {
        XCTAssertEqual(RecipeIndexColumns.count(width: 792, rows: 12), 2)
        XCTAssertEqual(RecipeIndexColumns.count(width: 791, rows: 12), 1)
    }

    func testThePageWidensOnlyWhenTwoColumnsAreDrawn() {
        // The 11" iPad held sideways beside a 320 pt sidebar: 874 pt of container.
        let wide = RecipeIndexColumns.count(containerWidth: 874, rows: 12, setsColumns: true)
        XCTAssertEqual(wide, 2)
        XCTAssertEqual(RecipeIndexColumns.pageWidth(columns: wide), RecipeIndexColumns.widePageWidth)
        // The iPad mini upright, a one-recipe list, an empty list and an accessibility size keep the 720 pt page.
        for columns in [
            RecipeIndexColumns.count(containerWidth: 744, rows: 12, setsColumns: true),
            RecipeIndexColumns.count(containerWidth: 1400, rows: 1, setsColumns: true),
            RecipeIndexColumns.count(containerWidth: 1400, rows: 0, setsColumns: true),
            RecipeIndexColumns.count(containerWidth: 1400, rows: 12, setsColumns: false),
        ] {
            XCTAssertEqual(columns, 1)
            XCTAssertEqual(RecipeIndexColumns.pageWidth(columns: columns), RecipeIndexColumns.narrowPageWidth)
        }
    }
}
