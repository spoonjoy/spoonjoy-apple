import CryptoKit
import Foundation
import UIKit
import XCTest

struct ObservedAuditIssue: Codable {
    let category: String
    let type: String
    let compactDescription: String
    let detailedDescription: String
    let diagnosticDescription: String
    let diagnosticMirror: String
    let elementIdentifier: String
    let elementLabel: String
    let elementType: String
    let elementFrame: ObservedRect?
}

private struct ObservedVerifiedContrastFalsePositive: Codable {
    let capturePhase: String
    let issue: ObservedAuditIssue
    let pixelEvidence: ObservedContrastPixelEvidence
}

private struct ObservedVerifiedStaleOffscreenContrastFalsePositive: Codable {
    let schema: String
    let capturePhase: String
    let reason: String
    let issue: ObservedAuditIssue
    let priorElementFrame: ObservedRect
    let currentElementFrame: ObservedRect
    let priorScreenshotSHA256: String
    let currentScreenshotSHA256: String
    let priorPixelEvidence: ObservedContrastPixelEvidence
}

private struct ObservedContrastPixelAdjudicationAttempt: Codable {
    let source: String
    let frame: ObservedRect
    let outcome: String
    let cropWidth: Int?
    let cropHeight: Int?

    private enum CodingKeys: String, CodingKey {
        case source
        case frame
        case outcome
        case cropWidth
        case cropHeight
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(frame, forKey: .frame)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(cropWidth, forKey: .cropWidth)
        try container.encode(cropHeight, forKey: .cropHeight)
    }
}

private struct ObservedContrastPixelAdjudicationDiagnostic: Codable {
    let schema: String
    let capturePhase: String
    let issue: ObservedAuditIssue
    let matchingAttestedElementCount: Int
    let attestedFrame: ObservedRect?
    let screenshotBufferAvailable: Bool
    let screenshotSHA256: String
    let screenshotPixelWidth: Int?
    let screenshotPixelHeight: Int?
    let attempts: [ObservedContrastPixelAdjudicationAttempt]

    private enum CodingKeys: String, CodingKey {
        case schema
        case capturePhase
        case issue
        case matchingAttestedElementCount
        case attestedFrame
        case screenshotBufferAvailable
        case screenshotSHA256
        case screenshotPixelWidth
        case screenshotPixelHeight
        case attempts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(capturePhase, forKey: .capturePhase)
        try container.encode(issue, forKey: .issue)
        try container.encode(matchingAttestedElementCount, forKey: .matchingAttestedElementCount)
        try container.encode(attestedFrame, forKey: .attestedFrame)
        try container.encode(screenshotBufferAvailable, forKey: .screenshotBufferAvailable)
        try container.encode(screenshotSHA256, forKey: .screenshotSHA256)
        try container.encode(screenshotPixelWidth, forKey: .screenshotPixelWidth)
        try container.encode(screenshotPixelHeight, forKey: .screenshotPixelHeight)
        try container.encode(attempts, forKey: .attempts)
    }
}

private struct ObservedSystemChromeElementReference: Codable, Equatable {
    let identifier: String
    let label: String
    let type: String
    let frame: ObservedRect
}

private struct ObservedVerifiedSystemChromeContrastFalsePositive: Codable {
    let schema: String
    let capturePhase: String
    let reason: String
    let contentSizeCategory: String
    let issue: ObservedAuditIssue
    let screenshotSHA256: String
    let issueElement: ObservedSystemChromeElementReference
    let pixelEvidence: [ObservedVisibleTextContrastEvidence]
    let navigationBar: ObservedSystemChromeElementReference
    let tabBar: ObservedSystemChromeElementReference?
    let destinations: [ObservedSystemChromeElementReference]
}

private struct ObservedVisibleTextContrastEvidence: Codable {
    let element: ObservedSystemChromeElementReference
    let pixelFrame: ObservedRect
    let pixelEvidence: ObservedContrastPixelEvidence
}

private struct ObservedVerifiedNativeSidebarSelectionContrastFalsePositive: Codable {
    let schema: String
    let capturePhase: String
    let reason: String
    let contentSizeCategory: String
    let issue: ObservedAuditIssue
    let screenshotSHA256: String
    let issueElement: ObservedSystemChromeElementReference
    let issuePixelEvidence: ObservedContrastPixelEvidence
    let sidebarNavigationBar: ObservedSystemChromeElementReference
    let detailNavigationBar: ObservedSystemChromeElementReference
    let sidebarCollection: ObservedSystemChromeElementReference
    let selectedCell: ObservedSystemChromeElementReference
    let selectedLabel: ObservedSystemChromeElementReference
    let selectedSymbol: ObservedSystemChromeElementReference
    let selectedCellInteriorFrame: ObservedRect
    let selectedLabelTextFrame: ObservedRect
    let selectedCellPixelEvidence: ObservedContrastPixelEvidence
    let selectedLabelTextPixelEvidence: ObservedContrastPixelEvidence
    let selectedSymbolPixelEvidence: ObservedContrastPixelEvidence
    let visibleTextPixelEvidence: [ObservedVisibleTextContrastEvidence]
}

private struct ObservedVerifiedTextClippedFalsePositive: Codable {
    let schema: String
    let capturePhase: String
    let reason: String
    let detailedDescription: String
    let elementIdentifier: String
    let elementLabel: String
    let elementType: String
    let elementFrame: ObservedRect
    let containerType: String
    let containerLabel: String
    let containerFrame: ObservedRect
}

private struct ObservedReadinessHandshake: Codable, Equatable {
    let captureRunNonce: String
    let route: String
    let source: String
    let applicationProcessIdentifier: Int
    let readinessGeneration: Int
    let proofFileName: String
    let proofSHA256: String
}

private struct ObservedCaptureIdentity: Codable, Equatable {
    let schema: String
    let captureID: String
    let captureRunNonce: String
    let capturePhase: String
    let applicationBundleIdentifier: String
    let applicationProcessIdentifier: Int
    let foregroundBeforeCapture: Bool
    let foregroundAfterCapture: Bool
    let screenshotSHA256: String
}

private struct ObservedPixelAccessibilityBinding: Codable, Equatable {
    let schema: String
    let captureID: String
    let capturePhase: String
    let pixelSource: String
    let screenshotSHA256: String
    let accessibilitySnapshotBeforeSHA256: String
    let accessibilitySnapshotAfterSHA256: String
    let windowFrame: ObservedRect
    let selectedScrollHierarchyIdentifier: String?
    let selectedScrollHierarchySnapshotBeforeSHA256: String?
    let selectedScrollHierarchySnapshotAfterSHA256: String?

    private enum CodingKeys: String, CodingKey {
        case schema
        case captureID
        case capturePhase
        case pixelSource
        case screenshotSHA256
        case accessibilitySnapshotBeforeSHA256
        case accessibilitySnapshotAfterSHA256
        case windowFrame
        case selectedScrollHierarchyIdentifier
        case selectedScrollHierarchySnapshotBeforeSHA256
        case selectedScrollHierarchySnapshotAfterSHA256
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(captureID, forKey: .captureID)
        try container.encode(capturePhase, forKey: .capturePhase)
        try container.encode(pixelSource, forKey: .pixelSource)
        try container.encode(screenshotSHA256, forKey: .screenshotSHA256)
        try container.encode(accessibilitySnapshotBeforeSHA256, forKey: .accessibilitySnapshotBeforeSHA256)
        try container.encode(accessibilitySnapshotAfterSHA256, forKey: .accessibilitySnapshotAfterSHA256)
        try container.encode(windowFrame, forKey: .windowFrame)
        if let selectedScrollHierarchyIdentifier {
            try container.encode(selectedScrollHierarchyIdentifier, forKey: .selectedScrollHierarchyIdentifier)
        } else {
            try container.encodeNil(forKey: .selectedScrollHierarchyIdentifier)
        }
        if let selectedScrollHierarchySnapshotBeforeSHA256 {
            try container.encode(
                selectedScrollHierarchySnapshotBeforeSHA256,
                forKey: .selectedScrollHierarchySnapshotBeforeSHA256
            )
        } else {
            try container.encodeNil(forKey: .selectedScrollHierarchySnapshotBeforeSHA256)
        }
        if let selectedScrollHierarchySnapshotAfterSHA256 {
            try container.encode(
                selectedScrollHierarchySnapshotAfterSHA256,
                forKey: .selectedScrollHierarchySnapshotAfterSHA256
            )
        } else {
            try container.encodeNil(forKey: .selectedScrollHierarchySnapshotAfterSHA256)
        }
    }
}

private struct ObservedAuditResult {
    let blockingIssues: [ObservedAuditIssue]
    let verifiedContrastFalsePositives: [ObservedVerifiedContrastFalsePositive]
    let verifiedStaleOffscreenContrastFalsePositives: [ObservedVerifiedStaleOffscreenContrastFalsePositive]
    let contrastPixelAdjudicationDiagnostics: [ObservedContrastPixelAdjudicationDiagnostic]
    let verifiedSystemChromeContrastFalsePositives: [ObservedVerifiedSystemChromeContrastFalsePositive]
    let verifiedNativeSidebarSelectionContrastFalsePositives: [ObservedVerifiedNativeSidebarSelectionContrastFalsePositive]
    let verifiedTextClippedFalsePositives: [ObservedVerifiedTextClippedFalsePositive]
    let hitRegionAuditPassed: Bool
    let auditTypes: [String]
}

private enum ObservedAccessibilityAuditScope: String, Codable {
    case initialFullTree
    case settledScrollWaypoint
    case settledTerminalInteraction
}

private struct AttestedScreenshot {
    let screenshot: XCUIScreenshot
    let handshake: ObservedReadinessHandshake
    let identity: ObservedCaptureIdentity
    let pixelAccessibilityBinding: ObservedPixelAccessibilityBinding
    let windowFrame: ObservedRect
    let elements: [ObservedAccessibilityElement]
    let selectedScrollHierarchyElements: [ObservedAccessibilityElement]
}

private struct ObservedScrollWaypointCoverage: Codable, Equatable {
    let requestedContentOffset: Double
    let observedContentDisplacement: Double
    let viewportOverlap: Double
}

private struct ObservedScrollWaypointEvidence: Codable {
    let index: Int
    let capturePhase: String
    let coverage: ObservedScrollWaypointCoverage?
    let contentViewport: ObservedRect
    let findings: [ObservedAccessibilityFinding]
    let auditIssues: [ObservedAuditIssue]
    let auditScope: ObservedAccessibilityAuditScope
    let auditTypes: [String]
    let verifiedContrastFalsePositives: [ObservedVerifiedContrastFalsePositive]
    let verifiedStaleOffscreenContrastFalsePositives: [ObservedVerifiedStaleOffscreenContrastFalsePositive]
    let contrastPixelAdjudicationDiagnostics: [ObservedContrastPixelAdjudicationDiagnostic]
    let verifiedSystemChromeContrastFalsePositives: [ObservedVerifiedSystemChromeContrastFalsePositive]
    let verifiedNativeSidebarSelectionContrastFalsePositives: [ObservedVerifiedNativeSidebarSelectionContrastFalsePositive]
    let verifiedTextClippedFalsePositives: [ObservedVerifiedTextClippedFalsePositive]
    let screenshotArtifactPath: String
    let screenshotBytes: Int
    let screenshotSHA256: String
    let readinessHandshake: ObservedReadinessHandshake
    let captureIdentity: ObservedCaptureIdentity
    let pixelAccessibilityBinding: ObservedPixelAccessibilityBinding
    let elements: [ObservedAccessibilityElement]
    let selectedScrollHierarchyElements: [ObservedAccessibilityElement]
}

private struct ObservedDeepScrollEvidence: Codable {
    let route: String
    let reachedTerminal: Bool
    let swipeCount: Int
    let contentViewport: ObservedRect
    let tabBarFrame: ObservedRect?
    let terminalElement: ObservedAccessibilityElement?
    let findings: [ObservedAccessibilityFinding]
    let auditIssues: [ObservedAuditIssue]
    let auditScope: ObservedAccessibilityAuditScope
    let auditTypes: [String]
    let verifiedContrastFalsePositives: [ObservedVerifiedContrastFalsePositive]
    let verifiedStaleOffscreenContrastFalsePositives: [ObservedVerifiedStaleOffscreenContrastFalsePositive]
    let contrastPixelAdjudicationDiagnostics: [ObservedContrastPixelAdjudicationDiagnostic]
    let verifiedSystemChromeContrastFalsePositives: [ObservedVerifiedSystemChromeContrastFalsePositive]
    let verifiedNativeSidebarSelectionContrastFalsePositives: [ObservedVerifiedNativeSidebarSelectionContrastFalsePositive]
    let verifiedTextClippedFalsePositives: [ObservedVerifiedTextClippedFalsePositive]
    let screenshotSHA256: String?
    let readinessHandshake: ObservedReadinessHandshake?
    let captureIdentity: ObservedCaptureIdentity?
    let pixelAccessibilityBinding: ObservedPixelAccessibilityBinding?
    let selectedScrollHierarchyIdentifier: String?
    let elements: [ObservedAccessibilityElement]
    let selectedScrollHierarchyElements: [ObservedAccessibilityElement]
    let waypoints: [ObservedScrollWaypointEvidence]
    let observedContentMovement: Bool
    let contentFitsWithoutScrolling: Bool
}

private struct ObservedScreenshotEvidence: Codable {
    let platform: String
    let route: String
    let viewport: ObservedRect
    let elements: [ObservedAccessibilityElement]
    let auditIssues: [ObservedAuditIssue]
    let auditTypes: [String]
    let verifiedContrastFalsePositives: [ObservedVerifiedContrastFalsePositive]
    let verifiedStaleOffscreenContrastFalsePositives: [ObservedVerifiedStaleOffscreenContrastFalsePositive]
    let contrastPixelAdjudicationDiagnostics: [ObservedContrastPixelAdjudicationDiagnostic]
    let verifiedSystemChromeContrastFalsePositives: [ObservedVerifiedSystemChromeContrastFalsePositive]
    let verifiedNativeSidebarSelectionContrastFalsePositives: [ObservedVerifiedNativeSidebarSelectionContrastFalsePositive]
    let verifiedTextClippedFalsePositives: [ObservedVerifiedTextClippedFalsePositive]
    let screenshotSHA256: String
    let readinessHandshake: ObservedReadinessHandshake
    let captureIdentity: ObservedCaptureIdentity
    let pixelAccessibilityBinding: ObservedPixelAccessibilityBinding
    let geometryFindings: [ObservedAccessibilityFinding]
    let deepScroll: ObservedDeepScrollEvidence?
    let operatingSystemVersion: String
    let observedContentSizeCategory: String
    let recordedAt: String
}

private struct ObservedRouteTerminalExpectation {
    let identifier: String
    let label: String
    let elementTypes: Set<String>
    let requiresInteraction: Bool
}

private extension Collection {
    func only(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        var result: Element?
        for element in self where try predicate(element) {
            guard result == nil else { return nil }
            result = element
        }
        return result
    }
}

@MainActor
final class NativeScreenshotEvidenceTests: XCTestCase {
    private static let evidencePathEnvironmentKey = "SPOONJOY_OBSERVED_ACCESSIBILITY_EVIDENCE_PATH"
    private static let requiredIdentifiersEnvironmentKey = "SPOONJOY_OBSERVED_REQUIRED_IDENTIFIERS"
    private static let peerPairsEnvironmentKey = "SPOONJOY_OBSERVED_PEER_PAIRS"
    private static let thisDeviceIdentifier = "settings.apns.this-device.heading"
    private static let pushDeliveryIdentifier = "settings.apns.push-delivery.heading"
    private static let notificationSyncIdentifier = "settings.apns.notification-sync.heading"
    private static let minimumTerminalDragDistance: CGFloat = 44
    private static let chromeTypes: Set<String> = [
        "navigationBar", "toolbar", "tabBar", "keyboard", "sheet", "alert"
    ]
    private static let actionableTypes: Set<String> = [
        "button", "switch", "textField", "secureTextField", "link", "slider", "stepper"
    ]
    private static let deepScrollRoutes: Set<String> = [
        "kitchen", "recipes", "saved-recipes", "recipe-detail", "recipe-editor", "recipe-covers",
        "cook-mode", "cook-log", "cookbooks", "cookbook-detail", "shopping-list", "chefs",
        "profile", "profile-graph", "search", "capture", "settings"
    ]

