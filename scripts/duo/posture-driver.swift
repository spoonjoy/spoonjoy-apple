// Folds and opens the iPhone Duo simulator for the Duo journey, which runs inside the simulator and cannot reach
// Device Hub itself.
//
// Usage: posture-driver <request directory> <simulator udid> <screenshot directory>
//
// The journey writes `<n>.request` holding a Device Hub hinge button ("Closed", "Partially Open" or "Open") or
// "shot <name>". The driver presses the button in Device Hub (or saves both displays' screenshots), waits for the
// simulator to settle, and writes `<n>.done`. It handles requests in order and stops when `stop` appears or after
// two hours.
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: posture-driver <request directory> <udid> <screenshot directory>\n".utf8))
    exit(64)
}
let requests = URL(fileURLWithPath: arguments[1], isDirectory: true)
let udid = arguments[2]
let shots = URL(fileURLWithPath: arguments[3], isDirectory: true)
try? FileManager.default.createDirectory(at: requests, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)

func log(_ message: String) {
    print("[posture-driver \(ISO8601DateFormatter().string(from: Date()))] \(message)")
    fflush(stdout)
}

func run(_ executable: String, _ args: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
    } catch {
        return (-1, "\(error)")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

func text(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
}

/// Device Hub's NSRunningApplication reports pid -1, so the process is found by its executable path.
func deviceHubPID() -> pid_t? {
    run("/usr/bin/pgrep", ["-f", "DeviceHub.app/Contents/MacOS"]).output
        .split(separator: "\n").compactMap { pid_t($0) }.first
}

func findButton(described description: String) -> AXUIElement? {
    guard let pid = deviceHubPID() else {
        log("no Device Hub process")
        return nil
    }
    let root = AXUIElementCreateApplication(pid)
    // SwiftUI apps build their accessibility tree only once an assistive client asks for it.
    AXUIElementSetAttributeValue(root, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(root, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    var queue: [(AXUIElement, Int)] = [(root, 0)]
    while !queue.isEmpty {
        let (element, depth) = queue.removeFirst()
        if text(element, kAXRoleAttribute) == "AXButton", text(element, kAXDescriptionAttribute) == description {
            return element
        }
        if depth < 12, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
            queue += children.map { ($0, depth + 1) }
        }
    }
    return nil
}

func center(of element: AXUIElement) -> CGPoint? {
    var position = CGPoint.zero
    var size = CGSize.zero
    guard let positionValue = attribute(element, kAXPositionAttribute),
          let sizeValue = attribute(element, kAXSizeAttribute) else {
        return nil
    }
    // swiftlint:disable:next force_cast
    AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
    // swiftlint:disable:next force_cast
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
}

/// A real click at the button's centre: the probe run (40067861333) showed a click opens the Duo, and an AX press
/// on these SwiftUI toolbar buttons is not proven.
func click(_ point: CGPoint) {
    let source = CGEventSource(stateID: .hidSystemState)
    [CGEventType.leftMouseDown, .leftMouseUp].forEach { type in
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(80_000)
    }
}

func press(_ description: String) -> Bool {
    _ = run("/usr/bin/open", ["-a", "/Applications/Xcode_27.1.app/Contents/Applications/DeviceHub.app"])
    usleep(1_500_000)
    // Device Hub takes a while to list a freshly booted simulator, so the button is looked for for up to a minute.
    let found = (0..<20).lazy.compactMap { attempt -> CGPoint? in
        if attempt > 0 {
            sleep(3)
        }
        return findButton(described: description).flatMap(center(of:))
    }.first
    guard let point = found else {
        log("Device Hub has no \(description) button")
        return false
    }
    log("clicking \(description) at \(point)")
    click(point)
    // The simulator swaps displays and relays out its windows after a hinge change.
    sleep(8)
    return true
}

func screenshot(_ name: String) {
    // Display 1 is the outer screen and 3 the inner one on the Duo (probe run 40067861333).
    ["1": "", "3": "-inner"].forEach { display, suffix in
        let path = shots.appendingPathComponent("\(name)\(suffix).png").path
        let result = run("/usr/bin/xcrun", ["simctl", "io", udid, "screenshot", "--display=\(display)", path])
        log("screenshot \(name) display \(display): \(result.status) \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}

log("watching \(requests.path) for \(udid); accessibility trusted: \(AXIsProcessTrusted())")
let deadline = Date().addingTimeInterval(2 * 60 * 60)
var next = 1
while Date() < deadline {
    if FileManager.default.fileExists(atPath: requests.appendingPathComponent("stop").path) {
        log("stop requested")
        break
    }
    let base = requests.appendingPathComponent(String(format: "%02d", next))
    guard let request = try? String(contentsOf: base.appendingPathExtension("request"), encoding: .utf8) else {
        usleep(250_000)
        continue
    }
    let command = request.trimmingCharacters(in: .whitespacesAndNewlines)
    log("request \(next): \(command)")
    let outcome: String
    if command.hasPrefix("shot ") {
        screenshot(String(command.dropFirst("shot ".count)))
        outcome = "ok"
    } else {
        outcome = press(command) ? "ok" : "missing"
    }
    try? Data(outcome.utf8).write(to: base.appendingPathExtension("done"))
    next += 1
}
log("done after \(next - 1) request(s)")
