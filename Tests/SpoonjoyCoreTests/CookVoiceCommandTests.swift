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

    @Test func onlyShortUtterancesAreCommands() {
        #expect(CookVoiceCommand.parse("okay go to next") == .next)
        #expect(CookVoiceCommand.parse("we should now start the timer") == nil)
        #expect(CookVoiceCommand.parse("put it in the oven and go back") == nil)
        #expect(CookVoiceCommand.words(in: "Okay, NEXT step 2!") == ["okay", "next", "step"])
    }

    @Test func englishOnly() {
        #expect(CookVoiceCommand.supports(languageCode: "en"))
        #expect(CookVoiceCommand.supports(languageCode: "EN"))
        #expect(!CookVoiceCommand.supports(languageCode: "fr"))
        #expect(!CookVoiceCommand.supports(languageCode: nil))
    }

    /// The app's own lines, shown and read by VoiceOver, must never turn a page or start a timer.
    @Test func noNoticeTextIsACommand() {
        let lines = [
            CookVoiceNoticeText.listening,
            CookVoiceNoticeText.preparing,
            CookVoiceNoticeText.lastStep,
            CookVoiceNoticeText.firstStep,
            CookVoiceNoticeText.actionFailed,
            CookVoiceNoticeText.unavailable(reason: "permission"),
            CookVoiceNoticeText.unavailable(reason: "locale"),
            CookVoiceNoticeText.unavailable(reason: "interrupted"),
            CookVoiceNoticeText.unavailable(reason: "audio"),
        ] + (1...12).flatMap { step in
            [
                CookVoiceNoticeText.turnedForward(to: step, of: 12),
                CookVoiceNoticeText.turnedBack(to: step, of: 12),
                CookVoiceNoticeText.reading(step: step, of: 12),
            ]
        }
        for line in lines {
            #expect(CookVoiceCommand.parse(line) == nil, "\(line)")
        }
    }

    @Test func onlyThePermissionNoticeOffersSettings() {
        #expect(CookVoiceNoticeText.offersSettings(reason: "permission"))
        #expect(!CookVoiceNoticeText.offersSettings(reason: "locale"))
    }
}
