#if DEBUG
import SwiftUI

/// Screens built to pass or break the layout audit, so its UI tests prove it catches a real overlap, a control run
/// off the screen and really truncated text instead of passing whatever it is shown. `SPOONJOY_LAYOUT_AUDIT_FIXTURE`
/// picks one.
enum LayoutAuditFixture: String {
    case sound
    case overlap
    case clipped
    case pill
    case offscreenControl
    case goneControl

    static let environmentKey = "SPOONJOY_LAYOUT_AUDIT_FIXTURE"

    static var requested: LayoutAuditFixture? {
        ProcessInfo.processInfo.environment[environmentKey].flatMap(LayoutAuditFixture.init(rawValue:))
    }
}

struct LayoutAuditFixtureView: View {
    let fixture: LayoutAuditFixture
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            switch fixture {
            case .sound:
                Text("Lemon pasta")
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("layoutAuditFixture.text")
                Button("Start cooking") {}
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("layoutAuditFixture.first")
                Button("Save") {}
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("layoutAuditFixture.second")
            case .overlap:
                // The labels fill each button, so the buttons' own frames are 180 by 44 and cross by 90 by 24.
                ZStack(alignment: .topLeading) {
                    Button {} label: {
                        Text("Start cooking").frame(width: 180, height: 44)
                    }
                    .accessibilityIdentifier("layoutAuditFixture.first")
                    Button {} label: {
                        Text("Save").frame(width: 180, height: 44)
                    }
                    .accessibilityIdentifier("layoutAuditFixture.second")
                    .padding(.leading, 90)
                    .padding(.top, 20)
                }
            case .clipped:
                // A one-line sentence and one long word, each in a frame too narrow for it, so both draw an ellipsis.
                Text("Simmer the tomatoes until the sauce coats a spoon")
                    .font(.title2)
                    .lineLimit(1)
                    .frame(width: 160, alignment: .leading)
                    .accessibilityIdentifier("layoutAuditFixture.text")
                Text("Worcestershire")
                    .font(.title2)
                    .lineLimit(1)
                    .frame(width: 110, alignment: .leading)
                    .accessibilityIdentifier("layoutAuditFixture.word")
            case .pill:
                // Built like the offline status pill: one line, a mid-size font that may shrink a little, a frame
                // too narrow for it, and an accessibility label that differs from the drawn text.
                Label("Saved copy may be stale", systemImage: "clock.badge.exclamationmark")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 130, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Saved kitchen may be out of date")
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("layoutAuditFixture.pill")
            case .offscreenControl:
                // A button pushed past the screen's trailing edge, outside any scroll view.
                Button {} label: {
                    Text("Start cooking").frame(width: 240, height: 44)
                }
                .offset(x: 260)
                .accessibilityIdentifier("layoutAuditFixture.first")
            case .goneControl:
                // A button pushed wholly past the screen's trailing edge, outside any scroll view, so none of it shows.
                Button {} label: {
                    Text("Start cooking").frame(width: 240, height: 44)
                }
                .offset(x: 1200)
                .accessibilityIdentifier("layoutAuditFixture.first")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("layoutAuditFixture.root")
        .task {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "layout-audit-fixture",
                source: "LayoutAuditFixtureView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
    }
}
#endif
