import SwiftUI

struct RecipeCoverImage: View {
    let url: URL?
    let title: String?
    let subtitle: String?
    let assetName: String?

    init(url: URL?, title: String? = nil, subtitle: String? = nil, assetName: String? = nil) {
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.assetName = assetName
    }

    var body: some View {
        if let assetName {
            bundledCover(assetName)
        } else if let url {
            AsyncImage(url: url) { phase in
                cover(for: phase)
            }
        } else {
            RecipeCoverFallback(title: title, subtitle: subtitle ?? "No cover yet", mode: .missing)
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
            RecipeCoverFallback(title: title, subtitle: "Loading cover", mode: .loading)
        case .failure:
            if let assetName {
                bundledCover(assetName)
            } else {
                RecipeCoverFallback(title: title, subtitle: "Cover unavailable", mode: .unavailable)
            }
        @unknown default:
            if let assetName {
                bundledCover(assetName)
            } else {
                RecipeCoverFallback(title: title, subtitle: subtitle ?? "No cover yet", mode: .missing)
            }
        }
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            garnish

            GeometryReader { proxy in
                if proxy.size.width < 150 || proxy.size.height < 110 {
                    compactMark
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                } else {
                    fullLabel
                        .padding(16)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var garnish: some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.18))
                .frame(width: 148, height: 148)
                .offset(x: -68, y: -46)
            Circle()
                .stroke(palette.accent.opacity(0.42), lineWidth: 2)
                .frame(width: 92, height: 92)
                .offset(x: 82, y: 46)
            Capsule()
                .fill(KitchenTableTheme.herb.opacity(0.16))
                .frame(width: 142, height: 16)
                .rotationEffect(.degrees(-18))
                .offset(x: 38, y: -16)
            Capsule()
                .fill(KitchenTableTheme.tomato.opacity(0.14))
                .frame(width: 112, height: 12)
                .rotationEffect(.degrees(16))
                .offset(x: -36, y: 30)
        }
        .accessibilityHidden(true)
    }

    private var compactMark: some View {
        ZStack {
            Circle()
                .fill(KitchenTableTheme.paper.opacity(0.90))
                .overlay {
                    Circle()
                        .stroke(palette.accent.opacity(0.35), lineWidth: 1)
                }
                .frame(width: 38, height: 38)
            if let initials {
                Text(initials)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .minimumScaleFactor(0.75)
            } else if mode == .loading {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.accent)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
        }
        .shadow(color: KitchenTableTheme.charcoal.opacity(0.10), radius: 4, y: 2)
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
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: mode == .loading ? "clock" : "fork.knife")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.accent)
            if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.bold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            Text(subtitle)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                background: [KitchenTableTheme.paper, Color(red: 0.95, green: 0.90, blue: 0.79)],
                accent: KitchenTableTheme.brass
            )
        case 1:
            RecipeCoverFallbackPalette(
                background: [Color(red: 0.94, green: 0.96, blue: 0.88), KitchenTableTheme.paper],
                accent: KitchenTableTheme.herb
            )
        case 2:
            RecipeCoverFallbackPalette(
                background: [Color(red: 0.98, green: 0.91, blue: 0.86), KitchenTableTheme.paper],
                accent: KitchenTableTheme.tomato
            )
        default:
            RecipeCoverFallbackPalette(
                background: [Color(red: 0.92, green: 0.94, blue: 0.91), Color(red: 0.98, green: 0.96, blue: 0.90)],
                accent: Color(red: 0.22, green: 0.34, blue: 0.38)
            )
        }
    }

    private static func stableBucket(for key: String) -> Int {
        let scalars = key.unicodeScalars.map { Int($0.value) }
        return scalars.reduce(0, +) % 4
    }
}
