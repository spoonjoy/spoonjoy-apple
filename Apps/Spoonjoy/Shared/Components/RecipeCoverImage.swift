import SwiftUI

#if os(macOS)
import AppKit
private typealias PlatformRecipeCoverImage = NSImage
#else
import UIKit
private typealias PlatformRecipeCoverImage = UIImage
#endif

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
            if url.isFileURL {
                LocalRecipeCoverImage(
                    url: url,
                    title: title,
                    loadingSubtitle: "Loading photo",
                    failureSubtitle: "Photo did not load",
                    showsFallbackLabel: showsFallbackLabel,
                    reduceMotion: accessibilityReduceMotion
                )
            } else {
                AsyncImage(url: url, transaction: imageTransaction) { phase in
                    let readinessPhase = readinessPhase(for: phase)
                    cover(for: phase)
                        .transition(accessibilityReduceMotion ? .identity : .opacity)
                        .task(id: readinessPhase) {
                            await record(readinessPhase, id: trackingID(for: url))
                        }
                }
                .id(url.absoluteString)
                .onDisappear {
                    let id = trackingID(for: url)
                    Task {
                        await ScreenshotVisualReadiness.removeMedia(id)
                    }
                }
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

    private func trackingID(for url: URL) -> String {
        "recipe-cover:\(url.absoluteString)"
    }

    private func readinessPhase(for phase: AsyncImagePhase) -> RecipeCoverReadinessPhase {
        switch phase {
        case .empty:
            .pending
        case .success:
            .loaded
        case .failure:
            .failed
        @unknown default:
            .failed
        }
    }

    private func record(_ phase: RecipeCoverReadinessPhase, id: String) async {
        switch phase {
        case .pending:
            await ScreenshotVisualReadiness.beginMedia(id)
        case .loaded:
            await ScreenshotVisualReadiness.finishMedia(id, succeeded: true)
        case .failed:
            await ScreenshotVisualReadiness.finishMedia(id, succeeded: false)
        }
    }
}

private enum RecipeCoverReadinessPhase: Hashable {
    case pending
    case loaded
    case failed
}

private struct LocalRecipeCoverImage: View {
    let url: URL
    let title: String?
    let loadingSubtitle: String
    let failureSubtitle: String
    let showsFallbackLabel: Bool
    let reduceMotion: Bool

    @State private var image: PlatformRecipeCoverImage?
    @State private var failed = false

    private var trackingID: String {
        "recipe-cover:\(url.absoluteString)"
    }

    var body: some View {
        ZStack {
            if let image {
                swiftUIImage(from: image)
                    .resizable()
                    .scaledToFill()
                    .transition(reduceMotion ? .identity : .opacity)
            } else {
                KitchenTableNoPhotoView(
                    title: title,
                    subtitle: failed ? failureSubtitle : loadingSubtitle,
                    mode: failed ? .unavailable : .loading,
                    showsLabel: failed && showsFallbackLabel
                )
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: image != nil)
        .task(id: url.absoluteString) {
            await ScreenshotVisualReadiness.beginMedia(trackingID)
            let data = await Task.detached(priority: .userInitiated) {
                try? Data(contentsOf: url, options: [.mappedIfSafe])
            }.value
            guard !Task.isCancelled else {
                return
            }
            guard let data, let decodedImage = PlatformRecipeCoverImage(data: data) else {
                failed = true
                await ScreenshotVisualReadiness.finishMedia(trackingID, succeeded: false)
                return
            }
            image = decodedImage
            failed = false
            await ScreenshotVisualReadiness.finishMedia(trackingID, succeeded: true)
        }
        .onDisappear {
            let id = trackingID
            Task {
                await ScreenshotVisualReadiness.removeMedia(id)
            }
        }
    }

    private func swiftUIImage(from image: PlatformRecipeCoverImage) -> Image {
#if os(macOS)
        Image(nsImage: image)
#else
        Image(uiImage: image)
#endif
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
                } else if mode == .loading || mode == .unavailable {
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
            Image(systemName: mode == .loading ? "photo" : "photo.badge.plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KitchenTableTheme.brass.opacity(mode == .loading ? 0.62 : 1))
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
                Image(systemName: mode == .loading ? "photo" : "photo.badge.plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass.opacity(mode == .loading ? 0.62 : 1))
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
