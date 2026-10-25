import SpoonjoyCore
import SwiftUI

extension KitchenSpring {
    /// The SwiftUI spring for this motion token.
    var animation: Animation {
        .spring(response: response, dampingFraction: dampingFraction)
    }
}

extension KitchenMotion {
    /// The spring to animate with, or nil when Reduce Motion is on so the change lands without movement.
    static func animation(_ spring: KitchenSpring, reduceMotion: Bool) -> Animation? {
        KitchenMotion.spring(spring, reduceMotion: reduceMotion)?.animation
    }

    /// The transition for content that enters or leaves. With Reduce Motion it is a plain crossfade.
    static func transition(_ motion: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : motion
    }

    /// The short fade used in place of a spring when Reduce Motion is on.
    static let reducedMotionCrossfade = Animation.easeInOut(duration: 0.2)
}

extension KitchenHapticKind {
    /// The SwiftUI `sensoryFeedback` value for this haptic.
    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .impactLight: .impact(weight: .light)
        case .impactMedium: .impact(weight: .medium)
        case .success: .success
        case .warning: .warning
        }
    }
}

extension KitchenHapticMoment {
    var sensoryFeedback: SensoryFeedback {
        feedback.sensoryFeedback
    }
}

private struct KitchenSpringAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let spring: KitchenSpring
    let value: Value

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? KitchenMotion.reducedMotionCrossfade : spring.animation,
            value: value
        )
    }
}

extension View {
    /// Animates changes to `value` with a Kitchen spring, or with a short crossfade when Reduce Motion is on.
    func kitchenAnimation<Value: Equatable>(_ spring: KitchenSpring, value: Value) -> some View {
        modifier(KitchenSpringAnimationModifier(spring: spring, value: value))
    }

    /// Plays the haptic for a Kitchen moment each time `trigger` changes.
    func kitchenHaptic<Trigger: Equatable>(_ moment: KitchenHapticMoment, trigger: Trigger) -> some View {
        sensoryFeedback(moment.sensoryFeedback, trigger: trigger)
    }
}
