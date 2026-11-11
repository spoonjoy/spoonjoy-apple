import Foundation

/// How a cook-mode page uses the room it is given. A phone page, and a page of the open iPhone Duo, is the reference
/// canvas and keeps the type it was designed with. A bigger page, an iPad's, sets the step larger so it reads from
/// across the kitchen, and a page wide enough puts the step's checklist beside the step instead of under it, so the
/// page is used top to bottom rather than holding a small step at the top and its checks at the foot.
public struct CookCanvas: Equatable, Sendable {
    /// The page every type size was designed for: about a phone's, or one page of the open Duo.
    public static let referenceWidth: Double = 480
    public static let referenceHeight: Double = 700
    /// The most the step's type grows. Past this the step's lines get too short to read comfortably.
    public static let maximumScale: Double = 1.5
    /// The narrowest page that sets the checklist beside the step: two columns of a comfortable reading width. The page
    /// must also be at least the reference height.
    public static let minimumSideBySideWidth: Double = 700
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
    /// already makes the step large, so the page keeps the reference layout and lets their setting decide.
    public static func page(width: Double, height: Double, isAccessibilityTextSize: Bool = false) -> CookCanvas {
        guard !isAccessibilityTextSize, width > 0, height > 0 else {
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
        let share = (scale - 1) / (Self.maximumScale - 1)
        return Int((share * Double(Self.maximumTypeSteps)).rounded())
    }

    /// True on any page bigger than the reference.
    public var isLarge: Bool {
        scale > 1
    }
}
