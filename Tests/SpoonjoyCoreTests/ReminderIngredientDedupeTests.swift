import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Reminder ingredient name keys")
struct ReminderIngredientKeyTests {
    @Test("plural, case, and spacing variants share one key", arguments: [
        ("Eggs", "egg"), ("egg", "egg"), ("  EGGS  ", "egg"),
        ("tomatoes", "tomato"), ("Tomato", "tomato"), ("potatoes", "potato"), ("mangoes", "mango"),
        ("cherries", "cherry"), ("berries", "berry"), ("blueberries", "blueberry"),
        ("peaches", "peach"), ("radishes", "radish"), ("sandwiches", "sandwich"),
        ("leaves", "leaf"), ("loaves", "loaf"), ("halves", "half"),
        ("cloves", "clove"), ("olives", "olive"), ("chives", "chive"), ("cheeses", "cheese"),
        ("chicken   thighs", "chicken thigh"), ("Chicken Thigh", "chicken thigh"),
        ("green onions", "green onion"), ("scallions", "green onion"), ("spring onions", "green onion"),
        ("asparagus", "asparagus"), ("hummus", "hummus"), ("couscous", "couscous"),
        ("molasses", "molasses"), ("swiss", "swiss"), ("watercress", "watercress"), ("lemongrass", "lemongrass"),
        ("chilies", "chili"), ("chiles", "chile"), ("jalapeños", "jalapeno"), ("Jalapeño", "jalapeno"),
        ("aubergine", "eggplant"), ("courgettes", "zucchini"), ("garbanzo beans", "chickpea"),
        ("cookies", "cookie"), ("pies", "pie"), ("brownies", "brownie"),
        ("large eggs", "egg"), ("fresh basil", "basil"), ("ripe tomatoes", "tomato"),
        ("onion, diced", "onion"), ("garlic cloves (minced)", "garlic clove"), ("flour; sifted", "flour"),
        ("extra-virgin olive oil", "extra virgin olive oil"), ("half-and-half", "half and half"),
        ("salt & pepper", "salt and pepper"), ("Crème fraîche", "creme fraiche"),
        ("peas", "pea"), ("oats", "oat"), ("lentils", "lentil"), ("bananas", "banana"),
        ("gas", "gas"), ("a", "a"), ("", ""), ("   ", "")
    ])
    func keys(raw: String, expected: String) {
        #expect(ReminderIngredientText.key(for: raw) == expected)
    }
}

@Suite("Reminder quantity parsing")
struct ReminderQuantityParsingTests {
    struct Case: Sendable {
        let text: String
        let value: Double?
        let unit: String?
        let name: String
    }

