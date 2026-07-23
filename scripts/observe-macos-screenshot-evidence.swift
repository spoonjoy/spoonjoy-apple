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

struct AXObservedPixelAccessibilityBinding: Codable {
    let schema: String
    let capturePhase: String
    let pixelSource: String
    let screenshotSHA256: String
    let accessibilitySnapshotBeforeSHA256: String
    let accessibilitySnapshotAfterSHA256: String
    let applicationProcessIdentifier: Int32
    let windowID: CGWindowID
    let windowFrame: AXObservedRect
    let selectedScrollHierarchyIdentifier: String?
    let selectedScrollHierarchySnapshotBeforeSHA256: String?
    let selectedScrollHierarchySnapshotAfterSHA256: String?
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
    let postScrollScreenshotSHA256: String?
    let applicationProcessIdentifier: Int32?
    let windowID: CGWindowID?
    let postScrollElements: [AXObservedElement]
    let postScrollAuditFindings: [AXObservedFinding]
    let pixelAccessibilityBinding: AXObservedPixelAccessibilityBinding?
    let selectedScrollHierarchyIdentifier: String?
    let selectedScrollHierarchyElements: [AXObservedElement]
}

struct AXObservedEvidence: Codable {
    let platform: String
    let route: String
    let captureRunNonce: String
    let readinessProofSHA256: String
    let screenshotSHA256: String
    let pid: Int32
    let windowID: CGWindowID
    let bundleIdentifier: String
    let bundlePath: String
    let executablePath: String
    let executableSHA256: String
    let windowFrames: [AXObservedRect]
    let elements: [AXObservedElement]
    let findings: [AXObservedFinding]
    let pixelAccessibilityBinding: AXObservedPixelAccessibilityBinding
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

struct AXBoundWindow {
    let element: AXUIElement
    let frame: AXObservedRect
}

struct AXPostScrollObservation {
    let window: AXBoundWindow
    let elements: [AXObservedElement]
    let selectedScrollHierarchyIdentifier: String?
    let selectedScrollHierarchyFrame: AXObservedRect?
    let selectedScrollHierarchyElements: [AXObservedElement]
    let terminal: AXObservedElement?
    let screenshot: CapturedPostScrollScreenshot
    let pixelAccessibilityBinding: AXObservedPixelAccessibilityBinding
}

struct CapturedPostScrollScreenshot {
    let temporaryURL: URL
    let data: Data
}

struct Options {
    let pid: pid_t
    let route: String
    let captureRunNonce: String
    let readinessProofPath: String
    let screenshotPath: String
    let deepScrollScreenshotPath: String
    let windowID: CGWindowID
    let expectedBundleIdentifier: String
    let expectedBundlePath: String
    let expectedExecutablePath: String
    let outputPath: String
    let requiredIdentifiers: Set<String>
    let peerPairs: [(String, String)]
    let observesAPNs: Bool
    let signedIn: Bool
    let shoppingVariant: String
    let searchVariant: String
    let captureVariant: String
    let expectedSearchQuery: String
    let expectedSearchScope: String
    let preflightOnly: Bool
}

var failureCleanupURLs: [URL] = []

func fail(_ message: String) -> Never {
    for url in failureCleanupURLs {
        try? FileManager.default.removeItem(at: url)
    }
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
    guard let deepScrollScreenshotPath = values["--deep-scroll-screenshot-path"], !deepScrollScreenshotPath.isEmpty else {
        fail("--deep-scroll-screenshot-path is required")
    }
    guard let rawWindowID = values["--window-id"], let windowID = CGWindowID(rawWindowID), windowID > 0 else {
        fail("--window-id must be a positive window identifier")
    }
    let shoppingVariant = values["--shopping-variant"] ?? "normal"
    let searchVariant = values["--search-variant"] ?? "blank"
    let captureVariant = values["--capture-variant"] ?? "empty"
    let expectedSearchQuery = values["--expected-search-query"] ?? ""
    let expectedSearchScope = values["--expected-search-scope"] ?? "all"
    guard ["normal", "empty", "all-complete", "duplicate", "conflict", "offline-queued"].contains(shoppingVariant) else {
        fail("unsupported --shopping-variant")
    }
    guard ["blank", "typed-results", "scoped-recipes", "scoped-cookbooks", "scoped-chefs", "scoped-shopping", "no-results"].contains(searchVariant) else {
        fail("unsupported --search-variant")
    }
    guard ["empty", "draft", "offline-retry", "provider-blocked", "signed-out"].contains(captureVariant) else {
        fail("unsupported --capture-variant")
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
        deepScrollScreenshotPath: deepScrollScreenshotPath,
        windowID: windowID,
        expectedBundleIdentifier: bundleIdentifier,
        expectedBundlePath: bundlePath,
        expectedExecutablePath: executablePath,
        outputPath: outputPath,
        requiredIdentifiers: requiredIdentifierSet,
        peerPairs: peerPairs,
        observesAPNs: observesAPNs,
        signedIn: signedIn,
        shoppingVariant: shoppingVariant,
        searchVariant: searchVariant,
        captureVariant: captureVariant,
        expectedSearchQuery: expectedSearchQuery,
        expectedSearchScope: expectedSearchScope,
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

func searchTerminalTitle(variant: String, query: String, scope: String) -> String {
    switch variant {
    case "typed-results", "scoped-shopping":
        "Shopping item, lemons, 2 each"
    case "scoped-recipes":
        "Recipe, Lemon Pantry Pasta, Bright pantry pasta with lemon, garlic, and parmesan."
    case "scoped-cookbooks":
        "Cookbook, Weeknights, 2 recipes"
    case "scoped-chefs":
        "Chef, ari, Chef"
    case "no-results":
        scope == "all"
            ? "No Spoonjoy results match \"\(query)\"."
            : "No results match \"\(query)\"."
    default:
        "Shopping item, parmesan, 0.5 cup"
    }
}

func terminalExpectation(for options: Options) -> AXRouteTerminalExpectation? {
    switch options.route {
    case "kitchen":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "kitchen.cookbook.cookbook_slow_sundays",
            terminalTitle: "Slow Sundays and Long Simmering Suppers, 0 recipes",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "recipes":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "recipes.terminal",
            terminalTitle: "Start your recipe box with the dishes you actually cook.",
            role: kAXStaticTextRole as String,
            requiredAction: nil
        )
    case "saved-recipes":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "saved-recipes.terminal",
            terminalTitle: "Recipes you save to your cookbooks will appear here.",
            role: kAXStaticTextRole as String,
            requiredAction: nil
        )
    case "recipe-editor":
        AXRouteTerminalExpectation(
            scrollIdentifier: "recipe-editor.scroll",
            terminalIdentifier: "recipe-editor.delete",
            terminalTitle: "Delete Recipe",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "recipe-detail":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "recipe-detail.terminal",
            terminalTitle: "No cooks logged yet",
            role: kAXStaticTextRole as String,
            requiredAction: nil
        )
    case "recipe-covers":
        AXRouteTerminalExpectation(
            scrollIdentifier: "recipe-covers.scroll",
            terminalIdentifier: "recipe-covers.terminal",
            terminalTitle: "Archive",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "profile":
        AXRouteTerminalExpectation(
            scrollIdentifier: "profile.scroll",
            terminalIdentifier: "profile.graph.kitchen-visitors",
            terminalTitle: "1 Kitchen visitors",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "cook-mode":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "cook-mode.terminal",
            terminalTitle: "spaghetti, 12 oz",
            role: kAXCheckBoxRole as String,
            requiredAction: kAXPressAction as String
        )
    case "cook-log":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "cook-log.terminal",
            terminalTitle: "No cooks logged yet",
            role: kAXStaticTextRole as String,
            requiredAction: nil
        )
    case "cookbooks":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "cookbooks.terminal",
            terminalTitle: "Slow Sundays and Long Simmering Suppers, 0 recipes",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "cookbook-detail":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "cookbook-detail.terminal",
            terminalTitle: "2. Tomato Toast",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "shopping-list":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "shopping-list.terminal",
            terminalTitle: ["empty", "all-complete"].contains(options.shoppingVariant)
                ? "Add from recipe"
                : "parmesan, 0.5 cup, Dairy",
            role: ["empty", "all-complete"].contains(options.shoppingVariant)
                ? kAXButtonRole as String
                : kAXCheckBoxRole as String,
            requiredAction: kAXPressAction as String
        )
    case "chefs":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "chefs.terminal",
            terminalTitle: "ari, Open kitchen profile",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "profile-graph":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "profile-graph.row.chef_jules",
            terminalTitle: "jules, 1 spoon",
            role: kAXButtonRole as String,
            requiredAction: kAXPressAction as String
        )
    case "search":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "search.terminal",
            terminalTitle: searchTerminalTitle(
                variant: options.searchVariant,
                query: options.expectedSearchQuery,
                scope: options.expectedSearchScope
            ),
            role: options.searchVariant == "no-results" ? kAXStaticTextRole as String : kAXButtonRole as String,
            requiredAction: options.searchVariant == "no-results" ? nil : kAXPressAction as String
        )
    case "capture":
        if !options.signedIn || options.captureVariant == "signed-out" {
            AXRouteTerminalExpectation(
                scrollIdentifier: "spoonjoy.page-scroll",
                terminalIdentifier: "native sign-in settings",
                terminalTitle: "Settings",
                role: kAXButtonRole as String,
                requiredAction: kAXPressAction as String
            )
        } else {
            AXRouteTerminalExpectation(
                scrollIdentifier: "spoonjoy.page-scroll",
                terminalIdentifier: "capture.terminal",
                terminalTitle: options.captureVariant == "empty"
                    ? "New recipes from your Spoonjoy agent will appear here."
                    : "Import actions",
                role: options.captureVariant == "empty" ? kAXStaticTextRole as String : kAXButtonRole as String,
                requiredAction: options.captureVariant == "empty" ? nil : kAXPressAction as String
            )
        }
    case "settings":
        AXRouteTerminalExpectation(
            scrollIdentifier: "spoonjoy.page-scroll",
            terminalIdentifier: "settings.terminal",
            terminalTitle: "Offline",
            role: kAXGroupRole as String,
            requiredAction: nil
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
    selectedScrollArea: AXUIElement,
    expectation: AXRouteTerminalExpectation
) -> AXObservedElement? {
    let matches = observeTree(root: selectedScrollArea).filter {
        $0.observation.identifier == expectation.terminalIdentifier
    }
    guard matches.count == 1 else { return nil }
    return matches[0].observation
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
            selectedScrollArea: scrollArea,
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
            selectedScrollArea: scrollArea,
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
        findings: findings,
        postScrollScreenshotSHA256: nil,
        applicationProcessIdentifier: nil,
        windowID: nil,
        postScrollElements: [],
        postScrollAuditFindings: [],
        pixelAccessibilityBinding: nil,
        selectedScrollHierarchyIdentifier: nil,
        selectedScrollHierarchyElements: []
    )
}

