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
    static let photoOverlay = Color.black.opacity(0.28)

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
    static let compactDockReserve: CGFloat = 148

    static let displayTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let sectionTitle = Font.system(.title2, design: .serif).weight(.bold)
    static let objectTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let bodyNote = Font.body
    static let uiLabel = Font.caption.weight(.semibold)

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
        bottomReserve: CGFloat = KitchenTableTheme.compactDockReserve,
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
        .background(KitchenTableTheme.bone.ignoresSafeArea())
    }
}

struct KitchenTableHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                titleStack
                Spacer(minLength: 12)
                trailing()
            }

            VStack(alignment: .leading, spacing: 12) {
                titleStack
                trailing()
            }
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(KitchenTableTheme.brass)
            Text(title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension KitchenTableHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct KitchenTableSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
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
                Text(title)
                    .font(KitchenTableTheme.sectionTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineLimit(1)
                    .layoutPriority(1)
                Rectangle()
                    .fill(KitchenTableTheme.line.opacity(0.55))
                    .frame(height: 1)
                    .layoutPriority(-1)
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
        }
    }
}

struct KitchenTableObjectRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leading()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(KitchenTableTheme.objectTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.line.opacity(0.35))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

extension KitchenTableObjectRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder leading: @escaping () -> Leading) {
        self.init(title: title, subtitle: subtitle, leading: leading) {
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
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget + 2)
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
