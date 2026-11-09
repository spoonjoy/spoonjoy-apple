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

    /// Each typeface's SIL Open Font License text, which ships beside its fonts and in the app's acknowledgements.
    public static let licences = [
        (typeface: "Fraunces", file: "OFL-Fraunces.txt"),
        (typeface: "Source Serif 4", file: "OFL-SourceSerif4.txt"),
        (typeface: "IBM Plex Sans Condensed", file: "OFL-IBMPlexSansCondensed.txt")
    ]

    /// The licence texts a bundle carries, each with its typeface, in the order of ``licences``.
    public static func licenceTexts(in bundle: Bundle) -> [(typeface: String, text: String)] {
        licences.compactMap { licence in
            let file = licence.file as NSString
            guard let url = bundle.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return (licence.typeface, text)
        }
    }

    /// The licence files a bundle is missing, or carries as something other than UTF-8 text. The app asserts this is
    /// empty at launch, so a debug build or a test run stops on a bundle that ships a font without its licence.
    public static func missingLicences(in bundle: Bundle) -> [String] {
        let present = Set(licenceTexts(in: bundle).map(\.typeface))
        return licences.filter { !present.contains($0.typeface) }.map(\.file)
    }

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
