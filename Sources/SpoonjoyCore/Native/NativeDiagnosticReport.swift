import Foundation

/// A crash or hang that Apple's MetricKit handed the app, in the shape `POST /api/v1/native/diagnostics` takes.
/// It says where the code stopped (each frame's binary name, UUID and offset) and nothing more: no symbols, no
/// addresses, no exception message and nothing a person typed.
public struct NativeDiagnosticReport: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case crash
        case hang
    }

    public struct Frame: Codable, Equatable, Sendable {
        public let binaryName: String
        public let binaryUUID: String?
        public let offsetIntoBinaryTextSegment: Int

        public init(binaryName: String, binaryUUID: String? = nil, offsetIntoBinaryTextSegment: Int) {
            self.binaryName = binaryName
            self.binaryUUID = binaryUUID
            self.offsetIntoBinaryTextSegment = offsetIntoBinaryTextSegment
        }
    }

    public let kind: Kind
    /// Made when the report is queued and kept across retries, so the server can drop a report it already has.
    public let diagnosticID: String
    public let installID: String?
    public let environment: String?
    public let platform: String?
    public let appVersion: String?
    public let buildNumber: String?
    public let osVersion: String?
    public let deviceModel: String?
    public let timestampBegin: String?
    public let timestampEnd: String?
    public let exceptionType: Int?
    public let signal: Int?
    public let exceptionCode: String?
    public let terminationReason: String?
    public let hangDurationMilliseconds: Int?
    public let frames: [Frame]?

    private enum CodingKeys: String, CodingKey {
        case kind
        case diagnosticID = "diagnosticId"
        case installID = "installId"
        case environment
        case platform
        case appVersion
        case buildNumber
        case osVersion
        case deviceModel
        case timestampBegin
        case timestampEnd
        case exceptionType
        case signal
        case exceptionCode
        case terminationReason
        case hangDurationMilliseconds
        case frames
    }

    public init(
        kind: Kind,
        diagnosticID: String,
        installID: String? = nil,
        environment: String? = nil,
        platform: String? = nil,
        appVersion: String? = nil,
        buildNumber: String? = nil,
        osVersion: String? = nil,
        deviceModel: String? = nil,
        timestampBegin: String? = nil,
        timestampEnd: String? = nil,
        exceptionType: Int? = nil,
        signal: Int? = nil,
        exceptionCode: String? = nil,
        terminationReason: String? = nil,
        hangDurationMilliseconds: Int? = nil,
        frames: [Frame]? = nil
    ) {
        self.kind = kind
        self.diagnosticID = diagnosticID
        self.installID = installID
        self.environment = environment
        self.platform = platform
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.timestampBegin = timestampBegin
        self.timestampEnd = timestampEnd
        self.exceptionType = exceptionType
        self.signal = signal
        self.exceptionCode = exceptionCode
        self.terminationReason = terminationReason
        self.hangDurationMilliseconds = hangDurationMilliseconds
        self.frames = frames
    }
}

/// What the app read off one MetricKit diagnostic, as plain values, so the mapping can be tested without MetricKit.
/// `callStackTree` is `MXCallStackTree.jsonRepresentation()`.
public struct NativeDiagnosticInput: Equatable, Sendable {
    public let kind: NativeDiagnosticReport.Kind
    public let appVersion: String?
    public let buildNumber: String?
    public let osVersion: String?
    public let deviceModel: String?
    public let timestampBegin: Date?
    public let timestampEnd: Date?
    public let exceptionType: Int?
    /// `MXCrashDiagnostic.exceptionCode` as text: the number can be larger than JSON numbers hold exactly.
    public let exceptionCode: String?
    public let signal: Int?
    public let terminationReason: String?
    public let hangDurationSeconds: Double?
    public let callStackTree: Data?

    public init(
        kind: NativeDiagnosticReport.Kind,
        appVersion: String? = nil,
        buildNumber: String? = nil,
        osVersion: String? = nil,
        deviceModel: String? = nil,
        timestampBegin: Date? = nil,
        timestampEnd: Date? = nil,
        exceptionType: Int? = nil,
        exceptionCode: String? = nil,
        signal: Int? = nil,
        terminationReason: String? = nil,
        hangDurationSeconds: Double? = nil,
        callStackTree: Data? = nil
    ) {
        self.kind = kind
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.timestampBegin = timestampBegin
        self.timestampEnd = timestampEnd
        self.exceptionType = exceptionType
        self.exceptionCode = exceptionCode
        self.signal = signal
        self.terminationReason = terminationReason
        self.hangDurationSeconds = hangDurationSeconds
        self.callStackTree = callStackTree
    }
}

/// Turns what MetricKit reported into a report the server accepts: every string cut to the server's limit, every
/// number kept in its range, and at most 24 frames from one thread.
public enum NativeDiagnosticMapper {
    public static let maximumFrames = 24

