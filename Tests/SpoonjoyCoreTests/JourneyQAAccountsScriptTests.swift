import Foundation
import Testing

/// Exercises scripts/journey-qa-accounts.sh against fake curl, openssl and xcrun binaries.
/// Nothing here talks to a real server.
@Suite("Journey QA accounts script")
struct JourneyQAAccountsScriptTests {
    private static let baseURL = "https://spoonjoy-v2-qa.mendelow-studio.workers.dev"

    @Test("create signs up two masked accounts and writes a private accounts file")
    func createWritesMaskedAccounts() throws {
        try withAccountsHarness { harness in
            let out = harness.root.appendingPathComponent("secrets/accounts.json")
            let result = try harness.run(["create", "--base-url", Self.baseURL + "/", "--count", "2", "--out", out.path])
            #expect(result.status == 0, Comment(rawValue: result.output))

            let accounts = try harness.accounts(at: out)
            let token = try #require(accounts.runToken)
            #expect(token.wholeMatch(of: /r4242a3xf[0-9a-f]{5}/) != nil, "unexpected token \(token)")
            #expect(accounts.entries.map(\.email) == [
                "codex-native-\(token)-1@example.com",
                "codex-native-\(token)-2@example.com"
            ])
            #expect(accounts.entries.map(\.username) == ["codex_native_\(token)_1", "codex_native_\(token)_2"])
            #expect(accounts.entries.allSatisfy { $0.password.wholeMatch(of: /f[0-9a-f]{47}/) != nil })
            #expect(Set(accounts.entries.map(\.password)).count == 2)
            let mode = try FileManager.default.attributesOfItem(atPath: out.path)[.posixPermissions] as? Int
            #expect(mode == 0o600)

            let lines = result.stdout.split(separator: "\n").map(String.init)
            for entry in accounts.entries {
                let mask = try #require(lines.firstIndex(of: "::add-mask::\(entry.password)"))
                let firstMention = try #require(lines.firstIndex { $0.contains(entry.username) || $0.contains(entry.email) })
                #expect(mask < firstMention)
            }

