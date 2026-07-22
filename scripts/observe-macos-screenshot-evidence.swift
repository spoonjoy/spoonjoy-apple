#!/usr/bin/env swift

import AppKit
import ApplicationServices
import CryptoKit
import Darwin
import Foundation

struct AXObservedRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var isEmpty: Bool { width <= 0 || height <= 0 }

    func contains(_ other: AXObservedRect) -> Bool {
        !other.isEmpty
            && other.minX >= minX - 0.5
            && other.minY >= minY - 0.5
            && other.maxX <= maxX + 0.5
            && other.maxY <= maxY + 0.5
    }

    func intersection(with other: AXObservedRect) -> AXObservedRect? {
        let left = max(minX, other.minX)
        let top = max(minY, other.minY)
        let right = min(maxX, other.maxX)
        let bottom = min(maxY, other.maxY)
        guard right > left, bottom > top else { return nil }
        return AXObservedRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}

struct AXObservedElement: Codable {
    let identifier: String
    let role: String
    let subrole: String
    let title: String
    let frame: AXObservedRect
    let enabled: Bool
    let focused: Bool
    let actions: [String]
}

struct AXObservedNode {
    let element: AXUIElement
    let observation: AXObservedElement
}

enum AXObservedFindingKind: String, Codable {
    case requiredIdentifierMissing
    case outsideViewport
    case peerOverlap
    case textOverlap
    case actionTargetTooSmall
    case apnsChromeIntersection
    case deepScrollUnavailable
    case terminalSemanticMismatch
}

struct AXObservedFinding: Codable {
    let kind: AXObservedFindingKind
    let identifiers: [String]
    let message: String
    let intersection: AXObservedRect?
}

struct AXObservedDeepScrollEvidence: Codable {
    let route: String
    let reachedTerminal: Bool
    let scrollAreaIdentifier: String
    let initialScrollValue: Double?
    let finalScrollValue: Double?
    let contentViewport: AXObservedRect
    let terminalElement: AXObservedElement?
    let findings: [AXObservedFinding]
}

struct AXObservedEvidence: Codable {
    let platform: String
    let route: String
    let captureRunNonce: String
    let readinessProofSHA256: String
    let screenshotSHA256: String
    let pid: Int32
    let bundleIdentifier: String
    let bundlePath: String
    let executablePath: String
    let executableSHA256: String
    let windowFrames: [AXObservedRect]
    let elements: [AXObservedElement]
    let findings: [AXObservedFinding]
    let deepScroll: AXObservedDeepScrollEvidence?
    let recordedAt: String
}

struct AXRouteTerminalExpectation {
    let scrollIdentifier: String
    let terminalIdentifier: String
    let terminalTitle: String?
    let role: String
    let requiredAction: String?
}

struct Options {
    let pid: pid_t
    let route: String
    let captureRunNonce: String
    let readinessProofPath: String
    let screenshotPath: String
    let expectedBundleIdentifier: String
    let expectedBundlePath: String
    let expectedExecutablePath: String
    let outputPath: String
    let requiredIdentifiers: Set<String>
    let peerPairs: [(String, String)]
    let observesAPNs: Bool
    let signedIn: Bool
    let preflightOnly: Bool
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
}

