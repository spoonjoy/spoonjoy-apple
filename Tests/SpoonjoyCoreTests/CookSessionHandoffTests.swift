import Foundation
import Testing
@testable import SpoonjoyCore

/// Final review I3: a fold, a rotation or a Split View resize rebuilds cook mode, and SwiftUI may run the new screen's
/// appear before or after the old screen's disappear.
@Suite("Cook session handoff")
struct CookSessionHandoffTests {
    @Test func leavingClearsOnlyYourOwnSession() {
        var ownership = CookSessionOwnership()
        let old = UUID(), new = UUID()
        ownership.claim(old)
        ownership.claim(new)
        let r1 = ownership.release(old)
        #expect(!r1)
        #expect(ownership.owner == new)
        let r2 = ownership.release(new)
        #expect(r2)
        #expect(ownership.owner == nil)
        let r3 = ownership.release(new)
        #expect(!r3)
    }

    @Test func micComesBackWhenTheOldScreenLeavesFirst() {
        var handoff = CookVoiceHandoff()
        handoff.leave(recipeID: "r1", voiceOn: true, at: 10)
        let r4 = handoff.resumes(recipeID: "r1", at: 10.2)
        #expect(r4)
        // It is used once.
        let r5 = handoff.resumes(recipeID: "r1", at: 10.3)
        #expect(!r5)
    }

    @Test func micStaysOffWhenItWasOff() {
        var handoff = CookVoiceHandoff()
        handoff.leave(recipeID: "r1", voiceOn: false, at: 10)
        let r6 = handoff.resumes(recipeID: "r1", at: 10.1)
        #expect(!r6)
    }

    @Test func micStaysOffForAnotherRecipe() {
        var handoff = CookVoiceHandoff()
        handoff.leave(recipeID: "r1", voiceOn: true, at: 10)
        let r7 = handoff.resumes(recipeID: "r2", at: 10.1)
        #expect(!r7)
    }

    @Test func micStaysOffAfterCookModeReallyClosed() {
        var handoff = CookVoiceHandoff()
        handoff.leave(recipeID: "r1", voiceOn: true, at: 10)
        let r8 = handoff.resumes(recipeID: "r1", at: 10 + CookVoiceHandoff.window + 0.01)
        #expect(!r8)
    }
}