            let calls = harness.curlCalls()
            #expect(calls.count == 2)
            #expect(calls.allSatisfy { $0.hasSuffix("\(Self.baseURL)/signup?redirectTo=%2Frecipes") })
            for entry in accounts.entries {
                #expect(!calls.contains { $0.contains(entry.password) })
                #expect(!result.output.contains("password=\(entry.password)"))
            }
            let bodies = harness.curlBodies()
            #expect(bodies.filter { $0.hasPrefix("password=") }.map { String($0.dropFirst("password=".count)) } == accounts.entries.map(\.password))
            #expect(bodies.filter { $0.hasPrefix("confirmPassword=") }.map { String($0.dropFirst("confirmPassword=".count)) } == accounts.entries.map(\.password))
        }
    }

    @Test("create fails on a rejected, rate-limited or misdirected signup")
    func createFailsOnBadSignup() throws {
        let responses = ["400 ", "429 ", "302 \(Self.baseURL)/login"]
        for response in responses {
            try withAccountsHarness { harness in
                try harness.respond("signup", response)
                let out = harness.root.appendingPathComponent("accounts.json")
                let result = try harness.run(["create", "--base-url", Self.baseURL, "--count", "2", "--out", out.path])
                #expect(result.status != 0, Comment(rawValue: result.output))
                #expect(result.output.contains("HTTP \(response.prefix(3))"))
                #expect(try harness.accounts(at: out).entries.isEmpty)
            }
        }
    }

    @Test("create keeps earlier accounts when a later signup fails")
    func createKeepsEarlierAccounts() throws {
        try withAccountsHarness { harness in
            try harness.respondInSequence("signup", ["302 \(Self.baseURL)/recipes", "429 "])
            let out = harness.root.appendingPathComponent("accounts.json")
            let result = try harness.run(["create", "--base-url", Self.baseURL, "--count", "2", "--out", out.path])
            #expect(result.status != 0)
            #expect(try harness.accounts(at: out).entries.count == 1)
        }
    }

    @Test("create refuses to run without a run id or complete arguments")
    func createRequiresRunIDAndArguments() throws {
        try withAccountsHarness { harness in
            let out = harness.root.appendingPathComponent("accounts.json")
            let noRunID = try harness.run(
                ["create", "--base-url", Self.baseURL, "--count", "2", "--out", out.path],
                environment: ["GITHUB_RUN_ID": ""]
            )
            #expect(noRunID.status == 1)
            #expect(noRunID.output.contains("GITHUB_RUN_ID"))

            #expect(try harness.run(["create", "--base-url", Self.baseURL, "--count", "0", "--out", out.path]).status == 2)
            #expect(try harness.run(["create", "--count"]).status == 2)
            #expect(try harness.run(["create", "--unknown"]).status == 2)
            #expect(try harness.run([]).status == 2)
            #expect(try harness.run(["delete"]).status == 2)
            #expect(harness.curlCalls().isEmpty)
        }
    }

    @Test("rotate without an accounts file has nothing to do")
    func rotateWithoutAccounts() throws {
        try withAccountsHarness { harness in
            let result = try harness.run([
                "rotate", "--base-url", Self.baseURL,
                "--accounts", harness.root.appendingPathComponent("missing.json").path
            ])
            #expect(result.status == 0)
            #expect(result.stdout.contains("no journey accounts to rotate"))
            #expect(harness.curlCalls().isEmpty)
        }
    }

    @Test("rotate signs in, changes the password and proves the old one is dead")
    func rotateHappyPath() throws {
        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let before = try harness.accounts(at: file)

            let result = try harness.run(["rotate", "--base-url", Self.baseURL, "--accounts", file.path])
            #expect(result.status == 0, Comment(rawValue: result.output))
            #expect(result.stdout.contains("Rotated 2 journey account(s)"))

            let paths = harness.curlCalls().suffix(6).map { call in
                String(call.split(separator: " ").last ?? "").replacingOccurrences(of: Self.baseURL, with: "")
            }
            #expect(paths == [
                "/login", "/account/settings", "/api/v1/auth/password/native",
                "/login", "/account/settings", "/api/v1/auth/password/native"
            ])

            let rotation = Array(harness.curlBodies().drop { !$0.hasPrefix("identifier=") })
            #expect(rotation.contains("identifier=\(before.entries[0].username)"))
            #expect(rotation.contains("password=\(before.entries[0].password)"))
            #expect(rotation.contains("currentPassword=\(before.entries[0].password)"))
            let newPasswords = rotation.filter { $0.hasPrefix("newPassword=") }.map { String($0.dropFirst("newPassword=".count)) }
            #expect(newPasswords.count == 2)
            #expect(rotation.filter { $0.hasPrefix("confirmPassword=") }.map { String($0.dropFirst("confirmPassword=".count)) } == newPasswords)
            #expect(Set(newPasswords).isDisjoint(with: before.entries.map(\.password)))
            let probes = rotation.filter { $0.hasPrefix("binary=") }
            #expect(probes.count == 2)
            #expect(probes[0].contains("\"emailOrUsername\":\"\(before.entries[0].username)\""))
            #expect(probes[0].contains("\"password\":\"\(before.entries[0].password)\""))

            let lines = result.stdout.split(separator: "\n").map(String.init)
            for password in newPasswords {
                #expect(lines.contains("::add-mask::\(password)"))
                #expect(!harness.anyFileContains(password, excluding: harness.bodiesLog))
            }
            for call in harness.curlCalls() {
                #expect(!newPasswords.contains { call.contains($0) })
                #expect(!before.entries.contains { call.contains($0.password) })
            }
        }
    }

    @Test("rotate fails when the old password still works, the change is not confirmed, or sign-in fails")
    func rotateFailures() throws {
        let cases: [(String, String, String)] = [
            ("api_v1_auth_password_native", "200 ", "still answered HTTP 200"),
            ("account_settings", "200 \n<p>Your current password is incorrect</p>", "did not confirm success"),
            ("account_settings", "500 ", "returned HTTP 500"),
            ("login", "200 ", "returned HTTP 200 to none instead of 302 to /recipes"),
            ("login", "302 \(Self.baseURL)/login?error=1", "returned HTTP 302 to /login?error=1 instead of 302 to /recipes"),
            ("account_settings", "302 \(Self.baseURL)/somewhere", "returned HTTP 302 to /somewhere"),
            ("account_settings", "200 \n<p>Your current password is incorrect</p>", "did not confirm success")
        ]
        for (path, response, message) in cases {
            try withAccountsHarness { harness in
                let file = try harness.createAccounts()
                try harness.respond(path, response)
                let result = try harness.run(["rotate", "--base-url", Self.baseURL, "--accounts", file.path])
                #expect(result.status == 1, Comment(rawValue: result.output))
                #expect(result.output.contains(message), Comment(rawValue: result.output))
                #expect(result.output.contains("2 journey account(s) could not be rotated"))
            }
        }
    }

    @Test("rotate works against a model of the web app, where a successful change redirects to /login")
    func rotateAgainstWebModel() throws {
        try withAccountsHarness { harness in
            let model = ["FAKE_QA_MODEL": "1"]
            let file = harness.root.appendingPathComponent("secrets/accounts.json")
            let create = try harness.run(["create", "--base-url", Self.baseURL, "--count", "2", "--out", file.path], environment: model)
            #expect(create.status == 0, Comment(rawValue: create.output))
            let before = try harness.accounts(at: file)

            let result = try harness.run(["rotate", "--base-url", Self.baseURL, "--accounts", file.path], environment: model)
            #expect(result.status == 0, Comment(rawValue: result.output))
            #expect(result.stdout.contains("Rotated journey account \(before.entries[0].username) (the settings page redirected to /login); its old password is rejected"))
            #expect(result.stdout.contains("Rotated 2 journey account(s)"))

            for entry in before.entries {
                let stored = try String(contentsOf: harness.root.appendingPathComponent("model-users/\(entry.username)/password"), encoding: .utf8)
                #expect(stored != entry.password)
                #expect(stored.wholeMatch(of: /f[0-9a-f]{47}/) != nil)
            }
            let headers = try String(contentsOf: harness.root.appendingPathComponent("curl-headers.log"), encoding: .utf8)
            #expect(headers.contains("login Origin: \(Self.baseURL)"))
            #expect(headers.contains("login Referer: \(Self.baseURL)/login"))
            #expect(headers.contains("account_settings Origin: \(Self.baseURL)"))
            #expect(headers.contains("account_settings Referer: \(Self.baseURL)/account/settings"))
        }
    }

    @Test("rotate fails when the web app does not accept the sign-in cookie, because the old password still works")
    func rotateFailsWhenSessionIsRejected() throws {
        try withAccountsHarness { harness in
            let file = harness.root.appendingPathComponent("secrets/accounts.json")
            let create = try harness.run(["create", "--base-url", Self.baseURL, "--count", "1", "--out", file.path], environment: ["FAKE_QA_MODEL": "1"])
            #expect(create.status == 0, Comment(rawValue: create.output))

            let result = try harness.run(
                ["rotate", "--base-url", Self.baseURL, "--accounts", file.path],
                environment: ["FAKE_QA_MODEL": "1", "FAKE_QA_DROP_COOKIES": "1"]
            )
            #expect(result.status == 1)
            #expect(result.output.contains("still answered HTTP 200 instead of 401 (the settings page redirected to /login, so the /login session was probably not accepted)"))
            #expect(result.output.contains("1 journey account(s) could not be rotated"))
        }
    }

    @Test("rotate fails when curl cannot reach QA")
    func rotateNetworkFailures() throws {
        for path in ["login", "account_settings", "api_v1_auth_password_native"] {
            try withAccountsHarness { harness in
                let file = try harness.createAccounts()
                try FileManager.default.removeItem(at: harness.responses.appendingPathComponent(path))
                let result = try harness.run(["rotate", "--base-url", Self.baseURL, "--accounts", file.path])
                #expect(result.status == 1)
                #expect(result.output.contains("did not complete"))
            }
        }
        try withAccountsHarness { harness in
            try FileManager.default.removeItem(at: harness.responses.appendingPathComponent("signup"))
            let out = harness.root.appendingPathComponent("accounts.json")
            let result = try harness.run(["create", "--base-url", Self.baseURL, "--count", "1", "--out", out.path])
            #expect(result.status == 1)
            #expect(result.output.contains("did not complete"))
        }
    }

    @Test("rotate requires a base URL")
    func rotateRequiresBaseURL() throws {
        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            #expect(try harness.run(["rotate", "--accounts", file.path]).status == 2)
            #expect(try harness.run(["rotate"]).status == 2)
        }
    }

    @Test("create and rotate refuse every host but the QA mirror before any network call")
    func refusesNonQAHosts() throws {
        let hosts = [
            "https://spoonjoy.app",
            "https://www.spoonjoy.app",
            "http://spoonjoy-v2-qa.mendelow-studio.workers.dev",
            "https://spoonjoy-v2-qa.mendelow-studio.workers.dev.evil.example",
            "https://spoonjoy-v2-qa.mendelow-studio.workers.dev/api",
            "http://localhost:5173"
        ]
        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let callsBefore = harness.curlCalls().count
            let out = harness.root.appendingPathComponent("refused.json")
            for host in hosts {
                let create = try harness.run(["create", "--base-url", host, "--count", "2", "--out", out.path])
                #expect(create.status == 1, Comment(rawValue: create.output))
                #expect(create.output.contains("may only be created or rotated on the QA mirror"))
                #expect(!create.stdout.contains("::add-mask::"))

                let rotate = try harness.run(["rotate", "--base-url", host, "--accounts", file.path])
                #expect(rotate.status == 1, Comment(rawValue: rotate.output))
                #expect(rotate.output.contains("refusing \(host)"))

                let missing = try harness.run([
                    "rotate", "--base-url", host,
                    "--accounts", harness.root.appendingPathComponent("missing.json").path
                ])
                #expect(missing.status == 1)
            }
            #expect(harness.curlCalls().count == callsBefore)
            #expect(!FileManager.default.fileExists(atPath: out.path))
        }
    }

    @Test("scan passes clean logs and result bundles")
    func scanPassesCleanArtifacts() throws {
        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let log = harness.root.appendingPathComponent("test.log")
            try "t = 1.0s Tap \"Paste\" MenuItem\n".write(to: log, atomically: true, encoding: .utf8)
            let bundle = try harness.makeResultBundle()

            let result = try harness.run([
                "scan", "--accounts", file.path, log.path, bundle.path,
                harness.root.appendingPathComponent("absent.log").path
            ])
            #expect(result.status == 0, Comment(rawValue: result.output))
            #expect(result.stdout.contains("Scanned \(log.path): no journey password found"))
            #expect(result.stdout.contains("Scanned \(bundle.path): no journey password found"))
            #expect(result.stdout.contains("(not present)"))
            #expect(harness.xcrunCalls().contains { $0.contains("activities --test-id test://SpoonjoyJourneys/SignInJourney/testSignInOutJourney") })
            #expect(harness.xcrunCalls().contains { $0.contains("get log --type action") })
            #expect(harness.xcrunCalls().contains { $0.contains("test-details --test-id test://SpoonjoyJourneys/SignInJourney/testSignInOutJourney") })
            #expect(harness.xcrunCalls().contains { $0.contains("export diagnostics") })
        }
    }

    @Test("scan fails when a password is in a log, a raw bundle file or the exported activities")
    func scanFindsLeaks() throws {
        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let password = try harness.accounts(at: file).entries[1].password
            let log = harness.root.appendingPathComponent("test.log")
            try "t = 1.0s Type '\(password)' into SecureTextField\n".write(to: log, atomically: true, encoding: .utf8)

            let result = try harness.run(["scan", "--accounts", file.path, log.path])
            #expect(result.status == 1)
            #expect(result.output.contains("journey account password found in \(log.path)"))
            #expect(!result.output.contains(password))
        }

        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let password = try harness.accounts(at: file).entries[0].password
            let bundle = try harness.makeResultBundle(activityText: "Type '\(password)' into \"Password\" SecureTextField")

            let result = try harness.run(["scan", "--accounts", file.path, bundle.path])
            #expect(result.status == 1)
            #expect(result.output.contains("journey account password found inside \(bundle.path)"))
            #expect(!result.output.contains(password))
        }

        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let password = try harness.accounts(at: file).entries[0].password
            let bundle = try harness.makeResultBundle()
            try password.write(to: bundle.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

            let result = try harness.run(["scan", "--accounts", file.path, bundle.path])
            #expect(result.status == 1)
            #expect(result.output.contains("journey account password found in \(bundle.path)"))
        }
    }

    @Test("scan fails closed when a result bundle cannot be exported or read")
    func scanFailsClosed() throws {
        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let bundle = try harness.makeResultBundle()
            let result = try harness.run(
                ["scan", "--accounts", file.path, bundle.path],
                environment: ["FAKE_XCRUN_FAIL": "1"]
            )
            #expect(result.status == 1)
            #expect(result.output.contains("could not export"))
        }

        try withAccountsHarness { harness in
            let file = try harness.createAccounts()
            let unreadable = harness.root.appendingPathComponent("unreadable.log")
            try "log".write(to: unreadable, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadable.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: unreadable.path) }

            let result = try harness.run(["scan", "--accounts", file.path, unreadable.path])
            #expect(result.status == 1)
            #expect(result.output.contains("could not read"))
        }
    }

    @Test("scan has nothing to check without accounts or passwords")
    func scanWithoutAccounts() throws {
        try withAccountsHarness { harness in
            let log = harness.root.appendingPathComponent("test.log")
            try "clean".write(to: log, atomically: true, encoding: .utf8)
            let missing = try harness.run(["scan", "--accounts", harness.root.appendingPathComponent("missing.json").path, log.path])
            #expect(missing.status == 0)
            #expect(missing.stdout.contains("no journey accounts to scan for"))

            let empty = harness.root.appendingPathComponent("empty.json")
            try #"{"runToken":"r1a1xf00001","accounts":[]}"#.write(to: empty, atomically: true, encoding: .utf8)
            let none = try harness.run(["scan", "--accounts", empty.path, log.path])
            #expect(none.status == 0)
            #expect(none.stdout.contains("no journey passwords to scan for"))

            #expect(try harness.run(["scan", "--accounts", empty.path]).status == 2)
        }
    }
}