func parseOptions() -> Options {
    var values: [String: String] = [:]
    var requiredIdentifierSet: Set<String> = []
    var peerPairs: [(String, String)] = []
    var observesAPNs = false
    var signedIn = true
    var preflightOnly = false
    var index = 1
    let arguments = CommandLine.arguments
    while index < arguments.count {
        let argument = arguments[index]
        if argument == "--apns" {
            observesAPNs = true
            index += 1
            continue
        }
        if argument == "--signed-out" {
            signedIn = false
            index += 1
            continue
        }
        if argument == "--preflight" {
            preflightOnly = true
            index += 1
            continue
        }
        guard index + 1 < arguments.count else { fail("missing value for \(argument)") }
        let value = arguments[index + 1]
        switch argument {
        case "--required-identifier":
            requiredIdentifierSet.insert(value)
        case "--peer":
            let pair = value.split(separator: ":", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { fail("--peer requires first:second") }
            peerPairs.append((pair[0], pair[1]))
        default:
            values[argument] = value
        }
        index += 2
    }

    guard let rawPID = values["--pid"], let pid = pid_t(rawPID), pid > 0 else { fail("--pid is required") }
    guard let bundleIdentifier = values["--bundle-id"], !bundleIdentifier.isEmpty else { fail("--bundle-id is required") }
    guard let bundlePath = values["--bundle-path"], !bundlePath.isEmpty else { fail("--bundle-path is required") }
    guard let executablePath = values["--executable-path"], !executablePath.isEmpty else { fail("--executable-path is required") }
    guard let outputPath = values["--output"], !outputPath.isEmpty else { fail("--output is required") }
    guard let route = values["--route"], !route.isEmpty else { fail("--route is required") }
    guard let captureRunNonce = values["--capture-run-nonce"], UUID(uuidString: captureRunNonce) != nil else {
        fail("--capture-run-nonce must be a UUID")
    }
    guard let readinessProofPath = values["--readiness-proof-path"], !readinessProofPath.isEmpty else {
        fail("--readiness-proof-path is required")
    }
    guard let screenshotPath = values["--screenshot-path"], !screenshotPath.isEmpty else {
        fail("--screenshot-path is required")
    }

    if observesAPNs {
        requiredIdentifierSet.formUnion([
            "settings.apns.this-device.heading",
            "settings.apns.push-delivery.heading",
            "settings.apns.notification-sync.heading"
        ])
    }
    requiredIdentifierSet.formUnion(requiredIdentifiers(for: route))
    return Options(
        pid: pid,
        route: route,
        captureRunNonce: captureRunNonce,
        readinessProofPath: readinessProofPath,
        screenshotPath: screenshotPath,
        expectedBundleIdentifier: bundleIdentifier,
        expectedBundlePath: bundlePath,
        expectedExecutablePath: executablePath,
        outputPath: outputPath,
        requiredIdentifiers: requiredIdentifierSet,
        peerPairs: peerPairs,
        observesAPNs: observesAPNs,
        signedIn: signedIn,
        preflightOnly: preflightOnly
    )
}

func canonicalPath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
}

func requiredFileData(at path: String, label: String) -> Data {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), !data.isEmpty else {
        fail("\(label) is missing or empty")
    }
    return data
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func validateReadinessProof(_ data: Data, options: Options) {
    guard let proof = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fail("readiness proof must be a JSON object")
    }
    guard proof["platform"] as? String == "macos" else {
        fail("readiness proof platform does not match macOS")
    }
    guard proof["route"] as? String == options.route else {
        fail("readiness proof route does not match expected route")
    }
    guard proof["captureRunNonce"] as? String == options.captureRunNonce else {
        fail("readiness proof capture nonce does not match the observer run")
    }
    guard proof["bundleIdentifier"] as? String == options.expectedBundleIdentifier else {
        fail("readiness proof bundle identifier does not match the exact application")
    }
}

func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value
}

func elementAttribute(_ element: AXUIElement, _ name: CFString) -> AXUIElement? {
    guard let rawValue = attribute(element, name), CFGetTypeID(rawValue) == AXUIElementGetTypeID() else {
        return nil
    }
    return unsafeBitCast(rawValue, to: AXUIElement.self)
}

func stringAttribute(_ element: AXUIElement, _ name: CFString) -> String {
    attribute(element, name) as? String ?? ""
}

func semanticText(of element: AXUIElement) -> String {
    for attributeName in [
        kAXTitleAttribute as CFString,
        kAXDescriptionAttribute as CFString,
        kAXValueAttribute as CFString
    ] {
        let value = stringAttribute(element, attributeName).trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { return value }
    }
    return ""
}

func boolAttribute(_ element: AXUIElement, _ name: CFString, default defaultValue: Bool) -> Bool {
    attribute(element, name) as? Bool ?? defaultValue
}

func numberAttribute(_ element: AXUIElement, _ name: CFString) -> Double? {
    (attribute(element, name) as? NSNumber)?.doubleValue
}

