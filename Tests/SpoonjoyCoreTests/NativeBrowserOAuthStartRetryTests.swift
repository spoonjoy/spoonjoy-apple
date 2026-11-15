import Foundation
import Testing
@testable import SpoonjoyCore

@MainActor
@Suite("Browser sign-in start retry")
struct NativeBrowserOAuthStartRetryTests {
    private struct Failure: Error {}

    private static let offline = APITransportError(
        kind: .offline,
        requestID: nil,
        statusCode: nil,
        apiError: nil,
        retryDecision: .retrySameRequest(afterSeconds: nil),
        urlErrorCode: URLError.Code.notConnectedToInternet.rawValue
    )
    private static let networkFailure = APITransportError(
        kind: .networkFailure,
        requestID: nil,
        statusCode: nil,
        apiError: nil,
        retryDecision: .retrySameRequest(afterSeconds: nil),
        urlErrorCode: URLError.Code.secureConnectionFailed.rawValue
    )
    private static let serverError = APITransportError(
        kind: .apiError,
        requestID: "req_1",
        statusCode: 503,
        apiError: nil,
        retryDecision: .retrySameRequest(afterSeconds: nil)
    )

    /// A scripted start: each call takes the next outcome.
    private final class Script {
        var outcomes: [Result<String, any Error>]
        var calls = 0
        var pauses: [Duration] = []
        var lines: [String] = []
        var current = true
        var onPause: (Script) -> Void = { _ in }
        /// Seconds each try takes before it fails or succeeds.
        var tryDuration: TimeInterval = 0.4
        var clock: TimeInterval = 0

        init(_ outcomes: [Result<String, any Error>]) {
            self.outcomes = outcomes
        }

        @MainActor
        func run() async throws -> String {
            try await NativeBrowserOAuthStartRetry.run(
                pause: { duration in
                    self.pauses.append(duration)
                    self.onPause(self)
                },
                now: { self.clock },
                isCurrent: { self.current },
                log: { self.lines.append($0) },
                operation: {
                    let outcome = self.outcomes[self.calls]
                    self.calls += 1
                    self.clock += self.tryDuration
                    return try outcome.get()
                }
            )
        }
    }

    @Test("a transient failure, then success: one retry after 0.7 s")
    func oneRetry() async throws {
        let script = Script([.failure(Self.offline), .success("sheet")])
        #expect(try await script.run() == "sheet")
        #expect(script.calls == 2)
        #expect(script.pauses == [.milliseconds(700)])
        #expect(script.lines == ["Browser sign-in start retried after offline NSURLError -1009 status none request none (attempt 1)"])
    }

    @Test("two transient failures, then success: two retries")
    func twoRetries() async throws {
        let script = Script([.failure(Self.offline), .failure(Self.networkFailure), .success("sheet")])
        #expect(try await script.run() == "sheet")
        #expect(script.calls == 3)
        #expect(script.pauses == [.milliseconds(700), .seconds(2)])
        #expect(script.lines.last == "Browser sign-in start retried after networkFailure NSURLError -1200 status none request none (attempt 2)")
    }

    @Test("three transient failures: the error comes out once, after 2.7 s of waiting")
    func threeFailures() async {
        let script = Script([.failure(Self.offline), .failure(Self.offline), .failure(Self.offline), .success("never")])
        await #expect(throws: APITransportError.self) { try await script.run() }
        #expect(script.calls == 3)
        #expect(script.pauses.reduce(Duration.zero, +) == .milliseconds(2700))
        #expect(script.lines.count == 2)
    }

