import Testing
@testable import SpoonjoyCore

@Suite("Checked ingredient order")
struct CheckedIngredientOrderTests {
    private struct Item: Identifiable, Equatable {
        let id: String
    }

    private let step = ["pasta", "salt", "oil", "garlic"].map(Item.init(id:))

    @Test("nothing checked keeps the step's order")
    func nothingCheckedKeepsTheStepsOrder() {
        #expect(CheckedIngredientOrder.ordered(step, checkedIDs: []) == step)
    }

    @Test("a checked ingredient sinks below every unchecked one")
    func aCheckedIngredientSinks() {
        let ordered = CheckedIngredientOrder.ordered(step, checkedIDs: ["pasta"])
        #expect(ordered.map(\.id) == ["salt", "oil", "garlic", "pasta"])
    }

    @Test("checked ingredients keep the step's order, not the order they were checked in")
    func checkedIngredientsKeepTheStepsOrder() {
        // The web's IngredientList sorts by the original index within each group; it keeps no check time.
        let ordered = CheckedIngredientOrder.ordered(step, checkedIDs: ["garlic", "salt"])
        #expect(ordered.map(\.id) == ["pasta", "oil", "salt", "garlic"])
    }

    @Test("unchecking puts an ingredient back where it was")
    func uncheckingRestoresThePosition() {
        // The order is always worked out from the step's own list, so unchecking salt returns it to second place.
        let checked = CheckedIngredientOrder.ordered(step, checkedIDs: ["salt", "oil"])
        #expect(checked.map(\.id) == ["pasta", "garlic", "salt", "oil"])
        let unchecked = CheckedIngredientOrder.ordered(step, checkedIDs: ["oil"])
        #expect(unchecked.map(\.id) == ["pasta", "salt", "garlic", "oil"])
    }

    @Test("everything checked keeps the step's order")
    func everythingCheckedKeepsTheStepsOrder() {
        #expect(CheckedIngredientOrder.ordered(step, checkedIDs: Set(step.map(\.id))) == step)
    }

    @Test("the predicate form orders rows that carry their own checked state")
    func thePredicateFormOrdersRows() {
        let rows = [("a", true), ("b", false), ("c", true), ("d", false)]
        let ordered = CheckedIngredientOrder.ordered(rows) { $0.1 }
        #expect(ordered.map(\.0) == ["b", "d", "a", "c"])
        #expect(CheckedIngredientOrder.ordered([(String, Bool)]()) { $0.1 }.isEmpty)
    }
}
