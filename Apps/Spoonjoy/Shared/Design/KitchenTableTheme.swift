import OuroHX
#if !SPOONJOY_WIDGET_EXTENSION
import SpoonjoyCore
#endif
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum KitchenTableTheme {
    /// The web's light palette. Every value comes from ouro-ui-core's cookbook theme (the `sj-*` tokens, the one
    /// source web and native share) through OuroHX; `KitchenPaletteOuroTests` holds each one to web's hex. Surfaces
    /// never use these directly; they use the roles below, which pick the light or night value for the appearance.
    enum Day {
        // Also the day value of `onInk` and `onPhoto` (text on a fill); same value, so it stays one constant.
        static let bone = cookbookDay(.sjBone)
        static let paper = cookbookDay(.sjBoneLift)
        static let vellum = cookbookDay(.sjVellum)
        static let charcoal = cookbookDay(.sjCharcoal)
        static let inkMuted = cookbookDay(.sjCharcoalSoft)
        static let brass = cookbookDay(.sjBrass)
        static let action = cookbookDay(.sjAction)
        static let actionDeep = cookbookDay(.sjActionDeep)
        static let tomato = cookbookDay(.sjTomato)
        static let herb = cookbookDay(.sjHerb)
        static let photoCharcoal = cookbookDay(.sjPhotoCharcoal)
        static let border = cookbookDay(.sjBorder)
        static let borderStrong = cookbookDay(.sjBorderStrong)
        static let onPhotoMuted = cookbookDay(.sjOnPhotoMuted)
    }

    /// The web's designed `.dark` palette, the night kitchen, from the same cookbook tokens.
    enum Night {
        static let boneNight = cookbookNight(.sjBone)
        static let paperNight = cookbookNight(.sjBoneLift)
        static let vellumNight = cookbookNight(.sjVellum)
        static let charcoalNight = cookbookNight(.sjCharcoal)
        static let inkMutedNight = cookbookNight(.sjCharcoalSoft)
        static let brassNight = cookbookNight(.sjBrass)
        static let actionNight = cookbookNight(.sjAction)
        static let actionDeepNight = cookbookNight(.sjActionDeep)
        static let tomatoNight = cookbookNight(.sjTomato)
        static let herbNight = cookbookNight(.sjHerb)
        static let photoCharcoalNight = cookbookNight(.sjPhotoCharcoal)
        static let pageNight = cookbookNight(.sjPage)
        static let onPhotoNight = cookbookNight(.sjOnPhoto)
        static let borderNight = cookbookNight(.sjBorder)
        static let borderStrongNight = cookbookNight(.sjBorderStrong)
        static let onPhotoMutedNight = cookbookNight(.sjOnPhotoMuted)
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
    /// A rule between rows, web's `--sj-border`.
    static let hairline = dynamic(Day.border, Night.borderNight)
    static let lineStrong = dynamic(Day.borderStrong, Night.borderStrongNight)
    static let vellum = dynamic(Day.vellum, Night.vellumNight)
    static let brass = dynamic(Day.brass, Night.brassNight)
    static let action = dynamic(Day.action, Night.actionNight)
    static let actionDeep = dynamic(Day.actionDeep, Night.actionDeepNight)
    static let tomato = dynamic(Day.tomato, Night.tomatoNight)
    static let herb = dynamic(Day.herb, Night.herbNight)
    /// Text on a photo stays light in both appearances.
    static let onPhoto = dynamic(Day.bone, Night.onPhotoNight) // --sj-on-photo
    static let onPhotoMuted = dynamic(Day.onPhotoMuted, Night.onPhotoMutedNight)
    static let photoCharcoal = dynamic(Day.photoCharcoal, Night.photoCharcoalNight)
    static let photoOverlay = Color.black.opacity(0.28)
    /// The soft shadow at a spread's fold: 10% ink by day. At night ink is light, so the fold darkens the paper with
    /// black instead, the same way a real crease shades in low light.
    static let foldShadow = dynamic(Day.charcoal.opacity(0.10), Color.black.opacity(0.32))

    /// Corners from the cookbook tokens, as web draws them. Controls keep the platform's capsule.
    enum Radius {
        static let edge: CGFloat = 0
        /// Book covers and recipe thumbnails: `sj-radius-small`.
        static let cover = cookbookLength(.sjRadiusSmall)
        /// Photographs: `sj-radius-photo`.
        static let photo = cookbookLength(.sjRadiusPhoto)
        /// Panels, cards and sheets' inner surfaces: `sj-radius-surface`.
        static let panel = cookbookLength(.sjRadiusSurface)
        static let control: CGFloat = 999
    }

    /// The soft lift under a cover or photo that sits above the page: web's `sj-shadow-soft`, with its own reach at
    /// night. Draw it with `kitchenLiftShadow()`.
    static let liftShadow = cookbookShadow(.sjShadowSoft)

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
        static let unit = cookbookLength(.sjSpaceUnit)
        static let marginCompact = cookbookLength(.sjMarginCompact)
        static let marginRegular = cookbookLength(.sjMarginRegular)
        static let marginFold = cookbookLength(.sjMarginFold)
    }

    // Type roles in web's faces (``KitchenTypeRole``): Fraunces titles, Source Serif 4 reading, IBM Plex Sans Condensed
    // labels. Each is its `sj-type-*` token's size, scaled with Dynamic Type relative to the token's text style.
    static let largeTitle = KitchenTypeRole.largeTitle.font
    static let recipeTitle = KitchenTypeRole.recipeTitle.font
    static let cookStep = KitchenTypeRole.cookStep.font
    static let story = KitchenTypeRole.story.font
    static let control = KitchenTypeRole.control.font
    static let meta = KitchenTypeRole.meta.font
    /// The timer's digits stay San Francisco, light and monospaced, so they never jump as they count.
    static let timer = Font.system(.largeTitle).weight(.light).monospacedDigit()

    static let displayTitle = KitchenTypeRole.displayTitle.font
    static let sectionTitle = KitchenTypeRole.sectionTitle.font
    static let objectTitle = KitchenTypeRole.objectTitle.font
    static let indexTitle = KitchenTypeRole.indexTitle.font
    static let bodyNote = KitchenTypeRole.bodyNote.font
    /// An ingredient's aisle under its name: the reading serif, a size down, as web sets a checklist item's description.
    static let ingredientNote = KitchenTypeRole.bodyNote.font(relativeTo: .subheadline)
    static let uiLabel = KitchenTypeRole.uiLabel.font

    // The cookbook spread: a recipe or cook mode laid open across a wide landscape screen, such as the inner
    // screen of the iPhone Duo.
    static let instructionBody = KitchenTypeRole.instructionBody.font
    static let spreadInstruction = KitchenTypeRole.spreadInstruction.font
    static let cookInstruction = KitchenTypeRole.cookInstruction.font
    static let stepNumeral = KitchenTypeRole.stepNumeral.font
    /// A step's name beside its "STEP 1" eyebrow on the recipe page.
    static let stepTitle = KitchenTypeRole.stepTitle.font
    static let runningHead = KitchenTypeRole.runningHead.font
    /// Web's eyebrow face (IBM Plex Sans Condensed bold); `.kitchenEyebrow()` adds its capitals, tracking and brass.
    static let eyebrow = KitchenTypeRole.eyebrow.font
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

    /// A cookbook colour by day.
    private static func cookbookDay(_ token: OuroExtraColor) -> Color { cookbookColor(token, .light) }

    /// A cookbook colour at night.
    private static func cookbookNight(_ token: OuroExtraColor) -> Color { cookbookColor(token, .dark) }

    /// A cookbook token is part of the pinned OuroHX release, so a missing one means the pin dropped a Spoonjoy token:
    /// stop at once (every test and launch reaches these) rather than draw a guessed colour.
    private static func cookbookColor(_ token: OuroExtraColor, _ scheme: ColorScheme) -> Color {
        guard let color = OuroTokens.cookbook.extras.color(token, scheme) else {
            preconditionFailure("OuroHX's cookbook theme has no \(token.rawValue)")
        }
        return color
    }

    private static func cookbookLength(_ token: OuroExtraLength) -> CGFloat {
        guard let length = OuroTokens.cookbook.extras.lengths[token] else {
            preconditionFailure("OuroHX's cookbook theme has no \(token.rawValue)")
        }
        return CGFloat(length)
    }

    private static func cookbookShadow(_ token: OuroExtraShadow) -> OuroShadow {
        guard let shadow = OuroTokens.cookbook.extras.shadows[token] else {
            preconditionFailure("OuroHX's cookbook theme has no \(token.rawValue)")
        }
        return shadow
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
    /// buttons and an inline title still sit on top, but a large title does not, so the paper appears only
    /// once the page has scrolled off its top: at rest the large title shows, and scrolled it has collapsed
    /// into the inline title. On the Mac the page fades under a solid edge instead.
    func paperTopEdge() -> some View {
        modifier(PaperTopEdge())
    }
}

private struct PaperTopEdge: ViewModifier {
#if os(iOS)
    @State private var isScrolled = false
#endif

    func body(content: Content) -> some View {
#if os(iOS)
        content
            .scrollEdgeEffectHidden(true, for: .top)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 1
            } action: { _, scrolled in
                isScrolled = scrolled
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 0)
                    .background(KitchenTableTheme.page.ignoresSafeArea(edges: .top))
                    .opacity(isScrolled ? 1 : 0)
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
    @Environment(\.spoonjoyBarShowsPageTitle) private var barShowsPageTitle

    let eyebrow: String
    let title: String
    let subtitle: String?
    let hidesTitleInCompactNavigation: Bool
    let titleFont: Font
    @ViewBuilder let trailing: () -> Trailing

    /// `eyebrow` is a kicker that carries state, such as the day or a cookbook's owner; leave it empty when it would
    /// only repeat where the reader already is.
    init(
        eyebrow: String = "",
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
            if !eyebrow.isEmpty {
                Text(eyebrow)
                    .kitchenEyebrow()
            }
            // A page whose title the bar already shows leaves it out, so it never reads twice.
            if !(usesCompactNavigation || barShowsPageTitle) || !hidesTitleInCompactNavigation {
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
        eyebrow: String = "",
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

private struct SpoonjoyBarShowsPageTitleEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var spoonjoyCompactNavigation: Bool {
        get { self[SpoonjoyCompactNavigationEnvironmentKey.self] }
        set { self[SpoonjoyCompactNavigationEnvironmentKey.self] = newValue }
    }

    /// Whether the navigation bar shows the page's title (the iPad's large titles), so the page's own heading steps
    /// aside, as it does under the phone's tab bar.
    var spoonjoyBarShowsPageTitle: Bool {
        get { self[SpoonjoyBarShowsPageTitleEnvironmentKey.self] }
        set { self[SpoonjoyBarShowsPageTitleEnvironmentKey.self] = newValue }
    }
}

#if !SPOONJOY_WIDGET_EXTENSION
// The app's sections; the widget draws none, and the shared header lives with the app's components.
/// A titled section. An accessory, such as a quiet control for the section, sits at the trailing end of the
/// subtitle line, so it never adds a line of its own.
struct KitchenTableSection<Content: View, Accessory: View>: View {
    let eyebrow: String?
    let title: String
    /// Tracked at the title's trailing edge: a count or a short hint, as web's section headers carry.
    let meta: String?
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let accessory: () -> Accessory

    init(
        eyebrow: String? = nil,
        title: String,
        meta: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.meta = meta
        self.subtitle = subtitle
        self.content = content
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenTableTheme.sectionSpacing) {
            KitchenSectionHeader(eyebrow: eyebrow, title: title, meta: meta)
            subtitleAndAccessory
            content()
        }
    }

    @ViewBuilder private var subtitleAndAccessory: some View {
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
    init(
        eyebrow: String? = nil,
        title: String,
        meta: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(eyebrow: eyebrow, title: title, meta: meta, subtitle: subtitle, content: content) {
            EmptyView()
        }
    }
}
#endif

struct KitchenTableObjectRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let detail: String?
    let ordinal: String?
    let titleFont: Font
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    .font(KitchenTableTheme.eyebrow)
                    .kitchenEyebrowTracking()
                    .foregroundStyle(KitchenTableTheme.brass)
                    .frame(width: 26, alignment: .leading)
                    .accessibilityHidden(true)
            }

            leading()
                .frame(width: 56, height: 56)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.cover))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .lineLimit(lineLimit)
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(KitchenTableTheme.meta)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .lineLimit(lineLimit)
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

    /// Two lines at the standard sizes; at the accessibility sizes the text wraps in full instead of truncating.
    private var lineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 2
    }
}

