import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Journey house rules")
struct JourneyHouseRulesTests {
    @Test("file kinds come from the path inside the journeys directory")
    func fileKinds() {
        #expect(JourneyHouseRules.kind(forRelativePath: "SignInJourney.swift") == .journey)
        #expect(JourneyHouseRules.kind(forRelativePath: "Support/JourneyApp.swift") == .support)
        #expect(JourneyHouseRules.kind(forRelativePath: "journeys.yml") == .workflow)
        #expect(JourneyHouseRules.kind(forRelativePath: "native.yaml") == .workflow)
        #expect(JourneyHouseRules.kind(forRelativePath: "journey-qa-accounts.sh") == .workflow)
        #expect(JourneyHouseRules.kind(forRelativePath: "README.md") == nil)
        #expect(JourneyHouseRules.kind(forRelativePath: "Support") == nil)
    }

    @Test("a clean journey has no violations")
    func cleanJourney() {
        let source = """
        import XCTest

        @MainActor
        final class SignInJourney: JourneyTestCase {
            func testSignIn() throws {
                let journey = JourneyApp.launchFresh()
                let account = try JourneyAccounts.account(1)
                journey.signIn(as: account.username, password: account.password)
                XCTAssertTrue(journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: 30))
                XCTAssertEqual(journey.copy(JourneyCopy.signOutConfirm).label, JourneyCopy.signOutConfirm)
                journey.element(JourneyID.shellMore).tap()
                XCTAssertTrue(journey.app.wait(for: .runningForeground, timeout: 10))
                let ids = [JourneyID.kitchenRoot, JourneyID.shellMore]
                XCTAssertEqual(ids.map { $0.count }.count, 2)
                verifyAfterRelaunch(journey) {
                    XCTAssertTrue(journey.element(JourneyID.kitchenRoot).exists)
                }
            }

            private func helper(for id: String, _ value: Int, while flag: Bool) -> String {
                id
            }
        }
        """

        #expect(violations(source).isEmpty)
    }