    public static func report(
        from input: NativeDiagnosticInput,
        diagnosticID: String,
        metadata: NativeTelemetryAppMetadata,
        environment: NativeCacheEnvironment?
    ) -> NativeDiagnosticReport {
        NativeDiagnosticReport(
            kind: input.kind,
            diagnosticID: clipped(diagnosticID, to: 80) ?? UUID().uuidString,
            installID: metadata.installID.flatMap { NativeInstallID.isValid($0) ? $0 : nil },
            environment: environment.map(diagnosticsEnvironment),
            platform: ["ios", "macos"].contains(metadata.platform ?? "") ? metadata.platform : nil,
            appVersion: clipped(input.appVersion, to: 40) ?? clipped(metadata.appVersion, to: 40),
            buildNumber: clipped(input.buildNumber, to: 40) ?? clipped(metadata.buildNumber, to: 40),
            osVersion: clipped(input.osVersion, to: 80),
            deviceModel: clipped(input.deviceModel, to: 80),
            timestampBegin: input.timestampBegin.map { $0.formatted(.iso8601) },
            timestampEnd: input.timestampEnd.map { $0.formatted(.iso8601) },
            exceptionType: input.exceptionType.flatMap { within($0, 0...1_000_000) },
            signal: input.signal.flatMap { within($0, 0...1_000) },
            exceptionCode: clipped(input.exceptionCode, to: 40),
            terminationReason: clipped(input.terminationReason, to: 300),
            hangDurationMilliseconds: input.hangDurationSeconds.flatMap(milliseconds),
            frames: frames(fromCallStackTree: input.callStackTree)
        )
    }

    /// The server knows three environments; a preview on any host is "preview".
    public static func diagnosticsEnvironment(_ environment: NativeCacheEnvironment) -> String {
        switch environment {
        case .production:
            "production"
        case .preview, .previewHost:
            "preview"
        case .local:
            "local"
        }
    }

    /// The thread MetricKit blames (`threadAttributed`), else the first one: its root frame, then each first
    /// sub-frame, top 24.
    static func frames(fromCallStackTree data: Data?) -> [NativeDiagnosticReport.Frame]? {
        guard let data,
              let tree = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let stacks = tree["callStacks"] as? [[String: Any]],
              let stack = stacks.first(where: { $0["threadAttributed"] as? Bool == true }) ?? stacks.first,
              var frame = (stack["callStackRootFrames"] as? [[String: Any]])?.first else {
            return nil
        }

        var frames: [NativeDiagnosticReport.Frame] = []
        while frames.count < maximumFrames {
            frames.append(NativeDiagnosticReport.Frame(
                binaryName: clipped(frame["binaryName"] as? String, to: 120) ?? "unknown",
                binaryUUID: clipped(frame["binaryUUID"] as? String, to: 40),
                offsetIntoBinaryTextSegment: max(0, (frame["offsetIntoBinaryTextSegment"] as? NSNumber)?.intValue ?? 0)
            ))
            guard let next = (frame["subFrames"] as? [[String: Any]])?.first else {
                break
            }
            frame = next
        }
        return frames
    }

    /// Trimmed, nil when blank, and cut to `limit` UTF-16 units (how the server counts) on a character boundary.
    static func clipped(_ value: String?, to limit: Int) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        var result = ""
        var units = 0
        for character in trimmed {
            let width = character.utf16.count
            if units + width > limit {
                break
            }
            result.append(character)
            units += width
        }
        return result
    }

    private static func within(_ value: Int, _ range: ClosedRange<Int>) -> Int? {
        range.contains(value) ? value : nil
    }

    private static func milliseconds(_ seconds: Double) -> Int? {
        guard seconds.isFinite else {
            return nil
        }
        return Int(min(max((seconds * 1_000).rounded(), 0), 86_400_000))
    }
}

public struct NativeDiagnosticsResponse: Decodable, Equatable, Sendable {
    public let accepted: Bool
}

public enum NativeDiagnosticsRequests {
    public static func record(_ report: NativeDiagnosticReport) throws -> APIRequestBuilder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return APIRequestBuilder(
            method: .post,
            pathComponents: ["api", "v1", "native", "diagnostics"],
            queryItems: [],
            headers: ["Content-Type": "application/json"],
            body: try encoder.encode(report),
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: APIRequestSupport.privateNoStore
        )
    }
}

/// What became of one send: the server took it, the server will never take it (any 4xx), or try again later
/// (a 5xx, offline, or no answer).
public enum NativeDiagnosticSendOutcome: Equatable, Sendable {
    case accepted
    case rejected
    case retryLater

    public static func classify(_ error: Error) -> NativeDiagnosticSendOutcome {
        guard let transportError = error as? APITransportError, let status = transportError.statusCode else {
            return error is EncodingError ? .rejected : .retryLater
        }
        switch status {
        case 200...299:
            // The server answered yes in a shape the client didn't expect; it has the report.
            return .accepted
        case 400...499:
            return .rejected
        default:
            return .retryLater
        }
    }
}

public struct NativeDiagnosticsSender: Sendable {
    private let transport: any SpoonjoyAPITransport

    public init(transport: any SpoonjoyAPITransport = URLSessionAPITransport()) {
        self.transport = transport
    }

    /// Sends with the signed-in token when there is one, like the app's other telemetry. Signing in is optional
    /// here, so a token the server turns down (401) is dropped and the report sent again without it.
    public func send(
        _ report: NativeDiagnosticReport,
        configuration: APIClientConfiguration
    ) async -> NativeDiagnosticSendOutcome {
        do {
            _ = try await transport.send(
                try NativeDiagnosticsRequests.record(report),
                configuration: configuration,
                decode: NativeDiagnosticsResponse.self
            )
            return .accepted
        } catch let error as APITransportError where error.statusCode == 401 && configuration.bearerToken != nil {
            return await send(report, configuration: APIClientConfiguration(baseURL: configuration.baseURL))
        } catch {
            return .classify(error)
        }
    }
}
