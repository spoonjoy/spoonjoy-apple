import Foundation
import Synchronization
import Testing
@testable import SpoonjoyCore

@Suite("MetricKit crash and hang diagnostics")
struct NativeDiagnosticsTests {
    private static let metadata = NativeTelemetryAppMetadata(
        platform: "ios",
        appVersion: "1.3",
        buildNumber: "77",
        installID: "install-abc"
    )
    private static let begin = Date(timeIntervalSince1970: 1_800_000_000)
    private static let end = Date(timeIntervalSince1970: 1_800_086_400)

    // MARK: Mapping

    @Test("a crash maps to the diagnostics body with the blamed thread's frames")
    func crashMapping() throws {
        let tree = Self.callStackTree(threads: [
            (attributed: false, frames: [Self.frame("Other", offset: 1)]),
            (attributed: true, frames: [Self.frame("Spoonjoy", uuid: "UUID-1", offset: 4096), Self.frame("libswiftCore.dylib", offset: 8192)])
        ])
        let report = NativeDiagnosticMapper.report(
            from: NativeDiagnosticInput(
                kind: .crash,
                appVersion: "1.2.2",
                buildNumber: "512",
                osVersion: "iPhone OS 27.1 (25B5)",
                deviceModel: "iPhone18,1",
                timestampBegin: Self.begin,
                timestampEnd: Self.end,
                exceptionType: 1,
                exceptionCode: "18446744073709551615",
                signal: 11,
                terminationReason: "Namespace SIGNAL, Code 11",
                callStackTree: tree
            ),
            diagnosticID: "diag-1",
            metadata: Self.metadata,
            environment: .production
        )

        #expect(report == NativeDiagnosticReport(
            kind: .crash,
            diagnosticID: "diag-1",
            installID: "install-abc",
            environment: "production",
            platform: "ios",
            appVersion: "1.2.2",
            buildNumber: "512",
            osVersion: "iPhone OS 27.1 (25B5)",
            deviceModel: "iPhone18,1",
            timestampBegin: "2027-01-15T08:00:00Z",
            timestampEnd: "2027-01-16T08:00:00Z",
            exceptionType: 1,
            signal: 11,
            exceptionCode: "18446744073709551615",
            terminationReason: "Namespace SIGNAL, Code 11",
            frames: [
                .init(binaryName: "Spoonjoy", binaryUUID: "UUID-1", offsetIntoBinaryTextSegment: 4096),
                .init(binaryName: "libswiftCore.dylib", offsetIntoBinaryTextSegment: 8192)
            ]
        ))
    }

    @Test("a hang maps its duration to milliseconds and takes the first thread when none is blamed")
    func hangMapping() {
        let tree = Self.callStackTree(threads: [
            (attributed: false, frames: [Self.frame("Spoonjoy", offset: 12)]),
            (attributed: false, frames: [Self.frame("Other", offset: 99)])
        ])
        let report = NativeDiagnosticMapper.report(
            from: NativeDiagnosticInput(kind: .hang, hangDurationSeconds: 2.5, callStackTree: tree),
            diagnosticID: "diag-hang",
            metadata: Self.metadata,
            environment: nil
        )

        #expect(report.kind == .hang)
        #expect(report.hangDurationMilliseconds == 2_500)
        #expect(report.exceptionType == nil)
        #expect(report.signal == nil)
        #expect(report.environment == nil)
        // No version on the diagnostic: the bundle's.
        #expect(report.appVersion == "1.3")
        #expect(report.buildNumber == "77")
        #expect(report.frames == [.init(binaryName: "Spoonjoy", offsetIntoBinaryTextSegment: 12)])
    }

    @Test("hang durations stay between zero and a day, and a non-number is left out")
    func hangDurationRange() {
        func milliseconds(_ seconds: Double) -> Int? {
            NativeDiagnosticMapper.report(
                from: NativeDiagnosticInput(kind: .hang, hangDurationSeconds: seconds),
                diagnosticID: "d",
                metadata: .unknown,
                environment: nil
            ).hangDurationMilliseconds
        }
        #expect(milliseconds(-3) == 0)
        #expect(milliseconds(1_000_000) == 86_400_000)
        #expect(milliseconds(.nan) == nil)
        #expect(milliseconds(.infinity) == nil)
    }

    @Test("frames stop at 24, deep chains included, and odd frames are made safe")
    func frameTruncation() throws {
        let deep = (0..<30).map { Self.frame("Bin\($0)", offset: $0) }
        let frames = try #require(NativeDiagnosticMapper.frames(fromCallStackTree: Self.callStackTree(threads: [(attributed: true, frames: deep)])))
        #expect(frames.count == 24)
        #expect(frames.first?.binaryName == "Bin0")
        #expect(frames.last?.binaryName == "Bin23")

        let odd: [String: Any] = [
            "binaryName": String(repeating: "b", count: 200),
            "binaryUUID": String(repeating: "u", count: 60),
            "offsetIntoBinaryTextSegment": -5,
            "address": 123_456
        ]
        let safe = try #require(NativeDiagnosticMapper.frames(fromCallStackTree: Self.callStackTree(threads: [(attributed: true, frames: [odd, [:]])])))
        #expect(safe[0].binaryName.count == 120)
        #expect(safe[0].binaryUUID?.count == 40)
        #expect(safe[0].offsetIntoBinaryTextSegment == 0)
        #expect(safe[1] == .init(binaryName: "unknown", offsetIntoBinaryTextSegment: 0))
    }

    @Test("a missing or unreadable call stack tree gives no frames")
    func missingFrames() throws {
        #expect(NativeDiagnosticMapper.frames(fromCallStackTree: nil) == nil)
        #expect(NativeDiagnosticMapper.frames(fromCallStackTree: Data("not json".utf8)) == nil)
        #expect(NativeDiagnosticMapper.frames(fromCallStackTree: Data("[]".utf8)) == nil)
        #expect(NativeDiagnosticMapper.frames(fromCallStackTree: Data(#"{"callStacks":[]}"#.utf8)) == nil)
        #expect(NativeDiagnosticMapper.frames(fromCallStackTree: Data(#"{"callStacks":[{"callStackRootFrames":[]}]}"#.utf8)) == nil)
    }

    @Test("strings are trimmed, blanks dropped and long ones cut to the server's limits")
    func stringTruncation() {
        let report = NativeDiagnosticMapper.report(
            from: NativeDiagnosticInput(
                kind: .crash,
                appVersion: "   ",
                buildNumber: "",
                osVersion: String(repeating: "o", count: 100),
                deviceModel: "  iPad16,3  ",
                exceptionType: 2_000_000,
                exceptionCode: String(repeating: "9", count: 60),
                signal: -1,
                terminationReason: String(repeating: "r", count: 299) + "🍝🍝"
            ),
            diagnosticID: "  ",
            metadata: NativeTelemetryAppMetadata(platform: "visionos", appVersion: "  ", buildNumber: nil, installID: String(repeating: "i", count: 70)),
            environment: .local
        )

        #expect(report.diagnosticID.count == 36)
        // Longer than the server's 64: left out rather than cut, since a cut ID would name another install.
        #expect(report.installID == nil)
        #expect(report.platform == nil)
        #expect(report.appVersion == nil)
        #expect(report.buildNumber == nil)
        #expect(report.osVersion?.count == 80)
        #expect(report.deviceModel == "iPad16,3")
        #expect(report.exceptionType == nil)
        #expect(report.signal == nil)
        #expect(report.exceptionCode?.count == 40)
        // 299 units fit; a pasta is two UTF-16 units, so it does not, and is never split in half.
        #expect(report.terminationReason == String(repeating: "r", count: 299))
        #expect(report.environment == "local")
        #expect(report.frames == nil)
    }

    @Test("every app environment maps to one the server knows")
    func environments() {
        #expect(NativeDiagnosticMapper.diagnosticsEnvironment(.production) == "production")
        #expect(NativeDiagnosticMapper.diagnosticsEnvironment(.preview) == "preview")
        #expect(NativeDiagnosticMapper.diagnosticsEnvironment(.previewHost("qa.example")) == "preview")
        #expect(NativeDiagnosticMapper.diagnosticsEnvironment(.local) == "local")
    }

    // MARK: Request

    @Test("the request posts the exact JSON keys, with the token only when signed in")
    func requestEncoding() throws {
        let report = NativeDiagnosticReport(
            kind: .crash,
            diagnosticID: "diag-1",
            installID: "install-abc",
            environment: "production",
            platform: "macos",
            appVersion: "1.3",
            buildNumber: "77",
            osVersion: "macOS 27.0",
            deviceModel: "Mac16,1",
            timestampBegin: "2027-01-15T08:00:00Z",
            timestampEnd: "2027-01-16T08:00:00Z",
            exceptionType: 1,
            signal: 11,
            exceptionCode: "0",
            terminationReason: "reason",
            hangDurationMilliseconds: 10,
            frames: [.init(binaryName: "Spoonjoy", binaryUUID: "U", offsetIntoBinaryTextSegment: 1)]
        )
        let builder = try NativeDiagnosticsRequests.record(report)
        let signedIn = try builder.urlRequest(configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "sj_token"))
        #expect(signedIn.method == .post)
        #expect(builder.pathComponents == ["api", "v1", "native", "diagnostics"])
        #expect(signedIn.headers["Content-Type"] == "application/json")
        #expect(signedIn.headers["Authorization"] == "Bearer sj_token")
        let signedOut = try builder.urlRequest(configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!))
        #expect(signedOut.headers["Authorization"] == nil)

        let body = try jsonBody(signedIn.body)
        #expect(Set(body.keys) == [
            "kind", "diagnosticId", "installId", "environment", "platform", "appVersion", "buildNumber", "osVersion",
            "deviceModel", "timestampBegin", "timestampEnd", "exceptionType", "signal", "exceptionCode",
            "terminationReason", "hangDurationMilliseconds", "frames"
        ])
        #expect(body["diagnosticId"] as? String == "diag-1")
        #expect(body["installId"] as? String == "install-abc")
        let frame = try #require((body["frames"] as? [[String: Any]])?.first)
        #expect(Set(frame.keys) == ["binaryName", "binaryUUID", "offsetIntoBinaryTextSegment"])

        let sparse = try NativeDiagnosticsRequests.record(NativeDiagnosticReport(kind: .hang, diagnosticID: "d"))
        let sparseBody = try jsonBody(sparse.body)
        // Absent fields are left out, never sent as null.
        #expect(Set(sparseBody.keys) == ["kind", "diagnosticId"])
    }

    @Test("the largest report the mapper can make fits the server's 16 KiB body limit")
    func worstCaseSize() throws {
        let long = String(repeating: "x", count: 1_000)
        let deep = (0..<40).map { _ in Self.frame(long, uuid: long, offset: Int.max) }
        let report = NativeDiagnosticMapper.report(
            from: NativeDiagnosticInput(
                kind: .crash,
                appVersion: long,
                buildNumber: long,
                osVersion: long,
                deviceModel: long,
                timestampBegin: Self.begin,
                timestampEnd: Self.end,
                exceptionType: 1_000_000,
                exceptionCode: long,
                signal: 1_000,
                terminationReason: long,
                hangDurationSeconds: 86_400,
                callStackTree: Self.callStackTree(threads: [(attributed: true, frames: deep)])
            ),
            diagnosticID: long,
            metadata: NativeTelemetryAppMetadata(platform: "macos", appVersion: long, buildNumber: long, installID: long),
            environment: .previewHost("qa")
        )
        let body = try #require(try NativeDiagnosticsRequests.record(report).body)
        #expect(body.count < 16_384)
    }

    // MARK: Sending

    @Test("2xx is accepted, 4xx is dropped for good, 5xx and offline wait for a retry")
    func sendOutcomes() async {
        let report = NativeDiagnosticReport(kind: .crash, diagnosticID: "d")
        let configuration = APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!)
        func outcome(_ result: FakeDiagnosticsTransport.Result) async -> NativeDiagnosticSendOutcome {
            await NativeDiagnosticsSender(transport: FakeDiagnosticsTransport([result])).send(report, configuration: configuration)
        }
        #expect(await outcome(.accepted) == .accepted)
        #expect(await outcome(.status(400)) == .rejected)
        #expect(await outcome(.status(413)) == .rejected)
        #expect(await outcome(.status(401)) == .rejected)
        #expect(await outcome(.status(500)) == .retryLater)
        #expect(await outcome(.status(503)) == .retryLater)
        #expect(await outcome(.status(202)) == .accepted)
        #expect(await outcome(.offline) == .retryLater)
        #expect(NativeDiagnosticSendOutcome.classify(EncodingError.invalidValue(1, .init(codingPath: [], debugDescription: "x"))) == .rejected)
        #expect(NativeDiagnosticSendOutcome.classify(CancellationError()) == .retryLater)
    }

    @Test("a token the server turns down is dropped and the report sent again without it")
    func unauthorizedRetriesAnonymously() async {
        let transport = FakeDiagnosticsTransport([.status(401), .accepted])
        let outcome = await NativeDiagnosticsSender(transport: transport).send(
            NativeDiagnosticReport(kind: .crash, diagnosticID: "d"),
            configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "sj_stale")
        )
        #expect(outcome == .accepted)
        #expect(transport.tokens == ["sj_stale", nil])
    }

    // MARK: Queue

    @Test("the queue survives a relaunch, keeps one copy of each report and holds the newest 50")
    func queuePersistence() async throws {
        let fileURL = try Self.temporaryQueueURL()
        let queue = NativeDiagnosticQueue(fileURL: fileURL)
        await queue.enqueue((0..<45).map { NativeDiagnosticReport(kind: .crash, diagnosticID: "d\($0)") })
        await queue.enqueue((40..<55).map { NativeDiagnosticReport(kind: .hang, diagnosticID: "d\($0)") })

        let reopened = NativeDiagnosticQueue(fileURL: fileURL)
        let pending = await reopened.pending()
        #expect(pending.count == 50)
        #expect(pending.first?.diagnosticID == "d5")
        #expect(pending.last?.diagnosticID == "d54")
        // d40...d44 were already queued as crashes, so the hang copies were not added.
        #expect(pending.first { $0.diagnosticID == "d42" }?.kind == .crash)
    }

    @Test("a flush drops sent and refused reports and stops at the first that must wait")
    func queueFlushRules() async throws {
        let fileURL = try Self.temporaryQueueURL()
        let queue = NativeDiagnosticQueue(fileURL: fileURL, capacity: 10)
        await queue.enqueue(["ok", "bad", "later", "after"].map { NativeDiagnosticReport(kind: .crash, diagnosticID: $0) })

        let attempted = AttemptLog()
        let result = await queue.flush { report in
            await attempted.append(report.diagnosticID)
            switch report.diagnosticID {
            case "ok": return .accepted
            case "bad": return .rejected
            default: return .retryLater
            }
        }

        #expect(result == NativeDiagnosticFlushResult(sent: 1, dropped: 1, remaining: 2))
        #expect(await attempted.ids == ["ok", "bad", "later"])
        #expect(await NativeDiagnosticQueue(fileURL: fileURL).pending().map(\.diagnosticID) == ["later", "after"])

        let drained = await queue.flush { _ in .accepted }
        #expect(drained == NativeDiagnosticFlushResult(sent: 2, dropped: 0, remaining: 0))
        #expect(await NativeDiagnosticQueue(fileURL: fileURL).pending().isEmpty)
    }

    @Test("an unreadable queue file starts empty, and the queue lives beside the app state")
    func queueFileHandling() async throws {
        let fileURL = try Self.temporaryQueueURL()
        try Data("garbage".utf8).write(to: fileURL)
        #expect(await NativeDiagnosticQueue(fileURL: fileURL).pending().isEmpty)

        let appState = URL(fileURLWithPath: "/tmp/Spoonjoy/native-app-state.json")
        #expect(NativeDiagnosticQueue.defaultFileURL(appStateFileURL: appState).path == "/tmp/Spoonjoy/native-diagnostics-queue.json")
        #expect(NativeDiagnosticQueue.defaultFileURL().lastPathComponent == NativeDiagnosticQueue.fileName)
        #expect(NativeDiagnosticQueue.defaultCapacity == 50)
    }

    // MARK: Install ID and launch

    @Test("the install ID is made once and kept, and a bad stored value is replaced")
    func installIDStability() throws {
        let suiteName = "spoonjoy.tests.install-id.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = NativeInstallID.current(defaults: defaults)
        #expect(UUID(uuidString: first) != nil)
        #expect(NativeInstallID.current(defaults: defaults) == first)
        #expect(NativeInstallID.current(defaults: defaults, makeID: { "never-used" }) == first)
        #expect(NativeInstallID.isValid(first))

        defaults.set(String(repeating: "x", count: 65), forKey: NativeInstallID.defaultsKey)
        #expect(NativeInstallID.current(defaults: defaults, makeID: { "replacement-1" }) == "replacement-1")
        defaults.set("", forKey: NativeInstallID.defaultsKey)
        #expect(NativeInstallID.current(defaults: defaults, makeID: { "again-123" }) == "again-123")
        #expect(NativeInstallID.current(defaults: defaults) == "again-123")
    }

    @Test("install IDs match the server's pattern: 8 to 64 letters, digits and hyphens")
    func installIDPattern() {
        #expect(NativeInstallID.isValid(UUID().uuidString))
        #expect(NativeInstallID.isValid(UUID().uuidString.lowercased()))
        #expect(!NativeInstallID.isValid("short"))
        #expect(!NativeInstallID.isValid(String(repeating: "a", count: 65)))
        #expect(!NativeInstallID.isValid("has space-1234"))
        #expect(!NativeInstallID.isValid("under_score1"))
        #expect(!NativeInstallID.isValid("éééééééééé"))
    }

    @Test("launch settles once per process")
    func launchSettlesOnce() {
        let settlement = NativeLaunchSettlement()
        #expect(!settlement.isSettled)
        #expect(settlement.markSettled())
        #expect(!settlement.markSettled())
        #expect(settlement.isSettled)
        #expect(NativeLaunchSettlement.process === NativeLaunchSettlement.process)
        #expect(NativeLaunchSettlement.settleDelay == .seconds(3))
    }

    @Test("launch_completed and the install ID go out on native telemetry")
    func launchCompletedEncoding() throws {
        let request = try NativeTelemetryRequests.recordEvent(NativeTelemetryEvent(
            name: .launchCompleted,
            stage: "launch",
            environment: "production",
            metadata: Self.metadata,
            accountBound: false
        ))
        let urlRequest = try request.urlRequest(configuration: APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!))
        let body = try jsonBody(urlRequest.body)
        #expect(body["event"] as? String == "launch_completed")
        #expect(body["stage"] as? String == "launch")
        #expect(body["installId"] as? String == "install-abc")
        #expect(body["platform"] as? String == "ios")

        let anonymous = try NativeTelemetryRequests.recordEvent(NativeTelemetryEvent(name: .launchCompleted, stage: "launch", environment: "production"))
        let anonymousBody = try jsonBody(anonymous.body)
        #expect(anonymousBody["installId"] == nil)
    }

    @Test("both native sign-in requests carry platform, version and install ID, and leave out what is unknown")
    func signInClientFields() throws {
        let installID = UUID().uuidString
        let client = NativeTelemetryAppMetadata(platform: "macos", appVersion: "1.3", buildNumber: "77", installID: installID)
        let apple = try NativeAppleSignInRequests.exchangeCredential(
            NativeAppleSignInCredential(identityToken: "token", rawNonce: "nonce"),
            client: client
        )
        let appleBody = try jsonBody(apple.body)
        #expect(Set(appleBody.keys) == ["identityToken", "rawNonce", "platform", "appVersion", "installId"])
        #expect(appleBody["platform"] as? String == "macos")
        #expect(appleBody["appVersion"] as? String == "1.3")
        #expect(appleBody["installId"] as? String == installID)

        let password = try NativePasswordSignInRequests.exchangeCredential(
            NativePasswordSignInCredential(emailOrUsername: "chef", password: "secret"),
            client: client
        )
        let passwordBody = try jsonBody(password.body)
        #expect(Set(passwordBody.keys) == ["emailOrUsername", "password", "platform", "appVersion", "installId"])
        #expect(passwordBody["installId"] as? String == installID)

        let unknown = try NativePasswordSignInRequests.exchangeCredential(
            NativePasswordSignInCredential(emailOrUsername: "chef", password: "secret"),
            client: NativeTelemetryAppMetadata(platform: "watchos", appVersion: "  ", installID: "bad id")
        )
        #expect(Set(try jsonBody(unknown.body).keys) == ["emailOrUsername", "password"])
        let plain = try NativeAppleSignInRequests.exchangeCredential(NativeAppleSignInCredential(identityToken: "t", rawNonce: "n"))
        #expect(Set(try jsonBody(plain.body).keys) == ["identityToken", "rawNonce"])
    }

    // MARK: Helpers

    private static func frame(_ name: String, uuid: String? = nil, offset: Int) -> [String: Any] {
        var frame: [String: Any] = ["binaryName": name, "offsetIntoBinaryTextSegment": offset, "sampleCount": 1, "address": 4_294_967_296]
        if let uuid {
            frame["binaryUUID"] = uuid
        }
        return frame
    }

    /// MetricKit's `jsonRepresentation()` shape: each thread's frames nest through the first `subFrames`.
    private static func callStackTree(threads: [(attributed: Bool, frames: [[String: Any]])]) -> Data {
        let stacks: [[String: Any]] = threads.map { thread in
            var nested: [String: Any]?
            for frame in thread.frames.reversed() {
                var frame = frame
                if let nested {
                    frame["subFrames"] = [nested]
                }
                nested = frame
            }
            return ["threadAttributed": thread.attributed, "callStackRootFrames": nested.map { [$0] } ?? []]
        }
        return try! JSONSerialization.data(withJSONObject: ["callStackPerThread": true, "callStacks": stacks])
    }

    private static func temporaryQueueURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diagnostics-queue-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(NativeDiagnosticQueue.fileName)
    }
}

private func jsonBody(_ data: Data?) throws -> [String: Any] {
    let data = try #require(data)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private actor AttemptLog {
    private(set) var ids: [String] = []

    func append(_ id: String) {
        ids.append(id)
    }
}

/// Answers each send with the next scripted result and records the token each send carried.
private final class FakeDiagnosticsTransport: SpoonjoyAPITransport, Sendable {
    enum Result: Sendable {
        case accepted
        case status(Int)
        case offline
    }

    private let state: Mutex<(results: [Result], tokens: [String?])>

    init(_ results: [Result]) {
        state = Mutex((results: results, tokens: []))
    }

    var tokens: [String?] {
        state.withLock { $0.tokens }
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let result = state.withLock { state in
            state.tokens.append(configuration.bearerToken)
            return state.results.removeFirst()
        }
        switch result {
        case .accepted:
            return try APIEnvelope<Value>.decode(Data(#"{"ok":true,"requestId":"req_diag","data":{"accepted":true}}"#.utf8))
        case .status(let status):
            throw APITransportError(kind: .apiError, requestID: nil, statusCode: status, apiError: nil, retryDecision: .doNotRetry)
        case .offline:
            throw APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        }
    }
}
