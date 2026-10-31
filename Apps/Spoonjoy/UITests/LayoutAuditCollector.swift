import SpoonjoyCore
import UIKit
import Vision
import XCTest

/// Measures what `LayoutAudit` judges: every control's and label's frame from the running app's accessibility
/// snapshot, and every line of text actually drawn, read from a screenshot taken right after the snapshot. The two
/// are sequential, so a screen still animating can differ between them.
///
/// Truncation is read from the pixels, not inferred from a font: a line drawn with a trailing ellipsis is cut. This
/// catches what a line limit truncates, whatever the label's accessibility text says. It does not catch text clipped
/// without an ellipsis; a label overflowing its container or the screen is caught from its frame instead.
@MainActor
enum LayoutAuditCollector {
    static let method = "XCUITest snapshot frames and Vision text recognition of a screenshot taken right after the snapshot, not at the same instant. noOverlap: no two visible controls' frames cross, apart from a control inside another, two of the dock's tab items (identifiers dock.*), which UIKit lays out, sharing at most \(Int(LayoutAudit.dockNeighbourOverlapLimit)) pt, and a control in a scroll view that runs at most \(Int(LayoutAudit.dockUnderlapLimit)) pt under the floating dock, or any depth while it runs off the scroll view's edge and the dock sits within \(Int(LayoutAudit.dockUnderlapLimit)) pt of that edge. controlsOnScreen: no control runs off the screen, or off a scroll view's edge where nothing else in that scroll view starts at or past that edge and no dock item in that scroll view sits within \(Int(LayoutAudit.dockUnderlapLimit)) pt of that edge; a control wholly off screen outside any scroll view is clipped. textFits: every visible label lies inside its container and the screen, and no drawn line ends in an ellipsis unless the label of the element holding it does (so such a label can hide a real truncation). Labels cut by a scroll view's edge are skipped. Text is not compared with other text or with controls."

    private static let interactiveTypes: Set<XCUIElement.ElementType> = [
        .button, .link, .switch, .toggle, .slider, .stepper, .textField, .secureTextField, .searchField,
        .segmentedControl, .menuButton, .popUpButton, .picker, .datePicker, .colorWell, .disclosureTriangle,
        .incrementArrow, .decrementArrow
    ]
    /// The dock's tab items carry `dock.<tab>` identifiers (`DockAccessibilityIdentifiers`).
    private static let dockIdentifierPrefix = "dock."
    private static let scrollingTypes: Set<XCUIElement.ElementType> = [.scrollView, .table, .collectionView, .webView]
    private static let unboundedTypes: Set<XCUIElement.ElementType> = [.application, .window]

    struct Measurement {
        let screen: LayoutAuditRect
        let screenshot: XCUIScreenshot
        let elements: [LayoutAuditElement]
        let drawnText: [LayoutAuditDrawnText]
        let report: LayoutAuditReport
    }

    static func measure(_ app: XCUIApplication) throws -> Measurement {
        let root = try app.snapshot()
        var elements: [LayoutAuditElement] = []
        var nextIndex = 0

        func walk(_ node: XCUIElementSnapshot, ancestors: [Int], viewport: (frame: CGRect, index: Int)?, container: CGRect?) {
            let index = nextIndex
            nextIndex += 1
            let type = node.elementType
            let role: LayoutAuditElement.Role? = interactiveTypes.contains(type) ? .interactive : (type == .staticText ? .text : nil)
            if let role, !node.frame.isEmpty {
                elements.append(LayoutAuditElement(
                    index: index,
                    ancestors: ancestors,
                    role: role,
                    type: typeName(type),
                    identifier: node.identifier,
                    label: node.label,
                    frame: rect(node.frame),
                    viewport: viewport.map { rect($0.frame) },
                    viewportIndex: viewport?.index,
                    container: container.map(rect),
                    isDockItem: role == .interactive && node.identifier.hasPrefix(dockIdentifierPrefix)
                ))
            }
            let scrolls = scrollingTypes.contains(type)
            let childViewport = scrolls ? (node.frame, index) : viewport
            let childContainer: CGRect? = if scrolls {
                nil
            } else if unboundedTypes.contains(type) || node.frame.isEmpty {
                container
            } else {
                node.frame
            }
            for child in node.children {
                walk(child, ancestors: ancestors + [index], viewport: childViewport, container: childContainer)
            }
        }

        walk(root, ancestors: [], viewport: nil, container: nil)
        let screenFrame = appScreenFrame(root)
        let screenshot = screenshot(matching: screenFrame.size)
        let screen = rect(screenFrame)
        let drawnText = try recognizeText(in: screenshot, screen: screenFrame)
        return Measurement(
            screen: screen,
            screenshot: screenshot,
            elements: elements,
            drawnText: drawnText,
            report: LayoutAudit.audit(elements, drawnText: drawnText, screen: screen)
        )
    }

    /// The app's largest window. On the Duo open wide the application element keeps the inner screen's portrait size
    /// while its window and every element in it are laid out wide, so the window is the screen the app draws on.
    private static func appScreenFrame(_ root: XCUIElementSnapshot) -> CGRect {
        let windows = root.children.filter { $0.elementType == .window && !$0.frame.isEmpty }
        return windows.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }?.frame ?? root.frame
    }

    /// The screenshot of the display the app is on. The Duo has two, and `XCUIScreen.main` is the cover screen even
    /// when the app is on the inner one.
    private static func screenshot(matching size: CGSize) -> XCUIScreenshot {
        for screen in XCUIScreen.screens {
            let shot = screen.screenshot()
            if abs(shot.image.size.width - size.width) <= 1, abs(shot.image.size.height - size.height) <= 1 {
                return shot
            }
        }
        return XCUIScreen.main.screenshot()
    }

    /// Reads every line of text in the screenshot, in screen points. Language correction stays off so an ellipsis is
    /// read as drawn instead of being corrected away.
    private static func recognizeText(in screenshot: XCUIScreenshot, screen: CGRect) throws -> [LayoutAuditDrawnText] {
        let image = try XCTUnwrap(screenshot.image.cgImage, "The screenshot has no bitmap.")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        // A rotated screen's bitmap is stored unrotated; Vision reads it upright and normalizes to the upright image.
        try VNImageRequestHandler(cgImage: image, orientation: visionOrientation(screenshot.image.imageOrientation)).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }
            // Vision's box is normalized with its origin at the bottom left.
            let box = observation.boundingBox
            return LayoutAuditDrawnText(
                text: candidate.string,
                frame: LayoutAuditRect(
                    x: Double(screen.minX + box.minX * screen.width),
                    y: Double(screen.minY + (1 - box.maxY) * screen.height),
                    width: Double(box.width * screen.width),
                    height: Double(box.height * screen.height)
                )
            )
        }
    }

    private static func visionOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }

    private static func typeName(_ type: XCUIElement.ElementType) -> String {
        let names: [XCUIElement.ElementType: String] = [
            .button: "button", .link: "link", .switch: "switch", .toggle: "toggle", .slider: "slider",
            .stepper: "stepper", .textField: "textField", .secureTextField: "secureTextField",
            .searchField: "searchField", .segmentedControl: "segmentedControl", .menuButton: "menuButton",
            .popUpButton: "popUpButton", .picker: "picker", .datePicker: "datePicker", .staticText: "staticText"
        ]
        return names[type] ?? "type\(type.rawValue)"
    }

    private static func rect(_ frame: CGRect) -> LayoutAuditRect {
        LayoutAuditRect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
    }
}
