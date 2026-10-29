import Foundation

/// A hands-free cook-mode command heard at the end of a final transcript segment.
///
/// Only the last word or phrase counts, so "the next thing is garlic" is not a command
/// while "okay, next step" is.
public enum CookVoiceCommand: Equatable, Sendable {
    case next, back, repeatStep, startTimer, checkAll

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
        let words = transcript.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        return phrases.first { words.suffix($0.words.count).elementsEqual($0.words) }?.command
    }
}
