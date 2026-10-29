import Foundation

/// Judges a screen's layout from what the UI test measured: the element frames an accessibility snapshot reports,
/// and the lines of text recognized in a screenshot of the same screen. The UI test does the measuring; this decides
/// what counts as an overlap, a clipped control or text that does not fit, so the rules are unit-tested apart from
/// the simulator.
///
/// Scope: controls are compared with controls. Text is not compared with other text or with controls, so text drawn
/// over text or over a button is not caught.
public enum LayoutAudit {
    /// Frames are in points and snapshots round them, so edges within half a point count as touching.
    public static let tolerance = 0.5

    public static func audit(
        _ elements: [LayoutAuditElement],
        drawnText: [LayoutAuditDrawnText] = [],
        screen: LayoutAuditRect
    ) -> LayoutAuditReport {
        var skippedOffscreen = 0
        var skippedPartiallyScrolled = 0
        var interactive: [(element: LayoutAuditElement, visibleFrame: LayoutAuditRect)] = []
        var visibleElements: [(element: LayoutAuditElement, visibleFrame: LayoutAuditRect)] = []
        var texts: [LayoutAuditElement] = []
        var textProblems: [LayoutAuditReport.TextProblem] = []
        var clippedControls: [LayoutAuditReport.ClippedControl] = []

        for element in elements {
            // An element inside a scroll view is visible only where the scroll view and the screen meet; a scroll
            // view entirely off screen hides everything in it.
            let visibleArea: LayoutAuditRect? = if let viewport = element.viewport {
                viewport.intersection(screen)
            } else {
                screen
            }
            guard let visibleArea, let visibleFrame = element.frame.intersection(visibleArea) else {
                skippedOffscreen += 1
                continue
            }
            let crossesVisibleArea = !visibleArea.contains(element.frame)
            switch element.role {
            case .interactive:
                interactive.append((element, visibleFrame))
                visibleElements.append((element, visibleFrame))
                guard crossesVisibleArea else {
                    continue
                }
                if element.viewport != nil, scrollingReveals(element, beyond: visibleArea, among: elements) {
                    skippedPartiallyScrolled += 1
                    continue
                }
                clippedControls.append(.init(
                    control: .init(element),
                    visibleFraction: visibleFrame.area / element.frame.area
                ))
            case .text:
                if crossesVisibleArea, element.viewport != nil {
                    // A scroll view cuts the label at its edge; scrolling shows the rest, so it is not clipped.
                    skippedPartiallyScrolled += 1
                    continue
                }
                texts.append(element)
                visibleElements.append((element, visibleFrame))
                textProblems += geometryProblems(for: element, crossesScreen: crossesVisibleArea)
            }
        }

        textProblems += truncations(in: drawnText, among: visibleElements)

        var overlaps: [LayoutAuditReport.Overlap] = []
        for (offset, first) in interactive.enumerated() {
            for second in interactive[(offset + 1)...] where !first.element.isRelated(to: second.element) {
                if let shared = first.visibleFrame.intersection(second.visibleFrame) {
                    overlaps.append(.init(first: .init(first.element), second: .init(second.element), intersection: shared))
                }
            }
        }

        return LayoutAuditReport(
            noOverlap: overlaps.isEmpty,
            textFits: textProblems.isEmpty,
            controlsOnScreen: clippedControls.isEmpty,
            interactiveCount: interactive.count,
            textCount: texts.count,
            drawnTextCount: drawnText.count,
            skippedOffscreenCount: skippedOffscreen,
            skippedPartiallyScrolledCount: skippedPartiallyScrolled,
            overlaps: overlaps,
            textProblems: textProblems,
            clippedControls: clippedControls
        )
    }

    /// True when a drawn line ends in an ellipsis after real text, which is how a line limit truncates. A bare "..."
    /// is an icon, such as a More button, not cut text.
    public static func isTruncated(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for ellipsis in ["…", "..."] where trimmed.hasSuffix(ellipsis) {
            return trimmed.dropLast(ellipsis.count).contains { $0.isLetter || $0.isNumber }
        }
        return false
    }

    private static func geometryProblems(for text: LayoutAuditElement, crossesScreen: Bool) -> [LayoutAuditReport.TextProblem] {
        var kinds: [LayoutAuditReport.TextProblem.Kind] = []
        if crossesScreen {
            kinds.append(.outsideScreen)
        }
        if let container = text.container, !container.contains(text.frame) {
            kinds.append(.outsideContainer)
        }
        return kinds.map { LayoutAuditReport.TextProblem(kind: $0, text: .init(text)) }
    }

    /// Each truncated line belongs to the smallest visible element whose frame holds the line's center. The audit
    /// reports what was drawn, so a label that differs from its accessibility label is still caught. A line whose
    /// element's own label ends in an ellipsis, such as "Loading…", is not truncated.
    private static func truncations(
        in drawnText: [LayoutAuditDrawnText],
        among visibleElements: [(element: LayoutAuditElement, visibleFrame: LayoutAuditRect)]
    ) -> [LayoutAuditReport.TextProblem] {
        drawnText.filter { isTruncated($0.text) }.compactMap { line in
            let owner = visibleElements
                .filter { $0.visibleFrame.contains(point: line.frame.center) }
                .min { $0.element.frame.area < $1.element.frame.area }?
                .element
            if let owner, isTruncated(owner.label) {
                return nil
            }
            let reference = owner.map(LayoutAuditReport.ElementReference.init) ?? .init(drawnText: line)
            return LayoutAuditReport.TextProblem(kind: .truncated, text: reference, drawnText: line.text)
        }
    }

