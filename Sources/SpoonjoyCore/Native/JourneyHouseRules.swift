import Foundation

/// The kind of file the journey house-rules checker is reading.
public enum JourneyFileKind: String, Equatable, Sendable {
    case journey
    case support
    case workflow
}

/// Every rule the journey house-rules checker enforces.
public enum JourneyRuleID: String, CaseIterable, Equatable, Sendable {
    case noRetryConfig = "no-retry-config"
    case noLoops = "no-loops"
    case noTapInIterationClosure = "no-tap-in-iteration-closure"
    case noConditionalAssertion = "no-assertion-in-condition"
    case noSkippedJourneys = "no-skipped-journeys"
    case mutationNeedsRelaunchCheck = "mutation-needs-relaunch-check"
    case noRawQueryStrings = "no-raw-query-strings"
}

public struct JourneyRuleViolation: Equatable, Sendable {
    public let file: String
    public let line: Int
    public let rule: JourneyRuleID
    public let message: String

    public init(file: String, line: Int, rule: JourneyRuleID, message: String) {
        self.file = file
        self.line = line
        self.rule = rule
        self.message = message
    }

    public var formatted: String {
        "\(file):\(line) \(rule.rawValue) \(message)"
    }
}

/// Lexical checks that keep XCUITest journeys honest: no retries, no loops, no taps inside
/// iteration closures, no assertions inside branches, no skipped tests, every test re-checks
/// its result after a relaunch, and element queries go through named identifiers.
public enum JourneyHouseRules {
    static let retryWorkflowFlags = [
        "-retry-tests-on-failure",
        "-test-iterations",
        "-run-tests-until-failure",
        "-test-repetition-relaunch-enabled"
    ]
    static let retrySwiftIdentifiers: Set<String> = ["retryOnFailure", "testRepetitionMode"]
    static let interactionMethods: Set<String> = [
        "tap", "doubleTap", "twoFingerTap", "press", "typeText",
        "swipeUp", "swipeDown", "swipeLeft", "swipeRight",
        "adjust", "pinch", "rotate", "click"
    ]
    /// Calls that drive the app, whether written as `.tap(` or through a journey helper such as `signIn(`.
    static let journeyActions: Set<String> = interactionMethods.union([
        "signIn", "signOut", "openSettings", "closeSettings", "relaunch", "launchFresh",
        "launch", "terminate", "activate", "pastePassword", "assertQAEnvironment"
    ])
    /// Receivers whose use inside an iteration closure means the closure is driving the app.
    static let journeyReceivers: Set<String> = ["journey", "app", "XCUIApplication"]
    static let iterationMethods: Set<String> = [
        "forEach", "map", "flatMap", "compactMap", "filter", "reduce", "first", "contains", "allSatisfy"
    ]
    static let skipIdentifiers: Set<String> = ["XCTSkip", "XCTSkipIf", "XCTSkipUnless", "XCTExpectFailure"]
    static let helperExemptModifiers: Set<String> = ["private", "fileprivate", "override"]
    static let nonSubscriptKeywords: Set<String> = [
        "return", "in", "case", "where", "try", "await", "throw", "is", "as", "if", "guard", "while", "switch", "else"
    ]

    /// `.yml`/`.yaml` workflows and `.sh` scripts are checked as shell; `.swift` under `Support/` is support
    /// code and every other `.swift` file is a journey.
    public static func kind(forRelativePath path: String) -> JourneyFileKind? {
        if path.hasSuffix(".yml") || path.hasSuffix(".yaml") || path.hasSuffix(".sh") {
            return .workflow
        }
        guard path.hasSuffix(".swift") else {
            return nil
        }
        return path.hasPrefix("Support/") ? .support : .journey
    }

    public static func check(fileName: String, source: String, kind: JourneyFileKind) -> [JourneyRuleViolation] {
        switch kind {
        case .workflow:
            JourneyShellRuleScanner(fileName: fileName, source: source).scan()
        case .journey, .support:
            JourneySwiftRuleScanner(
                fileName: fileName,
                tokens: JourneyLexer.tokens(in: source),
                isJourney: kind == .journey
            ).scan()
        }
    }
}

