import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe spread ingredient index")
struct RecipeSpreadIngredientIndexTests {
    private static func ingredient(_ id: String, _ name: String, _ quantity: Double = 1, _ unit: String? = nil) -> RecipeIngredient {
        RecipeIngredient(id: id, name: name, quantity: quantity, unit: unit)
    }

    private static let sections: [RecipeDetailStepSection] = [
        RecipeStep(id: "s1", stepNum: 1, stepTitle: "Brown the sausage", description: "Brown it.", duration: 8, ingredients: [
            ingredient("i1", "Italian sausage", 1, "lb"),
            ingredient("i2", "olive oil", 1, "tbsp")
        ]),
        RecipeStep(id: "s2", stepNum: 2, stepTitle: nil, description: "Boil water.", duration: nil, ingredients: []),
        RecipeStep(id: "s3", stepNum: 3, stepTitle: "Make the sauce", description: "Simmer.", duration: 20, ingredients: [
            ingredient("i3", "crushed tomatoes", 28, "oz")
        ], usingSteps: [
            RecipeStepOutputUse(id: "u1", inputStepNum: 3, outputStepNum: 1, outputOfStep: RecipeStepOutputReference(stepNum: 1, stepTitle: "Brown the sausage"))
        ]),
        RecipeStep(id: "s4", stepNum: 4, stepTitle: nil, description: "Toss.", duration: nil, ingredients: [], usingSteps: [
            RecipeStepOutputUse(id: "u2", inputStepNum: 4, outputStepNum: 3, outputOfStep: RecipeStepOutputReference(stepNum: 3, stepTitle: nil))
        ])
    ].map(RecipeDetailStepSection.init(step:))

    @Test("groups ingredients under the step that uses them, skipping steps with nothing to gather")
    func groupsByStep() {
        let index = RecipeSpreadIngredientIndex(stepSections: Self.sections)
        #expect(index.groups.map(\.id) == ["s1", "s3", "s4"])
        #expect(index.groups.map(\.stepNumber) == [1, 3, 4])
        #expect(index.groups[0].ingredients.map(\.name) == ["Italian sausage", "olive oil"])
        #expect(index.groups[1].dependencies.map(\.label) == ["Step 1: Brown the sausage"])
        #expect(index.groups[1].ingredients.map(\.name) == ["crushed tomatoes"])
        #expect(index.groups[2].dependencies.map(\.label) == ["Step 3"])
        #expect(index.groups[2].ingredients.isEmpty)
        #expect(index.ingredientCount == 3)
        #expect(!index.isEmpty)
    }

    @Test("group headings read like cookbook subheads")
    func headings() {
        let index = RecipeSpreadIngredientIndex(stepSections: Self.sections)
        #expect(index.groups[0].stepLabel == "Step 1")
        #expect(index.groups[0].title == "Brown the sausage")
        #expect(index.groups[2].stepLabel == "Step 4")
        #expect(index.groups[2].title == nil)
        #expect(index.groups[0].accessibilityHeading == "Step 1, Brown the sausage")
        #expect(index.groups[2].accessibilityHeading == "Step 4")
    }

    @Test("a blank step title reads as no title")
    func blankTitle() {
        let section = RecipeDetailStepSection(step: RecipeStep(id: "b", stepNum: 1, stepTitle: "", description: "Mix.", duration: nil, ingredients: [Self.ingredient("i", "flour")]))
        let index = RecipeSpreadIngredientIndex(stepSections: [section])
        #expect(index.groups[0].title == nil)
        #expect(index.groups[0].accessibilityHeading == "Step 1")
    }

    @Test("an empty recipe has an empty index")
    func emptyIndex() {
        let index = RecipeSpreadIngredientIndex(stepSections: [])
        #expect(index.isEmpty)
        #expect(index.ingredientCount == 0)
        #expect(index.group(forStepID: "s1") == nil)
    }

    @Test("selecting a step highlights its group and scrolls the ingredient page to it")
    func selectingStepHighlightsGroup() {
        let index = RecipeSpreadIngredientIndex(stepSections: Self.sections)
        var selection = RecipeSpreadSelection()
        #expect(selection.selectedStepID == nil)
        #expect(selection.highlightedGroupID(in: index) == nil)
        #expect(!selection.isSelected(stepID: "s1"))

        selection.toggle(stepID: "s3")
        #expect(selection.selectedStepID == "s3")
        #expect(selection.isSelected(stepID: "s3"))
        #expect(selection.highlightedGroupID(in: index) == "s3")
        #expect(selection.isHighlighted(groupID: "s3", in: index))
        #expect(!selection.isHighlighted(groupID: "s1", in: index))
        #expect(index.group(forStepID: "s3")?.stepNumber == 3)
    }

    @Test("selecting a step with nothing to gather selects it but highlights nothing")
    func selectingStepWithoutIngredients() {
        let index = RecipeSpreadIngredientIndex(stepSections: Self.sections)
        var selection = RecipeSpreadSelection()
        selection.toggle(stepID: "s2")
        #expect(selection.isSelected(stepID: "s2"))
        #expect(selection.highlightedGroupID(in: index) == nil)
    }

    @Test("tapping the selected step again clears the highlight, and another step moves it")
    func toggleAndMove() {
        var selection = RecipeSpreadSelection(selectedStepID: "s1")
        selection.toggle(stepID: "s1")
        #expect(selection.selectedStepID == nil)
        selection.toggle(stepID: "s1")
        selection.toggle(stepID: "s4")
        #expect(selection.selectedStepID == "s4")
        selection.clear()
        #expect(selection.selectedStepID == nil)
    }

    @Test("a selection pointing at a step the recipe no longer has highlights nothing")
    func staleSelection() {
        let index = RecipeSpreadIngredientIndex(stepSections: Self.sections)
        let selection = RecipeSpreadSelection(selectedStepID: "gone")
        #expect(selection.highlightedGroupID(in: index) == nil)
    }
}
