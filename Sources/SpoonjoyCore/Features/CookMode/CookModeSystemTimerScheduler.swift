public enum CookModeSystemTimerAuthorizationState: Equatable {
    case authorized
    case notDetermined
    case denied
}

public enum CookModeSystemTimerSchedulingError: Error, Equatable {
    case unsupportedPlatform
    case denied
    case authorizationFailed
    case schedulingFailed
}

@MainActor
public struct CookModeSystemTimerSchedulingClient {
    private let authorizationStateHandler: () -> CookModeSystemTimerAuthorizationState
    private let requestAuthorizationHandler: () async throws -> CookModeSystemTimerAuthorizationState
    private let scheduleHandler: () async throws -> Void

    public init(
        authorizationState: @escaping () -> CookModeSystemTimerAuthorizationState,
        requestAuthorization: @escaping () async throws -> CookModeSystemTimerAuthorizationState,
        schedule: @escaping () async throws -> Void
    ) {
        authorizationStateHandler = authorizationState
        requestAuthorizationHandler = requestAuthorization
        scheduleHandler = schedule
    }

    func authorizationState() -> CookModeSystemTimerAuthorizationState {
        authorizationStateHandler()
    }

    func requestAuthorization() async throws -> CookModeSystemTimerAuthorizationState {
        try await requestAuthorizationHandler()
    }

    func schedule() async throws {
        try await scheduleHandler()
    }
}

public enum CookModeSystemTimerScheduler {
    @MainActor
    public static func schedule(using client: CookModeSystemTimerSchedulingClient) async throws {
        let authorizationState: CookModeSystemTimerAuthorizationState
        switch client.authorizationState() {
        case .authorized:
            authorizationState = .authorized
        case .notDetermined:
            do {
                authorizationState = try await client.requestAuthorization()
            } catch {
                throw CookModeSystemTimerSchedulingError.authorizationFailed
            }
        case .denied:
            throw CookModeSystemTimerSchedulingError.denied
        }

        guard authorizationState == .authorized else {
            throw CookModeSystemTimerSchedulingError.denied
        }

        do {
            try await client.schedule()
        } catch {
            throw CookModeSystemTimerSchedulingError.schedulingFailed
        }
    }

    public static func message(for error: Error, fallback: String) -> String {
        guard let schedulingError = error as? CookModeSystemTimerSchedulingError else {
            return "Could not set the system timer."
        }

        switch schedulingError {
        case .unsupportedPlatform:
            return fallback
        case .denied:
            return "Allow system timers in Settings to set this timer."
        case .authorizationFailed:
            return "Could not request permission to set system timers."
        case .schedulingFailed:
            return "Could not set the system timer."
        }
    }
}
