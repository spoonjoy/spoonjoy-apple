import SwiftUI

enum KitchenTableTheme {
    static let bone = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let paper = Color(red: 0.99, green: 0.98, blue: 0.94)
    static let charcoal = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let inkMuted = Color(red: 0.40, green: 0.38, blue: 0.33)
    static let line = Color(red: 0.78, green: 0.72, blue: 0.62)
    static let brass = Color(red: 0.62, green: 0.45, blue: 0.20)
    static let tomato = Color(red: 0.75, green: 0.18, blue: 0.12)
    static let herb = Color(red: 0.24, green: 0.38, blue: 0.22)
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
    static let compactDockReserve: CGFloat = 104

    static let displayTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let sectionTitle = Font.system(.title2, design: .serif).weight(.bold)
    static let objectTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let bodyNote = Font.body
    static let uiLabel = Font.caption.weight(.semibold)
}

struct KitchenTablePage<Content: View>: View {
    let bottomReserve: CGFloat
    @ViewBuilder let content: () -> Content

    init(bottomReserve: CGFloat = KitchenTableTheme.compactDockReserve, @ViewBuilder content: @escaping () -> Content) {
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
            .frame(maxWidth: 720, alignment: .leading)
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
                Rectangle()
                    .fill(KitchenTableTheme.line.opacity(0.55))
                    .frame(height: 1)
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
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
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
            KitchenTableTheme.brass
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
            KitchenTableTheme.brass
        case .secondary, .quiet:
            KitchenTableTheme.line.opacity(0.75)
        case .destructive:
            KitchenTableTheme.tomato
        }
    }
}
