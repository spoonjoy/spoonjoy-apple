@testable import SpoonjoyCore
import XCTest

final class ShoppingAisleColumnsTests: XCTestCase {
    func testAPhoneAndANarrowListKeepOneColumn() {
        XCTAssertEqual(ShoppingAisleColumns.count(width: 345, aisles: 6), 1)
        XCTAssertEqual(ShoppingAisleColumns.count(width: 590, aisles: 6), 1)
    }

    func testTheUprightIPadListSetsTwoColumnsAndAWideOneThree() {
        // The 13" iPad upright, beside the recipes pane: about 610 pt of list.
        XCTAssertEqual(ShoppingAisleColumns.count(width: 610, aisles: 6), 2)
        XCTAssertEqual(ShoppingAisleColumns.count(width: 960, aisles: 6), 3)
        XCTAssertEqual(ShoppingAisleColumns.count(width: 2000, aisles: 6), ShoppingAisleColumns.maximumColumns)
    }

    func testTheWideIPadPageHoldsThreeColumns() {
        // The page's content is its width less its 20 pt sides.
        XCTAssertEqual(ShoppingAisleColumns.count(width: ShoppingAisleColumns.widePageWidth - 40, aisles: 6), 3)
    }

    func testNeverMoreColumnsThanAisles() {
        XCTAssertEqual(ShoppingAisleColumns.count(width: 960, aisles: 2), 2)
        XCTAssertEqual(ShoppingAisleColumns.count(width: 960, aisles: 1), 1)
        XCTAssertEqual(ShoppingAisleColumns.count(width: 0, aisles: 4), 1)
    }

    func testSplitKeepsAislesWholeInOrderAndBalancesTheTallest() {
        // Produce 7, Protein 3, Dairy 3, Pantry 4, Spices 2 (each counting its header).
        let ranges = ShoppingAisleColumns.split(heights: [7, 3, 3, 4, 2], columns: 2)
        XCTAssertEqual(ranges, [0..<2, 2..<5])
        XCTAssertEqual(ranges.flatMap { Array($0) }, Array(0..<5))
    }

    func testThreeColumns() {
        XCTAssertEqual(ShoppingAisleColumns.split(heights: [4, 4, 4, 4, 4, 4], columns: 3), [0..<2, 2..<4, 4..<6])
    }

    func testOneTallAisleTakesAColumnOfItsOwn() {
        XCTAssertEqual(ShoppingAisleColumns.split(heights: [2, 12, 2, 2], columns: 2), [0..<2, 2..<4])
        XCTAssertEqual(ShoppingAisleColumns.split(heights: [12, 2, 2, 2], columns: 2), [0..<1, 1..<4])
    }

    func testFewerAislesThanColumnsAndNoAisles() {
        XCTAssertEqual(ShoppingAisleColumns.split(heights: [3, 5], columns: 3), [0..<1, 1..<2])
        XCTAssertEqual(ShoppingAisleColumns.split(heights: [3, 5], columns: 1), [0..<2])
        XCTAssertEqual(ShoppingAisleColumns.split(heights: [], columns: 2), [])
    }
}
