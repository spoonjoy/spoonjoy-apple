import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum KitchenTableTheme {
    /// The web's light palette, verbatim from spoonjoy-v2 `:root`. Surfaces never use these directly; they use the
    /// roles below, which pick the light or night value for the current appearance.
    enum Day {
        static let bone = webColor(0xFBFAF4) // --sj-bone
        static let paper = webColor(0xFFFEFA) // --sj-bone-lift / --sj-panel-solid
        static let vellum = webColor(0xE8E9DF) // --sj-vellum / --sj-flour
        static let charcoal = webColor(0x28231D) // --sj-charcoal / --sj-action
        static let inkMuted = webColor(0x635D54) // --sj-charcoal-soft / --sj-ink-soft
        static let brass = webColor(0x9B6834) // --sj-brass
        static let action = webColor(0x28231D) // --sj-action
        static let actionDeep = webColor(0x1F1B17) // --sj-action-deep
        static let tomato = webColor(0xA24A38) // --sj-tomato
        static let herb = webColor(0x596A4F) // --sj-herb
        static let photoCharcoal = webColor(0x211F1B) // --sj-photo-charcoal
    }

    /// The web's designed `.dark` palette, verbatim from spoonjoy-v2 `.dark`: the night kitchen.
    enum Night {
        static let boneNight = webColor(0xF2EEE6) // .dark --sj-bone
        static let paperNight = webColor(0x282522) // .dark --sj-bone-lift
        static let vellumNight = webColor(0x34302B) // .dark --sj-vellum
        static let charcoalNight = webColor(0x1F1D1A) // .dark --sj-charcoal
        static let inkMutedNight = webColor(0xC8C0B4) // .dark --sj-charcoal-soft
        static let brassNight = webColor(0xC4945C) // .dark --sj-brass
        static let actionNight = webColor(0xB9854B) // .dark --sj-action
        static let actionDeepNight = webColor(0x95683A) // .dark --sj-action-deep
        static let tomatoNight = webColor(0xE58263) // .dark --sj-tomato
        static let herbNight = webColor(0xA4B578) // .dark --sj-herb
        static let photoCharcoalNight = webColor(0x1D1915) // .dark --sj-photo-charcoal
        static let pageNight = webColor(0x1E1C19) // .dark --sj-page
        static let onPhotoNight = webColor(0xF1E6D3) // .dark --sj-on-photo
    }

    // Roles. Each picks its light or night value from the current appearance, so every surface follows Dark Mode.

    /// The page behind everything: bone by day, the web's `--sj-page` at night.
    static let page = dynamic(Day.bone, Night.pageNight)
    /// A lifted surface on the page (a panel, a card, a sheet).
    static let raised = dynamic(Day.paper, Night.paperNight)
    /// Primary text and the one filled action.
    static let ink = dynamic(Day.charcoal, Night.boneNight)
    /// Secondary text.
    static let ink2 = dynamic(Day.inkMuted, Night.inkMutedNight)
    /// Text and symbols drawn on an `ink` or `action` fill.
    static let onInk = dynamic(Day.bone, Night.charcoalNight)
    /// A rule between rows: 18% ink by day, 16% bone at night, as the web's `--sj-border`.
    static let hairline = dynamic(Day.charcoal.opacity(0.18), Night.boneNight.opacity(0.16))
    static let lineStrong = dynamic(Day.charcoal.opacity(0.32), Night.boneNight.opacity(0.28)) // --sj-border-strong
    static let vellum = dynamic(Day.vellum, Night.vellumNight)
    static let brass = dynamic(Day.brass, Night.brassNight)
    static let action = dynamic(Day.action, Night.actionNight)
    static let actionDeep = dynamic(Day.actionDeep, Night.actionDeepNight)
    static let tomato = dynamic(Day.tomato, Night.tomatoNight)
    static let herb = dynamic(Day.herb, Night.herbNight)
    /// Text on a photo stays light in both appearances.
    static let onPhoto = dynamic(Day.bone, Night.onPhotoNight) // --sj-on-photo
    static let onPhotoMuted = onPhoto.opacity(0.76) // --sj-on-photo-muted
    static let photoCharcoal = dynamic(Day.photoCharcoal, Night.photoCharcoalNight)
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
    /// The room between a step's blocks: its heading, its ingredients and its method.
    static let stepBlockSpacing: CGFloat = 20
    /// The room above and below each step on the recipe page, either side of the rule between steps.
    static let stepSpacing: CGFloat = 22
    /// A separator a shade lighter than `line`, for rules between rows that should be felt more than seen.
    static let ruleSoft = hairline.opacity(0.42)
    static let hairlineWidth: CGFloat = 0.5

    /// A step's ingredient checklist. The column widths are base sizes; rows scale them with Dynamic Type.
    enum Checklist {
        /// The room above and below each row's text.
        static let rowVerticalPadding: CGFloat = 12
        static let checkColumn: CGFloat = 28
        static let iconColumn: CGFloat = 20
        static let columnGap: CGFloat = 12
        /// The room under the list's "Ingredients" label.
        static let headingGap: CGFloat = 4
        /// The spring the web's IngredientList uses when a checked ingredient moves to the bottom
        /// (`stiffness: 420, damping: 38, mass: 0.7`); with Reduce Motion the move is instant.
        static let reorderAnimation = Animation.interpolatingSpring(mass: 0.7, stiffness: 420, damping: 38)

        static func reorder(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : reorderAnimation
        }
    }
    static let compactDockReserve: CGFloat = 148

    /// The 1.1 layout grid: every spacing value is a multiple of 4 pt. Screen margins are 24 pt on iPhone,
    /// 32 pt on iPad and Mac, and 40 pt on the side of a page that meets the iPhone Duo fold.
    enum Spacing {
        static let unit: CGFloat = 4
        static let marginCompact: CGFloat = 24
        static let marginRegular: CGFloat = 32
        static let marginFold: CGFloat = 40
    }

    // 1.1 type roles. Serif roles use the system serif (New York); every role follows Dynamic Type.
    static let largeTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let recipeTitle = Font.system(.title, design: .serif).weight(.semibold)
    /// The cook step is read from arm's length, so it starts at the 34 pt large-title size (the closest Dynamic
    /// Type style to the 33 pt the design asks for) and scales from there.
    static let cookStep = Font.system(.largeTitle, design: .serif)
    static let story = Font.system(.body, design: .serif)
    static let control = Font.body.weight(.semibold)
    static let meta = Font.footnote
    static let timer = Font.system(.largeTitle).weight(.light).monospacedDigit()

    static let displayTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let sectionTitle = Font.system(.title2, design: .serif).weight(.bold)
    static let objectTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    // Index entries are titles in a book's contents, so they take the serif voice the web gives them.
    static let indexTitle = Font.system(.title3, design: .serif).weight(.semibold)
    static let bodyNote = Font.body
    static let uiLabel = Font.caption.weight(.semibold)

    // The cookbook spread: a recipe or cook mode laid open across a wide landscape screen, such as the inner
    // screen of the iPhone Duo. Instructions are body serif, as the design language assigns them.
    static let instructionBody = Font.system(.body, design: .serif)
    static let spreadInstruction = Font.system(.title3, design: .serif)
    static let cookInstruction = Font.system(.title, design: .serif)
    static let stepNumeral = Font.system(.title, design: .serif).weight(.semibold)
    static let runningHead = Font.caption2.weight(.bold)
    static let selectionWash = brass.opacity(0.09)
    static let spreadGutterRule = hairline

    private static func dynamic(_ light: Color, _ night: Color) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(night) : NSColor(light)
        })
        #else
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(night) : UIColor(light)
        })
        #endif
    }

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
    let topPadding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        maxContentWidth: CGFloat = 720,
        bottomReserve: CGFloat = KitchenTableTheme.compactDockReserve,
        topPadding: CGFloat = 20,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxContentWidth = maxContentWidth
        self.bottomReserve = bottomReserve
        self.topPadding = topPadding
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing) {
                content()
            }
            .padding(.horizontal, KitchenTableTheme.pagePadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomReserve)
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(KitchenTableTheme.page.ignoresSafeArea())
        .paperTopEdge()
    }
}

