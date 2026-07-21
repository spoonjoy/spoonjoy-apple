import Foundation
import Testing

@Suite("Native mobile design contract")
struct NativeMobileDesignContractTests {
    @Test("system tab chrome owns Liquid Glass and compact content owns a real viewport inset")
    func systemTabChromeOwnsLiquidGlassAndCompactContentOwnsViewportInset() throws {
        let appPath = "Apps/Spoonjoy/iOS/SpoonjoyiOSApp.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let themePath = "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
        let app = uncommentedSwift(try readRepoFile(appPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let theme = uncommentedSwift(try readRepoFile(themePath))

        expectContent(
            app,
            in: appPath,
            forbids: [
                "configureChromeAppearance",
                "UITabBarAppearance",
                "UITabBar.appearance()",
                "SpoonjoyUIColor"
            ]
        )
        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                ".safeAreaPadding(.bottom, KitchenTableTheme.compactTabBarContentInset)",
                ".toolbarBackground(KitchenTableTheme.bone, for: .tabBar)",
                ".toolbarBackground(.visible, for: .tabBar)",
                ".tabBarMinimizeBehavior(.never)"
            ],
            forbids: [
                ".safeAreaInset(edge: .bottom, spacing: 0)",
                ".overlay(alignment: .bottom) {\n                    Rectangle()",
                ".toolbarBackground(.regularMaterial, for: .tabBar)"
            ]
        )
        expectContent(
            theme,
            in: themePath,
            contains: [
                "static let compactTabBarContentInset: CGFloat = 148",
                ".scrollEdgeEffectStyle(.hard, for: .bottom)"
            ],
            forbids: [
                "static let compactTabBarBackdropHeight"
            ],
        )
        expectContent(
            theme,
            in: themePath,
            forbids: ["static let compactTabBarContentInset: CGFloat = 88"]
        )
    }

