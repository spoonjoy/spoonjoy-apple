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
    let hitRegionAuditPassed: Bool
    let auditTypes: [String]
}

private enum ObservedAccessibilityAuditScope: String, Codable {
    case initialFullTree
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
    let screenshotSHA256: String?
    let readinessHandshake: ObservedReadinessHandshake?
    let captureIdentity: ObservedCaptureIdentity?
    let pixelAccessibilityBinding: ObservedPixelAccessibilityBinding?
    let selectedScrollHierarchyIdentifier: String?
    let selectedScrollHierarchyElements: [ObservedAccessibilityElement]
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
            hasSystemTabBar: provisionalElements.contains { $0.type == "tabBar" && $0.exists },
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
                windowFrame: capturedWindowFrame,
                requiresSystemTabBar: UIDevice.current.userInterfaceIdiom == .phone
                    && environment["SPOONJOY_SCREENSHOT_AUTH"] != "0"
                    && routeUsesSystemTabBar(route)
            )
            : nil
        let auditResult = initialAuditResult
        let allAuditIssues = auditResult.blockingIssues + (deepScroll?.auditIssues ?? [])
        let verifiedContrastFalsePositives = auditResult.verifiedContrastFalsePositives
        let evidence = ObservedScreenshotEvidence(
            platform: UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "ios",
            route: route,
            viewport: viewport,
            elements: initialElements,
            auditIssues: allAuditIssues,
            auditTypes: initialAuditResult.auditTypes,
            verifiedContrastFalsePositives: verifiedContrastFalsePositives,
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
            "kitchen.cookbook.cookbook_weeknights",
            "kitchen.cookbook.cookbook_slow_sundays"
        ]

        let expectation = routeTerminalExpectation(route: "kitchen", environment: [:])
        XCTAssertEqual(expectation?.identifier, fixtureCookbookIdentifiers.last)
        XCTAssertNotEqual(expectation?.identifier, fixtureCookbookIdentifiers.first)
        XCTAssertEqual(
            expectation?.label,
            "Slow Sundays and Long Simmering Suppers, 0 recipes"
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

    func testAuditNeverIgnoresUnattributedSwiftUIContrastBehindSystemTabBar() {
        XCTAssertFalse(shouldIgnoreUnattributedSystemTabBarContrast(
            auditType: .contrast,
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            elementFrame: nil,
            hasSystemTabBar: true
        ))
        XCTAssertFalse(shouldIgnoreUnattributedSystemTabBarContrast(
            auditType: .contrast,
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            elementFrame: ObservedRect(x: 20, y: 200, width: 100, height: 30),
            hasSystemTabBar: true
        ))
        XCTAssertFalse(shouldIgnoreUnattributedSystemTabBarContrast(
            auditType: .contrast,
            detailedDescription: "Contrast failed for SwiftUI.AccessibilityNode",
            elementFrame: nil,
            hasSystemTabBar: false
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

    func testEveryDeepScrollRouteHasAnExactSourceGroundedTerminal() {
        for route in Self.deepScrollRoutes {
            let expectation = routeTerminalExpectation(route: route, environment: [:])
            XCTAssertNotNil(expectation, "Missing terminal expectation for \(route)")
            XCTAssertFalse(expectation?.identifier.isEmpty == true, "Missing terminal identifier for \(route)")
            XCTAssertFalse(expectation?.label.isEmpty == true, "Missing terminal label for \(route)")
            XCTAssertFalse(expectation?.elementTypes.isEmpty == true, "Missing terminal role for \(route)")
        }
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
        XCTAssertGreaterThanOrEqual(evidence?.contrastRatio ?? 0, 4.5)
        XCTAssertGreaterThanOrEqual(evidence?.backgroundCoverage ?? 0, 0.65)
        XCTAssertGreaterThan(evidence?.foregroundPixelCount ?? 0, 0)
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
        let pixels = Array(repeating: background, count: 700)
            + Array(repeating: highContrast, count: 172)
            + Array(repeating: lowContrast, count: 128)

        XCTAssertNil(ScreenshotPixelContrastAdjudicator.analyze(
            pixels: pixels,
            width: 50,
            height: 20
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
        guard capturePhase == "initial" || capturePhase == "deepScroll" else {
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
        hasSystemTabBar: Bool,
        capturePhase: String,
        scope: ObservedAccessibilityAuditScope,
        includesDynamicTypeChecks: Bool = true
    ) -> ObservedAuditResult {
        var blockingIssues: [ObservedAuditIssue] = []
        var verifiedContrastFalsePositives: [ObservedVerifiedContrastFalsePositive] = []
        var hitRegionAuditPassed = true
        let screenshotPNG = screenshot.pngRepresentation
        let screenshotSHA256 = SHA256.hash(data: screenshotPNG)
            .map { String(format: "%02x", $0) }
            .joined()
        let screenshotBuffer = ScreenshotPixelBuffer(
            pngData: screenshotPNG,
            pointSize: windowFrame.size
        )
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
                if self.shouldIgnoreUnattributedSystemTabBarContrast(
                    auditType: issue.auditType,
                    detailedDescription: issue.detailedDescription,
                    elementFrame: elementFrame,
                    hasSystemTabBar: hasSystemTabBar
                ) {
                    return true
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
                if issue.auditType == .contrast,
                   elementType == "staticText",
                   let elementFrame,
                   let crop = screenshotBuffer?.crop(in: elementFrame),
                   let pixelEvidence = ScreenshotPixelContrastAdjudicator.analyze(
                       pixels: crop.pixels,
                       width: crop.width,
                       height: crop.height,
                       screenshotSHA256: screenshotSHA256
                   ) {
                    verifiedContrastFalsePositives.append(ObservedVerifiedContrastFalsePositive(
                        capturePhase: capturePhase,
                        issue: observedIssue,
                        pixelEvidence: pixelEvidence
                    ))
                    return true
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

    private func shouldIgnoreUnattributedSystemTabBarContrast(
        auditType: XCUIAccessibilityAuditType,
        detailedDescription: String,
        elementFrame: ObservedRect?,
        hasSystemTabBar: Bool
    ) -> Bool {
        _ = auditType
        _ = detailedDescription
        _ = elementFrame
        _ = hasSystemTabBar
        return false
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
            "Recipe Index",
            "Cookbook Shelf",
            "Slow Sundays and Long Simmering Suppers"
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
                identifier: "kitchen.cookbook.cookbook_slow_sundays",
                label: "Slow Sundays and Long Simmering Suppers, 0 recipes",
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
            .staticText
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
                screenshotSHA256: nil,
                readinessHandshake: nil,
                captureIdentity: nil,
                pixelAccessibilityBinding: nil,
                selectedScrollHierarchyIdentifier: nil,
                selectedScrollHierarchyElements: [],
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
            if let correction = terminalScrollCorrection(
                terminalFrame: namedTerminal?.frame,
                viewport: initialViewport
            ) {
                drag(primarySurface, contentOffset: correction)
            } else {
                primarySurface.swipeUp(velocity: .fast)
            }
            scrollActionCount += 1
            waitForScrollToSettle()
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
        let capturedTabBar = deepCapture.elements.first { $0.type == "tabBar" && $0.exists }
        let viewport = contentViewport(windowFrame: capturedWindowFrame, elements: deepCapture.elements)
        let auditResult = accessibilityAuditIssues(
            in: app,
            viewport: viewport,
            screenshot: deepScreenshot,
            windowFrame: capturedWindowFrame,
            hasSystemTabBar: capturedTabBar != nil,
            capturePhase: "deepScroll",
            scope: .settledTerminalInteraction
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
            screenshotSHA256: Self.sha256(deepScreenshot.pngRepresentation),
            readinessHandshake: deepCapture.handshake,
            captureIdentity: deepCapture.identity,
            pixelAccessibilityBinding: deepCapture.pixelAccessibilityBinding,
            selectedScrollHierarchyIdentifier: deepCapture.pixelAccessibilityBinding.selectedScrollHierarchyIdentifier,
            selectedScrollHierarchyElements: selectedHierarchyElements,
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

    private func persistentChromeFindings(
        before: [ObservedAccessibilityElement],
        after: [ObservedAccessibilityElement],
        beforeScrollContent: [ObservedAccessibilityElement] = [],
        afterScrollContent: [ObservedAccessibilityElement] = []
    ) -> [ObservedAccessibilityFinding] {
        let beforeSignature = persistentChromeSignature(before, excluding: beforeScrollContent)
        let afterSignature = persistentChromeSignature(after, excluding: afterScrollContent)
        guard beforeSignature != afterSignature else {
            return []
        }
        return [ObservedAccessibilityFinding(
            kind: .persistentChromeChanged,
            identifiers: ["system.navigation.chrome"],
            message: persistentChromeChangeMessage(before: beforeSignature, after: afterSignature),
            intersection: nil
        )]
    }

    private func persistentChromeChangeMessage(before: [String], after: [String]) -> String {
        let removed = before.filter { !after.contains($0) }
        let added = after.filter { !before.contains($0) }
        return "Persistent navigation, sidebar, or tab chrome changed during deep scroll. "
            + "Removed: \(removed.joined(separator: "; ")). Added: \(added.joined(separator: "; "))."
    }

    private func persistentChromeSignature(
        _ elements: [ObservedAccessibilityElement],
        excluding scrollContent: [ObservedAccessibilityElement]
    ) -> [String] {
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
            .map { element in
                [
                    element.type,
                    element.identifier,
                    element.label,
                    stableChromeCoordinate(element.frame.x),
                    stableChromeCoordinate(element.frame.y),
                    stableChromeCoordinate(element.frame.width),
                    stableChromeCoordinate(element.frame.height)
                ].joined(separator: "|")
            }
            .sorted()
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
        (value * 2).rounded().formatted(.number.grouping(.never))
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