func pointAttribute(_ element: AXUIElement, _ name: CFString) -> CGPoint? {
    guard let rawValue = attribute(element, name), CFGetTypeID(rawValue) == AXValueGetTypeID() else { return nil }
    let value = unsafeBitCast(rawValue, to: AXValue.self)
    var point = CGPoint.zero
    return AXValueGetValue(value, .cgPoint, &point) ? point : nil
}

func sizeAttribute(_ element: AXUIElement, _ name: CFString) -> CGSize? {
    guard let rawValue = attribute(element, name), CFGetTypeID(rawValue) == AXValueGetTypeID() else { return nil }
    let value = unsafeBitCast(rawValue, to: AXValue.self)
    var size = CGSize.zero
    return AXValueGetValue(value, .cgSize, &size) ? size : nil
}

func normalizedObservedRect(x: Double, y: Double, width: Double, height: Double) -> AXObservedRect {
    let values = [x, y, width, height]
    guard values.allSatisfy(\.isFinite) else {
        return AXObservedRect(x: 0, y: 0, width: 0, height: 0)
    }
    return AXObservedRect(x: x, y: y, width: width, height: height)
}

func frame(of element: AXUIElement) -> AXObservedRect {
    let position = pointAttribute(element, kAXPositionAttribute as CFString) ?? .zero
    let size = sizeAttribute(element, kAXSizeAttribute as CFString) ?? .zero
    return normalizedObservedRect(
        x: Double(position.x),
        y: Double(position.y),
        width: Double(size.width),
        height: Double(size.height)
    )
}

func childElements(of element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []
}

func actionNames(of element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
    return names as? [String] ?? []
}

func observeTree(root: AXUIElement) -> [AXObservedNode] {
    var observations: [AXObservedNode] = []
    var queue: [(AXUIElement, Int)] = [(root, 0)]
    while !queue.isEmpty && observations.count < 10_000 {
        let (element, depth) = queue.removeFirst()
        let observation = AXObservedElement(
            identifier: stringAttribute(element, kAXIdentifierAttribute as CFString),
            role: stringAttribute(element, kAXRoleAttribute as CFString),
            subrole: stringAttribute(element, kAXSubroleAttribute as CFString),
            title: semanticText(of: element),
            frame: frame(of: element),
            enabled: boolAttribute(element, kAXEnabledAttribute as CFString, default: true),
            focused: boolAttribute(element, kAXFocusedAttribute as CFString, default: false),
            actions: actionNames(of: element)
        )
        observations.append(AXObservedNode(element: element, observation: observation))
        if depth < 80 {
            queue.append(contentsOf: childElements(of: element).map { ($0, depth + 1) })
        }
    }
    return observations
}

