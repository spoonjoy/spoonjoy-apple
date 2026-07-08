import Foundation
import Testing

@Suite("Native mobile design contract")
struct NativeMobileDesignContractTests {
    @Test("compact iOS shell owns SpoonDock instead of generic toolbar navigation")
    func compactIOSShellOwnsSpoonDockInsteadOfGenericToolbarNavigation() throws {
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let toolbarPath = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyToolbar.swift"
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let toolbar = uncommentedSwift(try readRepoFile(toolbarPath))

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "@Environment(\\.horizontalSizeClass)",
                "private var usesCompactMobileShell: Bool",
                "compactMobileShell",
                "compactBottomChrome",
                "compactOfflineStatusBar",
                ".safeAreaInset(edge: .bottom, spacing: 0)",
                "desktopClassShell",
                "NavigationStack",
                "NavigationSplitView",
                ".background(KitchenTableTheme.bone.ignoresSafeArea())",
                "SpoonDock(",
                "SpoonDockContext"
            ],
            forbids: [
                "VStack(spacing: 0) {\n                routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: false, showsSearchChrome: false)\n\n                SpoonDock(context: spoonDockContext)"
            ]
        )

        expectContent(
            toolbar,
            in: toolbarPath,
            contains: [
                "SpoonjoyToolbar",
                "ShareActions"
            ],
            forbids: [
                "Button(\"Kitchen\")",
                "Button(\"Capture Draft\")",
                "Button(\"Settings\")"
            ]
        )
    }

    @Test("SpoonDock defines route matrix glass controls and accessibility labels")
    func spoonDockDefinesRouteMatrixGlassControlsAndAccessibilityLabels() throws {
        let dockPath = "Apps/Spoonjoy/Shared/AppShell/SpoonDock.swift"
        let dock = uncommentedSwift(try readRepoFile(dockPath))

        expectContent(
            dock,
            in: dockPath,
            contains: [
                "struct SpoonDock: View",
                "struct SpoonDockContext",
                "struct SpoonDockAction",
                "enum SpoonDockActionRole",
                "leftZone",
                "centerZone",
                "rightTools",
                "buttonStyle(.glassProminent)",
                ".background(.thinMaterial, in: Circle())",
                ".background(.ultraThinMaterial",
                ".accessibilityLabel",
                "Kitchen",
                "Recipes",
                "Cook",
                "Step",
                "Shopping",
                "Search",
                "Capture",
                "Settings",
                "clear checked"
            ]
        )
    }

    @Test("SpoonDock is registered in both app targets")
    func spoonDockIsRegisteredInBothAppTargets() throws {
        let projectPath = "Spoonjoy.xcodeproj/project.pbxproj"
        let project = try readRepoFile(projectPath)

        expectContent(
            project,
            in: projectPath,
            contains: [
                "SpoonDock.swift",
                "SpoonDock.swift in Sources"
            ]
        )

        let sourceMembershipCount = project
            .components(separatedBy: .newlines)
            .filter { $0.contains("/* SpoonDock.swift in Sources */,") }
            .count
        #expect(sourceMembershipCount == 2, Comment(rawValue: "\(projectPath) should register SpoonDock.swift in iOS and macOS sources; found \(sourceMembershipCount)."))
    }

    @Test("kitchen recipe index is a scroll-friendly object layout, not a nested List island")
    func kitchenRecipeIndexIsScrollFriendlyObjectLayout() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                "struct KitchenRecipeIndexRow: View",
                "LazyVStack",
                "ForEach(recipes, id: \\.id)",
                "KitchenTableObjectRow",
                ".aspectRatio(1, contentMode: .fill)",
                ".accessibilityLabel(recipe.title)"
            ],
            forbids: [
                "List(recipes",
                ".frame(minHeight: 160)"
            ]
        )
    }

    @Test("recipe detail actions wrap with mobile action flow instead of one overflowing HStack")
    func recipeDetailActionsWrapWithMobileActionFlow() throws {
        let detailPath = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
        let detail = uncommentedSwift(try readRepoFile(detailPath))

        expectContent(
            detail,
            in: detailPath,
            contains: [
                "recipePrimaryActions",
                "recipeSecondaryActions",
                "Menu",
                "KitchenTableActionButtonStyle(prominence: .primary)",
                "KitchenTableActionButtonStyle(prominence: hasIngredientsInShoppingList ? .quiet : .secondary)",
                ".frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget"
            ],
            forbids: [
                "HStack {\n                if hasAction(.startCooking)",
                ".frame(maxWidth: 220)",
                "ViewThatFits(in: .horizontal)",
                "GridRow"
            ]
        )
    }

    @Test("cook mode owns a compact SpoonDock handrail wired to step state")
    func cookModeOwnsCompactSpoonDockHandrail() throws {
        let cookPath = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let cook = uncommentedSwift(try readRepoFile(cookPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            cook,
            in: cookPath,
            contains: [
                "@Environment(\\.horizontalSizeClass)",
                "private var usesEmbeddedSpoonDock: Bool",
                "compactCookControls",
                "SpoonDock(",
                "SpoonDockContext.cookMode(",
                "previous: previous",
                "next: advance",
                "markCurrentStepComplete"
            ]
        )

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "shouldShowShellSpoonDock",
                "case .recipeDetail(_, .cook), .shoppingList:"
            ]
        )
    }

    @Test("shopping list owns add clear checked and search through a compact SpoonDock")
    func shoppingListOwnsCompactSpoonDockActions() throws {
        let shoppingPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let shopping = uncommentedSwift(try readRepoFile(shoppingPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            shopping,
            in: shoppingPath,
            contains: [
                "@FocusState private var isItemFieldFocused",
                "openSearch: @escaping () -> Void",
                "focusAddItem",
                ".safeAreaInset(edge: .bottom)",
                "SpoonDock(",
                "SpoonDockContext.shoppingList(",
                "add: focusAddItem",
                "search: openSearch",
                "clearChecked: clearCompleted",
                "shoppingHeaderTools",
                "Menu",
                "KitchenTableHeader(",
                "VStack(alignment: .leading, spacing: 10)"
            ],
            forbids: [
                "Button(role: .destructive) {\n                    clearAll()",
                "HStack(alignment: .firstTextBaseline, spacing: 10)",
                "ViewThatFits(in: .horizontal)"
            ]
        )

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "ShoppingListView(",
                "openSearch: openSearchFromDock"
            ]
        )
    }

    @Test("SpoonDock has narrow phone and Dynamic Type fallbacks")
    func spoonDockHasNarrowPhoneAndDynamicTypeFallbacks() throws {
        let dockPath = "Apps/Spoonjoy/Shared/AppShell/SpoonDock.swift"
        let dock = uncommentedSwift(try readRepoFile(dockPath))

        expectContent(
            dock,
            in: dockPath,
            contains: [
                "@Environment(\\.dynamicTypeSize)",
                "dynamicTypeSize.isAccessibilitySize",
                "ViewThatFits(in: .horizontal)",
                "adaptiveDock",
                "horizontalDock",
                "compactDock",
                "accessibilityDock",
                "layoutPriority",
                "role == .destructive"
            ],
            forbids: [
                ".frame(minWidth: 82",
                ".frame(minWidth: 132",
                ".frame(width: 48, height: 48)",
                ".frame(maxWidth: 372)"
            ]
        )
    }

    @Test("native palette is pinned to the current Spoonjoy web tokens")
    func nativePaletteIsPinnedToCurrentSpoonjoyWebTokens() throws {
        let themePath = "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
        let theme = try readRepoFile(themePath)

        expectContent(
            theme,
            in: themePath,
            contains: [
                "webColor(0xFBFAF4) // --sj-bone",
                "webColor(0xFFFEFA) // --sj-bone-lift",
                "webColor(0xE8E9DF) // --sj-vellum",
                "webColor(0x28231D) // --sj-charcoal",
                "webColor(0x635D54) // --sj-charcoal-soft",
                "webColor(0x9B6834) // --sj-brass",
                "webColor(0x28231D) // --sj-action",
                "webColor(0x1F1B17) // --sj-action-deep",
                "webColor(0xA24A38) // --sj-tomato",
                "webColor(0x596A4F) // --sj-herb",
                "onPhoto = bone // --sj-on-photo",
                "onPhotoMuted = bone.opacity(0.76) // --sj-on-photo-muted",
                "webColor(0x211F1B) // --sj-photo-charcoal"
            ],
            forbids: [
                "Color(red: 0.97, green: 0.95, blue: 0.90)",
                "Color(red: 0.99, green: 0.98, blue: 0.94)"
            ]
        )
    }

    @Test("AI placeholder covers do not render as native food photography")
    func aiPlaceholderCoversDoNotRenderAsNativeFoodPhotography() throws {
        let modelPath = "Sources/SpoonjoyCore/RecipeCookbook/RecipeCookbook.swift"
        let model = try readRepoFile(modelPath)
        let catalogPath = "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogViewModel.swift"
        let catalog = try readRepoFile(catalogPath)
        let detailPath = "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift"
        let detail = try readRepoFile(detailPath)
        let coverComponentPath = "Apps/Spoonjoy/Shared/Components/RecipeCoverImage.swift"
        let coverComponent = uncommentedSwift(try readRepoFile(coverComponentPath))
        let liveRoutePaths = [
            "Apps/Spoonjoy/Shared/Views/KitchenView.swift",
            "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
            "Apps/Spoonjoy/Shared/Views/RecipesView.swift",
            "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
            "Apps/Spoonjoy/Shared/Views/ProfileView.swift"
        ]

        expectContent(
            model,
            in: modelPath,
            contains: [
                "public var displayCoverImageURL: URL?",
                "coverSourceType == .aiPlaceholder ? nil : coverImageURL",
                "public var displayCoverProvenanceLabel: String?",
                "displayCoverImageURL == nil ? nil : coverProvenanceLabel"
            ]
        )
        expectContent(catalog, in: catalogPath, contains: ["summary.displayCoverImageURL", "summary.displayCoverProvenanceLabel"])
        expectContent(detail, in: detailPath, contains: ["recipe.displayCoverImageURL", "recipe.displayCoverProvenanceLabel"])
        expectContent(
            coverComponent,
            in: coverComponentPath,
            contains: [
                "KitchenTableTheme.photoCharcoal",
                "KitchenTableTheme.photoOverlay",
                "KitchenTableTheme.onPhoto",
                "KitchenTableTheme.onPhotoMuted",
                "RecipeCoverFallbackPalette"
            ],
            forbids: [
                "garnish",
                "Capsule()",
                "Circle().stroke(palette.accent",
                "LinearGradient(\n                colors: palette.background"
            ]
        )
        for routePath in liveRoutePaths {
            expectContent(try readRepoFile(routePath), in: routePath, forbids: ["bundledAssetName(forRecipeID"])
        }
    }

    @Test("shopping destructive actions stay behind confirmations")
    func shoppingDestructiveActionsStayBehindConfirmations() throws {
        let shoppingPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let shopping = uncommentedSwift(try readRepoFile(shoppingPath))

        expectContent(
            shopping,
            in: shoppingPath,
            contains: [
                "activeConfirmationDialog",
                "Button(dialog.prompt.confirmButtonTitle, role: dialog.prompt.isDestructive ? .destructive : nil)",
                "Button(\"Cancel\", role: .cancel)",
                "deleteItem(",
                "confirmation: .required",
                "clearCompleted(",
                "clearAll(",
                "confirmedAction(for action: ShoppingSurfaceAction)"
            ]
        )
    }

    @Test("compact SpoonDock routes suppress stray global search chrome")
    func compactSpoonDockRoutesSuppressStrayGlobalSearchChrome() throws {
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "showsSearchChrome",
                "routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: false, showsSearchChrome: false)",
                "routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: true, showsSearchChrome: true)",
                "searchableRouteNavigationStack",
                ".searchable(text: searchText, prompt: \"Search Spoonjoy\")"
            ]
        )
    }

    @Test("compact mobile routes do not duplicate large system titles above authored headers")
    func compactMobileRoutesDoNotDuplicateLargeSystemTitles() throws {
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                ".navigationBarTitleDisplayMode(usesCompactMobileShell ? .inline : .large)"
            ],
            forbids: [
                ".navigationBarTitleDisplayMode(.large)"
            ]
        )
    }

    @Test("visual audit records all current feedback failures and no ready item can disappear")
    func visualAuditRecordsAllCurrentFeedbackFailuresAndNoReadyItemCanDisappear() throws {
        let auditPath = "codex-native/tasks/2026-07-07-2353-whole-native-ui-overhaul-visual-audit.md"
        let audit = try readRepoFile(auditPath)

        expectContent(
            audit,
            in: auditPath,
            contains: [
                "W1 | Compact shell",
                "W2 | Recipe detail",
                "W5 | Kitchen",
                "W6 | Kitchen/Cookbooks",
                "W9 | Whole app",
                "| Kitchen | Page masthead",
                "| Recipe detail | Editorial hero",
                "| Cook mode | High-contrast task page",
                "| Shopping list | Receipt page",
                "| Signed out/loading/error | Branded Spoonjoy page"
            ]
        )
    }
}

private let mobileDesignRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func readRepoFile(_ relativePath: String) throws -> String {
    try String(contentsOf: mobileDesignRepoURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: .regularExpression)
}

private func expectContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String] = [],
    forbids forbiddenTokens: [String] = []
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    let forbidden = forbiddenTokens.filter { content.contains($0) }
    #expect(missing.isEmpty, Comment(rawValue: "\(relativePath) missing tokens: \(missing.joined(separator: ", "))"))
    #expect(forbidden.isEmpty, Comment(rawValue: "\(relativePath) contains forbidden tokens: \(forbidden.joined(separator: ", "))"))
}
