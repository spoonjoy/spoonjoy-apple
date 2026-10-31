import Testing
@testable import SpoonjoyCore

@Suite("Recipe serves control")
struct RecipeServesTests {
    @Test("a stated count steps one serving at a time and labels the servings, not the factor")
    func countSteps() {
        let serves = RecipeServes(servings: " 4 ")
        #expect(serves.statedServings == "4")
        #expect(serves.baseCount == 4)
        #expect(serves.label(scale: 1) == "Serves 4")
        let five = serves.incremented(1)
        #expect(five == 1.25)
        let six = serves.incremented(five)
        #expect(six == 1.5)
        #expect(serves.label(scale: six) == "Serves 6")
        #expect(serves.servings(atScale: six) == 6)
        #expect(serves.decremented(six) == 1.25)
    }

    @Test("thirds round to the serving the stepper lands on")
    func thirds() {
        let serves = RecipeServes(servings: "3")
        let four = serves.incremented(1)
        #expect(four == 1.33)
        #expect(serves.label(scale: four) == "Serves 4")
        #expect(serves.incremented(four) == 1.67)
        #expect(serves.label(scale: serves.incremented(four)) == "Serves 5")
    }

    @Test("a count never steps below one serving or the smallest scale")
    func countFloor() {
        let one = RecipeServes(servings: "1")
        #expect(one.decremented(1) == 1)
        #expect(!one.canDecrement(1))
        #expect(one.canIncrement(1))
        let eight = RecipeServes(servings: "8")
        #expect(eight.decremented(0.25) == 0.25)
        #expect(!eight.canDecrement(0.25))
        #expect(eight.servings(atScale: 0.01) == 1)
    }

    @Test("a count keeps the words after it")
    func countUnit() {
        let serves = RecipeServes(servings: "6 people")
        #expect(serves.baseCount == 6)
        #expect(serves.countUnit == "people")
        #expect(serves.label(scale: 1.5) == "Serves 9 people")
        #expect(RecipeServes(servings: "2,5").baseCount == 2.5)
    }

    @Test("a range or unparseable servings scale by the factor and keep the recipe's words")
    func statedRange() {
        let serves = RecipeServes(servings: "4-6")
        #expect(serves.baseCount == nil)
        #expect(serves.servings(atScale: 2) == nil)
        #expect(serves.label(scale: 1) == "Serves 4-6")
        #expect(serves.label(scale: 1.5) == "Serves 4-6 ×1.5")
        #expect(RecipeServes(servings: "4 -6").baseCount == nil)
        #expect(RecipeServes(servings: "0").baseCount == nil)
        #expect(RecipeServes(servings: "nan").baseCount == nil)
        #expect(RecipeServes(servings: "inf").baseCount == nil)
    }

    @Test("no stated servings scales in quarters below 1× and halves above it")
    func factorSteps() {
        let serves = RecipeServes(servings: nil)
        #expect(serves.statedServings == nil)
        #expect(RecipeServes(servings: "   ").statedServings == nil)
        #expect(serves.label(scale: 1) == "Scale 1×")
        #expect(serves.label(scale: 0.75) == "Scale 0.75×")
        #expect(serves.incremented(1) == 1.5)
        #expect(serves.incremented(1.2) == 1.5)
        #expect(serves.incremented(0.5) == 0.75)
        #expect(serves.incremented(0.75) == 1)
        #expect(serves.decremented(1.5) == 1)
        #expect(serves.decremented(1.2) == 1)
        #expect(serves.decremented(1) == 0.75)
        #expect(serves.decremented(0.25) == 0.25)
        #expect(!serves.canDecrement(0.25))
        #expect(serves.incremented(50) == 50)
        #expect(!serves.canIncrement(50))
    }

    @Test("a saved scale is rounded and clamped before use")
    func normalizedScale() {
        #expect(RecipeServes.normalizedScale(1.256) == 1.26)
        #expect(RecipeServes.normalizedScale(0.01) == 0.25)
        #expect(RecipeServes.normalizedScale(80) == 50)
        #expect(RecipeServes.normalizedScale(.nan) == 1)
        #expect(RecipeServes.normalizedScale(.infinity) == 1)
    }
}

@Suite("Recipe cook time")
struct RecipeCookTimeTests {
    @Test("the timed steps add up, and untimed or zero steps are ignored")
    func addsTimedSteps() {
        #expect(RecipeCookTime.label(stepDurations: [8, nil, 15, 0]) == "23 min")
        #expect(RecipeCookTime.label(stepDurations: [60]) == "1 hr")
        #expect(RecipeCookTime.label(stepDurations: [45, 20]) == "1 hr 5 min")
    }

    @Test("a recipe with no timed step has no cook time")
    func noTime() {
        #expect(RecipeCookTime.label(stepDurations: []) == nil)
        #expect(RecipeCookTime.label(stepDurations: [nil, 0, -5]) == nil)
    }
}

/// The Serves stepper and cook mode each normalise the shared scale. They must agree, or cook mode would open at a
/// different amount than the page shows.
@Suite("Recipe scale normalisers agree")
struct RecipeScaleNormalisersAgreeTests {
    @Test(arguments: [
        -1, 0, 0.01, 0.24, 0.25, 0.333, 0.5, 0.75, 1, 1.25, 4.0 / 3.0, 1.5, 1.666, 2, 2.004, 2.005, 12.5, 50, 50.01, 900,
        Double.nan, Double.infinity, -Double.infinity
    ])
    func servesAndCookModeNormaliseIdentically(_ value: Double) {
        #expect(RecipeServes.normalizedScale(value) == CookModeProgress.normalizedScaleFactor(value))
        #expect(RecipeServes.normalizedScale(value) == RecipePageProgressSnapshot.normalizedScaleFactor(value))
    }
}