func terminalExpectation(for route: String) -> AXRouteTerminalExpectation? {
    switch route {
    case "kitchen":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "kitchen.cookbook.cookbook_slow_sundays",
            terminalTitle: "Slow Sundays and Long Simmering Suppers, 0 recipes",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "recipe-editor":
        AXRouteTerminalExpectation(
            scrollIdentifier: "recipe-editor.scroll",
            terminalIdentifier: "recipe-editor.delete",
            terminalTitle: nil,
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "recipe-covers":
        AXRouteTerminalExpectation(
            scrollIdentifier: "recipe-covers.scroll",
            terminalIdentifier: "recipe-covers.archive.cover_primary",
            terminalTitle: nil,
            role: kAXStaticTextRole as String,
            requiredAction: nil
        )
    case "profile":
        AXRouteTerminalExpectation(
            scrollIdentifier: "profile.scroll",
            terminalIdentifier: "profile.graph.kitchen-visitors",
            terminalTitle: nil,
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    default:
        nil
    }
}

func isScrollContainer(_ element: AXUIElement) -> Bool {
    stringAttribute(element, kAXRoleAttribute as CFString) == (kAXScrollAreaRole as String)
        || elementAttribute(element, kAXVerticalScrollBarAttribute as CFString) != nil
}

func enclosingScrollArea(for node: AXObservedNode) -> AXUIElement? {
    if isScrollContainer(node.element) {
        return node.element
    }

    var current = node.element
    for _ in 0..<40 {
        guard let parent = elementAttribute(current, kAXParentAttribute as CFString) else { break }
        if isScrollContainer(parent) {
            return parent
        }
        current = parent
    }
    return nil
}

func terminalObservation(
    rootWindowElement: AXUIElement,
    expectation: AXRouteTerminalExpectation
) -> AXObservedElement? {
    observeTree(root: rootWindowElement).first(where: {
        $0.observation.identifier == expectation.terminalIdentifier
    })?.observation
}

func terminalMatches(
    _ element: AXObservedElement?,
    viewport: AXObservedRect,
    expectation: AXRouteTerminalExpectation
) -> Bool {
    element.map { candidate in
        candidate.role == expectation.role
            && candidate.enabled
            && expectation.terminalTitle.map { candidate.title == $0 } != false
            && viewport.contains(candidate.frame)
            && expectation.requiredAction.map(candidate.actions.contains) != false
    } ?? false
}

func nativeIncrementPageControl(in scrollArea: AXUIElement) -> AXUIElement? {
    guard let scrollBar = elementAttribute(scrollArea, kAXVerticalScrollBarAttribute as CFString) else {
        return nil
    }
    return observeTree(root: scrollBar).first(where: {
        $0.observation.subrole == "AXIncrementPage"
            && $0.observation.actions.contains(kAXPressAction as String)
    })?.element
}

func performNativePageScroll(in scrollArea: AXUIElement) -> Bool {
    let scrollDownByPageAction = "AXScrollDownByPage"
    if actionNames(of: scrollArea).contains(scrollDownByPageAction),
       AXUIElementPerformAction(scrollArea, scrollDownByPageAction as CFString) == .success {
        return true
    }
    guard let pageControl = nativeIncrementPageControl(in: scrollArea) else { return false }
    return AXUIElementPerformAction(pageControl, kAXPressAction as CFString) == .success
}

func scrollByPageToTerminal(
    rootWindowElement: AXUIElement,
    scrollArea: AXUIElement,
    viewport: AXObservedRect,
    route: String,
    expectation: AXRouteTerminalExpectation
) -> AXObservedDeepScrollEvidence {
    let scrollDownByPageAction = "AXScrollDownByPage"
    let supportsPageScroll = actionNames(of: scrollArea).contains(scrollDownByPageAction)
    var pageCount = 0
    var consecutiveMatches = 0
    var terminalElement: AXObservedElement?

    for _ in 0..<80 {
        let candidate = terminalObservation(
            rootWindowElement: rootWindowElement,
            expectation: expectation
        )
        if terminalMatches(candidate, viewport: viewport, expectation: expectation) {
            consecutiveMatches += 1
            terminalElement = candidate
            if consecutiveMatches >= 2 { break }
            Thread.sleep(forTimeInterval: 0.1)
            continue
        }

        consecutiveMatches = 0
        guard supportsPageScroll, performNativePageScroll(in: scrollArea) else { break }
        pageCount += 1
        Thread.sleep(forTimeInterval: 0.1)
    }

    var findings: [AXObservedFinding] = []
    if consecutiveMatches < 2 {
        let candidate = terminalObservation(
            rootWindowElement: rootWindowElement,
            expectation: expectation
        )
        if !supportsPageScroll {
            findings.append(AXObservedFinding(
                kind: .deepScrollUnavailable,
                identifiers: [expectation.scrollIdentifier],
                message: "The route-specific macOS scroll area exposes neither a numeric scrollbar nor page-scroll actions.",
                intersection: nil
            ))
        } else if let candidate, !viewport.contains(candidate.frame) {
            findings.append(AXObservedFinding(
                kind: .outsideViewport,
                identifiers: [expectation.terminalIdentifier],
                message: "The route-specific terminal element remained clipped or offscreen after page scrolling.",
                intersection: candidate.frame.intersection(with: viewport)
            ))
        } else if candidate != nil {
            findings.append(AXObservedFinding(
                kind: .terminalSemanticMismatch,
                identifiers: [expectation.terminalIdentifier],
                message: "The route-specific terminal element did not expose the required role, enabled state, and action.",
                intersection: nil
            ))
        } else {
            findings.append(AXObservedFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [expectation.terminalIdentifier],
                message: "The route-specific terminal identifier was not observed after page scrolling.",
                intersection: nil
            ))
        }
    }

    return AXObservedDeepScrollEvidence(
        route: route,
        reachedTerminal: consecutiveMatches >= 2 && findings.isEmpty,
        scrollAreaIdentifier: expectation.scrollIdentifier,
        initialScrollValue: 0,
        finalScrollValue: Double(pageCount),
        contentViewport: viewport,
        terminalElement: terminalElement,
        findings: findings
    )
}

func observeDeepScroll(
    rootWindowElement: AXUIElement,
    route: String,
    expectation: AXRouteTerminalExpectation
) -> AXObservedDeepScrollEvidence {
    let initialNodes = observeTree(root: rootWindowElement)
    let scrollAnchor = initialNodes.first(where: {
        $0.observation.identifier == expectation.scrollIdentifier
    }) ?? initialNodes.first(where: {
        $0.observation.identifier == expectation.terminalIdentifier
    })
    guard let scrollAnchor, let scrollArea = enclosingScrollArea(for: scrollAnchor) else {
        return AXObservedDeepScrollEvidence(
            route: route,
            reachedTerminal: false,
            scrollAreaIdentifier: expectation.scrollIdentifier,
            initialScrollValue: nil,
            finalScrollValue: nil,
            contentViewport: AXObservedRect(x: 0, y: 0, width: 0, height: 0),
            terminalElement: nil,
            findings: [AXObservedFinding(
                kind: .deepScrollUnavailable,
                identifiers: [expectation.scrollIdentifier],
                message: "The route-specific macOS scroll area was not observed.",
                intersection: nil
            )]
        )
    }

    let viewport = frame(of: scrollArea)
    guard let scrollBar = elementAttribute(scrollArea, kAXVerticalScrollBarAttribute as CFString) else {
        return scrollByPageToTerminal(
            rootWindowElement: rootWindowElement,
            scrollArea: scrollArea,
            viewport: viewport,
            route: route,
            expectation: expectation
        )
    }

    let normalizedScrollMaximum = 1.0
    let initialValue = numberAttribute(scrollBar, kAXValueAttribute as CFString)
    let reportedMaximum = numberAttribute(scrollBar, kAXMaxValueAttribute as CFString)
    guard reportedMaximum != nil || initialValue != nil else {
        return scrollByPageToTerminal(
            rootWindowElement: rootWindowElement,
            scrollArea: scrollArea,
            viewport: viewport,
            route: route,
            expectation: expectation
        )
    }
    let maximum = reportedMaximum ?? normalizedScrollMaximum
    var settable = DarwinBoolean(false)
    let settableResult = AXUIElementIsAttributeSettable(
        scrollBar,
        kAXValueAttribute as CFString,
        &settable
    )
    var setResult: AXError = .failure
    if settableResult == .success, settable.boolValue {
        setResult = AXUIElementSetAttributeValue(
            scrollBar,
            kAXValueAttribute as CFString,
            NSNumber(value: maximum)
        )
    }
    if setResult != .success, actionNames(of: scrollBar).contains(kAXIncrementAction as String) {
        for _ in 0..<80 {
            if let current = numberAttribute(scrollBar, kAXValueAttribute as CFString), abs(current - maximum) <= 0.001 {
                break
            }
            guard AXUIElementPerformAction(scrollBar, kAXIncrementAction as CFString) == .success else { break }
        }
    }

    var consecutiveMatches = 0
    var terminalElement: AXObservedElement?
    var finalValue = numberAttribute(scrollBar, kAXValueAttribute as CFString)
    for _ in 0..<24 {
        Thread.sleep(forTimeInterval: 0.1)
        finalValue = numberAttribute(scrollBar, kAXValueAttribute as CFString)
        let nodes = observeTree(root: rootWindowElement)
        let candidate = nodes.first(where: {
            $0.observation.identifier == expectation.terminalIdentifier
        })?.observation
        let terminalMatches = candidate.map { element in
            element.role == expectation.role
                && element.enabled
                && expectation.terminalTitle.map { element.title == $0 } != false
                && viewport.contains(element.frame)
                && expectation.requiredAction.map(element.actions.contains) != false
        } ?? false
        let scrollMatches = finalValue.map { abs($0 - maximum) <= 0.001 } ?? false
        if terminalMatches, scrollMatches {
            consecutiveMatches += 1
            terminalElement = candidate
            if consecutiveMatches >= 2 { break }
        } else {
            consecutiveMatches = 0
        }
    }

    var deepFindings: [AXObservedFinding] = []
    if finalValue.map({ abs($0 - maximum) <= 0.001 }) != true {
        deepFindings.append(AXObservedFinding(
            kind: .deepScrollUnavailable,
            identifiers: [expectation.scrollIdentifier],
            message: "The route-specific macOS scroll area did not settle at its maximum value.",
            intersection: nil
        ))
    }
    if terminalElement == nil {
        let candidate = observeTree(root: rootWindowElement).first(where: {
            $0.observation.identifier == expectation.terminalIdentifier
        })?.observation
        if let candidate, !viewport.contains(candidate.frame) {
            deepFindings.append(AXObservedFinding(
                kind: .outsideViewport,
                identifiers: [expectation.terminalIdentifier],
                message: "The route-specific terminal element remained clipped or offscreen after scrolling.",
                intersection: candidate.frame.intersection(with: viewport)
            ))
        } else if candidate != nil {
            deepFindings.append(AXObservedFinding(
                kind: .terminalSemanticMismatch,
                identifiers: [expectation.terminalIdentifier],
                message: "The route-specific terminal element did not expose the required role, enabled state, and action.",
                intersection: nil
            ))
        } else {
            deepFindings.append(AXObservedFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [expectation.terminalIdentifier],
                message: "The route-specific terminal identifier was not observed after scrolling.",
                intersection: nil
            ))
        }
    }

    return AXObservedDeepScrollEvidence(
        route: route,
        reachedTerminal: consecutiveMatches >= 2 && deepFindings.isEmpty,
        scrollAreaIdentifier: expectation.scrollIdentifier,
        initialScrollValue: initialValue,
        finalScrollValue: finalValue,
        contentViewport: viewport,
        terminalElement: terminalElement,
        findings: deepFindings
    )
}

