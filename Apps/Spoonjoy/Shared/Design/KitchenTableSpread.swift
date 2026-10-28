import SpoonjoyCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Two facing pages split by a gutter that shades like the fold of a cookbook laid open on the counter.
///
/// `BookSpreadLayout` decides where the gutter goes. Built with the iOS 27.1 SDK and running on iOS 27.1 or later,
/// the gutter follows the hinge: `SpreadLayoutReader` reads the Reserved Region `.division` rect (see
/// `HingeFoldReader` below). Otherwise the gutter sits in the middle of the screen, which is where the iPhone
/// Duo folds. See "iPhone Duo Inner Screen" in docs/native-design-language.md.
struct KitchenTableSpread<Leading: View, Trailing: View>: View {
    let layout: BookSpreadLayout
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    private static var shadowWidth: CGFloat { CGFloat(BookSpreadLayout.gutterShadowWidth) }

    var body: some View {
        let gutterWidth = CGFloat(layout.gutter?.width ?? 0)

        HStack(spacing: 0) {
            leading()
                .frame(width: CGFloat(layout.leadingPage?.width ?? 0))
                .frame(maxHeight: .infinity, alignment: .top)
            Color.clear
                .frame(width: gutterWidth)
            trailing()
                .frame(width: CGFloat(layout.trailingPage?.width ?? 0))
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .leading) {
            foldShadow(gutterWidth: gutterWidth)
                .offset(x: CGFloat(layout.leadingPage?.width ?? 0) - Self.shadowWidth)
        }
        .background(KitchenTableTheme.page.ignoresSafeArea())
    }

    /// Two gradients mirrored about the fold line, darkest at the fold and gone by `gutterShadowWidth` into each
    /// page. The pages' gutter-side margin is wider than this, so text never sits in the shade.
    private func foldShadow(gutterWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [KitchenTableTheme.foldShadow.opacity(0), KitchenTableTheme.foldShadow],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.shadowWidth)
            KitchenTableTheme.foldShadow
                .frame(width: gutterWidth)
            LinearGradient(
                colors: [KitchenTableTheme.foldShadow, KitchenTableTheme.foldShadow.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.shadowWidth)
        }
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
            let layout = BookSpreadLayout.resolve(
                width: Double(proxy.size.width),
                height: Double(proxy.size.height),
                isRegularWidth: isRegularWidth,
                division: division
            )
            content(layout)
#if DEBUG
                .onChange(of: layout, initial: true) { _, layout in
                    SpreadLayoutProbe.record(layout, size: proxy.size)
                }
#endif
        }
        .readingHingeDivision($division)
    }
}

#if DEBUG
/// Appends each resolved layout to `tmp/spoonjoy-spread-layout.log` in the app's data container. The Duo tour workflow
/// reads it to check that the iPhone Duo held open flat opens recipes and cook mode as a spread on the hinge.
enum SpreadLayoutProbe {
    static func record(_ layout: BookSpreadLayout, size: CGSize) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-spread-layout.log")
        let line = Data("container=\(size.width)x\(size.height) \(layout.probeDescription)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }
}
#endif

/// What the system says about a foldable's fold, in one view's coordinate space.
struct FoldReading: Equatable {
    /// A vertical fold (the screen held like a book).
    var division: SpreadDivision?
    /// A horizontal fold (the screen held tall, or stood half-open on the counter).
    var band: FoldBand?
    var hinge: HingePosture = .unknown
    /// How far the hinge is open, 0° shut to 180° flat, when the system reports it.
    var angleDegrees: Double?

    /// How cook mode should present itself for this reading.
    var posture: CookPosture {
        TabletopLayout.posture(hingeStatus: hinge, angleDegrees: angleDegrees)
    }

    /// The posture a DEBUG build was launched with (`-SpoonjoyForcePosture tabletop`, `flat` or `closed`), so
    /// screenshots and journeys can show each posture on a simulator whose hinge they cannot move. Always nil in
    /// release builds.
    static let forcedHinge: HingePosture? = {
#if DEBUG
        switch UserDefaults.standard.string(forKey: "SpoonjoyForcePosture") {
        case "tabletop": .partiallyOpen
        case "flat": .fullyOpen
        case "closed": .closed
        default: nil
        }
#else
        nil
#endif
    }()

