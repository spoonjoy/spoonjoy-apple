import CoreGraphics
import Foundation
import SpoonjoyCore
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The app-wide image pipeline: memory cache, then a bounded disk cache in Caches, then the network.
enum AppImagePipeline {
    static let shared = ImagePipeline.standard(
        cachesDirectory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    )
}

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

/// A cached stand-in for AsyncImage. It decodes to the size it is shown at, shows a memory-cached image on
/// its first frame, and drops its load when the view goes away without leaving anything half-written.
struct CachedAsyncImage<Content: View>: View {
    private struct LoadKey: Hashable {
        let url: URL
        let pixelSize: Int
    }

    let url: URL
    let animation: Animation?
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .empty
    @State private var pixelSize = 0
    /// The URL and size of the image on screen at full sharpness, if any. A smaller stand-in does not count.
    @State private var loaded: LoadKey?
    /// The URL of the image on screen, sharp or a smaller stand-in.
    @State private var shown: URL?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        content(phase)
            .onGeometryChange(for: Double.self) { proxy in
                max(proxy.size.width, proxy.size.height)
            } action: { points in
                let bucket = ImageDownsampleBucket.pixelSize(points: points, scale: displayScale)
                guard bucket != pixelSize else {
                    return
                }
                pixelSize = bucket
                let memory = AppImagePipeline.shared.memory
                if let cached = memory.image(url: url, maxPixelSize: bucket) {
                    phase = .success(Image(decorative: cached, scale: 1))
                    loaded = LoadKey(url: url, pixelSize: bucket)
                    shown = url
                } else if shown != url, let smaller = memory.image(url: url, below: bucket) {
                    // A smaller decode (say the list thumbnail) shows at once while the sharp one loads.
                    phase = .success(Image(decorative: smaller, scale: 1))
                    shown = url
                }
            }
            .task(id: LoadKey(url: url, pixelSize: pixelSize)) {
                // Load when nothing sharp enough is on screen, including when the view has grown since.
                if pixelSize == 0 || (loaded?.url == url && (loaded?.pixelSize ?? 0) >= pixelSize) {
                    return
                }
                let image = await AppImagePipeline.shared.image(for: url, maxPixelSize: pixelSize)
                guard !Task.isCancelled else {
                    return
                }
                if let image {
                    loaded = LoadKey(url: url, pixelSize: pixelSize)
                    shown = url
                    withAnimation(animation) {
                        phase = .success(Image(decorative: image, scale: 1))
                    }
                } else if shown != url {
                    withAnimation(animation) {
                        phase = .failure
                    }
                }
            }
    }
}