func observeDeepScroll(
    rootWindowElement: AXUIElement,
    route: String,
    expectation: AXRouteTerminalExpectation
) -> AXObservedDeepScrollEvidence {
    let initialNodes = observeTree(root: rootWindowElement)
    let scrollAnchors = initialNodes.filter {
        $0.observation.identifier == expectation.scrollIdentifier
    }
    guard scrollAnchors.count == 1,
          let scrollAnchor = scrollAnchors.first,
          let scrollArea = enclosingScrollArea(for: scrollAnchor) else {
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
            )],
            postScrollScreenshotSHA256: nil,
            applicationProcessIdentifier: nil,
            windowID: nil,
            postScrollElements: [],
            postScrollAuditFindings: [],
            pixelAccessibilityBinding: nil,
            selectedScrollHierarchyIdentifier: nil,
            selectedScrollHierarchyElements: []
        )
    }

    let viewport = frame(of: scrollArea)
    guard let scrollBar = elementAttribute(scrollArea, kAXVerticalScrollBarAttribute as CFString) else {
        return scrollByPageToTerminal(
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
        let nodes = observeTree(root: scrollArea)
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
        let candidate = observeTree(root: scrollArea).first(where: {
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
        findings: deepFindings,
        postScrollScreenshotSHA256: nil,
        applicationProcessIdentifier: nil,
        windowID: nil,
        postScrollElements: [],
        postScrollAuditFindings: [],
        pixelAccessibilityBinding: nil,
        selectedScrollHierarchyIdentifier: nil,
        selectedScrollHierarchyElements: []
    )
}

func capturePostScrollScreenshot(path: String, windowID: CGWindowID) -> CapturedPostScrollScreenshot {
    let outputURL = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let temporaryURL = outputURL.deletingLastPathComponent().appendingPathComponent(
        ".\(outputURL.lastPathComponent).\(UUID().uuidString).capture.png"
    )
    try? FileManager.default.removeItem(at: temporaryURL)
    failureCleanupURLs.append(temporaryURL)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-x", "-l", String(windowID), temporaryURL.path]
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fail("macOS post-scroll screenshot capture failed: \(error)")
    }
    guard process.terminationStatus == 0 else {
        fail("macOS post-scroll screenshot capture exited \(process.terminationStatus)")
    }
    let data = requiredFileData(at: temporaryURL.path, label: "macOS post-scroll screenshot")
    guard data.starts(with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) else {
        fail("macOS post-scroll screenshot must be a PNG")
    }
    syncFile(at: temporaryURL, label: "macOS post-scroll screenshot")
    return CapturedPostScrollScreenshot(temporaryURL: temporaryURL, data: data)
}

func syncFile(at url: URL, label: String) {
    let descriptor = open(url.path, O_RDONLY)
    guard descriptor >= 0 else { fail("unable to open \(label) for durable publication") }
    defer { close(descriptor) }
    guard fsync(descriptor) == 0 else { fail("unable to fsync \(label)") }
}

func syncDirectory(containing url: URL, label: String) {
    let descriptor = open(url.deletingLastPathComponent().path, O_RDONLY)
    guard descriptor >= 0 else { fail("unable to open \(label) directory for durable publication") }
    defer { close(descriptor) }
    guard fsync(descriptor) == 0 else { fail("unable to fsync \(label) directory") }
}

func atomicallyPublish(_ temporaryURL: URL, to outputURL: URL, label: String) {
    guard rename(temporaryURL.path, outputURL.path) == 0 else {
        fail("unable to atomically publish \(label)")
    }
    failureCleanupURLs.removeAll { $0 == temporaryURL }
    failureCleanupURLs.append(outputURL)
    syncDirectory(containing: outputURL, label: label)
}

func publishPostScrollScreenshot(_ capture: CapturedPostScrollScreenshot, path: String) {
    let outputURL = URL(fileURLWithPath: path)
    atomicallyPublish(capture.temporaryURL, to: outputURL, label: "macOS post-scroll screenshot")
    let publishedData = requiredFileData(at: path, label: "published macOS post-scroll screenshot")
    guard sha256Hex(publishedData) == sha256Hex(capture.data) else {
        fail("published macOS post-scroll screenshot digest changed")
    }
}

func failCapture(_ capture: CapturedPostScrollScreenshot, _ message: String) -> Never {
    try? FileManager.default.removeItem(at: capture.temporaryURL)
    fail(message)
}

func findings(
    elements: [AXObservedElement],
    viewport: AXObservedRect,
    options: Options,
    includeRouteRequirements: Bool = true
) -> [AXObservedFinding] {
    var findings: [AXObservedFinding] = []
    let byIdentifier = Dictionary(grouping: elements.filter { !$0.identifier.isEmpty }, by: \.identifier)
    let byTitle = Dictionary(grouping: elements.filter { !$0.title.isEmpty }, by: \.title)

    for title in includeRouteRequirements ? requiredTitles(for: options) : [] where byTitle[title]?.isEmpty != false {
        findings.append(AXObservedFinding(
            kind: .requiredIdentifierMissing,
            identifiers: ["title:\(title)"],
            message: "Required AX title \(title) was not observed.",
            intersection: nil
        ))
    }

    for identifier in includeRouteRequirements ? options.requiredIdentifiers.sorted() : [] {
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

func requiredTitles(for options: Options) -> Set<String> {
    guard options.signedIn else { return ["Spoonjoy", "Sign in"] }
    return switch options.route {
    case "kitchen": ["My Kitchen", "Lemon Pantry Pasta"]
    case "recipes": ["My Recipes", "No recipes yet"]
    case "saved-recipes": ["Saved Recipes", "No saved recipes yet"]
    case "recipe-detail": ["Lemon Pantry Pasta"]
    case "recipe-editor": ["Recipe", "Title", "Save"]
    case "recipe-covers": ["Photo Studio", "Lemon Pantry Pasta", "Replace Photo", "Photo ready", "Clear", "Save Photo"]
    case "cook-mode": ["Lemon Pantry Pasta", "Current cooking step 1, Boil pasta", "Mark the current step done", "Tools", "Ingredients"]
    case "cook-log": ["Cooks", "What changed?", "Next time", "Add cook photo", "Log cook"]
    case "cookbooks", "cookbook-detail": ["Weeknights"]
    case "profile": ["@ari", "Joined Spoonjoy", "Edit Profile"]
    case "profile-graph": ["jules", "1 spoon"]
    case "shopping-list": ["Shopping"]
    case "chefs": ["Chefs"]
    case "search": ["Search"]
    case "capture": ["Imports"]
    case "settings": ["Account"]
    case "unknown-link": ["Link Not Found", "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link."]
    default: [options.route]
    }
}

func requiredIdentifiers(for route: String) -> Set<String> {
    switch route {
    case "recipe-editor":
        ["recipe-editor.title", "recipe-editor.save"]
    case "recipe-covers":
        [
            "recipe-covers.photo-picker", "recipe-covers.staged-photo-status", "recipe-covers.clear-photo",
            "recipe-covers.save-photo", "recipe-covers.terminal"
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

func framesMatch(_ first: AXObservedRect, _ second: AXObservedRect, tolerance: Double = 1.0) -> Bool {
    abs(first.x - second.x) <= tolerance
        && abs(first.y - second.y) <= tolerance
        && abs(first.width - second.width) <= tolerance
        && abs(first.height - second.height) <= tolerance
}

func validateRunningApplication(_ options: Options) -> NSRunningApplication {
    guard let runningApplication = NSRunningApplication(processIdentifier: options.pid),
          !runningApplication.isTerminated else {
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
    return runningApplication
}

func boundRootWindow(options: Options) -> AXBoundWindow {
    guard let rawWindowInfo = CGWindowListCopyWindowInfo(.optionIncludingWindow, options.windowID),
          let windowInfo = rawWindowInfo as? [[String: Any]],
          windowInfo.count == 1,
          let exactWindow = windowInfo.first else {
        fail("exact CGWindowID \(options.windowID) is not observable")
    }
    guard (exactWindow[kCGWindowNumber as String] as? NSNumber)?.uint32Value == options.windowID else {
        fail("CGWindow record does not match the requested window identifier")
    }
    guard (exactWindow[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == options.pid else {
        fail("CGWindow owner PID does not match the exact Spoonjoy process")
    }
    guard (exactWindow[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 else {
        fail("CGWindow is not an application content window")
    }
    guard (exactWindow[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true else {
        fail("CGWindow is not onscreen")
    }
    guard let rawBounds = exactWindow[kCGWindowBounds as String] as? NSDictionary,
          let cgBounds = CGRect(dictionaryRepresentation: rawBounds as CFDictionary) else {
        fail("CGWindow bounds are unavailable")
    }
    let cgFrame = normalizedObservedRect(
        x: Double(cgBounds.origin.x),
        y: Double(cgBounds.origin.y),
        width: Double(cgBounds.width),
        height: Double(cgBounds.height)
    )

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
    let axFrame = frame(of: rootWindowElement)
    guard framesMatch(axFrame, cgFrame) else {
        fail("exact CGWindowID bounds do not match the sole measurable AX window for PID \(options.pid)")
    }
    return AXBoundWindow(element: rootWindowElement, frame: axFrame)
}

func observationDigest(_ elements: [AXObservedElement]) -> String {
    let ordered = elements.sorted {
        let first = "\($0.identifier)|\($0.role)|\($0.title)|\($0.frame.x)|\($0.frame.y)"
        let second = "\($1.identifier)|\($1.role)|\($1.title)|\($1.frame.x)|\($1.frame.y)"
        return first < second
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(ordered) else {
        fail("post-scroll accessibility observations could not be encoded")
    }
    return sha256Hex(data)
}

func exactSelectedScrollArea(
    rootWindowElement: AXUIElement,
    expectation: AXRouteTerminalExpectation
) -> AXUIElement {
    let anchors = observeTree(root: rootWindowElement).filter {
        $0.observation.identifier == expectation.scrollIdentifier
    }
    guard anchors.count == 1,
          let anchor = anchors.first,
          let scrollArea = enclosingScrollArea(for: anchor) else {
        fail("expected exactly one selected scroll hierarchy \(expectation.scrollIdentifier)")
    }
    return scrollArea
}

func captureBoundObservation(
    options: Options,
    screenshotPath: String,
    capturePhase: String,
    expectation: AXRouteTerminalExpectation?
) -> AXPostScrollObservation {
    _ = validateRunningApplication(options)
    let firstWindow = boundRootWindow(options: options)
    let firstElements = observeTree(root: firstWindow.element).map(\.observation)
    let firstSelectedScrollArea = expectation.map {
        exactSelectedScrollArea(rootWindowElement: firstWindow.element, expectation: $0)
    }
    let firstSelectedElements = firstSelectedScrollArea.map {
        observeTree(root: $0).map(\.observation)
    } ?? []
    if let expectation, let firstSelectedScrollArea {
        let matches = firstSelectedElements.filter { $0.identifier == expectation.terminalIdentifier }
        guard matches.count == 1,
              terminalMatches(matches.first, viewport: frame(of: firstSelectedScrollArea), expectation: expectation) else {
            fail("terminal semantics were not exact inside the selected scroll hierarchy before capture")
        }
    }

    let screenshot = capturePostScrollScreenshot(path: screenshotPath, windowID: options.windowID)
    _ = validateRunningApplication(options)
    let secondWindow = boundRootWindow(options: options)
    let secondElements = observeTree(root: secondWindow.element).map(\.observation)
    let secondSelectedScrollArea = expectation.map {
        exactSelectedScrollArea(rootWindowElement: secondWindow.element, expectation: $0)
    }
    let secondSelectedElements = secondSelectedScrollArea.map {
        observeTree(root: $0).map(\.observation)
    } ?? []
    guard framesMatch(firstWindow.frame, secondWindow.frame, tolerance: 0.5),
          observationDigest(firstElements) == observationDigest(secondElements) else {
        failCapture(screenshot, "accessibility tree was not stable across the exact-window screenshot")
    }
    let firstSelectedDigest = expectation.map { _ in observationDigest(firstSelectedElements) }
    let secondSelectedDigest = expectation.map { _ in observationDigest(secondSelectedElements) }
    guard firstSelectedDigest == secondSelectedDigest else {
        failCapture(screenshot, "selected scroll hierarchy changed across the exact-window screenshot")
    }
    var terminal: AXObservedElement?
    if let expectation, let secondSelectedScrollArea {
        let matches = secondSelectedElements.filter { $0.identifier == expectation.terminalIdentifier }
        guard matches.count == 1,
              terminalMatches(matches.first, viewport: frame(of: secondSelectedScrollArea), expectation: expectation) else {
            failCapture(screenshot, "terminal semantics changed inside the selected scroll hierarchy across capture")
        }
        terminal = matches.first
    }
    let rootBeforeDigest = observationDigest(firstElements)
    let rootAfterDigest = observationDigest(secondElements)
    return AXPostScrollObservation(
        window: secondWindow,
        elements: secondElements,
        selectedScrollHierarchyIdentifier: expectation?.scrollIdentifier,
        selectedScrollHierarchyFrame: secondSelectedScrollArea.map(frame),
        selectedScrollHierarchyElements: secondSelectedElements,
        terminal: terminal,
        screenshot: screenshot,
        pixelAccessibilityBinding: AXObservedPixelAccessibilityBinding(
            schema: "macosPixelAccessibilityBindingV1",
            capturePhase: capturePhase,
            pixelSource: "exactCGWindowID",
            screenshotSHA256: sha256Hex(screenshot.data),
            accessibilitySnapshotBeforeSHA256: rootBeforeDigest,
            accessibilitySnapshotAfterSHA256: rootAfterDigest,
            applicationProcessIdentifier: options.pid,
            windowID: options.windowID,
            windowFrame: secondWindow.frame,
            selectedScrollHierarchyIdentifier: expectation?.scrollIdentifier,
            selectedScrollHierarchySnapshotBeforeSHA256: firstSelectedDigest,
            selectedScrollHierarchySnapshotAfterSHA256: secondSelectedDigest
        )
    )
}

func stableInitialObservation(options: Options) -> AXPostScrollObservation {
    captureBoundObservation(
        options: options,
        screenshotPath: options.screenshotPath,
        capturePhase: "initial",
        expectation: nil
    )
}

func stablePostScrollObservation(
    options: Options,
    expectation: AXRouteTerminalExpectation
) -> AXPostScrollObservation {
    captureBoundObservation(
        options: options,
        screenshotPath: options.deepScrollScreenshotPath,
        capturePhase: "deepScroll",
        expectation: expectation
    )
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
_ = validateRunningApplication(options)
let readinessProofData = requiredFileData(at: options.readinessProofPath, label: "readiness proof")
validateReadinessProof(readinessProofData, options: options)
let executableData = requiredFileData(at: options.expectedExecutablePath, label: "macOS executable")
if options.preflightOnly {
    print("macOS observer preflight ok")
    exit(0)
}
guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the observing process")
}

let initialObservation = stableInitialObservation(options: options)
let initialBoundWindow = initialObservation.window
let rootWindowElement = initialBoundWindow.element
let windowFrames = [initialBoundWindow.frame]
let viewport = initialBoundWindow.frame
let elements = initialObservation.elements
let observedFindings = findings(elements: elements, viewport: viewport, options: options)
guard observedFindings.isEmpty else {
    failCapture(initialObservation.screenshot, "macOS initial accessibility audit found \(observedFindings.count) issue(s)")
}
publishPostScrollScreenshot(initialObservation.screenshot, path: options.screenshotPath)
let screenshotData = requiredFileData(at: options.screenshotPath, label: "published macOS screenshot")
let deepScroll = terminalExpectation(for: options).map { expectation in
    let scrollEvidence = observeDeepScroll(
        rootWindowElement: rootWindowElement,
        route: options.route,
        expectation: expectation
    )
    guard scrollEvidence.reachedTerminal, scrollEvidence.findings.isEmpty else {
        fail("macOS deep scroll did not reach its exact terminal before capture")
    }
    let postScrollObservation = stablePostScrollObservation(
        options: options,
        expectation: expectation
    )
    guard let selectedViewport = postScrollObservation.selectedScrollHierarchyFrame,
          postScrollObservation.selectedScrollHierarchyIdentifier == expectation.scrollIdentifier,
          let postScrollTerminal = postScrollObservation.terminal else {
        failCapture(postScrollObservation.screenshot, "macOS post-scroll selected hierarchy binding is incomplete")
    }
    let postScrollRootFindings = findings(
        elements: postScrollObservation.elements,
        viewport: postScrollObservation.window.frame,
        options: options,
        includeRouteRequirements: false
    )
    let postScrollSelectedFindings = findings(
        elements: postScrollObservation.selectedScrollHierarchyElements,
        viewport: selectedViewport,
        options: options,
        includeRouteRequirements: false
    )
    let postScrollAuditFindings = postScrollRootFindings + postScrollSelectedFindings
    guard postScrollAuditFindings.isEmpty else {
        failCapture(postScrollObservation.screenshot, "macOS post-scroll accessibility audit found \(postScrollAuditFindings.count) issue(s)")
    }

    _ = validateRunningApplication(options)
    let publicationWindow = boundRootWindow(options: options)
    guard framesMatch(publicationWindow.frame, postScrollObservation.window.frame, tolerance: 0.5) else {
        failCapture(postScrollObservation.screenshot, "exact macOS window changed before artifact publication")
    }
    let publicationElements = observeTree(root: publicationWindow.element).map(\.observation)
    guard observationDigest(publicationElements) == observationDigest(postScrollObservation.elements) else {
        failCapture(postScrollObservation.screenshot, "post-scroll accessibility tree changed before artifact publication")
    }
    let publicationScrollArea = exactSelectedScrollArea(
        rootWindowElement: publicationWindow.element,
        expectation: expectation
    )
    let publicationSelectedElements = observeTree(root: publicationScrollArea).map(\.observation)
    guard observationDigest(publicationSelectedElements) == observationDigest(postScrollObservation.selectedScrollHierarchyElements) else {
        failCapture(postScrollObservation.screenshot, "selected scroll hierarchy changed before artifact publication")
    }
    let publicationTerminalMatches = publicationSelectedElements.filter {
        $0.identifier == expectation.terminalIdentifier
    }
    guard publicationTerminalMatches.count == 1,
          let publicationTerminal = publicationTerminalMatches.first,
          terminalMatches(publicationTerminal, viewport: frame(of: publicationScrollArea), expectation: expectation),
          publicationTerminal.identifier == postScrollTerminal.identifier else {
        failCapture(postScrollObservation.screenshot, "terminal semantics changed inside the selected hierarchy before artifact publication")
    }

    let completedEvidence = AXObservedDeepScrollEvidence(
        route: scrollEvidence.route,
        reachedTerminal: scrollEvidence.reachedTerminal,
        scrollAreaIdentifier: scrollEvidence.scrollAreaIdentifier,
        initialScrollValue: scrollEvidence.initialScrollValue,
        finalScrollValue: scrollEvidence.finalScrollValue,
        contentViewport: frame(of: publicationScrollArea),
        terminalElement: publicationTerminal,
        findings: scrollEvidence.findings,
        postScrollScreenshotSHA256: sha256Hex(postScrollObservation.screenshot.data),
        applicationProcessIdentifier: options.pid,
        windowID: options.windowID,
        postScrollElements: publicationElements,
        postScrollAuditFindings: postScrollAuditFindings,
        pixelAccessibilityBinding: postScrollObservation.pixelAccessibilityBinding,
        selectedScrollHierarchyIdentifier: expectation.scrollIdentifier,
        selectedScrollHierarchyElements: publicationSelectedElements
    )
    publishPostScrollScreenshot(postScrollObservation.screenshot, path: options.deepScrollScreenshotPath)
    return completedEvidence
}
let deepScrollFindings = deepScroll?.findings ?? []
let postScrollAuditFindings = deepScroll?.postScrollAuditFindings ?? []
if !observedFindings.isEmpty || !deepScrollFindings.isEmpty || !postScrollAuditFindings.isEmpty {
    fail("observed macOS accessibility geometry has \(observedFindings.count + deepScrollFindings.count + postScrollAuditFindings.count) finding(s)")
}
_ = validateRunningApplication(options)
let finalBoundWindow = boundRootWindow(options: options)
guard framesMatch(finalBoundWindow.frame, initialBoundWindow.frame) else {
    fail("exact macOS window changed before evidence publication")
}
if let expectation = terminalExpectation(for: options), let deepScroll {
    let finalElements = observeTree(root: finalBoundWindow.element).map(\.observation)
    guard observationDigest(finalElements) == observationDigest(deepScroll.postScrollElements) else {
        fail("post-scroll accessibility tree changed before evidence publication")
    }
    let finalScrollArea = exactSelectedScrollArea(rootWindowElement: finalBoundWindow.element, expectation: expectation)
    let finalSelectedElements = observeTree(root: finalScrollArea).map(\.observation)
    guard observationDigest(finalSelectedElements) == observationDigest(deepScroll.selectedScrollHierarchyElements) else {
        fail("selected scroll hierarchy changed before evidence publication")
    }
    let finalTerminalMatches = finalSelectedElements.filter { $0.identifier == expectation.terminalIdentifier }
    guard finalTerminalMatches.count == 1,
          terminalMatches(finalTerminalMatches.first, viewport: frame(of: finalScrollArea), expectation: expectation) else {
        fail("terminal semantics changed before evidence publication")
    }
    let publishedScreenshotData = requiredFileData(
        at: options.deepScrollScreenshotPath,
        label: "published macOS post-scroll screenshot"
    )
    guard sha256Hex(publishedScreenshotData) == deepScroll.postScrollScreenshotSHA256 else {
        fail("published macOS post-scroll screenshot changed before evidence publication")
    }
    guard deepScroll.applicationProcessIdentifier == options.pid, deepScroll.windowID == options.windowID else {
        fail("post-scroll evidence process or window binding changed before evidence publication")
    }
}
let evidence = AXObservedEvidence(
    platform: "macos",
    route: options.route,
    captureRunNonce: options.captureRunNonce,
    readinessProofSHA256: sha256Hex(readinessProofData),
    screenshotSHA256: sha256Hex(screenshotData),
    pid: options.pid,
    windowID: options.windowID,
    bundleIdentifier: options.expectedBundleIdentifier,
    bundlePath: canonicalPath(options.expectedBundlePath),
    executablePath: canonicalPath(options.expectedExecutablePath),
    executableSHA256: sha256Hex(executableData),
    windowFrames: windowFrames,
    elements: elements,
    findings: observedFindings,
    pixelAccessibilityBinding: initialObservation.pixelAccessibilityBinding,
    deepScroll: deepScroll,
    recordedAt: ISO8601DateFormatter().string(from: Date())
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(evidence)
let outputURL = URL(fileURLWithPath: options.outputPath)
let temporaryOutputURL = outputURL.deletingLastPathComponent().appendingPathComponent(
    ".\(outputURL.lastPathComponent).\(UUID().uuidString).evidence.json"
)
failureCleanupURLs.append(temporaryOutputURL)
do {
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: temporaryOutputURL)
} catch {
    fail("macOS observed screenshot evidence publication failed: \(error)")
}
syncFile(at: temporaryOutputURL, label: "macOS observed screenshot evidence")
atomicallyPublish(temporaryOutputURL, to: outputURL, label: "macOS observed screenshot evidence")
guard requiredFileData(at: outputURL.path, label: "published macOS observed screenshot evidence") == data else {
    fail("published macOS observed screenshot evidence changed")
}
failureCleanupURLs.removeAll {
    $0 == outputURL || $0.path == options.screenshotPath || $0.path == options.deepScrollScreenshotPath
}
print("macOS observed screenshot evidence ok")
