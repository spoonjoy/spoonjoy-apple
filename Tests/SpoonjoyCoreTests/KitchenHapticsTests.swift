import Testing
@testable import SpoonjoyCore

@Suite("Kitchen haptics")
struct KitchenHapticsTests {
    @Test("every moment in the kitchen has feedback")
    func everyMomentHasFeedback() {
        #expect(KitchenHapticMoment.allCases.count == 7)
    }

    @Test("a finished timer feels like success")
    func timerFinishedIsSuccess() {
        #expect(KitchenHapticMoment.timerFinished.feedback == .success)
    }

    @Test("each moment maps to the feedback the design system names")
    func momentMapping() {
        #expect(KitchenHapticMoment.ingredientChecked.feedback == .selection)
        #expect(KitchenHapticMoment.listItemChecked.feedback == .selection)
        #expect(KitchenHapticMoment.stepTurned.feedback == .impactLight)
        #expect(KitchenHapticMoment.timerStarted.feedback == .impactMedium)
        #expect(KitchenHapticMoment.cookFinished.feedback == .success)
        #expect(KitchenHapticMoment.destructiveConfirm.feedback == .warning)
    }
}