func findings(
    elements: [AXObservedElement],
    viewport: AXObservedRect,
    options: Options
) -> [AXObservedFinding] {
    var findings: [AXObservedFinding] = []
    let byIdentifier = Dictionary(grouping: elements.filter { !$0.identifier.isEmpty }, by: \.identifier)
    let byTitle = Dictionary(grouping: elements.filter { !$0.title.isEmpty }, by: \.title)

    for title in requiredTitles(for: options.route, signedIn: options.signedIn) where byTitle[title]?.isEmpty != false {
        findings.append(AXObservedFinding(
            kind: .requiredIdentifierMissing,
            identifiers: ["title:\(title)"],
            message: "Required AX title \(title) was not observed.",
            intersection: nil
        ))
    }

    for identifier in options.requiredIdentifiers.sorted() {
        guard let element = byIdentifier[identifier]?.first else {
            findings.append(AXObservedFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [identifier],
                message: "Required AX identifier \(identifier) was not observed.",
                intersection: nil
            ))
            continue
        }
        if !viewport.contains(element.frame) {
            findings.append(AXObservedFinding(
                kind: .outsideViewport,
                identifiers: [identifier],
                message: "Required AX element \(identifier) is clipped or offscreen.",
                intersection: element.frame.intersection(with: viewport)
            ))
        }
    }

    for (firstIdentifier, secondIdentifier) in options.peerPairs {
        guard let first = byIdentifier[firstIdentifier]?.first,
              let second = byIdentifier[secondIdentifier]?.first,
              let overlap = first.frame.intersection(with: second.frame) else { continue }
        findings.append(AXObservedFinding(
            kind: .peerOverlap,
            identifiers: [firstIdentifier, secondIdentifier],
            message: "AX peer elements overlap.",
            intersection: overlap
        ))
    }

    let visibleTexts = elements.filter {
        $0.role == (kAXStaticTextRole as String)
            && !$0.title.isEmpty
            && $0.frame.intersection(with: viewport) != nil
    }
    for firstIndex in visibleTexts.indices {
        for secondIndex in visibleTexts.indices where secondIndex > firstIndex {
            let first = visibleTexts[firstIndex]
            let second = visibleTexts[secondIndex]
            guard first.title != second.title,
                  let overlap = first.frame.intersection(with: second.frame),
                  overlap.width * overlap.height > 1 else { continue }
            findings.append(AXObservedFinding(
                kind: .textOverlap,
                identifiers: [first.title, second.title],
                message: "Visible AX text overlaps.",
                intersection: overlap
            ))
        }
    }

    let actionableRoles: Set<String> = [
        kAXButtonRole as String,
        kAXCheckBoxRole as String,
        kAXPopUpButtonRole as String,
        kAXRadioButtonRole as String,
        kAXTextFieldRole as String
    ]
    let minimumMacControlSize = 20.0
    for element in elements where element.enabled
        && !element.frame.isEmpty
        && element.frame.intersection(with: viewport) != nil
        && !isNativeSystemControl(element)
        && (!element.actions.isEmpty || actionableRoles.contains(element.role)) {
        if element.frame.width + 0.5 < minimumMacControlSize
            || element.frame.height + 0.5 < minimumMacControlSize {
            findings.append(AXObservedFinding(
                kind: .actionTargetTooSmall,
                identifiers: [element.identifier],
                message: "AX action target is smaller than the 20-point macOS minimum.",
                intersection: nil
            ))
        }
    }

    if options.observesAPNs,
       let heading = byIdentifier["settings.apns.this-device.heading"]?.first {
        let chromeRoles: Set<String> = [kAXToolbarRole as String, kAXSheetRole as String]
        let chromeSubroles: Set<String> = [kAXDialogSubrole as String, kAXSystemDialogSubrole as String]
        for chrome in elements where chromeRoles.contains(chrome.role) || chromeSubroles.contains(chrome.subrole) {
            guard let overlap = heading.frame.intersection(with: chrome.frame) else { continue }
            findings.append(AXObservedFinding(
                kind: .apnsChromeIntersection,
                identifiers: [heading.identifier, chrome.identifier],
                message: "This Device heading intersects macOS chrome.",
                intersection: overlap
            ))
        }
    }

    return findings
}

