import CoreGraphics
import Foundation

struct ObservedRect: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        self.init(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.size.width),
            height: Double(rect.size.height)
        )
    }

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var isEmpty: Bool { width <= 0 || height <= 0 }
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    func contains(_ other: ObservedRect, tolerance: Double = 0.5) -> Bool {
        !other.isEmpty
            && other.minX >= minX - tolerance
            && other.minY >= minY - tolerance
            && other.maxX <= maxX + tolerance
            && other.maxY <= maxY + tolerance
    }

    func intersection(with other: ObservedRect) -> ObservedRect? {
        let intersectionMinX = max(minX, other.minX)
        let intersectionMinY = max(minY, other.minY)
        let intersectionMaxX = min(maxX, other.maxX)
        let intersectionMaxY = min(maxY, other.maxY)
        guard intersectionMaxX > intersectionMinX, intersectionMaxY > intersectionMinY else {
            return nil
        }
        return ObservedRect(
            x: intersectionMinX,
            y: intersectionMinY,
            width: intersectionMaxX - intersectionMinX,
            height: intersectionMaxY - intersectionMinY
        )
    }
}

struct ObservedAccessibilityElement: Codable, Equatable, Sendable {
    let identifier: String
    let label: String
    let type: String
    let frame: ObservedRect
    let exists: Bool
    let hittable: Bool
    let enabled: Bool
    let focused: Bool?
}

enum ObservedAccessibilityFindingKind: String, Codable, Sendable {
    case requiredIdentifierMissing
    case outsideViewport
    case peerOverlap
    case textOverlap
    case actionTargetTooSmall
    case apnsChromeIntersection
    case terminalNotReached
    case terminalElementOccludedByTabBar
}

struct ObservedAccessibilityFinding: Codable, Equatable, Sendable {
    let kind: ObservedAccessibilityFindingKind
    let identifiers: [String]
    let message: String
    let intersection: ObservedRect?
}

struct ObservedGeometryRequirements: Sendable {
    let viewport: ObservedRect
    let requiredIdentifiers: Set<String>
    let requiredVisibleIdentifiers: Set<String>
    let requiredLabels: Set<String>
    let peerPairs: [(String, String)]
    let chromeTypes: Set<String>
    let actionableTypes: Set<String>
    let minimumActionTarget: Double
    let apnsThisDeviceIdentifier: String?
    let apnsPushDeliveryIdentifier: String?
}