    /// A control cut by its scroll view's edge is scrolled, not clipped, when other content in the same scroll view
    /// lies past that edge too. With nothing else past the edge, the scroll view does not scroll that way (a pager
    /// clipping a tall control at the screen's bottom), so the control is clipped.
    private static func scrollingReveals(_ control: LayoutAuditElement, beyond visibleArea: LayoutAuditRect, among elements: [LayoutAuditElement]) -> Bool {
        let neighbours = elements.filter {
            $0.index != control.index && $0.viewportIndex == control.viewportIndex && !$0.isRelated(to: control)
        }
        let slack = tolerance
        let frame = control.frame
        let edges: [(crosses: Bool, beyond: (LayoutAuditRect) -> Bool)] = [
            (frame.x < visibleArea.x - slack, { $0.x < visibleArea.x - slack }),
            (frame.maxX > visibleArea.maxX + slack, { $0.maxX > visibleArea.maxX + slack }),
            (frame.y < visibleArea.y - slack, { $0.y < visibleArea.y - slack }),
            (frame.maxY > visibleArea.maxY + slack, { $0.maxY > visibleArea.maxY + slack })
        ]
        return edges.filter(\.crosses).allSatisfy { edge in neighbours.contains { edge.beyond($0.frame) } }
    }
}

public struct LayoutAuditRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var area: Double { width * height }
    var center: (x: Double, y: Double) { (x + width / 2, y + height / 2) }

    /// The shared area, or nil when the two only touch or miss by no more than the tolerance.
    public func intersection(_ other: LayoutAuditRect) -> LayoutAuditRect? {
        let left = max(x, other.x)
        let top = max(y, other.y)
        let right = min(maxX, other.maxX)
        let bottom = min(maxY, other.maxY)
        guard right - left > LayoutAudit.tolerance, bottom - top > LayoutAudit.tolerance else {
            return nil
        }
        return LayoutAuditRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    public func contains(_ other: LayoutAuditRect) -> Bool {
        let slack = LayoutAudit.tolerance
        return other.x >= x - slack
            && other.y >= y - slack
            && other.maxX <= maxX + slack
            && other.maxY <= maxY + slack
    }

    func contains(point: (x: Double, y: Double)) -> Bool {
        point.x >= x && point.x <= maxX && point.y >= y && point.y <= maxY
    }
}

/// A line of text recognized in a screenshot of the audited screen, in screen points.
public struct LayoutAuditDrawnText: Codable, Equatable, Sendable {
    public let text: String
    public let frame: LayoutAuditRect

    public init(text: String, frame: LayoutAuditRect) {
        self.text = text
        self.frame = frame
    }
}

public struct LayoutAuditElement: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case interactive
        case text
    }

    /// The element's position in the snapshot walk, so ancestors can name it.
    public let index: Int
    public let ancestors: [Int]
    public let role: Role
    public let type: String
    public let identifier: String
    public let label: String
    public let frame: LayoutAuditRect
    /// The nearest scrolling ancestor's frame; nil when nothing between the element and the window scrolls.
    public let viewport: LayoutAuditRect?
    /// The nearest scrolling ancestor's snapshot index, so elements in the same scroll view can be compared.
    public let viewportIndex: Int?
    /// The nearest non-scrolling ancestor with a frame, which the element must stay inside.
    public let container: LayoutAuditRect?

    public init(
        index: Int,
        ancestors: [Int],
        role: Role,
        type: String,
        identifier: String,
        label: String,
        frame: LayoutAuditRect,
        viewport: LayoutAuditRect?,
        viewportIndex: Int? = nil,
        container: LayoutAuditRect?
    ) {
        self.index = index
        self.ancestors = ancestors
        self.role = role
        self.type = type
        self.identifier = identifier
        self.label = label
        self.frame = frame
        self.viewport = viewport
        self.viewportIndex = viewportIndex
        self.container = container
    }

    /// A control inside another control (a menu inside a row button) shares its parent's frame by design.
    func isRelated(to other: LayoutAuditElement) -> Bool {
        ancestors.contains(other.index) || other.ancestors.contains(index)
    }
}

public struct LayoutAuditReport: Codable, Equatable, Sendable {
    public struct ElementReference: Codable, Equatable, Sendable {
        public let type: String
        public let identifier: String
        public let label: String
        public let frame: LayoutAuditRect

        init(_ element: LayoutAuditElement) {
            type = element.type
            identifier = element.identifier
            label = element.label
            frame = element.frame
        }

        /// A truncated line that no audited element holds.
        init(drawnText: LayoutAuditDrawnText) {
            type = "drawnText"
            identifier = ""
            label = drawnText.text
            frame = drawnText.frame
        }
    }

    public struct Overlap: Codable, Equatable, Sendable {
        public let first: ElementReference
        public let second: ElementReference
        public let intersection: LayoutAuditRect
    }

    public struct TextProblem: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case outsideScreen
            case outsideContainer
            case truncated
        }

        public let kind: Kind
        public let text: ElementReference
        /// For `truncated`: the line as drawn, ellipsis included.
        public let drawnText: String?

        init(kind: Kind, text: ElementReference, drawnText: String? = nil) {
            self.kind = kind
            self.text = text
            self.drawnText = drawnText
        }
    }

    public struct ClippedControl: Codable, Equatable, Sendable {
        public let control: ElementReference
        /// The share of the control's frame left on screen, from 0 to 1.
        public let visibleFraction: Double
    }

    public let noOverlap: Bool
    public let textFits: Bool
    public let controlsOnScreen: Bool
    public let interactiveCount: Int
    public let textCount: Int
    public let drawnTextCount: Int
    public let skippedOffscreenCount: Int
    public let skippedPartiallyScrolledCount: Int
    public let overlaps: [Overlap]
    public let textProblems: [TextProblem]
    public let clippedControls: [ClippedControl]
}