extension View {
    /// Covers the status bar and navigation bar with the page's paper, so a scrolled page slides cleanly
    /// under them. The system's top scroll edge (soft or hard) leaves a blurred ghost of the content behind
    /// the clock and the bar buttons, and toolbarBackground does not change it, so on iOS the edge effect is
    /// off and a zero-height line at the top of the safe area carries paper up to the screen edge. (A
    /// GeometryReader that ignores the safe area reports a top inset of zero, so it cannot size this.) Bar
    /// buttons still sit on top. On the Mac the page fades under a solid edge instead.
    func paperTopEdge() -> some View {
        modifier(PaperTopEdge())
    }
}

private struct PaperTopEdge: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content
            .scrollEdgeEffectHidden(true, for: .top)
            .overlay(alignment: .top) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 0)
                    .background(KitchenTableTheme.page.ignoresSafeArea(edges: .top))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
#else
        content
            .scrollEdgeEffectStyle(.hard, for: .top)
#endif
    }
}

struct KitchenTableHeader<Trailing: View>: View {
    @Environment(\.spoonjoyCompactNavigation) private var usesCompactNavigation

    let eyebrow: String
    let title: String
    let subtitle: String?
    let hidesTitleInCompactNavigation: Bool
    let titleFont: Font
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        hidesTitleInCompactNavigation: Bool = false,
        titleFont: Font = KitchenTableTheme.displayTitle,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.titleFont = titleFont
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.hidesTitleInCompactNavigation = hidesTitleInCompactNavigation
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
            if !usesCompactNavigation || !hidesTitleInCompactNavigation {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension KitchenTableHeader where Trailing == EmptyView {
    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        hidesTitleInCompactNavigation: Bool = false,
        titleFont: Font = KitchenTableTheme.displayTitle
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            hidesTitleInCompactNavigation: hidesTitleInCompactNavigation,
            titleFont: titleFont
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

/// A titled section. An accessory, such as a quiet control for the section, sits at the trailing end of the
/// subtitle line, so it never adds a line of its own.
struct KitchenTableSection<Content: View, Accessory: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let accessory: () -> Accessory

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.accessory = accessory
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
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                Rectangle()
                    .fill(KitchenTableTheme.hairline.opacity(0.55))
                    .frame(height: 1)
                    .layoutPriority(-1)
            }
            if Accessory.self == EmptyView.self {
                subtitleText
            } else {
                // At large text sizes the accessory drops under the subtitle instead of squeezing it.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        subtitleText
                        Spacer(minLength: 0)
                        accessory()
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        subtitleText
                        accessory()
                    }
                }
            }
        }
    }

    @ViewBuilder private var subtitleText: some View {
        if let subtitle, !subtitle.isEmpty {
            Text(subtitle)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension KitchenTableSection where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, content: content) {
            EmptyView()
        }
    }
}

