import Testing
@testable import SpoonjoyCore

@Suite("Spread amount column")
struct SpreadAmountColumnTests {
    @Test("an amount breaks only between words")
    func words() {
        #expect(SpreadAmountColumn.words(in: "2 tablespoons") == ["2", "tablespoons"])
        #expect(SpreadAmountColumn.words(in: "  1½\u{00A0}cups ") == ["1½", "cups"])
        #expect(SpreadAmountColumn.words(in: "") == [])
    }

    // Review round 1: at the largest standard text size the 72 pt column split "tablespoons" mid-word.
    @Test("the amount keeps its column only while its longest word fits")
    func placement() {
        #expect(SpreadAmountColumn.placement(longestWordWidth: 60, columnWidth: 72, isAccessibilitySize: false) == .column)
        #expect(SpreadAmountColumn.placement(longestWordWidth: 72, columnWidth: 72, isAccessibilitySize: false) == .column)
        #expect(SpreadAmountColumn.placement(longestWordWidth: 72.5, columnWidth: 72, isAccessibilitySize: false) == .aboveName)
        #expect(SpreadAmountColumn.placement(longestWordWidth: 10, columnWidth: 72, isAccessibilitySize: true) == .aboveName)
    }
}
