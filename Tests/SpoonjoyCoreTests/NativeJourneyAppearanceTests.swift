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

    final class FakeWindow {
        var styled: [NativeJourneyAppearance] = []
    }

    @MainActor
    @Test("a notification styles every open window, and a window that appears later takes the same style")
    func relayReachesLateWindows() {
        var open = [FakeWindow(), FakeWindow()]
        let relay = JourneyAppearanceRelay<FakeWindow>(windows: { open }) { window, appearance in
            window.styled.append(appearance)
        }

        let late = FakeWindow()
        relay.windowAppeared(late)
        #expect(late.styled.isEmpty, "before any journey asks, a new window keeps the system appearance")

        #expect(relay.receive(notificationName: NativeJourneyAppearance.dark.notificationName))
        #expect(open.map(\.styled) == [[.dark], [.dark]])

        open.append(late)
        relay.windowAppeared(late)
        #expect(late.styled == [.dark])

        #expect(relay.receive(notificationName: NativeJourneyAppearance.system.notificationName))
        #expect(open.map(\.styled.last) == [.system, .system, .system])
        #expect(relay.current == .system)
    }

    @MainActor
    @Test("another notification name leaves every window as it was")
    func relayIgnoresOtherNames() {
        let window = FakeWindow()
        let relay = JourneyAppearanceRelay<FakeWindow>(windows: { [window] }) { window, appearance in
            window.styled.append(appearance)
        }
        #expect(!relay.receive(notificationName: "app.spoonjoy.journey.appearance.sepia"))
        #expect(window.styled.isEmpty)
        #expect(relay.current == nil)
    }
}
