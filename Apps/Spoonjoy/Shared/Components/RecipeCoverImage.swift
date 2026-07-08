import SwiftUI

struct RecipeCoverImage: View {
    let url: URL?
    let title: String?
    let subtitle: String?
    let assetName: String?
    let showsFallbackLabel: Bool

    init(url: URL?, title: String? = nil, subtitle: String? = nil, assetName: String? = nil, showsFallbackLabel: Bool = true) {
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.assetName = assetName
        self.showsFallbackLabel = showsFallbackLabel
    }

    var body: some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.22))) { phase in
                cover(for: phase)
                    .transition(.opacity)
            }
        } else if let assetName {
            bundledCover(assetName)
        } else if let loadingFallbackAssetName {
            bundledCover(loadingFallbackAssetName)
        } else {
            RecipeCoverFallback(title: title, subtitle: subtitle ?? "Cover coming soon", mode: .missing, showsLabel: showsFallbackLabel)
        }
    }

    static func bundledAssetName(forRecipeID recipeID: String) -> String? {
        switch recipeID {
        case "recipe_lemon_pantry_pasta":
            "LemonPantryPasta"
        default:
            nil
        }
    }

    @ViewBuilder
    private func cover(for phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let image):
            image
                .resizable()
                .scaledToFill()
        case .empty:
            if let loadingFallbackAssetName {
                bundledCover(loadingFallbackAssetName)
            } else {
                RecipeCoverFallback(title: title, subtitle: "Loading cover", mode: .loading, showsLabel: false)
            }
        case .failure:
            if let loadingFallbackAssetName {
                bundledCover(loadingFallbackAssetName)
            } else {
                RecipeCoverFallback(title: title, subtitle: "Cover unavailable", mode: .unavailable, showsLabel: showsFallbackLabel)
            }
        @unknown default:
            if let loadingFallbackAssetName {
                bundledCover(loadingFallbackAssetName)
            } else {
                RecipeCoverFallback(title: title, subtitle: subtitle ?? "Cover coming soon", mode: .missing, showsLabel: showsFallbackLabel)
            }
        }
    }

    private var loadingFallbackAssetName: String? {
        assetName ?? Self.fallbackFoodAssetName(forTitle: title)
    }

    static func fallbackFoodAssetName(forTitle title: String?) -> String? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        let lowercasedTitle = title.lowercased()
        if lowercasedTitle.contains("hummus") {
            return "RecipeFallbackHummus"
        }
        if lowercasedTitle.contains("challah") {
            return "RecipeFallbackChallah"
        }
        if lowercasedTitle.contains("cinnamon") || lowercasedTitle.contains("bun") {
            return "RecipeFallbackBuns"
        }
        if lowercasedTitle.contains("bread") || lowercasedTitle.contains("rye") {
            return "RecipeFallbackBread"
        }
        if lowercasedTitle.contains("pizza") {
            return "RecipeFallbackPizza"
        }

        let fallbacks = [
            "RecipeFallbackHummus",
            "RecipeFallbackChallah",
            "RecipeFallbackBuns",
            "RecipeFallbackBread",
            "RecipeFallbackPizza"
        ]
        let bucket = title.unicodeScalars.map { Int($0.value) }.reduce(0, +) % fallbacks.count
        return fallbacks[bucket]
    }

    private func bundledCover(_ assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
    }
}

private struct RecipeCoverFallback: View {
    enum Mode {
        case missing
        case loading
        case unavailable
    }

    let title: String?
    let subtitle: String
    let mode: Mode
    let showsLabel: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                if proxy.size.width < 150 || proxy.size.height < 110 {
                    compactMark
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                } else if showsLabel {
                    fullLabel
                        .padding(16)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var compactMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .fill(KitchenTableTheme.paper.opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                        .stroke(KitchenTableTheme.lineStrong.opacity(0.55), lineWidth: 1)
                }
                .frame(width: 38, height: 38)
            if showsLabel, let initials {
                Text(initials)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .minimumScaleFactor(0.75)
            } else if mode == .loading {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
            }
        }
        .shadow(color: KitchenTableTheme.charcoal.opacity(0.08), radius: 5, y: 3)
        .frame(width: 44, height: 44)
    }

    private var initials: String? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        let letters = title
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()

        return letters.isEmpty ? nil : letters
    }

    private var fullLabel: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: mode == .loading ? "clock" : "photo")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                        .stroke(KitchenTableTheme.lineStrong.opacity(0.55), lineWidth: 1)
                }

            Text(subtitle)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var accessibilityLabel: Text {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return Text("\(title): \(subtitle)")
        }

        return Text(subtitle)
    }

    private var palette: RecipeCoverFallbackPalette {
        RecipeCoverFallbackPalette.palette(for: title ?? subtitle)
    }
}

private struct RecipeCoverFallbackPalette {
    let background: [Color]
    let accent: Color

    static func palette(for key: String) -> RecipeCoverFallbackPalette {
        switch stableBucket(for: key) {
        case 0:
            RecipeCoverFallbackPalette(
                background: [KitchenTableTheme.paper, KitchenTableTheme.bone],
                accent: KitchenTableTheme.brass
            )
        case 1:
            RecipeCoverFallbackPalette(
                background: [KitchenTableTheme.paper, KitchenTableTheme.vellum.opacity(0.72)],
                accent: KitchenTableTheme.herb
            )
        case 2:
            RecipeCoverFallbackPalette(
                background: [KitchenTableTheme.paper, KitchenTableTheme.tomato.opacity(0.10)],
                accent: KitchenTableTheme.tomato
            )
        default:
            RecipeCoverFallbackPalette(
                background: [KitchenTableTheme.paper, KitchenTableTheme.vellum.opacity(0.82)],
                accent: KitchenTableTheme.inkMuted
            )
        }
    }

    private static func stableBucket(for key: String) -> Int {
        let scalars = key.unicodeScalars.map { Int($0.value) }
        return scalars.reduce(0, +) % 4
    }
}
