import CoreText
import Foundation

/// The font files Spoonjoy bundles, web's three typefaces, and their registration with Core Text for this process.
///
/// This file imports only Foundation and Core Text because the widget extension compiles it too. Registering at run
/// time, rather than through `UIAppFonts` or `ATSApplicationFontsPath`, works the same way in the iOS app, the Mac app
/// and the widget.
public enum KitchenFontFiles {
    /// Every bundled face: Fraunces and Source Serif 4 as variable fonts, IBM Plex Sans Condensed in four weights.
    public static let names = [
        "Fraunces[SOFT,WONK,opsz,wght].ttf",
        "SourceSerif4[opsz,wght].ttf",
        "IBMPlexSansCondensed-Regular.ttf",
        "IBMPlexSansCondensed-Medium.ttf",
        "IBMPlexSansCondensed-SemiBold.ttf",
        "IBMPlexSansCondensed-Bold.ttf"
    ]

    /// The bundled faces a bundle carries. A missing one is left out, and the text it would set falls back to the
    /// system font.
    public static func urls(in bundle: Bundle) -> [URL] {
        names.compactMap { name in
            let file = name as NSString
            return bundle.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension)
        }
    }

    /// Registers fonts for this process and answers the ones that failed. A font already registered counts as done,
    /// so calling it twice is harmless.
    @discardableResult
    public static func register(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return false }
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
            return code != CTFontManagerError.alreadyRegistered.rawValue
        }
    }
}
