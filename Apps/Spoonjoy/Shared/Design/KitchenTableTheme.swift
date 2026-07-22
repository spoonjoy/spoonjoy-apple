import SwiftUI

enum KitchenTableTheme {
    static let bone = webColor(0xFBFAF4) // --sj-bone
    static let paper = webColor(0xFFFEFA) // --sj-bone-lift / --sj-panel-solid
    static let vellum = webColor(0xE8E9DF) // --sj-vellum / --sj-flour
    static let charcoal = webColor(0x28231D) // --sj-charcoal / --sj-action
    static let inkMuted = webColor(0x635D54) // --sj-charcoal-soft / --sj-ink-soft
    static let line = charcoal.opacity(0.18) // --sj-border
    static let lineStrong = charcoal.opacity(0.32) // --sj-border-strong
    static let brass = webColor(0x9B6834) // --sj-brass
    static let action = webColor(0x28231D) // --sj-action
    static let actionDeep = webColor(0x1F1B17) // --sj-action-deep
    static let tomato = webColor(0xA24A38) // --sj-tomato
    static let herb = webColor(0x596A4F) // --sj-herb
    static let onPhoto = bone // --sj-on-photo
    static let onPhotoMuted = bone.opacity(0.76) // --sj-on-photo-muted
    static let photoCharcoal = webColor(0x211F1B) // --sj-photo-charcoal
    static let photoOverlay = Color.black.opacity(0.62)

    enum Radius {
        static let edge: CGFloat = 0
        static let media: CGFloat = 4
        static let panel: CGFloat = 8
        static let control: CGFloat = 999
    }

    static let pagePadding: CGFloat = 20
    static let pageSpacing: CGFloat = 24
    static let sectionSpacing: CGFloat = 12
    static let minimumTouchTarget: CGFloat = 44
    static let pageBottomSpacing: CGFloat = 32
    static let compactTabBarContentInset: CGFloat = 148

    static let displayTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let sectionTitle = Font.system(.title2, design: .serif).weight(.bold)
    static let objectTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let bodyNote = Font.body
    static let uiLabel = Font.caption.weight(.semibold)
    static let headerMeta = Font.caption2.weight(.semibold)

    private static func webColor(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

struct KitchenTablePage<Content: View>: View {
    let maxContentWidth: CGFloat
    let bottomReserve: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        maxContentWidth: CGFloat = 720,
        bottomReserve: CGFloat = KitchenTableTheme.pageBottomSpacing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxContentWidth = maxContentWidth
        self.bottomReserve = bottomReserve
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
                content()
            }
            .padding(.horizontal, KitchenTableTheme.pagePadding)
            .padding(.top, 20)
            .padding(.bottom, bottomReserve)
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        .accessibilityIdentifier("spoonjoy.page-scroll")
        .background(KitchenTableTheme.bone.ignoresSafeArea())
    }
}

struct KitchenTableHeader<Trailing: View>: View {
    @Environment(\.spoonjoyCompactNavigation) private var usesCompactNavigation

    let eyebrow: String
    let title: String
    let subtitle: String?
    let hidesTitleInCompactNavigation: Bool
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        hidesTitleInCompactNavigation: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.hidesTitleInCompactNavigation = hidesTitleInCompactNavigation
        self.trailing = trailing
    }

    var body: some View {
        KitchenTableHeaderLayout() {
            titleStack
            trailing()
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(KitchenTableTheme.brass)
                .accessibilityHidden(true)
                .fixedSize(horizontal: false, vertical: true)
            if !usesCompactNavigation || !hidesTitleInCompactNavigation {
                Text(title)
                    .font(KitchenTableTheme.displayTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(KitchenTableTheme.headerMeta)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KitchenTableHeaderLayout: Layout {
    private let horizontalSpacing: CGFloat = 16
    private let verticalSpacing: CGFloat = 12

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let title = subviews.first else {
            return .zero
        }

        let availableWidth = finiteWidth(proposal.width)
        guard subviews.count > 1 else {
            let titleSize = title.sizeThatFits(ProposedViewSize(width: availableWidth, height: proposal.height))
            return CGSize(width: availableWidth ?? titleSize.width, height: titleSize.height)
        }

        let trailing = subviews[1]
        if let availableWidth, usesHorizontalPlacement(width: availableWidth, title: title, trailing: trailing) {
            let trailingSize = trailing.sizeThatFits(.unspecified)
            let titleWidth = max(availableWidth - horizontalSpacing - trailingSize.width, 0)
            let titleSize = title.sizeThatFits(ProposedViewSize(width: titleWidth, height: proposal.height))
            return CGSize(width: availableWidth, height: max(titleSize.height, trailingSize.height))
        }

        let titleSize = title.sizeThatFits(ProposedViewSize(width: availableWidth, height: nil))
        let trailingSize = trailing.sizeThatFits(ProposedViewSize(width: availableWidth, height: nil))
        return CGSize(
            width: availableWidth ?? max(titleSize.width, trailingSize.width),
            height: titleSize.height + verticalSpacing + trailingSize.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let title = subviews.first else {
            return
        }

        guard subviews.count > 1 else {
            title.place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
            return
        }

        let trailing = subviews[1]
        if usesHorizontalPlacement(width: bounds.width, title: title, trailing: trailing) {
            let trailingSize = trailing.sizeThatFits(.unspecified)
            let titleWidth = max(bounds.width - horizontalSpacing - trailingSize.width, 0)
            title.place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: titleWidth, height: bounds.height)
            )
            trailing.place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY),
                anchor: .topTrailing,
                proposal: ProposedViewSize(width: trailingSize.width, height: trailingSize.height)
            )
            return
        }

        let childProposal = ProposedViewSize(width: bounds.width, height: nil)
        let titleSize = title.sizeThatFits(childProposal)
        title.place(at: bounds.origin, anchor: .topLeading, proposal: childProposal)
        trailing.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + titleSize.height + verticalSpacing),
            anchor: .topLeading,
            proposal: childProposal
        )
    }

    private func usesHorizontalPlacement(
        width: CGFloat,
        title: LayoutSubview,
        trailing: LayoutSubview
    ) -> Bool {
        let titleWidth = title.sizeThatFits(.unspecified).width
        let trailingWidth = trailing.sizeThatFits(.unspecified).width
        return titleWidth + horizontalSpacing + trailingWidth <= width
    }

    private func finiteWidth(_ width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite else {
            return nil
        }
        return max(width, 0)
    }
}

