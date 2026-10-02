import SpoonjoyCore
import SwiftUI

/// Two facing pages split by a hairline gutter, like a cookbook laid open on the counter.
///
/// `BookSpreadLayout` decides where the gutter goes. Today that is the middle of the screen, which is where the
/// iPhone Duo folds. FOLD SEAM: once the iOS 27.1 SDK ships, read the Reserved Region `.division` rect, convert it
/// to this view's coordinates and pass it to `BookSpreadLayout.resolve(division:)`; the gutter then follows the
/// hinge exactly and nothing here changes. See "iPhone Duo Inner Screen" in docs/native-design-language.md.
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
