import SpoonjoyCore
import SwiftUI

private struct SpoonjoyAddRecipeToListKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Recipe) -> Void)? = nil
}

extension EnvironmentValues {
    /// Adds a recipe's ingredients to the shopping list. The shell supplies it; without it rows offer no Add to list.
    var spoonjoyAddRecipeToList: (@MainActor (Recipe) -> Void)? {
        get { self[SpoonjoyAddRecipeToListKey.self] }
        set { self[SpoonjoyAddRecipeToListKey.self] = newValue }
    }
}

/// One recipe in a list: the photo (or a designed initial tile), the title in the serif and one quiet line.
/// Tapping opens the recipe; long-pressing previews it with Share and Add to list. The Kitchen and the Recipes
/// tab share it. The thumbnail is the zoom transition's source (`matchedTransitionSource(id: recipe id, in:)`).
struct RecipeIndexRow: View {
    private let content: RecipeIndexRowContent
    private let namespace: Namespace.ID
    /// The recipe's place in an ordered list, such as a cookbook's contents; nil for an unordered list.
    private let ordinal: Int?
    private let action: () -> Void

    @Environment(\.spoonjoyAddRecipeToList) private var addRecipeToList
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledThumbnail = RecipeIndexRowMetrics.thumbnail

    /// Grows with the text, up to a size that still leaves the title room on a phone.
    private var thumbnailSize: CGFloat {
        min(scaledThumbnail, RecipeIndexRowMetrics.maximumThumbnail)
    }

    init(recipe: Recipe, namespace: Namespace.ID, action: @escaping () -> Void) {
        self.content = RecipeIndexRowContent(recipe: recipe)
        self.namespace = namespace
        self.ordinal = nil
        self.action = action
    }

    init(row: RecipeCatalogRowViewModel, namespace: Namespace.ID, action: @escaping () -> Void) {
        self.content = RecipeIndexRowContent(row: row)
        self.namespace = namespace
        self.ordinal = nil
        self.action = action
    }

    /// A recipe from a list that only has its summary, such as a search result, a profile or a cookbook's contents.
    /// `accessibilityLabel` replaces the title-and-line label when the source already composes one.
    init(
        id: String,
        title: String,
        detail: String?,
        coverURL: URL?,
        shareURL: URL? = nil,
        accessibilityLabel: String? = nil,
        ordinal: Int? = nil,
        namespace: Namespace.ID,
        action: @escaping () -> Void
    ) {
        self.content = RecipeIndexRowContent(
            id: id,
            title: title,
            detail: detail,
            coverURL: coverURL,
            shareURL: shareURL,
            accessibilityLabel: accessibilityLabel
        )
        self.namespace = namespace
        self.ordinal = ordinal
        self.action = action
    }

