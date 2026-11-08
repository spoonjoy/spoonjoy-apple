import SwiftUI

/// One section header for every section, as web draws them: a brass eyebrow, the title in Fraunces with tracked meta
/// (a count, a hint) at its trailing edge, and a full-width rule under both. When the meta can't sit beside the title,
/// at the larger text sizes, it drops under it rather than squeezing it.
struct KitchenSectionHeader: View {
    let eyebrow: String?
    let title: String
    let meta: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow)
                    .kitchenEyebrow()
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    titleText
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    metaText
                }
                VStack(alignment: .leading, spacing: 4) {
                    titleText
                        .fixedSize(horizontal: false, vertical: true)
                    metaText
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
    }

    @ViewBuilder private var metaText: some View {
        if let meta, !meta.isEmpty {
            Text(meta)
                .kitchenEyebrow(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
