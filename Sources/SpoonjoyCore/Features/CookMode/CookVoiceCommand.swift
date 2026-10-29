import Foundation

/// A hands-free cook-mode command heard at the end of a short final utterance.
///
/// Only an utterance of four words or fewer counts, and only its last word or phrase, so "okay, next step" is a
/// command while "the next thing is garlic" and a sentence that happens to end in "timer" are not.
public enum CookVoiceCommand: Equatable, Sendable {
    case next, back, repeatStep, startTimer, checkAll

    /// The longest utterance that can be a command.
    public static let maximumWords = 4

    /// The parser's phrases are English, so voice runs only where the speech locale is English.
    public static func supports(languageCode: String?) -> Bool {
        languageCode?.lowercased() == "en"
    }

    private static let phrases: [(words: [String], command: CookVoiceCommand)] = [
        (["start", "the", "timer"], .startTimer),
        (["got", "them", "all"], .checkAll),
        (["start", "timer"], .startTimer),
        (["next", "step"], .next),
        (["go", "back"], .back),
        (["read", "it"], .repeatStep),
        (["check", "all"], .checkAll),
        (["next"], .next),
        (["back"], .back),
        (["previous"], .back),
        (["repeat"], .repeatStep),
        (["again"], .repeatStep),
        (["timer"], .startTimer),
    ]

    public static func parse(_ transcript: String) -> CookVoiceCommand? {
        let words = words(in: transcript)
        guard words.count <= maximumWords else {
            return nil
        }
        return phrases.first { words.suffix($0.words.count).elementsEqual($0.words) }?.command
    }

    /// The lowercased words of a transcript, without punctuation or numbers.
    public static func words(in transcript: String) -> [String] {
        transcript.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }
}
