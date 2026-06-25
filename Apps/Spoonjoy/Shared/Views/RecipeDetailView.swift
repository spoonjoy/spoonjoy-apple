import SpoonjoyCore
import SwiftUI

struct RecipeDetailRouteView: View {
    let recipeID: String
    let repository: any RecipeCatalogRepository
    let context: (Recipe) -> RecipeDetailContext
    let openRoute: (AppRoute) -> Void

    @State private var viewModel: RecipeDetailScreenViewModel?
    @State private var errorMessage: String?

    init(
        recipeID: String,
        repository: any RecipeCatalogRepository,
        initialViewModel: RecipeDetailScreenViewModel?,
        context: @escaping (Recipe) -> RecipeDetailContext,
        openRoute: @escaping (AppRoute) -> Void
    ) {
        self.recipeID = recipeID
        self.repository = repository
        self.context = context
        self.openRoute = openRoute
        _viewModel = State(initialValue: initialViewModel)
    }

    var body: some View {
        Group {
            if let viewModel {
                RecipeDetailView(viewModel: viewModel, openRoute: openRoute)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "text.book.closed")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .background(KitchenTableTheme.bone)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KitchenTableTheme.bone)
            }
        }
        .task(id: recipeID) {
            await loadRecipe()
        }
    }

    @MainActor private func loadRecipe() async {
        do {
            let result = try await repository.recipeDetail(id: recipeID)
            viewModel = RecipeDetailScreenViewModel(result: result, context: context(result.recipe))
            errorMessage = nil
        } catch {
            if viewModel == nil {
                errorMessage = "Recipe unavailable."
            }
        }
    }
}

struct RecipeDetailView: View {
    let viewModel: RecipeDetailScreenViewModel
    let openRoute: (AppRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                offlineIndicator
                hero
                cookbookSpread
                ingredientReceipt
                method
                spoonSummary
                cookbookSave
                ownerTools
            }
            .padding()
        }
        .background(KitchenTableTheme.bone)
    }

    private var provenance: String {
        viewModel.cover.provenanceLabel ?? viewModel.recipe.attribution.creditText
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecipeCoverImage(url: viewModel.cover.imageURL)
            .frame(maxWidth: .infinity, minHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            .overlay(alignment: .bottomLeading) {
                Text(provenance)
                    .font(KitchenTableTheme.uiLabel)
                    .padding(8)
                    .background(KitchenTableTheme.photoOverlay)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("\(viewModel.title) cover image")

            Text(viewModel.title)
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(viewModel.description ?? viewModel.recipe.attribution.creditText)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.secondary)

            Text(viewModel.chefAttribution)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)

            if let servingsLabel = viewModel.servingsLabel {
                Text(servingsLabel)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }

            if let sourceAttribution = viewModel.sourceAttribution {
                Label(sourceText(sourceAttribution), systemImage: "link")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Start Cooking") { openRoute(viewModel.actions.startCookingRoute) }
                    .buttonStyle(.borderedProminent)
                ShareLink(item: viewModel.actions.shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var ingredientReceipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredient Receipt")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(viewModel.ingredientReceipt.rows) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Text(ingredient.quantityText)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var cookbookSpread: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cookbook Spread")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(viewModel.recipe.cookbooks, id: \.id) { cookbook in
                HStack {
                    Label(cookbook.title, systemImage: "book.closed")
                    Spacer()
                    Text(cookbook.canonicalURL.host() ?? "spoonjoy.app")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.brass)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method")
                .font(.title2)
            ForEach(viewModel.methodSections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(section.stepNumber). \(section.title)")
                        .font(.headline)
                        .foregroundStyle(KitchenTableTheme.charcoal)

                    if !section.dependencies.isEmpty {
                        ForEach(section.dependencies, id: \.label) { dependency in
                            Label(dependency.label, systemImage: "arrow.triangle.branch")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                        }
                    }

                    Text(section.body)
                        .font(KitchenTableTheme.bodyNote)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var spoonSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Spoons")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            if viewModel.spoonSummary.rows.isEmpty {
                Text("No recent cooks yet.")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.spoonSummary.rows) { spoon in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(spoon.chefLine, systemImage: "fork.knife")
                            .font(.headline)
                            .foregroundStyle(KitchenTableTheme.charcoal)
                        if let note = spoon.note {
                            Text(note)
                                .font(KitchenTableTheme.bodyNote)
                                .foregroundStyle(.secondary)
                        }
                        if let nextTime = spoon.nextTime {
                            Text(nextTime)
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var cookbookSave: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save To Cookbook")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)

            ForEach(viewModel.cookbookSave.availableCookbooks) { cookbook in
                Label(
                    cookbook.title,
                    systemImage: viewModel.cookbookSave.isSaved(in: cookbook.id) ? "checkmark.circle.fill" : "circle"
                )
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(viewModel.cookbookSave.isSaved(in: cookbook.id) ? KitchenTableTheme.herb : .secondary)
            }

            if viewModel.hasIngredientsInShoppingList {
                Label("Ingredients are on your shopping list", systemImage: "checklist")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
            }
        }
    }

    @ViewBuilder private var ownerTools: some View {
        if viewModel.ownerTools.isVisible {
            VStack(alignment: .leading, spacing: 10) {
                Text("Owner Tools")
                    .font(.title2)
                    .foregroundStyle(KitchenTableTheme.charcoal)

                Button {
                    openRoute(.recipeEditor(id: viewModel.id))
                } label: {
                    Label("Edit Recipe", systemImage: "pencil")
                }
                .font(KitchenTableTheme.bodyNote)
            }
        }
    }

    @ViewBuilder private var offlineIndicator: some View {
        if viewModel.offlineIndicator.display != .synced {
            OfflineStatusView(display: viewModel.offlineIndicator.display)
        }
    }

    private func sourceText(_ attribution: RecipeDetailSourceAttribution) -> String {
        if let host = attribution.host {
            return "\(attribution.title) from \(host)"
        }

        return attribution.title
    }
}
