import SwiftUI

struct KitchenTableLoadingStateView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let title: String
    let subtitle: String?
    let systemImage: String?

    init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
                    .accessibilityHidden(true)
            }

            ProgressView()
                .controlSize(.large)

            VStack(spacing: 5) {
                Text(title)
                    .font(KitchenTableTheme.sectionTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                if let subtitle {
                    Text(subtitle)
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(32)
        .background(KitchenTableTheme.bone)
        .transition(accessibilityReduceMotion ? .identity : .opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .task(id: readinessID) {
            await ScreenshotVisualReadiness.beginBlockingIndicator(readinessID)
            do {
                try await Task.sleep(nanoseconds: .max)
            } catch {
                // View disappearance cancels the task and releases the readiness blocker.
            }
            await ScreenshotVisualReadiness.endBlockingIndicator(readinessID)
        }
    }

    private var readinessID: String {
        "route-loading:\(title)"
    }
}

struct KitchenTableRouteErrorView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let message: String
    let systemImage: String

    init(message: String, systemImage: String) {
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(message)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(KitchenTableTheme.brass)
        }
        .padding(KitchenTableTheme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
        .transition(accessibilityReduceMotion ? .identity : .opacity)
        .accessibilityElement(children: .combine)
    }
}