    func testObservedAccessibilityAndGeometry() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let route = environment["SPOONJOY_SCREENSHOT_EXPECTED_ROUTE"], !route.isEmpty else {
            throw XCTSkip("The external screenshot observer only runs for an explicit capture route.")
        }
        let app = XCUIApplication()
        app.launchEnvironment = environment.reduce(into: [:]) { result, pair in
            if pair.key.hasPrefix("SPOONJOY_") && pair.key != Self.evidencePathEnvironmentKey {
                result[pair.key] = pair.value
            }
        }
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15), "Spoonjoy did not present a window")
        waitForRenderedRoute(in: app, route: route, environment: environment)
        if route == "recipe-editor" {
            XCTAssertEqual(
                app.buttons.matching(identifier: "recipe-editor.save").count,
                1,
                "Recipe editor must have exactly one toolbar Save owner"
            )
        }

        let initialCapture = try captureAttestedScreenshot(
            in: app,
            route: route,
            captureRunNonce: environment["SPOONJOY_SCREENSHOT_RUN_NONCE"],
            capturePhase: "initial"
        )
        let capturedWindowFrame = initialCapture.windowFrame.cgRect
        let provisionalElements = initialCapture.elements
        let viewport = contentViewport(windowFrame: capturedWindowFrame, elements: provisionalElements)
        let apnsMode = environment["SPOONJOY_SCREENSHOT_SETTINGS_FOCUS"] == "notifications"
        var requiredIdentifiers = csvSet(environment[Self.requiredIdentifiersEnvironmentKey])
        requiredIdentifiers.formUnion(routeRequiredIdentifiers(route: route))
        var requiredVisibleIdentifiers = requiredIdentifiers
        requiredVisibleIdentifiers.subtract(routeRequiredChromeIdentifiers(route: route))
        requiredVisibleIdentifiers.subtract(routeRequiredScrollIdentifiers(route: route))
        if environment["SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY"]?.hasPrefix("accessibility") == true {
            requiredVisibleIdentifiers.subtract(routeRequiredAccessibilityScrollIdentifiers(route: route))
        }
        let requiredLabels = routeRequiredLabels(route: route, signedIn: environment["SPOONJOY_SCREENSHOT_AUTH"] != "0")
        if apnsMode {
            requiredIdentifiers.formUnion([
                Self.thisDeviceIdentifier,
                Self.pushDeliveryIdentifier,
                Self.notificationSyncIdentifier
            ])
            requiredVisibleIdentifiers.formUnion([
                Self.thisDeviceIdentifier,
                Self.pushDeliveryIdentifier
            ])
        }

        let requirements = ObservedGeometryRequirements(
            viewport: viewport,
            requiredIdentifiers: requiredIdentifiers,
            requiredVisibleIdentifiers: requiredVisibleIdentifiers,
            requiredLabels: requiredLabels,
            peerPairs: peerPairs(environment[Self.peerPairsEnvironmentKey]),
            chromeTypes: Self.chromeTypes,
            actionableTypes: Self.actionableTypes,
            minimumActionTarget: 44,
            apnsThisDeviceIdentifier: apnsMode ? Self.thisDeviceIdentifier : nil,
            apnsPushDeliveryIdentifier: apnsMode ? Self.pushDeliveryIdentifier : nil
        )
        let initialScreenshot = initialCapture.screenshot
        let readinessHandshake = initialCapture.handshake
        let initialAuditResult = accessibilityAuditIssues(
            in: app,
            viewport: viewport,
            screenshot: initialScreenshot,
            windowFrame: capturedWindowFrame,
            attestedElements: initialCapture.elements,
            contentSizeCategory: environment["SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY"] ?? "",
            capturePhase: "initial",
            scope: .initialFullTree
        )
        let initialElements = elementsWithHitRegionVerification(
            initialCapture.elements,
            windowFrame: capturedWindowFrame,
            hitRegionAuditVerified: initialAuditResult.hitRegionAuditPassed
        )
        let geometryFindings = ScreenshotEvidenceGeometry.validate(
            elements: initialElements,
            requirements: requirements
        )
        let terminalExpectation = routeTerminalExpectation(route: route, environment: environment)
        let deepScroll = Self.deepScrollRoutes.contains(route)
            ? try scrollPrimarySurfaceToTerminal(
                in: app,
                route: route,
                terminalExpectation: terminalExpectation,
                initialElements: initialElements,
                initialScreenshot: initialScreenshot,
                windowFrame: capturedWindowFrame,
                requiresSystemTabBar: UIDevice.current.userInterfaceIdiom == .phone
                    && environment["SPOONJOY_SCREENSHOT_AUTH"] != "0"
                    && routeUsesSystemTabBar(route)
            )
            : nil
        let auditResult = initialAuditResult
        let waypointAuditIssues = deepScroll?.waypoints.flatMap(\.auditIssues) ?? []
        let allAuditIssues = auditResult.blockingIssues
            + waypointAuditIssues
            + (deepScroll?.auditIssues ?? [])
        let verifiedContrastFalsePositives = auditResult.verifiedContrastFalsePositives
        let allContrastPixelAdjudicationDiagnostics = auditResult.contrastPixelAdjudicationDiagnostics
            + (deepScroll?.waypoints.flatMap(\.contrastPixelAdjudicationDiagnostics) ?? [])
            + (deepScroll?.contrastPixelAdjudicationDiagnostics ?? [])
        let evidence = ObservedScreenshotEvidence(
            platform: UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "ios",
            route: route,
            viewport: viewport,
            elements: initialElements,
            auditIssues: allAuditIssues,
            auditTypes: initialAuditResult.auditTypes,
            verifiedContrastFalsePositives: verifiedContrastFalsePositives,
            verifiedStaleOffscreenContrastFalsePositives: initialAuditResult.verifiedStaleOffscreenContrastFalsePositives,
            contrastPixelAdjudicationDiagnostics: allContrastPixelAdjudicationDiagnostics,
            verifiedSystemChromeContrastFalsePositives: initialAuditResult.verifiedSystemChromeContrastFalsePositives,
            verifiedNativeSidebarSelectionContrastFalsePositives: initialAuditResult.verifiedNativeSidebarSelectionContrastFalsePositives,
            verifiedTextClippedFalsePositives: initialAuditResult.verifiedTextClippedFalsePositives,
            screenshotSHA256: Self.sha256(initialScreenshot.pngRepresentation),
            readinessHandshake: readinessHandshake,
            captureIdentity: initialCapture.identity,
            pixelAccessibilityBinding: initialCapture.pixelAccessibilityBinding,
            geometryFindings: geometryFindings,
            deepScroll: deepScroll,
            operatingSystemVersion: UIDevice.current.systemVersion,
            observedContentSizeCategory: "pending-host-attestation",
            recordedAt: ISO8601DateFormatter().string(from: Date())
        )

        let data = try JSONEncoder.observedEvidence.encode(evidence)
        try writeEvidence(data, configuredPath: environment[Self.evidencePathEnvironmentKey])
        attachJSON(data, name: "observed-accessibility-evidence")
        attachScreenshot(initialScreenshot, name: "observed-accessibility-screenshot")

        XCTAssertTrue(
            allAuditIssues.isEmpty,
            "Accessibility audit found: \(allAuditIssues.map(\.compactDescription))"
        )
        XCTAssertTrue(geometryFindings.isEmpty, "Geometry found: \(geometryFindings.map(\.message))")
        if let deepScroll {
            XCTAssertTrue(deepScroll.reachedTerminal, "Primary surface did not reach a stable terminal position")
            if deepScroll.contentFitsWithoutScrolling {
                XCTAssertEqual(deepScroll.swipeCount, 0, "Content that already fits must not be disturbed by an overscroll probe")
            } else {
                XCTAssertGreaterThan(deepScroll.swipeCount, 0, "Scrollable content must perform a real scroll action")
            }
            XCTAssertTrue(
                deepScroll.observedContentMovement || deepScroll.contentFitsWithoutScrolling,
                "Deep-scroll evidence must observe movement or prove the terminal content already fits"
            )
            XCTAssertTrue(
                intermediateAuditCoverageIsComplete(
                    scrollActionCount: deepScroll.swipeCount,
                    waypointIndices: deepScroll.waypoints.map(\.index),
                    waypointAuditTypes: deepScroll.waypoints.map(\.auditTypes),
                    waypointHasOverlapProof: deepScroll.waypoints.map { $0.coverage != nil }
                ),
                "Every scroll action must have an ordered, overlap-proven accessibility audit waypoint"
            )
            XCTAssertTrue(deepScroll.findings.isEmpty, "Deep scroll found: \(deepScroll.findings.map(\.message))")
        }
    }

    func testGeometryRejectsMissingRequiredIdentifier() {
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [],
            requirements: requirements(required: ["missing"])
        )
        XCTAssertEqual(findings.map(\.kind), [.requiredIdentifierMissing])
    }

    func testInitialPixelAccessibilityBindingEncodesExactSchemaWithExplicitNullHierarchyFields() throws {
        let binding = ObservedPixelAccessibilityBinding(
            schema: "iosPixelAccessibilityBindingV1",
            captureID: "54857779-8c44-4b92-8184-ab76e45284cc",
            capturePhase: "initial",
            pixelSource: "mainScreen",
            screenshotSHA256: String(repeating: "a", count: 64),
            accessibilitySnapshotBeforeSHA256: String(repeating: "b", count: 64),
            accessibilitySnapshotAfterSHA256: String(repeating: "b", count: 64),
            windowFrame: ObservedRect(x: 0, y: 0, width: 402, height: 874),
            selectedScrollHierarchyIdentifier: nil,
            selectedScrollHierarchySnapshotBeforeSHA256: nil,
            selectedScrollHierarchySnapshotAfterSHA256: nil
        )

        let data = try JSONEncoder.observedEvidence.encode(binding)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), [
            "schema",
            "captureID",
            "capturePhase",
            "pixelSource",
            "screenshotSHA256",
            "accessibilitySnapshotBeforeSHA256",
            "accessibilitySnapshotAfterSHA256",
            "windowFrame",
            "selectedScrollHierarchyIdentifier",
            "selectedScrollHierarchySnapshotBeforeSHA256",
            "selectedScrollHierarchySnapshotAfterSHA256"
        ])
        XCTAssertTrue(object["selectedScrollHierarchyIdentifier"] is NSNull)
        XCTAssertTrue(object["selectedScrollHierarchySnapshotBeforeSHA256"] is NSNull)
        XCTAssertTrue(object["selectedScrollHierarchySnapshotAfterSHA256"] is NSNull)
    }

    func testDeepPixelAccessibilityBindingEncodesSelectedHierarchyValues() throws {
        let hierarchyDigest = String(repeating: "c", count: 64)
        let binding = ObservedPixelAccessibilityBinding(
            schema: "iosPixelAccessibilityBindingV1",
            captureID: "ae0e5a06-2728-47d3-a8bb-a97576a17c49",
            capturePhase: "deepScroll",
            pixelSource: "mainScreen",
            screenshotSHA256: String(repeating: "d", count: 64),
            accessibilitySnapshotBeforeSHA256: String(repeating: "e", count: 64),
            accessibilitySnapshotAfterSHA256: String(repeating: "e", count: 64),
            windowFrame: ObservedRect(x: 0, y: 0, width: 402, height: 874),
            selectedScrollHierarchyIdentifier: "spoonjoy.page-scroll",
            selectedScrollHierarchySnapshotBeforeSHA256: hierarchyDigest,
            selectedScrollHierarchySnapshotAfterSHA256: hierarchyDigest
        )

        let data = try JSONEncoder.observedEvidence.encode(binding)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["selectedScrollHierarchyIdentifier"] as? String, "spoonjoy.page-scroll")
        XCTAssertEqual(object["selectedScrollHierarchySnapshotBeforeSHA256"] as? String, hierarchyDigest)
        XCTAssertEqual(object["selectedScrollHierarchySnapshotAfterSHA256"] as? String, hierarchyDigest)
    }

    func testGeometryRejectsClippedOrOffscreenRequiredElement() {
        let element = observedElement(identifier: "required", frame: ObservedRect(x: 0, y: 90, width: 40, height: 20))
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [element],
            requirements: requirements(required: ["required"], visible: ["required"])
        )
        XCTAssertEqual(findings.map(\.kind), [.outsideViewport])
    }

    func testAuditRetainsContentPartiallyClippedVerticallyByChrome() {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 600)

        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 90, width: 160, height: 20),
            elementType: "staticText",
            viewport: viewport
        ))
    }

    func testAuditIgnoresContentFullyOutsideTheVerticalViewport() {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 600)

        XCTAssertTrue(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 720, width: 160, height: 20),
            elementType: "staticText",
            viewport: viewport
        ))
        XCTAssertTrue(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 40, width: 160, height: 20),
            elementType: "button",
            viewport: viewport
        ))
    }

    func testAuditIgnoresOnlyNegligiblyVisibleContentAtViewportBoundary() {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 600)

        XCTAssertTrue(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 699, width: 160, height: 20),
            elementType: "staticText",
            viewport: viewport
        ))
        XCTAssertTrue(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 81, width: 160, height: 20),
            elementType: "button",
            viewport: viewport
        ))
        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 698, width: 160, height: 20),
            elementType: "staticText",
            viewport: viewport
        ))
        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 82, width: 160, height: 20),
            elementType: "button",
            viewport: viewport
        ))
        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 0, y: 699, width: 400, height: 83),
            elementType: "tabBar",
            viewport: viewport
        ))
    }

    func testAuditRetainsContentClippedHorizontallyByTheViewport() {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 600)

        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: -10, y: 120, width: 160, height: 20),
            elementType: "staticText",
            viewport: viewport
        ))
        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 300, y: 120, width: 110, height: 20),
            elementType: "button",
            viewport: viewport
        ))
    }

    func testAuditRetainsFullyVisibleContentAndSystemChrome() {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 600)

        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 20, y: 120, width: 160, height: 20),
            elementType: "staticText",
            viewport: viewport
        ))
        XCTAssertFalse(shouldIgnoreAuditIssue(
            elementFrame: ObservedRect(x: 0, y: 60, width: 400, height: 54),
            elementType: "navigationBar",
            viewport: viewport
        ))
    }

    func testContentViewportReservesSystemScrollEdgeEffects() {
        let navigationBar = observedElement(
            identifier: "navigation",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 0, width: 402, height: 116)
        )
        let tabBar = observedElement(
            identifier: "tabs",
            type: "tabBar",
            frame: ObservedRect(x: 0, y: 791, width: 402, height: 83)
        )

        let viewport = contentViewport(
            windowFrame: CGRect(x: 0, y: 0, width: 402, height: 874),
            elements: [navigationBar, tabBar]
        )

        XCTAssertEqual(viewport, ObservedRect(x: 0, y: 140, width: 402, height: 651))
    }

    func testTerminalScrollCorrectionMovesClippedContentIntoViewport() {
        let viewport = ObservedRect(x: 0, y: 140, width: 402, height: 503)

        XCTAssertEqual(
            terminalScrollCorrection(
                terminalFrame: ObservedRect(x: 16, y: 107, width: 160, height: 26),
                viewport: viewport
            ),
            41
        )
        XCTAssertEqual(
            terminalScrollCorrection(
                terminalFrame: ObservedRect(x: 16, y: 630, width: 160, height: 26),
                viewport: viewport
            ),
            -21
        )
        XCTAssertNil(terminalScrollCorrection(
            terminalFrame: ObservedRect(x: 16, y: 200, width: 160, height: 26),
            viewport: viewport
        ))
    }

    func testTerminalDragDistanceClearsSmallChromeOcclusions() {
        XCTAssertEqual(terminalDragDistance(contentOffset: -10), -44)
        XCTAssertEqual(terminalDragDistance(contentOffset: 10), 44)
        XCTAssertEqual(terminalDragDistance(contentOffset: -60), -60)
    }

    func testContentMovementRejectsDuplicateLabelsWithoutStableIdentifiers() {
        let viewport = ObservedRect(x: 0, y: 0, width: 400, height: 600)
        let before = [
            observedElement(identifier: "", label: "Recipe", frame: ObservedRect(x: 20, y: 120, width: 160, height: 30)),
            observedElement(identifier: "", label: "Recipe", frame: ObservedRect(x: 20, y: 220, width: 160, height: 30))
        ]
        let after = [
            observedElement(identifier: "", label: "Recipe", frame: ObservedRect(x: 20, y: 80, width: 160, height: 30)),
            observedElement(identifier: "", label: "Recipe", frame: ObservedRect(x: 20, y: 180, width: 160, height: 30))
        ]

        XCTAssertFalse(didObserveContentMovement(before: before, after: after, viewport: viewport))
    }

    func testContentMovementRequiresUniqueStableIdentifierInBothFrames() {
        let viewport = ObservedRect(x: 0, y: 0, width: 400, height: 600)
        let duplicateBefore = [
            observedElement(identifier: "recipe.row", frame: ObservedRect(x: 20, y: 120, width: 160, height: 30)),
            observedElement(identifier: "recipe.row", frame: ObservedRect(x: 20, y: 220, width: 160, height: 30))
        ]
        let duplicateAfter = [
            observedElement(identifier: "recipe.row", frame: ObservedRect(x: 20, y: 80, width: 160, height: 30)),
            observedElement(identifier: "recipe.row", frame: ObservedRect(x: 20, y: 180, width: 160, height: 30))
        ]

        XCTAssertFalse(didObserveContentMovement(
            before: duplicateBefore,
            after: duplicateAfter,
            viewport: viewport
        ))
        XCTAssertTrue(didObserveContentMovement(
            before: [observedElement(identifier: "recipe.row", frame: ObservedRect(x: 20, y: 220, width: 160, height: 30))],
            after: [observedElement(identifier: "recipe.row", frame: ObservedRect(x: 20, y: 180, width: 160, height: 30))],
            viewport: viewport
        ))
    }

    func testNamedTerminalMovementAcceptsOffscreenToVisibleTransition() {
        let before = observedElement(
            identifier: "kitchen.cookbook.cookbook_weeknights",
            frame: ObservedRect(x: 20, y: 3_200, width: 308, height: 196)
        )
        let after = observedElement(
            identifier: "kitchen.cookbook.cookbook_weeknights",
            frame: ObservedRect(x: 20, y: 415, width: 308, height: 196)
        )

        XCTAssertTrue(didObserveIdentifiedMovement(before: before, after: after))
    }

    func testKitchenTerminalTraversesEveryCookbookToTheFinalFixtureObject() {
        let fixtureCookbookIdentifiers = [
            "kitchen.cookbook.cookbook_slow_sundays",
            "kitchen.cookbook.cookbook_weeknights"
        ]

        let expectation = routeTerminalExpectation(route: "kitchen", environment: [:])
        XCTAssertEqual(expectation?.identifier, fixtureCookbookIdentifiers.last)
        XCTAssertNotEqual(expectation?.identifier, fixtureCookbookIdentifiers.first)
        XCTAssertEqual(
            expectation?.label,
            "Weeknights"
        )
    }

    func testTerminalProofAcceptsContentThatAlreadyFitsWithoutADestructiveScrollProbe() {
        XCTAssertTrue(terminalProofIsValid(
            reachedStableTerminal: true,
            observedContentMovement: false,
            contentFitsWithoutScrolling: true,
            scrollActionCount: 0
        ))
        XCTAssertFalse(terminalProofIsValid(
            reachedStableTerminal: true,
            observedContentMovement: false,
            contentFitsWithoutScrolling: true,
            scrollActionCount: 1
        ))
        XCTAssertFalse(terminalProofIsValid(
            reachedStableTerminal: true,
            observedContentMovement: false,
            contentFitsWithoutScrolling: false,
            scrollActionCount: 1
        ))
    }

    func testPersistentChromeRejectsMissingOrMovedNavigationElements() {
        let before = [
            observedElement(
                identifier: "Kitchen",
                type: "navigationBar",
                frame: ObservedRect(x: 0, y: 62, width: 402, height: 54)
            ),
            observedElement(
                identifier: "tabs",
                label: "Tab Bar",
                type: "tabBar",
                frame: ObservedRect(x: 0, y: 791, width: 402, height: 83)
            ),
            observedElement(
                identifier: "house",
                label: "Kitchen",
                type: "button",
                frame: ObservedRect(x: 25, y: 795, width: 74, height: 54)
            )
        ]
        let stable = before
        let missingTab = [before[0]]
        let movedTitle = [
            observedElement(
                identifier: "Kitchen",
                type: "navigationBar",
                frame: ObservedRect(x: 0, y: 40, width: 402, height: 54)
            ),
            before[1],
            before[2]
        ]

        XCTAssertTrue(persistentChromeFindings(before: before, after: stable).isEmpty)
        XCTAssertEqual(persistentChromeFindings(before: before, after: missingTab).count, 1)
        let movedTitleFindings = persistentChromeFindings(before: before, after: movedTitle)
        XCTAssertEqual(movedTitleFindings.count, 1)
        XCTAssertTrue(movedTitleFindings[0].message.contains("Removed:"))
        XCTAssertTrue(movedTitleFindings[0].message.contains("Added:"))
    }

    func testPersistentChromeIgnoresScrolledContentBehindSystemTabBar() {
        let navigationBar = observedElement(
            identifier: "Kitchen",
            label: "",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 62, width: 402, height: 54)
        )
        let tabBar = observedElement(
            identifier: "tabs",
            label: "Tab Bar",
            type: "tabBar",
            frame: ObservedRect(x: 0, y: 791, width: 402, height: 83)
        )
        let tabButton = observedElement(
            identifier: "house",
            label: "Kitchen",
            type: "button",
            frame: ObservedRect(x: 25, y: 795, width: 74, height: 54)
        )
        let obscuredContent = observedElement(
            identifier: "",
            label: "Weeknights",
            type: "staticText",
            frame: ObservedRect(x: 183, y: 821, width: 118, height: 24)
        )

        XCTAssertTrue(persistentChromeFindings(
            before: [navigationBar, tabBar, tabButton, obscuredContent],
            after: [navigationBar, tabBar, tabButton]
        ).isEmpty)
    }

    func testPersistentChromeIgnoresObservedScrollContentBehindNavigationBar() {
        let navigationBar = observedElement(
            identifier: "Kitchen",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 62, width: 402, height: 54)
        )
        let headingBefore = observedElement(
            identifier: "",
            label: "LATEST FROM THE KITCHEN",
            type: "staticText",
            frame: ObservedRect(x: 38, y: 321, width: 159, height: 14)
        )
        let headingAfter = observedElement(
            identifier: "",
            label: "LATEST FROM THE KITCHEN",
            type: "staticText",
            frame: ObservedRect(x: 38, y: 99.5, width: 159, height: 14)
        )
        let structurallyObservedHeadingAfter = observedElement(
            identifier: "",
            label: "LATEST FROM THE KITCHEN",
            type: "staticText",
            frame: ObservedRect(x: 38.17, y: 99.63, width: 158.67, height: 13.33)
        )

        XCTAssertTrue(persistentChromeFindings(
            before: [navigationBar, headingBefore],
            after: [navigationBar, headingAfter],
            beforeScrollContent: [headingBefore],
            afterScrollContent: [structurallyObservedHeadingAfter]
        ).isEmpty)
    }

    func testPersistentChromeStillRejectsMovedNavigationTitleBesideObservedScrollContent() {
        let navigationBar = observedElement(
            identifier: "Kitchen",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 62, width: 402, height: 54)
        )
        let titleBefore = observedElement(
            identifier: "spoonjoy.navigation-title",
            label: "Kitchen",
            type: "staticText",
            frame: ObservedRect(x: 170, y: 74, width: 61, height: 21)
        )
        let titleAfter = observedElement(
            identifier: "spoonjoy.navigation-title",
            label: "Kitchen",
            type: "staticText",
            frame: ObservedRect(x: 154, y: 74, width: 61, height: 21)
        )
        let headingAfter = observedElement(
            identifier: "",
            label: "LATEST FROM THE KITCHEN",
            type: "staticText",
            frame: ObservedRect(x: 38, y: 99.5, width: 159, height: 14)
        )

        XCTAssertEqual(persistentChromeFindings(
            before: [navigationBar, titleBefore],
            after: [navigationBar, titleAfter, headingAfter],
            beforeScrollContent: [],
            afterScrollContent: [headingAfter]
        ).map(\.kind), [.persistentChromeChanged])
    }

    func testPersistentChromeRejectsChangedStructurallyNestedTabControl() {
        let tabBar = observedElement(
            identifier: "tabs",
            label: "Tab Bar",
            type: "tabBar",
            frame: ObservedRect(x: 0, y: 791, width: 402, height: 83)
        )
        let kitchenTab = observedElement(
            identifier: "house.fill",
            label: "Kitchen",
            type: "button",
            frame: ObservedRect(x: 25, y: 795, width: 74, height: 54)
        )
        let recipesTab = observedElement(
            identifier: "book.closed",
            label: "Recipes",
            type: "button",
            frame: ObservedRect(x: 25, y: 795, width: 74, height: 54)
        )

        XCTAssertEqual(
            persistentChromeFindings(
                before: [tabBar, kitchenTab],
                after: [tabBar, recipesTab]
            ).map(\.kind),
            [.persistentChromeChanged]
        )
    }

    func testPersistentChromeUsesStableLabelsWhenXCTestAddsSymbolIdentifiersAfterScroll() {
        let tabBar = observedElement(
            identifier: "tabs",
            label: "Tab Bar",
            type: "tabBar",
            frame: ObservedRect(x: 0, y: 791, width: 402, height: 83)
        )
        let kitchenBefore = observedElement(
            identifier: "",
            label: "Kitchen",
            type: "button",
            frame: ObservedRect(x: 25, y: 795, width: 74, height: 54)
        )
        let kitchenAfter = observedElement(
            identifier: "house",
            label: "Kitchen",
            type: "button",
            frame: ObservedRect(x: 25, y: 795, width: 74, height: 54)
        )

        XCTAssertTrue(persistentChromeFindings(
            before: [tabBar, kitchenBefore],
            after: [tabBar, kitchenAfter]
        ).isEmpty)
    }

    func testMovementCandidatesIncludeUniqueOffscreenContentButExcludeChrome() {
        let viewport = ObservedRect(x: 0, y: 0, width: 402, height: 874)
        let candidates = uniqueMovementCandidates(
            elements: [
                observedElement(
                    identifier: "kitchen.recipe-index.count",
                    frame: ObservedRect(x: 20, y: 1_604, width: 280, height: 53)
                ),
                observedElement(
                    identifier: "tabs",
                    type: "tabBar",
                    frame: ObservedRect(x: 0, y: 791, width: 402, height: 83)
                )
            ],
            viewport: viewport
        )

        XCTAssertEqual(candidates.map(\.identifier), ["kitchen.recipe-index.count"])
    }

    func testChromeContrastWaiverRequiresExactIssueBoundLargeTypeNativeCompactTabEvidence() {
        let windowFrame = ObservedRect(x: 0, y: 0, width: 834, height: 1_194)
        let navigationFrame = ObservedRect(x: 0, y: 32, width: 834, height: 54)
        let navigationBar = observedElement(
            identifier: "Kitchen",
            label: "",
            type: "navigationBar",
            frame: navigationFrame,
            hittable: true
        )
        let destinations = [
            observedElement(
                identifier: "house",
                label: "Kitchen",
                type: "button",
                frame: ObservedRect(x: 182, y: 32, width: 104, height: 41),
                hittable: true
            ),
            observedElement(
                identifier: "book.closed",
                label: "Recipes",
                type: "button",
                frame: ObservedRect(x: 286, y: 32, width: 107, height: 41),
                hittable: true
            ),
            observedElement(
                identifier: "bookmark",
                label: "Saved",
                type: "button",
                frame: ObservedRect(x: 393, y: 32, width: 90.5, height: 41),
                hittable: true
            ),
            observedElement(
                identifier: "books.vertical",
                label: "Cookbooks",
                type: "button",
                frame: ObservedRect(x: 483.5, y: 32, width: 138.5, height: 41),
                hittable: true
            )
        ]
        let issue = ObservedAuditIssue(
            category: "contrast",
            type: "XCUIAccessibilityAuditType(rawValue: 1)",
            compactDescription: "Contrast failed",
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            diagnosticDescription: "<XCUIAccessibilityAuditIssue> Element:Kitchen",
            diagnosticMirror: "",
            elementIdentifier: destinations[0].identifier,
            elementLabel: destinations[0].label,
            elementType: destinations[0].type,
            elementFrame: destinations[0].frame
        )
        let elements = [navigationBar] + destinations + destinations
        let screenshotSHA256 = String(repeating: "a", count: 64)
        let screenshotBuffer = syntheticChromePixelBuffer(
            width: Int(windowFrame.width),
            height: Int(windowFrame.height),
            frames: destinations.map(\.frame),
            foreground: ObservedRGBPixel(red: 40, green: 35, blue: 29),
            screenshotSHA256: screenshotSHA256
        )
        for frame in [navigationBar.frame] + destinations.map(\.frame) {
            let crop = try? XCTUnwrap(screenshotBuffer.crop(in: frame))
            XCTAssertNotNil(
                crop.flatMap {
                    ScreenshotPixelContrastAdjudicator.analyze(
                        pixels: $0.pixels,
                        width: $0.width,
                        height: $0.height,
                        screenshotSHA256: screenshotSHA256
                    )
                },
                "Expected high-contrast pixels in exact compact chrome frame \(frame)"
            )
        }

        let verified = verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: issue,
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        )
        XCTAssertEqual(verified?.schema, "iosNativeCompactTabChromeContrastFalsePositiveV2")
        XCTAssertEqual(verified?.reason, "elementContrastBoundToAttestedNativeCompactTabChrome")
        XCTAssertEqual(verified?.screenshotSHA256, screenshotSHA256)
        XCTAssertEqual(verified?.issueElement.frame, destinations[0].frame)
        XCTAssertEqual(verified?.pixelEvidence.count, 4)
        XCTAssertEqual(verified?.navigationBar.frame, navigationFrame)
        XCTAssertEqual(verified?.destinations.map(\.label), ["Kitchen", "Recipes", "Saved", "Cookbooks"])
        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: anonymousContrastIssue(),
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))

        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: issue,
            elements: elements,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: issue,
            elements: elements,
            screenshotBuffer: syntheticChromePixelBuffer(
                width: Int(windowFrame.width),
                height: Int(windowFrame.height),
                frames: destinations.map(\.frame),
                foreground: ObservedRGBPixel(red: 145, green: 141, blue: 136),
                screenshotSHA256: screenshotSHA256
            ),
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))

        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: issue,
            elements: elements,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: ObservedAuditIssue(
                category: issue.category,
                type: issue.type,
                compactDescription: issue.compactDescription,
                detailedDescription: issue.detailedDescription,
                diagnosticDescription: issue.diagnosticDescription,
                diagnosticMirror: issue.diagnosticMirror,
                elementIdentifier: "app.content",
                elementLabel: "Recipe Index",
                elementType: "staticText",
                elementFrame: ObservedRect(x: 20, y: 746, width: 341.5, height: 67)
            ),
            elements: elements,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: issue,
            elements: [navigationBar] + Array(destinations.dropLast()),
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeCompactTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "accessibility-extra-extra-extra-large",
            issue: issue,
            elements: elements + [observedElement(
                identifier: "house",
                label: "Kitchen",
                type: "button",
                frame: ObservedRect(x: 12, y: 300, width: 104, height: 41),
                hittable: true
            )],
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
    }

    func testSidebarContrastWaiverRequiresExactIssueBoundSelectionPixelAttestation() {
        let width = 700
        let height = 900
        let paper = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        let selection = ObservedRGBPixel(red: 224, green: 223, blue: 220)
        let ink = ObservedRGBPixel(red: 40, green: 35, blue: 29)
        var pixels = Array(repeating: paper, count: width * height)
        func paint(_ frame: ObservedRect, color: ObservedRGBPixel) {
            for row in Int(frame.minY)..<Int(frame.maxY) {
                for column in Int(frame.minX)..<Int(frame.maxX) {
                    pixels[row * width + column] = color
                }
            }
        }

        let windowFrame = ObservedRect(x: 0, y: 0, width: Double(width), height: Double(height))
        let sidebarNavigationBar = observedElement(
            identifier: "Spoonjoy",
            label: "",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 32, width: 320, height: 54)
        )
        let detailNavigationBar = observedElement(
            identifier: "Kitchen",
            label: "",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 32, width: 700, height: 106)
        )
        let sidebarCollection = observedElement(
            identifier: "",
            label: "Sidebar",
            type: "collectionView",
            frame: ObservedRect(x: 0, y: 32, width: 320, height: 850)
        )
        let selectedFrame = ObservedRect(x: 20, y: 100, width: 288, height: 64)
        let selectedCell = observedElement(
            identifier: "",
            label: "",
            type: "cell",
            frame: selectedFrame
        )
        let selectedLabel = observedElement(
            identifier: "",
            label: "Kitchen",
            type: "staticText",
            frame: selectedFrame
        )
        let selectedSymbolFrame = ObservedRect(x: 38, y: 118, width: 28, height: 28)
        let selectedSymbol = observedElement(
            identifier: "house",
            label: "Home",
            type: "image",
            frame: selectedSymbolFrame
        )
        paint(selectedFrame, color: selection)
        paint(ObservedRect(x: 45, y: 124, width: 8, height: 16), color: ink)
        paint(ObservedRect(x: 82, y: 124, width: 70, height: 16), color: ink)

        var visibleTextElements: [ObservedAccessibilityElement] = []
        var visibleTextFrames: [ObservedRect] = []
        for index in 0..<20 {
            let frame = ObservedRect(x: 360, y: 150 + Double(index * 30), width: 160, height: 20)
            visibleTextFrames.append(frame)
            visibleTextElements.append(observedElement(
                identifier: "content.text.\(index)",
                label: "Visible text \(index)",
                frame: frame
            ))
            paint(
                ObservedRect(x: frame.x + 12, y: frame.y + 5, width: 40, height: 10),
                color: ink
            )
        }

        let issue = ObservedAuditIssue(
            category: "contrast",
            type: "XCUIAccessibilityAuditType(rawValue: 1)",
            compactDescription: "Contrast failed",
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            diagnosticDescription: "<XCUIAccessibilityAuditIssue> Element:Kitchen",
            diagnosticMirror: "",
            elementIdentifier: "",
            elementLabel: selectedLabel.label,
            elementType: selectedLabel.type,
            elementFrame: selectedLabel.frame
        )
        let elements = [
            sidebarNavigationBar,
            detailNavigationBar,
            sidebarCollection,
            selectedCell,
            selectedLabel,
            selectedSymbol
        ] + visibleTextElements
        let screenshotSHA256 = String(repeating: "a", count: 64)
        let screenshotBuffer = ScreenshotPixelBuffer(
            width: width,
            height: height,
            pixels: pixels,
            pointSize: CGSize(width: width, height: height),
            screenshotSHA256: screenshotSHA256
        )

        let verified = verifiedNativeSidebarSelectionContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        )
        XCTAssertEqual(verified?.schema, "iosNativeSidebarSelectionContrastFalsePositiveV3")
        XCTAssertEqual(verified?.reason, "elementContrastBoundToAttestedNativeSidebarSelection")
        XCTAssertEqual(verified?.screenshotSHA256, screenshotSHA256)
        XCTAssertEqual(verified?.issueElement.frame, selectedLabel.frame)
        XCTAssertEqual(verified?.issuePixelEvidence.screenshotSHA256, screenshotSHA256)
        XCTAssertEqual(verified?.selectedCell.frame, selectedFrame)
        XCTAssertEqual(verified?.selectedSymbol.frame, selectedSymbolFrame)
        XCTAssertEqual(verified?.visibleTextPixelEvidence.count, 21)
        XCTAssertTrue(verified?.visibleTextPixelEvidence.allSatisfy {
            $0.pixelEvidence.screenshotSHA256 == screenshotSHA256
                && $0.pixelEvidence.contrastRatio >= 4.5
        } == true)
        XCTAssertNil(verifiedNativeSidebarSelectionContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "large",
            issue: anonymousContrastIssue(),
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))

        var unprovenPixels = pixels
        let unprovenFrame = visibleTextFrames[7]
        for row in Int(unprovenFrame.minY)..<Int(unprovenFrame.maxY) {
            for column in Int(unprovenFrame.minX)..<Int(unprovenFrame.maxX) {
                unprovenPixels[row * width + column] = paper
            }
        }
        let unprovenBuffer = ScreenshotPixelBuffer(
            width: width,
            height: height,
            pixels: unprovenPixels,
            pointSize: CGSize(width: width, height: height),
            screenshotSHA256: screenshotSHA256
        )
        XCTAssertNil(verifiedNativeSidebarSelectionContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements,
            screenshotBuffer: unprovenBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarSelectionContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarSelectionContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "extra-large",
            issue: issue,
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarSelectionContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements.filter { $0.type != "image" },
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarSelectionContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "large",
            issue: ObservedAuditIssue(
                category: issue.category,
                type: issue.type,
                compactDescription: issue.compactDescription,
                detailedDescription: issue.detailedDescription,
                diagnosticDescription: issue.diagnosticDescription,
                diagnosticMirror: issue.diagnosticMirror,
                elementIdentifier: "content.text.0",
                elementLabel: "Visible text 0",
                elementType: "staticText",
                elementFrame: visibleTextFrames[0]
            ),
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
    }

    func testChromeContrastWaiverRequiresExactIssueBoundPhoneBottomTabEvidence() {
        let windowFrame = ObservedRect(x: 0, y: 0, width: 402, height: 874)
        let navigationBar = observedElement(
            identifier: "Kitchen",
            label: "",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 62, width: 402, height: 54),
            hittable: true
        )
        let tabBar = observedElement(
            identifier: "",
            label: "Tab Bar",
            type: "tabBar",
            frame: ObservedRect(x: 0, y: 791, width: 402, height: 83),
            hittable: true
        )
        let destinations = [
            ("house", "Kitchen", ObservedRect(x: 25, y: 795, width: 74, height: 54)),
            ("book.closed", "Recipes", ObservedRect(x: 90, y: 795, width: 74, height: 54)),
            ("bookmark", "Saved", ObservedRect(x: 155, y: 795, width: 74, height: 54)),
            ("books.vertical", "Cookbooks", ObservedRect(x: 220, y: 795, width: 87, height: 54)),
            ("checklist", "Shopping", ObservedRect(x: 298, y: 795, width: 79, height: 54))
        ].map { identifier, label, frame in
            observedElement(
                identifier: identifier,
                label: label,
                type: "button",
                frame: frame,
                hittable: true
            )
        }
        let issue = ObservedAuditIssue(
            category: "contrast",
            type: "XCUIAccessibilityAuditType(rawValue: 1)",
            compactDescription: "Contrast failed",
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            diagnosticDescription: "<XCUIAccessibilityAuditIssue> Element:Kitchen",
            diagnosticMirror: "",
            elementIdentifier: destinations[0].identifier,
            elementLabel: destinations[0].label,
            elementType: destinations[0].type,
            elementFrame: destinations[0].frame
        )
        let elements = [navigationBar, tabBar] + destinations + destinations
        let screenshotSHA256 = String(repeating: "b", count: 64)
        let screenshotBuffer = syntheticChromePixelBuffer(
            width: Int(windowFrame.width),
            height: Int(windowFrame.height),
            frames: [navigationBar.frame] + destinations.map(\.frame),
            foreground: ObservedRGBPixel(red: 40, green: 35, blue: 29),
            screenshotSHA256: screenshotSHA256
        )
        for frame in [navigationBar.frame, tabBar.frame] + destinations.map(\.frame) {
            let crop = try? XCTUnwrap(screenshotBuffer.crop(in: frame))
            XCTAssertNotNil(
                crop.flatMap {
                    ScreenshotPixelContrastAdjudicator.analyze(
                        pixels: $0.pixels,
                        width: $0.width,
                        height: $0.height,
                        screenshotSHA256: screenshotSHA256
                    )
                },
                "Expected high-contrast pixels in exact bottom chrome frame \(frame)"
            )
        }

        for contentSizeCategory in [
            "large",
            "extra-extra-extra-large",
            "accessibility-extra-extra-extra-large"
        ] {
            let verified = verifiedNativeBottomTabChromeContrastFalsePositive(
                idiom: .phone,
                contentSizeCategory: contentSizeCategory,
                issue: issue,
                elements: elements,
                screenshotBuffer: screenshotBuffer,
                screenshotSHA256: screenshotSHA256,
                windowFrame: windowFrame,
                capturePhase: "deepScroll"
            )
            XCTAssertEqual(verified?.schema, "iosNativeBottomTabChromeContrastFalsePositiveV3")
            XCTAssertEqual(verified?.reason, "elementContrastBoundToAttestedNativeBottomTabChrome")
            XCTAssertEqual(verified?.screenshotSHA256, screenshotSHA256)
            XCTAssertEqual(verified?.issueElement.frame, destinations[0].frame)
            XCTAssertEqual(verified?.pixelEvidence.count, 5)
            XCTAssertEqual(verified?.tabBar?.frame, tabBar.frame)
            XCTAssertEqual(verified?.destinations.map(\.label), ["Kitchen", "Recipes", "Saved", "Cookbooks", "Shopping"])
        }
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: anonymousContrastIssue(),
            elements: elements,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))

        let largeTypeLabelOnlyDestinations = destinations.map { destination in
            observedElement(
                identifier: "",
                label: destination.label,
                type: destination.type,
                frame: destination.frame,
                hittable: true
            )
        }
        let labelOnlyIssue = ObservedAuditIssue(
            category: issue.category,
            type: issue.type,
            compactDescription: issue.compactDescription,
            detailedDescription: issue.detailedDescription,
            diagnosticDescription: issue.diagnosticDescription,
            diagnosticMirror: issue.diagnosticMirror,
            elementIdentifier: "",
            elementLabel: largeTypeLabelOnlyDestinations[0].label,
            elementType: largeTypeLabelOnlyDestinations[0].type,
            elementFrame: largeTypeLabelOnlyDestinations[0].frame
        )
        for contentSizeCategory in [
            "extra-extra-extra-large",
            "accessibility-extra-extra-extra-large"
        ] {
            let verified = verifiedNativeBottomTabChromeContrastFalsePositive(
                idiom: .phone,
                contentSizeCategory: contentSizeCategory,
                issue: labelOnlyIssue,
                elements: [navigationBar, tabBar] + largeTypeLabelOnlyDestinations + largeTypeLabelOnlyDestinations,
                screenshotBuffer: screenshotBuffer,
                screenshotSHA256: screenshotSHA256,
                windowFrame: windowFrame,
                capturePhase: "initial"
            )
            XCTAssertEqual(verified?.schema, "iosNativeLargeTypeBottomTabChromeContrastFalsePositiveV4")
            XCTAssertEqual(verified?.reason, "elementContrastBoundToAttestedNativeLargeTypeBottomTabChrome")
            XCTAssertEqual(verified?.destinations.map(\.identifier), ["", "", "", "", ""])
        }
        let ordinaryLabelOnly = verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: labelOnlyIssue,
            elements: [navigationBar, tabBar] + largeTypeLabelOnlyDestinations,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        )
        XCTAssertEqual(ordinaryLabelOnly?.schema, "iosNativeLabelOnlyBottomTabChromeContrastFalsePositiveV5")
        XCTAssertEqual(ordinaryLabelOnly?.reason, "elementContrastBoundToAttestedNativeLabelOnlyBottomTabChrome")
        XCTAssertEqual(ordinaryLabelOnly?.destinations.map(\.identifier), ["", "", "", "", ""])
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements,
            screenshotBuffer: syntheticChromePixelBuffer(
                width: Int(windowFrame.width),
                height: Int(windowFrame.height),
                frames: [navigationBar.frame] + destinations.map(\.frame),
                foreground: ObservedRGBPixel(red: 145, green: 141, blue: 136),
                screenshotSHA256: screenshotSHA256
            ),
            screenshotSHA256: screenshotSHA256,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: issue,
            elements: [navigationBar, tabBar] + largeTypeLabelOnlyDestinations,
            windowFrame: windowFrame,
            capturePhase: "deepScroll"
        ))
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "extra-extra-extra-large",
            issue: issue,
            elements: [navigationBar, tabBar] + Array(largeTypeLabelOnlyDestinations.dropLast()) + [destinations.last!],
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))

        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .pad,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "extra-large",
            issue: issue,
            elements: elements,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: issue,
            elements: [navigationBar, tabBar] + Array(destinations.dropLast()),
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: issue,
            elements: [navigationBar] + destinations,
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeBottomTabChromeContrastFalsePositive(
            idiom: .phone,
            contentSizeCategory: "large",
            issue: issue,
            elements: elements + [observedElement(
                identifier: "checklist",
                label: "Shopping",
                type: "button",
                frame: ObservedRect(x: 20, y: 700, width: 79, height: 54),
                hittable: true
            )],
            windowFrame: windowFrame,
            capturePhase: "initial"
        ))
    }

    func testPersistentChromeIgnoresSubpointObservationJitter() {
        let before = observedElement(
            identifier: "Kitchen",
            type: "navigationBar",
            frame: ObservedRect(x: 350, y: 89.5, width: 122, height: 41)
        )
        let after = observedElement(
            identifier: "Kitchen",
            type: "navigationBar",
            frame: ObservedRect(x: 350, y: 89.125, width: 122, height: 41)
        )

        XCTAssertTrue(persistentChromeFindings(before: [before], after: [after]).isEmpty)
    }

    func testContrastAuditMatchesAUniqueElementBackToTheAttestedPixelFrame() {
        let elements = [
            observedElement(
                identifier: "recipe.attribution",
                label: "by @ari",
                frame: ObservedRect(x: 38, y: 512, width: 63, height: 22)
            )
        ]

        XCTAssertEqual(
            attestedFrameForAuditElement(
                identifier: "",
                label: "by @ari",
                type: "staticText",
                elements: elements
            ),
            elements[0].frame
        )
        XCTAssertNil(attestedFrameForAuditElement(
            identifier: "",
            label: "by @ari",
            type: "staticText",
            elements: elements + elements
        ))
        XCTAssertNil(attestedFrameForAuditElement(
            identifier: "",
            label: "",
            type: "staticText",
            elements: elements
        ))
        XCTAssertEqual(
            auditElementAttestation(
                identifier: "",
                label: "by @ari",
                type: "staticText",
                elements: elements + elements
            ).matchingCount,
            2
        )
    }

    func testBlockingContrastPixelDiagnosticEncodesTheExactFailedStage() throws {
        let issue = ObservedAuditIssue(
            category: "contrast",
            type: "XCUIAccessibilityAuditType(rawValue: 1)",
            compactDescription: "Contrast failed",
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            diagnosticDescription: "diagnostic",
            diagnosticMirror: "",
            elementIdentifier: "",
            elementLabel: "My Kitchen",
            elementType: "staticText",
            elementFrame: ObservedRect(x: 20, y: 71, width: 318, height: 72)
        )
        let diagnostic = ObservedContrastPixelAdjudicationDiagnostic(
            schema: "iosContrastPixelAdjudicationFailureV1",
            capturePhase: "initial",
            issue: issue,
            matchingAttestedElementCount: 0,
            attestedFrame: nil,
            screenshotBufferAvailable: true,
            screenshotSHA256: String(repeating: "c", count: 64),
            screenshotPixelWidth: 1_206,
            screenshotPixelHeight: 2_622,
            attempts: [ObservedContrastPixelAdjudicationAttempt(
                source: "audit",
                frame: ObservedRect(x: 20, y: 71, width: 318, height: 72),
                outcome: "analyzerRejected",
                cropWidth: 954,
                cropHeight: 216
            )]
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(diagnostic)) as? [String: Any]
        )
        XCTAssertEqual(
            object.keys.sorted(),
            [
                "attempts", "attestedFrame", "capturePhase", "issue",
                "matchingAttestedElementCount", "schema", "screenshotBufferAvailable",
                "screenshotPixelHeight", "screenshotPixelWidth", "screenshotSHA256"
            ]
        )
        XCTAssertTrue(object["attestedFrame"] is NSNull)
        let attempt = try XCTUnwrap((object["attempts"] as? [[String: Any]])?.first)
        XCTAssertEqual(attempt.keys.sorted(), ["cropHeight", "cropWidth", "frame", "outcome", "source"])
        XCTAssertEqual(attempt["outcome"] as? String, "analyzerRejected")
    }

    func testPixelAdjudicationPrefersTheAttestedFrameOverTheRawAuditFrame() {
        let raw = ObservedRect(x: 10, y: 10, width: 100, height: 20)
        let attested = ObservedRect(x: 30, y: 40, width: 120, height: 30)

        XCTAssertEqual(pixelAdjudicationFrames(elementFrame: raw, attestedFrame: attested), [attested])
        XCTAssertEqual(pixelAdjudicationFrames(elementFrame: raw, attestedFrame: nil), [raw])
        XCTAssertEqual(pixelAdjudicationFrames(elementFrame: nil, attestedFrame: nil), [])
    }

    func testNativeIPadSidebarClippingWarningRequiresExactFrameBoundAttestation() {
        let sidebar = observedElement(
            identifier: "",
            label: "Sidebar",
            type: "collectionView",
            frame: ObservedRect(x: 10, y: 32, width: 320, height: 1168)
        )
        let row = observedElement(
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            frame: ObservedRect(x: 26, y: 206, width: 288, height: 44)
        )
        let exactDetail = "Text of this SwiftUI.AccessibilityNode may be clipped at larger Dynamic Type sizes."

        let verified = verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .pad,
            auditType: .textClipped,
            detailedDescription: exactDetail,
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            elements: [sidebar, row],
            capturePhase: "initial"
        )
        XCTAssertEqual(verified?.schema, "iosNativeSidebarTextClippedFalsePositiveV1")
        XCTAssertEqual(verified?.reason, "nativeSidebarRowExpandedWithinAttestedContainer")
        XCTAssertEqual(verified?.elementFrame, row.frame)
        XCTAssertEqual(verified?.containerFrame, sidebar.frame)

        XCTAssertNil(verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .phone,
            auditType: .textClipped,
            detailedDescription: exactDetail,
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            elements: [sidebar, row],
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .pad,
            auditType: .textClipped,
            detailedDescription: "Different warning",
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            elements: [sidebar, row],
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .pad,
            auditType: .textClipped,
            detailedDescription: exactDetail,
            identifier: "",
            label: "Unknown",
            type: "staticText",
            elements: [sidebar, row],
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .pad,
            auditType: .textClipped,
            detailedDescription: exactDetail,
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            elements: [sidebar, row, row],
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .pad,
            auditType: .textClipped,
            detailedDescription: exactDetail,
            identifier: "",
            label: "Cookbooks",
            type: "button",
            elements: [sidebar, row],
            capturePhase: "initial"
        ))
        XCTAssertNil(verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .pad,
            auditType: .textClipped,
            detailedDescription: exactDetail,
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            elements: [row],
            capturePhase: "initial"
        ))
        let outsideRow = observedElement(
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            frame: ObservedRect(x: 500, y: 206, width: 288, height: 44)
        )
        XCTAssertNil(verifiedNativeSidebarTextClippedFalsePositive(
            idiom: .pad,
            auditType: .textClipped,
            detailedDescription: exactDetail,
            identifier: "",
            label: "Cookbooks",
            type: "staticText",
            elements: [sidebar, outsideRow],
            capturePhase: "initial"
        ))
    }

    func testInitialAuditCoversVisualTypographyAndInteractionFailures() {
        let auditTypes = accessibilityAuditTypes(
            scope: .initialFullTree,
            includesDynamicTypeChecks: true
        )

        XCTAssertTrue(auditTypes.contains(.contrast))
        XCTAssertTrue(auditTypes.contains(.dynamicType))
        XCTAssertTrue(auditTypes.contains(.textClipped))
        XCTAssertTrue(auditTypes.contains(.hitRegion))
        XCTAssertTrue(auditTypes.contains(.trait))
    }

    func testSettledTerminalAuditCoversVisualTypographyAndInteractionFailures() {
        let auditTypes = accessibilityAuditTypes(
            scope: .settledTerminalInteraction,
            includesDynamicTypeChecks: true
        )

        XCTAssertTrue(auditTypes.contains(.contrast))
        XCTAssertTrue(auditTypes.contains(.dynamicType))
        XCTAssertTrue(auditTypes.contains(.textClipped))
        XCTAssertTrue(auditTypes.contains(.hitRegion))
        XCTAssertTrue(auditTypes.contains(.trait))
    }

    func testSettledScrollWaypointAuditCoversVisualTypographyAndInteractionFailures() {
        let auditTypes = accessibilityAuditTypes(
            scope: .settledScrollWaypoint,
            includesDynamicTypeChecks: true
        )

        XCTAssertTrue(auditTypes.contains(.contrast))
        XCTAssertTrue(auditTypes.contains(.dynamicType))
        XCTAssertTrue(auditTypes.contains(.textClipped))
        XCTAssertTrue(auditTypes.contains(.hitRegion))
        XCTAssertTrue(auditTypes.contains(.trait))
    }

    func testIntermediateWaypointCoverageRejectsViewportGaps() throws {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 600)
        let before = [
            observedElement(
                identifier: "recipe.waypoint.anchor",
                frame: ObservedRect(x: 20, y: 300, width: 200, height: 44)
            )
        ]
        let overlappingAfter = [
            observedElement(
                identifier: "recipe.waypoint.anchor",
                frame: ObservedRect(x: 20, y: 0, width: 200, height: 44)
            )
        ]
        let gappedAfter = [
            observedElement(
                identifier: "recipe.waypoint.anchor",
                frame: ObservedRect(x: 20, y: -300, width: 200, height: 44)
            )
        ]

        let coverage = try XCTUnwrap(scrollWaypointCoverage(
            requestedContentOffset: -300,
            before: before,
            after: overlappingAfter,
            viewport: viewport
        ))
        XCTAssertEqual(coverage.observedContentDisplacement, 300)
        XCTAssertEqual(coverage.viewportOverlap, 300)
        XCTAssertNil(scrollWaypointCoverage(
            requestedContentOffset: -600,
            before: before,
            after: gappedAfter,
            viewport: viewport
        ))
    }

    func testIntermediateAuditCoverageRequiresOneCompleteWaypointPerScrollAction() {
        let requiredAuditTypes = ["contrast", "dynamicType", "textClipped", "hitRegion", "trait"]

        XCTAssertTrue(intermediateAuditCoverageIsComplete(
            scrollActionCount: 2,
            waypointIndices: [1, 2],
            waypointAuditTypes: [requiredAuditTypes, requiredAuditTypes],
            waypointHasOverlapProof: [true, true]
        ))
        XCTAssertFalse(intermediateAuditCoverageIsComplete(
            scrollActionCount: 2,
            waypointIndices: [1],
            waypointAuditTypes: [requiredAuditTypes],
            waypointHasOverlapProof: [true]
        ))
        XCTAssertFalse(intermediateAuditCoverageIsComplete(
            scrollActionCount: 2,
            waypointIndices: [1, 2],
            waypointAuditTypes: [requiredAuditTypes, ["contrast", "trait"]],
            waypointHasOverlapProof: [true, true]
        ))
        XCTAssertFalse(intermediateAuditCoverageIsComplete(
            scrollActionCount: 2,
            waypointIndices: [1, 2],
            waypointAuditTypes: [requiredAuditTypes, requiredAuditTypes],
            waypointHasOverlapProof: [true, false]
        ))
    }

    func testEveryDeepScrollRouteHasAnExactSourceGroundedTerminal() {
        for route in Self.deepScrollRoutes {
            let expectation = routeTerminalExpectation(route: route, environment: [:])
            XCTAssertNotNil(expectation, "Missing terminal expectation for \(route)")
            XCTAssertFalse(expectation?.identifier.isEmpty == true, "Missing terminal identifier for \(route)")
            XCTAssertFalse(expectation?.label.isEmpty == true, "Missing terminal label for \(route)")
            XCTAssertFalse(expectation?.elementTypes.isEmpty == true, "Missing terminal role for \(route)")
        }
    }

    func testKitchenInitialFrameDoesNotClaimItsDeepScrollTerminal() {
        let initialLabels = routeRequiredLabels(route: "kitchen", signedIn: true)
        let terminal = routeTerminalExpectation(route: "kitchen", environment: [:])

        XCTAssertFalse(initialLabels.contains("Cookbook Shelf"))
        XCTAssertFalse(initialLabels.contains("Slow Sundays and Long Simmering Suppers"))
        XCTAssertEqual(terminal?.identifier, "kitchen.cookbook.cookbook_weeknights")
        XCTAssertEqual(terminal?.label, "Weeknights")
    }

    func testEveryVariantHasAnExactTerminalContract() {
        let cases: [(String, [String: String], String, String, Set<String>, Bool)] = [
            ("shopping-list", ["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT": "normal"], "shopping-list.terminal", "parmesan, 0.5 cup, Dairy", ["button", "switch"], true),
            ("shopping-list", ["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT": "empty"], "shopping-list.terminal", "Add from recipe", ["button", "switch"], true),
            ("shopping-list", ["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT": "all-complete"], "shopping-list.terminal", "Add from recipe", ["button", "switch"], true),
            ("shopping-list", ["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT": "duplicate"], "shopping-list.terminal", "parmesan, 0.5 cup, Dairy", ["button", "switch"], true),
            ("shopping-list", ["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT": "conflict"], "shopping-list.terminal", "parmesan, 0.5 cup, Dairy", ["button", "switch"], true),
            ("shopping-list", ["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT": "offline-queued"], "shopping-list.terminal", "parmesan, 0.5 cup, Dairy", ["button", "switch"], true),
            ("search", ["SPOONJOY_SCREENSHOT_SEARCH_VARIANT": "blank"], "search.terminal", "Shopping item, parmesan, 0.5 cup", ["button"], true),
            ("search", ["SPOONJOY_SCREENSHOT_SEARCH_VARIANT": "typed-results"], "search.terminal", "Shopping item, lemons, 2 each", ["button"], true),
            ("search", ["SPOONJOY_SCREENSHOT_SEARCH_VARIANT": "scoped-shopping"], "search.terminal", "Shopping item, lemons, 2 each", ["button"], true),
            ("search", ["SPOONJOY_SCREENSHOT_SEARCH_VARIANT": "scoped-recipes"], "search.terminal", "Recipe, Lemon Pantry Pasta, Bright pantry pasta with lemon, garlic, and parmesan.", ["button"], true),
            ("search", ["SPOONJOY_SCREENSHOT_SEARCH_VARIANT": "scoped-cookbooks"], "search.terminal", "Cookbook, Weeknights, 2 recipes", ["button"], true),
            ("search", ["SPOONJOY_SCREENSHOT_SEARCH_VARIANT": "scoped-chefs"], "search.terminal", "Chef, ari, Chef", ["button"], true),
            ("search", ["SPOONJOY_SCREENSHOT_SEARCH_VARIANT": "no-results"], "search.terminal", "No Spoonjoy results match \"kumquat\".", ["staticText"], false),
            ("capture", ["SPOONJOY_SCREENSHOT_CAPTURE_VARIANT": "empty", "SPOONJOY_SCREENSHOT_AUTH": "1"], "capture.terminal", "New recipes from your Spoonjoy agent will appear here.", ["staticText"], false),
            ("capture", ["SPOONJOY_SCREENSHOT_CAPTURE_VARIANT": "draft", "SPOONJOY_SCREENSHOT_AUTH": "1"], "capture.terminal", "Import actions", ["button"], true),
            ("capture", ["SPOONJOY_SCREENSHOT_CAPTURE_VARIANT": "offline-retry", "SPOONJOY_SCREENSHOT_AUTH": "1"], "capture.terminal", "Import actions", ["button"], true),
            ("capture", ["SPOONJOY_SCREENSHOT_CAPTURE_VARIANT": "provider-blocked", "SPOONJOY_SCREENSHOT_AUTH": "1"], "capture.terminal", "Import actions", ["button"], true),
            ("capture", ["SPOONJOY_SCREENSHOT_CAPTURE_VARIANT": "signed-out", "SPOONJOY_SCREENSHOT_AUTH": "0"], "native sign-in settings", "Settings", ["button"], true)
        ]

        for (route, environment, identifier, label, elementTypes, requiresInteraction) in cases {
            let expectation = routeTerminalExpectation(route: route, environment: environment)
            XCTAssertEqual(expectation?.identifier, identifier, "terminal identifier mismatch for \(route) \(environment)")
            XCTAssertEqual(expectation?.label, label, "terminal label mismatch for \(route) \(environment)")
            XCTAssertEqual(expectation?.elementTypes, elementTypes, "terminal role mismatch for \(route) \(environment)")
            XCTAssertEqual(expectation?.requiresInteraction, requiresInteraction, "terminal interaction mismatch for \(route) \(environment)")
        }
    }

    func testReadinessHandshakeRequiresGenerationBoundProofArchive() {
        let nonce = "123e4567-e89b-12d3-a456-426614174000"
        XCTAssertNotNil(parseReadinessHandshake(
            "Screenshot readiness|\(nonce)|kitchen|KitchenView|42012|12|screenshot-accessibility-proof.generation-12.json|\(String(repeating: "a", count: 64))",
            expectedNonce: nonce,
            expectedRoute: "kitchen"
        ))
        XCTAssertNil(parseReadinessHandshake(
            "Screenshot readiness|\(nonce)|kitchen|KitchenView|\(String(repeating: "a", count: 64))",
            expectedNonce: nonce,
            expectedRoute: "kitchen"
        ))
    }

    func testScreenshotContrastAdjudicatorVerifiesStableHighContrastTextPixels() {
        let pixels = syntheticContrastPixels(
            width: 40,
            height: 20,
            background: ObservedRGBPixel(red: 251, green: 250, blue: 244),
            foreground: ObservedRGBPixel(red: 40, green: 35, blue: 29)
        )

        let evidence = ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: 40,
            height: 20
        )

        XCTAssertNotNil(evidence)
        XCTAssertEqual(evidence?.method, "screenshotPixelContrastV2")
        XCTAssertGreaterThanOrEqual(evidence?.contrastRatio ?? 0, 4.5)
        XCTAssertGreaterThanOrEqual(evidence?.backgroundCoverage ?? 0, 0.65)
        XCTAssertGreaterThan(evidence?.foregroundPixelCount ?? 0, 0)
        XCTAssertEqual(evidence?.ignoredEdgeRulePixelCount, 0)
        XCTAssertEqual(evidence?.ignoredEdgeRuleRowCount, 0)
    }

    func testStaleOffscreenContrastRequiresPriorPixelsAndExactScrollDisplacement() {
        let priorFrame = ObservedRect(x: 0, y: 0, width: 40, height: 20)
        let currentFrame = ObservedRect(x: 0, y: -100, width: 40, height: 20)
        let issue = ObservedAuditIssue(
            category: "contrast",
            type: "XCUIAccessibilityAuditType(rawValue: 1)",
            compactDescription: "Contrast failed",
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            diagnosticDescription: "diagnostic",
            diagnosticMirror: "",
            elementIdentifier: "",
            elementLabel: "My Kitchen",
            elementType: "staticText",
            elementFrame: priorFrame
        )
        let priorBuffer = ScreenshotPixelBuffer(
            width: 40,
            height: 20,
            pixels: syntheticContrastPixels(
                width: 40,
                height: 20,
                background: ObservedRGBPixel(red: 251, green: 250, blue: 244),
                foreground: ObservedRGBPixel(red: 40, green: 35, blue: 29)
            ),
            pointSize: CGSize(width: 40, height: 20),
            screenshotSHA256: String(repeating: "a", count: 64)
        )

        let verified = verifiedStaleOffscreenContrastFalsePositive(
            issue: issue,
            priorElementFrame: priorFrame,
            currentElementFrame: currentFrame,
            windowFrame: ObservedRect(x: 0, y: 0, width: 100, height: 100),
            priorScreenshotBuffer: priorBuffer,
            priorScreenshotSHA256: String(repeating: "a", count: 64),
            currentScreenshotSHA256: String(repeating: "b", count: 64),
            capturePhase: "deepScroll"
        )

        XCTAssertEqual(verified?.schema, "iosStaleOffscreenContrastFalsePositiveV1")
        XCTAssertEqual(verified?.priorPixelEvidence.screenshotSHA256, String(repeating: "a", count: 64))
        XCTAssertNil(verifiedStaleOffscreenContrastFalsePositive(
            issue: issue,
            priorElementFrame: priorFrame,
            currentElementFrame: priorFrame,
            windowFrame: ObservedRect(x: 0, y: 0, width: 100, height: 100),
            priorScreenshotBuffer: priorBuffer,
            priorScreenshotSHA256: String(repeating: "a", count: 64),
            currentScreenshotSHA256: String(repeating: "b", count: 64),
            capturePhase: "deepScroll"
        ))
    }

    func testScreenshotContrastAdjudicatorRejectsLowContrastTextPixels() {
        var pixels = syntheticContrastPixels(
            width: 40,
            height: 20,
            background: ObservedRGBPixel(red: 251, green: 250, blue: 244),
            foreground: ObservedRGBPixel(red: 145, green: 141, blue: 136)
        )
        pixels[0] = ObservedRGBPixel(red: 20, green: 20, blue: 20)
        pixels[1] = ObservedRGBPixel(red: 20, green: 20, blue: 20)
        pixels[2] = ObservedRGBPixel(red: 20, green: 20, blue: 20)
        pixels[3] = ObservedRGBPixel(red: 20, green: 20, blue: 20)
        pixels[40] = ObservedRGBPixel(red: 20, green: 20, blue: 20)
        pixels[41] = ObservedRGBPixel(red: 20, green: 20, blue: 20)
        pixels[42] = ObservedRGBPixel(red: 20, green: 20, blue: 20)
        pixels[43] = ObservedRGBPixel(red: 20, green: 20, blue: 20)

        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: 40,
            height: 20
        ))
    }

    func testScreenshotContrastAdjudicatorRejectsFlatAndNoisyCrops() {
        let background = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: Array(repeating: background, count: 800),
            width: 40,
            height: 20
        ))

        var noisyPixels: [ObservedRGBPixel] = []
        noisyPixels.reserveCapacity(800)
        for index in 0..<800 {
            let red = UInt8((index * 37) % 256)
            let green = UInt8((index * 67) % 256)
            let blue = UInt8((index * 97) % 256)
            noisyPixels.append(ObservedRGBPixel(red: red, green: green, blue: blue))
        }
        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: noisyPixels,
            width: 40,
            height: 20
        ))
    }

    func testScreenshotContrastAdjudicatorRejectsMixedHighAndLowContrastRuns() {
        let background = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        var pixels = Array(repeating: background, count: 800)
        for row in 5..<15 {
            for column in 8..<13 {
                pixels[row * 40 + column] = ObservedRGBPixel(red: 40, green: 35, blue: 29)
            }
            for column in 27..<32 {
                pixels[row * 40 + column] = ObservedRGBPixel(red: 145, green: 141, blue: 136)
            }
        }

        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: 40,
            height: 20
        ))
    }

    func testScreenshotContrastAdjudicatorRejectsMeaningfulMinorityLowContrastCluster() {
        let background = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        let highContrast = ObservedRGBPixel(red: 40, green: 35, blue: 29)
        let lowContrast = ObservedRGBPixel(red: 145, green: 141, blue: 136)
        var pixels = Array(repeating: background, count: 1_000)
        for row in 4..<12 {
            for column in 3..<23 {
                pixels[row * 50 + column] = highContrast
            }
            for column in 30..<45 {
                pixels[row * 50 + column] = lowContrast
            }
        }

        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: 50,
            height: 20
        ))
    }

    func testScreenshotContrastAdjudicatorRejectsSmallLowContrastSpanBelowTwentyPercentOfForeground() {
        let width = 40
        let height = 20
        let background = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        let highContrast = ObservedRGBPixel(red: 40, green: 35, blue: 29)
        let lowContrast = ObservedRGBPixel(red: 145, green: 141, blue: 136)
        var pixels = Array(repeating: background, count: width * height)
        for row in 5..<13 {
            for column in 5..<15 {
                pixels[row * width + column] = highContrast
            }
            pixels[row * width + 30] = lowContrast
        }

        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: width,
            height: height
        ))
    }

    func testScreenshotContrastAdjudicatorRejectsConnectedLowContrastSpanOutsideAntialiasFringe() {
        let width = 40
        let height = 20
        let background = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        let highContrast = ObservedRGBPixel(red: 40, green: 35, blue: 29)
        let lowContrast = ObservedRGBPixel(red: 145, green: 141, blue: 136)
        var pixels = Array(repeating: background, count: width * height)
        for row in 5..<13 {
            for column in 5..<15 {
                pixels[row * width + column] = highContrast
            }
            pixels[row * width + 17] = lowContrast
        }
        pixels[5 * width + 15] = lowContrast
        pixels[5 * width + 16] = lowContrast

        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: width,
            height: height
        ))
    }

    func testScreenshotContrastAdjudicatorIgnoresOnlyWideEdgeAlignedDividerPixels() {
        let width = 100
        let height = 40
        let background = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        let highContrast = ObservedRGBPixel(red: 40, green: 35, blue: 29)
        let lowContrastDivider = ObservedRGBPixel(red: 233, green: 231, blue: 225)
        var pixels = syntheticContrastPixels(
            width: width,
            height: height,
            background: background,
            foreground: highContrast
        )
        for row in (height - 2)..<height {
            for column in 5..<(width - 5) {
                pixels[row * width + column] = lowContrastDivider
            }
        }

        let dividerEvidence = ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: width,
            height: height
        )
        XCTAssertEqual(dividerEvidence?.method, "screenshotPixelContrastV2")
        XCTAssertGreaterThan(dividerEvidence?.ignoredEdgeRulePixelCount ?? 0, 0)
        XCTAssertGreaterThan(dividerEvidence?.ignoredEdgeRuleRowCount ?? 0, 0)

        var interiorRule = syntheticContrastPixels(
            width: width,
            height: height,
            background: background,
            foreground: highContrast
        )
        for row in 2..<7 {
            for column in 35..<65 {
                interiorRule[row * width + column] = lowContrastDivider
            }
        }
        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: interiorRule,
            width: width,
            height: height
        ))
    }

    func testScreenshotContrastBufferDecodesAntialiasedSystemTextFromPNG() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 32), format: format)
        let image = renderer.image { context in
            UIColor(red: 251 / 255, green: 250 / 255, blue: 244 / 255, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 96, height: 32))
            ("Inbox" as NSString).draw(
                at: CGPoint(x: 4, y: 6),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: UIColor(red: 40 / 255, green: 35 / 255, blue: 29 / 255, alpha: 1)
                ]
            )
        }
        let pngData = try XCTUnwrap(image.pngData())
        let buffer = try XCTUnwrap(ScreenshotPixelBuffer(
            pngData: pngData,
            pointSize: CGSize(width: 96, height: 32)
        ))
        let crop = try XCTUnwrap(buffer.crop(in: ObservedRect(x: 4, y: 6, width: 48, height: 21)))

        XCTAssertNotNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: crop.pixels,
            width: crop.width,
            height: crop.height,
            screenshotSHA256: SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        ))
    }

    func testScreenshotPixelBufferUsesTopLeftScreenshotCoordinates() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12), format: format)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 6))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 6, width: 12, height: 6))
        }
        let buffer = try XCTUnwrap(ScreenshotPixelBuffer(
            pngData: try XCTUnwrap(image.pngData()),
            pointSize: CGSize(width: 12, height: 12)
        ))
        let top = try XCTUnwrap(buffer.crop(in: ObservedRect(x: 0, y: 0, width: 12, height: 6)))
        let bottom = try XCTUnwrap(buffer.crop(in: ObservedRect(x: 0, y: 6, width: 12, height: 6)))

        XCTAssertTrue(top.pixels.allSatisfy { $0.red > 240 && $0.blue < 15 })
        XCTAssertTrue(bottom.pixels.allSatisfy { $0.blue > 240 && $0.red < 15 })
    }

    func testScreenshotContrastBufferRejectsOutOfBoundsIssueFrame() {
        let buffer = ScreenshotPixelBuffer(
            width: 20,
            height: 20,
            pixels: Array(
                repeating: ObservedRGBPixel(red: 251, green: 250, blue: 244),
                count: 400
            ),
            pointSize: CGSize(width: 10, height: 10)
        )

        XCTAssertNil(buffer.pixels(in: ObservedRect(x: 9, y: 9, width: 2, height: 2)))
    }

    func testReadinessHandshakeRequiresExactNonceRouteSourceAndSHA256() {
        let nonce = "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d"
        let hash = String(repeating: "a", count: 64)
        let generation = 3
        let proofFileName = "screenshot-accessibility-proof.generation-3.json"

        XCTAssertEqual(
            parseReadinessHandshake(
                "Screenshot readiness|\(nonce)|kitchen|KitchenView|42012|\(generation)|\(proofFileName)|\(hash)",
                expectedNonce: nonce,
                expectedRoute: "kitchen"
            ),
            ObservedReadinessHandshake(
                captureRunNonce: nonce,
                route: "kitchen",
                source: "KitchenView",
                applicationProcessIdentifier: 42_012,
                readinessGeneration: generation,
                proofFileName: proofFileName,
                proofSHA256: hash
            )
        )
        XCTAssertNil(parseReadinessHandshake(
            "Screenshot readiness|dd9e30cb-630f-4b4d-99b4-9ed82b80a7f2|kitchen|KitchenView|42012|\(generation)|\(proofFileName)|\(hash)",
            expectedNonce: nonce,
            expectedRoute: "kitchen"
        ))
        XCTAssertNil(parseReadinessHandshake(
            "Screenshot readiness|\(nonce)|recipes|RecipesView|42012|\(generation)|\(proofFileName)|\(hash)",
            expectedNonce: nonce,
            expectedRoute: "kitchen"
        ))
        XCTAssertNil(parseReadinessHandshake(
            "Screenshot readiness|\(nonce)|kitchen|KitchenView|42012|\(generation)|\(proofFileName)|not-a-hash",
            expectedNonce: nonce,
            expectedRoute: "kitchen"
        ))
        XCTAssertNil(parseReadinessHandshake(
            "Screenshot readiness|\(nonce)|kitchen|KitchenView|0|\(generation)|\(proofFileName)|\(hash)",
            expectedNonce: nonce,
            expectedRoute: "kitchen"
        ))
    }

    func testRouteToolbarIdentifiersAreRequiredButNotConstrainedToTheContentViewport() {
        let required = routeRequiredIdentifiers(route: "recipe-editor")
        let visible = required.subtracting(routeRequiredChromeIdentifiers(route: "recipe-editor"))

        XCTAssertTrue(required.contains("recipe-editor.save"))
        XCTAssertFalse(visible.contains("recipe-editor.save"))
        XCTAssertTrue(visible.contains("recipe-editor.title"))
    }

    func testLongScrollActionsAreRequiredButMayStartBelowTheInitialViewport() {
        let required = routeRequiredIdentifiers(route: "recipe-covers")
        let visible = required.subtracting(routeRequiredScrollIdentifiers(route: "recipe-covers"))

        XCTAssertTrue(required.contains("recipe-covers.archive.cover_primary"))
        XCTAssertFalse(visible.contains("recipe-covers.archive.cover_primary"))
        XCTAssertTrue(visible.contains("recipe-covers.photo-picker"))
        XCTAssertTrue(visible.contains("recipe-covers.staged-photo-status"))
        XCTAssertTrue(visible.contains("recipe-covers.clear-photo"))
    }

    func testAccessibilityTextAllowsForegroundActionsToStartBelowTheInitialViewport() {
        let required = routeRequiredIdentifiers(route: "recipe-covers")
        var visible = required.subtracting(routeRequiredScrollIdentifiers(route: "recipe-covers"))
        visible.subtract(routeRequiredAccessibilityScrollIdentifiers(route: "recipe-covers"))

        XCTAssertFalse(visible.contains("recipe-covers.photo-picker"))
        XCTAssertFalse(visible.contains("recipe-covers.save-photo"))
    }

    func testNamedTerminalStopsWhenItIsFullyVisible() {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 500)
        let visible = observedElement(
            identifier: "recipe-covers.archive.cover_primary",
            frame: ObservedRect(x: 20, y: 520, width: 180, height: 44)
        )
        let clipped = observedElement(
            identifier: "recipe-covers.archive.cover_primary",
            frame: ObservedRect(x: 20, y: 580, width: 180, height: 44)
        )

        XCTAssertTrue(namedTerminalIsVisible(
            in: [visible],
            terminalIdentifier: "recipe-covers.archive.cover_primary",
            viewport: viewport
        ))
        XCTAssertFalse(namedTerminalIsVisible(
            in: [clipped],
            terminalIdentifier: "recipe-covers.archive.cover_primary",
            viewport: viewport
        ))
    }

    func testGeometryRejectsPeerOverlap() {
        let first = observedElement(identifier: "first", type: "button", frame: ObservedRect(x: 10, y: 10, width: 50, height: 50))
        let second = observedElement(identifier: "second", type: "button", frame: ObservedRect(x: 40, y: 20, width: 50, height: 50))
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [first, second],
            requirements: requirements(peerPairs: [("first", "second")])
        )
        XCTAssertEqual(findings.map(\.kind), [.peerOverlap])
    }

    func testGeometryRejectsUnspecifiedVisibleTextOverlap() {
        let first = observedElement(identifier: "first", frame: ObservedRect(x: 10, y: 10, width: 60, height: 30))
        let second = observedElement(identifier: "second", frame: ObservedRect(x: 20, y: 20, width: 60, height: 30))
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [first, second],
            requirements: requirements()
        )
        XCTAssertEqual(findings.map(\.kind), [.textOverlap])
    }

    func testGeometryRejectsSameLabelVisibleTextOverlap() {
        let first = observedElement(
            identifier: "first-title",
            label: "Lemon Pantry Pasta",
            frame: ObservedRect(x: 10, y: 10, width: 120, height: 30)
        )
        let second = observedElement(
            identifier: "second-title",
            label: "Lemon Pantry Pasta",
            frame: ObservedRect(x: 20, y: 20, width: 120, height: 30)
        )
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [first, second],
            requirements: requirements()
        )

        XCTAssertEqual(findings.map(\.kind), [.textOverlap])
    }

    func testGeometryRejectsPartiallyVisibleSmallActionTarget() {
        let action = ObservedAccessibilityElement(
            identifier: "partial-action",
            label: "Partial action",
            type: "button",
            frame: ObservedRect(x: 90, y: 20, width: 30, height: 44),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: true,
            focused: nil
        )
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [action],
            requirements: requirements()
        )
        XCTAssertEqual(findings.map(\.kind), [.actionTargetTooSmall])
    }

    func testGeometryAcceptsNativeSystemStepperAccessibilityFrames() {
        let stepper = ObservedAccessibilityElement(
            identifier: "",
            label: "Duration, Duration",
            type: "stepper",
            frame: ObservedRect(x: 2, y: 20, width: 94, height: 32),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: true,
            focused: nil
        )
        let decrement = ObservedAccessibilityElement(
            identifier: "Decrement",
            label: "Duration, Duration, Decrement",
            type: "button",
            frame: ObservedRect(x: 2, y: 20, width: 47, height: 32),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: true,
            focused: nil
        )
        let increment = ObservedAccessibilityElement(
            identifier: "Increment",
            label: "Duration, Duration, Increment",
            type: "button",
            frame: ObservedRect(x: 49, y: 20, width: 47, height: 32),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: true,
            focused: nil
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [stepper, decrement, increment],
            requirements: requirements()
        )

        XCTAssertTrue(findings.isEmpty)
    }

    func testGeometryRejectsStepperNamedButtonsWithoutNativeStepperPair() {
        let decrement = ObservedAccessibilityElement(
            identifier: "Decrement",
            label: "Duration, Decrement",
            type: "button",
            frame: ObservedRect(x: 2, y: 20, width: 47, height: 32),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: true,
            focused: nil
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [decrement],
            requirements: requirements()
        )

        XCTAssertEqual(findings.map(\.kind), [.actionTargetTooSmall])
    }

    func testGeometryAcceptsNativeSwitchChromeForAFullWidthLabeledToggle() {
        let row = ObservedAccessibilityElement(
            identifier: "",
            label: "Editorialize cover",
            type: "switch",
            frame: ObservedRect(x: 32, y: 22, width: 338, height: 28),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: true,
            focused: nil
        )
        let thumb = ObservedAccessibilityElement(
            identifier: "",
            label: "",
            type: "switch",
            frame: ObservedRect(x: 309, y: 22, width: 63, height: 28),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: false,
            focused: nil
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [row, thumb],
            requirements: requirements()
        )

        XCTAssertTrue(findings.isEmpty)
    }

    func testGeometryRejectsNarrowLabeledSwitchChrome() {
        let toggle = ObservedAccessibilityElement(
            identifier: "",
            label: "Editorialize cover",
            type: "switch",
            frame: ObservedRect(x: 33, y: 22, width: 63, height: 28),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: false,
            focused: nil
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [toggle],
            requirements: requirements()
        )

        XCTAssertEqual(findings.map(\.kind), [.actionTargetTooSmall])
    }

    func testGeometryRejectsUnlabeledSmallSwitchWithoutFullSizeToggleRow() {
        let thumb = ObservedAccessibilityElement(
            identifier: "",
            label: "",
            type: "switch",
            frame: ObservedRect(x: 33, y: 22, width: 63, height: 28),
            exists: true,
            hittable: true,
            enabled: true,
            hitRegionAuditVerified: false,
            focused: nil
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [thumb],
            requirements: requirements()
        )

        XCTAssertEqual(findings.map(\.kind), [.actionTargetTooSmall])
    }

    func testGeometryAcceptsFullWidthLabeledNativeTextField() {
        let textField = observedElement(
            identifier: "",
            label: "Placeholder direction",
            type: "textField",
            frame: ObservedRect(x: 32, y: 20, width: 338, height: 34),
            hittable: true,
            hitRegionAuditVerified: true
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [textField],
            requirements: requirements()
        )

        XCTAssertTrue(findings.isEmpty)
    }

    func testGeometryRejectsUnlabeledOrNarrowNativeTextField() {
        let unlabeled = observedElement(
            identifier: "",
            label: "",
            type: "textField",
            frame: ObservedRect(x: 32, y: 20, width: 338, height: 34),
            hittable: true
        )
        let narrow = observedElement(
            identifier: "",
            label: "Placeholder direction",
            type: "textField",
            frame: ObservedRect(x: 32, y: 70, width: 60, height: 34),
            hittable: true
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [unlabeled, narrow],
            requirements: requirements()
        )

        XCTAssertEqual(findings.map(\.kind), [.actionTargetTooSmall, .actionTargetTooSmall])
    }

    func testGeometryAcceptsOnlyTheNamedFullWidthNativeDisclosure() {
        let disclosure = observedElement(
            identifier: "recipe-covers.spoon-details",
            label: "Spoon details",
            type: "button",
            frame: ObservedRect(x: 32, y: 20, width: 338, height: 22),
            hittable: true,
            hitRegionAuditVerified: true
        )
        let lookalike = observedElement(
            identifier: "",
            label: "Spoon details",
            type: "button",
            frame: ObservedRect(x: 32, y: 70, width: 338, height: 22),
            hittable: true
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [disclosure, lookalike],
            requirements: requirements()
        )

        XCTAssertEqual(findings.map(\.kind), [.actionTargetTooSmall])
    }

    func testGeometryRejectsVisuallySmallNativeControlsWithoutHitRegionProof() {
        let toggle = observedElement(
            identifier: "",
            label: "Editorialize cover",
            type: "switch",
            frame: ObservedRect(x: 32, y: 20, width: 338, height: 28),
            hittable: true
        )
        let textField = observedElement(
            identifier: "",
            label: "Placeholder direction",
            type: "textField",
            frame: ObservedRect(x: 32, y: 60, width: 338, height: 34),
            hittable: true
        )
        let disclosure = observedElement(
            identifier: "recipe-covers.spoon-details",
            label: "Spoon details",
            type: "button",
            frame: ObservedRect(x: 32, y: 70, width: 338, height: 22),
            hittable: true
        )

        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [toggle, textField, disclosure],
            requirements: requirements()
        )

        XCTAssertEqual(findings.map(\.kind), [
            .actionTargetTooSmall,
            .actionTargetTooSmall,
            .actionTargetTooSmall
        ])
    }

    func testGeometryRejectsAPNsChromeIntersection() {
        let heading = observedElement(
            identifier: Self.thisDeviceIdentifier,
            type: "staticText",
            frame: ObservedRect(x: 10, y: 10, width: 80, height: 30)
        )
        let toolbar = observedElement(
            identifier: "navigation",
            type: "navigationBar",
            frame: ObservedRect(x: 0, y: 0, width: 100, height: 24)
        )
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [heading, toolbar],
            requirements: requirements(
                required: [Self.thisDeviceIdentifier],
                visible: [Self.thisDeviceIdentifier],
                apnsThisDeviceIdentifier: Self.thisDeviceIdentifier
            )
        )
        XCTAssertEqual(findings.map(\.kind), [.apnsChromeIntersection])
    }

    func testGeometryRejectsTerminalElementBehindTabBar() {
        let terminal = observedElement(
            identifier: "terminal",
            frame: ObservedRect(x: 10, y: 70, width: 70, height: 25)
        )
        let findings = ScreenshotEvidenceGeometry.validateTerminalElement(
            terminal,
            contentViewport: ObservedRect(x: 0, y: 0, width: 100, height: 80),
            tabBarFrame: ObservedRect(x: 0, y: 80, width: 100, height: 20)
        )
        XCTAssertEqual(Set(findings.map(\.kind)), [.outsideViewport, .terminalElementOccludedByTabBar])
    }

    private func waitForReadinessHandshake(
        in app: XCUIApplication,
        route: String,
        captureRunNonce: String?
    ) throws -> ObservedReadinessHandshake {
        let captureRunNonce = try XCTUnwrap(
            captureRunNonce?.trimmingCharacters(in: .whitespacesAndNewlines),
            "Screenshot observer requires a capture run nonce"
        )
        XCTAssertNotNil(UUID(uuidString: captureRunNonce), "Screenshot capture run nonce must be a UUID")
        let identifier = "screenshot.readiness.\(captureRunNonce)"
        let marker = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(
            marker.waitForExistence(timeout: 15),
            "Spoonjoy did not publish settled readiness for capture run \(captureRunNonce)"
        )
        let deadline = Date().addingTimeInterval(15)
        var candidate: ObservedReadinessHandshake?
        var stableSince: Date?
        while Date() < deadline {
            let current = currentReadinessHandshake(
                in: app,
                route: route,
                captureRunNonce: captureRunNonce
            )
            if current != candidate {
                candidate = current
                stableSince = current == nil ? nil : Date()
            } else if let current,
                      let stableSince,
                      Date().timeIntervalSince(stableSince) >= 0.35 {
                return current
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw NSError(
            domain: "app.spoonjoy.screenshot-readiness",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Screenshot readiness marker never held a stable lease."]
        )
    }

    private func captureAttestedScreenshot(
        in app: XCUIApplication,
        route: String,
        captureRunNonce: String?,
        capturePhase: String,
        selectedScrollHierarchy: XCUIElement? = nil
    ) throws -> AttestedScreenshot {
        let nonce = try XCTUnwrap(
            captureRunNonce?.trimmingCharacters(in: .whitespacesAndNewlines),
            "Screenshot observer requires a capture run nonce"
        )
        guard isAuditedCapturePhase(capturePhase) else {
            throw NSError(
                domain: "app.spoonjoy.screenshot-capture",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Screenshot observer requires an exact capture phase."]
            )
        }
        for _ in 0..<4 {
            let before = try waitForReadinessHandshake(
                in: app,
                route: route,
                captureRunNonce: nonce
            )
            let applicationProcessIdentifier = before.applicationProcessIdentifier
            let foregroundBeforeCapture = app.state == .runningForeground
            let beforeWindow = app.windows.firstMatch
            guard applicationProcessIdentifier > 0,
                  foregroundBeforeCapture,
                  beforeWindow.exists else {
                throw NSError(
                    domain: "app.spoonjoy.screenshot-capture",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Spoonjoy was not the foreground application before capture."]
                )
            }
            let beforeWindowFrame = beforeWindow.frame
            let beforeElements = observedElements(in: app, windowFrame: beforeWindowFrame)
            let beforeSnapshotSHA256 = try observationDigest(beforeElements)
            let selectedHierarchyIdentifier = selectedScrollHierarchy?.identifier
            let selectedBeforeElements = selectedScrollHierarchy.map {
                observedElements(in: $0, windowFrame: beforeWindowFrame)
            } ?? []
            let selectedBeforeSnapshotSHA256 = try selectedScrollHierarchy.map { _ in
                try observationDigest(selectedBeforeElements)
            }
            let captureID = UUID().uuidString.lowercased()
            let screenshot = XCUIScreen.main.screenshot()
            let screenshotSHA256 = Self.sha256(screenshot.pngRepresentation)
            let foregroundAfterCapture = app.state == .runningForeground
            let afterWindow = app.windows.firstMatch
            guard foregroundAfterCapture, afterWindow.exists else {
                throw NSError(
                    domain: "app.spoonjoy.screenshot-capture",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Spoonjoy foreground process changed during capture."]
                )
            }
            let afterWindowFrame = afterWindow.frame
            let afterElements = observedElements(in: app, windowFrame: afterWindowFrame)
            let afterSnapshotSHA256 = try observationDigest(afterElements)
            let selectedAfterElements = selectedScrollHierarchy.map {
                observedElements(in: $0, windowFrame: afterWindowFrame)
            } ?? []
            let selectedAfterSnapshotSHA256 = try selectedScrollHierarchy.map { _ in
                try observationDigest(selectedAfterElements)
            }
            guard readinessHandshakeRemainsStable(
                in: app,
                route: route,
                captureRunNonce: nonce,
                expected: before
            ) else {
                continue
            }
            guard beforeWindowFrame.equalTo(afterWindowFrame),
                  beforeSnapshotSHA256 == afterSnapshotSHA256,
                  selectedBeforeSnapshotSHA256 == selectedAfterSnapshotSHA256 else {
                continue
            }
            let identity = ObservedCaptureIdentity(
                schema: "iosObservedCaptureV1",
                captureID: captureID,
                captureRunNonce: nonce,
                capturePhase: capturePhase,
                applicationBundleIdentifier: "app.spoonjoy",
                applicationProcessIdentifier: applicationProcessIdentifier,
                foregroundBeforeCapture: foregroundBeforeCapture,
                foregroundAfterCapture: foregroundAfterCapture,
                screenshotSHA256: screenshotSHA256
            )
            return AttestedScreenshot(
                screenshot: screenshot,
                handshake: before,
                identity: identity,
                pixelAccessibilityBinding: ObservedPixelAccessibilityBinding(
                    schema: "iosPixelAccessibilityBindingV1",
                    captureID: captureID,
                    capturePhase: capturePhase,
                    pixelSource: "mainScreen",
                    screenshotSHA256: screenshotSHA256,
                    accessibilitySnapshotBeforeSHA256: beforeSnapshotSHA256,
                    accessibilitySnapshotAfterSHA256: afterSnapshotSHA256,
                    windowFrame: ObservedRect(afterWindowFrame),
                    selectedScrollHierarchyIdentifier: selectedHierarchyIdentifier,
                    selectedScrollHierarchySnapshotBeforeSHA256: selectedBeforeSnapshotSHA256,
                    selectedScrollHierarchySnapshotAfterSHA256: selectedAfterSnapshotSHA256
                ),
                windowFrame: ObservedRect(afterWindowFrame),
                elements: afterElements,
                selectedScrollHierarchyElements: selectedAfterElements
            )
        }
        throw NSError(
            domain: "app.spoonjoy.screenshot-readiness",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Visual readiness changed during every screenshot lease attempt."]
        )
    }

    private func readinessHandshakeRemainsStable(
        in app: XCUIApplication,
        route: String,
        captureRunNonce: String,
        expected: ObservedReadinessHandshake
    ) -> Bool {
        let deadline = Date().addingTimeInterval(0.35)
        while Date() < deadline {
            guard currentReadinessHandshake(
                in: app,
                route: route,
                captureRunNonce: captureRunNonce
            ) == expected else {
                return false
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return true
    }

    private func isAuditedCapturePhase(_ capturePhase: String) -> Bool {
        capturePhase == "initial"
            || capturePhase == "deepScroll"
            || capturePhase.range(
                of: #"\AdeepScrollWaypoint-[1-9][0-9]*\z"#,
                options: .regularExpression
            ) != nil
    }

    private func attestedFrameForAuditElement(
        identifier: String,
        label: String,
        type: String,
        elements: [ObservedAccessibilityElement]
    ) -> ObservedRect? {
        auditElementAttestation(
            identifier: identifier,
            label: label,
            type: type,
            elements: elements
        ).frame
    }

    private func auditElementAttestation(
        identifier: String,
        label: String,
        type: String,
        elements: [ObservedAccessibilityElement]
    ) -> (matchingCount: Int, frame: ObservedRect?) {
        let matches = elements.filter { element in
            guard element.exists, element.type == type else {
                return false
            }
            if !identifier.isEmpty {
                return element.identifier == identifier
                    && (label.isEmpty || element.label == label)
            }
            return !label.isEmpty && element.label == label
        }
        return (matches.count, matches.count == 1 ? matches[0].frame : nil)
    }

    private func verifiedStaleOffscreenContrastFalsePositive(
        issue: ObservedAuditIssue,
        priorElementFrame: ObservedRect,
        currentElementFrame: ObservedRect,
        windowFrame: ObservedRect,
        priorScreenshotBuffer: ScreenshotPixelBuffer?,
        priorScreenshotSHA256: String,
        currentScreenshotSHA256: String,
        capturePhase: String
    ) -> ObservedVerifiedStaleOffscreenContrastFalsePositive? {
        let dimensionTolerance = 0.75
        guard capturePhase == "deepScroll" || capturePhase.hasPrefix("deepScrollWaypoint-"),
              issue.category == "contrast",
              issue.elementType == "staticText",
              let issueFrame = issue.elementFrame,
              windowFrame.contains(issueFrame),
              windowFrame.contains(priorElementFrame),
              windowFrame.intersection(with: currentElementFrame) == nil,
              abs(priorElementFrame.x - currentElementFrame.x) <= dimensionTolerance,
              abs(priorElementFrame.width - currentElementFrame.width) <= dimensionTolerance,
              abs(priorElementFrame.height - currentElementFrame.height) <= dimensionTolerance,
              abs(priorElementFrame.y - currentElementFrame.y) >= Self.minimumTerminalDragDistance,
              priorScreenshotBuffer?.screenshotSHA256 == priorScreenshotSHA256,
              let crop = priorScreenshotBuffer?.crop(in: priorElementFrame),
              let pixelEvidence = ScreenshotPixelContrastAdjudicator.analyze(
                  pixels: crop.pixels,
                  width: crop.width,
                  height: crop.height,
                  screenshotSHA256: priorScreenshotSHA256
              ) else {
            return nil
        }
        return ObservedVerifiedStaleOffscreenContrastFalsePositive(
            schema: "iosStaleOffscreenContrastFalsePositiveV1",
            capturePhase: capturePhase,
            reason: "priorHighContrastPixelsBoundToNowOffscreenAttestedElement",
            issue: issue,
            priorElementFrame: priorElementFrame,
            currentElementFrame: currentElementFrame,
            priorScreenshotSHA256: priorScreenshotSHA256,
            currentScreenshotSHA256: currentScreenshotSHA256,
            priorPixelEvidence: pixelEvidence
        )
    }

    private func verifiedNativeSidebarTextClippedFalsePositive(
        idiom: UIUserInterfaceIdiom,
        auditType: XCUIAccessibilityAuditType,
        detailedDescription: String,
        identifier: String,
        label: String,
        type: String,
        elements: [ObservedAccessibilityElement],
        capturePhase: String
    ) -> ObservedVerifiedTextClippedFalsePositive? {
        let exactWarning = "Text of this SwiftUI.AccessibilityNode may be clipped at larger Dynamic Type sizes."
        let sidebarLabels: Set<String> = [
            "Kitchen",
            "My Recipes",
            "Saved Recipes",
            "Cookbooks",
            "Shopping List",
            "Chefs",
            "Kitchen Search",
            "Imports",
            "Settings"
        ]
        guard idiom == .pad,
              auditType == .textClipped,
              detailedDescription == exactWarning,
              type == "staticText",
              sidebarLabels.contains(label),
              isAuditedCapturePhase(capturePhase),
              let elementFrame = attestedFrameForAuditElement(
                  identifier: identifier,
                  label: label,
                  type: type,
                  elements: elements
              ) else {
            return nil
        }
        let matchingContainers = elements.filter { element in
            element.exists
                && element.type == "collectionView"
                && element.label == "Sidebar"
                && element.frame.contains(elementFrame)
        }
        guard matchingContainers.count == 1, let container = matchingContainers.first else {
            return nil
        }
        return ObservedVerifiedTextClippedFalsePositive(
            schema: "iosNativeSidebarTextClippedFalsePositiveV1",
            capturePhase: capturePhase,
            reason: "nativeSidebarRowExpandedWithinAttestedContainer",
            detailedDescription: detailedDescription,
            elementIdentifier: identifier,
            elementLabel: label,
            elementType: type,
            elementFrame: elementFrame,
            containerType: container.type,
            containerLabel: container.label,
            containerFrame: container.frame
        )
    }

    private func currentReadinessHandshake(
        in app: XCUIApplication,
        route: String,
        captureRunNonce: String
    ) -> ObservedReadinessHandshake? {
        let identifier = "screenshot.readiness.\(captureRunNonce)"
        let marker = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        guard marker.exists else { return nil }
        return parseReadinessHandshake(
            marker.label,
            expectedNonce: captureRunNonce,
            expectedRoute: route
        )
    }

    private func parseReadinessHandshake(
        _ label: String,
        expectedNonce: String,
        expectedRoute: String
    ) -> ObservedReadinessHandshake? {
        let fields = label.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 8,
              fields[0] == "Screenshot readiness",
              fields[1] == expectedNonce,
              UUID(uuidString: fields[1]) != nil,
              fields[2] == expectedRoute,
              !fields[3].isEmpty,
              let applicationProcessIdentifier = Int(fields[4]),
              applicationProcessIdentifier > 0,
              let readinessGeneration = Int(fields[5]),
              readinessGeneration >= 0,
              fields[6].range(
                of: #"\A[A-Za-z0-9._-]+\.generation-[0-9]+\.json\z"#,
                options: .regularExpression
              ) != nil,
              fields[6].contains(".generation-\(readinessGeneration)."),
              fields[7].range(of: #"\A[0-9a-f]{64}\z"#, options: .regularExpression) != nil else {
            return nil
        }
        return ObservedReadinessHandshake(
            captureRunNonce: fields[1],
            route: fields[2],
            source: fields[3],
            applicationProcessIdentifier: applicationProcessIdentifier,
            readinessGeneration: readinessGeneration,
            proofFileName: fields[6],
            proofSHA256: fields[7]
        )
    }

    private func accessibilityAuditIssues(
        in app: XCUIApplication,
        viewport: ObservedRect,
        screenshot: XCUIScreenshot,
        windowFrame: CGRect,
        attestedElements: [ObservedAccessibilityElement],
        contentSizeCategory: String,
        capturePhase: String,
        scope: ObservedAccessibilityAuditScope,
        priorScreenshot: XCUIScreenshot? = nil,
        priorAttestedElements: [ObservedAccessibilityElement] = [],
        includesDynamicTypeChecks: Bool = true
    ) -> ObservedAuditResult {
        var blockingIssues: [ObservedAuditIssue] = []
        var verifiedContrastFalsePositives: [ObservedVerifiedContrastFalsePositive] = []
        var verifiedStaleOffscreenContrastFalsePositives: [ObservedVerifiedStaleOffscreenContrastFalsePositive] = []
        var contrastPixelAdjudicationDiagnostics: [ObservedContrastPixelAdjudicationDiagnostic] = []
        var verifiedSystemChromeContrastFalsePositives: [ObservedVerifiedSystemChromeContrastFalsePositive] = []
        var verifiedNativeSidebarSelectionContrastFalsePositives: [ObservedVerifiedNativeSidebarSelectionContrastFalsePositive] = []
        var verifiedTextClippedFalsePositives: [ObservedVerifiedTextClippedFalsePositive] = []
        var hitRegionAuditPassed = true
        let screenshotPNG = screenshot.pngRepresentation
        let screenshotSHA256 = SHA256.hash(data: screenshotPNG)
            .map { String(format: "%02x", $0) }
            .joined()
        let screenshotBuffer = ScreenshotPixelBuffer(
            pngData: screenshotPNG,
            pointSize: windowFrame.size
        )
        let priorScreenshotPNG = priorScreenshot?.pngRepresentation
        let priorScreenshotSHA256 = priorScreenshotPNG.map {
            SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
        }
        let priorScreenshotBuffer = priorScreenshotPNG.flatMap {
            ScreenshotPixelBuffer(pngData: $0, pointSize: windowFrame.size)
        }
        let auditTypes = accessibilityAuditTypes(
            scope: scope,
            includesDynamicTypeChecks: includesDynamicTypeChecks
        )
        do {
            try app.performAccessibilityAudit(for: auditTypes) { issue in
                let element = issue.element
                let elementFrame = element.map { ObservedRect($0.frame) }
                let elementType = element.map { self.elementTypeName($0.elementType) } ?? ""
                if issue.auditType == .hitRegion {
                    hitRegionAuditPassed = false
                }
                if let elementFrame,
                   self.shouldIgnoreAuditIssue(
                       elementFrame: elementFrame,
                       elementType: elementType,
                       viewport: viewport
                ) {
                    return true
                }
                let observedIssue = ObservedAuditIssue(
                    category: self.auditCategory(issue.auditType),
                    type: String(describing: issue.auditType),
                    compactDescription: issue.compactDescription,
                    detailedDescription: issue.detailedDescription,
                    diagnosticDescription: String(reflecting: issue),
                    diagnosticMirror: self.auditIssueMirror(issue),
                    elementIdentifier: element?.identifier ?? "",
                    elementLabel: element?.label ?? "",
                    elementType: elementType,
                    elementFrame: elementFrame
                )
                if let verified = self.verifiedNativeSidebarSelectionContrastFalsePositive(
                    idiom: UIDevice.current.userInterfaceIdiom,
                    contentSizeCategory: contentSizeCategory,
                    issue: observedIssue,
                    elements: attestedElements,
                    screenshotBuffer: screenshotBuffer,
                    screenshotSHA256: screenshotSHA256,
                    windowFrame: ObservedRect(windowFrame),
                    capturePhase: capturePhase
                ) {
                    verifiedNativeSidebarSelectionContrastFalsePositives.append(verified)
                    return true
                }
                if let verified = self.verifiedNativeBottomTabChromeContrastFalsePositive(
                    idiom: UIDevice.current.userInterfaceIdiom,
                    contentSizeCategory: contentSizeCategory,
                    issue: observedIssue,
                    elements: attestedElements,
                    screenshotBuffer: screenshotBuffer,
                    screenshotSHA256: screenshotSHA256,
                    windowFrame: ObservedRect(windowFrame),
                    capturePhase: capturePhase
                ) ?? self.verifiedNativeCompactTabChromeContrastFalsePositive(
                    idiom: UIDevice.current.userInterfaceIdiom,
                    contentSizeCategory: contentSizeCategory,
                    issue: observedIssue,
                    elements: attestedElements,
                    screenshotBuffer: screenshotBuffer,
                    screenshotSHA256: screenshotSHA256,
                    windowFrame: ObservedRect(windowFrame),
                    capturePhase: capturePhase
                ) {
                    verifiedSystemChromeContrastFalsePositives.append(verified)
                    return true
                }
                let attestation = self.auditElementAttestation(
                    identifier: element?.identifier ?? "",
                    label: element?.label ?? "",
                    type: elementType,
                    elements: attestedElements
                )
                let attestedFrame = attestation.frame
                if let verified = self.verifiedNativeSidebarTextClippedFalsePositive(
                    idiom: UIDevice.current.userInterfaceIdiom,
                    auditType: issue.auditType,
                    detailedDescription: issue.detailedDescription,
                    identifier: element?.identifier ?? "",
                    label: element?.label ?? "",
                    type: elementType,
                    elements: attestedElements,
                    capturePhase: capturePhase
                ) {
                    verifiedTextClippedFalsePositives.append(verified)
                    return true
                }
                let pixelCandidates = self.pixelAdjudicationFrames(
                    elementFrame: elementFrame,
                    attestedFrame: attestedFrame
                )
                var pixelAttempts: [ObservedContrastPixelAdjudicationAttempt] = []
                var pixelAdjudication: (ObservedRect, ObservedContrastPixelEvidence)?
                if issue.auditType == .contrast && elementType == "staticText" {
                    for (index, frame) in pixelCandidates.enumerated() {
                        let source = attestedFrame == nil || index > 0 ? "audit" : "attested"
                        guard let crop = screenshotBuffer?.crop(in: frame) else {
                            pixelAttempts.append(ObservedContrastPixelAdjudicationAttempt(
                                source: source,
                                frame: frame,
                                outcome: screenshotBuffer == nil ? "screenshotBufferUnavailable" : "cropUnavailable",
                                cropWidth: nil,
                                cropHeight: nil
                            ))
                            continue
                        }
                        guard let evidence = ScreenshotPixelContrastAdjudicator.analyze(
                            pixels: crop.pixels,
                            width: crop.width,
                            height: crop.height,
                            screenshotSHA256: screenshotSHA256
                        ) else {
                            pixelAttempts.append(ObservedContrastPixelAdjudicationAttempt(
                                source: source,
                                frame: frame,
                                outcome: "analyzerRejected",
                                cropWidth: crop.width,
                                cropHeight: crop.height
                            ))
                            continue
                        }
                        pixelAttempts.append(ObservedContrastPixelAdjudicationAttempt(
                            source: source,
                            frame: frame,
                            outcome: "verified",
                            cropWidth: crop.width,
                            cropHeight: crop.height
                        ))
                        pixelAdjudication = (frame, evidence)
                        break
                    }
                }
                if let (pixelFrame, pixelEvidence) = pixelAdjudication {
                    let pixelBoundIssue = ObservedAuditIssue(
                        category: observedIssue.category,
                        type: observedIssue.type,
                        compactDescription: observedIssue.compactDescription,
                        detailedDescription: observedIssue.detailedDescription,
                        diagnosticDescription: observedIssue.diagnosticDescription,
                        diagnosticMirror: observedIssue.diagnosticMirror,
                        elementIdentifier: observedIssue.elementIdentifier,
                        elementLabel: observedIssue.elementLabel,
                        elementType: observedIssue.elementType,
                        elementFrame: pixelFrame
                    )
                    verifiedContrastFalsePositives.append(ObservedVerifiedContrastFalsePositive(
                        capturePhase: capturePhase,
                        issue: pixelBoundIssue,
                        pixelEvidence: pixelEvidence
                    ))
                    return true
                }
                let priorAttestation = self.auditElementAttestation(
                    identifier: observedIssue.elementIdentifier,
                    label: observedIssue.elementLabel,
                    type: observedIssue.elementType,
                    elements: priorAttestedElements
                )
                if let priorElementFrame = priorAttestation.frame,
                   let currentElementFrame = attestedFrame,
                   let priorScreenshotSHA256,
                   let verified = self.verifiedStaleOffscreenContrastFalsePositive(
                       issue: observedIssue,
                       priorElementFrame: priorElementFrame,
                       currentElementFrame: currentElementFrame,
                       windowFrame: ObservedRect(windowFrame),
                       priorScreenshotBuffer: priorScreenshotBuffer,
                       priorScreenshotSHA256: priorScreenshotSHA256,
                       currentScreenshotSHA256: screenshotSHA256,
                       capturePhase: capturePhase
                   ) {
                    verifiedStaleOffscreenContrastFalsePositives.append(verified)
                    return true
                }
                if issue.auditType == .contrast {
                    contrastPixelAdjudicationDiagnostics.append(ObservedContrastPixelAdjudicationDiagnostic(
                        schema: "iosContrastPixelAdjudicationFailureV1",
                        capturePhase: capturePhase,
                        issue: observedIssue,
                        matchingAttestedElementCount: attestation.matchingCount,
                        attestedFrame: attestedFrame,
                        screenshotBufferAvailable: screenshotBuffer != nil,
                        screenshotSHA256: screenshotSHA256,
                        screenshotPixelWidth: screenshotBuffer?.width,
                        screenshotPixelHeight: screenshotBuffer?.height,
                        attempts: pixelAttempts
                    ))
                }
                blockingIssues.append(observedIssue)
                return true
            }
        } catch {
            hitRegionAuditPassed = false
            blockingIssues.append(ObservedAuditIssue(
                category: "auditExecution",
                type: "auditExecution",
                compactDescription: "Accessibility audit did not complete.",
                detailedDescription: String(describing: error),
                diagnosticDescription: String(reflecting: error),
                diagnosticMirror: "",
                elementIdentifier: "",
                elementLabel: "",
                elementType: "",
                elementFrame: nil
            ))
        }
        return ObservedAuditResult(
            blockingIssues: blockingIssues,
            verifiedContrastFalsePositives: verifiedContrastFalsePositives,
            verifiedStaleOffscreenContrastFalsePositives: verifiedStaleOffscreenContrastFalsePositives,
            contrastPixelAdjudicationDiagnostics: contrastPixelAdjudicationDiagnostics,
            verifiedSystemChromeContrastFalsePositives: verifiedSystemChromeContrastFalsePositives,
            verifiedNativeSidebarSelectionContrastFalsePositives: verifiedNativeSidebarSelectionContrastFalsePositives,
            verifiedTextClippedFalsePositives: verifiedTextClippedFalsePositives,
            hitRegionAuditPassed: hitRegionAuditPassed,
            auditTypes: accessibilityAuditTypeNames(auditTypes)
        )
    }

    private func accessibilityAuditTypes(
        scope: ObservedAccessibilityAuditScope,
        includesDynamicTypeChecks: Bool
    ) -> XCUIAccessibilityAuditType {
        var auditTypes = XCUIAccessibilityAuditType.hitRegion.union(.trait)
        auditTypes.formUnion(.contrast)
        if includesDynamicTypeChecks {
            auditTypes.formUnion(.dynamicType)
            auditTypes.formUnion(.textClipped)
        }
        return auditTypes
    }

    private func accessibilityAuditTypeNames(_ auditTypes: XCUIAccessibilityAuditType) -> [String] {
        [
            (.contrast, "contrast"),
            (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"),
            (.hitRegion, "hitRegion"),
            (.trait, "trait")
        ].compactMap { type, name in
            auditTypes.contains(type) ? name : nil
        }
    }

    private func shouldIgnoreAuditIssue(
        elementFrame: ObservedRect,
        elementType: String,
        viewport: ObservedRect
    ) -> Bool {
        let tolerance = 0.5
        let negligibleVisibleHeight = 1.0
        let isHorizontallyContained = elementFrame.minX >= viewport.minX - tolerance
            && elementFrame.maxX <= viewport.maxX + tolerance
        let visibleMinY = max(elementFrame.minY, viewport.minY)
        let visibleMaxY = min(elementFrame.maxY, viewport.maxY)
        let visibleHeight = max(0, visibleMaxY - visibleMinY)
        let isVerticallyOutside = elementFrame.maxY <= viewport.minY + tolerance
            || elementFrame.minY >= viewport.maxY - tolerance
            || visibleHeight <= negligibleVisibleHeight
        return !Self.chromeTypes.contains(elementType)
            && isHorizontallyContained
            && isVerticallyOutside
    }

    private func verifiedNativeSidebarSelectionContrastFalsePositive(
        idiom: UIUserInterfaceIdiom,
        contentSizeCategory: String,
        issue: ObservedAuditIssue,
        elements: [ObservedAccessibilityElement],
        screenshotBuffer: ScreenshotPixelBuffer?,
        screenshotSHA256: String,
        windowFrame: ObservedRect,
        capturePhase: String
    ) -> ObservedVerifiedNativeSidebarSelectionContrastFalsePositive? {
        guard idiom == .pad,
              contentSizeCategory == "large",
              isAuditedCapturePhase(capturePhase),
              issue.category == "contrast",
              issue.type == "XCUIAccessibilityAuditType(rawValue: 1)",
              issue.compactDescription == "Contrast failed",
              issue.detailedDescription == "Contrast failed for SwiftUI.AccessibilityNode",
              screenshotSHA256.range(of: #"\A[0-9a-f]{64}\z"#, options: .regularExpression) != nil,
              let screenshotBuffer,
              screenshotBuffer.screenshotSHA256 == screenshotSHA256 else {
            return nil
        }

        let liveElements = uniqueAttestedElements(elements.filter { $0.exists && $0.enabled })
        guard !liveElements.contains(where: { $0.type == "tabBar" }) else { return nil }
        let navigationBars = liveElements.filter { $0.type == "navigationBar" }
        guard navigationBars.count == 2,
              let sidebarNavigationBar = navigationBars.only(where: {
                  $0.identifier == "Spoonjoy"
                      && $0.label.isEmpty
                      && $0.frame.width >= 280
                      && $0.frame.width <= 360
                      && $0.frame.minX >= windowFrame.minX
                      && $0.frame.minX <= windowFrame.minX + 20
                      && $0.frame.height >= 44
                      && $0.frame.height <= 80
              }),
              let detailNavigationBar = navigationBars.only(where: {
                  $0.identifier == "Kitchen"
                      && $0.label.isEmpty
                      && abs($0.frame.minX - windowFrame.minX) <= 0.75
                      && abs($0.frame.maxX - windowFrame.maxX) <= 0.75
                      && $0.frame.height >= 80
                      && $0.frame.height <= 120
              }),
              let sidebarCollection = liveElements.only(where: {
                  $0.type == "collectionView"
                      && $0.identifier.isEmpty
                      && $0.label == "Sidebar"
                      && abs($0.frame.minX - sidebarNavigationBar.frame.minX) <= 0.75
                      && abs($0.frame.width - sidebarNavigationBar.frame.width) <= 0.75
                      && $0.frame.contains(sidebarNavigationBar.frame)
              }),
              let selectedLabel = liveElements.only(where: {
                  $0.type == "staticText"
                      && $0.identifier.isEmpty
                      && $0.label == "Kitchen"
                      && sidebarCollection.frame.contains($0.frame)
                      && $0.frame.width >= 200
                      && $0.frame.height >= 44
              }),
              let selectedCell = liveElements.only(where: {
                  $0.type == "cell"
                      && $0.identifier.isEmpty
                      && $0.label.isEmpty
                      && sidebarCollection.frame.contains($0.frame)
                      && rectsApproximatelyEqual($0.frame, selectedLabel.frame)
              }),
              let selectedSymbol = liveElements.only(where: {
                  $0.type == "image"
                      && $0.identifier == "house"
                      && $0.label == "Home"
                      && selectedCell.frame.contains($0.frame)
              }) else {
            return nil
        }
        let issueReferences = [selectedLabel, selectedSymbol].map(systemChromeReference)
        guard let issueElement = auditIssueReference(issue, references: issueReferences) else {
            return nil
        }

        let interiorInset = 12.0
        let interiorFrame = ObservedRect(
            x: selectedCell.frame.x + interiorInset,
            y: selectedCell.frame.y + interiorInset,
            width: selectedCell.frame.width - interiorInset * 2,
            height: selectedCell.frame.height - interiorInset * 2
        )
        let selectedLabelTextFrame = ObservedRect(
            x: max(selectedSymbol.frame.maxX + 8, selectedCell.frame.minX + 8),
            y: selectedCell.frame.minY + 8,
            width: selectedCell.frame.maxX - max(selectedSymbol.frame.maxX + 8, selectedCell.frame.minX + 8) - 8,
            height: selectedCell.frame.height - 16
        )
        guard !interiorFrame.isEmpty,
              !selectedLabelTextFrame.isEmpty,
              let selectedCellCrop = screenshotBuffer.crop(in: interiorFrame),
              let selectedCellPixelEvidence = ScreenshotPixelContrastAdjudicator.analyze(
                  pixels: selectedCellCrop.pixels,
                  width: selectedCellCrop.width,
                  height: selectedCellCrop.height,
                  screenshotSHA256: screenshotSHA256
              ),
              let selectedLabelTextCrop = screenshotBuffer.crop(in: selectedLabelTextFrame),
              let selectedLabelTextPixelEvidence = ScreenshotPixelContrastAdjudicator.analyze(
                  pixels: selectedLabelTextCrop.pixels,
                  width: selectedLabelTextCrop.width,
                  height: selectedLabelTextCrop.height,
                  screenshotSHA256: screenshotSHA256
              ),
              let selectedSymbolCrop = screenshotBuffer.crop(in: selectedSymbol.frame),
              let selectedSymbolPixelEvidence = ScreenshotPixelContrastAdjudicator.analyze(
                  pixels: selectedSymbolCrop.pixels,
                  width: selectedSymbolCrop.width,
                  height: selectedSymbolCrop.height,
                  screenshotSHA256: screenshotSHA256
              ) else {
            return nil
        }
        let issuePixelEvidence = rectsApproximatelyEqual(issueElement.frame, selectedSymbol.frame)
            ? selectedSymbolPixelEvidence
            : selectedLabelTextPixelEvidence

        let visibleTextElements = liveElements.filter {
            $0.type == "staticText"
                && !$0.label.isEmpty
                && windowFrame.contains($0.frame)
        }
        guard visibleTextElements.count >= 20 else { return nil }
        var visibleTextPixelEvidence: [ObservedVisibleTextContrastEvidence] = []
        for element in visibleTextElements.sorted(by: visualElementOrder) {
            let pixelFrame = rectsApproximatelyEqual(element.frame, selectedLabel.frame)
                ? selectedLabelTextFrame
                : element.frame
            guard let crop = screenshotBuffer.crop(in: pixelFrame),
                  let pixelEvidence = ScreenshotPixelContrastAdjudicator.analyze(
                      pixels: crop.pixels,
                      width: crop.width,
                      height: crop.height,
                      screenshotSHA256: screenshotSHA256
                  ) else {
                return nil
            }
            visibleTextPixelEvidence.append(ObservedVisibleTextContrastEvidence(
                element: systemChromeReference(element),
                pixelFrame: pixelFrame,
                pixelEvidence: pixelEvidence
            ))
        }

        return ObservedVerifiedNativeSidebarSelectionContrastFalsePositive(
            schema: "iosNativeSidebarSelectionContrastFalsePositiveV3",
            capturePhase: capturePhase,
            reason: "elementContrastBoundToAttestedNativeSidebarSelection",
            contentSizeCategory: contentSizeCategory,
            issue: issue,
            screenshotSHA256: screenshotSHA256,
            issueElement: issueElement,
            issuePixelEvidence: issuePixelEvidence,
            sidebarNavigationBar: systemChromeReference(sidebarNavigationBar),
            detailNavigationBar: systemChromeReference(detailNavigationBar),
            sidebarCollection: systemChromeReference(sidebarCollection),
            selectedCell: systemChromeReference(selectedCell),
            selectedLabel: systemChromeReference(selectedLabel),
            selectedSymbol: systemChromeReference(selectedSymbol),
            selectedCellInteriorFrame: interiorFrame,
            selectedLabelTextFrame: selectedLabelTextFrame,
            selectedCellPixelEvidence: selectedCellPixelEvidence,
            selectedLabelTextPixelEvidence: selectedLabelTextPixelEvidence,
            selectedSymbolPixelEvidence: selectedSymbolPixelEvidence,
            visibleTextPixelEvidence: visibleTextPixelEvidence
        )
    }

    private func rectsApproximatelyEqual(
        _ first: ObservedRect,
        _ second: ObservedRect,
        tolerance: Double = 0.75
    ) -> Bool {
        abs(first.x - second.x) <= tolerance
            && abs(first.y - second.y) <= tolerance
            && abs(first.width - second.width) <= tolerance
            && abs(first.height - second.height) <= tolerance
    }

    private func visualElementOrder(
        _ first: ObservedAccessibilityElement,
        _ second: ObservedAccessibilityElement
    ) -> Bool {
        if abs(first.frame.minY - second.frame.minY) > 0.5 {
            return first.frame.minY < second.frame.minY
        }
        return first.frame.minX < second.frame.minX
    }

    private func verifiedNativeCompactTabChromeContrastFalsePositive(
        idiom: UIUserInterfaceIdiom,
        contentSizeCategory: String,
        issue: ObservedAuditIssue,
        elements: [ObservedAccessibilityElement],
        screenshotBuffer: ScreenshotPixelBuffer? = nil,
        screenshotSHA256: String = "",
        windowFrame: ObservedRect,
        capturePhase: String
    ) -> ObservedVerifiedSystemChromeContrastFalsePositive? {
        let supportedContentSizes = [
            "extra-extra-extra-large",
            "accessibility-extra-extra-extra-large"
        ]
        guard idiom == .pad,
              supportedContentSizes.contains(contentSizeCategory),
              isAuditedCapturePhase(capturePhase),
              issue.category == "contrast",
              issue.type == "XCUIAccessibilityAuditType(rawValue: 1)",
              issue.compactDescription == "Contrast failed",
              issue.detailedDescription == "Contrast failed for SwiftUI.AccessibilityNode",
              !elements.contains(where: { $0.exists && $0.type == "tabBar" }) else {
            return nil
        }

        let uniqueNavigationBars = uniqueAttestedElements(elements.filter {
            $0.exists && $0.enabled && $0.type == "navigationBar"
        })
        guard uniqueNavigationBars.count == 1,
              let navigationBar = uniqueNavigationBars.first,
              !navigationBar.identifier.isEmpty,
              navigationBar.label.isEmpty,
              abs(navigationBar.frame.minX - windowFrame.minX) <= 0.75,
              abs(navigationBar.frame.maxX - windowFrame.maxX) <= 0.75,
              navigationBar.frame.minY >= windowFrame.minY - 0.75,
              navigationBar.frame.maxY <= windowFrame.minY + 120,
              navigationBar.frame.height >= 44,
              navigationBar.frame.height <= 80 else {
            return nil
        }

        let expectedDestinations = [
            (identifier: "house", label: "Kitchen"),
            (identifier: "book.closed", label: "Recipes"),
            (identifier: "bookmark", label: "Saved"),
            (identifier: "books.vertical", label: "Cookbooks")
        ]
        var destinationReferences: [ObservedSystemChromeElementReference] = []
        for destination in expectedDestinations {
            let matches = uniqueAttestedElements(elements.filter {
                $0.exists
                    && $0.enabled
                    && $0.hittable
                    && $0.type == "button"
                    && $0.identifier == destination.identifier
                    && $0.label == destination.label
            })
            guard matches.count == 1,
                  let match = matches.first,
                  navigationBar.frame.contains(match.frame, tolerance: 0.75) else {
                return nil
            }
            destinationReferences.append(systemChromeReference(match))
        }

        guard let issueElement = auditIssueReference(issue, references: destinationReferences),
              let pixelEvidence = systemChromePixelEvidence(
            references: destinationReferences,
            labelPlacement: .trailing,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256
        ) else {
            return nil
        }

        return ObservedVerifiedSystemChromeContrastFalsePositive(
            schema: "iosNativeCompactTabChromeContrastFalsePositiveV2",
            capturePhase: capturePhase,
            reason: "elementContrastBoundToAttestedNativeCompactTabChrome",
            contentSizeCategory: contentSizeCategory,
            issue: issue,
            screenshotSHA256: screenshotSHA256,
            issueElement: issueElement,
            pixelEvidence: pixelEvidence,
            navigationBar: systemChromeReference(navigationBar),
            tabBar: nil,
            destinations: destinationReferences
        )
    }

    private func verifiedNativeBottomTabChromeContrastFalsePositive(
        idiom: UIUserInterfaceIdiom,
        contentSizeCategory: String,
        issue: ObservedAuditIssue,
        elements: [ObservedAccessibilityElement],
        screenshotBuffer: ScreenshotPixelBuffer? = nil,
        screenshotSHA256: String = "",
        windowFrame: ObservedRect,
        capturePhase: String
    ) -> ObservedVerifiedSystemChromeContrastFalsePositive? {
        let supportedContentSizes = [
            "large",
            "extra-extra-extra-large",
            "accessibility-extra-extra-extra-large"
        ]
        guard idiom == .phone,
              supportedContentSizes.contains(contentSizeCategory),
              isAuditedCapturePhase(capturePhase),
              issue.category == "contrast",
              issue.type == "XCUIAccessibilityAuditType(rawValue: 1)",
              issue.compactDescription == "Contrast failed",
              issue.detailedDescription == "Contrast failed for SwiftUI.AccessibilityNode",
              !issue.elementType.isEmpty,
              issue.elementFrame != nil else {
            return nil
        }

        let uniqueNavigationBars = uniqueAttestedElements(elements.filter {
            $0.exists && $0.enabled && $0.type == "navigationBar"
        })
        let uniqueTabBars = uniqueAttestedElements(elements.filter {
            $0.exists && $0.enabled && $0.hittable && $0.type == "tabBar"
        })
        guard uniqueNavigationBars.count == 1,
              let navigationBar = uniqueNavigationBars.first,
              !navigationBar.identifier.isEmpty,
              navigationBar.label.isEmpty,
              abs(navigationBar.frame.minX - windowFrame.minX) <= 0.75,
              abs(navigationBar.frame.maxX - windowFrame.maxX) <= 0.75,
              navigationBar.frame.minY >= windowFrame.minY - 0.75,
              navigationBar.frame.maxY <= windowFrame.minY + 120,
              navigationBar.frame.height >= 44,
              navigationBar.frame.height <= 80,
              uniqueTabBars.count == 1,
              let tabBar = uniqueTabBars.first,
              tabBar.identifier.isEmpty,
              tabBar.label == "Tab Bar",
              abs(tabBar.frame.minX - windowFrame.minX) <= 0.75,
              abs(tabBar.frame.maxX - windowFrame.maxX) <= 0.75,
              abs(tabBar.frame.maxY - windowFrame.maxY) <= 0.75,
              tabBar.frame.height >= 44,
              tabBar.frame.height <= 120 else {
            return nil
        }

        let expectedDestinations = [
            (identifier: "house", label: "Kitchen"),
            (identifier: "book.closed", label: "Recipes"),
            (identifier: "bookmark", label: "Saved"),
            (identifier: "books.vertical", label: "Cookbooks"),
            (identifier: "checklist", label: "Shopping")
        ]
        let liveDestinationButtons = uniqueAttestedElements(elements.filter {
            $0.exists
                && $0.enabled
                && $0.hittable
                && $0.type == "button"
                && tabBar.frame.contains($0.frame, tolerance: 0.75)
        })
        guard liveDestinationButtons.count == expectedDestinations.count else {
            return nil
        }
        let orderedLiveDestinations = liveDestinationButtons.sorted { $0.frame.minX < $1.frame.minX }
        guard orderedLiveDestinations.map(\.label) == expectedDestinations.map(\.label) else {
            return nil
        }
        let usesOrdinaryLabelOnlyIdentity = contentSizeCategory == "large"
            && capturePhase == "initial"
            && liveDestinationButtons.allSatisfy(\.identifier.isEmpty)
        let usesLargeTypeLabelOnlyIdentity = contentSizeCategory != "large"
            && liveDestinationButtons.allSatisfy(\.identifier.isEmpty)
        let usesLabelOnlyIdentity = usesOrdinaryLabelOnlyIdentity || usesLargeTypeLabelOnlyIdentity
        let usesExactSymbolIdentity = expectedDestinations.allSatisfy { destination in
            liveDestinationButtons.contains {
                $0.identifier == destination.identifier && $0.label == destination.label
            }
        }
        guard usesLabelOnlyIdentity || usesExactSymbolIdentity else {
            return nil
        }

        var destinationReferences: [ObservedSystemChromeElementReference] = []
        for destination in expectedDestinations {
            let matches = uniqueAttestedElements(elements.filter {
                $0.exists
                    && $0.enabled
                    && $0.hittable
                    && $0.type == "button"
                    && $0.identifier == (usesLabelOnlyIdentity ? "" : destination.identifier)
                    && $0.label == destination.label
            })
            guard matches.count == 1,
                  let match = matches.first,
                  tabBar.frame.contains(match.frame, tolerance: 0.75),
                  liveDestinationButtons.contains(match) else {
                return nil
            }
            destinationReferences.append(systemChromeReference(match))
        }

        guard liveDestinationButtons.allSatisfy({ button in
            expectedDestinations.contains {
                (usesLabelOnlyIdentity ? button.identifier.isEmpty : $0.identifier == button.identifier)
                    && $0.label == button.label
            }
        }) else { return nil }

        guard let issueElement = auditIssueReference(issue, references: destinationReferences),
              let pixelEvidence = systemChromePixelEvidence(
            references: destinationReferences,
            labelPlacement: .bottom,
            screenshotBuffer: screenshotBuffer,
            screenshotSHA256: screenshotSHA256
        ) else {
            return nil
        }

        return ObservedVerifiedSystemChromeContrastFalsePositive(
            schema: usesOrdinaryLabelOnlyIdentity
                ? "iosNativeLabelOnlyBottomTabChromeContrastFalsePositiveV5"
                : usesLargeTypeLabelOnlyIdentity
                    ? "iosNativeLargeTypeBottomTabChromeContrastFalsePositiveV4"
                    : "iosNativeBottomTabChromeContrastFalsePositiveV3",
            capturePhase: capturePhase,
            reason: usesOrdinaryLabelOnlyIdentity
                ? "elementContrastBoundToAttestedNativeLabelOnlyBottomTabChrome"
                : usesLargeTypeLabelOnlyIdentity
                    ? "elementContrastBoundToAttestedNativeLargeTypeBottomTabChrome"
                    : "elementContrastBoundToAttestedNativeBottomTabChrome",
            contentSizeCategory: contentSizeCategory,
            issue: issue,
            screenshotSHA256: screenshotSHA256,
            issueElement: issueElement,
            pixelEvidence: pixelEvidence,
            navigationBar: systemChromeReference(navigationBar),
            tabBar: systemChromeReference(tabBar),
            destinations: destinationReferences
        )
    }

    private func auditIssueReference(
        _ issue: ObservedAuditIssue,
        references: [ObservedSystemChromeElementReference]
    ) -> ObservedSystemChromeElementReference? {
        guard !issue.elementType.isEmpty,
              let issueFrame = issue.elementFrame,
              !issue.diagnosticDescription.contains("Element:(null)") else {
            return nil
        }
        return references.only { reference in
            reference.identifier == issue.elementIdentifier
                && reference.label == issue.elementLabel
                && reference.type == issue.elementType
                && rectsApproximatelyEqual(reference.frame, issueFrame)
        }
    }

    private enum SystemChromeLabelPlacement {
        case trailing
        case bottom
    }

    private func systemChromePixelEvidence(
        references: [ObservedSystemChromeElementReference],
        labelPlacement: SystemChromeLabelPlacement,
        screenshotBuffer: ScreenshotPixelBuffer?,
        screenshotSHA256: String
    ) -> [ObservedVisibleTextContrastEvidence]? {
        guard screenshotSHA256.range(
            of: #"\A[0-9a-f]{64}\z"#,
            options: .regularExpression
        ) != nil,
        let screenshotBuffer,
        screenshotBuffer.screenshotSHA256 == screenshotSHA256 else {
            return nil
        }
        var evidence: [ObservedVisibleTextContrastEvidence] = []
        for reference in references {
            let pixelFrame: ObservedRect
            switch labelPlacement {
            case .trailing:
                pixelFrame = ObservedRect(
                    x: reference.frame.minX + reference.frame.width * 0.28,
                    y: reference.frame.minY + 4,
                    width: reference.frame.width * 0.68,
                    height: reference.frame.height - 8
                )
            case .bottom:
                pixelFrame = ObservedRect(
                    x: reference.frame.minX + 2,
                    y: reference.frame.minY + reference.frame.height * 0.50,
                    width: reference.frame.width - 4,
                    height: reference.frame.height * 0.46
                )
            }
            guard !pixelFrame.isEmpty,
                  let crop = screenshotBuffer.crop(in: pixelFrame) else {
                return nil
            }
            guard let pixelEvidence = ScreenshotPixelContrastAdjudicator.analyze(
                pixels: crop.pixels,
                width: crop.width,
                height: crop.height,
                screenshotSHA256: screenshotSHA256
            ) else {
                return nil
            }
            evidence.append(ObservedVisibleTextContrastEvidence(
                element: reference,
                pixelFrame: pixelFrame,
                pixelEvidence: pixelEvidence
            ))
        }
        return evidence
    }

    private func uniqueAttestedElements(
        _ elements: [ObservedAccessibilityElement]
    ) -> [ObservedAccessibilityElement] {
        elements.reduce(into: []) { unique, element in
            if !unique.contains(element) {
                unique.append(element)
            }
        }
    }

    private func systemChromeReference(
        _ element: ObservedAccessibilityElement
    ) -> ObservedSystemChromeElementReference {
        ObservedSystemChromeElementReference(
            identifier: element.identifier,
            label: element.label,
            type: element.type,
            frame: element.frame
        )
    }

    private func pixelAdjudicationFrames(
        elementFrame: ObservedRect?,
        attestedFrame: ObservedRect?
    ) -> [ObservedRect] {
        if let attestedFrame {
            return [attestedFrame]
        }
        if let elementFrame {
            return [elementFrame]
        }
        return []
    }

    private func auditCategory(_ type: XCUIAccessibilityAuditType) -> String {
        if type == .contrast { return "contrast" }
        if type == .hitRegion { return "hitRegion" }
        if type == .dynamicType { return "dynamicType" }
        if type == .textClipped { return "textClipped" }
        if type == .trait { return "trait" }
        return "unknown"
    }

    private func auditIssueMirror(_ issue: XCUIAccessibilityAuditIssue) -> String {
        Mirror(reflecting: issue).children.map { child in
            "\(child.label ?? "unknown")=\(String(reflecting: child.value))"
        }.joined(separator: "; ")
    }

    private func waitForRenderedRoute(
        in app: XCUIApplication,
        route: String,
        environment: [String: String]
    ) {
        let expectedLabel: String
        if environment["SPOONJOY_SCREENSHOT_AUTH"] == "0" {
            expectedLabel = "Spoonjoy"
        } else {
            expectedLabel = switch route {
            case "kitchen", "recipes", "saved-recipes", "recipe-detail": "Lemon Pantry Pasta"
            case "recipe-editor": "Recipe"
            case "recipe-covers": "Photo Studio"
            case "cook-mode": "Current cooking step 1, Boil pasta"
            case "cook-log": "Cooks"
            case "cookbooks", "cookbook-detail": "Weeknights"
            case "profile": "@ari"
            case "profile-graph": "jules"
            case "shopping-list": "Lemons"
            case "chefs": "Chefs"
            case "search": "Search"
            case "capture": "Imports"
            case "settings": "Account"
            case "unknown-link": "Link Not Found"
            default: route
            }
        }
        XCTAssertTrue(
            app.staticTexts[expectedLabel].waitForExistence(timeout: 30),
            "Observed route \(route) never rendered its expected content \(expectedLabel)."
        )
        XCTAssertTrue(
            app.staticTexts["Preparing"].waitForNonExistence(timeout: 10),
            "Observed route \(route) remained in its preparing state."
        )
    }

    private func routeRequiredLabels(route: String, signedIn: Bool) -> Set<String> {
        guard signedIn else {
            return ["Spoonjoy", "Sign in"]
        }
        return switch route {
        case "kitchen": [
            "My Kitchen",
            "Lemon Pantry Pasta",
            "Recipe Index"
        ]
        case "recipes", "saved-recipes": ["Lemon Pantry Pasta"]
        case "recipe-detail": ["Lemon Pantry Pasta", "Start Cooking"]
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

    private func routeRequiredIdentifiers(route: String) -> Set<String> {
        switch route {
        case "recipe-editor":
            ["recipe-editor.title", "recipe-editor.save"]
        case "recipe-covers":
            [
                "recipe-covers.photo-picker",
                "recipe-covers.staged-photo-status",
                "recipe-covers.clear-photo",
                "recipe-covers.save-photo",
                "recipe-covers.archive.cover_primary"
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

    private func routeRequiredChromeIdentifiers(route: String) -> Set<String> {
        switch route {
        case "recipe-editor":
            ["recipe-editor.save"]
        default:
            []
        }
    }

    private func routeRequiredScrollIdentifiers(route: String) -> Set<String> {
        switch route {
        case "recipe-covers":
            ["recipe-covers.archive.cover_primary"]
        default:
            []
        }
    }

    private func routeRequiredAccessibilityScrollIdentifiers(route: String) -> Set<String> {
        switch route {
        case "recipe-covers":
            ["recipe-covers.photo-picker", "recipe-covers.save-photo"]
        default:
            []
        }
    }

    private func routeTerminalExpectation(
        route: String,
        environment: [String: String]
    ) -> ObservedRouteTerminalExpectation? {
        let shoppingVariant = environment["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT"]
            ?? environment["SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT"]
            ?? "normal"
        let searchVariant = environment["SPOONJOY_SCREENSHOT_SEARCH_VARIANT"] ?? "blank"
        let captureVariant = environment["SPOONJOY_SCREENSHOT_CAPTURE_VARIANT"]
            ?? environment["SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT"]
            ?? "empty"
        let signedIn = environment["SPOONJOY_SCREENSHOT_AUTH"] != "0"

        switch route {
        case "kitchen":
            return ObservedRouteTerminalExpectation(
                identifier: "kitchen.cookbook.cookbook_weeknights",
                label: "Weeknights",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "recipes":
            return ObservedRouteTerminalExpectation(
                identifier: "recipes.terminal",
                label: "Start your recipe box with the dishes you actually cook.",
                elementTypes: ["staticText"],
                requiresInteraction: false
            )
        case "saved-recipes":
            return ObservedRouteTerminalExpectation(
                identifier: "saved-recipes.terminal",
                label: "Recipes you save to your cookbooks will appear here.",
                elementTypes: ["staticText"],
                requiresInteraction: false
            )
        case "recipe-detail":
            return ObservedRouteTerminalExpectation(
                identifier: "recipe-detail.terminal",
                label: "No cooks logged yet",
                elementTypes: ["staticText"],
                requiresInteraction: false
            )
        case "recipe-editor":
            return ObservedRouteTerminalExpectation(
                identifier: "recipe-editor.delete",
                label: "Delete Recipe",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "recipe-covers":
            return ObservedRouteTerminalExpectation(
                identifier: "recipe-covers.terminal",
                label: "Archive",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "cook-mode":
            return ObservedRouteTerminalExpectation(
                identifier: "cook-mode.terminal",
                label: "spaghetti, 12 oz",
                elementTypes: ["switch"],
                requiresInteraction: true
            )
        case "cook-log":
            return ObservedRouteTerminalExpectation(
                identifier: "cook-log.terminal",
                label: "No cooks logged yet",
                elementTypes: ["staticText"],
                requiresInteraction: false
            )
        case "cookbooks":
            return ObservedRouteTerminalExpectation(
                identifier: "cookbooks.terminal",
                label: "Slow Sundays and Long Simmering Suppers, 0 recipes",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "cookbook-detail":
            return ObservedRouteTerminalExpectation(
                identifier: "cookbook-detail.terminal",
                label: "2. Tomato Toast",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "shopping-list":
            return ObservedRouteTerminalExpectation(
                identifier: "shopping-list.terminal",
                label: ["empty", "all-complete"].contains(shoppingVariant)
                    ? "Add from recipe"
                    : "parmesan, 0.5 cup, Dairy",
                elementTypes: ["button", "switch"],
                requiresInteraction: true
            )
        case "chefs":
            return ObservedRouteTerminalExpectation(
                identifier: "chefs.terminal",
                label: "ari, Open kitchen profile",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "profile":
            return ObservedRouteTerminalExpectation(
                identifier: "profile.graph.kitchen-visitors",
                label: "1 Kitchen visitors",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "profile-graph":
            return ObservedRouteTerminalExpectation(
                identifier: "profile-graph.row.chef_jules",
                label: "jules, 1 spoon",
                elementTypes: ["button"],
                requiresInteraction: true
            )
        case "search":
            return ObservedRouteTerminalExpectation(
                identifier: "search.terminal",
                label: searchTerminalLabel(variant: searchVariant),
                elementTypes: searchVariant == "no-results" ? ["staticText"] : ["button"],
                requiresInteraction: searchVariant != "no-results"
            )
        case "capture":
            if !signedIn || captureVariant == "signed-out" {
                return ObservedRouteTerminalExpectation(
                    identifier: "native sign-in settings",
                    label: "Settings",
                    elementTypes: ["button"],
                    requiresInteraction: true
                )
            } else {
                return ObservedRouteTerminalExpectation(
                    identifier: "capture.terminal",
                    label: captureVariant == "empty"
                        ? "New recipes from your Spoonjoy agent will appear here."
                        : "Import actions",
                    elementTypes: captureVariant == "empty" ? ["staticText"] : ["button"],
                    requiresInteraction: captureVariant != "empty"
                )
            }
        case "settings":
            return ObservedRouteTerminalExpectation(
                identifier: "settings.terminal",
                label: "Offline",
                elementTypes: ["other"],
                requiresInteraction: false
            )
        default:
            return nil
        }
    }

    private func searchTerminalLabel(variant: String) -> String {
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
            "No Spoonjoy results match \"kumquat\"."
        default:
            "Shopping item, parmesan, 0.5 cup"
        }
    }

    private func routeUsesSystemTabBar(_ route: String) -> Bool {
        !["recipe-editor", "recipe-covers", "profile", "profile-graph", "unknown-link"].contains(route)
    }

    private func observedElements(
        in root: XCUIElement,
        windowFrame: CGRect,
        hitRegionAuditVerified: Bool = false
    ) -> [ObservedAccessibilityElement] {
        let observedTypes: [XCUIElement.ElementType] = [
            .scrollView, .collectionView, .navigationBar, .toolbar, .tabBar, .keyboard, .sheet, .alert,
            .button, .switch, .textField, .secureTextField, .textView, .link, .slider, .stepper,
            .cell, .staticText, .image
        ]
        return observedTypes.flatMap { type in
            root.descendants(matching: type).allElementsBoundByAccessibilityElement.map { element in
                let typeName = elementTypeName(type)
                let frame = element.frame
                let hasUsableFrame = !frame.isNull
                    && !frame.isInfinite
                    && frame.origin.x.isFinite
                    && frame.origin.y.isFinite
                    && frame.width.isFinite
                    && frame.height.isFinite
                    && frame.width > 0
                    && frame.height > 0
                let intersectsWindow = hasUsableFrame
                    && frame.intersects(windowFrame)
                return ObservedAccessibilityElement(
                    identifier: element.identifier,
                    label: element.label,
                    type: typeName,
                    frame: ObservedRect(frame),
                    exists: true,
                    hittable: element.isHittable,
                    enabled: element.isEnabled,
                    hitRegionAuditVerified: hitRegionAuditVerified && intersectsWindow,
                    focused: nil
                )
            }
        }
    }

    private func elementsWithHitRegionVerification(
        _ elements: [ObservedAccessibilityElement],
        windowFrame: CGRect,
        hitRegionAuditVerified: Bool
    ) -> [ObservedAccessibilityElement] {
        elements.map { element in
            ObservedAccessibilityElement(
                identifier: element.identifier,
                label: element.label,
                type: element.type,
                frame: element.frame,
                exists: element.exists,
                hittable: element.hittable,
                enabled: element.enabled,
                hitRegionAuditVerified: hitRegionAuditVerified
                    && element.frame.cgRect.intersects(windowFrame),
                focused: element.focused
            )
        }
    }

    private func observationDigest(_ elements: [ObservedAccessibilityElement]) throws -> String {
        let ordered = elements.sorted { first, second in
            let firstKey = [
                first.identifier, first.label, first.type,
                String(first.frame.x), String(first.frame.y),
                String(first.frame.width), String(first.frame.height),
                String(first.exists), String(first.hittable), String(first.enabled)
            ].joined(separator: "|")
            let secondKey = [
                second.identifier, second.label, second.type,
                String(second.frame.x), String(second.frame.y),
                String(second.frame.width), String(second.frame.height),
                String(second.exists), String(second.hittable), String(second.enabled)
            ].joined(separator: "|")
            return firstKey < secondKey
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ordered)
        return Self.sha256(data)
    }

    private func scrollPrimarySurfaceToTerminal(
        in app: XCUIApplication,
        route: String,
        terminalExpectation: ObservedRouteTerminalExpectation?,
        initialElements: [ObservedAccessibilityElement],
        initialScreenshot: XCUIScreenshot,
        windowFrame: CGRect,
        requiresSystemTabBar: Bool
    ) throws -> ObservedDeepScrollEvidence {
        let identifiedPageSurface = app.scrollViews["spoonjoy.page-scroll"]
        guard identifiedPageSurface.exists else {
            let finding = ObservedAccessibilityFinding(
                kind: .terminalNotReached,
                identifiers: [route],
                message: "No primary scroll surface was observed.",
                intersection: nil
            )
            return ObservedDeepScrollEvidence(
                route: route,
                reachedTerminal: false,
                swipeCount: 0,
                contentViewport: ObservedRect(windowFrame),
                tabBarFrame: nil,
                terminalElement: nil,
                findings: [finding],
                auditIssues: [],
                auditScope: .settledTerminalInteraction,
                auditTypes: [],
                verifiedContrastFalsePositives: [],
                verifiedStaleOffscreenContrastFalsePositives: [],
                contrastPixelAdjudicationDiagnostics: [],
                verifiedSystemChromeContrastFalsePositives: [],
                verifiedNativeSidebarSelectionContrastFalsePositives: [],
                verifiedTextClippedFalsePositives: [],
                screenshotSHA256: nil,
                readinessHandshake: nil,
                captureIdentity: nil,
                pixelAccessibilityBinding: nil,
                selectedScrollHierarchyIdentifier: nil,
                elements: [],
                selectedScrollHierarchyElements: [],
                waypoints: [],
                observedContentMovement: false,
                contentFitsWithoutScrolling: false
            )
        }
        let primarySurface = identifiedPageSurface

        let maxScrollActions = 12
        let initialViewport = contentViewport(windowFrame: windowFrame, elements: initialElements)
        let movementViewport = ObservedRect(windowFrame)
        guard let terminalExpectation else {
            XCTFail("Every deep-scroll route must define an exact terminal expectation: \(route)")
            throw NSError(domain: "NativeScreenshotEvidence", code: 2)
        }
        let terminalIdentifier = terminalExpectation.identifier
        let initialPrimaryElements = observedElements(in: primarySurface, windowFrame: windowFrame)
        let initialNamedTerminal = observedElement(
            in: primarySurface,
            identifier: terminalIdentifier,
            windowFrame: windowFrame
        )
        let terminalWasFullyVisibleInitially = terminalElementMatches(
            initialNamedTerminal,
            expectation: terminalExpectation,
            viewport: initialViewport
        )
        var reachedStableTerminal = false
        var observedContentMovement = false
        var scrollActionCount = 0
        var consecutiveTerminalMatches = 0
        var priorTerminalSignature: String?
        var waypoints: [ObservedScrollWaypointEvidence] = []
        var priorWaypointScreenshot = initialScreenshot
        var priorWaypointElements = initialElements
        var priorSelectedHierarchyElements = initialPrimaryElements
        let movementCandidates = uniqueMovementCandidates(
            elements: initialPrimaryElements,
            viewport: movementViewport
        )
        while !reachedStableTerminal && scrollActionCount < maxScrollActions {
            let namedTerminal = observedElement(
                in: primarySurface,
                identifier: terminalIdentifier,
                windowFrame: windowFrame
            )
            if terminalElementMatches(namedTerminal, expectation: terminalExpectation, viewport: initialViewport),
               let namedTerminal,
               let signature = terminalScrollSignature(
                   elements: [namedTerminal],
                   terminalIdentifier: terminalIdentifier,
                   viewport: initialViewport
               ) {
                consecutiveTerminalMatches = signature == priorTerminalSignature
                    ? consecutiveTerminalMatches + 1
                    : 1
                priorTerminalSignature = signature
                if consecutiveTerminalMatches >= 2 {
                    reachedStableTerminal = true
                    break
                }
                waitForScrollToSettle()
                continue
            }
            consecutiveTerminalMatches = 0
            priorTerminalSignature = nil
            let requestedContentOffset = deterministicWaypointContentOffset(
                correction: terminalScrollCorrection(
                    terminalFrame: namedTerminal?.frame,
                    viewport: initialViewport
                ),
                viewport: initialViewport
            )
            drag(primarySurface, contentOffset: requestedContentOffset)
            scrollActionCount += 1
            waitForScrollToSettle()
            let waypointCapturePhase = "deepScrollWaypoint-\(scrollActionCount)"
            let waypointCapture = try captureAttestedScreenshot(
                in: app,
                route: route,
                captureRunNonce: ProcessInfo.processInfo.environment["SPOONJOY_SCREENSHOT_RUN_NONCE"],
                capturePhase: waypointCapturePhase,
                selectedScrollHierarchy: primarySurface
            )
            let waypointWindowFrame = waypointCapture.windowFrame.cgRect
            let waypointViewport = contentViewport(
                windowFrame: waypointWindowFrame,
                elements: waypointCapture.elements
            )
            let waypointAuditResult = accessibilityAuditIssues(
                in: app,
                viewport: waypointViewport,
                screenshot: waypointCapture.screenshot,
                windowFrame: waypointWindowFrame,
                attestedElements: waypointCapture.elements,
                contentSizeCategory: ProcessInfo.processInfo.environment["SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY"] ?? "",
                capturePhase: waypointCapturePhase,
                scope: .settledScrollWaypoint,
                priorScreenshot: priorWaypointScreenshot,
                priorAttestedElements: priorWaypointElements
            )
            let waypointElements = elementsWithHitRegionVerification(
                waypointCapture.elements,
                windowFrame: waypointWindowFrame,
                hitRegionAuditVerified: waypointAuditResult.hitRegionAuditPassed
            )
            let waypointSelectedHierarchyElements = elementsWithHitRegionVerification(
                waypointCapture.selectedScrollHierarchyElements,
                windowFrame: waypointWindowFrame,
                hitRegionAuditVerified: waypointAuditResult.hitRegionAuditPassed
            )
            let waypointCoverage = scrollWaypointCoverage(
                requestedContentOffset: requestedContentOffset,
                before: priorSelectedHierarchyElements,
                after: waypointSelectedHierarchyElements,
                viewport: waypointViewport
            )
            var waypointFindings = persistentChromeFindings(
                before: priorWaypointElements,
                after: waypointElements,
                beforeScrollContent: priorSelectedHierarchyElements,
                afterScrollContent: waypointSelectedHierarchyElements
            )
            waypointFindings.append(contentsOf: ScreenshotEvidenceGeometry.validate(
                elements: waypointElements,
                requirements: unconstrainedGeometryRequirements(viewport: waypointViewport)
            ))
            if waypointCoverage == nil {
                waypointFindings.append(ObservedAccessibilityFinding(
                    kind: .terminalNotReached,
                    identifiers: [waypointCapturePhase],
                    message: "Scroll waypoint did not prove overlapping viewport coverage.",
                    intersection: nil
                ))
            }
            if waypointCapture.pixelAccessibilityBinding.selectedScrollHierarchyIdentifier
                != "spoonjoy.page-scroll" {
                waypointFindings.append(ObservedAccessibilityFinding(
                    kind: .requiredIdentifierMissing,
                    identifiers: ["spoonjoy.page-scroll"],
                    message: "Scroll waypoint was not bound to the exact selected scroll hierarchy.",
                    intersection: nil
                ))
            }
            let waypoint = ObservedScrollWaypointEvidence(
                index: scrollActionCount,
                capturePhase: waypointCapturePhase,
                coverage: waypointCoverage,
                contentViewport: waypointViewport,
                findings: waypointFindings,
                auditIssues: waypointAuditResult.blockingIssues,
                auditScope: .settledScrollWaypoint,
                auditTypes: waypointAuditResult.auditTypes,
                verifiedContrastFalsePositives: waypointAuditResult.verifiedContrastFalsePositives,
                verifiedStaleOffscreenContrastFalsePositives: waypointAuditResult.verifiedStaleOffscreenContrastFalsePositives,
                contrastPixelAdjudicationDiagnostics: waypointAuditResult.contrastPixelAdjudicationDiagnostics,
                verifiedSystemChromeContrastFalsePositives: waypointAuditResult.verifiedSystemChromeContrastFalsePositives,
                verifiedNativeSidebarSelectionContrastFalsePositives: waypointAuditResult.verifiedNativeSidebarSelectionContrastFalsePositives,
                verifiedTextClippedFalsePositives: waypointAuditResult.verifiedTextClippedFalsePositives,
                screenshotArtifactPath: try writeDurableWaypointScreenshot(
                    waypointCapture.screenshot.pngRepresentation,
                    index: scrollActionCount
                ).path,
                screenshotBytes: waypointCapture.screenshot.pngRepresentation.count,
                screenshotSHA256: Self.sha256(waypointCapture.screenshot.pngRepresentation),
                readinessHandshake: waypointCapture.handshake,
                captureIdentity: waypointCapture.identity,
                pixelAccessibilityBinding: waypointCapture.pixelAccessibilityBinding,
                elements: waypointElements,
                selectedScrollHierarchyElements: waypointSelectedHierarchyElements
            )
            waypoints.append(waypoint)
            attachScreenshot(
                waypointCapture.screenshot,
                name: "deep-scroll-waypoint-\(scrollActionCount)-screenshot"
            )
            priorWaypointScreenshot = waypointCapture.screenshot
            priorWaypointElements = waypointElements
            priorSelectedHierarchyElements = waypointSelectedHierarchyElements
            if waypointCoverage != nil {
                observedContentMovement = true
            }
            if !observedContentMovement {
                let currentNamedTerminal = observedElement(
                    in: primarySurface,
                    identifier: terminalIdentifier,
                    windowFrame: windowFrame
                )
                let namedTerminalMoved: Bool
                if let initialNamedTerminal, let currentNamedTerminal {
                    namedTerminalMoved = didObserveIdentifiedMovement(
                        before: initialNamedTerminal,
                        after: currentNamedTerminal
                    )
                } else {
                    namedTerminalMoved = false
                }
                observedContentMovement = namedTerminalMoved || movementCandidates.contains { before in
                    guard let after = observedElement(
                        in: primarySurface,
                        identifier: before.identifier,
                        windowFrame: windowFrame
                    ) else {
                        return false
                    }
                    return didObserveIdentifiedMovement(before: before, after: after)
                }
            }
        }

        let deepCapture = try captureAttestedScreenshot(
            in: app,
            route: route,
            captureRunNonce: ProcessInfo.processInfo.environment["SPOONJOY_SCREENSHOT_RUN_NONCE"],
            capturePhase: "deepScroll",
            selectedScrollHierarchy: primarySurface
        )
        let deepScreenshot = deepCapture.screenshot
        let capturedWindowFrame = deepCapture.windowFrame.cgRect
        let viewport = contentViewport(windowFrame: capturedWindowFrame, elements: deepCapture.elements)
        let auditResult = accessibilityAuditIssues(
            in: app,
            viewport: viewport,
            screenshot: deepScreenshot,
            windowFrame: capturedWindowFrame,
            attestedElements: deepCapture.elements,
            contentSizeCategory: ProcessInfo.processInfo.environment["SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY"] ?? "",
            capturePhase: "deepScroll",
            scope: .settledTerminalInteraction,
            priorScreenshot: initialScreenshot,
            priorAttestedElements: initialElements
        )
        let elements = elementsWithHitRegionVerification(
            deepCapture.elements,
            windowFrame: capturedWindowFrame,
            hitRegionAuditVerified: auditResult.hitRegionAuditPassed
        )
        let selectedHierarchyElements = elementsWithHitRegionVerification(
            deepCapture.selectedScrollHierarchyElements,
            windowFrame: capturedWindowFrame,
            hitRegionAuditVerified: auditResult.hitRegionAuditPassed
        )
        let terminalMatchesInSelectedHierarchy = selectedHierarchyElements.filter {
            $0.identifier == terminalIdentifier && $0.exists
        }
        let terminalElement = terminalMatchesInSelectedHierarchy.count == 1
            ? terminalMatchesInSelectedHierarchy.first
            : nil
        let tabBar = elements.first { $0.type == "tabBar" && $0.exists }
        let contentFitsWithoutScrolling = terminalWasFullyVisibleInitially
            && !observedContentMovement
        var findings: [ObservedAccessibilityFinding] = []
        findings.append(contentsOf: waypoints.flatMap(\.findings))
        findings.append(contentsOf: persistentChromeFindings(
            before: initialElements,
            after: elements,
            beforeScrollContent: initialPrimaryElements,
            afterScrollContent: selectedHierarchyElements
        ))
        findings.append(contentsOf: ScreenshotEvidenceGeometry.validate(
            elements: elements,
            requirements: ObservedGeometryRequirements(
                viewport: viewport,
                requiredIdentifiers: [],
                requiredVisibleIdentifiers: [],
                requiredLabels: [],
                peerPairs: [],
                chromeTypes: Self.chromeTypes,
                actionableTypes: Self.actionableTypes,
                minimumActionTarget: 44,
                apnsThisDeviceIdentifier: nil,
                apnsPushDeliveryIdentifier: nil
            )
        ))
        let hasCompleteIntermediateAuditCoverage = intermediateAuditCoverageIsComplete(
            scrollActionCount: scrollActionCount,
            waypointIndices: waypoints.map(\.index),
            waypointAuditTypes: waypoints.map(\.auditTypes),
            waypointHasOverlapProof: waypoints.map { $0.coverage != nil }
        )
        if !hasCompleteIntermediateAuditCoverage {
            findings.append(ObservedAccessibilityFinding(
                kind: .terminalNotReached,
                identifiers: [route],
                message: "Deep-scroll proof did not audit every deterministic overlapping waypoint.",
                intersection: nil
            ))
        }
        if deepCapture.pixelAccessibilityBinding.selectedScrollHierarchyIdentifier != "spoonjoy.page-scroll" {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: ["spoonjoy.page-scroll"],
                message: "Deep-scroll proof was not bound to the exact selected scroll hierarchy.",
                intersection: nil
            ))
        }
        if !reachedStableTerminal {
            findings.append(ObservedAccessibilityFinding(
                kind: .terminalNotReached,
                identifiers: [route],
                message: "Primary surface did not settle after \(maxScrollActions) terminal scroll actions.",
                intersection: nil
            ))
        }
        if !observedContentMovement && !contentFitsWithoutScrolling {
            findings.append(ObservedAccessibilityFinding(
                kind: .terminalNotReached,
                identifiers: [route],
                message: "Primary surface did not produce observed content movement.",
                intersection: nil
            ))
        }
        if terminalElement?.identifier != terminalIdentifier {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [terminalIdentifier],
                message: "Deep-scroll proof did not reach the route terminal control.",
                intersection: nil
            ))
        }
        if terminalElement?.label != terminalExpectation.label {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: ["label:\(terminalExpectation.label)"],
                message: "Deep-scroll proof did not reach the route terminal object label.",
                intersection: nil
            ))
        }
        if let terminalElement,
           !terminalExpectation.elementTypes.contains(terminalElement.type)
                || terminalExpectation.requiresInteraction && (!terminalElement.hittable || !terminalElement.enabled) {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [terminalIdentifier],
                message: "Deep-scroll proof terminal role or interaction semantics did not match the route contract.",
                intersection: nil
            ))
        }
        if let terminalElement, tabBar != nil || !requiresSystemTabBar {
            findings.append(contentsOf: ScreenshotEvidenceGeometry.validateTerminalElement(
                terminalElement,
                contentViewport: viewport,
                tabBarFrame: tabBar?.frame
            ))
        } else {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [terminalElement == nil ? "terminalElement" : "system.tabBar"],
                message: "Deep-scroll proof requires both a terminal content element and the system tab bar.",
                intersection: nil
            ))
        }

        let evidence = ObservedDeepScrollEvidence(
            route: route,
            reachedTerminal: terminalProofIsValid(
                reachedStableTerminal: reachedStableTerminal,
                observedContentMovement: observedContentMovement,
                contentFitsWithoutScrolling: contentFitsWithoutScrolling,
                scrollActionCount: scrollActionCount
            )
                && hasCompleteIntermediateAuditCoverage
                && terminalElementMatches(terminalElement, expectation: terminalExpectation, viewport: viewport),
            swipeCount: scrollActionCount,
            contentViewport: viewport,
            tabBarFrame: tabBar?.frame,
            terminalElement: terminalElement,
            findings: findings,
            auditIssues: auditResult.blockingIssues,
            auditScope: .settledTerminalInteraction,
            auditTypes: auditResult.auditTypes,
            verifiedContrastFalsePositives: auditResult.verifiedContrastFalsePositives,
            verifiedStaleOffscreenContrastFalsePositives: auditResult.verifiedStaleOffscreenContrastFalsePositives,
            contrastPixelAdjudicationDiagnostics: auditResult.contrastPixelAdjudicationDiagnostics,
            verifiedSystemChromeContrastFalsePositives: auditResult.verifiedSystemChromeContrastFalsePositives,
            verifiedNativeSidebarSelectionContrastFalsePositives: auditResult.verifiedNativeSidebarSelectionContrastFalsePositives,
            verifiedTextClippedFalsePositives: auditResult.verifiedTextClippedFalsePositives,
            screenshotSHA256: Self.sha256(deepScreenshot.pngRepresentation),
            readinessHandshake: deepCapture.handshake,
            captureIdentity: deepCapture.identity,
            pixelAccessibilityBinding: deepCapture.pixelAccessibilityBinding,
            selectedScrollHierarchyIdentifier: deepCapture.pixelAccessibilityBinding.selectedScrollHierarchyIdentifier,
            elements: elements,
            selectedScrollHierarchyElements: selectedHierarchyElements,
            waypoints: waypoints,
            observedContentMovement: observedContentMovement,
            contentFitsWithoutScrolling: contentFitsWithoutScrolling
        )
        let data = try JSONEncoder.observedEvidence.encode(evidence)
        attachJSON(data, name: "deep-scroll-evidence")
        if let configuredPath = ProcessInfo.processInfo.environment[Self.evidencePathEnvironmentKey] {
            let output = URL(fileURLWithPath: configuredPath)
                .deletingPathExtension()
                .appendingPathExtension("deep-scroll.json")
            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: output, options: Data.WritingOptions.atomic)
        }
        attachScreenshot(deepScreenshot, name: "deep-scroll-screenshot")
        return evidence
    }

    private func terminalProofIsValid(
        reachedStableTerminal: Bool,
        observedContentMovement: Bool,
        contentFitsWithoutScrolling: Bool,
        scrollActionCount: Int
    ) -> Bool {
        reachedStableTerminal
            && ((scrollActionCount > 0 && observedContentMovement)
                || (scrollActionCount == 0 && contentFitsWithoutScrolling))
    }

    private func intermediateAuditCoverageIsComplete(
        scrollActionCount: Int,
        waypointIndices: [Int],
        waypointAuditTypes: [[String]],
        waypointHasOverlapProof: [Bool]
    ) -> Bool {
        let requiredAuditTypes: Set<String> = [
            "contrast", "dynamicType", "textClipped", "hitRegion", "trait"
        ]
        let expectedIndices = scrollActionCount == 0 ? [] : Array(1...scrollActionCount)
        guard scrollActionCount >= 0,
              waypointIndices.count == scrollActionCount,
              waypointAuditTypes.count == scrollActionCount,
              waypointHasOverlapProof.count == scrollActionCount,
              waypointIndices == expectedIndices,
              waypointHasOverlapProof.allSatisfy({ $0 }) else {
            return false
        }
        return waypointAuditTypes.allSatisfy {
            Set($0).isSuperset(of: requiredAuditTypes)
        }
    }

    private func scrollWaypointCoverage(
        requestedContentOffset: CGFloat,
        before: [ObservedAccessibilityElement],
        after: [ObservedAccessibilityElement],
        viewport: ObservedRect
    ) -> ObservedScrollWaypointCoverage? {
        guard requestedContentOffset != 0, viewport.height > Self.minimumTerminalDragDistance else {
            return nil
        }
        let excludedTypes = Self.chromeTypes.union(["scrollView", "collectionView"])
        let beforeByIdentifier = Dictionary(
            grouping: before.filter {
                $0.exists && !$0.identifier.isEmpty && !excludedTypes.contains($0.type)
            },
            by: \.identifier
        )
        let afterByIdentifier = Dictionary(
            grouping: after.filter {
                $0.exists && !$0.identifier.isEmpty && !excludedTypes.contains($0.type)
            },
            by: \.identifier
        )
        let direction = requestedContentOffset.sign == .minus ? -1.0 : 1.0
        let displacements = beforeByIdentifier.compactMap { identifier, beforeMatches -> Double? in
            guard beforeMatches.count == 1,
                  let beforeElement = beforeMatches.first,
                  let afterMatches = afterByIdentifier[identifier],
                  afterMatches.count == 1,
                  let afterElement = afterMatches.first,
                  beforeElement.type == afterElement.type,
                  beforeElement.label == afterElement.label,
                  abs(beforeElement.frame.x - afterElement.frame.x) <= 0.75,
                  abs(beforeElement.frame.width - afterElement.frame.width) <= 0.75,
                  abs(beforeElement.frame.height - afterElement.frame.height) <= 0.75 else {
                return nil
            }
            let displacement = afterElement.frame.y - beforeElement.frame.y
            return abs(displacement) > 1 && displacement.sign == direction.sign
                ? abs(displacement)
                : nil
        }
        guard let observedContentDisplacement = displacements.max() else {
            return nil
        }
        let viewportOverlap = viewport.height - observedContentDisplacement
        guard viewportOverlap >= Self.minimumTerminalDragDistance else {
            return nil
        }
        return ObservedScrollWaypointCoverage(
            requestedContentOffset: requestedContentOffset,
            observedContentDisplacement: observedContentDisplacement,
            viewportOverlap: viewportOverlap
        )
    }

    private func deterministicWaypointContentOffset(
        correction: CGFloat?,
        viewport: ObservedRect
    ) -> CGFloat {
        let maximumStep = max(
            Self.minimumTerminalDragDistance,
            min(viewport.height * 0.5, viewport.height - Self.minimumTerminalDragDistance)
        )
        let desired = correction ?? -maximumStep
        let magnitude = min(max(abs(desired), Self.minimumTerminalDragDistance), maximumStep)
        return desired.sign == .minus ? -magnitude : magnitude
    }

    private func persistentChromeFindings(
        before: [ObservedAccessibilityElement],
        after: [ObservedAccessibilityElement],
        beforeScrollContent: [ObservedAccessibilityElement] = [],
        afterScrollContent: [ObservedAccessibilityElement] = []
    ) -> [ObservedAccessibilityFinding] {
        let beforeElements = persistentChromeElements(before, excluding: beforeScrollContent)
        let afterElements = persistentChromeElements(after, excluding: afterScrollContent)
        var unmatchedAfterIndices = Array(afterElements.indices)
        var removed: [ObservedAccessibilityElement] = []

        for beforeElement in beforeElements {
            guard let matchedPosition = unmatchedAfterIndices.firstIndex(where: { position in
                persistentChromeElementsMatch(beforeElement, afterElements[position])
            }) else {
                removed.append(beforeElement)
                continue
            }
            unmatchedAfterIndices.remove(at: matchedPosition)
        }
        let added = unmatchedAfterIndices.map { afterElements[$0] }
        guard !removed.isEmpty || !added.isEmpty else {
            return []
        }
        return [ObservedAccessibilityFinding(
            kind: .persistentChromeChanged,
            identifiers: ["system.navigation.chrome"],
            message: persistentChromeChangeMessage(
                removed: removed.map(persistentChromeSignature).sorted(),
                added: added.map(persistentChromeSignature).sorted()
            ),
            intersection: nil
        )]
    }

    private func persistentChromeChangeMessage(removed: [String], added: [String]) -> String {
        return "Persistent navigation, sidebar, or tab chrome changed during deep scroll. "
            + "Removed: \(removed.joined(separator: "; ")). Added: \(added.joined(separator: "; "))."
    }

    private func persistentChromeElements(
        _ elements: [ObservedAccessibilityElement],
        excluding scrollContent: [ObservedAccessibilityElement]
    ) -> [ObservedAccessibilityElement] {
        let containers = elements.filter { element in
            Self.chromeTypes.contains(element.type)
                || (element.type == "collectionView" && element.label == "Sidebar")
        }
        return elements
            .filter { element in
                guard element.exists else { return false }
                if containers.contains(element) { return true }
                if isStructurallyObservedScrollContent(element, in: scrollContent) { return false }
                guard ["button", "staticText"].contains(element.type),
                      !element.identifier.isEmpty || !element.label.isEmpty else {
                    return false
                }
                return containers.contains { container in
                    guard container.frame.contains(element.frame, tolerance: 2.5) else {
                        return false
                    }
                    return container.type != "tabBar" || element.type == "button"
                }
            }
    }

    private func persistentChromeElementsMatch(
        _ before: ObservedAccessibilityElement,
        _ after: ObservedAccessibilityElement
    ) -> Bool {
        let tolerance = 0.75
        return before.type == after.type
            && stableChromeIdentity(before) == stableChromeIdentity(after)
            && before.label == after.label
            && abs(before.frame.x - after.frame.x) <= tolerance
            && abs(before.frame.y - after.frame.y) <= tolerance
            && abs(before.frame.width - after.frame.width) <= tolerance
            && abs(before.frame.height - after.frame.height) <= tolerance
    }

    private func persistentChromeSignature(_ element: ObservedAccessibilityElement) -> String {
        [
            element.type,
            stableChromeIdentity(element),
            element.label,
            stableChromeCoordinate(element.frame.x),
            stableChromeCoordinate(element.frame.y),
            stableChromeCoordinate(element.frame.width),
            stableChromeCoordinate(element.frame.height)
        ].joined(separator: "|")
    }

    private func stableChromeIdentity(_ element: ObservedAccessibilityElement) -> String {
        element.label.isEmpty ? element.identifier : ""
    }

    private func isStructurallyObservedScrollContent(
        _ element: ObservedAccessibilityElement,
        in scrollContent: [ObservedAccessibilityElement]
    ) -> Bool {
        scrollContent.contains { candidate in
            guard candidate.exists, candidate.type == element.type else {
                return false
            }
            let identityMatches: Bool
            if !element.identifier.isEmpty || !candidate.identifier.isEmpty {
                identityMatches = !element.identifier.isEmpty
                    && element.identifier == candidate.identifier
            } else {
                identityMatches = !element.label.isEmpty && element.label == candidate.label
            }
            guard identityMatches else {
                return false
            }
            let tolerance = 2.5
            return abs(element.frame.x - candidate.frame.x) <= tolerance
                && abs(element.frame.y - candidate.frame.y) <= tolerance
                && abs(element.frame.width - candidate.frame.width) <= tolerance
                && abs(element.frame.height - candidate.frame.height) <= tolerance
        }
    }

    private func stableChromeCoordinate(_ value: Double) -> String {
        value.rounded().formatted(.number.grouping(.never))
    }

    private func didObserveContentMovement(
        before: [ObservedAccessibilityElement],
        after: [ObservedAccessibilityElement],
        viewport: ObservedRect
    ) -> Bool {
        let excludedTypes = Self.chromeTypes.union(["application", "window", "scrollView", "collectionView"])
        let eligibleBefore = before.filter {
            !$0.identifier.isEmpty
                && !excludedTypes.contains($0.type)
                && $0.frame.intersection(with: viewport) != nil
        }
        let eligibleAfter = after.filter {
            !$0.identifier.isEmpty && !excludedTypes.contains($0.type)
        }
        let beforeByIdentifier = Dictionary(grouping: eligibleBefore, by: \.identifier)
        let afterByIdentifier = Dictionary(grouping: eligibleAfter, by: \.identifier)
        return beforeByIdentifier.contains { identifier, beforeMatches in
            guard beforeMatches.count == 1,
                  let afterMatches = afterByIdentifier[identifier],
                  afterMatches.count == 1,
                  let element = beforeMatches.first,
                  let moved = afterMatches.first else {
                return false
            }
            return didObserveIdentifiedMovement(before: element, after: moved)
        }
    }

    private func didObserveIdentifiedMovement(
        before: ObservedAccessibilityElement,
        after: ObservedAccessibilityElement
    ) -> Bool {
        guard before.exists,
              after.exists,
              !before.identifier.isEmpty,
              before.identifier == after.identifier,
              !Self.chromeTypes.contains(before.type),
              !Self.chromeTypes.contains(after.type) else {
            return false
        }
        return abs(after.frame.x - before.frame.x) > 1
            || abs(after.frame.y - before.frame.y) > 1
    }

    private func uniqueMovementCandidates(
        elements: [ObservedAccessibilityElement],
        viewport: ObservedRect
    ) -> [ObservedAccessibilityElement] {
        let excludedTypes = Self.chromeTypes.union(["application", "window", "scrollView", "collectionView"])
        return Dictionary(
            grouping: elements.filter {
                !$0.identifier.isEmpty
                    && !excludedTypes.contains($0.type)
            },
            by: \.identifier
        )
        .values
        .filter { $0.count == 1 }
        .compactMap(\.first)
        .sorted { $0.frame.maxY > $1.frame.maxY }
    }

    private func observedElement(
        in root: XCUIElement,
        identifier: String,
        windowFrame: CGRect
    ) -> ObservedAccessibilityElement? {
        let matches = root.descendants(matching: .any)
            .matching(identifier: identifier)
            .allElementsBoundByAccessibilityElement
        guard matches.count == 1, let element = matches.first else {
            return nil
        }
        let frame = element.frame
        return ObservedAccessibilityElement(
            identifier: element.identifier,
            label: element.label,
            type: elementTypeName(element.elementType),
            frame: ObservedRect(frame),
            exists: element.exists,
            hittable: element.isHittable,
            enabled: element.isEnabled,
            hitRegionAuditVerified: false,
            focused: nil
        )
    }

    private func namedTerminalIsVisible(
        in elements: [ObservedAccessibilityElement],
        terminalIdentifier: String?,
        viewport: ObservedRect
    ) -> Bool {
        guard let terminalIdentifier else {
            return false
        }
        return elements.contains { element in
            element.identifier == terminalIdentifier
                && element.exists
                && viewport.contains(element.frame)
        }
    }

    private func terminalScrollCorrection(
        terminalFrame: ObservedRect?,
        viewport: ObservedRect
    ) -> CGFloat? {
        guard let terminalFrame else {
            return nil
        }
        let margin: CGFloat = 8
        if terminalFrame.minY < viewport.minY + margin {
            return viewport.minY + margin - terminalFrame.minY
        }
        if terminalFrame.maxY > viewport.maxY - margin {
            return viewport.maxY - margin - terminalFrame.maxY
        }
        return nil
    }

    private func drag(_ surface: XCUIElement, contentOffset: CGFloat) {
        let surfaceHeight = max(surface.frame.height, 1)
        let dragDistance = terminalDragDistance(contentOffset: contentOffset)
        let endY = min(0.85, max(0.15, 0.5 + dragDistance / surfaceHeight))
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(
            forDuration: 0.05,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 0.05
        )
    }

    private func terminalDragDistance(contentOffset: CGFloat) -> CGFloat {
        guard contentOffset != 0 else {
            return 0
        }
        return contentOffset.sign == .minus
            ? min(contentOffset, -Self.minimumTerminalDragDistance)
            : max(contentOffset, Self.minimumTerminalDragDistance)
    }

    private func waitForScrollToSettle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func terminalScrollSignature(
        elements: [ObservedAccessibilityElement],
        terminalIdentifier: String?,
        viewport: ObservedRect
    ) -> String? {
        guard let terminalIdentifier else { return nil }
        let terminal = elements.first { $0.identifier == terminalIdentifier && $0.exists }
        guard let terminal, viewport.contains(terminal.frame) else {
            return nil
        }
        return [
            terminal.identifier,
            terminal.label,
            terminal.type,
            terminal.frame.x.formatted(.number.precision(.fractionLength(0...2))),
            terminal.frame.y.formatted(.number.precision(.fractionLength(0...2))),
            terminal.frame.width.formatted(.number.precision(.fractionLength(0...2))),
            terminal.frame.height.formatted(.number.precision(.fractionLength(0...2)))
        ].joined(separator: "|")
    }

    private func terminalElementMatches(
        _ element: ObservedAccessibilityElement?,
        expectation: ObservedRouteTerminalExpectation,
        viewport: ObservedRect
    ) -> Bool {
        guard let element else { return false }
        return element.exists
            && element.identifier == expectation.identifier
            && element.label == expectation.label
            && expectation.elementTypes.contains(element.type)
            && element.enabled
            && (!expectation.requiresInteraction || element.hittable)
            && viewport.contains(element.frame)
    }

    private func contentViewport(
        windowFrame: CGRect,
        elements: [ObservedAccessibilityElement]
    ) -> ObservedRect {
        let window = ObservedRect(windowFrame)
        let sidebarMaxX = elements
            .filter {
                $0.type == "navigationBar"
                    && $0.exists
                    && $0.frame.minX <= window.minX + 16
                    && $0.frame.width < window.width * 0.6
            }
            .map(\.frame.maxX)
            .max() ?? window.minX
        let topChrome = elements
            .filter { ["navigationBar", "toolbar"].contains($0.type) && $0.exists }
            .map(\.frame.maxY)
            .max() ?? window.minY
        let topClearance = topChrome > window.minY ? 24.0 : 0
        let bottomChrome = elements
            .filter { ["tabBar", "keyboard"].contains($0.type) && $0.exists }
            .map(\.frame.minY)
            .min() ?? window.maxY
        let contentMinY = min(window.maxY, max(window.minY, topChrome + topClearance))
        let contentMaxY = max(contentMinY, min(window.maxY, bottomChrome))
        return ObservedRect(
            x: max(window.minX, sidebarMaxX),
            y: contentMinY,
            width: max(0, window.maxX - max(window.minX, sidebarMaxX)),
            height: max(0, contentMaxY - contentMinY)
        )
    }

    private func unconstrainedGeometryRequirements(
        viewport: ObservedRect
    ) -> ObservedGeometryRequirements {
        ObservedGeometryRequirements(
            viewport: viewport,
            requiredIdentifiers: [],
            requiredVisibleIdentifiers: [],
            requiredLabels: [],
            peerPairs: [],
            chromeTypes: Self.chromeTypes,
            actionableTypes: Self.actionableTypes,
            minimumActionTarget: 44,
            apnsThisDeviceIdentifier: nil,
            apnsPushDeliveryIdentifier: nil
        )
    }

    private func requirements(
        required: Set<String> = [],
        visible: Set<String> = [],
        peerPairs: [(String, String)] = [],
        apnsThisDeviceIdentifier: String? = nil
    ) -> ObservedGeometryRequirements {
        ObservedGeometryRequirements(
            viewport: ObservedRect(x: 0, y: 0, width: 100, height: 100),
            requiredIdentifiers: required,
            requiredVisibleIdentifiers: visible,
            requiredLabels: [],
            peerPairs: peerPairs,
            chromeTypes: Self.chromeTypes,
            actionableTypes: Self.actionableTypes,
            minimumActionTarget: 44,
            apnsThisDeviceIdentifier: apnsThisDeviceIdentifier,
            apnsPushDeliveryIdentifier: nil
        )
    }

    private func observedElement(
        identifier: String,
        label: String? = nil,
        type: String = "staticText",
        frame: ObservedRect,
        hittable: Bool = false,
        hitRegionAuditVerified: Bool = false
    ) -> ObservedAccessibilityElement {
        ObservedAccessibilityElement(
            identifier: identifier,
            label: label ?? identifier,
            type: type,
            frame: frame,
            exists: true,
            hittable: hittable,
            enabled: true,
            hitRegionAuditVerified: hitRegionAuditVerified,
            focused: nil
        )
    }

    private func syntheticContrastPixels(
        width: Int,
        height: Int,
        background: ObservedRGBPixel,
        foreground: ObservedRGBPixel
    ) -> [ObservedRGBPixel] {
        var pixels = Array(repeating: background, count: width * height)
        let foregroundMinX = width / 3
        let foregroundMaxX = foregroundMinX + max(2, width / 4)
        let foregroundMinY = height / 4
        let foregroundMaxY = foregroundMinY + max(2, height / 2)
        for row in foregroundMinY..<min(height, foregroundMaxY) {
            for column in foregroundMinX..<min(width, foregroundMaxX) {
                pixels[row * width + column] = foreground
            }
        }
        return pixels
    }

    private func anonymousContrastIssue() -> ObservedAuditIssue {
        ObservedAuditIssue(
            category: "contrast",
            type: "XCUIAccessibilityAuditType(rawValue: 1)",
            compactDescription: "Contrast failed",
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            diagnosticDescription: "<XCUIAccessibilityAuditIssue> Element:(null)",
            diagnosticMirror: "",
            elementIdentifier: "",
            elementLabel: "",
            elementType: "",
            elementFrame: nil
        )
    }

    private func syntheticChromePixelBuffer(
        width: Int,
        height: Int,
        frames: [ObservedRect],
        foreground: ObservedRGBPixel,
        screenshotSHA256: String
    ) -> ScreenshotPixelBuffer {
        let background = ObservedRGBPixel(red: 251, green: 250, blue: 244)
        var pixels = Array(repeating: background, count: width * height)
        for frame in frames {
            let insetX = max(2, Int(frame.width / 3))
            let insetY = max(2, Int(frame.height / 3))
            let minX = max(0, Int(frame.minX) + insetX)
            let minY = max(0, Int(frame.minY) + insetY)
            let maxX = min(width, max(minX + 2, Int(frame.maxX) - insetX))
            let maxY = min(height, max(minY + 2, Int(frame.maxY) - insetY))
            for row in minY..<maxY {
                for column in minX..<maxX {
                    pixels[row * width + column] = foreground
                }
            }
        }
        return ScreenshotPixelBuffer(
            width: width,
            height: height,
            pixels: pixels,
            pointSize: CGSize(width: width, height: height),
            screenshotSHA256: screenshotSHA256
        )
    }

    private func csvSet(_ raw: String?) -> Set<String> {
        Set((raw ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private func peerPairs(_ raw: String?) -> [(String, String)] {
        (raw ?? "").split(separator: ";").compactMap { pair in
            let identifiers = pair.split(separator: ":", maxSplits: 1).map(String.init)
            guard identifiers.count == 2 else { return nil }
            return (identifiers[0], identifiers[1])
        }
    }

    private func frameArea(_ frame: CGRect) -> CGFloat {
        max(0, frame.width) * max(0, frame.height)
    }

    private func elementTypeName(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .application: "application"
        case .window: "window"
        case .scrollView: "scrollView"
        case .collectionView: "collectionView"
        case .navigationBar: "navigationBar"
        case .toolbar: "toolbar"
        case .tabBar: "tabBar"
        case .keyboard: "keyboard"
        case .sheet: "sheet"
        case .alert: "alert"
        case .button: "button"
        case .switch: "switch"
        case .textField: "textField"
        case .secureTextField: "secureTextField"
        case .textView: "textView"
        case .link: "link"
        case .slider: "slider"
        case .stepper: "stepper"
        case .cell: "cell"
        case .staticText: "staticText"
        case .image: "image"
        default: "type-\(type.rawValue)"
        }
    }

    private func writeEvidence(_ data: Data, configuredPath: String?) throws {
        guard let configuredPath, !configuredPath.isEmpty else { return }
        let output = URL(fileURLWithPath: configuredPath)
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: output, options: .atomic)
    }

    private func writeDurableWaypointScreenshot(_ data: Data, index: Int) throws -> (path: String, url: URL) {
        let configuredPath = try XCTUnwrap(
            ProcessInfo.processInfo.environment[Self.evidencePathEnvironmentKey],
            "Deep-scroll waypoint evidence requires a durable configured evidence path"
        )
        let evidenceURL = URL(fileURLWithPath: configuredPath)
        let stem = evidenceURL.deletingPathExtension().lastPathComponent
        let fileName = "\(stem).deep-scroll-waypoint-\(index).png"
        let output = evidenceURL.deletingLastPathComponent().appendingPathComponent(fileName)
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: output, options: .atomic)
        return (fileName, output)
    }

    private func attachJSON(_ data: Data, name: String) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachScreenshot(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(
            data: screenshot.pngRepresentation,
            uniformTypeIdentifier: "public.png"
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension JSONEncoder {
    static var observedEvidence: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