    @Test("a non-transient error is never retried", arguments: [
        "http", "cancelled", "urlCancelled", "other",
    ])
    func nonTransient(kind: String) async {
        let error: any Error = switch kind {
        case "http": Self.serverError
        case "cancelled": APITransportError(
            kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
        case "urlCancelled": URLError(.cancelled)
        default: Failure()
        }
        let script = Script([.failure(error), .success("never")])
        await #expect(throws: (any Error).self) { try await script.run() }
        #expect(script.calls == 1)
        #expect(script.pauses.isEmpty)
        #expect(script.lines.isEmpty)
    }

    @Test("a slow failure is not retried; a fast offline one is")
    func onlyFastFailuresRetry() async throws {
        let slow = Script([.failure(Self.offline), .success("never")])
        slow.tryDuration = 3.5
        await #expect(throws: APITransportError.self) { try await slow.run() }
        #expect(slow.calls == 1)
        #expect(slow.pauses.isEmpty)

        let fast = Script([.failure(Self.offline), .success("sheet")])
        fast.tryDuration = 2.9
        #expect(try await fast.run() == "sheet")
        #expect(fast.calls == 2)
    }

    @Test("a timeout is never retried, however fast")
    func timeoutNeverRetries() async {
        let timedOut = OAuthErrorResponse.offlineError(for: URLError(.timedOut))!
        #expect(timedOut.kind == .offline)
        let script = Script([.failure(timedOut), .success("never")])
        await #expect(throws: APITransportError.self) { try await script.run() }
        #expect(script.calls == 1)
        #expect(!NativeBrowserOAuthStartRetry.shouldRetry(URLError(.timedOut), secondsTaken: 0.1))
    }

    @Test("a raw network URLError counts as transient")
    func rawURLError() {
        #expect(NativeBrowserOAuthStartRetry.isTransient(URLError(.secureConnectionFailed)))
        #expect(!NativeBrowserOAuthStartRetry.isTransient(URLError(.badURL)))
    }

    @Test("replaced during either wait: nothing more starts", arguments: [0, 1])
    func replacedDuringWait(wait: Int) async {
        let script = Script([.failure(Self.offline), .failure(Self.offline), .success("never")])
        script.onPause = { script in
            if script.pauses.count == wait + 1 {
                script.current = false
            }
        }
        await #expect(throws: CancellationError.self) { try await script.run() }
        #expect(script.calls == wait + 1)
        #expect(script.lines.last == NativeBrowserOAuthStartRetry.abandonedMessage)
    }

    @Test("replaced while the request is in flight: its transient failure logs no retry and waits for nothing")
    func replacedDuringRequest() async {
        let script = Script([.failure(Self.offline), .success("never")])
        script.current = false
        await #expect(throws: CancellationError.self) { try await script.run() }
        #expect(script.calls == 1)
        #expect(script.pauses.isEmpty)
        #expect(script.lines == [NativeBrowserOAuthStartRetry.abandonedMessage])
    }

    @Test("the default pause sleeps for the delay, then the start goes again")
    func defaultPause() async throws {
        var calls = 0
        let value = try await NativeBrowserOAuthStartRetry.run(
            delays: [.milliseconds(1)],
            isCurrent: { true },
            log: { _ in },
            operation: { () async throws -> String in
                calls += 1
                if calls == 1 { throw Self.offline }
                return "sheet"
            }
        )
        #expect(value == "sheet")
        #expect(calls == 2)
    }

    @Test("a cancelled wait stops the start")
    func cancelledWait() async {
        var calls = 0
        await #expect(throws: CancellationError.self) {
            try await NativeBrowserOAuthStartRetry.run(
                pause: { _ in throw CancellationError() },
                isCurrent: { true },
                log: { _ in },
                operation: { () async throws -> String in
                    calls += 1
                    throw Self.offline
                }
            )
        }
        #expect(calls == 1)
    }

    @Test("the transport keeps the URLError code for the log")
    func transportKeepsCode() {
        let offline = OAuthErrorResponse.offlineError(for: URLError(.timedOut))
        #expect(offline?.urlErrorCode == URLError.Code.timedOut.rawValue)
        #expect(NativeBrowserOAuthEarlyCancel.diagnosticReason(offline!) == "offline NSURLError -1001 status none request none")
    }
}
