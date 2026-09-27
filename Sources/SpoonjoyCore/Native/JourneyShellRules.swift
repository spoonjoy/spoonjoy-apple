import Foundation

/// Checks workflow and shell text for ways to retry, skip or soften journeys: xcodebuild retry flags,
/// loops that re-run xcodebuild or a script, `cmd || cmd` re-runs, retry wrappers, `continue-on-error`,
/// and test selection that drops journeys.
struct JourneyShellRuleScanner {
    static let allowedTestTargets: Set<String> = ["SpoonjoyJourneys", "SpoonjoyShoppingUITests"]
    static let loopKeywords: Set<String> = ["for", "while", "until"]
    static let neutralCommands: Set<String> = ["", "[[", "[", "test", "{", "(", "!", "true", "false"]

    struct LogicalLine {
        let line: Int
        let text: String
    }

    struct Loop {
        let line: Int
        var reported = false
    }

    let fileName: String
    let source: String

    func scan() -> [JourneyRuleViolation] {
        var violations: [JourneyRuleViolation] = []
        var loops: [Loop] = []
        for logical in Self.logicalLines(in: source) {
            violations += lineViolations(logical)
            for command in Self.commands(in: logical.text) {
                var words = command.split(whereSeparator: \.isWhitespace).map(String.init)
                let first = words.first ?? ""
                if Self.loopKeywords.contains(first) {
                    loops.append(Loop(line: logical.line))
                    // `while`/`until` run their condition on every pass; a `for` list is only data.
                    words = first == "for" ? [] : Array(words.dropFirst())
                } else if first == "done" {
                    _ = loops.popLast()
                }
                if let index = loops.indices.last, !loops[index].reported, let runner = Self.runner(words) {
                    loops[index].reported = true
                    violations.append(violation(loops[index].line, .noRetryConfig, "a shell loop re-runs `\(runner)`; flaky is failing"))
                }
            }
        }
        return violations
    }

    private func lineViolations(_ logical: LogicalLine) -> [JourneyRuleViolation] {
        let text = logical.text
        var found = JourneyHouseRules.retryWorkflowFlags.filter { text.contains($0) }.map { flag in
            violation(logical.line, .noRetryConfig, "`\(flag)` retries or repeats tests; flaky is failing")
        }
        if text.components(separatedBy: "xcodebuild").count > 2 || Self.hasRepeatedAlternative(text) {
            found.append(violation(logical.line, .noRetryConfig, "a command is re-run after it fails; flaky is failing"))
        }
        if Self.hasRetryWrapper(text) {
            found.append(violation(logical.line, .noRetryConfig, "a retry wrapper re-runs a failing step; flaky is failing"))
        }
        if let value = Self.value(ofKey: "continue-on-error", in: text), value != "false" {
            found.append(violation(logical.line, .noSkippedJourneys, "`continue-on-error: \(value)` lets a failing journey pass"))
        }
        if text.contains("-skip-testing") || text.contains("-skip-test-configuration") {
            found.append(violation(logical.line, .noSkippedJourneys, "test skipping drops journeys; select whole test targets only"))
        }
        for target in Self.onlyTestingTargets(in: text) where !Self.allowedTestTargets.contains(target) {
            found.append(violation(logical.line, .noSkippedJourneys, "`-only-testing:\(target)` runs part of a target; select SpoonjoyJourneys or SpoonjoyShoppingUITests whole"))
        }
        return found
    }

    private func violation(_ line: Int, _ rule: JourneyRuleID, _ message: String) -> JourneyRuleViolation {
        JourneyRuleViolation(file: fileName, line: line, rule: rule, message: message)
    }

    /// Joins backslash continuations and drops comments, keeping the first physical line number.
    static func logicalLines(in source: String) -> [LogicalLine] {
        var result: [LogicalLine] = []
        var pending: (line: Int, text: String)?
        for (index, raw) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = stripComment(String(raw))
            let start = pending?.line ?? index + 1
            let joined = (pending?.text ?? "") + line
            if joined.hasSuffix("\\") {
                pending = (start, String(joined.dropLast()) + " ")
            } else {
                pending = nil
                result.append(LogicalLine(line: start, text: joined))
            }
        }
        return result
    }

    static func stripComment(_ line: String) -> String {
        var previous: Character = " "
        for (offset, character) in line.enumerated() {
            if character == "#" && previous.isWhitespace {
                return String(line.prefix(offset))
            }
            previous = character
        }
        return line
    }

    /// Splits a logical line into shell commands, dropping YAML `run:` prefixes and shell keywords that
    /// introduce a command (`do`, `then`, `else`).
    static func commands(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ";&|")).map { segment in
            var command = segment.trimmingCharacters(in: .whitespaces)
            for prefix in ["- run:", "run:", "do ", "then ", "else "] where command.hasPrefix(prefix) {
                command = String(command.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
            return command
        }
    }

    static let launchers: Set<String> = ["bash", "sh", "zsh", "xcrun", "exec", "env", "time", "command"]

    /// The word naming a command that builds or runs tests: xcodebuild, a `*.sh` script, or a command named
    /// for journeys, run directly or through a launcher such as `bash` or `xcrun`. Nil for anything else.
    static func runner(_ words: [String]) -> String? {
        let words = words.first == "!" ? Array(words.dropFirst()) : words
        let candidates = launchers.contains(words.first ?? "") ? Array(words.prefix(2)) : Array(words.prefix(1))
        return candidates.first { word in
            word.contains("xcodebuild") || word.hasSuffix(".sh") || word.lowercased().contains("journey")
        }
    }

    /// `cmd … || cmd …`: the command after `||` starts the same way as the one before it.
    static func hasRepeatedAlternative(_ text: String) -> Bool {
        let parts = text.components(separatedBy: "||")
        return zip(parts, parts.dropFirst()).contains { left, right in
            let after = firstWord(right)
            return !neutralCommands.contains(after) && commands(in: left).map(firstWord).last == after
        }
    }

    static func firstWord(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    static func hasRetryWrapper(_ text: String) -> Bool {
        if let action = value(ofKey: "uses", in: text), action.lowercased().contains("retry") {
            return true
        }
        if value(ofKey: "max_attempts", in: text) != nil || value(ofKey: "max-attempts", in: text) != nil {
            return true
        }
        return commands(in: text).contains { firstWord($0).lowercased().contains("retry") }
    }

    /// The value of a YAML `key:` on this line (also `- key:`), trimmed; nil when the key is absent.
    static func value(ofKey key: String, in text: String) -> String? {
        var line = text.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("- ") {
            line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        guard line.hasPrefix(key + ":") else {
            return nil
        }
        return String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
    }

    static func onlyTestingTargets(in text: String) -> [String] {
        text.components(separatedBy: "-only-testing").dropFirst().map { rest in
            let value = rest.drop { $0 == ":" || $0 == " " || $0 == "=" }
            return String(value.prefix { !$0.isWhitespace && $0 != "\\" })
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
    }
}
