import Testing
@testable import SpoonjoyCore

@Suite("Cook voice listener state")
struct CookVoiceListenerStateTests {
    @Test func toggleOnAsksForPermission() {
        #expect(CookVoiceListenerState.off.next(on: .userToggledOn) == .requestingPermission)
    }

    @Test func grantedStartsListening() {
        #expect(CookVoiceListenerState.requestingPermission.next(on: .permissionGranted) == .listening)
    }

    @Test func deniedIsUnavailable() {
        #expect(CookVoiceListenerState.requestingPermission.next(on: .permissionDenied) == .unavailable(reason: "permission"))
    }

    @Test func recognizerFailureIsUnavailable() {
        #expect(CookVoiceListenerState.requestingPermission.next(on: .recognizerUnavailable(reason: "locale")) == .unavailable(reason: "locale"))
        #expect(CookVoiceListenerState.listening.next(on: .recognizerUnavailable(reason: "assets")) == .unavailable(reason: "assets"))
    }

    @Test func stopsWhenSceneGoesInactive() {
        #expect(CookVoiceListenerState.listening.next(on: .sceneInactive) == .off)
        #expect(CookVoiceListenerState.requestingPermission.next(on: .sceneInactive) == .off)
    }

    @Test func stopsWhenCookModeCloses() {
        #expect(CookVoiceListenerState.listening.next(on: .cookModeClosed) == .off)
        #expect(CookVoiceListenerState.unavailable(reason: "permission").next(on: .cookModeClosed) == .off)
    }

    @Test func toggleOffAlwaysStops() {
        #expect(CookVoiceListenerState.listening.next(on: .userToggledOff) == .off)
        #expect(CookVoiceListenerState.requestingPermission.next(on: .userToggledOff) == .off)
        #expect(CookVoiceListenerState.unavailable(reason: "permission").next(on: .userToggledOff) == .off)
    }

    @Test func unavailableStaysQuietUntilTheUserAsksAgain() {
        let denied = CookVoiceListenerState.unavailable(reason: "permission")
        #expect(denied.next(on: .sceneInactive) == denied)
        #expect(denied.next(on: .permissionGranted) == denied)
        #expect(denied.next(on: .userToggledOn) == .requestingPermission)
    }

    @Test func strayEventsAreIgnored() {
        #expect(CookVoiceListenerState.off.next(on: .permissionGranted) == .off)
        #expect(CookVoiceListenerState.off.next(on: .permissionDenied) == .off)
        #expect(CookVoiceListenerState.off.next(on: .recognizerUnavailable(reason: "x")) == .off)
        #expect(CookVoiceListenerState.listening.next(on: .userToggledOn) == .listening)
        #expect(CookVoiceListenerState.listening.next(on: .permissionGranted) == .listening)
        #expect(CookVoiceListenerState.requestingPermission.next(on: .userToggledOn) == .requestingPermission)
    }

    @Test func micIsLiveOnlyWhileListening() {
        #expect(CookVoiceListenerState.listening.isMicLive)
        #expect(!CookVoiceListenerState.off.isMicLive)
        #expect(!CookVoiceListenerState.requestingPermission.isMicLive)
        #expect(!CookVoiceListenerState.unavailable(reason: "permission").isMicLive)
    }

    @Test func toggleShowsOnWhenTheUserWantsVoice() {
        #expect(CookVoiceListenerState.listening.isToggledOn)
        #expect(CookVoiceListenerState.requestingPermission.isToggledOn)
        #expect(!CookVoiceListenerState.off.isToggledOn)
        #expect(!CookVoiceListenerState.unavailable(reason: "permission").isToggledOn)
    }
}
