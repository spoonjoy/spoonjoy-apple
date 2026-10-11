import SpoonjoyCore
import SwiftUI

extension View {
    /// Under the journeys' `-UITestDisableAnimations` launch argument, stops everything that keeps the app
    /// from going idle for XCUITest: SwiftUI transitions and implicit animations, and spinners, which spin
    /// until the work they show ends. DEBUG builds only, so release builds always animate.
    @ViewBuilder
    func journeyQuietMode() -> some View {
        #if DEBUG
        if NativeJourneyAnimations.isRequested(arguments: ProcessInfo.processInfo.arguments) {
            self
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
                .progressViewStyle(JourneyStillProgressViewStyle())
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if DEBUG
/// A progress view that does not move: dots for an unknown amount of work, a plain bar for a known one.
struct JourneyStillProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            if let fraction = configuration.fractionCompleted {
                GeometryReader { proxy in
                    Capsule()
                        .fill(KitchenTableTheme.brass)
                        .frame(width: proxy.size.width * fraction)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 4)
            } else {
                Image(systemName: "ellipsis")
                    .foregroundStyle(KitchenTableTheme.brass)
            }
            configuration.label
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
