import Foundation

/// Spoonjoy's phone shell as a model: the route (`AppNavigationState`) and the tab bar's stacks
/// (`CompactTabNavigation`), and the moves a tap, a back swipe or a link makes on them.
///
/// The SwiftUI shell (`PlatformNavigationView`) and Ouro Reins (`SpoonjoyReinsShell`) both call these methods, so a
/// headless journey and the app take the same path. The view keeps its own storage (the route is a binding from the
/// root view, the tabs are view state) and applies each change through `SpoonjoyShell(navigation:compactTabs:)`.
public struct SpoonjoyShell: Equatable {
    public private(set) var navigation: AppNavigationState
    public private(set) var compactTabs: CompactTabNavigation

    public init(route: AppRoute = .kitchen) {
        navigation = AppNavigationState(route: route)
        compactTabs = CompactTabNavigation(route: route)
    }

    public init(navigation: AppNavigationState, compactTabs: CompactTabNavigation) {
        self.navigation = navigation
        self.compactTabs = compactTabs
    }

    /// The route on screen.
    public var route: AppRoute {
        navigation.route
    }

    /// Every route change, from a tap, a link, Spotlight or an App Intent, moves the tabs to follow.
    public mutating func navigate(to route: AppRoute, restoring: Bool = false) {
        navigation.navigate(to: route, restoring: restoring)
        followRoute()
    }

    /// The tabs follow the route. A blank editor route is the Add a recipe sheet, which no tab pushes.
    public mutating func followRoute() {
        guard navigation.route != .recipeEditor(id: nil) else {
            return
        }
        compactTabs.apply(navigation.route)
    }

    /// A tap on a tab: the tab keeps its stack, and the route becomes whatever it shows. Returns true when the tab is
    /// the search tab at its root, where the shell runs the search.
    @discardableResult
    public mutating func select(_ tab: CompactTab) -> Bool {
        restore(compactTabs.select(tab))
        return tab == .search && compactTabs.path(for: .search).isEmpty
    }

    /// A back tap, back swipe or tab re-tap changed a tab's stack.
    public mutating func setPath(_ path: [AppRoute], for tab: CompactTab) {
        restore(compactTabs.setPath(path, for: tab))
    }

    /// Whether the selected tab's top page has a way back now. Cook mode closes with its own Close, and an editor
    /// leaves only through Cancel or Save, which ask before dropping a draft.
    public var canGoBack: Bool {
        guard let top = compactTabs.path(for: compactTabs.selectedTab).last, !navigation.route.isCookModeActive else {
            return false
        }
        switch top {
        case .recipeEditor, .recipeCoverControls:
            return false
        default:
            return true
        }
    }

    /// The back button, edge swipe and ⌘[: the selected tab drops its top page. Returns false when there is no way back.
    @discardableResult
    public mutating func goBack() -> Bool {
        guard canGoBack else {
            return false
        }
        let tab = compactTabs.selectedTab
        setPath(Array(compactTabs.path(for: tab).dropLast()), for: tab)
        return true
    }

    public mutating func openRecipe(_ id: String) {
        navigate(to: .recipeDetail(id: id, presentation: .detail))
    }

    public mutating func startCooking(_ id: String) {
        navigate(to: .recipeDetail(id: id, presentation: .cook))
    }

    /// Cook mode's Close goes back to the recipe it cooked.
    public mutating func closeCook(_ id: String) {
        openRecipe(id)
    }

    public mutating func openCookbook(_ id: String) {
        navigate(to: .cookbookDetail(id: id))
    }

    /// The tab bar carries Cooking now on every page but the Kitchen's own, where the strip does the same job.
    public func showsCookingNowSwitcher(hasCooks: Bool) -> Bool {
        hasCooks && (compactTabs.selectedTab != .kitchen || !compactTabs.path(for: .kitchen).isEmpty)
    }

    private mutating func restore(_ route: AppRoute) {
        if route != navigation.route {
            navigate(to: route, restoring: true)
        }
    }
}

// MARK: - Cook mode

extension SpoonjoyShell {
    /// The progress cook mode opens with: the saved progress, else a fresh start.
    public static func cookProgress(for recipe: Recipe, saved: CookModeProgress?, startedAt: String) -> CookModeProgress {
        saved ?? CookModeProgress.starting(recipe: recipe, startedAt: startedAt)
    }

    /// A swipe, Next or Back, a voice command: the progress after turning a page.
    public static func turnCookPage(_ model: CookModeViewModel, forward: Bool, updatedAt: String) -> CookModeProgress {
        forward ? model.progressAfterSelectingNext(updatedAt: updatedAt) : model.progressAfterSelectingPrevious(updatedAt: updatedAt)
    }

    /// An ingredient row's checkbox.
    public static func checkIngredient(_ model: CookModeViewModel, id: String, checked: Bool, updatedAt: String) throws -> CookModeProgress {
        try model.progressAfterTogglingIngredient(id: id, checked: checked, updatedAt: updatedAt)
    }

    /// The step timers a change of checks starts by itself: each step whose ingredients the change completed, that has
    /// a duration and no running timer (`CookAutoTimerPolicy`). Progress from another device never comes here.
    public static func timersToAutoStart(
        recipe: Recipe,
        from previous: CookModeProgress,
        to next: CookModeProgress,
        runningStepIDs: Set<String>
    ) -> [CookModeSystemTimerViewModel] {
        guard previous.checkedIngredientIDs != next.checkedIngredientIDs else {
            return []
        }
        let checked = Set(next.checkedIngredientIDs)
        let previouslyChecked = Set(previous.checkedIngredientIDs)
        return recipe.steps.compactMap { step in
            guard CookAutoTimerPolicy.shouldAutoStart(
                step: step,
                checkedIngredientIDs: checked,
                previouslyChecked: previouslyChecked,
                runningStepIDs: runningStepIDs
            ) else {
                return nil
            }
            return CookModeViewModel(
                recipe: recipe,
                progress: (try? next.selectingStep(id: step.id, updatedAt: next.updatedAt)) ?? next
            ).systemTimer
        }
    }
}