func isNativeSystemControl(_ element: AXObservedElement) -> Bool {
    if element.role == (kAXDisclosureTriangleRole as String) {
        return true
    }
    return Set([
        "AXCloseButton",
        "AXMinimizeButton",
        "AXZoomButton",
        "AXFullScreenButton",
        "AXIncrementArrow",
        "AXDecrementArrow",
        "AXIncrementPage",
        "AXDecrementPage"
    ]).contains(element.subrole)
}

func requiredTitles(for route: String, signedIn: Bool) -> Set<String> {
    guard signedIn else { return ["Spoonjoy", "Sign in"] }
    return switch route {
    case "kitchen": ["My Kitchen", "Lemon Pantry Pasta"]
    case "recipes", "saved-recipes", "recipe-detail": ["Lemon Pantry Pasta"]
    case "recipe-editor": ["Recipe", "Title", "Save"]
    case "recipe-covers": ["Photo Studio", "Lemon Pantry Pasta", "Replace Photo", "Photo ready", "Clear", "Save Photo"]
    case "cook-mode": ["Lemon Pantry Pasta", "Current cooking step 1, Boil pasta", "Mark the current step done", "Tools", "Ingredients"]
    case "cook-log": ["Cooks", "What changed?", "Next time", "Add cook photo", "Log cook"]
    case "cookbooks", "cookbook-detail": ["Weeknights"]
    case "profile": ["@ari", "Joined Spoonjoy", "Edit Profile"]
    case "profile-graph": ["jules", "1 spoon"]
    case "shopping-list": ["Lemons"]
    case "chefs": ["Chefs"]
    case "search": ["Search"]
    case "capture": ["Imports"]
    case "settings": ["Account"]
    case "unknown-link": ["Link Not Found", "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link."]
    default: [route]
    }
}

