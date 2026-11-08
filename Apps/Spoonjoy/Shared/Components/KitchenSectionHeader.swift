import SwiftUI

/// One section header for every section, as web draws them: a brass eyebrow, the title in Fraunces with tracked meta
/// (a count, a hint) and any section action at its trailing edge, and a full-width rule under them. When they can't
/// share the title's line, at the larger text sizes, the meta and action drop under the title rather than squeezing it.
struct KitchenSectionHeader<Action: View>: View {
    let eyebrow: String?
    let title: String
    let meta: String?
    @ViewBuilder let action: () -> Action

    init(eyebrow: String? = nil, title: String, meta: String? = nil, @ViewBuilder action: @escaping () -> Action) {
        self.eyebrow = eyebrow
        self.title = title
        self.meta = meta
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow)
                    .kitchenEyebrow()
                    .accessibilityHidden(true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    titleText
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    metaText
                    action()
                }
                VStack(alignment: .leading, spacing: 4) {
                    titleText
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        metaText
                        Spacer(minLength: 0)
                        action()
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    titleText
                        .fixedSize(horizontal: false, vertical: true)
                    metaText
                    action()
                }
            }
            Rectangle()
                .fill(KitchenTableTheme.lineStrong)
                // Web's 1 px border-strong rule.
                .frame(maxWidth: .infinity, maxHeight: 1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: some View {
        Text(title)
            .font(KitchenTableTheme.sectionTitle)
            .foregroundStyle(KitchenTableTheme.ink)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(meta ?? "")
    }

    @ViewBuilder private var metaText: some View {
        if let meta, !meta.isEmpty {
            Text(meta)
                .kitchenEyebrow(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                // Read as the title's value.
                .accessibilityHidden(true)
        }
    }
}

extension KitchenSectionHeader where Action == EmptyView {
    init(eyebrow: String? = nil, title: String, meta: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, meta: meta) {
            EmptyView()
        }
    }
}
