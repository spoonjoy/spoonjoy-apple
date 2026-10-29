import SpoonjoyCore
import UIKit
import XCTest

/// Walks the running app's accessibility snapshot and measures what `LayoutAudit` judges: every control's frame,
/// and every label's frame next to the room its words need.
///
/// Truncation is a lower bound. The snapshot reports a label's full text but not the font it is drawn in, so each
/// label is measured at the smallest size the app could draw it: caption2 for the observed text size, shrunk by the
/// app's smallest `minimumScaleFactor` (0.5). Text that cannot fit at that size is certainly cut; text that would fit
/// only at that size may still be cut and is not flagged.
@MainActor
enum LayoutAuditCollector {
    static let smallestScaleFactor: CGFloat = 0.5
    static let method = "XCUITest snapshot frames. noOverlap: no two visible controls' frames cross, apart from a control inside another. textFits: every visible label lies inside its container and the screen, and its longest word and wrapped height fit its frame at caption2 x 0.5 for the observed text size; labels cut by a scroll view's edge are skipped."

    private static let interactiveTypes: Set<XCUIElement.ElementType> = [
        .button, .link, .switch, .toggle, .slider, .stepper, .textField, .secureTextField, .searchField,
        .segmentedControl, .menuButton, .popUpButton, .picker, .datePicker, .colorWell, .disclosureTriangle,
        .incrementArrow, .decrementArrow
    ]
    private static let scrollingTypes: Set<XCUIElement.ElementType> = [.scrollView, .table, .collectionView, .webView]
    private static let unboundedTypes: Set<XCUIElement.ElementType> = [.application, .window]

    struct Measurement {
        let screen: LayoutAuditRect
        let minimumPointSize: Double
        let elements: [LayoutAuditElement]
        let report: LayoutAuditReport
    }

    static func measure(_ app: XCUIApplication, contentSize: UIContentSizeCategory) throws -> Measurement {
        let root = try app.snapshot()
        let caption = UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: UITraitCollection(preferredContentSizeCategory: contentSize))
        let font = caption.withSize(caption.pointSize * smallestScaleFactor)
        var elements: [LayoutAuditElement] = []
        var nextIndex = 0

        func walk(_ node: XCUIElementSnapshot, ancestors: [Int], viewport: CGRect?, container: CGRect?) {
            let index = nextIndex
            nextIndex += 1
            let type = node.elementType
            let role: LayoutAuditElement.Role? = interactiveTypes.contains(type) ? .interactive : (type == .staticText ? .text : nil)
            if let role, !node.frame.isEmpty {
                let label = node.label
                elements.append(LayoutAuditElement(
                    index: index,
                    ancestors: ancestors,
                    role: role,
                    type: typeName(type),
                    identifier: node.identifier,
                    label: label,
                    frame: rect(node.frame),
                    viewport: viewport.map(rect),
                    container: container.map(rect),
                    minimumWordWidth: role == .text ? longestWordWidth(label, font: font) : nil,
                    minimumHeight: role == .text ? wrappedHeight(label, width: node.frame.width, font: font) : nil
                ))
            }
            let scrolls = scrollingTypes.contains(type)
            let childViewport = scrolls ? node.frame : viewport
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
        let screen = rect(root.frame)
        return Measurement(
            screen: screen,
            minimumPointSize: Double(font.pointSize),
            elements: elements,
            report: LayoutAudit.audit(elements, screen: screen)
        )
    }

    /// `String(describing: DynamicTypeSize)` as the app's accessibility proof records it, as a UIKit category.
    static func contentSize(observed: String) -> UIContentSizeCategory? {
        [
            "xSmall": .extraSmall, "small": .small, "medium": .medium, "large": .large, "xLarge": .extraLarge,
            "xxLarge": .extraExtraLarge, "xxxLarge": .extraExtraExtraLarge,
            "accessibility1": .accessibilityMedium, "accessibility2": .accessibilityLarge,
            "accessibility3": .accessibilityExtraLarge, "accessibility4": .accessibilityExtraExtraLarge,
            "accessibility5": .accessibilityExtraExtraExtraLarge
        ][observed]
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

    private static func longestWordWidth(_ label: String, font: UIFont) -> Double {
        let widths = label.split(whereSeparator: \.isWhitespace).map {
            (String($0) as NSString).size(withAttributes: [.font: font]).width
        }
        return Double(widths.max() ?? 0)
    }

    private static func wrappedHeight(_ label: String, width: CGFloat, font: UIFont) -> Double {
        guard !label.isEmpty else {
            return 0
        }
        let bounds = (label as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        )
        return Double(bounds.height.rounded(.up))
    }
}
