import Testing
@testable import SpoonjoyCore

@Suite("Cook voice command")
struct CookVoiceCommandTests {
    @Test func nextVariants() {
        #expect(CookVoiceCommand.parse("okay next step") == .next)
        #expect(CookVoiceCommand.parse("Next.") == .next)
        #expect(CookVoiceCommand.parse("next step") == .next)
    }

    @Test func ignoresNextInsideASentence() {
        #expect(CookVoiceCommand.parse("the next thing is garlic and onions") == nil)
    }

    @Test func backVariants() {
        #expect(CookVoiceCommand.parse("go back") == .back)
        #expect(CookVoiceCommand.parse("Back!") == .back)
        #expect(CookVoiceCommand.parse("previous") == .back)
    }

    @Test func repeatVariants() {
        #expect(CookVoiceCommand.parse("repeat") == .repeatStep)
        #expect(CookVoiceCommand.parse("can you read it") == .repeatStep)
        #expect(CookVoiceCommand.parse("say that again") == .repeatStep)
    }

    @Test func timer() {
        #expect(CookVoiceCommand.parse("start the timer") == .startTimer)
        #expect(CookVoiceCommand.parse("start timer") == .startTimer)
        #expect(CookVoiceCommand.parse("TIMER") == .startTimer)
    }

    @Test func checkAllVariants() {
        #expect(CookVoiceCommand.parse("check all") == .checkAll)
        #expect(CookVoiceCommand.parse("okay, got them all") == .checkAll)
    }

    @Test func rejectsEmptyAndUnknown() {
        #expect(CookVoiceCommand.parse("") == nil)
        #expect(CookVoiceCommand.parse("   ,. ") == nil)
        #expect(CookVoiceCommand.parse("all") == nil)
        #expect(CookVoiceCommand.parse("stir the sauce") == nil)
    }

    @Test func matchesWholeWordsOnly() {
        #expect(CookVoiceCommand.parse("feedback") == nil)
        #expect(CookVoiceCommand.parse("nextdoor") == nil)
    }
}
