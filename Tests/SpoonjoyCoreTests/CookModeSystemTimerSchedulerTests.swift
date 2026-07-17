import Testing
@testable import SpoonjoyCore

@Suite("Cook mode system timer scheduling")
@MainActor
struct CookModeSystemTimerSchedulerTests {
    @Test("denied authorization fails without requesting or scheduling")
    func deniedAuthorizationFailsWithoutRequestingOrScheduling() async {
        var events: [String] = []
        let client = CookModeSystemTimerSchedulingClient(
            authorizationState: {
                events.append("authorization-state")
                return .denied
            },
            requestAuthorization: {
                events.append("request-authorization")
                return .authorized
            },
            schedule: {
                events.append("schedule")
            }
        )

        await expectSchedulingError(.denied) {
            try await CookModeSystemTimerScheduler.schedule(using: client)
        }
        #expect(events == ["authorization-state"])
    }

    @Test("undetermined authorization is requested before scheduling")
    func undeterminedAuthorizationIsRequestedBeforeScheduling() async throws {
        var events: [String] = []
        let client = CookModeSystemTimerSchedulingClient(
            authorizationState: {
                events.append("authorization-state")
                return .notDetermined
            },
            requestAuthorization: {
                events.append("request-authorization")
                return .authorized
            },
            schedule: {
                events.append("schedule")
            }
        )

        try await CookModeSystemTimerScheduler.schedule(using: client)

        #expect(events == ["authorization-state", "request-authorization", "schedule"])
    }

    @Test("authorization denied by the request does not schedule")
    func authorizationDeniedByRequestDoesNotSchedule() async {
        var events: [String] = []
        let client = CookModeSystemTimerSchedulingClient(
            authorizationState: {
                events.append("authorization-state")
                return .notDetermined
            },
            requestAuthorization: {
                events.append("request-authorization")
                return .denied
            },
            schedule: {
                events.append("schedule")
            }
        )

        await expectSchedulingError(.denied) {
            try await CookModeSystemTimerScheduler.schedule(using: client)
        }
        #expect(events == ["authorization-state", "request-authorization"])
    }

    @Test("authorization request failures become stable timer errors")
    func authorizationRequestFailuresBecomeStableTimerErrors() async {
        let client = CookModeSystemTimerSchedulingClient(
            authorizationState: { .notDetermined },
            requestAuthorization: { throw TestFailure.authorizationRequestFailed },
            schedule: { Issue.record("Scheduling must not run after an authorization request failure.") }
        )

        await expectSchedulingError(.authorizationFailed) {
            try await CookModeSystemTimerScheduler.schedule(using: client)
        }
    }

    @Test("authorized timer schedules without requesting authorization")
    func authorizedTimerSchedulesWithoutRequestingAuthorization() async throws {
        var events: [String] = []
        let client = CookModeSystemTimerSchedulingClient(
            authorizationState: {
                events.append("authorization-state")
                return .authorized
            },
            requestAuthorization: {
                events.append("request-authorization")
                return .authorized
            },
            schedule: {
                events.append("schedule")
            }
        )

        try await CookModeSystemTimerScheduler.schedule(using: client)

        #expect(events == ["authorization-state", "schedule"])
    }

    @Test("AlarmKit scheduling failures become stable timer errors")
    func schedulingFailuresBecomeStableTimerErrors() async {
        let client = CookModeSystemTimerSchedulingClient(
            authorizationState: { .authorized },
            requestAuthorization: { .authorized },
            schedule: { throw TestFailure.alarmKitRejectedSchedule }
        )

        await expectSchedulingError(.schedulingFailed) {
            try await CookModeSystemTimerScheduler.schedule(using: client)
        }
    }

    @Test("timer errors have stable actionable messages")
    func timerErrorsHaveStableActionableMessages() {
        let fallback = "System timers are unavailable here."

        #expect(CookModeSystemTimerScheduler.message(
            for: CookModeSystemTimerSchedulingError.unsupportedPlatform,
            fallback: fallback
        ) == fallback)
        #expect(CookModeSystemTimerScheduler.message(
            for: CookModeSystemTimerSchedulingError.denied,
            fallback: fallback
        ) == "Allow system timers in Settings to set this timer.")
        #expect(CookModeSystemTimerScheduler.message(
            for: CookModeSystemTimerSchedulingError.authorizationFailed,
            fallback: fallback
        ) == "Could not request permission to set system timers.")
        #expect(CookModeSystemTimerScheduler.message(
            for: CookModeSystemTimerSchedulingError.schedulingFailed,
            fallback: fallback
        ) == "Could not set the system timer.")
        #expect(CookModeSystemTimerScheduler.message(
            for: TestFailure.alarmKitRejectedSchedule,
            fallback: fallback
        ) == "Could not set the system timer.")
    }

    private func expectSchedulingError(
        _ expected: CookModeSystemTimerSchedulingError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected scheduling to fail with \(expected).")
        } catch let error as CookModeSystemTimerSchedulingError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected CookModeSystemTimerSchedulingError, got \(error).")
        }
    }
}

private enum TestFailure: Error {
    case authorizationRequestFailed
    case alarmKitRejectedSchedule
}