public enum JourneyHouseRulesCommand {
    public static let usage = "usage: SpoonjoyJourneyRules <journeys directory> [<workflow or script file> ...]"

    /// Checks every file under the journeys directory plus the named workflow files.
    /// Returns 0 when everything is clean and 1 for violations, usage errors or IO errors.
    public static func run(
        arguments: [String],
        listFiles: (URL) throws -> [URL],
        readFile: (URL) throws -> String,
        output: (String) -> Void,
        error: (String) -> Void
    ) -> Int32 {
        guard let directoryArgument = arguments.first else {
            error(usage)
            return 1
        }

        let directory = URL(fileURLWithPath: directoryArgument, isDirectory: true)
        let prefix = directory.path + "/"
        var checkedFiles = 0
        var violations: [JourneyRuleViolation] = []

        do {
            let relativePaths = try listFiles(directory).map { file in
                file.path.hasPrefix(prefix) ? String(file.path.dropFirst(prefix.count)) : file.lastPathComponent
            }.sorted()
            let targets = relativePaths.compactMap { relative -> (String, URL, JourneyFileKind)? in
                JourneyHouseRules.kind(forRelativePath: relative).map { kind in
                    ((directoryArgument as NSString).appendingPathComponent(relative), directory.appendingPathComponent(relative), kind)
                }
            } + arguments.dropFirst().map { path in
                (path, URL(fileURLWithPath: path), JourneyFileKind.workflow)
            }
            try targets.forEach { displayName, url, kind in
                let source = try readFile(url)
                checkedFiles += 1
                violations += JourneyHouseRules.check(fileName: displayName, source: source, kind: kind)
            }
        } catch let failure {
            error("SpoonjoyJourneyRules could not read the journeys: \(failure.localizedDescription)")
            return 1
        }

        violations.forEach { output($0.formatted) }
        output("Checked \(checkedFiles) journey file(s), \(violations.count) violation(s).")
        return violations.isEmpty ? 0 : 1
    }

    public static func main(arguments: [String]) -> Int32 {
        let fileManager = FileManager.default
        return run(
            arguments: arguments,
            listFiles: { directory in
                try fileManager.subpathsOfDirectory(atPath: directory.path).map { directory.appendingPathComponent($0) }
            },
            readFile: { try String(contentsOf: $0, encoding: .utf8) },
            output: { print($0) },
            error: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
        )
    }
}

struct JourneyToken: Equatable {
    enum Kind: Equatable {
        case identifier
        case number
        case string
        case punctuation
    }

    let kind: Kind
    let text: String
    let line: Int
}