    static let cases: [Case] = [
        Case(text: "2 cups flour", value: 2, unit: "cup", name: "flour"),
        Case(text: "2 cups of flour", value: 2, unit: "cup", name: "flour"),
        Case(text: "1 1/2 cups sugar", value: 1.5, unit: "cup", name: "sugar"),
        Case(text: "1/2 tsp salt", value: 0.5, unit: "tsp", name: "salt"),
        Case(text: "½ cup milk", value: 0.5, unit: "cup", name: "milk"),
        Case(text: "1½ lb beef", value: 1.5, unit: "lb", name: "beef"),
        Case(text: "1.5 kg potatoes", value: 1.5, unit: "kg", name: "potatoes"),
        Case(text: "2-3 cloves garlic", value: 3, unit: "clove", name: "garlic"),
        Case(text: "12 eggs", value: 12, unit: nil, name: "eggs"),
        Case(text: "3x eggs", value: 3, unit: nil, name: "eggs"),
        Case(text: "2 Tbsp. olive oil", value: 2, unit: "tbsp", name: "olive oil"),
        Case(text: "2 tablespoons butter", value: 2, unit: "tbsp", name: "butter"),
        Case(text: "3 teaspoons sugar", value: 3, unit: "tsp", name: "sugar"),
        Case(text: "8 oz cream cheese", value: 8, unit: "oz", name: "cream cheese"),
        Case(text: "2 pounds chicken", value: 2, unit: "lb", name: "chicken"),
        Case(text: "2 lbs chicken", value: 2, unit: "lb", name: "chicken"),
        Case(text: "500 g pasta", value: 500, unit: "g", name: "pasta"),
        Case(text: "500g pasta", value: 500, unit: "g", name: "pasta"),
        Case(text: "250 ml cream", value: 250, unit: "ml", name: "cream"),
        Case(text: "1 can tomatoes", value: 1, unit: "can", name: "tomatoes"),
        Case(text: "2 cans black beans", value: 2, unit: "can", name: "black beans"),
        Case(text: "1 bunch cilantro", value: 1, unit: "bunch", name: "cilantro"),
        Case(text: "1 pinch salt", value: 1, unit: "pinch", name: "salt"),
        Case(text: "1 gallon milk", value: 1, unit: "gal", name: "milk"),
        Case(text: "1 liter water", value: 1, unit: "l", name: "water"),
        Case(text: "flour", value: nil, unit: nil, name: "flour"),
        Case(text: "Flour (2 cups)", value: 2, unit: "cup", name: "Flour"),
        Case(text: "Eggs (12)", value: 12, unit: nil, name: "Eggs"),
        Case(text: "Eggs x2", value: 2, unit: nil, name: "Eggs"),
        Case(text: "Flour - 2 cups", value: 2, unit: "cup", name: "Flour"),
        Case(text: "Flour — 2 cups", value: 2, unit: "cup", name: "Flour"),
        Case(text: "Salt (to taste)", value: nil, unit: nil, name: "Salt (to taste)"),
        Case(text: "2", value: 2, unit: nil, name: ""),
        Case(text: "2 cups", value: 2, unit: "cup", name: ""),
        Case(text: "", value: nil, unit: nil, name: "")
    ]

    @Test("leading and trailing quantities split from the name", arguments: cases)
    func parse(testCase: Case) {
        let parsed = ReminderIngredientText.parse(testCase.text)
        #expect(parsed.quantity.value == testCase.value, "value for \(testCase.text)")
        #expect(parsed.quantity.unit == testCase.unit, "unit for \(testCase.text)")
        #expect(parsed.name == testCase.name, "name for \(testCase.text)")
    }

    @Test("quantities format with kitchen fractions", arguments: [
        (2.0, "cup", "2 cups"), (1.0, "cup", "1 cup"), (0.5, "cup", "1/2 cup"), (1.5, "cup", "1 1/2 cups"),
        (0.25, "tsp", "1/4 tsp"), (0.75, "tbsp", "3/4 tbsp"), (1.0 / 3.0, "cup", "1/3 cup"), (2.0 / 3.0, "cup", "2/3 cup"),
        (0.125, "tsp", "1/8 tsp"), (2.3, "lb", "2.3 lb"), (12.0, "", "12"), (3.0, "clove", "3 cloves"), (2.0, "bunch", "2 bunches"),
        (1.0, "pinch", "1 pinch"), (2.0, "pinch", "2 pinches"), (2.0, "oz", "2 oz"), (1.0, "can", "1 can"), (3.0, "can", "3 cans"),
        (2.0, "gal", "2 gal")
    ])
    func format(value: Double, unit: String, expected: String) {
        let quantity = ReminderQuantity(value: value, unit: unit.isEmpty ? nil : unit)
        #expect(quantity.displayText == expected)
    }

    @Test("a quantity without a value formats as nothing")
    func emptyQuantity() {
        #expect(ReminderQuantity(value: nil, unit: nil).displayText == "")
        #expect(ReminderQuantity(value: nil, unit: "cup").displayText == "")
    }

