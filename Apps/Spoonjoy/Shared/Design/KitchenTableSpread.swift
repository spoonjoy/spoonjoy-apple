import SpoonjoyCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Two facing pages split by a hairline gutter, like a cookbook laid open on the counter.
///
/// `BookSpreadLayout` decides where the gutter goes. Built with the iOS 27.1 SDK and running on iOS 27.1 or later,
/// the gutter follows the hinge: `SpreadLayoutReader` reads the Reserved Region `.division` rect (see
/// `HingeDivisionProbe` below). Otherwise the gutter sits in the middle of the screen, which is where the iPhone
/// Duo folds. See "iPhone Duo Inner Screen" in docs/native-design-language.md.
struct KitchenTableSpread<Leading: View, Trailing: View>: View {
    let layout: BookSpreadLayout
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    private static var ruleWidth: CGFloat { 1 }

    var body: some View {
        let leadingWidth = CGFloat(layout.leadingPage?.width ?? 0)
        let trailingWidth = CGFloat(layout.trailingPage?.width ?? 0)
        let gutterWidth = max(CGFloat(layout.gutter?.width ?? 0), Self.ruleWidth)
        // A zero-width gutter still needs a visible rule; it takes half a point from each page.
        let overlap = (gutterWidth - CGFloat(layout.gutter?.width ?? 0)) / 2

        HStack(spacing: 0) {
            leading()
                .frame(width: max(0, leadingWidth - overlap))
                .frame(maxHeight: .infinity, alignment: .top)
            gutter(width: gutterWidth)
            trailing()
                .frame(width: max(0, trailingWidth - overlap))
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(KitchenTableTheme.bone.ignoresSafeArea())
    }

    private func gutter(width: CGFloat) -> some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(KitchenTableTheme.spreadGutterRule)
                .frame(width: Self.ruleWidth)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Pads one page of a spread: a wider margin on the gutter side keeps text and tap targets off the fold.
    func spreadPagePadding(_ side: SpreadPageSide, top: CGFloat = 24, bottom: CGFloat = 40) -> some View {
        let insets = BookSpreadLayout.pageInsets(for: side)
        return padding(.leading, CGFloat(insets.leading))
            .padding(.trailing, CGFloat(insets.trailing))
            .padding(.top, top)
            .padding(.bottom, bottom)
    }

    /// A small uppercase running head, like the line at the top of a cookbook page.
    func spreadRunningHead() -> some View {
        font(KitchenTableTheme.runningHead)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(KitchenTableTheme.brass)
    }
}

// MARK: - Hinge division (iOS 27.1 SDK)

/// Resolves the spread for the space it is given, following the hinge when the system reports one.
///
/// This replaces a bare `GeometryReader` around `BookSpreadLayout.resolve`: it measures the same space and also
/// hands the Reserved Region `.division` rect, in that space's coordinates, to `resolve(division:)`. With no
/// hinge information it resolves exactly as before, from the width heuristic.
struct SpreadLayoutReader<Content: View>: View {
    let isRegularWidth: Bool
    @ViewBuilder let content: (BookSpreadLayout) -> Content

    @State private var division: SpreadDivision?

    var body: some View {
        GeometryReader { proxy in
            content(
                BookSpreadLayout.resolve(
                    width: Double(proxy.size.width),
                    height: Double(proxy.size.height),
                    isRegularWidth: isRegularWidth,
                    division: division
                )
            )
        }
        .readingHingeDivision($division)
    }
}

/// What the system says about a foldable's fold, in one view's coordinate space.
struct FoldReading: Equatable {
    /// A vertical fold (the screen held like a book).
    var division: SpreadDivision?
    /// A horizontal fold (the screen held tall, or stood half-open on the counter).
    var band: FoldBand?
    var hinge: HingePosture = .unknown

    /// The posture a DEBUG build was launched with (`-SpoonjoyForcePosture tabletop`), so screenshots and previews
    /// can show tabletop cook mode on a simulator that cannot half-open its hinge. Always nil in release builds.
    static var forcedHinge: HingePosture? {
#if DEBUG
        switch UserDefaults.standard.string(forKey: "SpoonjoyForcePosture") {
        case "tabletop": .partiallyOpen
        case "flat": .fullyOpen
        default: nil
        }
#else
        nil
#endif
    }
}

extension View {
    /// Reports the hinge division in this view's coordinate space, or nil when there is none. Compiles to a no-op
    /// unless the app is built with the iOS 27.1 SDK, and does nothing at run time before iOS 27.1.
    func readingHingeDivision(_ division: Binding<SpreadDivision?>) -> some View {
        readingFold(Binding(
            get: { FoldReading(division: division.wrappedValue) },
            set: { division.wrappedValue = $0.division }
        ))
    }

    /// Reports the fold and the hinge posture in this view's coordinate space. Compiles to a no-op unless the app is
    /// built with the iOS 27.1 SDK, and does nothing at run time before iOS 27.1.
    @ViewBuilder func readingFold(_ reading: Binding<FoldReading>) -> some View {
#if os(iOS) && SPOONJOY_IOS_27_1_SDK
        background(HingeDivisionProbe(reading: reading))
#else
        self
#endif
    }
}

#if os(iOS) && SPOONJOY_IOS_27_1_SDK
/// An invisible view that fills the space it measures and reads the `.division` Reserved Region and the hinge from
/// UIKit.
///
/// UIKit's `UIView.reservedRegions(kind:options:)` gives the fold's rect; `UIHingeInteraction` gives the hinge's
/// status, and asks for a fresh read of the rect when the hinge moves.
private struct HingeDivisionProbe: UIViewRepresentable {
    @Binding var reading: FoldReading

    func makeUIView(context: Context) -> UIView {
        guard #available(iOS 27.1, *) else {
            return UIView()
        }
        let view = HingeDivisionView()
        view.onChange = { [binding = $reading] new in binding.wrappedValue = new }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard #available(iOS 27.1, *), let view = view as? HingeDivisionView else {
            return
        }
        view.onChange = { [binding = $reading] new in binding.wrappedValue = new }
    }
}

@available(iOS 27.1, *)
private final class HingeDivisionView: UIView {
    var onChange: ((FoldReading) -> Void)?
    private var reported: FoldReading?
    private var hinge: HingePosture = .unknown

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        addInteraction(UIHingeInteraction { [weak self] _, update in
            guard let self else {
                return
            }
            self.hinge = Self.posture(update.hinge?.status)
            self.setNeedsLayout()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("HingeDivisionView is created in code only")
    }

    private static func posture(_ status: UIHinge.Status?) -> HingePosture {
        switch status {
        case .closed: .closed
        case .partiallyOpen: .partiallyOpen
        case .fullyOpen: .fullyOpen
        default: .unknown
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let region = reservedRegions(kind: .division).first(where: \.isActive)
        let division = region.flatMap { region in
            SpreadDivision(
                frameMinX: Double(region.frame.minX),
                frameWidth: Double(region.frame.width),
                frameHeight: Double(region.frame.height),
                containerWidth: Double(bounds.width),
                containerHeight: Double(bounds.height)
            )
        }
        let band = region.flatMap { region in
            FoldBand(
                frameMinY: Double(region.frame.minY),
                frameHeight: Double(region.frame.height),
                frameWidth: Double(region.frame.width),
                containerWidth: Double(bounds.width),
                containerHeight: Double(bounds.height)
            )
        }
        let reading = FoldReading(division: division, band: band, hinge: hinge)
        guard reading != reported else {
            return
        }
        reported = reading
        DispatchQueue.main.async { [onChange] in
            onChange?(reading)
        }
    }
}
#endif
