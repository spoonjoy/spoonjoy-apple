import Foundation

/// A step control cook mode shows outside the swipe.
public enum CookModeControl: String, Equatable, Sendable, CaseIterable {
    case back, close, markDone, next, finish
}

/// Which controls cook mode puts where on a foldable, so nothing sits on the fold and nothing leaves its page.
public enum CookModeControlPlan {
    /// On the last step Finish cooking takes Next's place, so there is never a Next with nowhere to go.
    public static func forward(isLastStep: Bool) -> CookModeControl {
        isLastStep ? .finish : .next
    }

    /// The open-flat spread: Back and Close at the outer corner of the left page, Mark done and Next (or Finish
    /// cooking) at the outer corner of the right page, like turning a page.
    public static func spread(isLastStep: Bool) -> (leadingPage: [CookModeControl], trailingPage: [CookModeControl]) {
        ([.back, .close], [.markDone, forward(isLastStep: isLastStep)])
    }

    /// The tabletop's half on the counter. At accessibility text sizes the dock would cut its labels short, so the
    /// controls stack whole, one to a row: Next (or Finish cooking), Mark done, Back. Otherwise the dock carries
    /// Back, Mark done and Next, and the last step adds Finish cooking under the checklist.
    public static func tabletop(isLastStep: Bool, accessibilityText: Bool) -> (stacked: [CookModeControl], usesDock: Bool) {
        if accessibilityText {
            return ([forward(isLastStep: isLastStep), .markDone, .back], false)
        }
        return (isLastStep ? [.finish] : [], true)
    }
}