private struct AccountsFile {
    struct Entry {
        let email: String
        let username: String
        let password: String
    }

    let runToken: String?
    let entries: [Entry]
}

private struct ScriptResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var output: String {
        stdout + stderr
    }
}

private struct AccountsHarness {
    let root: URL
    let bin: URL
    let responses: URL
    let temp: URL

    var curlLog: URL { root.appendingPathComponent("curl-calls.log") }
    var bodiesLog: URL { root.appendingPathComponent("curl-bodies.log") }
    var xcrunLog: URL { root.appendingPathComponent("xcrun-calls.log") }

    func run(_ arguments: [String], environment overrides: [String: String] = [:]) throws -> ScriptResult {
        let script = accountsRepoRoot().appendingPathComponent("scripts/journey-qa-accounts.sh")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(bin.path):\(environment["PATH"] ?? "/usr/bin:/bin")"
        environment["TMPDIR"] = temp.path
        environment["GITHUB_RUN_ID"] = "4242"
        environment["GITHUB_RUN_ATTEMPT"] = "3"
        environment["FAKE_STATE"] = root.path
        environment["FAKE_CURL_RESPONSES"] = responses.path
        environment.merge(overrides) { _, new in new }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        process.environment = environment
        let stdoutURL = root.appendingPathComponent("stdout-\(UUID().uuidString)")
        let stderrURL = root.appendingPathComponent("stderr-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        try process.run()
        process.waitUntilExit()
        try stdoutHandle.close()
        try stderrHandle.close()
        defer {
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
        }
        return ScriptResult(
            status: process.terminationStatus,
            stdout: try String(contentsOf: stdoutURL, encoding: .utf8),
            stderr: try String(contentsOf: stderrURL, encoding: .utf8)
        )
    }

    func createAccounts() throws -> URL {
        let out = root.appendingPathComponent("secrets/accounts.json")
        let result = try run(["create", "--base-url", "https://spoonjoy-v2-qa.mendelow-studio.workers.dev", "--count", "2", "--out", out.path])
        guard result.status == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: result.output])
        }
        return out
    }

    func respond(_ path: String, _ response: String) throws {
        try response.write(to: responses.appendingPathComponent(path), atomically: true, encoding: .utf8)
    }

    func respondInSequence(_ path: String, _ sequence: [String]) throws {
        try sequence.enumerated().forEach { index, response in
            try response.write(to: responses.appendingPathComponent("\(path).\(index + 1)"), atomically: true, encoding: .utf8)
        }
        try FileManager.default.removeItem(at: responses.appendingPathComponent(path))
    }

    func accounts(at url: URL) throws -> AccountsFile {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
        let entries = (object["accounts"] as? [[String: String]] ?? []).map { entry in
            AccountsFile.Entry(email: entry["email"] ?? "", username: entry["username"] ?? "", password: entry["password"] ?? "")
        }
        return AccountsFile(runToken: object["runToken"] as? String, entries: entries)
    }

    func curlCalls() -> [String] {
        lines(of: curlLog)
    }

    func curlBodies() -> [String] {
        lines(of: bodiesLog)
    }

    func xcrunCalls() -> [String] {
        lines(of: xcrunLog)
    }

    func anyFileContains(_ text: String, excluding excluded: URL) -> Bool {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        let files = (enumerator?.allObjects as? [URL] ?? []).filter { $0.standardizedFileURL != excluded.standardizedFileURL }
        return files.contains { url in
            (try? String(contentsOf: url, encoding: .utf8))?.contains(text) == true
        }
    }

    func makeResultBundle(activityText: String = "Tap \"Paste\" MenuItem") throws -> URL {
        let bundle = root.appendingPathComponent("SpoonjoyJourneys.xcresult", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle.appendingPathComponent("Data"), withIntermediateDirectories: true)
        try "<plist/>".write(to: bundle.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        try Data([0x28, 0xB5, 0x2F, 0xFD]).write(to: bundle.appendingPathComponent("Data/data.0~compressed"))
        try activityText.write(to: root.appendingPathComponent("fake-activities.txt"), atomically: true, encoding: .utf8)
        return bundle
    }

    private func lines(of url: URL) -> [String] {
        ((try? String(contentsOf: url, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }
}

private func withAccountsHarness(_ body: (AccountsHarness) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("spoonjoy-journey-accounts-\(UUID().uuidString)", isDirectory: true)
    let bin = root.appendingPathComponent("bin", isDirectory: true)
    let responses = root.appendingPathComponent("responses", isDirectory: true)
    let temp = root.appendingPathComponent("tmp", isDirectory: true)
    try [bin, responses, temp].forEach { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true) }
    defer { try? FileManager.default.removeItem(at: root) }

    let harness = AccountsHarness(root: root, bin: bin, responses: responses, temp: temp)
    try writeExecutable(fakeCurlSource, to: bin.appendingPathComponent("curl"))
    try writeExecutable(fakeOpenSSLSource, to: bin.appendingPathComponent("openssl"))
    try writeExecutable(fakeXcrunSource, to: bin.appendingPathComponent("xcrun"))
    try harness.respond("signup", "302 https://spoonjoy-v2-qa.mendelow-studio.workers.dev/recipes")
    try harness.respond("login", "302 https://spoonjoy-v2-qa.mendelow-studio.workers.dev/recipes")
    try harness.respond(
        "account_settings",
        "200 \n<html><body><p>Your password has been changed successfully. Other browsers signed in to your account have been signed out.</p></body></html>"
    )
    try harness.respond("api_v1_auth_password_native", "401 ")
    try body(harness)
}

private func writeExecutable(_ source: String, to url: URL) throws {
    try source.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

private func accountsRepoRoot() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

/// Logs argv, records form fields read from @files, and answers from responses/<path> (first line is the
/// "-w" output, the rest is the body). A numbered responses/<path>.N file answers the Nth call instead.
/// Logs argv, records form fields read from @files and request headers, and answers either from
/// responses/<path> (first line is the "-w" output, the rest is the body; responses/<path>.N answers the
/// Nth call) or, with FAKE_QA_MODEL=1, from a small model of the web app's real behaviour.
private let fakeCurlSource = #"""
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_STATE/curl-calls.log"
args=("$@")
output=""
jar_in=""
jar_out=""
request="$(mktemp -d "$FAKE_STATE/request.XXXXXX")"
trap 'rm -rf "$request"' EXIT
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o) output="${args[$((i + 1))]}" ;;
    -b) jar_in="${args[$((i + 1))]}" ;;
    -c) jar_out="${args[$((i + 1))]}" ;;
    -H) printf '%s\n' "${args[$((i + 1))]}" >> "$request/headers" ;;
    --data-urlencode)
      field="${args[$((i + 1))]}"
      # curl reads name@file only when no '=' comes first; name=value otherwise.
      if [[ "${field%%=*}" == *@* ]]; then
        value="$(cat "${field#*@}")"
        printf '%s=%s\n' "${field%%@*}" "$value" >> "$FAKE_STATE/curl-bodies.log"
        printf '%s' "$value" > "$request/field-${field%%@*}"
      else
        printf '%s\n' "$field" >> "$FAKE_STATE/curl-bodies.log"
        printf '%s' "${field#*=}" > "$request/field-${field%%=*}"
      fi
      ;;
    --data-binary)
      printf 'binary=%s\n' "$(tr -d '\n' < "${args[$((i + 1))]#@}")" >> "$FAKE_STATE/curl-bodies.log"
      cp "${args[$((i + 1))]#@}" "$request/json"
      ;;
  esac
done
url="${args[${#args[@]}-1]}"
origin="$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+).*#\1#')"
path="${url#*://*/}"
path="${path%%\?*}"
name="${path//\//_}"
if [[ -f "$request/headers" ]]; then
  sed "s#^#$name #" "$request/headers" >> "$FAKE_STATE/curl-headers.log"
fi
counter_file="$FAKE_STATE/curl-count-$name"
count=$(( $(cat "$counter_file" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$counter_file"

field() { cat "$request/field-$1" 2>/dev/null || true; }
users="$FAKE_STATE/model-users"
user_for() {
  local id="$1"
  if [[ -d "$users/$id" ]]; then printf '%s' "$id"; return; fi
  grep -l -x -F "$id" "$users"/*/email 2>/dev/null | head -n 1 | xargs -n 1 dirname 2>/dev/null | xargs -n 1 basename 2>/dev/null || true
}
bounce="302 $origin/login?redirectTo=%2Faccount%2Fsettings"

if [[ -n "${FAKE_QA_MODEL:-}" ]]; then
  response="$request/response"
  mkdir -p "$users"
  case "$name" in
    signup)
      user="$users/$(field username)"
      mkdir -p "$user"
      field email > "$user/email"
      field password > "$user/password"
      echo 0 > "$user/version"
      echo "302 $origin/recipes" > "$response"
      ;;
    login)
      user="$(user_for "$(field identifier)")"
      if [[ -n "$user" && "$(field password)" == "$(cat "$users/$user/password")" ]]; then
        if [[ -z "${FAKE_QA_DROP_COOKIES:-}" ]]; then
          printf '#HttpOnly_%s\tFALSE\t/\tTRUE\t0\t__session\t%s.%s\n' "${origin#https://}" "$user" "$(cat "$users/$user/version")" > "$jar_out"
        fi
        echo "302 $origin/recipes" > "$response"
      else
        printf '401 \n<p>Invalid username, email, or password</p>\n' > "$response"
      fi
      ;;
    account_settings)
      cookie="$(awk -F '\t' '$6 == "__session" { print $7 }' "$jar_in" 2>/dev/null || true)"
      user="${cookie%.*}"
      if [[ -z "$cookie" || ! -d "$users/$user" || "${cookie##*.}" != "$(cat "$users/$user/version")" ]]; then
        echo "$bounce" > "$response"
      elif [[ "$(field intent)" != "changePassword" || "$(field currentPassword)" != "$(cat "$users/$user/password")" ]]; then
        printf '200 \n<p>Your current password is incorrect</p>\n' > "$response"
      elif [[ "$(field newPassword)" != "$(field confirmPassword)" ]]; then
        printf '200 \n<p>Passwords do not match</p>\n' > "$response"
      else
        field newPassword > "$users/$user/password"
        echo $(( $(cat "$users/$user/version") + 1 )) > "$users/$user/version"
        # The action succeeds, then the document render reloads the page with the pre-change cookie,
        # whose session version is now stale, so the settings loader redirects to /login.
        echo "$bounce" > "$response"
      fi
      ;;
    api_v1_auth_password_native)
      user="$(user_for "$(jq -r '.emailOrUsername' "$request/json")")"
      if [[ -n "$user" && "$(jq -r '.password' "$request/json")" == "$(cat "$users/$user/password")" ]]; then
        printf '200 \n{"access_token":"a","refresh_token":"r","token_type":"Bearer","expires_in":1,"scope":"s"}\n' > "$response"
      else
        printf '401 \n{"ok":false}\n' > "$response"
      fi
      ;;
    *) echo "404 " > "$response" ;;
  esac
else
  response="$FAKE_CURL_RESPONSES/$name"
  if [[ -f "$response.$count" ]]; then
    response="$response.$count"
  fi
fi
if [[ ! -f "$response" ]]; then
  echo "curl: (7) Failed to connect" >&2
  exit 7
fi
if [[ -n "$output" && "$output" != /dev/null ]]; then
  tail -n +2 "$response" > "$output"
fi
head -n 1 "$response" | tr -d '\n'
"""#

private let fakeOpenSSLSource = #"""
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "rand" && "$2" == "-hex" ]] || exit 64
counter_file="$FAKE_STATE/openssl-count"
count=$(( $(cat "$counter_file" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$counter_file"
length=$(( $3 * 2 - 1 ))
printf "f%0${length}x\n" "$count"
"""#

private let fakeXcrunSource = #"""
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_STATE/xcrun-calls.log"
[[ -z "${FAKE_XCRUN_FAIL:-}" ]] || exit 1
[[ "$1" == "xcresulttool" ]] || exit 64
shift
case "$1 $2" in
  "get content-availability")
    echo '{"hasCoverage":false,"hasDiagnostics":true,"hasTestResults":true,"logs":["action","console"]}'
    ;;
  "get log")
    echo '{"type":"action","title":"Test"}'
    ;;
  "get test-results")
    case "$3" in
      summary) echo '{"title":"Journeys","result":"Passed"}' ;;
      tests) echo '{"testNodes":[{"nodeType":"UI test bundle","name":"SpoonjoyJourneys","children":[{"nodeType":"Test Case","name":"testSignInOutJourney()","nodeIdentifierURL":"test://SpoonjoyJourneys/SignInJourney/testSignInOutJourney"}]}]}' ;;
      activities) cat "$FAKE_STATE/fake-activities.txt" ;;
      test-details) echo '{"testName":"testSignInOutJourney()","result":"Passed"}' ;;
      *) exit 64 ;;
    esac
    ;;
  "export attachments"|"export diagnostics")
    output=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--output-path" ]]; then output="$2"; fi
      shift
    done
    echo "exported" > "$output/manifest.json"
    ;;
  *) exit 64 ;;
esac
"""#