extension KitchenTableObjectRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        titleFont: Font = KitchenTableTheme.objectTitle,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        self.init(title: title, subtitle: subtitle, detail: detail, ordinal: nil, titleFont: titleFont, leading: leading) {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()
        // At the accessibility sizes a label wraps to a second line instead of truncating.
        let label = configuration.label
            .font(KitchenTableTheme.control)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
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

/// A designed empty state: a brass mark, the title in the serif, one line of copy and at most one way in. It sits on the
/// page under a strong rule, never in a box, so an empty screen reads like the Kitchen's "The table is set".
struct KitchenTableEmptyTile<Action: View>: View {
    let systemImage: String
    let title: String
    let message: String
    /// Brass by default; herb when the state is a finish rather than a start.
    let tint: Color
    @ViewBuilder let action: () -> Action
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        systemImage: String,
        title: String,
        message: String,
        tint: Color = KitchenTableTheme.brass,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.tint = tint
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(.title, design: .serif))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(KitchenTableTheme.sectionTitle)
                .foregroundStyle(KitchenTableTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(KitchenTableTheme.instructionBody)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if Action.self != EmptyView.self {
                // At the accessibility sizes the action spans the tile, so its label stays on one line where it can.
                action()
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 320, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(KitchenTableTheme.lineStrong).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

extension KitchenTableEmptyTile where Action == EmptyView {
    init(systemImage: String, title: String, message: String) {
        self.init(systemImage: systemImage, title: title, message: message) {
            EmptyView()
        }
    }
}

private struct KitchenLiftShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let layer = KitchenTableTheme.liftShadow.layer(colorScheme)
        content.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y)
    }
}

