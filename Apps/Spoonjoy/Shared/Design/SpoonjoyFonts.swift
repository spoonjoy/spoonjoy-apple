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
    /// calling it again is harmless.
    static func registerBundled(in bundle: Bundle = .main) {
        KitchenFontFiles.register(KitchenFontFiles.urls(in: bundle))
    }

    /// A cookbook text role as a font.
    static func resolve(_ type: OuroExtraType) -> Font {
        guard let token = OuroTokens.cookbook.extras.type[type] else {
            preconditionFailure("OuroHX's cookbook theme has no \(type.rawValue)")
        }
        return .ouro(token, in: OuroTokens.cookbook.extras)
    }
}
