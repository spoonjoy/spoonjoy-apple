@testable import SpoonjoyCore
import Testing

@Suite("Shopping aisle columns")
struct ShoppingAisleColumnsTests {
    @Test func testAPhoneAndANarrowListKeepOneColumn() {
        #expect(ShoppingAisleColumns.count(width: 345, aisles: 6) == 1)
        #expect(ShoppingAisleColumns.count(width: 590, aisles: 6) == 1)
    }

    @Test func testTheUprightIPadListSetsTwoColumnsAndAWideOneThree() {
        // The 13" iPad upright beside the recipes pane, about 610 pt of list.
        #expect(ShoppingAisleColumns.count(width: 610, aisles: 6) == 2)
        #expect(ShoppingAisleColumns.count(width: 960, aisles: 6) == 3)
        #expect(ShoppingAisleColumns.count(width: 2000, aisles: 6) == ShoppingAisleColumns.maximumColumns)
    }

    @Test func testTheWideIPadPageHoldsThreeColumns() {
        // The page's content is its width less its 20 pt sides.
        #expect(ShoppingAisleColumns.count(width: ShoppingAisleColumns.widePageWidth - 40, aisles: 6) == 3)
    }

    @Test func testNeverMoreColumnsThanAisles() {
        #expect(ShoppingAisleColumns.count(width: 960, aisles: 2) == 2)
        #expect(ShoppingAisleColumns.count(width: 960, aisles: 1) == 1)
        #expect(ShoppingAisleColumns.count(width: 0, aisles: 4) == 1)
    }

    @Test func testSplitKeepsAislesWholeInOrderAndBalancesTheTallest() {
        // Produce 7, Protein 3, Dairy 3, Pantry 4, Spices 2 (each counting its header).
        let ranges = ShoppingAisleColumns.split(heights: [7, 3, 3, 4, 2], columns: 2)
        #expect(ranges == [0..<2, 2..<5])
        #expect(ranges.flatMap { Array($0) } == Array(0..<5))
    }

    @Test func testThreeColumns() {
        #expect(ShoppingAisleColumns.split(heights: [4, 4, 4, 4, 4, 4], columns: 3) == [0..<2, 2..<4, 4..<6])
    }

    @Test func testOneTallAisleTakesAColumnOfItsOwn() {
        #expect(ShoppingAisleColumns.split(heights: [2, 12, 2, 2], columns: 2) == [0..<2, 2..<4])
        #expect(ShoppingAisleColumns.split(heights: [12, 2, 2, 2], columns: 2) == [0..<1, 1..<4])
    }

    @Test func testFewerAislesThanColumnsAndNoAisles() {
        #expect(ShoppingAisleColumns.split(heights: [3, 5], columns: 3) == [0..<1, 1..<2])
        #expect(ShoppingAisleColumns.split(heights: [3, 5], columns: 1) == [0..<2])
        #expect(ShoppingAisleColumns.split(heights: [], columns: 2) == [])
    }

    @Test func testThePageWidensOnlyWhenThreeColumnsAreDrawn() {
        // The 13" iPad held sideways with the sidebar hidden, beside the recipes pane: about 1,005 pt of list container.
        let three = ShoppingAisleColumns.count(containerWidth: 1005, aisles: 6, setsColumns: true)
        #expect(three == 3)
        #expect(ShoppingAisleColumns.pageWidth(columns: three) == ShoppingAisleColumns.widePageWidth)
        // With the sidebar showing it is about 685 pt: two columns, which fit the 760 pt page, so it keeps its width.
        let two = ShoppingAisleColumns.count(containerWidth: 685, aisles: 6, setsColumns: true)
        #expect(two == 2)
        #expect(ShoppingAisleColumns.pageWidth(columns: two) == ShoppingAisleColumns.narrowPageWidth)
        // An empty list and accessibility sizes keep one column and the 760 pt page.
        #expect(ShoppingAisleColumns.count(containerWidth: 1400, aisles: 0, setsColumns: true) == 1)
        #expect(ShoppingAisleColumns.count(containerWidth: 1400, aisles: 6, setsColumns: false) == 1)
    }
}
