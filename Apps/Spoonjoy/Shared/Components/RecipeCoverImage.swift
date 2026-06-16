import SwiftUI

struct RecipeCoverImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            cover(for: phase)
        }
    }

    @ViewBuilder
    private func cover(for phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let image):
            image
                .resizable()
                .scaledToFill()
        case .empty, .failure:
            Image("LemonPantryPasta")
                .resizable()
                .scaledToFill()
        @unknown default:
            Image("LemonPantryPasta")
                .resizable()
                .scaledToFill()
        }
    }
}
