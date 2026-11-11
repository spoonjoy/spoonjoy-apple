// Drives Xcode's DeviceHub app through accessibility, for the Duo tour workflow.
//   devicehub dump                       print the window's buttons (description, help and frame)
//   devicehub wait <desc> [seconds]      wait until a button whose description or help matches appears (default 120 s)
//   devicehub press <desc> [<desc> ...]  press each button in order, pausing DEVICEHUB_PAUSE seconds (default 4) after each
//
// Every search stops at the first match, breadth first, instead of walking DeviceHub's whole accessibility tree: a full
// walk took tens of seconds on a CI runner, and three of them ran a 4-minute step out of time (spoonjoy-apple run
// 42939127260). One `press` call handles a whole sequence, so DeviceHub is asked to build its tree only once.
import AppKit
import ApplicationServices
import Foundation

func attr(_ e: AXUIElement, _ a: String) -> AnyObject? {
    var v: AnyObject?
    AXUIElementCopyAttributeValue(e, a as CFString, &v)
    return v
}

func str(_ e: AXUIElement, _ a: String) -> String {
    (attr(e, a) as? String) ?? ""
}

func children(_ e: AXUIElement) -> [AXUIElement] {
    (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func frame(_ e: AXUIElement) -> String {
    var p = CGPoint.zero, s = CGSize.zero
    if let v = attr(e, kAXPositionAttribute) { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
    if let v = attr(e, kAXSizeAttribute) { AXValueGetValue(v as! AXValue, .cgSize, &s) }
    return "\(Int(p.x)),\(Int(p.y)) \(Int(s.width))x\(Int(s.height))"
}

func stamp() -> String { ISO8601DateFormatter().string(from: Date()) }

func say(_ line: String) {
    print("[devicehub \(stamp())] \(line)")
    fflush(stdout)
}

// DeviceHub's NSRunningApplication reports pid -1, so find the process by its executable path.
func deviceHubPID() -> pid_t? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    p.arguments = ["-f", "DeviceHub.app/Contents/MacOS"]
    let out = Pipe()
    p.standardOutput = out
    try? p.run()
    p.waitUntilExit()
    let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return text.split(separator: "\n").compactMap { pid_t($0) }.first
}

func matches(_ e: AXUIElement, _ query: String) -> Bool {
    str(e, kAXDescriptionAttribute) == query || str(e, kAXHelpAttribute) == query
}

// Breadth first, so the window's toolbar (where the pose buttons live) is reached before deep content.
func first(in root: AXUIElement, where test: (AXUIElement) -> Bool) -> AXUIElement? {
    var queue: [(AXUIElement, Int)] = [(root, 0)]
    var index = 0
    while index < queue.count {
        let (e, depth) = queue[index]
        index += 1
        if test(e) { return e }
        if depth < 40 { queue.append(contentsOf: children(e).map { ($0, depth + 1) }) }
    }
    return nil
}

func everything(in root: AXUIElement) -> [AXUIElement] {
    var all: [AXUIElement] = []
    func walk(_ e: AXUIElement, _ depth: Int) {
        all.append(e)
        if depth < 40 { children(e).forEach { walk($0, depth + 1) } }
    }
    walk(root, 0)
    return all
}

guard AXIsProcessTrusted() else { say("not trusted for accessibility"); exit(3) }

let args = CommandLine.arguments
let command = args.count > 1 ? args[1] : "dump"
let started = Date()
let waitLimit = command == "wait" && args.count > 3 ? (Double(args[3]) ?? 120) : 120

// DeviceHub may still be launching; wait for its process within the same limit as `wait`.
var pid = deviceHubPID()
while pid == nil, Date().timeIntervalSince(started) < waitLimit {
    usleep(1_000_000)
    pid = deviceHubPID()
}
guard let pid else { say("no DeviceHub process"); exit(1) }
let root = AXUIElementCreateApplication(pid)
// SwiftUI and Catalyst apps build their accessibility tree only once an assistive client asks.
AXUIElementSetAttributeValue(root, "AXManualAccessibility" as CFString, kCFBooleanTrue)
usleep(1_500_000)

switch command {
case "wait":
    guard args.count > 2 else { say("usage: devicehub wait <desc> [seconds]"); exit(64) }
    let query = args[2]
    while Date().timeIntervalSince(started) < waitLimit {
        if first(in: root, where: { matches($0, query) }) != nil {
            say("found \(query) after \(Int(Date().timeIntervalSince(started))) s")
            exit(0)
        }
        usleep(2_000_000)
    }
    say("not found within \(Int(waitLimit)) s: \(query)")
    exit(2)
case "press":
    let queries = Array(args.dropFirst(2))
    guard !queries.isEmpty else { say("usage: devicehub press <desc> [<desc> ...]"); exit(64) }
    let pause = Double(ProcessInfo.processInfo.environment["DEVICEHUB_PAUSE"] ?? "") ?? 4
    for query in queries {
        let began = Date()
        guard let e = first(in: root, where: { matches($0, query) }) else {
            say("not found: \(query)")
            exit(2)
        }
        let result = AXUIElementPerformAction(e, kAXPressAction as CFString)
        say("pressed \(query): \(result.rawValue) (found in \(String(format: "%.1f", Date().timeIntervalSince(began))) s)")
        guard result == .success else { exit(4) }
        usleep(useconds_t(pause * 1_000_000))
    }
default:
    for e in everything(in: root) where str(e, kAXRoleAttribute) == "AXButton" {
        print(str(e, kAXDescriptionAttribute), "|", str(e, kAXHelpAttribute), "|", frame(e))
    }
}