    /// The hinge `TabletopLayout.resolve` should split for. A bend in the tabletop band stands up even when the
    /// system calls it fully open, and one too shallow to stand on never splits.
    var tabletopHinge: HingePosture {
        switch posture {
        case .tabletop: .partiallyOpen
        case .openFlat: .fullyOpen
        case .closedGlance: .closed
        case .single: .unknown
        }
    }

    /// This reading with a DEBUG forced posture applied. A forced posture carries no angle, so the status decides.
    var applyingForcedHinge: FoldReading {
        guard let forced = Self.forcedHinge else {
            return self
        }
        var reading = self
        reading.hinge = forced
        reading.angleDegrees = nil
        return reading
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

    /// Reports the fold, the hinge posture and the hinge angle in this view's coordinate space. Compiles to a no-op
    /// unless the app is built with the iOS 27.1 SDK, and does nothing at run time before iOS 27.1, where no API
    /// reports a fold.
    @ViewBuilder func readingFold(_ reading: Binding<FoldReading>) -> some View {
#if os(iOS) && SPOONJOY_IOS_27_1_SDK
        if #available(iOS 27.1, *) {
            modifier(HingeFoldReader(reading: reading))
        } else {
            self
        }
#else
        self
#endif
    }
}

#if os(iOS) && SPOONJOY_IOS_27_1_SDK
/// Reads the fold with SwiftUI's own hinge APIs: `onHingeChange` for the hinge's status and angle, and
/// `GeometryProxy.reservedRegions(kind: .division)` for where the fold lies in this view.
@available(iOS 27.1, *)
private struct HingeFoldReader: ViewModifier {
    @Binding var reading: FoldReading
    @State private var hinge: DeviceHinge?

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: Self.reading(in: proxy, hinge: hinge), initial: true) { _, new in
                            if reading != new {
                                reading = new
                            }
                        }
                }
                .accessibilityHidden(true)
            }
            .onHingeChange { _, new in
                hinge = new.hinge
            }
    }

    private static func posture(_ status: DeviceHinge.Status?) -> HingePosture {
        switch status {
        case .closed?: .closed
        case .partiallyOpen?: .partiallyOpen
        case .fullyOpen?: .fullyOpen
        default: .unknown
        }
    }

    private static func reading(in proxy: GeometryProxy, hinge: DeviceHinge?) -> FoldReading {
        // Open flat, iOS marks the fold inactive, and a plain query drops it; see FoldRegionChoice.
        let regions = proxy.reservedRegions(kind: .division, options: .includeInactive, layoutDirectionBehavior: .fixed)
            .map { region in
                ReportedFoldRegion(
                    minX: Double(region.frame.minX),
                    minY: Double(region.frame.minY),
                    width: Double(region.frame.width),
                    height: Double(region.frame.height),
                    isActive: region.isActive
                )
            }
        let width = Double(proxy.size.width)
        let height = Double(proxy.size.height)
        let posture = posture(hinge?.status)
        let band = FoldRegionChoice.band(from: regions, containerWidth: width, containerHeight: height)
            ?? screenMidline(in: proxy, hinge: posture)
        return FoldReading(
            division: FoldRegionChoice.division(from: regions, containerWidth: width, containerHeight: height),
            band: band,
            hinge: posture,
            angleDegrees: hinge.map { $0.angle.degrees }
        )
    }

    /// With a half-open hinge and no reported fold, the fold is at the middle of the screen, which is not the middle
    /// of this view when it sits under a navigation bar. The global space is the window's.
    private static func screenMidline(in proxy: GeometryProxy, hinge: HingePosture) -> FoldBand? {
        guard hinge == .partiallyOpen else {
            return nil
        }
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let windowHeight = window?.bounds.height else {
            return nil
        }
        let midY = Double(windowHeight / 2 - proxy.frame(in: .global).minY)
        guard midY > 0, midY < Double(proxy.size.height) else {
            return nil
        }
        return FoldBand(minY: midY, height: 0)
    }
}
#endif