func requiredIdentifiers(for route: String) -> Set<String> {
    switch route {
    case "recipe-editor":
        ["recipe-editor.title", "recipe-editor.save"]
    case "recipe-covers":
        [
            "recipe-covers.photo-picker", "recipe-covers.staged-photo-status", "recipe-covers.clear-photo",
            "recipe-covers.save-photo", "recipe-covers.archive.cover_primary"
        ]
    case "profile":
        ["profile.header"]
    case "profile-graph":
        ["profile-graph.row.chef_jules"]
    case "unknown-link":
        ["unknown-link.message"]
    case "cook-mode":
        ["cook.current-step", "cook.done", "cook.tools"]
    case "cook-log":
        ["cook-log.note", "cook-log.next-time", "cook-log.photo", "cook-log.submit"]
    default:
        []
    }
}

if CommandLine.arguments.dropFirst() == ["--self-test-non-finite-frame"] {
    let rect = normalizedObservedRect(x: .infinity, y: 12, width: 40, height: 40)
    guard rect.isEmpty, (try? JSONEncoder().encode(rect)) != nil else {
        fail("non-finite AX frame normalization self-test failed")
    }
    print("macOS non-finite frame normalization ok")
    exit(0)
}

let options = parseOptions()
guard let runningApplication = NSRunningApplication(processIdentifier: options.pid) else {
    fail("no running application for PID \(options.pid)")
}
guard runningApplication.bundleIdentifier == options.expectedBundleIdentifier else {
    fail("PID bundle identifier does not match expected bundle")
}
guard canonicalPath(runningApplication.bundleURL?.path ?? "") == canonicalPath(options.expectedBundlePath) else {
    fail("PID bundle path does not match expected bundle")
}
guard canonicalPath(runningApplication.executableURL?.path ?? "") == canonicalPath(options.expectedExecutablePath) else {
    fail("PID executable path does not match expected executable")
}
let readinessProofData = requiredFileData(at: options.readinessProofPath, label: "readiness proof")
validateReadinessProof(readinessProofData, options: options)
let screenshotData = requiredFileData(at: options.screenshotPath, label: "macOS screenshot")
guard screenshotData.starts(with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) else {
    fail("macOS screenshot must be a PNG")
}
let executableData = requiredFileData(at: options.expectedExecutablePath, label: "macOS executable")
if options.preflightOnly {
    print("macOS observer preflight ok")
    exit(0)
}
guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the observing process")
}