struct KitchenTableObjectRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let detail: String?
    let ordinal: String?
    let titleFont: Font
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        ordinal: String? = nil,
        titleFont: Font = KitchenTableTheme.objectTitle,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.ordinal = ordinal
        self.titleFont = titleFont
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let ordinal {
                // The number sits beside the thumbnail, never on it.
                Text(ordinal)
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(KitchenTableTheme.brass)
                    .frame(width: 26, alignment: .leading)
                    .accessibilityHidden(true)
            }

            leading()
                .frame(width: 56, height: 56)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .lineLimit(2)
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.hairline.opacity(0.35))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

extension KitchenTableObjectRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder leading: @escaping () -> Leading) {
        self.init(title: title, subtitle: subtitle, detail: nil, ordinal: nil, titleFont: KitchenTableTheme.objectTitle, leading: leading) {
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
                .foregroundStyle(KitchenTableTheme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Text(amount)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink2)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTableTheme.hairline.opacity(0.34))
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

/// Kitchen action buttons on Liquid Glass. `.primary` is the screen's one filled action, in ink; `.destructive` is
/// the same shape in tomato for a confirmed delete; `.secondary` is clear glass; `.quiet` is text only. The fills sit
/// on interactive glass, so every glass-backed button gets the system press response.
struct KitchenTableActionButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
        case quiet
        case destructive
    }

    let prominence: Prominence

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()
        let label = configuration.label
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget + 2)
            .padding(.horizontal, 14)
            .foregroundStyle(foreground)
            .contentShape(shape)

        switch prominence {
        case .primary, .destructive:
            // A tinted glass fill reads grey over the bone page, so the fill is solid and the glass under it supplies
            // the interactive press response.
            label
                .background(fill, in: shape)
                .glassEffect(.regular.interactive(), in: shape)
        case .secondary:
            label
                .glassEffect(.regular.interactive(), in: shape)
        case .quiet:
            label
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }

    private var foreground: Color {
        switch prominence {
        case .primary, .destructive:
            KitchenTableTheme.onInk
        case .secondary, .quiet:
            KitchenTableTheme.ink
        }
    }

    private var fill: Color {
        prominence == .destructive ? KitchenTableTheme.tomato : KitchenTableTheme.ink
    }
}
