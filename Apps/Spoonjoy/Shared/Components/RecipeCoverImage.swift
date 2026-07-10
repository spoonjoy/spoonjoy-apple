import SwiftUI

struct RecipeCoverImage: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let url: URL?
    let title: String?
    let subtitle: String?
    let showsFallbackLabel: Bool

    init(url: URL?, title: String? = nil, subtitle: String? = nil, showsFallbackLabel: Bool = true) {
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.showsFallbackLabel = showsFallbackLabel
    }

    var body: some View {
        if let url {
            AsyncImage(url: url, transaction: imageTransaction) { phase in
                cover(for: phase)
                    .transition(accessibilityReduceMotion ? .identity : .opacity)
            }
        } else {
            noPhoto(subtitle: subtitle ?? "No photo yet", mode: .missing, showsLabel: showsFallbackLabel)
        }
    }

    private var imageTransaction: Transaction {
        Transaction(animation: accessibilityReduceMotion ? nil : .easeInOut(duration: 0.20))
    }

    @ViewBuilder
    private func cover(for phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let image):
            image
                .resizable()
                .scaledToFill()
        case .empty:
            noPhoto(subtitle: "Loading photo", mode: .loading, showsLabel: false)
        case .failure:
            noPhoto(subtitle: "Photo did not load", mode: .unavailable, showsLabel: showsFallbackLabel)
        @unknown default:
            noPhoto(subtitle: subtitle ?? "No photo yet", mode: .missing, showsLabel: showsFallbackLabel)
        }
    }

    private func noPhoto(subtitle: String, mode: KitchenTableNoPhotoView.Mode, showsLabel: Bool) -> some View {
        KitchenTableNoPhotoView(title: title, subtitle: subtitle, mode: mode, showsLabel: showsLabel)
    }
}

struct KitchenTableNoPhotoView: View {
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
            noPhotoBackground

            GeometryReader { proxy in
                if proxy.size.width < 150 || proxy.size.height < 110 {
                    compactMark
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                } else if showsLabel {
                    fullLabel
                        .padding(16)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var noPhotoBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    KitchenTableTheme.paper,
                    KitchenTableTheme.vellum.opacity(0.78),
                    KitchenTableTheme.bone
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 11) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? KitchenTableTheme.brass.opacity(0.12) : KitchenTableTheme.herb.opacity(0.09))
                        .frame(height: index == 1 ? 7 : 5)
                        .padding(.horizontal, CGFloat(22 + index * 15))
                        .offset(x: index.isMultiple(of: 2) ? -8 : 10)
                }
            }
            .rotationEffect(.degrees(-5))
            .opacity(0.82)
        }
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
                Image(systemName: "fork.knife.circle")
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
            Image(systemName: mode == .loading ? "clock" : "fork.knife.circle")
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

    private var palette: KitchenTableNoPhotoPalette {
        KitchenTableNoPhotoPalette.palette(for: title ?? subtitle)
    }
}

private struct KitchenTableNoPhotoPalette {
    let accent: Color

    static func palette(for key: String) -> KitchenTableNoPhotoPalette {
        switch stableBucket(for: key) {
        case 0:
            KitchenTableNoPhotoPalette(accent: KitchenTableTheme.brass)
        case 1:
            KitchenTableNoPhotoPalette(accent: KitchenTableTheme.herb)
        case 2:
            KitchenTableNoPhotoPalette(accent: KitchenTableTheme.tomato)
        default:
            KitchenTableNoPhotoPalette(accent: KitchenTableTheme.inkMuted)
        }
    }

    private static func stableBucket(for key: String) -> Int {
        let scalars = key.unicodeScalars.map { Int($0.value) }
        return scalars.reduce(0, +) % 4
    }
}