extension View {
    /// Lifts a cover or photo off the page with web's soft shadow, by day or by night.
    func kitchenLiftShadow() -> some View { modifier(KitchenLiftShadow()) }
}

extension View {
    /// Web's eyebrow: IBM Plex Sans Condensed bold capitals, tracked 0.18 em at every text size, in brass unless a
    /// quieter ink is passed. VoiceOver reads the text as written, not spelled out in capitals.
    func kitchenEyebrow(_ color: Color = KitchenTableTheme.brass) -> some View {
        ouroType(KitchenTypeRole.eyebrow.token, in: OuroTokens.cookbook.extras)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// The eyebrow token's letter spacing (`sj-tracking-eyebrow`, 0.18 em), scaled with Dynamic Type, for a tracked
    /// uppercase label that keeps its own font. Letter spacing is never hand-set.
    func kitchenEyebrowTracking() -> some View {
        modifier(KitchenEyebrowTracking())
    }
}

private struct KitchenEyebrowTracking: ViewModifier {
    private let token = KitchenTypeRole.eyebrow.token
    @ScaledMetric private var scale: Double

    init() {
        _scale = ScaledMetric(wrappedValue: 1, relativeTo: KitchenTypeRole.eyebrow.token.textStyle)
    }

    func body(content: Content) -> some View {
        content.tracking(OuroFont.tracking(token, scale: scale))
    }
}