    @Test("units normalize through the same table")
    func unitNormalization() {
        #expect(ReminderQuantity(value: 2, unit: "Cups").unit == "cup")
        #expect(ReminderQuantity(value: 2, unit: " ").unit == nil)
        #expect(ReminderQuantity(value: 2, unit: "handfuls").unit == "handful")
        #expect(ReminderQuantity(value: 2, unit: "hanks").unit == "hank")
        #expect(ReminderQuantity(value: 2, unit: "hank").unit == "hank")
    }
}

@Suite("Reminder sync planner")
struct ReminderSyncPlannerTests {
    let recipe = ReminderSource(id: "recipe-1", label: "Carbonara")
    let otherRecipe = ReminderSource(id: "recipe-2", label: "Pancakes")

    func ingredient(_ name: String, _ quantity: Double? = nil, _ unit: String? = nil) -> ReminderIncomingIngredient {
        ReminderIncomingIngredient(name: name, quantity: quantity, unit: unit)
    }

    func existing(_ id: String, _ title: String, notes: String? = nil, done: Bool = false) -> ReminderExisting {
        ReminderExisting(id: id, title: title, notes: notes, isCompleted: done)
    }

    /// Applies a plan to an in-memory list the way the EventKit adapter does, so tests can run sends twice.
    func apply(_ plan: ReminderSyncPlan, to list: [ReminderExisting]) -> [ReminderExisting] {
        var result = list
        var nextID = 100 + list.count
        for operation in plan.operations {
            switch operation {
            case .create(let title, let notes):
                result.append(ReminderExisting(id: "new-\(nextID)", title: title, notes: notes, isCompleted: false))
                nextID += 1
            case .update(let id, let title, let notes, _):
                if let index = result.firstIndex(where: { $0.id == id }) {
                    result[index] = ReminderExisting(id: id, title: title, notes: notes, isCompleted: false)
                }
            case .unchanged:
                break
            }
        }
        return result
    }