    @Test("loops are reported in journeys and support files with their lines")
    func loopsAreReported() {
        let journey = """
        func testX() {
            for item in items {
                print(item)
            }
            while ready {
                wait()
            }
            repeat {
                wait()
            } while ready
            verifyAfterRelaunch(journey) {}
        }
        """
        #expect(violations(journey).map(\.line) == [2, 5, 8])
        #expect(violations(journey).allSatisfy { $0.rule == .noLoops })

        let support = "enum JourneyApp {\n    static func go() {\n        for _ in 0..<3 {}\n    }\n}\n"
        let supportViolations = JourneyHouseRules.check(fileName: "Support/JourneyApp.swift", source: support, kind: .support)
        #expect(supportViolations == [
            JourneyRuleViolation(
                file: "Support/JourneyApp.swift",
                line: 3,
                rule: .noLoops,
                message: "`for` loop; drive each journey step explicitly"
            )
        ])
    }

    @Test("loop words in comments, strings, raw strings and labels are not loops")
    func loopWordsOutsideCodeAreIgnored() {
        let source = ##"""
        // for item in items
        /* while outer /* for nested */ repeat */
        func testX() {
            let a = "for x in y \(value("while")) \" repeat"
            let b = """
            for line in lines
            while true
            """
            let c = #"for "raw" while"#
            let d = ##"repeat "# still raw"##
            let e = #"""
            for inside raw multi-line
            """#
            element.wait(for: .runningForeground, timeout: 1)
            call(x, for: y)
            #if DEBUG
            #endif
            let f = "unterminated
            verifyAfterRelaunch(journey) {}
        }
        """##

        #expect(violations(source).isEmpty)
    }

    @Test("line numbers stay correct after multi-line strings and block comments")
    func lineNumbersSurviveMultilineTokens() {
        let source = #"""
        /*
         comment
         */
        func testX() {
            let text = """
            one
            two
            """
            for x in text {}
            verifyAfterRelaunch(journey) {}
        }
        """#

        #expect(violations(source).map(\.line) == [9])
    }

    @Test("interactions inside iteration closures are reported")
    func tapsInIterationClosures() {
        let source = """
        func testX() {
            app.buttons.allElementsBoundByIndex.forEach { $0.tap() }
            items.map { e in e.typeText("a") }
            items.compactMap { $0.swipeUp() }
            items.reduce(0) { $1.press(forDuration: 1); return $0 }
            items.first(where: { $0.doubleTap(); return true })
            let labels = items.map { $0.label }
            verifyAfterRelaunch(journey) {}
        }
        """

        let found = violations(source)
        #expect(found.map(\.rule) == Array(repeating: .noTapInIterationClosure, count: 5))
        #expect(found.map(\.line) == [2, 3, 4, 5, 6])

        let support = "func go() { items.forEach { $0.click() } }"
        #expect(JourneyHouseRules.check(fileName: "Support/A.swift", source: support, kind: .support).map(\.rule) == [.noTapInIterationClosure])
    }

    @Test("assertions inside branches are reported in journeys only")
    func conditionalAssertions() {
        let source = """
        func testX() {
            if ready {
                XCTAssertTrue(ready)
            } else {
                XCTFail("not ready")
            }
            guard ready else {
                XCTAssertTrue(ready)
                return
            }
            switch state {
            case .ready:
                XCTAssertEqual(state, .ready)
            default:
                break
            }
            if items.contains(where: { $0 == 1 }) {
                journey.assertQAEnvironment()
            }
            XCTAssertTrue(ready)
            let value = try XCTUnwrap(optional)
            journey.assertQAEnvironment()
            verifyAfterRelaunch(journey) {}
        }
        """

        let found = violations(source)
        #expect(found.map(\.rule) == Array(repeating: .noConditionalAssertion, count: 5))
        #expect(found.map(\.line) == [3, 5, 8, 13, 18])

        let support = "func go() { if ready { XCTAssertTrue(ready) } }"
        #expect(JourneyHouseRules.check(fileName: "Support/A.swift", source: support, kind: .support).isEmpty)
    }

    @Test("skipped, softened and hidden journeys are reported")
    func skippedJourneys() {
        let source = """
        final class J: JourneyTestCase {
            func testA() throws {
                try XCTSkipIf(true)
                try XCTSkipUnless(false)
                throw XCTSkip("later")
                XCTExpectFailure("flaky")
                continueAfterFailure = true
                verifyAfterRelaunch(journey) {}
            }

            func disabled_testB() {}
            private func helper() {}
            fileprivate func other() {}
            override func setUp() {}
        }
        """

        let found = violations(source)
        #expect(found.map(\.rule) == Array(repeating: .noSkippedJourneys, count: 6))
        #expect(found.map(\.line) == [3, 4, 5, 6, 7, 11])
        #expect(found.last?.message == "`disabled_testB` is neither a test nor private; a renamed test silently stops running")
    }

    @Test("continueAfterFailure = true is reported in support files too")
    func continueAfterFailureInSupport() {
        let support = "class JourneyTestCase { func setUp() { continueAfterFailure = true; continueAfterFailure = false } }"
        #expect(JourneyHouseRules.check(fileName: "Support/A.swift", source: support, kind: .support).map(\.rule) == [.noSkippedJourneys])
    }

    @Test("every journey test must re-check after a relaunch")
    func relaunchCheckIsRequired() {
        let missing = "func testA() {\n    tapSomething()\n}\n"
        #expect(violations(missing) == [
            JourneyRuleViolation(
                file: "SignInJourney.swift",
                line: 1,
                rule: .mutationNeedsRelaunchCheck,
                message: "`testA` never calls verifyAfterRelaunch; re-check the result after app.terminate() and launch()"
            )
        ])

        let present = "func testA() async throws {\n    verifyAfterRelaunch(journey) { XCTAssertTrue(ok) }\n}\n"
        #expect(violations(present).isEmpty)

        let support = "func testLooksLikeATest() {}"
        #expect(JourneyHouseRules.check(fileName: "Support/A.swift", source: support, kind: .support).map(\.rule) == [.noSkippedJourneys])
    }

    @Test("raw string queries are reported in journeys only")
    func rawStringQueries() {
        let source = """
        func testA() {
            app.buttons["Sign in"].tap()
            app.cells.element(boundBy: 0)["Row"].tap()
            app.staticTexts.matching(identifier: "kitchen.root").firstMatch.tap()
            journey.element("kitchen.root").tap()
            journey.copy("My Recipes").tap()
            journey.element(JourneyID.kitchenRoot).tap()
            journey.copy(JourneyCopy.myRecipesTab).tap()
            let names = ["a", "b"]
            XCTAssertEqual(names, ["a", "b"])
            for name in ["a"] {}
            verifyAfterRelaunch(journey) {}
        }
        """

        let found = violations(source).filter { $0.rule == .noRawQueryStrings }
        #expect(found.map(\.line) == [2, 3, 4, 5, 6])

        let support = "func go() { app.buttons[\"Paste\"].tap() }"
        #expect(JourneyHouseRules.check(fileName: "Support/A.swift", source: support, kind: .support).isEmpty)
    }

    @Test("retry configuration is reported in workflows and Swift")
    func retryConfiguration() {
        let workflow = """
        jobs:
          journeys:
            steps:
              # -retry-tests-on-failure is banned
              - run: xcodebuild test -retry-tests-on-failure
              - run: xcodebuild test -test-iterations 3
              - run: xcodebuild test -run-tests-until-failure
              - run: xcodebuild test -test-iterations 2 -test-repetition-relaunch-enabled YES
        """
        let workflowViolations = JourneyHouseRules.check(fileName: "journeys.yml", source: workflow, kind: .workflow)
        #expect(workflowViolations.map(\.line) == [5, 6, 7, 8, 8])
        #expect(workflowViolations.allSatisfy { $0.rule == .noRetryConfig })
        #expect(workflowViolations.first?.formatted == "journeys.yml:5 no-retry-config `-retry-tests-on-failure` retries or repeats tests; flaky is failing")

        let swift = "func go() {\n    options.retryOnFailure = true\n    plan.testRepetitionMode = .retryOnFailure\n}\n"
        let swiftViolations = JourneyHouseRules.check(fileName: "Support/A.swift", source: swift, kind: .support)
        #expect(swiftViolations.map(\.line) == [2, 3, 3])
        #expect(swiftViolations.allSatisfy { $0.rule == .noRetryConfig })
    }

    @Test("workflow retries, soft failures and partial test selection are reported (reviewer probes)")
    func workflowRetryAndSkipProbes() {
        let workflow = """
        jobs:
          j:
            steps:
              - run: |
                  for attempt in 1 2 3; do xcodebuild test-without-building -only-testing:SpoonjoyJourneys && break; done
              - run: xcodebuild test-without-building || xcodebuild test-without-building
              - name: soft
                continue-on-error: true
                run: xcodebuild test -skip-testing:SpoonjoyJourneys/SignInJourney
              - run: xcodebuild test -only-testing:SpoonjoyJourneys/SignInJourney
              - uses: nick-fields/retry@0000000000000000000000000000000000000000
                with:
                  max_attempts: 3
              - run: retry 3 scripts/run-journeys.sh
              - run: |
                  until scripts/run-journeys.sh; do
                    sleep 5
                  done
              - run: scripts/run-journeys.sh || scripts/run-journeys.sh
              - run: xcodebuild test -skip-test-configuration Slow
              - run: |
                  while ! bash scripts/run.sh; do
                    sleep 1
                  done
              - continue-on-error: ${{ true }}
        """
        let found = JourneyHouseRules.check(fileName: "journeys.yml", source: workflow, kind: .workflow)
        #expect(found.map(\.line) == [5, 6, 8, 9, 10, 11, 13, 14, 16, 19, 20, 22, 25])
        #expect(found.map(\.rule) == [
            .noRetryConfig, .noRetryConfig, .noSkippedJourneys, .noSkippedJourneys, .noSkippedJourneys,
            .noRetryConfig, .noRetryConfig, .noRetryConfig, .noRetryConfig, .noRetryConfig,
            .noSkippedJourneys, .noRetryConfig, .noSkippedJourneys
        ])
        #expect(found.first?.message == "a shell loop re-runs `xcodebuild`; flaky is failing")
        #expect(found.dropFirst(4).first?.message == "`-only-testing:SpoonjoyJourneys/SignInJourney` runs part of a target; select SpoonjoyJourneys or SpoonjoyShoppingUITests whole")
        #expect(found.dropFirst(8).first?.message == "a shell loop re-runs `scripts/run-journeys.sh`; flaky is failing")
    }

    @Test("retries hidden in conditions, subshells and bash -c, soft failures and set +e are reported (round-2 probes)")
    func hiddenRetryAndSoftFailureProbes() {
        let workflow = """
        jobs:
          j:
            steps:
              - run: |
                  for attempt in 1 2; do
                    if xcodebuild test-without-building -only-testing:SpoonjoyJourneys; then break; fi
                  done
              - run: for i in 1 2; do ( xcodebuild test-without-building ) && break; done
              - run: |
                  while true; do
                    bash -c "xcodebuild test-without-building" && break
                  done
              - run: xcodebuild test-without-building 2>&1 | tee log || true
              - run: xcodebuild test-without-building || echo "flaky"
              - run: scripts/run-journeys.sh || :
              - run: |
                  set +e
                  xcodebuild test-without-building
              - run: set +o errexit
              - run: xcodebuild test -only-testing:SpoonjoyJourneys; echo done
        """
        let found = JourneyHouseRules.check(fileName: "journeys.yml", source: workflow, kind: .workflow)
        #expect(found.map(\.line) == [5, 8, 10, 13, 14, 15, 17, 19])
        #expect(found.map(\.rule) == [
            .noRetryConfig, .noRetryConfig, .noRetryConfig,
            .noSkippedJourneys, .noSkippedJourneys, .noSkippedJourneys, .noSkippedJourneys, .noSkippedJourneys
        ])
        #expect(found.dropFirst(3).first?.message == "`||` on a line that runs tests hides their failure")
        #expect(found.dropFirst(6).first?.message == "`set +e` lets a failing journey command pass")
    }

    @Test("ordinary workflow and script shell is not mistaken for a retry or skip")
    func cleanShellIsAccepted() {
        let workflow = #"""
        jobs:
          journeys:
            steps:
              - uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6
                continue-on-error: false
              - run: |
                  set -euo pipefail
                  printf '%s\n' "$settings" | grep -Eq 'DEBUG( |$)' \
                    || { echo "::error::no DEBUG; stop"; exit 1; }
                  xcodebuild build-for-testing -destination "$d" -only-testing:SpoonjoyJourneys \
                    -only-testing:"SpoonjoyShoppingUITests" CODE_SIGNING_ALLOWED=NO
                  [[ -n "$a" ]] || [[ -n "$b" ]] || fail "missing"
                  n="${#items[@]}" # a comment mentioning xcodebuild || xcodebuild
                  for account in 1 2; do
                    echo "Created journey account $account"
                    rotate_account "$account" || failures=$((failures + 1))
                  done
                  while IFS= read -r test_id; do
                    xcrun xcresulttool get test-results activities --test-id "$test_id"
                  done <<< "$ids"
                  scripts/journey-qa-accounts.sh rotate --base-url "$QA"
                  set -x
                  xcodebuild test -only-testing:SpoonjoyJourneys;
        """#
        #expect(JourneyHouseRules.check(fileName: "journeys.yml", source: workflow, kind: .workflow).isEmpty)
    }

    @Test("a loop inside a script that re-runs a journey script is reported once")
    func scriptLoopReportedOnce() {
        let script = "for ((n = 1; n <= 3; n++)); do\n  echo try\n  bash scripts/journeys.sh\n  xcodebuild test\ndone\ndone\n"
        let found = JourneyHouseRules.check(fileName: "scripts/run.sh", source: script, kind: .workflow)
        #expect(found.map(\.line) == [1])
        #expect(found.first?.message == "a shell loop re-runs `scripts/journeys.sh`; flaky is failing")
    }

    @Test("journey actions inside iteration closures are reported, qualified or not (reviewer probes)")
    func journeyActionsInIterationClosures() {
        let journey = """
        func testA() {
            (1...3).forEach { _ in journey.signIn(as: "a", password: "b") }
            ids.map { app.buttons[$0] }
            ids.forEach { id in relaunch() }
            verifyAfterRelaunch(journey) {}
        }
        """
        let found = violations(journey)
        #expect(found.map(\.line) == [2, 2, 3, 4])
        #expect(found.allSatisfy { $0.rule == .noTapInIterationClosure })

        let support = "extension JourneyApp {\n    func tapAll(_ ids: [String]) {\n        ids.forEach { tap($0) }\n        ids.map { typeText($0) }\n        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }\n    }\n}\n"
        let supportFound = JourneyHouseRules.check(fileName: "Support/Helpers.swift", source: support, kind: .support)
        #expect(supportFound.map(\.line) == [3, 4])
        #expect(supportFound.first?.message == "`tap(` inside an iteration closure; drive each journey step explicitly")
    }

    @Test("ternary, catch and optional-try assertions are conditional; a conditional relaunch check does not count")
    func conditionalAssertionEdges() {
        let journey = """
        func testA() {
            ready ? XCTAssertTrue(a) : XCTFail("no")
            do {
                try start()
            } catch {
                XCTAssertTrue(false)
            }
            let value = try? XCTUnwrap(optional)
            if false {
                verifyAfterRelaunch(journey) {}
            }
        }
        """
        let found = violations(journey)
        #expect(found.map(\.line) == [2, 2, 6, 8, 1])
        #expect(found.last?.rule == .mutationNeedsRelaunchCheck)
    }

    @Test("journeys subclass JourneyTestCase and test classes do not hide in Support")
    func testClassPlacement() {
        let journey = "final class RawJourney: XCTestCase {\n    func testA() { verifyAfterRelaunch(journey) {} }\n}\nclass Plain {}\nclass Generic<T>: XCTestCase {}\n"
        #expect(violations(journey).map(\.line) == [1])
        #expect(violations(journey).first?.message == "`RawJourney` subclasses XCTestCase; journeys subclass JourneyTestCase")

        let support = "class JourneyTestCase: XCTestCase {}\nclass Hidden: JourneyTestCase {}\nclass Other: XCTestCase {}\nclass Helper: NSObject {}\nlet kind = type.class\n"
        let found = JourneyHouseRules.check(fileName: "Support/A.swift", source: support, kind: .support)
        #expect(found.map(\.line) == [2, 3])
        #expect(found.first?.message == "test class `Hidden` in Support/ escapes the journey rules")
    }

    @Test("rule identifiers are stable")
    func ruleIdentifiers() {
        #expect(JourneyRuleID.allCases.map(\.rawValue) == [
            "no-retry-config",
            "no-loops",
            "no-tap-in-iteration-closure",
            "no-assertion-in-condition",
            "no-skipped-journeys",
            "mutation-needs-relaunch-check",
            "no-raw-query-strings"
        ])
        #expect(JourneyFileKind.journey.rawValue == "journey")
    }

    @Test("unbalanced closers and a trailing subscript do not crash the scanner")
    func unbalancedSource() {
        #expect(violations("} ) ] [").isEmpty)
        #expect(violations("[\"a\"]").isEmpty)
        #expect(violations("func").map(\.rule) == [.noSkippedJourneys])
        #expect(violations("let text = \"\"\"\nfor x in y").isEmpty)
    }

    @Test("a relaunch check inside a nested block still counts for its test")
    func nestedRelaunchCheckCounts() {
        let source = "func testA() {\n    journey.run {\n        verifyAfterRelaunch(journey) {}\n    }\n}\n"
        #expect(violations(source).isEmpty)
    }

    @Test("the command reports usage without arguments")
    func commandUsage() {
        var errors: [String] = []
        let status = JourneyHouseRulesCommand.run(
            arguments: [],
            listFiles: { _ in [] },
            readFile: { _ in "" },
            output: { _ in },
            error: { errors.append($0) }
        )
        #expect(status == 1)
        #expect(errors == [JourneyHouseRulesCommand.usage])
    }

    @Test("the command fails when the journeys directory cannot be read")
    func commandUnreadableDirectory() {
        var errors: [String] = []
        let status = JourneyHouseRulesCommand.run(
            arguments: ["Apps/Spoonjoy/Journeys"],
            listFiles: { _ in throw CocoaError(.fileReadNoSuchFile) },
            readFile: { _ in "" },
            output: { _ in },
            error: { errors.append($0) }
        )
        #expect(status == 1)
        #expect(errors.count == 1)
        #expect(errors.first?.hasPrefix("SpoonjoyJourneyRules could not read the journeys:") == true)
    }

    @Test("the command prints each violation and a summary")
    func commandReportsViolations() {
        let directory = URL(fileURLWithPath: "/repo/Apps/Spoonjoy/Journeys", isDirectory: true)
        let sources = [
            "/repo/Apps/Spoonjoy/Journeys/SignInJourney.swift": "func testA() {\n    for x in y {}\n}\n",
            "/repo/Apps/Spoonjoy/Journeys/Support/JourneyApp.swift": "enum JourneyApp {}\n",
            "/elsewhere/Stray.swift": "enum Stray {}\n",
            "/repo/.github/workflows/journeys.yml": "run: xcodebuild -retry-tests-on-failure\n"
        ]
        var lines: [String] = []
        let status = JourneyHouseRulesCommand.run(
            arguments: ["/repo/Apps/Spoonjoy/Journeys", "/repo/.github/workflows/journeys.yml"],
            listFiles: { _ in
                [
                    directory.appendingPathComponent("SignInJourney.swift"),
                    directory.appendingPathComponent("Support/JourneyApp.swift"),
                    directory.appendingPathComponent("README.md"),
                    URL(fileURLWithPath: "/elsewhere/Stray.swift")
                ]
            },
            readFile: { url in sources[url.path] ?? "" },
            output: { lines.append($0) },
            error: { _ in }
        )

        #expect(status == 1)
        #expect(lines == [
            "/repo/Apps/Spoonjoy/Journeys/SignInJourney.swift:2 no-loops `for` loop; drive each journey step explicitly",
            "/repo/Apps/Spoonjoy/Journeys/SignInJourney.swift:1 mutation-needs-relaunch-check `testA` never calls verifyAfterRelaunch; re-check the result after app.terminate() and launch()",
            "/repo/.github/workflows/journeys.yml:1 no-retry-config `-retry-tests-on-failure` retries or repeats tests; flaky is failing",
            "Checked 4 journey file(s), 3 violation(s)."
        ])
    }

    @Test("the command fails when a listed file cannot be read")
    func commandUnreadableFile() {
        var errors: [String] = []
        let status = JourneyHouseRulesCommand.run(
            arguments: ["Journeys"],
            listFiles: { directory in [directory.appendingPathComponent("SignInJourney.swift")] },
            readFile: { _ in throw CocoaError(.fileReadNoPermission) },
            output: { _ in },
            error: { errors.append($0) }
        )
        #expect(status == 1)
        #expect(errors.count == 1)
    }

    @Test("the file-system command passes a clean journey directory")
    func mainOverRealDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-journey-rules-\(UUID().uuidString)", isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "func testA() {\n    verifyAfterRelaunch(journey) {}\n}\n".write(
            to: root.appendingPathComponent("SignInJourney.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "enum JourneyApp {}\n".write(to: support.appendingPathComponent("JourneyApp.swift"), atomically: true, encoding: .utf8)
        let workflow = root.appendingPathComponent("journeys.yml")
        try "name: Journeys\n".write(to: workflow, atomically: true, encoding: .utf8)

        #expect(JourneyHouseRulesCommand.main(arguments: [root.path]) == 0)
        #expect(JourneyHouseRulesCommand.main(arguments: []) == 1)
        #expect(JourneyHouseRulesCommand.main(arguments: [root.appendingPathComponent("missing").path]) == 1)
    }
}

private func violations(_ source: String) -> [JourneyRuleViolation] {
    JourneyHouseRules.check(fileName: "SignInJourney.swift", source: source, kind: .journey)
}