extension KitchenTableHeader where Trailing == EmptyView {
    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        hidesTitleInCompactNavigation: Bool = false
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            hidesTitleInCompactNavigation: hidesTitleInCompactNavigation
        ) {
            EmptyView()
        }
    }
}

private struct SpoonjoyCompactNavigationEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var spoonjoyCompactNavigation: Bool {
        get { self[SpoonjoyCompactNavigationEnvironmentKey.self] }
        set { self[SpoonjoyCompactNavigationEnvironmentKey.self] = newValue }
    }
}

struct KitchenTableSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let accessibilityHeaderIdentifier: String?
    let accessibilitySubtitleIdentifier: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        accessibilityHeaderIdentifier: String? = nil,
        accessibilitySubtitleIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessibilityHeaderIdentifier = accessibilityHeaderIdentifier
        self.accessibilitySubtitleIdentifier = accessibilitySubtitleIdentifier
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTableTheme.sectionSpacing) {
            sectionHeader
            content()
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                sectionTitle
                Rectangle()
                    .fill(KitchenTableTheme.line.opacity(0.55))
                    .frame(height: 1)
                    .layoutPriority(-1)
                    .accessibilityHidden(true)
            }
            if let subtitle, !subtitle.isEmpty {
                subtitleText(subtitle)
            }
        }
    }

    @ViewBuilder private func subtitleText(_ subtitle: String) -> some View {
        if let accessibilitySubtitleIdentifier {
            styledSubtitle(subtitle)
                .accessibilityIdentifier(accessibilitySubtitleIdentifier)
        } else {
            styledSubtitle(subtitle)
        }
    }

    private func styledSubtitle(_ subtitle: String) -> some View {
        Text(subtitle)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(KitchenTableTheme.charcoal)
    }

    @ViewBuilder private var sectionTitle: some View {
        if let accessibilityHeaderIdentifier {
            sectionTitleText
                .accessibilityIdentifier(accessibilityHeaderIdentifier)
        } else {
            sectionTitleText
        }
    }

    private var sectionTitleText: some View {
        Text(title)
            .font(KitchenTableTheme.sectionTitle)
            .foregroundStyle(KitchenTableTheme.charcoal)
            .layoutPriority(1)
    }
}

struct KitchenTableObjectRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let showsLeading: Bool
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        showsLeading: Bool = true,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsLeading = showsLeading
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            objectIdentity
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.line.opacity(0.35))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    private var objectIdentity: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsLeading {
                leading()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(KitchenTableTheme.objectTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension KitchenTableObjectRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        showsLeading: Bool = true,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            showsLeading: showsLeading,
            leading: leading
        ) {
            EmptyView()
        }
    }
}

struct KitchenTableReceiptRow<Leading: View>: View {
    let name: String
    let amount: String
    @ViewBuilder let leading: () -> Leading

    init(name: String, amount: String, @ViewBuilder leading: @escaping () -> Leading) {
        self.name = name
        self.amount = amount
        self.leading = leading
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            leading()
            Text(name)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Text(amount)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.line.opacity(0.34))
                .frame(height: 1)
        }
    }
}

extension KitchenTableReceiptRow where Leading == EmptyView {
    init(name: String, amount: String) {
        self.init(name: name, amount: amount) {
            EmptyView()
        }
    }
}

struct KitchenTableActionButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
        case quiet
        case destructive
    }

    let prominence: Prominence

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget + 2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .foregroundStyle(foreground)
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(stroke, lineWidth: prominence == .quiet ? 0 : 1)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private var foreground: Color {
        switch prominence {
        case .primary, .destructive:
            KitchenTableTheme.paper
        case .secondary, .quiet:
            KitchenTableTheme.charcoal
        }
    }

    private func background(configuration _: Configuration) -> Color {
        switch prominence {
        case .primary:
            KitchenTableTheme.action
        case .secondary:
            KitchenTableTheme.paper
        case .quiet:
            KitchenTableTheme.bone.opacity(0.01)
        case .destructive:
            KitchenTableTheme.tomato
        }
    }

    private var stroke: Color {
        switch prominence {
        case .primary:
            KitchenTableTheme.action
        case .secondary, .quiet:
            KitchenTableTheme.line.opacity(0.75)
        case .destructive:
            KitchenTableTheme.tomato
        }
    }
}