    var body: some View {
        // At the accessibility text sizes the photo sits above the text, so the title and line wrap in full.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        Button(action: action) {
            layout {
                if let ordinal, !dynamicTypeSize.isAccessibilitySize {
                    ordinalText(ordinal)
                        .frame(minWidth: 24, alignment: .leading)
                }
                RecipeIndexThumbnail(title: content.title, coverURL: content.coverURL)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .matchedTransitionSource(id: content.id, in: namespace)
                VStack(alignment: .leading, spacing: 2) {
                    // At the accessibility sizes the number leads the text, over the title.
                    if let ordinal, dynamicTypeSize.isAccessibilitySize {
                        ordinalText(ordinal)
                    }
                    Text(content.title)
                        .font(KitchenTableTheme.indexTitle)
                        .foregroundStyle(KitchenTableTheme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = content.detail {
                        Text(detail)
                            .font(KitchenTableTheme.meta)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .multilineTextAlignment(.leading)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityHint("Opens the recipe")
        .contextMenu {
            if let shareURL = content.shareURL {
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            if let recipe = content.recipe, let addRecipeToList, recipe.steps.contains(where: { !$0.ingredients.isEmpty }) {
                Button {
                    addRecipeToList(recipe)
                } label: {
                    Label("Add to list", systemImage: "cart.badge.plus")
                }
            }
        } preview: {
            RecipeIndexRowPreview(content: content)
        }
    }
}

extension RecipeIndexRow {
    private func ordinalText(_ ordinal: Int) -> some View {
        Text(ordinal < 10 ? "0\(ordinal)" : "\(ordinal)")
            .font(.caption.weight(.bold).monospacedDigit())
            .tracking(1.0)
            .foregroundStyle(KitchenTableTheme.brass)
            .accessibilityHidden(true)
    }
}

/// The separator between rows, inset to start under the title as the system lists do.
struct RecipeIndexRowSeparator: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledThumbnail = RecipeIndexRowMetrics.thumbnail

    var body: some View {
        Rectangle()
            .fill(KitchenTableTheme.hairline)
            .frame(height: KitchenTableTheme.hairlineWidth)
            .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : min(scaledThumbnail, RecipeIndexRowMetrics.maximumThumbnail) + 14)
            .accessibilityHidden(true)
    }
}

private enum RecipeIndexRowMetrics {
    static let thumbnail: CGFloat = 64
    static let maximumThumbnail: CGFloat = 112
    static let thumbnailRadius: CGFloat = 14
}

private struct RecipeIndexRowContent {
    let id: String
    let title: String
    let detail: String?
    /// What VoiceOver reads: the title, the line under it and, when the line leaves it out, who wrote it.
    let accessibilityLabel: String
    let coverURL: URL?
    let shareURL: URL?
    /// The full recipe, when the list has it; only full recipes can add their ingredients to the list.
    let recipe: Recipe?

    init(recipe: Recipe) {
        id = recipe.id
        title = recipe.title
        detail = Self.detail([recipe.displaySubtitle, recipe.servings.map { "Serves \($0)" }, recipe.displayCoverProvenanceLabel])
        accessibilityLabel = Self.accessibilityLabel(title: recipe.title, detail: detail, chef: recipe.chef.username)
        coverURL = recipe.displayCoverImageURL
        shareURL = recipe.attribution.canonicalURL
        self.recipe = recipe
    }

    init(row: RecipeCatalogRowViewModel) {
        id = row.id
        title = row.title
        detail = Self.detail([row.subtitle, row.chefLine, row.servingsLabel])
        accessibilityLabel = Self.accessibilityLabel(title: row.title, detail: detail, chef: nil)
        coverURL = row.coverImageURL
        shareURL = row.shareURL
        recipe = nil
    }

    init(id: String, title: String, detail: String?, coverURL: URL?, shareURL: URL?, accessibilityLabel: String?) {
        self.id = id
        self.title = title
        self.detail = Self.detail([detail])
        self.accessibilityLabel = accessibilityLabel ?? Self.accessibilityLabel(title: title, detail: self.detail, chef: nil)
        self.coverURL = coverURL
        self.shareURL = shareURL
        recipe = nil
    }

    private static func accessibilityLabel(title: String, detail: String?, chef: String?) -> String {
        let byline = chef.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : "by \($0)" }
        return [title, detail, byline].compactMap { $0 }.joined(separator: ", ")
    }

    private static func detail(_ parts: [String?]) -> String? {
        let joined = parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return joined.isEmpty ? nil : joined
    }
}

/// The photo, or a designed tile with the title's initial when there is none.
private struct RecipeIndexThumbnail: View {
    let title: String
    let coverURL: URL?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RecipeIndexRowMetrics.thumbnailRadius, style: .continuous)
        Group {
            if let coverURL {
                RecipeCoverImage(url: coverURL, title: title, subtitle: nil, showsFallbackLabel: false)
                    .scaledToFill()
            } else {
                RecipeInitialTile(title: title)
            }
        }
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// A recipe with no photo: a warm vellum tile with the title's first letter in the serif.
struct RecipeInitialTile: View {
    let title: String

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [KitchenTableTheme.vellum, KitchenTableTheme.brass.opacity(0.32)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // The letter is decoration sized to the tile, not text to read, so it scales with the tile
                // (a Large Title is 34 points at the default text size) instead of with Dynamic Type.
                Text(initial)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .dynamicTypeSize(.large)
                    .foregroundStyle(KitchenTableTheme.brass)
                    .scaleEffect(proxy.size.height * 0.42 / 34)
            }
        }
    }

    private var initial: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "S"
    }
}

/// The long-press preview: the photo large, with the title under it.
private struct RecipeIndexRowPreview: View {
    let content: RecipeIndexRowContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let coverURL = content.coverURL {
                    RecipeCoverImage(url: coverURL, title: content.title, subtitle: nil, showsFallbackLabel: false)
                        .scaledToFill()
                } else {
                    RecipeInitialTile(title: content.title)
                }
            }
            .frame(width: 300, height: 220)
            .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(KitchenTableTheme.indexTitle)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .lineLimit(2)
                if let detail = content.detail {
                    Text(detail)
                        .font(KitchenTableTheme.meta)
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
        }
        .background(KitchenTableTheme.raised)
    }
}
