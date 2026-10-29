import Foundation

/// Judges a screen's layout from the element frames an accessibility snapshot reports. The UI test that took the
/// snapshot does the measuring (frames, and how much room each label needs); this decides what counts as an
/// overlap or as text that does not fit, so the rule is unit-tested apart from the simulator.
public enum LayoutAudit {
    /// Frames are in points and snapshots round them, so edges within half a point count as touching.
    public static let tolerance = 0.5

    public static func audit(_ elements: [LayoutAuditElement], screen: LayoutAuditRect) -> LayoutAuditReport {
        var skippedOffscreen = 0
        var skippedPartiallyScrolled = 0
        var interactive: [(element: LayoutAuditElement, visibleFrame: LayoutAuditRect)] = []
        var texts: [LayoutAuditElement] = []
        var textProblems: [LayoutAuditReport.TextProblem] = []

        for element in elements {
            let visibleArea = element.viewport.flatMap { $0.intersection(screen) } ?? screen
            guard let visibleFrame = element.frame.intersection(visibleArea) else {
                skippedOffscreen += 1
                continue
            }
            switch element.role {
            case .interactive:
                interactive.append((element, visibleFrame))
            case .text:
                let crossesVisibleArea = !visibleArea.contains(element.frame)
                if crossesVisibleArea, element.viewport != nil {
                    // A scroll view cuts the label at its edge; scrolling shows the rest, so it is not clipped.
                    skippedPartiallyScrolled += 1
                    continue
                }
                texts.append(element)
                textProblems += problems(for: element, screen: screen, crossesScreen: crossesVisibleArea)
            }
        }

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
            interactiveCount: interactive.count,
            textCount: texts.count,
            skippedOffscreenCount: skippedOffscreen,
            skippedPartiallyScrolledCount: skippedPartiallyScrolled,
            overlaps: overlaps,
            textProblems: textProblems
        )
    }

    private static func problems(for text: LayoutAuditElement, screen: LayoutAuditRect, crossesScreen: Bool) -> [LayoutAuditReport.TextProblem] {
        var kinds: [LayoutAuditReport.TextProblem.Kind] = []
        if crossesScreen {
            kinds.append(.outsideScreen)
        }
        if let container = text.container, !container.contains(text.frame) {
            kinds.append(.outsideContainer)
        }
        if let wordWidth = text.minimumWordWidth, wordWidth > text.frame.width + tolerance {
            kinds.append(.truncatedWidth)
        }
        if let height = text.minimumHeight, height > text.frame.height + tolerance {
            kinds.append(.truncatedHeight)
        }
        return kinds.map { LayoutAuditReport.TextProblem(kind: $0, text: .init(text)) }
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

    /// The shared area, or nil when the two only touch or miss by no more than the tolerance.
    public func intersection(_ other: LayoutAuditRect) -> LayoutAuditRect? {
        let minX = max(x, other.x)
        let minY = max(y, other.y)
        let maxX = min(x + width, other.x + other.width)
        let maxY = min(y + height, other.y + other.height)
        guard maxX - minX > LayoutAudit.tolerance, maxY - minY > LayoutAudit.tolerance else {
            return nil
        }
        return LayoutAuditRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public func contains(_ other: LayoutAuditRect) -> Bool {
        let slack = LayoutAudit.tolerance
        return other.x >= x - slack
            && other.y >= y - slack
            && other.x + other.width <= x + width + slack
            && other.y + other.height <= y + height + slack
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
    /// The nearest non-scrolling ancestor with a frame, which the element must stay inside.
    public let container: LayoutAuditRect?
    /// Text only: the width of the label's longest word at the smallest size the app could draw it.
    public let minimumWordWidth: Double?
    /// Text only: the height the whole label needs, wrapped to the element's width, at that size.
    public let minimumHeight: Double?

    public init(
        index: Int,
        ancestors: [Int],
        role: Role,
        type: String,
        identifier: String,
        label: String,
        frame: LayoutAuditRect,
        viewport: LayoutAuditRect?,
        container: LayoutAuditRect?,
        minimumWordWidth: Double? = nil,
        minimumHeight: Double? = nil
    ) {
        self.index = index
        self.ancestors = ancestors
        self.role = role
        self.type = type
        self.identifier = identifier
        self.label = label
        self.frame = frame
        self.viewport = viewport
        self.container = container
        self.minimumWordWidth = minimumWordWidth
        self.minimumHeight = minimumHeight
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
            case truncatedWidth
            case truncatedHeight
        }

        public let kind: Kind
        public let text: ElementReference
    }

    public let noOverlap: Bool
    public let textFits: Bool
    public let interactiveCount: Int
    public let textCount: Int
    public let skippedOffscreenCount: Int
    public let skippedPartiallyScrolledCount: Int
    public let overlaps: [Overlap]
    public let textProblems: [TextProblem]
}