enum ScreenshotEvidenceGeometry {
    static func validate(
        elements: [ObservedAccessibilityElement],
        requirements: ObservedGeometryRequirements
    ) -> [ObservedAccessibilityFinding] {
        var findings: [ObservedAccessibilityFinding] = []
        let existingElements = elements.filter(\.exists)
        let elementsByIdentifier = Dictionary(
            grouping: existingElements.filter { !$0.identifier.isEmpty },
            by: \.identifier
        )
        let elementsByLabel = Dictionary(
            grouping: existingElements.filter { !$0.label.isEmpty },
            by: \.label
        )

        for identifier in requirements.requiredIdentifiers.sorted() where elementsByIdentifier[identifier]?.isEmpty != false {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: [identifier],
                message: "Required accessibility identifier \(identifier) was not observed.",
                intersection: nil
            ))
        }

        for label in requirements.requiredLabels.sorted() where elementsByLabel[label]?.isEmpty != false {
            findings.append(ObservedAccessibilityFinding(
                kind: .requiredIdentifierMissing,
                identifiers: ["label:\(label)"],
                message: "Required accessibility label \(label) was not observed.",
                intersection: nil
            ))
        }

        for identifier in requirements.requiredVisibleIdentifiers.sorted() {
            guard let element = elementsByIdentifier[identifier]?.first else {
                continue
            }
            guard requirements.viewport.contains(element.frame) else {
                findings.append(ObservedAccessibilityFinding(
                    kind: .outsideViewport,
                    identifiers: [identifier],
                    message: "Required element \(identifier) is clipped or outside the content viewport.",
                    intersection: element.frame.intersection(with: requirements.viewport)
                ))
                continue
            }
        }

        for element in existingElements where element.hittable
            && element.enabled
            && requirements.actionableTypes.contains(element.type)
            && element.frame.intersection(with: requirements.viewport) != nil
            && !isNativeSystemStepperTarget(element, in: existingElements) {
            guard element.frame.width + 0.5 < requirements.minimumActionTarget
                    || element.frame.height + 0.5 < requirements.minimumActionTarget else {
                continue
            }
            findings.append(ObservedAccessibilityFinding(
                kind: .actionTargetTooSmall,
                identifiers: [element.identifier],
                message: "Action target \(element.identifier.isEmpty ? element.label : element.identifier) is smaller than \(requirements.minimumActionTarget) points.",
                intersection: nil
            ))
        }

        for (firstIdentifier, secondIdentifier) in requirements.peerPairs {
            guard let first = elementsByIdentifier[firstIdentifier]?.first,
                  let second = elementsByIdentifier[secondIdentifier]?.first,
                  let overlap = first.frame.intersection(with: second.frame) else {
                continue
            }
            findings.append(ObservedAccessibilityFinding(
                kind: .peerOverlap,
                identifiers: [firstIdentifier, secondIdentifier],
                message: "Peer elements \(firstIdentifier) and \(secondIdentifier) overlap.",
                intersection: overlap
            ))
        }


        let visibleTexts = existingElements.filter {
            $0.type == "staticText"
                && !$0.label.isEmpty
                && $0.frame.intersection(with: requirements.viewport) != nil
        }
        for firstIndex in visibleTexts.indices {
            for secondIndex in visibleTexts.indices where secondIndex > firstIndex {
                let first = visibleTexts[firstIndex]
                let second = visibleTexts[secondIndex]
                guard first.label != second.label,
                      let overlap = first.frame.intersection(with: second.frame),
                      overlap.width * overlap.height > 1 else {
                    continue
                }
                findings.append(ObservedAccessibilityFinding(
                    kind: .textOverlap,
                    identifiers: [first.label, second.label],
                    message: "Visible text \(first.label) overlaps \(second.label).",
                    intersection: overlap
                ))
            }
        }

        if let thisDeviceIdentifier = requirements.apnsThisDeviceIdentifier,
           let thisDevice = elementsByIdentifier[thisDeviceIdentifier]?.first {
            let chrome = existingElements.filter { requirements.chromeTypes.contains($0.type) }
            for chromeElement in chrome {
                guard let overlap = thisDevice.frame.intersection(with: chromeElement.frame) else {
                    continue
                }
                findings.append(ObservedAccessibilityFinding(
                    kind: .apnsChromeIntersection,
                    identifiers: [thisDeviceIdentifier, chromeElement.identifier],
                    message: "This Device heading intersects \(chromeElement.type) chrome.",
                    intersection: overlap
                ))
            }
        }

        if let pushDeliveryIdentifier = requirements.apnsPushDeliveryIdentifier,
           let pushDelivery = elementsByIdentifier[pushDeliveryIdentifier]?.first,
           !requirements.viewport.contains(pushDelivery.frame) {
            findings.append(ObservedAccessibilityFinding(
                kind: .outsideViewport,
                identifiers: [pushDeliveryIdentifier],
                message: "Push Delivery heading is not fully visible in the content viewport.",
                intersection: pushDelivery.frame.intersection(with: requirements.viewport)
            ))
        }

        return findings
    }

    private static func isNativeSystemStepperTarget(
        _ candidate: ObservedAccessibilityElement,
        in elements: [ObservedAccessibilityElement]
    ) -> Bool {
        let stepperIdentifiers = ["Decrement", "Increment"]
        guard candidate.type == "stepper"
                || (candidate.type == "button" && stepperIdentifiers.contains(candidate.identifier)) else {
            return false
        }

        return elements.contains { stepper in
            guard stepper.type == "stepper", !stepper.label.isEmpty else {
                return false
            }
            let controls = stepperIdentifiers.compactMap { identifier in
                elements.first { element in
                    element.type == "button"
                        && element.identifier == identifier
                        && element.label == "\(stepper.label), \(identifier)"
                        && stepper.frame.contains(element.frame)
                }
            }
            guard controls.count == stepperIdentifiers.count else {
                return false
            }
            return candidate == stepper || controls.contains(candidate)
        }
    }

    static func validateTerminalElement(
        _ terminalElement: ObservedAccessibilityElement,
        contentViewport: ObservedRect,
        tabBarFrame: ObservedRect?
    ) -> [ObservedAccessibilityFinding] {
        var findings: [ObservedAccessibilityFinding] = []
        let terminalName = terminalElement.identifier.isEmpty ? terminalElement.label : terminalElement.identifier

        if !contentViewport.contains(terminalElement.frame) {
            findings.append(ObservedAccessibilityFinding(
                kind: .outsideViewport,
                identifiers: [terminalName],
                message: "Terminal element is clipped or outside the content viewport after deep scroll.",
                intersection: terminalElement.frame.intersection(with: contentViewport)
            ))
        }

        if let tabBarFrame,
           terminalElement.frame.intersection(with: tabBarFrame) != nil || terminalElement.frame.maxY > tabBarFrame.minY + 0.5 {
            findings.append(ObservedAccessibilityFinding(
                kind: .terminalElementOccludedByTabBar,
                identifiers: [terminalName],
                message: "Terminal element is not fully above the tab bar after deep scroll.",
                intersection: terminalElement.frame.intersection(with: tabBarFrame)
            ))
        }

        return findings
    }
}
