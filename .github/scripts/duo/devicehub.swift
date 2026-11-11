// Drives Xcode's DeviceHub app through accessibility, for the Duo tour workflow.
//   devicehub dump                       print the window's buttons (description, help and frame)
//   devicehub wait <desc> [seconds]      wait until a button whose description or help matches appears (default 120 s)
//   devicehub press <desc> [<desc> ...]  press each button in order, pausing DEVICEHUB_PAUSE seconds (default 4) between
//
// Searches start at DeviceHub's windows, read each element in one accessibility call, match only buttons and stop once
// every requested button is found. A full walk from the application root, once per press, took tens of seconds on a CI
// runner, and three of them ran a 4-minute step out of time (spoonjoy-apple run 42939127260). One `press` call finds a
// whole sequence in one walk.
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

// Role, description, help and children in one accessibility call; a missing attribute comes back as an AXValue error.
let wanted = [kAXRoleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXChildrenAttribute] as CFArray

struct Node {
    let element: AXUIElement
    let role: String
    let description: String
    let help: String
    let children: [AXUIElement]
}

func node(_ e: AXUIElement) -> Node {
    var values: CFArray?
    AXUIElementCopyMultipleAttributeValues(e, wanted, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
    let list = (values as? [AnyObject]) ?? []
    func at(_ i: Int) -> AnyObject? { i < list.count ? list[i] : nil }
    return Node(element: e, role: (at(0) as? String) ?? "", description: (at(1) as? String) ?? "",
                help: (at(2) as? String) ?? "", children: (at(3) as? [AXUIElement]) ?? [])
}

// The pose buttons sit in DeviceHub's window (the bottom bar beside Home and Screenshot), so searches start at the
// windows and skip the menu bar, whose every menu item a search from the application root would visit first.
func windows(_ app: AXUIElement) -> [AXUIElement] {
    let list = (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    return list.isEmpty ? [app] : list
}

// One walk, breadth first, that stops once every query has a button; returns the buttons found by query.
func buttons(_ queries: Set<String>, in app: AXUIElement, deadline: Date) -> [String: AXUIElement] {
    var found: [String: AXUIElement] = [:]
    var queue: [(AXUIElement, Int)] = windows(app).map { ($0, 0) }
    var index = 0
    while index < queue.count, found.count < queries.count, Date() < deadline {
        let (e, depth) = queue[index]
        index += 1
        let n = node(e)
        if n.role == "AXButton" {
            for q in [n.description, n.help] where queries.contains(q) && found[q] == nil { found[q] = e }
        }
        if depth < 40 { queue.append(contentsOf: n.children.map { ($0, depth + 1) }) }
    }
    return found
}

func everyButton(in app: AXUIElement, deadline: Date) -> [AXUIElement] {
    var out: [AXUIElement] = []
    var queue: [(AXUIElement, Int)] = windows(app).map { ($0, 0) }
    var index = 0
    while index < queue.count, Date() < deadline {
        let (e, depth) = queue[index]
        index += 1
        let n = node(e)
        if n.role == "AXButton" { out.append(e) }
        if depth < 40 { queue.append(contentsOf: n.children.map { ($0, depth + 1) }) }
    }
    return out
}

func seconds(_ text: String?, default value: Double, name: String) -> Double {
    guard let text, !text.isEmpty else { return value }
    guard let parsed = Double(text), parsed >= 0 else { say("\(name) is not a number of seconds: \(text)"); exit(64) }
    return parsed
}

guard AXIsProcessTrusted() else { say("not trusted for accessibility"); exit(3) }

let args = CommandLine.arguments
let command = args.count > 1 ? args[1] : "dump"
let started = Date()
let waitLimit = command == "wait" ? seconds(args.count > 3 ? args[3] : nil, default: 120, name: "wait limit") : 10
let pause = seconds(ProcessInfo.processInfo.environment["DEVICEHUB_PAUSE"], default: 4, name: "DEVICEHUB_PAUSE")

// `wait` allows DeviceHub time to launch; every other command expects it running and fails fast if it has died.
var pid = deviceHubPID()
while pid == nil, Date().timeIntervalSince(started) < waitLimit {
    usleep(1_000_000)
    pid = deviceHubPID()
}
guard let pid else { say("no DeviceHub process"); exit(1) }
let app = AXUIElementCreateApplication(pid)
// SwiftUI and Catalyst apps build their accessibility tree only once an assistive client asks.
AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
usleep(1_500_000)

switch command {
case "wait":
    guard args.count > 2 else { say("usage: devicehub wait <desc> [seconds]"); exit(64) }
    let query = args[2]
    let deadline = started.addingTimeInterval(waitLimit)
    while Date() < deadline {
        if buttons([query], in: app, deadline: deadline)[query] != nil {
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
    let began = Date()
    var found = buttons(Set(queries), in: app, deadline: began.addingTimeInterval(90))
    say("found \(found.count) of \(Set(queries).count) buttons in \(String(format: "%.1f", Date().timeIntervalSince(began))) s")
    for (i, query) in queries.enumerated() {
        if i > 0 { usleep(useconds_t(pause * 1_000_000)) }
        var result = AXError.invalidUIElement
        if let e = found[query] { result = AXUIElementPerformAction(e, kAXPressAction as CFString) }
        // A pose change can rebuild the window and invalidate a button found before it; look it up again once.
        if result != .success {
            found[query] = buttons([query], in: app, deadline: Date().addingTimeInterval(60))[query]
            guard let e = found[query] else { say("not found: \(query)"); exit(2) }
            result = AXUIElementPerformAction(e, kAXPressAction as CFString)
        }
        say("pressed \(query): \(result.rawValue)")
        guard result == .success else { exit(4) }
    }
default:
    // Bounded, so a dump printed as a failure diagnostic finishes inside the step's time limit.
    for e in everyButton(in: app, deadline: started.addingTimeInterval(90)) {
        print(str(e, kAXDescriptionAttribute), "|", str(e, kAXHelpAttribute), "|", frame(e))
    }
}
