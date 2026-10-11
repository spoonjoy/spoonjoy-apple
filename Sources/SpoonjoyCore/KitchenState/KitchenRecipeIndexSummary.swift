import Foundation

/// The Kitchen's Recipe Index lists every saved recipe, the one leading the page included, so its count
/// matches the "N recipes" line under the masthead.
public struct KitchenRecipeIndexSummary: Equatable, Sendable {
    public let count: Int

    public init(recipeCount: Int) {
        count = max(0, recipeCount)
    }

    public var subtitle: String {
        "\(count) saved \(count == 1 ? "recipe" : "recipes")"
    }
}
