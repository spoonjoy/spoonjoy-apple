import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native journey launch reset")
struct NativeJourneyLaunchResetTests {
    @Test("reset is requested only by truthy launch values")
    func resetRequestParsing() {
        let key = NativeJourneyLaunchReset.environmentKey
        #expect(key == "SPOONJOY_JOURNEY_RESET_STATE")
        #expect(NativeJourneyLaunchReset.isRequested(environment: [key: "1"]))
        #expect(NativeJourneyLaunchReset.isRequested(environment: [key: "true"]))
        #expect(NativeJourneyLaunchReset.isRequested(environment: [key: " YES "]))
        #expect(!NativeJourneyLaunchReset.isRequested(environment: [:]))
        #expect(!NativeJourneyLaunchReset.isRequested(environment: [key: ""]))
        #expect(!NativeJourneyLaunchReset.isRequested(environment: [key: "0"]))
        #expect(!NativeJourneyLaunchReset.isRequested(environment: [key: "no"]))
    }

    @Test("without a request the app state stays in place")
    func notRequestedKeepsState() throws {
        try withResetDirectory { directory in
            let state = directory.appendingPathComponent("native-app-state.json")
            let session = directory.appendingPathComponent("debug-auth-session.json")
            try Data("{}".utf8).write(to: state)
            try Data("{}".utf8).write(to: session)

            let removed = try NativeJourneyLaunchReset.resetIfRequested(environment: [:], appDirectory: directory)

            #expect(!removed)
            #expect(FileManager.default.fileExists(atPath: state.path))
            #expect(FileManager.default.fileExists(atPath: session.path))
        }
    }

    @Test("a requested reset removes files and nested directories but keeps the app directory")
    func requestedResetRemovesChildren() throws {
        try withResetDirectory { directory in
            try Data("{}".utf8).write(to: directory.appendingPathComponent("native-app-state.json"))
            try Data("{}".utf8).write(to: directory.appendingPathComponent("debug-auth-session.json"))
            let media = directory.appendingPathComponent("native-staged-media", isDirectory: true)
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
            try Data("jpg".utf8).write(to: media.appendingPathComponent("photo.jpg"))

            let removed = try NativeJourneyLaunchReset.resetIfRequested(
                environment: [NativeJourneyLaunchReset.environmentKey: "1"],
                appDirectory: directory
            )

            #expect(removed)
            #expect(FileManager.default.fileExists(atPath: directory.path))
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test("a requested reset of an empty directory reports that nothing was removed")
    func requestedResetOfEmptyDirectory() throws {
        try withResetDirectory { directory in
            let removed = try NativeJourneyLaunchReset.resetIfRequested(
                environment: [NativeJourneyLaunchReset.environmentKey: "true"],
                appDirectory: directory
            )

            #expect(!removed)
            #expect(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @Test("a requested reset of a missing directory is a no-op")
    func requestedResetOfMissingDirectory() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-journey-reset-missing-\(UUID().uuidString)", isDirectory: true)

        let removed = try NativeJourneyLaunchReset.resetIfRequested(
            environment: [NativeJourneyLaunchReset.environmentKey: "1"],
            appDirectory: missing
        )

        #expect(!removed)
        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }

    @Test("a child that cannot be removed fails the reset")
    func unremovableChildThrows() throws {
        try withResetDirectory { directory in
            try Data("{}".utf8).write(to: directory.appendingPathComponent("native-app-state.json"))
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            }

            #expect(throws: (any Error).self) {
                try NativeJourneyLaunchReset.resetIfRequested(
                    environment: [NativeJourneyLaunchReset.environmentKey: "1"],
                    appDirectory: directory
                )
            }
        }
    }
}

private func withResetDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("spoonjoy-journey-reset-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}
