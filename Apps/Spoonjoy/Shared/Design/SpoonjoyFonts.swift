import OuroHX
#if !SPOONJOY_WIDGET_EXTENSION
// The widget extension does not link SpoonjoyCore, so it compiles KitchenFontFiles.swift itself.
import SpoonjoyCore
#endif
import SwiftUI

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
}
