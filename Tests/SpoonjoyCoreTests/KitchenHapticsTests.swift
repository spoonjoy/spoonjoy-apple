import OuroHX
import SwiftUI
import Testing
@testable import SpoonjoyCore

@Suite("Kitchen haptics")
struct KitchenHapticsTests {
    /// What each moment played before its feedback came from OuroHX: the app's old `KitchenHapticKind` mapping.
    static let feltBefore: [KitchenHapticMoment: SensoryFeedback] = [
        .ingredientChecked: .selection,
        .listItemChecked: .selection,
        .servingsStepped: .selection,
        .stepTurned: .impact(weight: .light),
        .timerStarted: .impact(weight: .medium),
        .timerFinished: .success,
        .cookFinished: .success,
        .destructiveConfirm: .warning
    ]

    @Test("every moment in the kitchen has feedback")
    func everyMomentHasFeedback() {
        #expect(KitchenHapticMoment.allCases.count == 8)
        #expect(Set(Self.feltBefore.keys) == Set(KitchenHapticMoment.allCases))
    }

    @Test("each moment plays the OuroHX moment of the same meaning")
    func momentMapping() {
        #expect(KitchenHapticMoment.ingredientChecked.ouroMoment == .checked)
        #expect(KitchenHapticMoment.listItemChecked.ouroMoment == .checked)
        #expect(KitchenHapticMoment.servingsStepped.ouroMoment == .stepped)
        #expect(KitchenHapticMoment.timerStarted.ouroMoment == .started)
        #expect(KitchenHapticMoment.timerFinished.ouroMoment == .finished)
        #expect(KitchenHapticMoment.cookFinished.ouroMoment == .finished)
        #expect(KitchenHapticMoment.destructiveConfirm.ouroMoment == .warned)
    }

    @Test("every moment feels exactly as it did before")
    func feelsTheSame() throws {
        for moment in KitchenHapticMoment.allCases {
            #expect(moment.ouroMoment.sensoryFeedback == (try #require(Self.feltBefore[moment])), "\(moment)")
        }
    }

    @Test("a step turn keeps Spoonjoy's full-strength light impact, because OuroHX's turn is softer")
    func stepTurnKeepsSpoonjoysOwn() {
        #expect(KitchenHapticMoment.stepTurned.ouroMoment == .spoonjoyStepTurned)
        #expect(OuroHapticMoment.spoonjoyStepTurned.feedback == .impact(weight: .light, intensity: 1))
        // OuroHX's `.turned` is a light impact at 0.7: playing it would be a felt change.
        #expect(OuroHapticMoment.turned.sensoryFeedback != SensoryFeedback.impact(weight: .light))
    }
}
