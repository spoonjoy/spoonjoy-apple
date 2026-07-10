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
            noPhoto(subtitle: missingSubtitle, mode: .missing, showsLabel: showsFallbackLabel)
        }
    }

    private var imageTransaction: Transaction {
        Transaction(animation: accessibilityReduceMotion ? nil : .easeInOut(duration: 0.20))
    }

    private var missingSubtitle: String {
        guard let subtitle else {
            return "Photo not added"
        }

        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Photo not added" : trimmed
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
            noPhoto(subtitle: missingSubtitle, mode: .missing, showsLabel: showsFallbackLabel)
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
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .fill(KitchenTableTheme.paper)

            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .fill(KitchenTableTheme.vellum.opacity(mode == .loading ? 0.30 : 0.18))
                .padding(7)

            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                .strokeBorder(KitchenTableTheme.line.opacity(0.58), lineWidth: 1)
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
            if mode == .loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(KitchenTableTheme.brass)
            } else {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
            }
        }
        .shadow(color: KitchenTableTheme.charcoal.opacity(0.08), radius: 5, y: 3)
        .frame(width: 44, height: 44)
    }

    private var fullLabel: some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                    .fill(KitchenTableTheme.paper.opacity(0.94))
                    .frame(width: 48, height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                            .stroke(KitchenTableTheme.lineStrong.opacity(0.55), lineWidth: 1)
                    }
                if mode == .loading {
                    ProgressView()
                        .tint(KitchenTableTheme.brass)
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.brass)
                }
            }

            Text(displaySubtitle)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var displaySubtitle: String {
        subtitle
    }

    private var accessibilityLabel: Text {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return Text("\(title): \(displaySubtitle)")
        }

        return Text(displaySubtitle)
    }
}
