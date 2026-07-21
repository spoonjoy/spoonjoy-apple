import Foundation
import XCTest

private struct ObservedAuditIssue: Codable {
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

private struct ObservedAuditResult {
    let blockingIssues: [ObservedAuditIssue]
    let hitRegionAuditPassed: Bool
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
}

private struct ObservedScreenshotEvidence: Codable {
    let platform: String
    let route: String
    let viewport: ObservedRect
    let elements: [ObservedAccessibilityElement]
    let auditIssues: [ObservedAuditIssue]
    let geometryFindings: [ObservedAccessibilityFinding]
    let deepScroll: ObservedDeepScrollEvidence?
    let operatingSystemVersion: String
    let observedContentSizeCategory: String
    let recordedAt: String
}

@MainActor
final class NativeScreenshotEvidenceTests: XCTestCase {
    private static let evidencePathEnvironmentKey = "SPOONJOY_OBSERVED_ACCESSIBILITY_EVIDENCE_PATH"
    private static let requiredIdentifiersEnvironmentKey = "SPOONJOY_OBSERVED_REQUIRED_IDENTIFIERS"
    private static let peerPairsEnvironmentKey = "SPOONJOY_OBSERVED_PEER_PAIRS"
    private static let thisDeviceIdentifier = "settings.apns.this-device.heading"
    private static let pushDeliveryIdentifier = "settings.apns.push-delivery.heading"
    private static let notificationSyncIdentifier = "settings.apns.notification-sync.heading"
    private static let chromeTypes: Set<String> = [
        "navigationBar", "toolbar", "tabBar", "keyboard", "sheet", "alert"
    ]
    private static let actionableTypes: Set<String> = [
        "button", "switch", "textField", "secureTextField", "link", "slider", "stepper"
    ]
    private static let deepScrollRoutes: Set<String> = [
        "kitchen", "recipe-detail", "recipe-editor", "recipe-covers", "profile",
        "shopping-list", "cookbooks", "cookbook-detail"
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

        let provisionalElements = observedElements(in: app, windowFrame: window.frame)
        let viewport = contentViewport(windowFrame: window.frame, elements: provisionalElements)
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
        let initialScreenshot = XCUIScreen.main.screenshot()
        let initialAuditResult = accessibilityAuditIssues(
            in: app,
            viewport: viewport,
            screenshot: initialScreenshot,
            windowFrame: window.frame,
            hasSystemTabBar: provisionalElements.contains { $0.type == "tabBar" && $0.exists }
        )
        let initialElements = observedElements(
            in: app,
            windowFrame: window.frame,
            hitRegionAuditVerified: initialAuditResult.hitRegionAuditPassed
        )
        let geometryFindings = ScreenshotEvidenceGeometry.validate(
            elements: initialElements,
            requirements: requirements
        )
        let deepScroll = Self.deepScrollRoutes.contains(route)
            ? scrollPrimarySurfaceToTerminal(
                in: app,
                route: route,
                terminalIdentifier: routeTerminalIdentifier(route: route),
                windowFrame: window.frame,
                requiresSystemTabBar: UIDevice.current.userInterfaceIdiom == .phone
                    && environment["SPOONJOY_SCREENSHOT_AUTH"] != "0"
                    && routeUsesSystemTabBar(route)
            )
            : nil
        let auditResult = initialAuditResult
        let allAuditIssues = auditResult.blockingIssues + (deepScroll?.auditIssues ?? [])
        let evidence = ObservedScreenshotEvidence(
            platform: UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "ios",
            route: route,
            viewport: viewport,
            elements: initialElements,
            auditIssues: allAuditIssues,
            geometryFindings: geometryFindings,
            deepScroll: deepScroll,
            operatingSystemVersion: UIDevice.current.systemVersion,
            observedContentSizeCategory: "pending-host-attestation",
            recordedAt: ISO8601DateFormatter().string(from: Date())
        )

        let data = try JSONEncoder.observedEvidence.encode(evidence)
        writeEvidence(data, configuredPath: environment[Self.evidencePathEnvironmentKey])
        attachJSON(data, name: "observed-accessibility-evidence")
        attachScreenshot(initialScreenshot, name: "observed-accessibility-screenshot")

        XCTAssertTrue(
            allAuditIssues.isEmpty,
            "Accessibility audit found: \(allAuditIssues.map(\.compactDescription))"
        )
        XCTAssertTrue(geometryFindings.isEmpty, "Geometry found: \(geometryFindings.map(\.message))")
        if let deepScroll {
            XCTAssertTrue(deepScroll.reachedTerminal, "Primary surface did not reach a stable terminal position")
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

    func testGeometryRejectsClippedOrOffscreenRequiredElement() {
        let element = observedElement(identifier: "required", frame: ObservedRect(x: 0, y: 90, width: 40, height: 20))
        let findings = ScreenshotEvidenceGeometry.validate(
            elements: [element],
            requirements: requirements(required: ["required"], visible: ["required"])
        )
        XCTAssertEqual(findings.map(\.kind), [.outsideViewport])
    }

    func testAuditIgnoresContentPartiallyClippedVerticallyByChrome() {
        let viewport = ObservedRect(x: 0, y: 100, width: 400, height: 600)

        XCTAssertTrue(shouldIgnoreAuditIssue(
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

        XCTAssertEqual(viewport, ObservedRect(x: 0, y: 140, width: 402, height: 503))
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

    func testAuditOnlyIgnoresUnattributedSwiftUIContrastBehindSystemTabBar() {
        XCTAssertTrue(shouldIgnoreUnattributedSystemTabBarContrast(
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

        XCTAssertTrue(required.contains("recipe-covers.generate-placeholder"))
        XCTAssertTrue(required.contains("recipe-covers.archive.cover_primary"))
        XCTAssertFalse(visible.contains("recipe-covers.generate-placeholder"))
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
        XCTAssertFalse(visible.contains("recipe-covers.generate-placeholder"))
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

    private func accessibilityAuditIssues(
        in app: XCUIApplication,
        viewport: ObservedRect,
        screenshot: XCUIScreenshot,
        windowFrame: CGRect,
        hasSystemTabBar: Bool,
        includesDynamicTypeChecks: Bool = true
    ) -> ObservedAuditResult {
        var blockingIssues: [ObservedAuditIssue] = []
        var hitRegionAuditPassed = true
        var auditTypes = XCUIAccessibilityAuditType.contrast
            .union(.hitRegion)
            .union(.trait)
        if includesDynamicTypeChecks,
           ProcessInfo.processInfo.environment["SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY"]?.hasPrefix("accessibility") == true {
            auditTypes.formUnion(.dynamicType)
            auditTypes.formUnion(.textClipped)
        }
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
            hitRegionAuditPassed: hitRegionAuditPassed
        )
    }

    private func shouldIgnoreAuditIssue(
        elementFrame: ObservedRect,
        elementType: String,
        viewport: ObservedRect
    ) -> Bool {
        let tolerance = 0.5
        let isHorizontallyContained = elementFrame.minX >= viewport.minX - tolerance
            && elementFrame.maxX <= viewport.maxX + tolerance
        let isVerticallyClipped = elementFrame.minY < viewport.minY - tolerance
            || elementFrame.maxY > viewport.maxY + tolerance
        return !Self.chromeTypes.contains(elementType)
            && isHorizontallyContained
            && isVerticallyClipped
    }

    private func shouldIgnoreUnattributedSystemTabBarContrast(
        auditType: XCUIAccessibilityAuditType,
        detailedDescription: String,
        elementFrame: ObservedRect?,
        hasSystemTabBar: Bool
    ) -> Bool {
        auditType == .contrast
            && elementFrame == nil
            && hasSystemTabBar
            && detailedDescription == "Contrast failed for SwiftUI.AccessibilityNode"
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
        case "kitchen": ["Ari's kitchen", "Lemon Pantry Pasta", "Recipe Index", "Cookbook Shelf"]
        case "recipes", "saved-recipes": ["Lemon Pantry Pasta"]
        case "recipe-detail": ["Lemon Pantry Pasta", "Start Cooking"]
        case "recipe-editor": ["Recipe", "Title", "Save"]
        case "recipe-covers": ["Photo Studio", "Lemon Pantry Pasta", "Replace Photo", "Photo ready", "Clear", "Save Photo", "Generate Placeholder"]
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
                "recipe-covers.generate-placeholder",
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
            ["recipe-covers.generate-placeholder", "recipe-covers.archive.cover_primary"]
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

    private func routeTerminalIdentifier(route: String) -> String? {
        switch route {
        case "recipe-editor": "recipe-editor.delete"
        case "recipe-covers": "recipe-covers.archive.cover_primary"
        case "profile": "profile.graph.kitchen-visitors"
        default: nil
        }
    }

    private func routeUsesSystemTabBar(_ route: String) -> Bool {
        !["recipe-editor", "recipe-covers", "profile", "profile-graph", "unknown-link"].contains(route)
    }

    private func observedElements(
        in app: XCUIApplication,
        windowFrame: CGRect,
        hitRegionAuditVerified: Bool = false
    ) -> [ObservedAccessibilityElement] {
        let observedTypes: [XCUIElement.ElementType] = [
            .scrollView, .collectionView, .navigationBar, .toolbar, .tabBar, .keyboard, .sheet, .alert,
            .button, .switch, .textField, .secureTextField, .textView, .link, .slider, .stepper,
            .staticText
        ]
        return observedTypes.flatMap { type in
            app.descendants(matching: type).allElementsBoundByIndex.map { element in
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

    private func scrollPrimarySurfaceToTerminal(
        in app: XCUIApplication,
        route: String,
        terminalIdentifier: String?,
        windowFrame: CGRect,
        requiresSystemTabBar: Bool
    ) -> ObservedDeepScrollEvidence {
        let scrollViews = (
            app.scrollViews.allElementsBoundByIndex
                + app.collectionViews.allElementsBoundByIndex
        ).filter(\.exists)
        guard let primarySurface = scrollViews.max(by: { frameArea($0.frame) < frameArea($1.frame) }) else {
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
                auditIssues: []
            )
        }

        let maxScrollActions = 12
        var previousSignature: String?
        var reachedStableTerminal = false
        var scrollActionCount = 0
        while scrollActionCount < maxScrollActions {
            let beforeScrollElements = observedElements(in: app, windowFrame: windowFrame)
            let beforeScrollViewport = contentViewport(windowFrame: windowFrame, elements: beforeScrollElements)
            if namedTerminalIsVisible(
                in: beforeScrollElements,
                terminalIdentifier: terminalIdentifier,
                viewport: beforeScrollViewport
            ) {
                reachedStableTerminal = true
                break
            }
            let namedTerminal = terminalIdentifier.flatMap { identifier in
                beforeScrollElements.first { $0.identifier == identifier && $0.exists }
            }
            if let correction = terminalScrollCorrection(
                terminalFrame: namedTerminal?.frame,
                viewport: beforeScrollViewport
            ) {
                drag(primarySurface, contentOffset: correction)
            } else {
                primarySurface.swipeUp(velocity: .fast)
            }
            scrollActionCount += 1
            let probeElements = observedElements(in: app, windowFrame: windowFrame)
            let probeViewport = contentViewport(windowFrame: windowFrame, elements: probeElements)
            if namedTerminalIsVisible(
                in: probeElements,
                terminalIdentifier: terminalIdentifier,
                viewport: probeViewport
            ) {
                reachedStableTerminal = true
                break
            }
            let signature = terminalScrollSignature(
                elements: probeElements,
                terminalIdentifier: terminalIdentifier,
                viewport: probeViewport
            )
            if terminalIdentifier == nil, let signature, signature == previousSignature {
                reachedStableTerminal = true
                break
            }
            previousSignature = signature
        }

        let elements = observedElements(in: app, windowFrame: windowFrame)
        let tabBar = elements.first { $0.type == "tabBar" && $0.exists }
        let viewport = contentViewport(windowFrame: windowFrame, elements: elements)
        let terminalElement = terminalIdentifier.flatMap { identifier in
            elements.first { $0.identifier == identifier && $0.exists }
        } ?? terminalContentElement(elements: elements, viewport: viewport)
        var findings: [ObservedAccessibilityFinding] = []
        if !reachedStableTerminal {
            findings.append(ObservedAccessibilityFinding(
                kind: .terminalNotReached,
                identifiers: [route],
                message: "Primary surface did not settle after \(maxScrollActions) terminal scroll actions.",
                intersection: nil
            ))
        }
        if let terminalIdentifier, terminalElement?.identifier != terminalIdentifier {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [terminalIdentifier],
                message: "Deep-scroll proof did not reach the route terminal control.",
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

        let deepScreenshot = XCUIScreen.main.screenshot()
        let auditResult = accessibilityAuditIssues(
            in: app,
            viewport: viewport,
            screenshot: deepScreenshot,
            windowFrame: windowFrame,
            hasSystemTabBar: tabBar != nil,
            includesDynamicTypeChecks: false
        )
        let evidence = ObservedDeepScrollEvidence(
            route: route,
            reachedTerminal: reachedStableTerminal && (terminalIdentifier == nil || terminalElement?.identifier == terminalIdentifier),
            swipeCount: scrollActionCount,
            contentViewport: viewport,
            tabBarFrame: tabBar?.frame,
            terminalElement: terminalElement,
            findings: findings,
            auditIssues: auditResult.blockingIssues
        )
        if let data = try? JSONEncoder.observedEvidence.encode(evidence) {
            attachJSON(data, name: "deep-scroll-evidence")
            if let configuredPath = ProcessInfo.processInfo.environment[Self.evidencePathEnvironmentKey] {
                let output = URL(fileURLWithPath: configuredPath)
                    .deletingPathExtension()
                    .appendingPathExtension("deep-scroll.json")
                try? data.write(to: output, options: .atomic)
            }
        }
        attachScreenshot(deepScreenshot, name: "deep-scroll-screenshot")
        return evidence
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
        let endY = min(0.85, max(0.15, 0.5 + contentOffset / surfaceHeight))
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(
            forDuration: 0.05,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 0.05
        )
    }

    private func terminalScrollSignature(
        elements: [ObservedAccessibilityElement],
        terminalIdentifier: String?,
        viewport: ObservedRect
    ) -> String? {
        let terminal = terminalIdentifier.flatMap { identifier in
            elements.first { $0.identifier == identifier && $0.exists }
        } ?? terminalContentElement(elements: elements, viewport: viewport)
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

    private func terminalContentElement(
        elements: [ObservedAccessibilityElement],
        viewport: ObservedRect
    ) -> ObservedAccessibilityElement? {
        let excludedTypes = Self.chromeTypes.union(["application", "window", "scrollView", "collectionView"])
        return elements
            .filter { element in
                element.exists
                    && !excludedTypes.contains(element.type)
                    && (!element.identifier.isEmpty || !element.label.isEmpty)
                    && element.frame.intersection(with: viewport) != nil
                    && element.frame.height <= viewport.height * 1.25
            }
            .max { first, second in
                if first.frame.maxY == second.frame.maxY {
                    return first.frame.minY < second.frame.minY
                }
                return first.frame.maxY < second.frame.maxY
            }
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
        let hasSystemTabBar = elements.contains { $0.type == "tabBar" && $0.exists }
        let bottomClearance = hasSystemTabBar ? 148.0 : 0
        let contentMinY = min(window.maxY, max(window.minY, topChrome + topClearance))
        let contentMaxY = max(contentMinY, min(window.maxY, bottomChrome) - bottomClearance)
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

    private func writeEvidence(_ data: Data, configuredPath: String?) {
        guard let configuredPath, !configuredPath.isEmpty else { return }
        let output = URL(fileURLWithPath: configuredPath)
        try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: output, options: .atomic)
    }

    private func attachJSON(_ data: Data, name: String) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachScreenshot(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension JSONEncoder {
    static var observedEvidence: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
