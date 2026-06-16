import CoreGraphics
import Foundation

struct WindowCandidate {
  let number: Int
  let owner: String
  let name: String
  let layer: Int
  let area: Double
}

func intValue(_ value: Any?) -> Int? {
  if let number = value as? NSNumber {
    return number.intValue
  }
  return value as? Int
}

func doubleValue(_ value: Any?) -> Double? {
  if let number = value as? NSNumber {
    return number.doubleValue
  }
  return value as? Double
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let pidArgument = arguments.first, let targetPID = Int(pidArgument) else {
  fputs("usage: find-macos-window-id.swift <pid> [preferred-window-name]\n", stderr)
  exit(2)
}
let preferredName = arguments.dropFirst().first ?? ""

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
func candidate(from window: [String: Any]) -> WindowCandidate? {
  guard let number = intValue(window[kCGWindowNumber as String]) else {
    return nil
  }

  let layer = intValue(window[kCGWindowLayer as String]) ?? 0
  guard layer == 0 else {
    return nil
  }

  let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
  let width = doubleValue(bounds["Width"]) ?? 0
  let height = doubleValue(bounds["Height"]) ?? 0
  guard width > 0, height > 0 else {
    return nil
  }

  return WindowCandidate(
    number: number,
    owner: window[kCGWindowOwnerName as String] as? String ?? "",
    name: window[kCGWindowName as String] as? String ?? "",
    layer: layer,
    area: width * height
  )
}

func preferredWindow(from candidates: [WindowCandidate]) -> WindowCandidate? {
  candidates.first(where: { $0.name == preferredName })
    ?? candidates.first(where: { !preferredName.isEmpty && $0.name.localizedCaseInsensitiveContains(preferredName) })
    ?? candidates.sorted(by: { $0.area > $1.area }).first
}

let pidCandidates = windows.compactMap { window -> WindowCandidate? in
  guard intValue(window[kCGWindowOwnerPID as String]) == targetPID else {
    return nil
  }
  return candidate(from: window)
}
let ownerCandidates = windows.compactMap { window -> WindowCandidate? in
  guard window[kCGWindowOwnerName as String] as? String == "Spoonjoy" else {
    return nil
  }
  return candidate(from: window)
}

if let preferred = preferredWindow(from: pidCandidates) ?? preferredWindow(from: ownerCandidates) {
  print(preferred.number)
  exit(0)
}

fputs("No on-screen layer-0 window found for PID \(targetPID).\n", stderr)
let nearby = windows.compactMap { window -> String? in
  guard intValue(window[kCGWindowOwnerPID as String]) == targetPID else {
    return nil
  }
  let owner = window[kCGWindowOwnerName as String] as? String ?? ""
  let name = window[kCGWindowName as String] as? String ?? ""
  let number = intValue(window[kCGWindowNumber as String]) ?? -1
  let layer = intValue(window[kCGWindowLayer as String]) ?? -1
  return "window[number=\(number), owner=\(owner), name=\(name), layer=\(layer)]"
}
if nearby.isEmpty {
  fputs("No windows were reported for PID \(targetPID).\n", stderr)
} else {
  fputs(nearby.joined(separator: "\n") + "\n", stderr)
}
exit(1)
