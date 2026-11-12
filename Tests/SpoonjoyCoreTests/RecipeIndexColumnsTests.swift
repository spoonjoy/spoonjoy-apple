@testable import SpoonjoyCore
import Testing

@Suite("Recipe index columns")
struct RecipeIndexColumnsTests {
    @Test func testAPhoneAndTheIPadMiniKeepOneColumn() {
        #expect(RecipeIndexColumns.count(width: 353, rows: 12) == 1)
        // The iPad mini upright: 744 pt less its 20 pt sides.
        #expect(RecipeIndexColumns.count(width: 704, rows: 12) == 1)
    }

    @Test func testAWideIPadPageSetsTwoColumnsAndNeverMore() {
        // The 13" iPad held sideways beside its sidebar: about 1,016 pt of list.
        #expect(RecipeIndexColumns.count(width: 1016, rows: 12) == 2)
        #expect(RecipeIndexColumns.count(width: RecipeIndexColumns.widePageWidth - 40, rows: 12) == 2)
        #expect(RecipeIndexColumns.count(width: 3000, rows: 12) == RecipeIndexColumns.maximumColumns)
    }

    @Test func testOneRowOrNoRoomKeepsOneColumn() {
        #expect(RecipeIndexColumns.count(width: 1016, rows: 1) == 1)
        #expect(RecipeIndexColumns.count(width: 0, rows: 12) == 1)
    }

    @Test func testSeparatorsRunBetweenRowsOfEachColumnOnly() {
        #expect(!(RecipeIndexColumns.hasRowAbove(index: 0, columns: 2)))
        #expect(!(RecipeIndexColumns.hasRowAbove(index: 1, columns: 2)))
        #expect(RecipeIndexColumns.hasRowAbove(index: 2, columns: 2))
        #expect(!(RecipeIndexColumns.hasRowAbove(index: 0, columns: 1)))
        #expect(RecipeIndexColumns.hasRowAbove(index: 1, columns: 1))
    }

    @Test func testTwoColumnsNeedTwo380PointColumnsAndTheirGap() {
        #expect(RecipeIndexColumns.count(width: 792, rows: 12) == 2)
        #expect(RecipeIndexColumns.count(width: 791, rows: 12) == 1)
    }

    @Test func testThePageWidensOnlyWhenTwoColumnsAreDrawn() {
        // The 11" iPad held sideways beside a 320 pt sidebar: 874 pt of container.
        let wide = RecipeIndexColumns.count(containerWidth: 874, rows: 12, setsColumns: true)
        #expect(wide == 2)
        #expect(RecipeIndexColumns.pageWidth(columns: wide) == RecipeIndexColumns.widePageWidth)
        // The iPad mini upright, a one-recipe list, an empty list and an accessibility size keep the 720 pt page.
        for columns in [
            RecipeIndexColumns.count(containerWidth: 744, rows: 12, setsColumns: true),
            RecipeIndexColumns.count(containerWidth: 1400, rows: 1, setsColumns: true),
            RecipeIndexColumns.count(containerWidth: 1400, rows: 0, setsColumns: true),
            RecipeIndexColumns.count(containerWidth: 1400, rows: 12, setsColumns: false),
        ] {
            #expect(columns == 1)
            #expect(RecipeIndexColumns.pageWidth(columns: columns) == RecipeIndexColumns.narrowPageWidth)
        }
    }
}
