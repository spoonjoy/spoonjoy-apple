import Foundation
import Testing

@Suite("Native mobile design contract")
struct NativeMobileDesignContractTests {
    @Test("compact iOS shell uses native tab and navigation bars")
    func compactIOSShellUsesNativeTabAndNavigationBars() throws {
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
                "TabView(selection: compactTabSelection)",
                ".tabItem",
                "Label(\"Kitchen\", systemImage: \"house\")",
                "Label(\"Recipes\", systemImage: \"book.closed\")",
                "Label(\"Cookbooks\", systemImage: \"books.vertical\")",
                "Label(\"Shopping\", systemImage: \"checklist\")",
                "Label(\"Search\", systemImage: \"magnifyingglass\")",
                "compactNavigationToolbar",
                "ToolbarItem(placement: .topBarTrailing)",
                ".toolbarBackground(KitchenTableTheme.bone, for: .navigationBar)",
                ".toolbarBackground(.visible, for: .navigationBar)",
                "compactOfflineStatusBar",
                "desktopClassShell",
                "NavigationStack",
                "NavigationSplitView",
                ".background(KitchenTableTheme.bone.ignoresSafeArea())",
                ".navigationBarTitleDisplayMode(.inline)"
            ],
            forbids: [
                "compactBottomChrome",
                ".safeAreaInset(edge: .bottom, spacing: 0)",
                "ToolbarItemGroup(placement: .topBarTrailing)",
                "SpoonDock(context: spoonDockContext)",
                "shouldShowShellSpoonDock",
                "spoonDockContext"
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

    @Test("iOS tab bar appearance is opaque Spoonjoy bone")
    func iOSTabBarAppearanceIsOpaqueSpoonjoyBone() throws {
        let appPath = "Apps/Spoonjoy/iOS/SpoonjoyiOSApp.swift"
        let app = uncommentedSwift(try readRepoFile(appPath))

        expectContent(
            app,
            in: appPath,
            contains: [
                "configureChromeAppearance()",
                "UITabBarAppearance()",
                "configureWithOpaqueBackground()",
                "appearance.backgroundColor = SpoonjoyUIColor.bone",
                "UITabBar.appearance().isTranslucent = false",
                "UITabBar.appearance().standardAppearance = appearance",
                "UITabBar.appearance().scrollEdgeAppearance = appearance",
                "private enum SpoonjoyUIColor",
                "UIColor(red: 251.0 / 255.0, green: 250.0 / 255.0, blue: 244.0 / 255.0, alpha: 1)"
            ]
        )
    }

    @Test("compact route pages reserve enough space for the floating native tab bar")
    func compactRoutePagesReserveEnoughSpaceForFloatingNativeTabBar() throws {
        let themePath = "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
        let theme = uncommentedSwift(try readRepoFile(themePath))

        expectContent(
            theme,
            in: themePath,
            contains: [
                "static let compactDockReserve: CGFloat = 148",
                ".padding(.bottom, bottomReserve)"
            ]
        )
    }

    @Test("Spoonjoy section headers keep titles legible before drawing dividers")
    func spoonjoySectionHeadersKeepTitlesLegibleBeforeDrawingDividers() throws {
        let themePath = "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
        let theme = uncommentedSwift(try readRepoFile(themePath))

        expectContent(
            theme,
            in: themePath,
            contains: [
                "Text(title)",
                ".font(KitchenTableTheme.sectionTitle)",
                ".lineLimit(1)",
                ".layoutPriority(1)",
                "Rectangle()",
                ".layoutPriority(-1)"
            ]
        )
    }

    @Test("SpoonDock is limited to cook mode handrail controls")
    func spoonDockIsLimitedToCookModeHandrailControls() throws {
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
                ".accessibilityLabel",
                "static func cookMode(",
                "Done",
                "Previous",
                "Next"
            ],
            forbids: [
                "static func kitchen(",
                "static func recipes(",
                "static func shoppingList(",
                "static func search(",
                "static func generic("
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
                "ForEach(Array(recipes.enumerated()), id: \\.element.id)",
                "KitchenRecipeIndexRow(recipe: recipe, ordinal: index + 1)",
                "KitchenTableObjectRow",
                ".aspectRatio(1, contentMode: .fill)",
                "Image(systemName: \"chevron.forward\")",
                ".accessibilityLabel(recipe.title)"
            ],
            forbids: [
                "List(recipes",
                ".frame(minHeight: 160)",
                "Text(\"Open\")"
            ]
        )
    }

    @Test("TestFlight feedback polish removes clutter and placeholder overlap")
    func testFlightFeedbackPolishRemovesClutterAndPlaceholderOverlap() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let recipesPath = "Apps/Spoonjoy/Shared/Views/RecipesView.swift"
        let detailPath = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
        let spoonLogPath = "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift"
        let capturePath = "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift"
        let coverPath = "Apps/Spoonjoy/Shared/Components/RecipeCoverImage.swift"
        let searchPath = "Apps/Spoonjoy/Shared/Views/SearchView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))
        let recipes = uncommentedSwift(try readRepoFile(recipesPath))
        let detail = uncommentedSwift(try readRepoFile(detailPath))
        let spoonLog = uncommentedSwift(try readRepoFile(spoonLogPath))
        let capture = uncommentedSwift(try readRepoFile(capturePath))
        let cover = uncommentedSwift(try readRepoFile(coverPath))
        let search = uncommentedSwift(try readRepoFile(searchPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                "hasRealCover",
                "photoLead",
                "coverlessLead",
                "showsFallbackLabel: false",
                "Text(recipe.title)"
            ],
            forbids: [
                "let hasCoverImage = recipe.displayCoverImageURL != nil"
            ]
        )
        expectContent(
            recipes,
            in: recipesPath,
            contains: [
                "Image(systemName: \"chevron.forward\")",
                "subtitle: nil",
                "showsFallbackLabel: false",
                "RecipeCoverPrefetcher.prefetch"
            ],
            forbids: [
                "Text(\"Open\")",
                "row.servingsLabel,\n            row.coverProvenanceLabel"
            ]
        )
        expectContent(
            detail,
            in: detailPath,
            contains: [
                "KitchenTableLoadingStateView(",
                "title: loadingTitle ?? \"Loading recipe\"",
                "KitchenTableRouteErrorView(message: errorMessage",
                "errorMessage = \"We couldn't load this recipe.\"",
                "ownerToolsMenu"
            ],
            forbids: [
                "errorMessage = \"Recipe unavailable.\"",
                "Text(recipeID)",
                "note: ingredientIsChecked(ingredient.id) ? \"used\" : nil",
                "note: dependencyIsChecked(dependency.id) ? \"used\" : \"step output\"",
                "KitchenTableSection(title: \"Recipe maintenance\")"
            ]
        )
        expectContent(
            spoonLog,
            in: spoonLogPath,
            contains: [
                "cookLogControls",
                "ViewThatFits(in: .horizontal)",
                "Label(hasStagedPhoto ? \"Ready\" : \"Photo\"",
                "if hasStagedPhoto",
                "Label(\"Log\", systemImage: \"fork.knife\")"
            ],
            forbids: [
                "Label(hasStagedPhoto ? \"Photo Ready\" : \"Add Photo\"",
                "Label(\"Log Cook\", systemImage: \"fork.knife\")",
                "Toggle(isOn: $useAsRecipeCover) {\n                    Label(\"Use as cover\""
            ]
        )
        expectContent(
            capture,
            in: capturePath,
            contains: [
                "eyebrow: \"Spoonjoy Capture\"",
                "title: \"Import Status\"",
                "agentImportStatus",
                "ImportStatusPanel",
                "draftPreview(currentDraft)"
            ],
            forbids: [
                "eyebrow: \"Ouro Draft\"",
                "Label(\"Local Draft\"",
                "manualCaptureInputs",
                "textCapture\n        sourceCapture\n        imageCapture"
            ]
        )
        expectContent(
            cover,
            in: coverPath,
            contains: [
                "AsyncImage(url: url, transaction: imageTransaction)",
                ".transition(accessibilityReduceMotion ? .identity : .opacity)",
                "KitchenTableNoPhotoView",
                "missingSubtitle",
                "trimmingCharacters(in: .whitespacesAndNewlines)",
                "Photo not added",
                "compactMark",
                "case .empty:",
                "Loading photo"
            ],
            forbids: [
                "fallbackFoodAssetName",
                "loadingFallbackAssetName",
                "RecipeFallback",
                "assetName:",
                "fallbackTexture",
                "ForEach(0..<4",
                "fork.knife.circle",
                "Text(title)"
            ]
        )
        expectContent(
            search,
            in: searchPath,
            contains: [
                "AsyncImage(url: imageURL, transaction: imageLoadingTransaction)",
                "KitchenTableImagePhaseView",
                ".transition(reduceMotion ? .identity : .opacity)"
            ],
            forbids: [
                "fallbackAssetName",
                "fallbackFoodAssetName",
                "RecipeFallback"
            ]
        )
        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "Button(\"Import Status\", systemImage: \"tray.and.arrow.down\")",
                "loadingTitle: recipeLoadingTitle(id: id)",
                "private func recipeLoadingTitle(id: String) -> String?"
            ],
            forbids: [
                "Label(\"Capture\", systemImage: \"camera\")"
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
                "@Environment(\\.horizontalSizeClass)",
                "usesCompactRecipeDock",
                "if !usesCompactRecipeDock",
                "Menu",
                "KitchenTableActionButtonStyle(prominence: .primary)",
                "KitchenTableActionButtonStyle(prominence: hasIngredientsInShoppingList ? .quiet : .secondary)",
                "Label(\"Cook mode\", systemImage: \"fork.knife\")",
                "Label(\"Save\", systemImage: \"book.closed\")",
                "hasIngredientsInShoppingList ? \"In list\" : \"Add to list\"",
                "recipeHeaderControls"
            ],
            forbids: [
                "HStack {\n                if hasAction(.startCooking)",
                "Stepper(value: $shoppingScaleFactor",
                ".frame(maxWidth: 220)",
                "ViewThatFits(in: .horizontal)",
                "GridRow",
                "recipeDockClearance"
            ]
        )
    }

    @Test("recipe detail follows web step language instead of invented receipt method copy")
    func recipeDetailFollowsWebStepLanguageInsteadOfInventedReceiptMethodCopy() throws {
        let detailPath = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
        let detailModelPath = "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift"
        let spoonLogPath = "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift"
        let screenshotProofPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let detail = uncommentedSwift(try readRepoFile(detailPath))
        let detailModel = uncommentedSwift(try readRepoFile(detailModelPath))
        let spoonLog = uncommentedSwift(try readRepoFile(spoonLogPath))
        let screenshotProof = uncommentedSwift(try readRepoFile(screenshotProofPath))

        expectContent(
            detail,
            in: detailPath,
            contains: [
                "recipeHeaderControls",
                "RecipeScaleSelector",
                "Label(\"Clear progress\", systemImage: \"arrow.counterclockwise\")",
                "isCookbookSaveSheetPresented",
                "Label(\"Save\", systemImage: \"book.closed\")",
                "stepsSection",
                "KitchenTableSection(title: \"Steps\", subtitle: \"Tap ingredients as you go\")",
                "Text(\"Ingredients\")",
                "RecipeStepChecklistRow",
                "RecipeDetailCookProgressSnapshot",
                "spoonjoy-cook-progress:\\(viewModel.id)",
                "Label(\"Cook mode\", systemImage: \"fork.knife\")",
                "hasIngredientsInShoppingList ? \"In list\" : \"Add to list\"",
                "KitchenTableSection(title: \"Save to Cookbook\")"
            ],
            forbids: [
                "Ingredient Receipt",
                "KitchenTableSection(title: \"Method\")",
                "note: ingredientIsChecked",
                "cookbookSpread",
                "KitchenTableSection(title: \"Cookbooks\")",
                "KitchenTableSection(title: \"Cookbook Spread\")",
                "Save To Cookbook"
            ]
        )

        expectContent(
            spoonLog,
            in: spoonLogPath,
            contains: [
                "Text(\"Cooks\")"
            ],
            forbids: [
                "Text(\"Cook Log\")"
            ]
        )

        expectContent(
            detailModel,
            in: detailModelPath,
            contains: [
                "case steps",
                "RecipeDetailStepSection",
                "RecipeDetailStepDependency",
                "stepSections = recipe.steps.map(RecipeDetailStepSection.init(step:))"
            ],
            forbids: [
                "ingredientReceipt",
                "RecipeDetailIngredientReceipt",
                "case method"
            ]
        )

        expectContent(
            screenshotProof,
            in: screenshotProofPath,
            contains: [
                "\"Cook mode\"",
                "\"Save\"",
                "\"Yield\"",
                "\"Clear progress\"",
                "\"Add to list\"",
                "\"Steps\"",
                "\"Cooks\"",
                "\"Ingredients\"",
                "\"RecipeScaleSelector\"",
                "\"RecipeStepChecklistRow\""
            ],
            forbids: [
                "Ingredient Receipt"
            ]
        )
    }

    @Test("cook mode owns a compact SpoonDock handrail wired to step state")
    func cookModeOwnsCompactSpoonDockHandrail() throws {
        let cookPath = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let receiptPath = "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift"
        let proofPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let cook = uncommentedSwift(try readRepoFile(cookPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let receipt = uncommentedSwift(try readRepoFile(receiptPath))
        let proof = try readRepoFile(proofPath)
        let capture = try readRepoFile(capturePath)
        let validator = try readRepoFile(validatorPath)

        expectContent(
            cook,
            in: cookPath,
            contains: [
                "@Environment(\\.horizontalSizeClass)",
                "private var usesEmbeddedSpoonDock: Bool",
                "compactHeader",
                "compactCookControls",
                ".safeAreaInset(edge: .bottom, spacing: 0)",
                "SpoonDock(",
                "SpoonDockContext.cookMode(",
                "previous: previous",
                "markComplete: markCurrentStepComplete",
                "next: advance",
                "canGoBack: canGoBack",
                "canAdvance: canAdvance",
                "markCurrentStepComplete",
                "KitchenTableSection(title: \"Step Inputs\"",
                "KitchenTableSection(title: \"Step Ingredients\"",
                ".toggleStyle(.largeCheck)",
                ".padding(.horizontal, KitchenTableTheme.pagePadding + 4)",
                ".padding(.bottom, compactScrollBottomPadding)",
                ".background(KitchenTableTheme.bone)",
                ".overlay(alignment: .top)"
            ],
            forbids: [
                ".padding()",
                "Hands free",
                "VStack(spacing: 10) {\n            Button(action: markCurrentStepComplete)",
                "Label(\"Recipe\", systemImage: \"text.book.closed\")"
            ]
        )

        expectContent(
            receipt,
            in: receiptPath,
            contains: [
                "struct LargeCheckToggleStyle",
                "extension ToggleStyle where Self == LargeCheckToggleStyle"
            ],
            forbids: [
                "private struct LargeCheckToggleStyle",
                "private extension ToggleStyle where Self == LargeCheckToggleStyle"
            ]
        )

        for (path, content) in [
            (proofPath, proof),
            (capturePath, capture),
            (validatorPath, validator)
        ] {
            expectContent(
                content,
                in: path,
                contains: [
                    "Step Ingredients"
                ]
            )
        }

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                ".recipeDetail(_, .cook),"
            ],
            forbids: [
                "shouldShowShellSpoonDock",
                "SpoonDock(context: spoonDockContext)",
                "case .kitchen, .recipes, .recipeDetail(_, .cook), .capture, .unknownLink:"
            ]
        )
    }

    @Test("shopping list relies on native tab navigation instead of compact SpoonDock")
    func shoppingListReliesOnNativeTabNavigation() throws {
        let shoppingPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let proofPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let screenshotHarnessPath = "scripts/capture-native-screenshots.sh"
        let shopping = uncommentedSwift(try readRepoFile(shoppingPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let proof = uncommentedSwift(try readRepoFile(proofPath))
        let screenshotHarness = try readRepoFile(screenshotHarnessPath)

        expectContent(
            shopping,
            in: shoppingPath,
            contains: [
                "@FocusState private var isItemFieldFocused",
                "openSearch: @escaping () -> Void",
                "focusAddItem",
                "shoppingHeaderTools",
                "Menu",
                "KitchenTableHeader(",
                "VStack(alignment: .leading, spacing: 10)"
            ],
            forbids: [
                "Button(role: .destructive) {\n                    clearAll()",
                "HStack(alignment: .firstTextBaseline, spacing: 10)",
                "ViewThatFits(in: .horizontal)",
                "usesEmbeddedSpoonDock",
                "SpoonDock(",
                "SpoonDockContext.shoppingList(",
                ".safeAreaInset(edge: .bottom)"
            ]
        )

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "TabView(selection: compactTabSelection)",
                "Label(\"Shopping\", systemImage: \"checklist\")",
                ".tag(AppSection.shoppingList)",
                "case .shoppingList:\n            navigation.navigate(to: .shoppingList)"
            ],
            forbids: [
                "openKitchen: { openRoute(.kitchen) }",
                "SpoonDockContext.shoppingList("
            ]
        )

        expectContent(
            proof,
            in: proofPath,
            contains: [
                "voiceOverLabels: [\"Shopping\", \"Kitchen\", \"List Actions\", \"Add\", \"Clear checked\"]"
            ]
        )
        expectContent(
            screenshotHarness,
            in: screenshotHarnessPath,
            contains: [
                "\"voiceOverLabels\" => [\"Shopping\", \"Kitchen\", \"List Actions\", \"Add\", \"Clear checked\"]"
            ]
        )
    }

    @Test("compact primary routes are native tab bar sections")
    func compactPrimaryRoutesAreNativeTabBarSections() throws {
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "private var compactNavigationContent: some View",
                "if navigation.route.isCookModeActive",
                "compactImmersiveRouteContent(for: navigation.route)",
                "private var compactTabSelection: Binding<AppSection>",
                "compactTabContent(for: .kitchen)",
                "compactTabContent(for: .recipes)",
                "compactTabContent(for: .cookbooks)",
                "compactTabContent(for: .shoppingList)",
                "compactTabContent(for: .search)",
                "private func compactRootRoute(for section: AppSection) -> AppRoute",
                "private func compactTabSection(for route: AppRoute) -> AppSection",
                "case .profile, .profileGraph:\n            .search",
                "case .capture, .settings, .unknownLink:\n            .kitchen"
            ],
            forbids: [
                ".toolbar(navigation.route.isCookModeActive ? .hidden : .automatic, for: .tabBar)",
                "SpoonDockContext.recipes(",
                "SpoonDockContext.search(",
                "SpoonDockContext.generic(",
                "SpoonDockContext.kitchen("
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
        let cookbookViewPath = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let cookbookView = uncommentedSwift(try readRepoFile(cookbookViewPath))
        let screenshotProofPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let screenshotProof = uncommentedSwift(try readRepoFile(screenshotProofPath))
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
                "missingSubtitle",
                "trimmingCharacters(in: .whitespacesAndNewlines)",
                "KitchenTableNoPhotoView",
                "AsyncImage(url: url, transaction: imageTransaction)",
                "KitchenTableTheme.paper",
                "KitchenTableTheme.vellum",
                "Photo not added",
                "photo.badge.plus",
                "accessibilityLabel"
            ],
            forbids: [
                "LinearGradient(",
                "ForEach(0..<4",
                "fork.knife.circle",
                "bundledAssetName",
                "fallbackFoodAssetName",
                "loadingFallbackAssetName",
                "RecipeFallback",
                "LemonPantryPasta",
                "assetName:",
                "Circle().stroke(palette.accent",
                "fallbackTexture",
                "KitchenTableTheme.photoCharcoal"
            ]
        )
        expectContent(
            try readRepoFile("Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"),
            in: "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
            contains: [
                "if let coverImageURL = viewModel.cover.imageURL",
                "showsFallbackLabel: false"
            ],
            forbids: [
                "coverPlaceholderLabel",
                "Awaiting first chef photo",
                "Cover coming soon",
                "assetName:",
                "bundledAssetName(forRecipeID"
            ]
        )
        expectContent(
            cookbookView,
            in: cookbookViewPath,
            contains: [
                "Cookbook cover not added",
                "url: row.cover.primaryImageURL,",
                "showsFallbackLabel: true",
                "CookbookDetailHero"
            ],
            forbids: [
                "if let imageURL = row.cover.primaryImageURL {\n            VStack(alignment: .leading, spacing: 8) {"
            ]
        )
        expectContent(
            screenshotProof,
            in: screenshotProofPath,
            contains: [
                "\"media-aware contrast on real covers\"",
                "\"secondary text on bone\""
            ],
            forbids: [
                "\"white on photo overlay\""
            ]
        )
        expectContent(
            try readRepoFile("scripts/capture-native-screenshots.sh"),
            in: "scripts/capture-native-screenshots.sh",
            contains: [
                "\"media-aware contrast on real covers\"",
                "\"secondary text on bone\""
            ],
            forbids: [
                "\"white on photo overlay\""
            ]
        )
        for routePath in liveRoutePaths {
            expectContent(
                try readRepoFile(routePath),
                in: routePath,
                forbids: [
                    "bundledAssetName(forRecipeID",
                    "fallbackFoodAssetName",
                    "RecipeFallback",
                    "assetName:"
                ]
            )
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

    @Test("compact tab routes use system navigation chrome without global searchable")
    func compactTabRoutesUseSystemNavigationChromeWithoutGlobalSearchable() throws {
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "showsSearchChrome",
                "routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: true, showsSearchChrome: true)",
                "searchableRouteNavigationStack",
                ".searchable(text: searchText, prompt: \"Search Spoonjoy\")",
                "compactMobileShell(spotlightPayload: spotlightPayload)",
                "ToolbarItem(placement: .topBarTrailing)"
            ],
            forbids: [
                "ToolbarItemGroup(placement: .topBarTrailing)",
                "routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: false, showsSearchChrome: false)"
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
                ".navigationBarTitleDisplayMode(.inline)"
            ],
            forbids: [
                ".navigationBarTitleDisplayMode(usesCompactMobileShell ? .inline : .large)"
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
                "| Recipe detail | Web-parity `RecipeHeader`",
                "`Steps` using per-step `Ingredients`",
                "then `Cooks`",
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