    @Test("a new ingredient creates a reminder with the quantity in the title and the source in notes")
    func createsNew() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("Flour", 2, "cups")], existing: [], source: recipe)
        #expect(plan.operations == [.create(title: "Flour (2 cups)", notes: "2 cups · Carbonara [sj:recipe-1]")])
        #expect(plan.summary == ReminderSyncSummary(added: 1, updated: 0, reopened: 0, unchanged: 0))
    }

    @Test("a new ingredient without a quantity is a plain title")
    func createsWithoutQuantity() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("Salt")], existing: [], source: recipe)
        #expect(plan.operations == [.create(title: "Salt", notes: "some · Carbonara [sj:recipe-1]")])
    }

    @Test("blank ingredient names are skipped")
    func skipsBlank() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("  "), ingredient("")], existing: [], source: recipe)
        #expect(plan.operations.isEmpty)
        #expect(plan.summary == ReminderSyncSummary(added: 0, updated: 0, reopened: 0, unchanged: 0))
    }

    @Test("ingredients that normalize to the same name combine inside one send")
    func combinesWithinBatch() {
        let plan = ReminderSyncPlanner.plan(
            incoming: [ingredient("egg", 2), ingredient("Eggs", 3), ingredient("flour", 1, "cup"), ingredient("Flour", 0.5, "cups")],
            existing: [],
            source: recipe
        )
        #expect(plan.operations == [
            .create(title: "egg (5)", notes: "5 · Carbonara [sj:recipe-1]"),
            .create(title: "flour (1 1/2 cups)", notes: "1 1/2 cups · Carbonara [sj:recipe-1]")
        ])
    }

    @Test("different units in one send are listed together without conversion")
    func mixedUnits() {
        let plan = ReminderSyncPlanner.plan(
            incoming: [ingredient("butter", 2, "tbsp"), ingredient("butter", 1, "stick"), ingredient("butter")],
            existing: [],
            source: recipe
        )
        #expect(plan.operations == [.create(title: "butter (2 tbsp + 1 stick)", notes: "2 tbsp + 1 stick · Carbonara [sj:recipe-1]")])
    }

    @Test("an incomplete match updates the quantity instead of adding a duplicate")
    func updatesIncomplete() {
        let list = [existing("a", "Eggs (6)", notes: "6 · Pancakes [sj:recipe-2]")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("egg", 2)], existing: list, source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "Eggs (8)", notes: "6 · Pancakes [sj:recipe-2]\n2 · Carbonara [sj:recipe-1]", reopen: false)
        ])
        #expect(plan.summary == ReminderSyncSummary(added: 0, updated: 1, reopened: 0, unchanged: 0))
    }

    @Test("a plural reminder matches a singular ingredient and keeps the user's name")
    func keepsUserName() {
        let list = [existing("a", "Tomatoes")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("tomato", 3)], existing: list, source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "Tomatoes (3)", notes: "3 · Carbonara [sj:recipe-1]", reopen: false)
        ])
    }

    @Test("a hand-typed quantity on the list is kept and combined", arguments: [
        ("2 cups flour", "flour (3 cups)"), ("flour (2 cups)", "flour (3 cups)"), ("Flour - 2 cups", "Flour (3 cups)")
    ])
    func combinesWithHandTypedQuantity(title: String, expectedTitle: String) {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("Flour", 1, "cup")], existing: [existing("a", title)], source: recipe)
        guard case .update(let id, let newTitle, let notes, let reopen) = plan.operations.first else {
            Issue.record("expected an update")
            return
        }
        #expect(id == "a")
        #expect(newTitle.lowercased() == expectedTitle.lowercased())
        #expect(notes == "2 cups · on your list [sj:existing]\n1 cup · Carbonara [sj:recipe-1]")
        #expect(!reopen)
    }

    @Test("a hand-typed quantity with a different unit is listed beside the new one")
    func handTypedDifferentUnit() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("flour", 100, "g")], existing: [existing("a", "2 cups flour")], source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "flour (2 cups + 100 g)", notes: "2 cups · on your list [sj:existing]\n100 g · Carbonara [sj:recipe-1]", reopen: false)
        ])
    }

    @Test("a reminder whose title is only a quantity takes the incoming name")
    func quantityOnlyTitleTakesIncomingName() {
        let list = [existing("a", "2 cups flour"), existing("b", "2 cups")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("Rice", 1, "cup")], existing: list, source: recipe)
        #expect(plan.operations == [.create(title: "Rice (1 cup)", notes: "1 cup · Carbonara [sj:recipe-1]")])
        let reopened = ReminderSyncPlanner.plan(incoming: [ingredient("", 1)], existing: list, source: recipe)
        #expect(reopened.operations.isEmpty)
    }

    @Test("a typed quantity and the same recipe quantity add together")
    func typedQuantityAddsToRecipeQuantity() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 2)], existing: [existing("a", "Eggs (2)")], source: recipe)
        #expect(plan.operations == [.update(id: "a", title: "Eggs (4)", notes: "2 · on your list [sj:existing]\n2 · Carbonara [sj:recipe-1]", reopen: false)])
    }

    @Test("a match with no incoming quantity leaves an incomplete reminder alone")
    func noQuantityNoWrite() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("salt")], existing: [existing("a", "Salt")], source: recipe)
        #expect(plan.operations == [.unchanged(id: "a")])
        #expect(plan.summary == ReminderSyncSummary(added: 0, updated: 0, reopened: 0, unchanged: 1))
    }

    @Test("a completed match is reopened with only the new quantity")
    func reopensCompleted() {
        let list = [existing("a", "Milk (1 gal)", notes: "1 gal · Pancakes [sj:recipe-2]", done: true)]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("milk", 2, "cups")], existing: list, source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "Milk (2 cups)", notes: "2 cups · Carbonara [sj:recipe-1]", reopen: true)
        ])
        #expect(plan.summary == ReminderSyncSummary(added: 0, updated: 0, reopened: 1, unchanged: 0))
    }

    @Test("a completed hand-typed reminder reopens and drops the old quantity")
    func reopensCompletedHandTyped() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("flour", 1, "cup")], existing: [existing("a", "2 cups flour", done: true)], source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "flour (1 cup)", notes: "1 cup · Carbonara [sj:recipe-1]", reopen: true)
        ])
    }

    @Test("a completed match with no quantity reopens with a plain title")
    func reopensCompletedWithoutQuantity() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("salt")], existing: [existing("a", "Salt (2 tbsp)", done: true)], source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "Salt", notes: "some · Carbonara [sj:recipe-1]", reopen: true)
        ])
    }

    @Test("an incomplete match wins over a completed one")
    func prefersIncomplete() {
        let list = [existing("done", "Eggs", done: true), existing("open", "Eggs (2)", notes: "2 · Pancakes [sj:recipe-2]")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 1)], existing: list, source: recipe)
        guard case .update(let id, _, _, let reopen) = plan.operations.first else {
            Issue.record("expected an update")
            return
        }
        #expect(id == "open")
        #expect(!reopen)
    }

    @Test("with several incomplete matches the first one on the list is used")
    func firstIncompleteWins() {
        let list = [existing("one", "Eggs"), existing("two", "Egg")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 1)], existing: list, source: recipe)
        guard case .update(let id, _, _, _) = plan.operations.first else {
            Issue.record("expected an update")
            return
        }
        #expect(id == "one")
    }

    @Test("with only completed matches the first one is reopened")
    func firstCompletedWins() {
        let list = [existing("one", "Eggs", done: true), existing("two", "Egg", done: true)]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 1)], existing: list, source: recipe)
        guard case .update(let id, _, _, let reopen) = plan.operations.first else {
            Issue.record("expected an update")
            return
        }
        #expect(id == "one")
        #expect(reopen)
    }

    @Test("two matched ingredients never claim the same reminder twice")
    func noDoubleClaim() {
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("egg", 1), ingredient("eggs", 2)], existing: [existing("a", "Eggs")], source: recipe)
        #expect(plan.operations.count == 1)
        #expect(plan.operations == [.update(id: "a", title: "Eggs (3)", notes: "3 · Carbonara [sj:recipe-1]", reopen: false)])
    }

    @Test("sending the same recipe twice is a no-op the second time", arguments: [0, 1, 2, 3])
    func idempotent(scenario: Int) {
        let ingredients = [ingredient("flour", 2, "cups"), ingredient("Eggs", 3), ingredient("salt"), ingredient("tomatoes", 4)]
        let lists: [[ReminderExisting]] = [
            [],
            [existing("a", "Flour"), existing("b", "egg (6)", notes: "6 · Pancakes [sj:recipe-2]")],
            [existing("a", "2 cups flour"), existing("b", "Eggs", done: true), existing("c", "Tomato", done: true)],
            [existing("a", "Salt", done: true), existing("b", "Milk"), existing("c", "flour (1 cup)", notes: "1 cup · Carbonara [sj:recipe-1]")]
        ]
        let first = ReminderSyncPlanner.plan(incoming: ingredients, existing: lists[scenario], source: recipe)
        let afterFirst = apply(first, to: lists[scenario])
        let second = ReminderSyncPlanner.plan(incoming: ingredients, existing: afterFirst, source: recipe)
        #expect(second.isNoOp, "second send must change nothing: \(second.operations)")
        #expect(second.summary.added == 0 && second.summary.updated == 0 && second.summary.reopened == 0)
        let afterSecond = apply(second, to: afterFirst)
        #expect(afterSecond == afterFirst)
    }

    @Test("a second recipe adds to the first recipe's quantity and stays a no-op when repeated")
    func twoRecipes() {
        var list: [ReminderExisting] = []
        list = apply(ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 2)], existing: list, source: recipe), to: list)
        list = apply(ReminderSyncPlanner.plan(incoming: [ingredient("egg", 3)], existing: list, source: otherRecipe), to: list)
        #expect(list.count == 1)
        #expect(list[0].title == "eggs (5)")
        let again = ReminderSyncPlanner.plan(incoming: [ingredient("egg", 3)], existing: list, source: otherRecipe)
        #expect(again.isNoOp)
        let firstAgain = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 2)], existing: list, source: recipe)
        #expect(firstAgain.isNoOp)
    }

    @Test("re-sending a recipe with a changed quantity replaces its own share")
    func changedQuantityReplacesShare() {
        var list: [ReminderExisting] = []
        list = apply(ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 2)], existing: list, source: recipe), to: list)
        list = apply(ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 3)], existing: list, source: otherRecipe), to: list)
        let scaled = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 4)], existing: list, source: recipe)
        list = apply(scaled, to: list)
        #expect(list[0].title == "eggs (7)")
    }

    @Test("a reminder with unreadable notes still dedupes by name")
    func garbledNotes() {
        let plan = ReminderSyncPlanner.plan(
            incoming: [ingredient("eggs", 2)],
            existing: [existing("a", "Eggs", notes: "buy the brown ones\n[sj:broken")],
            source: recipe
        )
        #expect(plan.operations == [
            .update(id: "a", title: "Eggs (2)", notes: "buy the brown ones\n[sj:broken\n2 · Carbonara [sj:recipe-1]", reopen: false)
        ])
    }

    @Test("lines the user wrote in notes survive an update")
    func keepsUserNotes() {
        let list = [existing("a", "Eggs (2)", notes: "brown ones\n2 · Pancakes [sj:recipe-2]")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 1)], existing: list, source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "Eggs (3)", notes: "brown ones\n2 · Pancakes [sj:recipe-2]\n1 · Carbonara [sj:recipe-1]", reopen: false)
        ])
    }

    @Test("lines the user wrote in notes survive a reopen")
    func keepsUserNotesOnReopen() {
        let list = [existing("a", "Eggs (2)", notes: "brown ones\n2 · Pancakes [sj:recipe-2]", done: true)]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("eggs", 1)], existing: list, source: recipe)
        #expect(plan.operations == [
            .update(id: "a", title: "Eggs (1)", notes: "brown ones\n1 · Carbonara [sj:recipe-1]", reopen: true)
        ])
    }

    @Test("one ingredient mixed with no match and a match reports both")
    func summaryCounts() {
        let list = [existing("a", "Milk", done: true), existing("b", "Salt"), existing("c", "Eggs (1)", notes: "1 · Pancakes [sj:recipe-2]")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("butter", 1), ingredient("milk", 1), ingredient("salt"), ingredient("eggs", 1)], existing: list, source: recipe)
        #expect(plan.summary == ReminderSyncSummary(added: 1, updated: 1, reopened: 1, unchanged: 1))
        #expect(!plan.isNoOp)
        #expect(plan.summary.totalChanged == 3)
    }

    @Test("an incoming quantity-less ingredient does not erase a counted share")
    func quantitylessIncomingKeepsShare() {
        let list = [existing("a", "Eggs (2)", notes: "2 · Carbonara [sj:recipe-1]")]
        let plan = ReminderSyncPlanner.plan(incoming: [ingredient("eggs")], existing: list, source: recipe)
        #expect(plan.operations == [.update(id: "a", title: "Eggs", notes: "some · Carbonara [sj:recipe-1]", reopen: false)])
    }

    @Test("the message summarizes what changed")
    func messages() {
        #expect(ReminderSyncSummary(added: 2, updated: 1, reopened: 1, unchanged: 3).message(listName: "Groceries")
            == "Added 2, updated 1, reopened 1 in Groceries. 3 were already there.")
        #expect(ReminderSyncSummary(added: 1, updated: 0, reopened: 0, unchanged: 0).message(listName: "Groceries")
            == "Added 1 in Groceries.")
        #expect(ReminderSyncSummary(added: 1, updated: 0, reopened: 0, unchanged: 1).message(listName: "Groceries")
            == "Added 1 in Groceries. 1 was already there.")
        #expect(ReminderSyncSummary(added: 0, updated: 0, reopened: 0, unchanged: 4).message(listName: "Groceries")
            == "Everything was already in Groceries. Nothing changed.")
        #expect(ReminderSyncSummary(added: 0, updated: 0, reopened: 0, unchanged: 0).message(listName: "Groceries")
            == "No ingredients to send.")
    }

    @Test("shopping items convert to incoming ingredients for the shopping list source")
    func shoppingItems() {
        let items = [
            ShoppingListItem(id: "1", name: "eggs", quantity: 6, unit: nil, checked: false, checkedAt: nil, deletedAt: nil, categoryKey: nil, iconKey: nil, sortIndex: 0, updatedAt: "t"),
            ShoppingListItem(id: "2", name: "flour", quantity: nil, unit: "cup", checked: false, checkedAt: nil, deletedAt: nil, categoryKey: nil, iconKey: nil, sortIndex: 1, updatedAt: "t"),
            ShoppingListItem(id: "3", name: "milk", quantity: 1, unit: "gal", checked: true, checkedAt: "t", deletedAt: nil, categoryKey: nil, iconKey: nil, sortIndex: 2, updatedAt: "t"),
            ShoppingListItem(id: "5", name: "zero", quantity: 0, unit: nil, checked: false, checkedAt: nil, deletedAt: nil, categoryKey: nil, iconKey: nil, sortIndex: 4, updatedAt: "t"),
            ShoppingListItem(id: "4", name: "gone", quantity: 1, unit: nil, checked: false, checkedAt: nil, deletedAt: "t", categoryKey: nil, iconKey: nil, sortIndex: 3, updatedAt: "t")
        ]
        let incoming = ReminderIncomingIngredient.fromShoppingItems(items)
        #expect(incoming == [
            ReminderIncomingIngredient(name: "eggs", quantity: 6, unit: nil),
            ReminderIncomingIngredient(name: "flour", quantity: nil, unit: "cup"),
            ReminderIncomingIngredient(name: "zero", quantity: nil, unit: nil)
        ])
        #expect(ReminderSource.shoppingList == ReminderSource(id: "shopping-list", label: "Shopping list"))
    }

    @Test("recipe ingredients convert and scale")
    func recipeIngredients() {
        let ingredients = [RecipeIngredient(id: "i1", name: "Eggs", quantity: 2, unit: nil), RecipeIngredient(id: "i2", name: "Flour", quantity: 1.5, unit: "cups")]
        let incoming = ReminderIncomingIngredient.fromRecipe(ingredients, scaleFactor: 2)
        #expect(incoming == [
            ReminderIncomingIngredient(name: "Eggs", quantity: 4, unit: nil),
            ReminderIncomingIngredient(name: "Flour", quantity: 3, unit: "cups")
        ])
        #expect(ReminderIncomingIngredient.fromRecipe(ingredients, scaleFactor: 0).first?.quantity == 2)
        #expect(ReminderIncomingIngredient.fromRecipe([RecipeIngredient(id: "z", name: "Salt", quantity: 0, unit: nil)], scaleFactor: 1).first?.quantity == nil)
    }

    @Test("the default list prefers a Groceries-named list")
    func defaultList() {
        let lists = [ReminderListSummary(id: "1", title: "Reminders"), ReminderListSummary(id: "2", title: "Weekend Grocery Run"), ReminderListSummary(id: "3", title: "Groceries")]
        #expect(ReminderListSummary.preferredDefault(in: lists)?.id == "3")
        #expect(ReminderListSummary.preferredDefault(in: Array(lists.prefix(2)))?.id == "2")
        #expect(ReminderListSummary.preferredDefault(in: [lists[0]]) == nil)
        #expect(ReminderListSummary.preferredDefault(in: [ReminderListSummary(id: "9", title: "grocery")])?.id == "9")
        #expect(ReminderListSummary.preferredDefault(in: []) == nil)
    }
}
