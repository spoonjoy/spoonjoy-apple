import Foundation
import OuroReins
import SpoonjoyCore

/// Spoonjoy's phone shell without SwiftUI: the live store plus the two navigation models the shell already keeps in
/// SpoonjoyCore (`AppNavigationState`, `CompactTabNavigation`), driven by Ouro Reins.
///
/// SPIKE. Each method below copies the few lines a binding or button handler runs in
/// `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift` (cited per method). That glue is the one part of the
/// shell that lives in SwiftUI today; an adoption moves it into SpoonjoyCore once, so the view and Reins call the same
/// code instead of two copies.
@MainActor
public final class SpoonjoyReinsShell {
    public let store: NativeLiveAppStore
    public private(set) var navigation = AppNavigationState()
    public private(set) var compactTabs = CompactTabNavigation()
    private let timestamp: () -> String

    public init(store: NativeLiveAppStore, timestamp: @escaping () -> String = { ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_793_000_000)) }) {
        self.store = store
        self.timestamp = timestamp
    }

    public var content: NativeShellContentState { store.bootstrapState.contentState }

    // MARK: The shell's glue

    /// `navigation.navigate(to:)`, then the compact shell follows the route (its `.onChange(of: navigation.route)`).
    func navigate(to route: AppRoute, restoring: Bool = false) {
        navigation.navigate(to: route, restoring: restoring)
        compactTabs.apply(navigation.route)
    }

    /// `selectCompactTab(_:)`.
    func select(_ tab: CompactTab) {
        let route = compactTabs.select(tab)
        if route != navigation.route { navigate(to: route, restoring: true) }
    }

    /// The back button and edge swipe: `compactPath(for:)`'s setter with the top page dropped.
    func goBack() {
        let tab = compactTabs.selectedTab
        let route = compactTabs.setPath(Array(compactTabs.path(for: tab).dropLast()), for: tab)
        if route != navigation.route { navigate(to: route, restoring: true) }
    }

    /// Closing cook mode: `compactFullScreenRoute`'s setter when the cover is dismissed.
    func closeCook() {
        navigate(to: compactTabs.dismissFullScreen())
    }

    /// `openRecipe(_:)`.
    func openRecipe(_ id: String) { navigate(to: .recipeDetail(id: id, presentation: .detail)) }

    /// `startCooking(_:)`, then CookModeView's `.onAppear`, which tells the store cook mode opened.
    func startCooking(_ id: String) {
        navigate(to: .recipeDetail(id: id, presentation: .cook))
        store.cookModeOpened(recipeID: id)
    }

    /// `cookProgress(for:)`.
    func cookProgress(for recipe: Recipe) -> CookModeProgress {
        content.cookProgress(for: recipe.id) ?? CookModeProgress.starting(recipe: recipe, startedAt: timestamp())
    }

    /// CookModeView's `advance()` and `previous()`: the view model's next progress, handed to `progressDidChange`.
    func turn(_ recipe: Recipe, forward: Bool) {
        let model = CookModeViewModel(recipe: recipe, progress: cookProgress(for: recipe))
        store.recordCookProgress(forward ? model.progressAfterSelectingNext(updatedAt: timestamp()) : model.progressAfterSelectingPrevious(updatedAt: timestamp()))
    }

    /// An ingredient row's checkbox binding.
    func check(_ recipe: Recipe, ingredient id: String, checked: Bool) throws {
        let model = CookModeViewModel(recipe: recipe, progress: cookProgress(for: recipe))
        store.recordCookProgress(try model.progressAfterTogglingIngredient(id: id, checked: checked, updatedAt: timestamp()))
    }
}

// MARK: - Nodes

struct RecipeID: ReinsInput {
    let id: String
}

struct IngredientCheck: ReinsInput {
    let id: String
    let checked: Bool
}

extension SpoonjoyReinsShell: ReinsDrivable {
    public var reinsNode: ReinsNode {
        let tabs = CompactTab.allCases.map(\.rawValue)
        let tabbed = ReinsNode.tabs(selected: compactTabs.selectedTab.rawValue, tabs: tabs, select: { [unowned self] in
            if let tab = CompactTab(rawValue: $0) { self.select(tab) }
        }, child: tabStack)
        guard let cover = compactTabs.fullScreenRoute, case .recipeDetail(let id, .cook) = cover, let recipe = content.recipe(id: id) else {
            return ReinsNode("spoonjoy", state: shellState, child: tabbed)
        }
        // Cook mode covers the tabs (CompactRoutePlacement.fullScreen): the tab bar isn't reachable, so it isn't in the
        // tree; the cover lends the way back.
        let cook = ReinsNode("cover", state: ["route": .string(cover.stateIdentifier)], lends: [
            ReinsAction("goBack", "Close cook mode") { [unowned self] in self.closeCook() },
        ], child: cookNode(recipe))
        return ReinsNode("spoonjoy", state: shellState, child: cook)
    }