/// A small Swift lexer: identifiers, numbers, single-character punctuation and string
/// literals (collapsed to one token). Comments are dropped; line numbers are kept.
enum JourneyLexer {
    static func tokens(in source: String) -> [JourneyToken] {
        var lexer = Cursor(characters: Array(source))
        var tokens: [JourneyToken] = []
        while let character = lexer.current {
            let next = lexer.peek(1)
            if character.isNewline {
                lexer.advance()
            } else if character.isWhitespace {
                lexer.advance()
            } else if character == "/" && next == "/" {
                lexer.skipLineComment()
            } else if character == "/" && next == "*" {
                lexer.skipBlockComment()
            } else if character == "\"" || (character == "#" && lexer.startsRawString()) {
                let line = lexer.line
                lexer.skipStringLiteral()
                tokens.append(JourneyToken(kind: .string, text: "\"\"", line: line))
            } else if character.isLetter || character == "_" || character == "$" {
                let line = lexer.line
                let text = lexer.consume { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" }
                tokens.append(JourneyToken(kind: .identifier, text: text, line: line))
            } else if character.isNumber {
                let line = lexer.line
                let text = lexer.consume { $0.isLetter || $0.isNumber || $0 == "_" }
                tokens.append(JourneyToken(kind: .number, text: text, line: line))
            } else {
                tokens.append(JourneyToken(kind: .punctuation, text: String(character), line: lexer.line))
                lexer.advance()
            }
        }
        return tokens
    }

    struct Cursor {
        let characters: [Character]
        var index = 0
        var line = 1

        var current: Character? {
            peek(0)
        }

        func peek(_ offset: Int) -> Character? {
            index + offset < characters.count ? characters[index + offset] : nil
        }

        mutating func advance(_ count: Int = 1) {
            (0..<count).forEach { _ in
                if let character = current {
                    line += character.isNewline ? 1 : 0
                    index += 1
                }
            }
        }

        func matches(_ text: String) -> Bool {
            Array(text).enumerated().allSatisfy { offset, character in peek(offset) == character }
        }

        mutating func consume(while predicate: (Character) -> Bool) -> String {
            var text = ""
            while let character = current, predicate(character) {
                text.append(character)
                advance()
            }
            return text
        }

        func startsRawString() -> Bool {
            var offset = 0
            while peek(offset) == "#" {
                offset += 1
            }
            return peek(offset) == "\""
        }

        mutating func skipLineComment() {
            while let character = current, !character.isNewline {
                advance()
            }
        }

        mutating func skipBlockComment() {
            advance(2)
            var depth = 1
            while current != nil && depth > 0 {
                if matches("/*") {
                    depth += 1
                    advance(2)
                } else if matches("*/") {
                    depth -= 1
                    advance(2)
                } else {
                    advance()
                }
            }
        }

        mutating func skipStringLiteral() {
            var hashes = 0
            while current == "#" {
                hashes += 1
                advance()
            }
            let multiline = matches("\"\"\"")
            let quote = multiline ? "\"\"\"" : "\""
            let terminator = quote + String(repeating: "#", count: hashes)
            advance(quote.count)
            while let character = current {
                if matches(terminator) {
                    advance(terminator.count)
                    return
                }
                if !multiline && character.isNewline {
                    return
                }
                if hashes == 0 && character == "\\" && peek(1) == "(" {
                    advance(2)
                    skipInterpolation()
                } else if hashes == 0 && character == "\\" {
                    advance(2)
                } else {
                    advance()
                }
            }
        }

        mutating func skipInterpolation() {
            var depth = 1
            while let character = current, depth > 0 {
                if character == "\"" {
                    skipStringLiteral()
                } else {
                    depth += character == "(" ? 1 : 0
                    depth -= character == ")" ? 1 : 0
                    advance()
                }
            }
        }
    }
}

/// Walks the token stream with a brace/paren stack that records which construct opened
/// each block, and reports house-rule violations.
struct JourneySwiftRuleScanner {
    enum Block: Equatable {
        case conditional
        case loop(String)
        case iterationClosure
        case iterationCall
        case testFunction(name: String, line: Int)
        case other
    }

    struct Frame {
        let opener: String
        let block: Block
        var callsRelaunchCheck = false
    }

    let fileName: String
    let tokens: [JourneyToken]
    let isJourney: Bool

    private var stack: [Frame] = []
    private var pending: (block: Block, depth: Int)?
    private var pendingIteration = false
    private var closedIterationCall = false
    private var closedBlock: Block?
    private var violations: [JourneyRuleViolation] = []

    init(fileName: String, tokens: [JourneyToken], isJourney: Bool) {
        self.fileName = fileName
        self.tokens = tokens
        self.isJourney = isJourney
    }

    private var parenDepth: Int {
        stack.filter { $0.opener != "{" }.count
    }

    func scan() -> [JourneyRuleViolation] {
        var scanner = self
        tokens.indices.forEach { scanner.visit($0) }
        return scanner.violations
    }

    private func text(at index: Int) -> String? {
        tokens.indices.contains(index) ? tokens[index].text : nil
    }

