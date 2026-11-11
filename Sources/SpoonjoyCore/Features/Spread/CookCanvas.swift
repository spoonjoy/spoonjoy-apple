import Foundation

/// How a cook-mode page uses the room it is given. Every iPhone page, the open iPhone Duo's included in every posture,
/// and every Mac window keep the reference canvas and the type they were designed with. An iPad's bigger page sets
/// the step larger so it reads from across the kitchen, and a page wide enough puts the step's checklist beside the
/// step instead of under it, so the page is used top to bottom rather than holding a small step at the top and its
/// checks at the foot.
public struct CookCanvas: Equatable, Sendable {
    /// The page every type size was designed for: about a phone's, or one page of the open Duo.
    public static let referenceWidth: Double = 480
    public static let referenceHeight: Double = 700
    /// The most the step's type grows. Past this the step's lines get too short to read comfortably.
    public static let maximumScale: Double = 1.5
    /// The narrowest page that sets the checklist beside the step: wide enough for a step column of about 390 pt beside
    /// the checklist. The 12.9" and 13" iPads upright and wide windows qualify; the iPad mini and the 11" iPad upright (about
    /// 712 and 802 pt) keep one column, with the step set larger. The page must also be at least the
    /// reference height.
    public static let minimumSideBySideWidth: Double = 820
    /// The checklist column beside the step: about a third of the page, between these widths.
    public static let checklistWidthRange: ClosedRange<Double> = 300...380
    /// How many Dynamic Type steps the checklist and timer go up at the largest scale, so they keep in proportion
    /// with the step.
    public static let maximumTypeSteps = 3

    /// The reference canvas: nothing grows and the checklist stays under the step.
    public static let reference = CookCanvas(scale: 1, setsChecklistBesideStep: false)

    /// How much larger than the reference the step's type is set, from 1 to `maximumScale`.
    public let scale: Double
    /// True when the step and its checklist sit side by side.
    public let setsChecklistBesideStep: Bool

    public init(scale: Double, setsChecklistBesideStep: Bool) {
        self.scale = scale
        self.setsChecklistBesideStep = setsChecklistBesideStep
    }

    /// The canvas for a page of the given size. The scale follows whichever side has less room to spare, so the step
    /// grows only as far as both the width and the height allow. At accessibility text sizes the person's own size
    /// already makes the step large, so the page keeps the reference layout and lets their setting decide. Only an
    /// iPad's page grows (`isPad`): an iPhone's never does, so the open Duo held upright, whose single page is about as
    /// big as an iPad mini's spread page, keeps exactly the layout it was designed with.
    public static func page(
        width: Double,
        height: Double,
        isPad: Bool,
        isAccessibilityTextSize: Bool = false
    ) -> CookCanvas {
        guard isPad, !isAccessibilityTextSize, width > 0, height > 0 else {
            return .reference
        }
        let room = min(width / referenceWidth, height / referenceHeight)
        let scale = min(max(room, 1), maximumScale)
        // A phone held sideways is wide but short: it keeps the checklist under the step, as on every other phone.
        return CookCanvas(scale: scale, setsChecklistBesideStep: width >= minimumSideBySideWidth && height >= referenceHeight)
    }

    /// How many Dynamic Type steps the page's checklist and timer go up: none on the reference canvas, up to
    /// `maximumTypeSteps` at the largest scale.
    public var typeSteps: Int {
        Int((growth * Double(Self.maximumTypeSteps)).rounded())
    }

    /// True on any page bigger than the reference.
    public var isLarge: Bool {
        scale > 1
    }

    /// How far the page has grown, from 0 on the reference canvas to 1 at `maximumScale`.
    public var growth: Double {
        (scale - 1) / (Self.maximumScale - 1)
    }

    /// `reference` on the reference canvas, `large` at the largest scale, and in proportion between: a margin or a gap
    /// that opens with the page rather than jumping the moment it grows.
    public func interpolate(_ reference: Double, _ large: Double) -> Double {
        reference + (large - reference) * growth
    }

    /// The checklist column's width beside the step on a page `width` wide.
    public static func checklistWidth(pageWidth width: Double) -> Double {
        min(max(width * 0.36, checklistWidthRange.lowerBound), checklistWidthRange.upperBound)
    }
}