    @Test("regular-width kitchen preserves a readable recipe index track")
    func regularWidthKitchenPreservesReadableRecipeIndexTrack() throws {
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))

        expectContent(
            kitchen,
            in: kitchenPath,
            contains: [
                "ViewThatFits(in: .horizontal)",
                ".frame(width: 360, alignment: .topLeading)",
                ".frame(minWidth: 928, alignment: .leading)",
                "VStack(alignment: .leading, spacing: KitchenTableTheme.pageSpacing)"
            ],
            forbids: [
                "if usesWideKitchenSpread, let leadRecipe"
            ]
        )
    }

    @Test("desktop navigation gives labels room and cook mode removes the library shell")
    func desktopNavigationGivesLabelsRoomAndCookModeRemovesLibraryShell() throws {
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                "sidebar.navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)",
                "navigation.route.isCookModeActive",
                "focusedCookModeShell",
                "showsToolbar: false",
                "showsSearchChrome: false"
            ],
            forbids: [
                ".navigationSplitViewColumnWidth(min: 240, ideal: 280)"
            ]
        )
    }

    @Test("compact root routes have one title owner and recipe actions are unambiguous")
    func compactRootRoutesHaveOneTitleOwnerAndRecipeActionsAreUnambiguous() throws {
        let themePath = "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let recipesPath = "Apps/Spoonjoy/Shared/Views/RecipesView.swift"
        let cookbooksPath = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let shoppingPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let recipeDetailPath = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
        let searchPath = "Apps/Spoonjoy/Shared/Views/SearchView.swift"
        let offlinePath = "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift"
        let signedOutPath = "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift"
        let cookModePath = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let theme = uncommentedSwift(try readRepoFile(themePath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let recipes = uncommentedSwift(try readRepoFile(recipesPath))
        let cookbooks = uncommentedSwift(try readRepoFile(cookbooksPath))
        let shopping = uncommentedSwift(try readRepoFile(shoppingPath))
        let recipeDetail = uncommentedSwift(try readRepoFile(recipeDetailPath))
        let search = uncommentedSwift(try readRepoFile(searchPath))
        let offline = uncommentedSwift(try readRepoFile(offlinePath))
        let signedOut = uncommentedSwift(try readRepoFile(signedOutPath))
        let cookMode = uncommentedSwift(try readRepoFile(cookModePath))

        expectContent(theme, in: themePath, contains: ["hidesTitleInCompactNavigation"])
        expectContent(navigation, in: navigationPath, contains: [".environment(\\.spoonjoyCompactNavigation, true)"])
        expectContent(
            recipes,
            in: recipesPath,
            contains: [
                "hidesTitleInCompactNavigation: true",
                "state.resolvedEmptyState(overridingDefaultWith: emptyStateOverride)",
                "RecipeCatalogEmptyState.noSavedRecipes"
            ],
            forbids: [
                "emptyStateOverride ?? state.emptyState"
            ]
        )
        expectContent(cookbooks, in: cookbooksPath, contains: ["hidesTitleInCompactNavigation: true"])
        expectContent(shopping, in: shoppingPath, contains: ["hidesTitleInCompactNavigation: true"])
        expectContent(search, in: searchPath, contains: ["hidesTitleInCompactNavigation: true"])
        expectContent(
            offline,
            in: offlinePath,
            contains: [
                "Button(action: onDismiss)",
                ".frame(minHeight: KitchenTableTheme.minimumTouchTarget)",
                ".accessibilityHint(\"Hides this status\")"
            ],
            forbids: [
                "effectiveProminence == .standard, let onDismiss",
                ".contextMenu"
            ]
        )
        expectContent(
            signedOut,
            in: signedOutPath,
            contains: ["Sign in with Apple isn't available right now."],
            forbids: ["local dogfood copy", "not Apple-authorized yet"]
        )
        expectContent(
            cookMode,
            in: cookModePath,
            forbids: ["unavailableCue", "systemUnavailableMessage, systemImage: \"iphone\""]
        )
        expectContent(
            recipeDetail,
            in: recipeDetailPath,
            contains: [
                "recipeActionBar",
                "recipeActionsMenu",
                "Label(\"Recipe actions\", systemImage: \"ellipsis.circle\")",
                "ownerToolsMenuItems"
            ],
            forbids: [
                "if !usesCompactRecipeDock",
                "recipeSecondaryActions"
            ]
        )
    }

    @Test("screenshot proof waits for terminal media and the route matrix covers iPad")
    func screenshotProofWaitsForTerminalMediaAndRouteMatrixCoversIPad() throws {
        let imagePath = "Apps/Spoonjoy/Shared/Components/RecipeCoverImage.swift"
        let proofPath = "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let matrixPath = "scripts/capture-native-screenshot-matrix.sh"
        let image = uncommentedSwift(try readRepoFile(imagePath))
        let proof = uncommentedSwift(try readRepoFile(proofPath))
        let capture = try readRepoFile(capturePath)
        let matrix = try readRepoFile(matrixPath)

        expectContent(
            image,
            in: imagePath,
            contains: ["ScreenshotVisualReadiness"],
            forbids: ["ProgressView()"]
        )
        expectContent(
            proof,
            in: proofPath,
            contains: [
                "XCUIApplication()",
                "throw XCTSkip(\"The external screenshot observer only runs for an explicit capture route.\")",
                "performAccessibilityAudit",
                "observedElements(in: app, windowFrame: window.frame)",
                "geometryFindings",
                "let initialScreenshot = XCUIScreen.main.screenshot()",
                "attachScreenshot(initialScreenshot",
                "primarySurface.swipeUp(velocity: .fast)",
                "terminalScrollSignature("
            ],
            forbids: [
                "XCUIScreen.main.screenshot().pngRepresentation",
                "primarySurface.scroll(byDeltaX:"
            ]
        )
        expectContent(
            capture,
            in: capturePath,
            contains: [
                "ios-tablet.png",
                "accessibility-proof-ipad.json",
                "abort(\"platform mismatch\") unless proof.fetch(\"platform\") == expected_platform",
                "pendingMediaCount",
                "SPOONJOY_SCREENSHOT_IOS_BOOT_TIMEOUT_SECONDS",
                "SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID",
                "SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID",
                "simulator boot readiness timeout",
                "log stream",
                "latest_front_display_event",
                "start_ios_foreground_stream",
                "stop_ios_foreground_stream",
                "transition_ios_capture_device",
                "open -a Simulator --args -CurrentDeviceUDID",
                "Spoonjoy stopped being the front display before screenshot capture",
                "Spoonjoy stopped being the front display during screenshot capture",
                "Front display did change",
                "distinct_color_buckets",
                "edge_ratio"
            ],
            forbids: [
                "registered as running before foreground pixel validation",
                "continuing to foreground/proof checks",
                "date -u '+%Y-%m-%d %H:%M:%S'",
                "--start \"$launched_at\"",
                "log show"
            ]
        )
        expectContent(
            matrix,
            in: matrixPath,
            contains: [
                "iosTabletScreenshot",
                "accessibility-proof-ipad.json",
                "SPOONJOY_SCREENSHOT_RESET_SIMULATOR_BETWEEN_ROUTES:-0"
            ],
            forbids: [
                "SPOONJOY_SCREENSHOT_RESET_SIMULATOR_BETWEEN_ROUTES:-1"
            ]
        )
    }

    @Test("shopping duplicates become a review section and completion uses the success role")
    func shoppingDuplicatesBecomeAReviewSectionAndCompletionUsesTheSuccessRole() throws {
        let receiptPath = "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift"
        let shoppingPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let receipt = uncommentedSwift(try readRepoFile(receiptPath))
        let shopping = uncommentedSwift(try readRepoFile(shoppingPath))

        expectContent(
            receipt,
            in: receiptPath,
            contains: [
                "Duplicates to review",
                "duplicateItemIDs",
                "Remove duplicate",
                "Remove one copy to resolve this duplicate.",
                ".contextMenu",
                "ReceiptDeleteSwipeModifier {"
            ],
            forbids: [
                "Review duplicate",
                "duplicateCountLabel(for:",
                "return matchCount > 1 ? \"\\(matchCount) on receipt\" : nil",
                "isEnabled: !isDuplicateReview"
            ]
        )
        expectContent(
            shopping,
            in: shoppingPath,
            contains: [
                "state.isSuccess ? KitchenTableTheme.herb : KitchenTableTheme.brass"
            ]
        )
    }

    @Test("release screenshot evidence covers every shipping route and substantive cook controls")
    func releaseScreenshotEvidenceCoversShippingRoutesAndCookControls() throws {
        let matrixPath = "scripts/capture-native-screenshot-matrix.sh"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let observerPath = "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"
        let cookModePath = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let cookControlsPath = "Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift"
        let cookLogPath = "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift"
        let matrix = try readRepoFile(matrixPath)
        let capture = try readRepoFile(capturePath)
        let observer = uncommentedSwift(try readRepoFile(observerPath))
        let cookMode = uncommentedSwift(try readRepoFile(cookModePath))
        let cookControls = uncommentedSwift(try readRepoFile(cookControlsPath))
        let cookLog = uncommentedSwift(try readRepoFile(cookLogPath))

        expectContent(
            matrix,
            in: matrixPath,
            contains: [
                "recipe-editor|recipe-editor|",
                "recipe-covers|recipe-covers|",
                "profile|profile|",
                "profile-graph|profile-graph|",
                "unknown-link|unknown-link|"
            ]
        )
        expectContent(
            capture,
            in: capturePath,
            contains: [
                "recipe-editor:recipe_lemon_pantry_pasta",
                "recipe-covers:recipe_lemon_pantry_pasta",
                "profile:ari",
                "profile-graph:ari:kitchen-visitors:1",
                "spoonjoy://unknown"
            ]
        )
        expectContent(
            observer,
            in: observerPath,
            contains: [
                "recipe-editor.title",
                "recipe-editor.save",
                "recipe-editor.delete",
                "recipe-covers.photo-picker",
                "recipe-covers.saved-covers",
                "profile.header",
                "profile.graph.kitchen-visitors",
                "profile-graph.row.chef_jules",
                "unknown-link.message",
                "cook.current-step",
                "cook.done",
                "cook.tools",
                "cook-log.note",
                "cook-log.next-time",
                "cook-log.photo",
                "cook-log.submit"
            ]
        )
        expectContent(
            cookMode,
            in: cookModePath,
            contains: [
                ".accessibilityIdentifier(\"cook.current-step\")",
                ".accessibilityIdentifier(\"cook.tools\")"
            ]
        )
        expectContent(
            cookControls,
            in: cookControlsPath,
            contains: [".accessibilityIdentifier(\"cook.done\")"]
        )
        expectContent(
            cookLog,
            in: cookLogPath,
            contains: [
                ".accessibilityIdentifier(\"cook-log.note\")",
                ".accessibilityIdentifier(\"cook-log.next-time\")",
                ".accessibilityIdentifier(\"cook-log.photo\")",
                ".accessibilityIdentifier(\"cook-log.submit\")"
            ]
        )
    }

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
                "Label(\"My Recipes\", systemImage: \"book.closed\")",
                "Label(\"Saved\", systemImage: \"bookmark\")",
                "Label(\"Cookbooks\", systemImage: \"books.vertical\")",
                "Label(\"Shopping List\", systemImage: \"checklist\")",
                "Button(\"Chefs\", systemImage: \"person.2\")",
                "Button(\"Search\", systemImage: \"magnifyingglass\")",
                "compactNavigationToolbar",
                "compactNavigationRootContent",
                "compactNavigationBaseContent",
                "RecipeEditorToolbarCoordinator",
                ".id(editorViewModel.route.stateIdentifier)",
                "performSave(for: navigation.route.stateIdentifier)",
                "private var isRecipeEditorRoute: Bool",
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
                "compactTabContent(for: .search)",
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

    @Test("recipe editor collection bindings survive list updates")
    func recipeEditorCollectionBindingsSurviveListUpdates() throws {
        let editorPath = "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift"
        let editor = uncommentedSwift(try readRepoFile(editorPath))

        expectContent(
            editor,
            in: editorPath,
            contains: [
                "ForEach(draft.steps)",
                "stepBinding(id: stepValue.id, fallback: stepValue)",
                "ForEach(step.wrappedValue.ingredients)",
                "ingredientBinding(",
                "stepID: stepValue.id",
                "ingredientID: ingredientValue.id",
                "fallback: ingredientValue"
            ],
            forbids: [
                "ForEach($draft.steps)",
                "ForEach($step.ingredients)"
            ]
        )
    }

    @Test("recipe editor owns a real macOS scroll viewport")
    func recipeEditorOwnsARealMacOSScrollViewport() throws {
        let editorPath = "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift"
        let editor = uncommentedSwift(try readRepoFile(editorPath))

        expectContent(
            editor,
            in: editorPath,
            contains: [
                "RecipeEditorPlatformScroller",
                "#if os(macOS)",
                "ScrollView {",
                "content.fixedSize(horizontal: false, vertical: true)",
                ".padding(.horizontal, KitchenTableTheme.pageSpacing)",
                ".modifier(RecipeEditorPlatformScroller())"
            ]
        )
    }

    @Test("recipe editor fields have one visible label and compact values")
    func recipeEditorFieldsHaveOneVisibleLabelAndCompactValues() throws {
        let editorPath = "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift"
        let editor = uncommentedSwift(try readRepoFile(editorPath))

        expectContent(
            editor,
            in: editorPath,
            contains: [
                "LabeledContent(\"Servings\")",
                "TextField(\"\", text: servingsText)",
                ".labelsHidden()",
                "LabeledContent(\"Duration\")",
                "durationSummary(value.wrappedValue)",
                "private func durationSummary(_ minutes: Int?) -> String"
            ],
            forbids: [
                "Text(\"Duration \\(value.wrappedValue ?? 0) minutes\")"
            ]
        )
    }

    @Test("recipe editor reflows controls at accessibility sizes")
    func recipeEditorReflowsControlsAtAccessibilitySizes() throws {
        let editorPath = "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift"
        let editor = uncommentedSwift(try readRepoFile(editorPath))

        expectContent(
            editor,
            in: editorPath,
            contains: [
                "accessibilityIngredientControls(",
                "compactIngredientControls(",
                "Label(\"Delete Ingredient\", systemImage: \"minus.circle\")",
                "durationStepper(",
                "Stepper(value: durationMinutes(value), in: 0...720)",
                ".labelsHidden()",
                ".controlSize(.extraLarge)",
                ".fixedSize(horizontal: false, vertical: true)"
            ]
        )
    }

    @Test("compact tab shell is the sole owner of the native tab bar viewport inset")
    func compactTabShellIsTheSoleOwnerOfTheNativeTabBarViewportInset() throws {
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let themePath = "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
        let kitchenPath = "Apps/Spoonjoy/Shared/Views/KitchenView.swift"
        let cookbooksPath = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let theme = uncommentedSwift(try readRepoFile(themePath))
        let kitchen = uncommentedSwift(try readRepoFile(kitchenPath))
        let cookbooks = uncommentedSwift(try readRepoFile(cookbooksPath))

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                ".safeAreaPadding(.bottom, KitchenTableTheme.compactTabBarContentInset)"
            ]
        )
        expectContent(
            theme,
            in: themePath,
            contains: [
                "static let pageBottomSpacing: CGFloat = 32",
                "bottomReserve: CGFloat = KitchenTableTheme.pageBottomSpacing",
                ".padding(.bottom, bottomReserve)"
            ],
            forbids: [
                "compactDockReserve"
            ]
        )
        for (path, content) in [(kitchenPath, kitchen), (cookbooksPath, cookbooks)] {
            expectContent(
                content,
                in: path,
                contains: ["KitchenTableTheme.pageBottomSpacing"],
                forbids: ["KitchenTableTheme.compactDockReserve"]
            )
        }
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
                "cookModeIconHandrail",
                "primaryIcon",
                "Back step",
                "Mark step",
                "Next step"
            ],
            forbids: [
                "static func kitchen(",
                "static func recipes(",
                "static func shoppingList(",
                "static func search(",
                "static func generic(",
                "title: \"Previous\"",
                "title: \"Done\""
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

    @Test("cook mode uses system AlarmKit timers instead of an in-app countdown")
    func cookModeUsesSystemAlarmKitTimersInsteadOfAnInAppCountdown() throws {
        let cookModePath = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let viewModelPath = "Sources/SpoonjoyCore/AppState/ScreenViewModels.swift"
        let editorPath = "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift"
        let infoPath = "Apps/Spoonjoy/Shared/Info.plist"
        let cookMode = uncommentedSwift(try readRepoFile(cookModePath))
        let viewModel = uncommentedSwift(try readRepoFile(viewModelPath))
        let editor = uncommentedSwift(try readRepoFile(editorPath))
        let info = try readRepoFile(infoPath)

        expectContent(
            cookMode,
            in: cookModePath,
            contains: [
                "canImport(AlarmKit)",
                "import AlarmKit",
                "AlarmManager.shared.authorizationState",
                "AlarmManager.shared.requestAuthorization()",
                "AlarmManager.AlarmConfiguration",
                ".timer(duration:",
                "AlarmAttributes(",
                "SpoonjoyCookTimerMetadata",
                "CookModeSystemTimer",
                "timer.startButtonTitle",
                "#if os(iOS)\n            if #available(iOS 26.1, *), let timer = viewModel.systemTimer",
                "return \"\\(timer.durationLabel) timer set.\""
            ],
            forbids: [
                "Timer.publish(every:",
                "remainingSeconds",
                "isRunning",
                "Pause timer",
                "Reset timer",
                "Restart timer",
                "#else\n        unavailableCue\n#endif",
                "system timer set.",
                "iPhone OS"
            ]
        )

        expectContent(
            viewModel,
            in: viewModelPath,
            contains: [
                "CookModeSystemTimerViewModel",
                "public var systemTimer: CookModeSystemTimerViewModel?",
                "durationMinutes",
                "Set \\(durationLabel) timer"
            ],
            forbids: [
                "CookModeTimerViewModel",
                "formattedRemainingTime",
                "remainingSeconds",
                "isRunning",
                "Pause timer",
                "Reset timer",
                "Restart timer"
            ]
        )

        expectContent(
            editor,
            in: editorPath,
            contains: [
                "LabeledContent(\"Duration\")",
                "durationSummary(value.wrappedValue)",
                "Stepper(value: durationMinutes(value), in: 0...720)",
                "private func durationMinutes(_ value: Binding<Int?>) -> Binding<Int>",
                "value.wrappedValue = minutes == 0 ? nil : minutes"
            ],
            forbids: [
                "Duration \\(step.duration ?? 0) seconds",
                "0...7200, step: 30"
            ]
        )

        expectContent(
            info,
            in: infoPath,
            contains: [
                "NSAlarmKitUsageDescription",
                "Spoonjoy can set system cooking timers for timed recipe steps."
            ]
        )
    }

    @Test("native recipe duration fixtures use API minutes rather than legacy seconds")
    func nativeRecipeDurationFixturesUseAPIMinutesRatherThanLegacySeconds() throws {
        let nativeBriefPath = "docs/native-design-language.md"
        let nativeBrief = try readRepoFile(nativeBriefPath)

        expectContent(
            nativeBrief,
            in: nativeBriefPath,
            contains: [
                "Treat recipe step `duration` as Spoonjoy API minutes everywhere"
            ]
        )

        let staleSecondsTokens = [
            "duration: 120",
            "duration: 180",
            "duration: 240",
            "duration: 300",
            "duration: 600",
            "duration: 7200",
            "\"duration\": 120",
            "\"duration\": 180",
            "\"duration\": 240",
            "\"duration\": 300",
            "\"duration\": 600",
            "\"duration\": 7200"
        ]

        for path in [
            "Tests/SpoonjoyCoreTests/RecipeEditorParityTests.swift",
            "Tests/SpoonjoyCoreTests/NativeLiveStoreTests.swift",
            "Tests/SpoonjoyCoreTests/NativeSyncEngineTests.swift"
        ] {
            expectContent(
                uncommentedSwift(try readRepoFile(path)),
                in: path,
                forbids: staleSecondsTokens
            )
        }
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
                "coverlessNoPhotoBadge",
                "Text(\"Photo not added\")",
                "let hasCoverImage = recipe.displayCoverImageURL != nil",
                ".frame(maxWidth: .infinity, minHeight: 210"
            ]
        )
        expectContent(
            recipes,
            in: recipesPath,
            contains: [
                "Image(systemName: \"chevron.forward\")",
                "subtitle: nil",
                "subtitle: \"Photo not added\"",
                "showsFallbackLabel: false",
                "showsFallbackLabel: true",
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
                "cookLogForm",
                "cookLogPhotoSlot",
                "cookLogActionBar",
                "Image(systemName: hasStagedPhoto ? \"photo.fill\" : \"photo.badge.plus\")",
                "if hasStagedPhoto",
                "KitchenTableActionButtonStyle(prominence: .primary)"
            ],
            forbids: [
                "Label(hasStagedPhoto ? \"Ready\" : \"Photo\"",
                "Label(hasStagedPhoto ? \"Photo Ready\" : \"Add Photo\"",
                "Label(\"Log\", systemImage: \"fork.knife\")",
                "Label(\"Log Cook\", systemImage: \"fork.knife\")",
                "Toggle(isOn: $useAsRecipeCover) {\n                    Label(\"Use as cover\""
            ]
        )
        expectContent(
            capture,
            in: capturePath,
            contains: [
                "eyebrow: \"Kitchen\"",
                "title: \"Imports\"",
                "Review recipes before they join your kitchen.",
                "agentImportStatus",
                "shouldShowStatusPanel",
                "captureActionsMenu",
                "Import actions",
                "Delete import",
                "ImportStatusPanel",
                "draftPreview(currentDraft)",
                "Import paused",
                "Saved locally",
                "No imports waiting",
                "OfflineStatusView"
            ],
            forbids: [
                "CaptureImportEntryPoint",
                "entryPointLedger",
                "Import queue",
                "Submit import",
                "Retry sync",
                "eyebrow: \"Agent import\"",
                "MCP agent",
                "MCP agent imports",
                "Use the Spoonjoy MCP agent",
                "eyebrow: \"Ouro Draft\"",
                "eyebrow: \"Spoonjoy Capture\"",
                "title: \"Import Status\"",
                "Label(\"Local Draft\"",
                "manualCaptureInputs",
                "textCapture\n        sourceCapture\n        imageCapture",
                "CaptureDraft.localText(",
                "CaptureDraft.importURL(",
                "\"Send to Spoonjoy\"",
                "shareSheetComingSoon",
                "siriComingSoon",
                "cameraComingSoon",
                "photoLibraryComingSoon",
                "Future entry points are listed"
            ]
        )
        expectContent(
            cover,
            in: coverPath,
            contains: [
                "AsyncImage(url: url, transaction: imageTransaction)",
                ".transition(reduceMotion ? .identity : .opacity)",
                "KitchenTableNoPhotoView",
                "missingSubtitle",
                "trimmingCharacters(in: .whitespacesAndNewlines)",
                ".id(url.absoluteString)",
                "Photo not added",
                "compactMark",
                "mode == .loading || mode == .unavailable",
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
                "Button(\"Imports\", systemImage: \"tray.and.arrow.down\")",
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
                "recipeActionBar",
                "recipeActionsMenu",
                "@Environment(\\.horizontalSizeClass)",
                "usesCompactRecipeDock",
                "ViewThatFits(in: .horizontal)",
                "Menu",
                "KitchenTableActionButtonStyle(prominence: .primary)",
                "Label(\"Cook mode\", systemImage: \"fork.knife\")",
                "Label(\"Log\", systemImage: \"fork.knife.circle\")",
                "Label(\"Recipe actions\", systemImage: \"ellipsis.circle\")",
                "Label(\"Save\", systemImage: \"book.closed\")",
                "Label(\"Add to list\", systemImage: \"cart.badge.plus\")",
                "recipeHeaderControls",
                "recipeMastheadActions\n            recipeHeaderControls"
            ],
            forbids: [
                "recipePrimaryActions",
                "recipeSecondaryActions",
                "if !usesCompactRecipeDock",
                "hasIngredientsInShoppingList ? \"In list\" : \"Add to list\"",
                "KitchenTableActionButtonStyle(prominence: hasIngredientsInShoppingList ? .quiet : .secondary)",
                "HStack {\n                if hasAction(.startCooking)",
                "Stepper(value: $shoppingScaleFactor",
                ".frame(maxWidth: 220)",
                "GridRow",
                "recipeDockClearance",
                "compactRecipeSectionBreak",
                "Spacer(minLength: 64)",
                "recipeMasthead\n            compactRecipeSectionBreak\n            stepsSection"
            ]
        )
    }

    @Test("recipe detail follows web step language instead of invented receipt method copy")
    func recipeDetailFollowsWebStepLanguageInsteadOfInventedReceiptMethodCopy() throws {
        let detailPath = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
        let detailModelPath = "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift"
        let spoonLogPath = "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift"
        let detail = uncommentedSwift(try readRepoFile(detailPath))
        let detailModel = uncommentedSwift(try readRepoFile(detailModelPath))
        let spoonLog = uncommentedSwift(try readRepoFile(spoonLogPath))

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
                "RecipeStepDurationCue",
                "RecipeStepChecklistRow",
                "RecipeDetailCookProgressSnapshot",
                "spoonjoy-cook-progress:\\(viewModel.id)",
                "Label(\"Cook mode\", systemImage: \"fork.knife\")",
                "Label(\"Add to list\", systemImage: \"cart.badge.plus\")",
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
                "durationMinutes",
                "durationLabel",
                "RecipeDetailStepDependency",
                "stepSections = recipe.steps.map(RecipeDetailStepSection.init(step:))"
            ],
            forbids: [
                "ingredientReceipt",
                "RecipeDetailIngredientReceipt",
                "case method"
            ]
        )

    }

    @Test("recipe detail preserves web masthead structure and stable route states")
    func recipeDetailPreservesWebMastheadStructureAndStableRouteStates() throws {
        let detailPath = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
        let detail = uncommentedSwift(try readRepoFile(detailPath))

        expectContent(
            detail,
            in: detailPath,
            contains: [
                "private enum RecipeDetailRouteState",
                "case loading(snapshotTitle: String?)",
                "case loaded(RecipeDetailScreenViewModel)",
                "case missing(message: String)",
                "case failed(message: String)",
                "@State private var routeState: RecipeDetailRouteState",
                "let hasVisibleCurrentRecipe = routeState.currentViewModel?.id == recipeID",
                "if !hasVisibleCurrentRecipe",
                "private var recipeMasthead",
                "private var recipeHeroMedia",
                "if viewModel.cover.hasRealCover",
                "private var recipeNoPhotoStatus",
                "Label(viewModel.cover.noPhotoLabel",
                "private var recipeIdentityAndProvenance",
                "private var recipeMastheadActions",
                "private var recipeMastheadLogCookAction",
                "viewModel.cover.hasRealCover",
                "Label(\"Log\", systemImage: \"fork.knife.circle\")",
                ".frame(maxWidth: usesCompactRecipeDock ? .infinity : 440)",
                ".buttonStyle(.plain)",
                ".navigationTitle(\"Save to Cookbook\")"
            ],
            forbids: [
                ".navigationTitle(\"Save\")",
                "subtitle: viewModel.cover.noPhotoLabel",
                "showsFallbackLabel: true",
                "private var recipeNoPhotoHeight"
            ]
        )
    }

    @Test("cook mode owns a compact SpoonDock handrail wired to step state")
    func cookModeOwnsCompactSpoonDockHandrail() throws {
        let cookPath = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let receiptPath = "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let cook = uncommentedSwift(try readRepoFile(cookPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let receipt = uncommentedSwift(try readRepoFile(receiptPath))
        let capture = try readRepoFile(capturePath)
        let validator = try readRepoFile(validatorPath)

        expectContent(
            cook,
            in: cookPath,
            contains: [
                "@Environment(\\.horizontalSizeClass)",
                "private var usesEmbeddedSpoonDock: Bool",
                "compactTaskHeader",
                "macOSCookModeCloseButton",
                "Button(action: close)",
                "Label(\"Close\", systemImage: \"xmark\")",
                ".accessibilityLabel(\"Close cook mode\")",
                "cookModeBottomActionRail",
                "currentStepCard",
                "stepProgressRail",
                ".safeAreaInset(edge: .bottom, spacing: 0)",
                "SpoonDock(",
                "SpoonDockContext.cookMode(",
                "previous: previous",
                "markComplete: markCurrentStepComplete",
                "next: advance",
                "canGoBack: canGoBack",
                "canAdvance: canAdvance",
                "markCurrentStepComplete",
                "KitchenTableSection(title: \"Use from earlier\"",
                "KitchenTableSection(title: \"Ingredients\"",
                ".toggleStyle(.largeCheck)",
                "regularCookModeWorkspace",
                "regularReferenceColumn",
                ".frame(maxWidth: 1040, alignment: .leading)",
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

        expectContent(capture, in: capturePath, contains: ["\"cook-mode\"", "CookModeView"])
        expectContent(
            validator,
            in: validatorPath,
            contains: ["cookModeBottomActionRail", "cookModeUtilitySheet", "Ingredients"]
        )

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

    @Test("cook mode and cook log stay kitchen safe instead of crowded control chrome")
    func cookModeAndCookLogStayKitchenSafeInsteadOfCrowdedControlChrome() throws {
        let cookPath = "Apps/Spoonjoy/Shared/Views/CookModeView.swift"
        let controlsPath = "Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift"
        let dockPath = "Apps/Spoonjoy/Shared/AppShell/SpoonDock.swift"
        let recipeDetailPath = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
        let spoonLogPath = "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let cook = uncommentedSwift(try readRepoFile(cookPath))
        let controls = uncommentedSwift(try readRepoFile(controlsPath))
        let dock = uncommentedSwift(try readRepoFile(dockPath))
        let recipeDetail = uncommentedSwift(try readRepoFile(recipeDetailPath))
        let spoonLog = uncommentedSwift(try readRepoFile(spoonLogPath))
        let capture = try readRepoFile(capturePath)
        let validator = try readRepoFile(validatorPath)

        expectContent(
            cook,
            in: cookPath,
            contains: [
                "private var compactTaskHeader",
                "private var currentStepCard",
                "private var cookModeUtilitySheet",
                "private var cookModeBottomActionRail",
                "private var stepProgressRail",
                "private var ingredientChecklistAnimation: Animation?",
                "accessibilityReduceMotion ? nil : .easeInOut(duration: 0.24)",
                "private var ingredientChecklistTransaction: Transaction",
                "transaction.disablesAnimations = true",
                "withTransaction(ingredientChecklistTransaction)",
                ".animation(ingredientChecklistAnimation, value: viewModel.ingredientChecklistRows)",
                "CookModeIngredientChecklistLabel(row: row)",
                "HStack(alignment: .firstTextBaseline, spacing: 10)",
                ".fixedSize(horizontal: false, vertical: true)",
                ".layoutPriority(1)",
                ".transition(.opacity.combined(with: .move(edge: .bottom)))"
            ],
            forbids: [
                "Button(\"Done\")",
                "Label(\"Previous\", systemImage: \"arrow.backward.circle\")",
                "Label(\"Add Ingredients\", systemImage: \"cart.badge.plus\")",
                "ScaleSelector(scaleFactor: progress.scaleFactor)",
                "KitchenTableSection(title: \"Step Inputs\"",
                "KitchenTableSection(title: \"Step Ingredients\"",
                ".background(.background)"
            ]
        )

        expectContent(
            controls,
            in: controlsPath,
            contains: [
                "KitchenSafeControlDeck",
                "primaryStepAction",
                "secondaryStepActions",
                "ViewThatFits(in: .horizontal)",
                "Label(\"Mark done\", systemImage: \"checkmark.circle.fill\")",
                "Label(\"Back step\", systemImage: \"chevron.backward.circle\")",
                "Label(\"Next step\", systemImage: \"arrow.forward.circle\")"
            ],
            forbids: [
                "Label(\"Done\", systemImage: \"checkmark.circle.fill\")",
                "Label(\"Recipe\", systemImage: \"text.book.closed\")",
                ".buttonStyle(.bordered)",
                "Label(\"Close\", systemImage: \"text.book.closed\")"
            ]
        )

        expectContent(
            dock,
            in: dockPath,
            contains: [
                "title: \"Mark step\"",
                "subtitle: nil",
                "accessibilityHint: \"Mark this cooking step complete.\"",
                "case primaryIcon",
                "dockButton(context.centerZone, prominence: .primaryIcon)"
            ],
            forbids: [
                "title: \"Done\"",
                "title: \"Previous\"",
                "subtitle: stepTitle"
            ]
        )

        expectContent(
            recipeDetail,
            in: recipeDetailPath,
            contains: [
                "Label(\"Recipe actions\", systemImage: \"ellipsis.circle\")",
                ".accessibilityLabel(\"Recipe actions\")",
                "ownerToolsMenuItems"
            ],
            forbids: [
                "Text(provenance)",
                "Label(\"Manage recipe\", systemImage: \"ellipsis.circle\")",
                ".accessibilityLabel(\"Manage recipe\")",
                ".background(KitchenTableTheme.photoOverlay"
            ]
        )

        expectContent(
            spoonLog,
            in: spoonLogPath,
            contains: [
                "private var cookLogForm",
                "private var cookLogPhotoSlot",
                "private var cookLogActionBar",
                "Image(systemName: hasStagedPhoto ? \"photo.fill\" : \"photo.badge.plus\")",
                "KitchenTableActionButtonStyle(prominence: .primary)",
                "accessibilityLabel(hasStagedPhoto ? \"Cook photo ready\" : \"Add cook photo\")"
            ],
            forbids: [
                "Label(hasStagedPhoto ? \"Ready\" : \"Photo\"",
                "Label(\"Log\", systemImage: \"fork.knife\")",
                ".buttonStyle(.borderedProminent)",
                ".controlSize(.large)",
                "ViewThatFits(in: .horizontal)",
                ".background(KitchenTableTheme.paper)"
            ]
        )

        expectContent(
            recipeDetail,
            in: recipeDetailPath,
            contains: [
                "screenshotCookLogFocusEnvironmentKey",
                "SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS",
                "presentCookLogForScreenshotIfNeeded()",
                "private var cookLogSheet",
                "KitchenTablePage(maxContentWidth: 620, bottomReserve: 28)",
                ".frame(minWidth: 560, idealWidth: 620, maxWidth: 700, minHeight: 400, idealHeight: 440, maxHeight: 480)",
                "cookLogView(showsHeader: true)",
                "cookLogView(showsHeader: false)",
                "isCookLogSheetPresented = true"
            ]
        )

        expectContent(
            spoonLog,
            in: spoonLogPath,
            contains: [
                "let showsHeader: Bool",
                "showsHeader: Bool = true",
                "if showsHeader",
                "route: \"cook-log\"",
                "source: \"SpoonCookLogView\""
            ]
        )

        for (path, content) in [(capturePath, capture), (validatorPath, validator)] {
            expectContent(
                content,
                in: path,
                contains: [
                    "\"cook-log\"",
                    "SpoonCookLogView",
                    "cookLogForm",
                    "cookLogPhotoSlot",
                    "cookLogActionBar"
                ]
            )
        }
    }

    @Test("shopping list relies on native tab navigation instead of compact SpoonDock")
    func shoppingListReliesOnNativeTabNavigation() throws {
        let shoppingPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let proofPath = "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"
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
                "Label(\"Shopping List\", systemImage: \"checklist\")",
                ".tag(AppSection.shoppingList)",
                "case .shoppingList:\n            navigation.navigate(to: .shoppingList)",
                ".settings,\n             .shoppingList,\n             .search:\n            true"
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
                "app.descendants(matching: type).allElementsBoundByIndex",
                "performAccessibilityAudit",
                "actionableTypes",
                "shopping-list"
            ]
        )
        expectContent(
            screenshotHarness,
            in: screenshotHarnessPath,
            contains: [
                "shopping-list"
            ]
        )
    }

    @Test("shopping workflow is an authored receipt, not a generic form and toggle stack")
    func shoppingWorkflowIsAuthoredReceiptNotGenericFormAndToggleStack() throws {
        let shoppingPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let receiptPath = "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift"
        let viewModelPath = "Sources/SpoonjoyCore/Features/Shopping/ShoppingSurfaceViewModel.swift"
        let verifierPath = "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
        let proofPath = "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"
        let screenshotHarnessPath = "scripts/capture-native-screenshots.sh"
        let shopping = uncommentedSwift(try readRepoFile(shoppingPath))
        let receipt = uncommentedSwift(try readRepoFile(receiptPath))
        let viewModel = uncommentedSwift(try readRepoFile(viewModelPath))
        let verifier = uncommentedSwift(try readRepoFile(verifierPath))
        let proof = uncommentedSwift(try readRepoFile(proofPath))
        let screenshotHarness = try readRepoFile(screenshotHarnessPath)

        expectContent(
            shopping,
            in: shoppingPath,
            contains: [
                "KitchenTablePage(",
                "private var shoppingRunHeader",
                "private var shoppingReceiptComposer",
                "private var shoppingReceiptState",
                "ShoppingReceiptStateView(",
                "receiptActionsMenu",
                "Clear checked",
                "Add from recipe"
            ],
            forbids: [
                "ContentUnavailableView(",
                "Label(\"List Actions\"",
                "TextField(\"Qty\"",
                "TextField(\"Unit\""
            ]
        )

        expectContent(
            receipt,
            in: receiptPath,
            contains: [
                "List {",
                "Section {",
                "private struct ShoppingReceiptRow",
                "sourceLine",
                ".accessibilityHint",
                ".toggleStyle(.largeCheck)",
                ".swipeActions"
            ],
            forbids: [
                "Review duplicate",
                "duplicateCountLabel(for:",
                "ScrollView",
                "LazyVStack",
                "Label(\"Done\", systemImage: \"checkmark\")",
                "KitchenTableReceiptRow(name: item.name, amount: item.displayQuantity)"
            ]
        )

        expectContent(
            viewModel,
            in: viewModelPath,
            contains: [
                "ShoppingReceiptState",
                "shoppingRunSummary",
                "emptyReceiptState",
                "allCompleteState",
                "queuedReceiptState",
                "duplicateCountLabel"
            ],
            forbids: [
                "title: \"Load your shopping list\"",
                "title: \"Your shopping list is empty\""
            ]
        )

        expectContent(
            verifier,
            in: verifierPath,
            contains: [
                "\"List {\"",
                "\"Section {\"",
                "\"ShoppingReceiptRow\"",
                "\"shoppingReceiptState\""
            ],
            forbids: [
                "\"List\", \"Section\""
            ]
        )

        expectContent(
            proof,
            in: proofPath,
            contains: [
                "app.descendants(matching: type).allElementsBoundByIndex",
                "performAccessibilityAudit",
                "geometryFindings",
                "shopping-list"
            ],
            forbids: [
                "RouteAccessibilityEvidence"
            ]
        )
        expectContent(
            screenshotHarness,
            in: screenshotHarnessPath,
            contains: [
                "\"shopping-list-empty\"",
                "\"shopping-list-all-complete\"",
                "\"shopping-list-duplicate\"",
                "\"shopping-list-conflict\"",
                "\"shopping-list-offline-queued\""
            ],
            forbids: [
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
                "compactTabContent(for: .savedRecipes)",
                "compactTabContent(for: .cookbooks)",
                "compactTabContent(for: .shoppingList)",
                "private func compactRootRoute(for section: AppSection) -> AppRoute",
                "private func compactTabSection(for route: AppRoute) -> AppSection",
                "case .search:\n            .kitchen",
                "case .chefs, .profile, .profileGraph:\n            .chefs",
                "case .capture, .settings, .unknownLink:\n            .kitchen"
            ],
            forbids: [
                "compactTabContent(for: .search)",
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
                ".id(url.absoluteString)",
                "KitchenTableTheme.paper",
                "KitchenTableTheme.vellum",
                "Photo not added",
                "photo.badge.plus",
                "mode == .loading || mode == .unavailable",
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
                "CookbookCoverArt(row:",
                "CookbookCoverArt(cookbook:",
                "CookbookFallbackCover",
                "CookbookImageCover",
                "private struct CookbookThumb",
                "KitchenTableNoPhotoView(",
                "CookbookThumb(row: row)",
                "CookbookDetailHero"
            ],
            forbids: [
                "Image(systemName: \"books.vertical.fill\")",
                "VStack(alignment: .leading, spacing: 8) {\n                Rectangle().frame(height: 1)",
                "RecipeCoverImage(\n                    url: row.cover.primaryImageURL",
                "if let imageURL = row.cover.primaryImageURL {\n            VStack(alignment: .leading, spacing: 8) {"
            ]
        )
        expectContent(
            try readRepoFile("scripts/validate-design-review.rb"),
            in: "scripts/validate-design-review.rb",
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

    @Test("cookbook surfaces use authored shelf spread and native contents grammar")
    func cookbookSurfacesUseAuthoredShelfSpreadAndNativeContentsGrammar() throws {
        let cookbookPath = "Apps/Spoonjoy/Shared/Views/CookbooksView.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let cookbook = uncommentedSwift(try readRepoFile(cookbookPath))
        let capture = try readRepoFile(capturePath)
        let validator = try readRepoFile(validatorPath)

        expectContent(
            cookbook,
            in: cookbookPath,
            contains: [
                "private var leadCookbook",
                "current.cover.primaryImageURL != candidate.cover.primaryImageURL",
                "current.recipeCount != candidate.recipeCount",
                "private var usesCompactCookbookLayout",
                "private var cookbookPageBottomReserve",
                "ToolbarItem(placement: .primaryAction)",
                "private var newCookbookButton",
                "private func leadCookbookCoverButton",
                "Image(systemName: \"square.and.arrow.up\")",
                "private var cookbookLibrarySpread",
                "private var cookbookShelfStrip",
                "private var cookbookIndexRows",
                "ScrollView(.horizontal",
                "CookbookCoverArt(row:",
                "CookbookCoverArt(cookbook:",
                "CookbookFallbackCover",
                "CookbookImageCover",
                "private struct CookbookThumb",
                "KitchenTableNoPhotoView(",
                ".system(.title2, design: .serif).weight(.bold)",
                ".minimumScaleFactor(0.66)",
                "private var detailHeaderWidth",
                "private var detailShareAction",
                "HStack(alignment: .top, spacing: 28)",
                ".frame(width: detailHeaderWidth, alignment: .leading)",
                "private var detailCoverWidth",
                "ForEach(Array(viewModel.recipes.enumerated()), id: \\.element.id)",
                "CookbookRecipeIndexRow(recipe: recipe, ordinal: index + 1",
                "private struct CookbookRecipeIndexRow",
                "if recipe.coverImageURL != nil",
                "DisclosureGroup(isExpanded: $isOwnerToolsExpanded)",
                "Label(\"Owner tools\", systemImage: \"wrench.and.screwdriver\")",
                ".swipeActions(edge: .trailing, allowsFullSwipe: false)",
                "Button(role: .destructive)"
            ],
            forbids: [
                "private func leadCookbookActions",
                "private func openCookbookButton",
                "Label(\"Open cookbook\"",
                "Image(systemName: \"books.vertical.fill\")",
                "VStack(alignment: .leading, spacing: 8) {\n                Rectangle().frame(height: 1)",
                "title: \"\\(emptyState.title). \\(emptyState.message)\"",
                "RecipeCoverImage(\n                    url: row.cover.primaryImageURL",
                "Image(systemName: \"books.vertical\")\n                    .foregroundStyle(KitchenTableTheme.brass)",
                "Text(\"Owner Tools\")",
                "Label(\"Remove\", systemImage: \"minus.circle\")",
                "HStack(alignment: .bottom, spacing: 28) {\n                detailHeader",
                "HStack(alignment: .firstTextBaseline) {\n                    TextField(\"Title\""
            ]
        )

        expectContent(
            capture,
            in: capturePath,
            contains: [
                "\"cookbookShelfStrip\"",
                "\"cookbookLibrarySpread\"",
                "\"cookbookContentsIndex\"",
                "\"cookbookOwnerToolsDisclosure\""
            ]
        )
        expectContent(
            validator,
            in: validatorPath,
            contains: [
                "\"cookbookShelfStrip\"",
                "\"cookbookLibrarySpread\"",
                "\"cookbookContentsIndex\"",
                "\"cookbookOwnerToolsDisclosure\""
            ]
        )
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
                "navigation.route.usesCompactAuxiliaryShell",
                "@State private var isSearchPresented = false",
                ".searchable(text: searchText, isPresented: $isSearchPresented, placement: .toolbarPrincipal, prompt: \"Search Spoonjoy\")",
                "focusCompactSearchFieldIfNeeded",
                "routeKeepsSearchFocus",
                "if case .search = route",
                "compactMobileShell(spotlightPayload: spotlightPayload)",
                "ToolbarItem(placement: .topBarTrailing)"
            ],
            forbids: [
                "ToolbarItemGroup(placement: .topBarTrailing)",
                "routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: false, showsSearchChrome: false)"
            ]
        )
    }

    @Test("search uses native searchable chrome and captures typed scoped evidence")
    func searchUsesNativeSearchableChromeAndCapturesTypedScopedEvidence() throws {
        let searchPath = "Apps/Spoonjoy/Shared/Views/SearchView.swift"
        let navigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let capturePath = "scripts/capture-native-screenshots.sh"
        let matrixPath = "scripts/capture-native-screenshot-matrix.sh"
        let validatorPath = "scripts/validate-design-review.rb"
        let search = uncommentedSwift(try readRepoFile(searchPath))
        let navigation = uncommentedSwift(try readRepoFile(navigationPath))
        let capture = try readRepoFile(capturePath)
        let matrix = try readRepoFile(matrixPath)
        let validator = try readRepoFile(validatorPath)

        expectContent(
            navigation,
            in: navigationPath,
            contains: [
                ".searchable(text: searchText, prompt: \"Search Spoonjoy\")",
                ".searchable(text: searchText, isPresented: $isSearchPresented, placement: .toolbarPrincipal, prompt: \"Search Spoonjoy\")",
                "@FocusState private var isSearchFieldFocused",
                ".searchFocused($isSearchFieldFocused)",
                "isSearchFieldFocused = true",
                "SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS",
                ".searchScopes(searchScope)",
                "SearchSurfaceScopeGrammar.title(for: scope)",
                ".onSubmit(of: .search)",
                "private var searchScope: Binding<SearchScope>"
            ],
            forbids: [
                "TextField(\"tomato beans\"",
                "visibleSearchField",
                "TextField(\"Search Spoonjoy\"",
                "SearchSurfaceContract.visibleSearchField",
                "ScrollView(.horizontal, showsIndicators: false)",
                "scopeLabel(scope)",
                "searchControls"
            ]
        )
        expectContent(
            search,
            in: searchPath,
            forbids: [
                ".searchable(",
                ".searchScopes(",
                "@FocusState"
            ]
        )

        expectContent(
            capture,
            in: capturePath,
            contains: [
                "capture_surface_variant",
                "captureSignedOutSurface",
                "SignedOutSetupView",
                "search_capture_variant",
                "search-typed-results",
                "search-scoped-recipes",
                "search-scoped-cookbooks",
                "search-scoped-chefs",
                "search-scoped-shopping",
                "search-no-results",
                "expected_search_query",
                "expected_search_scope",
                "expected_search_route_identifier",
                "\"searchSurfaceVariant\" => search_capture_variant",
                "\"expectedQuery\" => expected_search_query",
                "\"expectedScope\" => expected_search_scope"
            ],
            forbids: [
                "proof.fetch(\"scope\") == \"all\"",
                "proof.fetch(\"query\") == \"\""
            ]
        )

        expectContent(
            matrix,
            in: matrixPath,
            contains: [
                "search-typed-results|search-typed-results|",
                "search-scoped-recipes|search-scoped-recipes|",
                "search-scoped-cookbooks|search-scoped-cookbooks|",
                "search-scoped-chefs|search-scoped-chefs|",
                "search-scoped-shopping|search-scoped-shopping|",
                "search-no-results|search-no-results|",
                "capture-empty|capture-empty|",
                "capture-draft|capture-draft|",
                "capture-offline-retry|capture-offline-retry|",
                "capture-provider-blocked|capture-provider-blocked|",
                "capture-signed-out|capture-signed-out|"
            ]
        )

        expectContent(
            validator,
            in: validatorPath,
            contains: [
                "searchSurfaceVariant",
                "EXPECTED_CAPTURE_VARIANTS",
                "captureSurfaceVariant",
                "captureSignedOutSurface",
                "expected_search_proof",
                "\"typed-results\"",
                "\"scoped-recipes\"",
                "\"scoped-cookbooks\"",
                "\"scoped-chefs\"",
                "\"scoped-shopping\"",
                "\"no-results\"",
                "proof[\"query\"] == expected[\"query\"]",
                "proof[\"scope\"] == expected[\"scope\"]"
            ],
            forbids: [
                "routeIdentifier must be search:all:",
                "query must be blank",
                "scope must be all"
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
                ".navigationBarTitleDisplayMode(.inline)",
                ".navigationTitle(usesCompactMobileShell ? title(for: navigation.route) : \"\")"
            ],
            forbids: [
                ".navigationBarTitleDisplayMode(usesCompactMobileShell ? .inline : .large)",
                ".navigationTitle(title(for: navigation.route))"
            ]
        )
    }

    @Test("screenshot variants prove rendered state from isolated fixture storage")
    func screenshotVariantsProveRenderedStateFromIsolatedFixtureStorage() throws {
        let rootPath = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"
        let writerPath = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
        let captureViewPath = "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift"
        let shoppingViewPath = "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift"
        let captureScriptPath = "scripts/capture-native-screenshots.sh"
        let validatorPath = "scripts/validate-design-review.rb"

        expectContent(
            uncommentedSwift(try readRepoFile(rootPath)),
            in: rootPath,
            contains: ["SPOONJOY_SCREENSHOT_STATE_DIRECTORY", "screenshotStateDirectory"]
        )
        expectContent(
            uncommentedSwift(try readRepoFile(writerPath)),
            in: writerPath,
            contains: [
                "observedSurfaceVariant",
                "\"observedSurfaceVariant\"",
                "observedSurfaceState",
                "\"observedSurfaceState\"",
                "screenshotStateSnapshotProof",
                "NativeAppStateLocation.defaultFileURL()",
                "native-sync-store.json",
                "\"stateDirectoryConfigured\"",
                "\"stateDirectoryResolved\"",
                "\"appSnapshotPresent\"",
                "\"appSnapshotJSONReadable\"",
                "\"appSnapshotCaptureDraftPresent\"",
                "\"appSnapshotShoppingListPresent\"",
                "\"appSnapshotPendingCaptureImportPresent\"",
                "\"appSnapshotProviderBlockerPresent\"",
                "\"syncSnapshotPresent\"",
                "\"syncSnapshotJSONReadable\"",
                "\"syncSnapshotQueueCount\"",
                "\"syncSnapshotQueuedShoppingWorkPresent\""
            ]
        )
        expectContent(
            uncommentedSwift(try readRepoFile(captureViewPath)),
            in: captureViewPath,
            contains: [
                "screenshotSurfaceVariant",
                ".task(id: screenshotSurfaceVariant)",
                "observedSurfaceVariant: screenshotSurfaceVariant"
            ]
        )
        expectContent(
            uncommentedSwift(try readRepoFile(shoppingViewPath)),
            in: shoppingViewPath,
            contains: [
                "screenshotSurfaceVariant",
                "screenshotObservedSurfaceState",
                "statusOwner: \"ShoppingListView\"",
                "queuedMutationCount: viewModel.shoppingQueuedMutationCount",
                "case .queuedWork:",
                "\"queuedWork\"",
                "if viewModel.queuedWorkSummary != nil",
                "return \"offline-queued\"",
                ".task(id: screenshotSurfaceVariant)",
                "observedSurfaceVariant: screenshotSurfaceVariant",
                "observedSurfaceState: screenshotObservedSurfaceState"
            ],
            forbids: [
                "if viewModel.connectivity == .offline, viewModel.queuedWorkSummary != nil"
            ]
        )
        expectContent(
            try readRepoFile(captureScriptPath),
            in: captureScriptPath,
            contains: [
                "macos_state_directory",
                "SPOONJOY_SCREENSHOT_STATE_DIRECTORY",
                "expected_surface_variant",
                "observedSurfaceVariant",
                "expectedSurfaceVariant",
                "actualObservedSurfaceVariant"
            ]
        )
        expectContent(
            try readRepoFile(validatorPath),
            in: validatorPath,
            contains: [
                "observedSurfaceVariant",
                "captureSurfaceVariant",
                "shoppingListVariant"
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