    private mutating func visit(_ index: Int) {
        let token = tokens[index]
        let trailingIteration = closedIterationCall
        let previousClosedBlock = closedBlock
        closedIterationCall = false
        closedBlock = nil

        switch token.kind {
        case .identifier:
            visitIdentifier(token, at: index, previousClosedBlock: previousClosedBlock)
        case .punctuation:
            visitPunctuation(token, at: index, trailingIteration: trailingIteration)
        case .number, .string:
            break
        }
    }

    private mutating func visitIdentifier(_ token: JourneyToken, at index: Int, previousClosedBlock: Block?) {
        let name = token.text
        let previous = text(at: index - 1)
        let next = text(at: index + 1)
        let isKeywordUse = previous != "#" && previous != "." && previous != "(" && previous != "," && next != ":"

        if ["for", "while", "repeat"].contains(name) && isKeywordUse {
            if name == "while" && previous == "}" && previousClosedBlock == .loop("repeat") {
                return
            }
            report(token, .noLoops, "`\(name)` loop; drive each journey step explicitly")
            pending = (.loop(name), parenDepth)
        } else if ["if", "guard", "switch", "else", "catch"].contains(name) && isKeywordUse {
            pending = (.conditional, parenDepth)
        } else if name == "class" && previous != "." {
            checkClassDeclaration(token, at: index)
        } else if name == "func" {
            visitFunctionDeclaration(token, at: index)
        } else if JourneyHouseRules.retrySwiftIdentifiers.contains(name) {
            report(token, .noRetryConfig, "`\(name)` retries or repeats tests; flaky is failing")
        } else if name == "continueAfterFailure" && next == "=" && text(at: index + 2) == "true" {
            report(token, .noSkippedJourneys, "`continueAfterFailure = true` lets a failing journey keep going")
        } else if isJourney && JourneyHouseRules.skipIdentifiers.contains(name) {
            report(token, .noSkippedJourneys, "`\(name)` skips or softens a journey")
        } else if name == "verifyAfterRelaunch" {
            markRelaunchCheck()
        } else if isJourney && isAssertion(name, next: next) {
            if stack.contains(where: { $0.block == .conditional }) || previous == "?" || previous == ":" {
                report(token, .noConditionalAssertion, "`\(name)` inside a conditional branch; assert unconditionally")
            }
        } else if next == "(" && JourneyHouseRules.journeyActions.contains(name) && isInsideIterationClosure {
            report(token, .noTapInIterationClosure, "`\(name)(` inside an iteration closure; drive each journey step explicitly")
        } else if previous != "." && JourneyHouseRules.journeyReceivers.contains(name) && isInsideIterationClosure {
            report(token, .noTapInIterationClosure, "`\(name)` used inside an iteration closure; drive each journey step explicitly")
        } else if previous == "." && (next == "{" || next == "(") && JourneyHouseRules.iterationMethods.contains(name) {
            pendingIteration = true
        } else if isJourney && previous == "." && ["element", "copy"].contains(name) && next == "(" && tokens.indices.contains(index + 2) && tokens[index + 2].kind == .string {
            report(token, .noRawQueryStrings, "`.\(name)(` with a string literal; use a JourneyID or JourneyCopy constant")
        } else if isJourney && name == "identifier" && next == ":" && tokens.indices.contains(index + 2) && tokens[index + 2].kind == .string {
            report(token, .noRawQueryStrings, "identifier query with a string literal; use a JourneyID constant")
        }
    }

    private var isInsideIterationClosure: Bool {
        stack.contains { $0.block == .iterationClosure }
    }

    /// Journeys must subclass JourneyTestCase (it stops at the first failure and sets the time limit), and
    /// test classes must not hide under Support/, where the journey-only rules do not apply.
    private mutating func checkClassDeclaration(_ token: JourneyToken, at index: Int) {
        guard text(at: index + 2) == ":", let name = text(at: index + 1), let superclass = text(at: index + 3) else {
            return
        }
        if isJourney && superclass == "XCTestCase" {
            report(token, .noSkippedJourneys, "`\(name)` subclasses XCTestCase; journeys subclass JourneyTestCase")
        } else if !isJourney && ["XCTestCase", "JourneyTestCase"].contains(superclass) && name != "JourneyTestCase" {
            report(token, .noSkippedJourneys, "test class `\(name)` in Support/ escapes the journey rules")
        }
    }

