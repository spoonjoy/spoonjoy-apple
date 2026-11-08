import Testing
@testable import SpoonjoyCore

@Suite("Journey appearance notifications")
struct NativeJourneyAppearanceTests {
    @Test("each appearance round-trips through its notification name")
    func roundTrip() {
        for appearance in NativeJourneyAppearance.allCases {
            #expect(NativeJourneyAppearance(notificationName: appearance.notificationName) == appearance)
        }
        #expect(NativeJourneyAppearance.dark.notificationName == "app.spoonjoy.journey.appearance.dark")
    }

    @Test("any other name is not an appearance")
    func unknownName() {
        #expect(NativeJourneyAppearance(notificationName: "app.spoonjoy.journey.appearance.sepia") == nil)
        #expect(NativeJourneyAppearance(notificationName: "") == nil)
    }
}
