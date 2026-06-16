import SpoonjoyCore
import SwiftUI

struct CookbooksView: View {
    let cookbooks: [Cookbook]
    let openCookbook: (String) -> Void

    var body: some View {
        ScrollView {
            CookbookShelf(cookbooks: cookbooks, openCookbook: openCookbook)
                .padding()
        }
        .background(KitchenTableTheme.bone)
    }
}

struct CookbookShelf: View {
    let cookbooks: [Cookbook]
    let openCookbook: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cookbook Shelf")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(cookbooks, id: \.id) { cookbook in
                        Button {
                            openCookbook(cookbook.id)
                        } label: {
                            CookbookCoverView(cookbook: cookbook)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct CookbookCoverView: View {
    let cookbook: Cookbook
    private var cover: CookbookCover {
        cookbook.cover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                    .fill(KitchenTableTheme.brass.opacity(0.18))
                    .aspectRatio(3 / 4, contentMode: .fit)
                if let imageURL = cover.primaryImageURL {
                    RecipeCoverImage(url: imageURL)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                    .accessibilityHidden(true)
                }
            }
            .frame(width: 120)

            Text(cookbook.title)
                .font(.headline)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text("\(cookbook.recipeCount) recipes")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(.secondary)
        }
        .frame(width: 132, alignment: .leading)
    }
}