    private mutating func visitFunctionDeclaration(_ token: JourneyToken, at index: Int) {
        let name = text(at: index + 1) ?? ""
        if !isJourney && name.hasPrefix("test") {
            report(token, .noSkippedJourneys, "`\(name)` in Support/ escapes the journey rules")
        }
        guard name.hasPrefix("test") else {
            pending = (.other, parenDepth)
            let modifiers = tokens[..<index].filter { $0.line == token.line }.map(\.text)
            if isJourney && !modifiers.contains(where: JourneyHouseRules.helperExemptModifiers.contains) {
                report(token, .noSkippedJourneys, "`\(name)` is neither a test nor private; a renamed test silently stops running")
            }
            return
        }
        pending = (.testFunction(name: name, line: token.line), parenDepth)
    }

    private func isAssertion(_ name: String, next: String?) -> Bool {
        name.hasPrefix("XCTAssert") || name.hasPrefix("XCTFail") || name.hasPrefix("XCTUnwrap") ||
            (name.hasPrefix("assert") && next == "(")
    }

    /// Counts only an unconditional call: `if false { verifyAfterRelaunch … }` proves nothing.
    private mutating func markRelaunchCheck() {
        if let index = stack.lastIndex(where: { if case .testFunction = $0.block { true } else { false } }),
           !stack[index...].contains(where: { $0.block == .conditional }) {
            stack[index].callsRelaunchCheck = true
        }
    }

    private mutating func visitPunctuation(_ token: JourneyToken, at index: Int, trailingIteration: Bool) {
        switch token.text {
        case "{":
            stack.append(Frame(opener: "{", block: blockForOpeningBrace(trailingIteration: trailingIteration)))
        case "(":
            stack.append(Frame(opener: "(", block: pendingIteration ? .iterationCall : .other))
            pendingIteration = false
        case "[":
            checkRawSubscript(token, at: index)
            stack.append(Frame(opener: "[", block: .other))
        case "}", ")", "]":
            close(token)
        default:
            break
        }
    }

    private mutating func blockForOpeningBrace(trailingIteration: Bool) -> Block {
        if pendingIteration {
            pendingIteration = false
            return .iterationClosure
        }
        if let pending, pending.depth == parenDepth {
            self.pending = nil
            return pending.block
        }
        if trailingIteration || stack.last?.block == .iterationCall {
            return .iterationClosure
        }
        return .other
    }

    private mutating func checkRawSubscript(_ token: JourneyToken, at index: Int) {
        guard isJourney,
              tokens.indices.contains(index + 1),
              tokens[index + 1].kind == .string,
              index > 0 else {
            return
        }
        let previous = tokens[index - 1]
        let isSubscript = (previous.kind == .identifier && !JourneyHouseRules.nonSubscriptKeywords.contains(previous.text)) ||
            [")", "]", "?", "!"].contains(previous.text)
        if isSubscript {
            report(token, .noRawQueryStrings, "raw string query; use a JourneyID or JourneyCopy constant")
        }
    }

    private mutating func close(_ token: JourneyToken) {
        guard let frame = stack.popLast() else {
            return
        }
        closedBlock = frame.block
        closedIterationCall = token.text == ")" && frame.block == .iterationCall
        if isJourney, case .testFunction(let name, let line) = frame.block, !frame.callsRelaunchCheck {
            violations.append(JourneyRuleViolation(
                file: fileName,
                line: line,
                rule: .mutationNeedsRelaunchCheck,
                message: "`\(name)` never calls verifyAfterRelaunch; re-check the result after app.terminate() and launch()"
            ))
        }
    }

    private mutating func report(_ token: JourneyToken, _ rule: JourneyRuleID, _ message: String) {
        violations.append(JourneyRuleViolation(file: fileName, line: token.line, rule: rule, message: message))
    }
}
