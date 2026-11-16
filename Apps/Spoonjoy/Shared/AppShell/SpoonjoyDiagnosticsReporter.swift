import Foundation
import MetricKit
import SpoonjoyCore

/// Apple's MetricKit hands the app its crash and hang reports, usually on the launch after one happened. This keeps
/// them in a queue on disk and sends them to `POST /api/v1/native/diagnostics`, so we learn of a crash without anyone
/// filing TestFlight feedback. The mapping, the queue and the send rules live in SpoonjoyCore
/// (`NativeDiagnosticMapper`, `NativeDiagnosticQueue`, `NativeDiagnosticsSender`); this is only the MetricKit glue.
@MainActor
final class SpoonjoyDiagnosticsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = SpoonjoyDiagnosticsReporter()

    private let queue = NativeDiagnosticQueue(fileURL: NativeDiagnosticQueue.defaultFileURL())
    private let sender = NativeDiagnosticsSender()
    private var isSubscribed = false
    /// Set once the shell has bootstrapped; until then reports only wait in the queue.
    private weak var store: NativeLiveAppStore?

    /// At launch. Subscribing is cheap; MetricKit delivers later, off the launch path.
    func start() {
        guard !isSubscribed else { return }
        isSubscribed = true
        MXMetricManager.shared.add(self)
    }

    /// After the shell bootstraps: reports go out with the store's server and token from here, starting with any an
    /// earlier launch left in the queue.
    func attach(_ store: NativeLiveAppStore) async {
        self.store = store
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.syntheticDiagnosticArgument), !hasSentSynthetic {
            hasSentSynthetic = true
            await receive(Self.syntheticInputs())
            return
        }
#endif
        await flush()
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let inputs = payloads.flatMap(Self.inputs(from:))
        Task { @MainActor in
            await self.receive(inputs)
        }
    }

    private func receive(_ inputs: [NativeDiagnosticInput]) async {
        guard !inputs.isEmpty else { return }
        let metadata = SpoonjoyRootView.nativeTelemetryMetadata()
        let environment = store?.telemetryEnvironment ?? SpoonjoyRootView.appCacheEnvironment()
        let reports = inputs.map { input in
            NativeDiagnosticMapper.report(
                from: input,
                diagnosticID: UUID().uuidString.lowercased(),
                metadata: metadata,
                environment: environment
            )
        }
        await queue.enqueue(reports)
        await flush()
    }

    private func flush() async {
        guard let store else { return }
        let configuration = store.telemetryConfiguration
        let sender = sender
        await queue.flush { report in
            await sender.send(report, configuration: configuration)
        }
    }

    /// Reads plain values off MetricKit's objects here, so nothing of MetricKit's crosses to the main actor. The
    /// Objective-C exception message (`exceptionReason`) is never read.
    nonisolated private static func inputs(from payload: MXDiagnosticPayload) -> [NativeDiagnosticInput] {
        let crashes = (payload.crashDiagnostics ?? []).map { crash in
            NativeDiagnosticInput(
                kind: .crash,
                appVersion: crash.applicationVersion,
                buildNumber: crash.metaData.applicationBuildVersion,
                osVersion: crash.metaData.osVersion,
                deviceModel: crash.metaData.deviceType,
                timestampBegin: payload.timeStampBegin,
                timestampEnd: payload.timeStampEnd,
                exceptionType: crash.exceptionType?.intValue,
                exceptionCode: crash.exceptionCode?.stringValue,
                signal: crash.signal?.intValue,
                terminationReason: crash.terminationReason,
                callStackTree: crash.callStackTree.jsonRepresentation()
            )
        }
        let hangs = (payload.hangDiagnostics ?? []).map { hang in
            NativeDiagnosticInput(
                kind: .hang,
                appVersion: hang.applicationVersion,
                buildNumber: hang.metaData.applicationBuildVersion,
                osVersion: hang.metaData.osVersion,
                deviceModel: hang.metaData.deviceType,
                timestampBegin: payload.timeStampBegin,
                timestampEnd: payload.timeStampEnd,
                hangDurationSeconds: hang.hangDuration.converted(to: .seconds).value,
                callStackTree: hang.callStackTree.jsonRepresentation()
            )
        }
        return crashes + hangs
    }

#if DEBUG
    /// `-SpoonjoyDebugSendSyntheticDiagnostic` (DEBUG only): once the shell is up, queues one made-up crash and one
    /// made-up hang and sends them the real way, to prove the path end to end without crashing anything.
    static let syntheticDiagnosticArgument = "-SpoonjoyDebugSendSyntheticDiagnostic"
    private var hasSentSynthetic = false

    private static func syntheticInputs() -> [NativeDiagnosticInput] {
        let tree = Data("""
        {"callStackPerThread":true,"callStacks":[{"threadAttributed":true,"callStackRootFrames":[\
        {"binaryName":"Spoonjoy","binaryUUID":"00000000-0000-0000-0000-000000000000","offsetIntoBinaryTextSegment":4096,\
        "sampleCount":1,"subFrames":[{"binaryName":"libswiftCore.dylib","offsetIntoBinaryTextSegment":8192,"sampleCount":1}]}]}]}
        """.utf8)
        let now = Date()
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return [
            NativeDiagnosticInput(
                kind: .crash,
                osVersion: osVersion,
                timestampBegin: now.addingTimeInterval(-60),
                timestampEnd: now,
                exceptionType: 1,
                exceptionCode: "0",
                signal: 11,
                terminationReason: "Synthetic crash from \(syntheticDiagnosticArgument)",
                callStackTree: tree
            ),
            NativeDiagnosticInput(
                kind: .hang,
                osVersion: osVersion,
                timestampBegin: now.addingTimeInterval(-60),
                timestampEnd: now,
                hangDurationSeconds: 2.5,
                callStackTree: tree
            )
        ]
    }
#endif
}
