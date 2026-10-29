#if DEBUG
import SwiftUI

/// Screens built to pass or break the layout audit, so its UI tests prove it catches a real overlap and real
/// clipped text instead of passing whatever it is shown. `SPOONJOY_LAYOUT_AUDIT_FIXTURE` picks one.
enum LayoutAuditFixture: String {
    case sound
    case overlap
    case clipped

    static let environmentKey = "SPOONJOY_LAYOUT_AUDIT_FIXTURE"

    static var requested: LayoutAuditFixture? {
        ProcessInfo.processInfo.environment[environmentKey].flatMap(LayoutAuditFixture.init(rawValue:))
    }
}

struct LayoutAuditFixtureView: View {
    let fixture: LayoutAuditFixture

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
                // Too short for a sentence, and too narrow for one word, at any size the app draws text.
                Text("Simmer the tomatoes until the sauce coats a spoon and the oil starts to split")
                    .lineLimit(1)
                    .frame(width: 44, height: 8, alignment: .leading)
                    .accessibilityIdentifier("layoutAuditFixture.text")
                Text("Worcestershire")
                    .lineLimit(1)
                    .frame(width: 16, height: 44, alignment: .leading)
                    .accessibilityIdentifier("layoutAuditFixture.word")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("layoutAuditFixture.root")
    }
}
#endif