    private var shellState: ReinsValue {
        ["route": .string(navigation.route.stateIdentifier), "bootstrap": .string(bootstrapName)]
    }

    private var bootstrapName: String {
        String(describing: store.bootstrapState).split(separator: "(").first.map(String.init) ?? "unknown"
    }

    private var tabStack: ReinsNode {
        let tab = compactTabs.selectedTab
        return .stack(depth: compactTabs.path(for: tab).count, goBack: { [unowned self] in self.goBack() }, child: page(for: compactTabs.visibleRoute))
    }

    private func page(for route: AppRoute) -> ReinsNode {
        switch route {
        case .kitchen: kitchenNode
        case .recipeDetail(let id, .detail): content.recipe(id: id).map(recipeNode) ?? ReinsNode("missing", state: ["route": .string(route.stateIdentifier)])
        default: ReinsNode(route.stateIdentifier.split(separator: ":").first.map(String.init) ?? "page", state: ["route": .string(route.stateIdentifier), "x-unmodelled": "the spike models kitchen, recipe and cook only"])
        }
    }

    private var kitchenNode: ReinsNode {
        let ids = content.recipes.map(\.id)
        var lead: ReinsValue = .null
        if case .recipe(let id, let title) = content.kitchen.leadObject { lead = ["id": .string(id), "title": .string(title)] }
        let recipeInput = ReinsSchema.object(properties: ["id": .oneOf(ids)], required: ["id"])
        return ReinsNode("kitchen", state: [
            "lead": lead,
            "recipes": .array(content.recipes.map { ["id": .string($0.id), "title": .string($0.title), "steps": .number(Double($0.steps.count))] }),
            "counts": ["recipes": .number(Double(content.kitchen.counts.recipes)), "shoppingItems": .number(Double(content.kitchen.counts.shoppingItems))],
        ], actions: ids.isEmpty ? [] : [
            ReinsAction("openRecipe", "Open a recipe", input: RecipeID.self) { [unowned self] in self.openRecipe($0.id) }.narrowed(recipeInput),
            ReinsAction("startCooking", "Start cooking a recipe", input: RecipeID.self) { [unowned self] in self.startCooking($0.id) }.narrowed(recipeInput),
        ])
    }

    private func recipeNode(_ recipe: Recipe) -> ReinsNode {
        let model = RecipeDetailViewModel(recipe: recipe)
        return ReinsNode("recipe", state: [
            "id": .string(model.id),
            "title": .string(model.title),
            "servings": recipe.servings.map(ReinsValue.string) ?? .null,
            "steps": .array(model.stepSections.map { section in
                [
                    "number": .number(Double(section.stepNumber)),
                    "title": section.step.stepTitle.map(ReinsValue.string) ?? .null,
                    "ingredients": .array(section.step.ingredients.map { .string($0.name) }),
                ]
            }),
        ], actions: [
            ReinsAction("startCooking", "Start cooking") { [unowned self] in self.startCooking(recipe.id) },
        ])
    }

    private func cookNode(_ recipe: Recipe) -> ReinsNode {
        let model = CookModeViewModel(recipe: recipe, progress: cookProgress(for: recipe))
        let index = model.activeStep.flatMap { step in recipe.steps.firstIndex { $0.id == step.id } } ?? 0
        var actions: [ReinsAction] = []
        if index < recipe.steps.count - 1 {
            actions.append(ReinsAction("nextStep", "Turn to the next step") { [unowned self] in self.turn(recipe, forward: true) })
        }
        if index > 0 {
            actions.append(ReinsAction("previousStep", "Turn back a step") { [unowned self] in self.turn(recipe, forward: false) })
        }
        let rows = model.ingredientChecklistRows
        if !rows.isEmpty {
            actions.append(ReinsAction("checkIngredient", "Check or uncheck an ingredient on this step", input: IngredientCheck.self) { [unowned self] in
                try self.check(recipe, ingredient: $0.id, checked: $0.checked)
            }.narrowed(.object(properties: ["id": .oneOf(rows.map(\.id)), "checked": .boolean], required: ["id", "checked"])))
        }
        return ReinsNode("cook", state: [
            "recipe": .string(recipe.id),
            "title": .string(recipe.title),
            "step": .string(model.stepProgressLabel),
            "stepTitle": model.activeStep?.stepTitle.map(ReinsValue.string) ?? .null,
            "page": .string(model.currentPageProgressLabel),
            "ingredients": .array(rows.map { ["id": .string($0.id), "title": .string($0.title), "quantity": .string($0.quantityText), "checked": .bool($0.isChecked)] }),
            "timer": model.systemTimer.map { .string($0.durationLabel) } ?? .null,
        ], actions: actions)
    }
}