let applicationElement = AXUIElementCreateApplication(options.pid)
guard let windowElements = attribute(applicationElement, kAXWindowsAttribute as CFString) as? [AXUIElement],
      !windowElements.isEmpty else {
    fail("the exact application PID has no AX windows")
}
let measurableWindows = windowElements.filter {
    !frame(of: $0).isEmpty
        && !boolAttribute($0, kAXMinimizedAttribute as CFString, default: false)
}
guard measurableWindows.count == 1, let rootWindowElement = measurableWindows.first else {
    fail("expected exactly one measurable main content window, observed \(measurableWindows.count)")
}
let windowFrames = measurableWindows.map(frame(of:))
let viewport = frame(of: rootWindowElement)
let observedNodes = observeTree(root: rootWindowElement)
let elements = observedNodes.map(\.observation)
let observedFindings = findings(elements: elements, viewport: viewport, options: options)
let deepScroll = terminalExpectation(for: options.route).map {
    observeDeepScroll(rootWindowElement: rootWindowElement, route: options.route, expectation: $0)
}
let evidence = AXObservedEvidence(
    platform: "macos",
    route: options.route,
    captureRunNonce: options.captureRunNonce,
    readinessProofSHA256: sha256Hex(readinessProofData),
    screenshotSHA256: sha256Hex(screenshotData),
    pid: options.pid,
    bundleIdentifier: options.expectedBundleIdentifier,
    bundlePath: canonicalPath(options.expectedBundlePath),
    executablePath: canonicalPath(options.expectedExecutablePath),
    executableSHA256: sha256Hex(executableData),
    windowFrames: windowFrames,
    elements: elements,
    findings: observedFindings,
    deepScroll: deepScroll,
    recordedAt: ISO8601DateFormatter().string(from: Date())
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(evidence)
let outputURL = URL(fileURLWithPath: options.outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: outputURL, options: .atomic)
let deepScrollFindings = deepScroll?.findings ?? []
if !observedFindings.isEmpty || !deepScrollFindings.isEmpty {
    fail("observed macOS accessibility geometry has \(observedFindings.count + deepScrollFindings.count) finding(s)")
}
print("macOS observed screenshot evidence ok")
