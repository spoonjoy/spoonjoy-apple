import Foundation
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

    /// Saves the Mac's screenshots of both Duo displays, which show every window of the app at once.
    static func shot(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        try send("shot \(name)", file: file, line: line)
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
