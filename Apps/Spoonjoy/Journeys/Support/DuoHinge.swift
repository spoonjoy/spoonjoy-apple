import Foundation
import SpoonjoyCore
import XCTest

/// Folds and opens the iPhone Duo simulator from inside a journey. Only Device Hub, on the Mac, can move the
/// simulator's hinge, so the journey writes a numbered request file and `scripts/duo/posture-driver.swift`, which the
/// Duo journeys job runs on the Mac, presses the matching Device Hub button and answers with a `.done` file.
@MainActor
enum DuoHinge {
    enum Posture: String {
        case closed = "Closed"
        case open = "Open"
    }

    nonisolated static let directoryVariable = "SPOONJOY_DUO_POSTURE_DIR"
    /// A press reopens Device Hub, finds the button and waits eight seconds for the simulator to settle.
    private static let requestTimeout: TimeInterval = 90
    private static var sequence = 0

    /// Moves the hinge and waits until the simulator has settled in the new posture.
    static func set(_ posture: Posture, file: StaticString = #filePath, line: UInt = #line) throws {
        try send(posture.rawValue, file: file, line: line)
    }

    /// Turns the Duo a quarter turn clockwise, as Device Hub's Rotate Right does. The open Duo starts held sideways,
    /// and `XCUIDevice.orientation` does not turn the inner screen.
    static func rotateRight(file: StaticString = #filePath, line: UInt = #line) throws {
        try send("Rotate Right", file: file, line: line)
    }

    /// Saves the Mac's screenshots of both Duo displays, which show every window of the app at once.
    static func shot(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        try send("shot \(name)", file: file, line: line)
    }

    /// Has the Mac install `session` as the app's saved sign-in (the DEBUG file vault in the app's data container),
    /// so the next launch is signed in. On the Duo simulator the sign-in form's paste failed every way tried (runs
    /// 40110150926, 40111789546, 40113266863, 40114806670), and typing the password would record it in the result
    /// bundle. The session file sits in the driver's request directory, which is never uploaded, until the driver
    /// moves it.
    static func installSession(_ session: AuthSession, file: StaticString = #filePath, line: UInt = #line) throws {
        struct VaultFile: Encodable {
            let clientID: String
            let session: AuthSession
        }
        let data = try JSONEncoder().encode(VaultFile(clientID: session.clientID, session: session))
        try data.write(to: try requestDirectory().appendingPathComponent("session.json"), options: .atomic)
        try send("session", file: file, line: line)
    }

    private static func send(_ request: String, file: StaticString, line: UInt) throws {
        let directory = try requestDirectory()
        sequence += 1
        let base = directory.appendingPathComponent(String(format: "%02d", sequence))
        let done = base.appendingPathExtension("done")
        try Data(request.utf8).write(to: base.appendingPathExtension("request"), options: .atomic)
        let path = done.path
        let answered = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: path) },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [answered], timeout: requestTimeout),
            .completed,
            "The posture driver did not answer \"\(request)\" within \(Int(requestTimeout)) seconds.",
            file: file,
            line: line
        )
        let outcome = try String(contentsOf: done, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(outcome, "ok", "The posture driver could not do \"\(request)\".", file: file, line: line)
    }

    private static func requestDirectory() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment[directoryVariable], !path.isEmpty else {
            throw DuoHingeError.missingDirectory
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

enum DuoHingeError: Error, CustomStringConvertible {
    case missingDirectory

    var description: String {
        "\(DuoHinge.directoryVariable) is not set. The Duo journeys job passes the posture driver's request directory as TEST_RUNNER_\(DuoHinge.directoryVariable)."
    }
}
