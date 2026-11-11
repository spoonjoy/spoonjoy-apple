import OuroHX
#if !SPOONJOY_WIDGET_EXTENSION
// The widget extension does not link SpoonjoyCore, so it compiles KitchenFontFiles.swift itself.
import SpoonjoyCore
#endif
import SwiftUI
#if os(iOS) && !SPOONJOY_WIDGET_EXTENSION
import CoreText
import UIKit
#endif

/// Web's three typefaces in the app: Fraunces for titles, Source Serif 4 for reading and IBM Plex Sans Condensed for
/// labels, bundled in `Fonts/` and named by ouro-ui-core's cookbook theme. Each role scales with Dynamic Type, and a
/// face that isn't registered falls back to the system serif or sans (``OuroFont``), so text never disappears.
enum SpoonjoyFonts {
    /// Registers the bundled faces for this process. The app and the widget extension each call it once at launch;
    /// calling it again is harmless. A debug build or test run stops here if the bundle lacks a face or a licence, so
    /// a font never ships without its OFL text.
    static func registerBundled(in bundle: Bundle = .main) {
        let urls = KitchenFontFiles.urls(in: bundle)
        assert(urls.count == KitchenFontFiles.names.count, "\(bundle.bundleURL.lastPathComponent) is missing a bundled font")
        let missing = KitchenFontFiles.missingLicences(in: bundle)
        assert(missing.isEmpty, "\(bundle.bundleURL.lastPathComponent) is missing font licences: \(missing)")
        KitchenFontFiles.register(urls)
    }

    /// A cookbook text role as a font.
    static func resolve(_ type: OuroExtraType) -> Font {
        guard let token = OuroTokens.cookbook.extras.type[type] else {
            preconditionFailure("OuroHX's cookbook theme has no \(type.rawValue)")
        }
        return .ouro(token, in: OuroTokens.cookbook.extras)
    }

#if os(iOS) && !SPOONJOY_WIDGET_EXTENSION
    /// A navigation bar's large title is the screen's title, so it is set in the `largeTitle` role (Fraunces display),
    /// as web sets its page titles and the Mac sets its page headers. The bar itself stays the system's: the title
    /// still collapses inline on scroll (in the system face, like the bar's other chrome), names the back button and
    /// carries the header trait. Only the large title's font and ink change.
    @MainActor static func styleNavigationBarLargeTitles() {
        guard let font = navigationBarLargeTitleFont() else {
            return
        }
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: font,
            .foregroundColor: UIColor(KitchenTableTheme.ink),
        ]
    }

    /// The `largeTitle` role as a UIKit font, scaled with Dynamic Type relative to the large-title style, or nil when
    /// its face isn't registered, which leaves the system's large title.
    static func navigationBarLargeTitleFont() -> UIFont? {
        let token = KitchenTypeRole.largeTitle.token
        guard case .custom(let family) = OuroFont.resolve(token, in: OuroTokens.cookbook.extras),
              let face = OuroFont.face(family: family, weight: token.weight)
        else {
            return nil
        }
        var descriptor = UIFontDescriptor(name: face.postScriptName, size: token.size)
        if face.isVariable {
            // The weight and optical size SwiftUI's `Font.custom(_:size:).weight(_:)` gives the same face.
            let weightAxis = 0x7767_6874 // 'wght'
            let opticalSizeAxis = 0x6F70_737A // 'opsz'
            let axes: [Int: Double] = [weightAxis: Double(token.weight), opticalSizeAxis: token.size]
            descriptor = descriptor.addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): axes,
            ])
        }
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: UIFont(descriptor: descriptor, size: token.size))
    }
#endif
}
