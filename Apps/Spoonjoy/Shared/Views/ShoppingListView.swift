import Foundation
import SpoonjoyCore
import SwiftUI

struct ShoppingListView: View {
#if os(iOS)
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
#endif
    @State private var addItemForm = ShoppingAddItemFormState()
    @State private var actionStatusMessage: String?
    @State private var actionErrorMessage: String?
    @State private var activeConfirmationDialog: ShoppingConfirmationDialog?
    @State private var pendingItemIDs: Set<String> = []
    @State private var lastFailedAction: ShoppingSurfaceAction?
    @State private var viewMode: ShoppingListViewMode = .all
    @State private var activeCategory = "all"
    @FocusState private var isItemFieldFocused: Bool
    @FocusState private var isRetryButtonFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private let viewModel: ShoppingSurfaceViewModel
    private let actionDidPlan: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    private let shoppingMutationFeedback: ShoppingMutationFeedback?
    private let retryShoppingMutationRecovery: @MainActor @Sendable () async throws -> ShoppingSurfaceMutationOutcome
    private let hasRecipes: Bool
    private let openSearch: () -> Void
    private let createRecipe: () -> Void
    private let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    init(
        viewModel: ShoppingSurfaceViewModel,
        actionDidPlan: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome = { _ in .synced },
        shoppingMutationFeedback: ShoppingMutationFeedback? = nil,
        retryShoppingMutationRecovery: @escaping @MainActor @Sendable () async throws -> ShoppingSurfaceMutationOutcome = { .synced },
        hasRecipes: Bool = true,
        openSearch: @escaping () -> Void = {},
        createRecipe: @escaping () -> Void = {},
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        let screenshotEnvironment = ProcessInfo.processInfo.environment
        self.viewModel = viewModel
        _viewMode = State(initialValue: ShoppingListViewMode(
            rawValue: screenshotEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_MODE"] ?? ""
        ) ?? .all)
        _activeCategory = State(initialValue: screenshotEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_CATEGORY"] ?? "all")
        _pendingItemIDs = State(initialValue: screenshotEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT"] == "pending"
            ? ["item_lemons"]
            : [])
        self.actionDidPlan = actionDidPlan
        self.shoppingMutationFeedback = shoppingMutationFeedback
        self.retryShoppingMutationRecovery = retryShoppingMutationRecovery
        self.hasRecipes = hasRecipes
        self.openSearch = openSearch
        self.createRecipe = createRecipe
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
    }

    var body: some View {
        KitchenTablePage(maxContentWidth: 760) {
            shoppingRunHeader
            shoppingReceiptComposer
            shoppingModeStrip
            shoppingCategoryFilters
            statusBanner
            shoppingReceiptState
        }
        .confirmationDialog(
            activeConfirmationDialog?.prompt.title ?? "",
            isPresented: Binding(
                get: { activeConfirmationDialog != nil },
                set: { isPresented in
                    if !isPresented {
                        activeConfirmationDialog = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let dialog = activeConfirmationDialog {
                Button(dialog.prompt.confirmButtonTitle, role: dialog.prompt.isDestructive ? .destructive : nil) {
                    runAction(dialog.confirmedAction)
                    activeConfirmationDialog = nil
                }
                Button("Cancel", role: .cancel) {
                    activeConfirmationDialog = nil
                }
            }
        } message: {
            if let message = activeConfirmationDialog?.prompt.message {
                Text(message)
            }
        }
#if os(iOS)
        .toolbar {
            EditButton()
        }
#endif
        .task(id: viewModel.activeCountLabel) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "shopping-list",
                source: "ShoppingListView",
                runtimeContext: screenshotAccessibilityRuntimeContext
            )
        }
    }

#if os(iOS)
    private var currentEditMode: EditMode? {
        editMode?.wrappedValue
    }
#endif

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    private var shoppingRunHeader: some View {
        KitchenTableHeader(
            eyebrow: "Kitchen",
            title: "Shopping List",
            subtitle: viewModel.shoppingRunSummary,
            hidesTitleInCompactNavigation: true
        ) {
            shoppingHeaderTools
        }
    }

    private var shoppingTitleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shopping")
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(viewModel.activeCountLabel)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
        }
    }

    @ViewBuilder private var shoppingHeaderTools: some View {
        HStack(spacing: 8) {
            if shoppingList != nil {
                receiptActionsMenu
            }

#if os(iOS)
            if currentEditMode == .active {
                Label("Editing", systemImage: "slider.horizontal.3")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
#endif
        }
    }

    private var receiptActionsMenu: some View {
        Menu {
            Button("Clear checked") {
                clearCompleted()
            }
            Button("Clear all", role: .destructive) {
                clearAll()
            }
        } label: {
            Group {
                if isAccessibilityLayout {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Receipt actions")
                } else {
                    Label("Receipt actions", systemImage: "ellipsis.circle")
                }
            }
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.charcoal)
            .padding(.horizontal, 12)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .background(KitchenTableTheme.paper, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var shoppingList: ShoppingListState? {
        viewModel.shoppingList
    }

    private var shoppingPresentation: ShoppingPresentationModel? {
        viewModel.presentation(mode: viewMode, activeCategory: activeCategory)
    }

    @ViewBuilder private var shoppingModeStrip: some View {
        if let presentation = shoppingPresentation {
            if isAccessibilityLayout {
                Menu {
                    ForEach(presentation.modeOptions, id: \.mode) { option in
                        Button(option.label) {
                            viewMode = option.mode
                            activeCategory = "all"
                        }
                    }
                } label: {
                    Label(selectedModeLabel(in: presentation), systemImage: "line.3.horizontal.decrease.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                .accessibilityLabel("Shopping view, \(selectedModeLabel(in: presentation)) selected")
            } else {
                HStack(spacing: 0) {
                    ForEach(presentation.modeOptions, id: \.mode) { option in
                        Button {
                            viewMode = option.mode
                            activeCategory = "all"
                        } label: {
                            Text(option.label)
                                .font(KitchenTableTheme.uiLabel)
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget)
                                .foregroundStyle(viewMode == option.mode ? KitchenTableTheme.paper : KitchenTableTheme.inkMuted)
                                .background(viewMode == option.mode ? KitchenTableTheme.charcoal : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(viewMode == option.mode ? .isSelected : [])
                    }
                }
                .overlay(alignment: .top) { Divider() }
                .overlay(alignment: .bottom) { Divider() }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Shopping view")
            }
        }
    }

    @ViewBuilder private var shoppingCategoryFilters: some View {
        if let presentation = shoppingPresentation {
            if isAccessibilityLayout {
                Menu {
                    ForEach(presentation.categoryOptions, id: \.self) { category in
                        Button(categoryLabel(category)) {
                            activeCategory = category
                        }
                    }
                } label: {
                    Label(categoryLabel(presentation.activeCategory), systemImage: "basket")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                .accessibilityLabel("Aisle filter, \(categoryLabel(presentation.activeCategory)) selected")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presentation.categoryOptions, id: \.self) { category in
                            let isSelected = presentation.activeCategory == category
                            Button {
                                activeCategory = category
                            } label: {
                                Text(categoryLabel(category))
                                    .font(KitchenTableTheme.uiLabel)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                                    .foregroundStyle(isSelected ? KitchenTableTheme.paper : KitchenTableTheme.charcoal)
                                    .background(isSelected ? KitchenTableTheme.charcoal : KitchenTableTheme.paper, in: Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(KitchenTableTheme.line.opacity(0.6), lineWidth: isSelected ? 0 : 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .accessibilityLabel("Aisle filter")
            }
        }
    }

    private var shoppingReceiptComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isAccessibilityLayout {
                itemNameField
                addItemButton
            } else {
                HStack(spacing: 8) {
                    itemNameField
                    compactAddItemButton
                }
            }
            recipeActionButton
        }
    }

    private var addItemControls: some View {
        shoppingReceiptComposer
    }

    private var itemNameField: some View {
        TextField("Add an item", text: $addItemForm.itemName)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
            .focused($isItemFieldFocused)
            .onSubmit(addItem)
    }

    private var quantityField: some View {
        TextField("Amount", text: $addItemForm.itemQuantity)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
            .frame(maxWidth: 120)
#if os(iOS)
            .keyboardType(.decimalPad)
#endif
    }

    private var unitField: some View {
        TextField("Measure", text: $addItemForm.itemUnit)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
            .frame(maxWidth: .infinity)
    }

    private var addItemButton: some View {
        Button(action: addItem) {
            Label("Add item", systemImage: "plus.circle")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
    }

    private var compactAddItemButton: some View {
        Button(action: addItem) {
            Image(systemName: "plus")
                .font(.headline.weight(.bold))
                .frame(width: 50, height: 50)
                .foregroundStyle(KitchenTableTheme.paper)
                .background(KitchenTableTheme.action, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add item")
    }

    private var addFromRecipeButton: some View {
        Button(action: openSearch) {
            Label("Add from recipe", systemImage: "book")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
    }

    private var createRecipeButton: some View {
        Button(action: createRecipe) {
            Label("Create a recipe", systemImage: "square.and.pencil")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
    }

    @ViewBuilder private var recipeActionButton: some View {
        if isAccessibilityLayout && hasRecipes {
            Button(action: openSearch) {
                Label("Recipes", systemImage: "book")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .accessibilityLabel("Add from recipe")
        } else if isAccessibilityLayout {
            Button(action: createRecipe) {
                Label("New recipe", systemImage: "square.and.pencil")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .accessibilityLabel("Create a recipe")
        } else if hasRecipes {
            addFromRecipeButton
        } else {
            createRecipeButton
        }
    }

    private var isAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private func selectedModeLabel(in presentation: ShoppingPresentationModel) -> String {
        presentation.modeOptions.first { $0.mode == viewMode }?.label ?? "All"
    }

    private func categoryLabel(_ category: String) -> String {
        category == "all" ? "All aisles" : category
    }

    @ViewBuilder private var shoppingReceiptState: some View {
        if let presentation = shoppingPresentation, let emptyTitle = presentation.emptyTitle {
            shoppingMarketEmptyState(
                title: emptyTitle,
                message: presentation.emptyMessage ?? "Switch views to see the rest of your list."
            )
        } else if let presentation = shoppingPresentation {
            ReceiptListView(
                sections: presentation.sections,
                pendingItemIDs: pendingItemIDs,
                setChecked: settingChecked,
                deleteItem: deleteItem
            )
        } else if let receiptState = viewModel.shoppingReceiptState {
            ShoppingReceiptStateView(
                state: receiptState,
                primaryAction: {
                    if receiptState.actionTitle == "Clear checked" {
                        clearCompleted()
                    } else {
                        focusAddItem()
                    }
                },
                recipeActionTitle: hasRecipes ? "Add from recipe" : "Create a recipe",
                addFromRecipeAction: hasRecipes ? openSearch : createRecipe
            )
        } else {
            shoppingMarketEmptyState(
                title: "Your shopping list is empty",
                message: "Add an item above or bring ingredients over from a recipe."
            )
        }
    }

    private func shoppingMarketEmptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(KitchenTableTheme.sectionTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(message)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
            }
            if let conflictBanner = viewModel.conflictBanner {
                Label(conflictBanner.message, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
                    .accessibilityHint(conflictBanner.actionTitle)
            }
            if let visibleActionStatusMessage {
                Label(visibleActionStatusMessage, systemImage: "checkmark.circle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
            } else if let visibleActionErrorMessage {
                HStack(alignment: .center, spacing: 10) {
                    Label(visibleActionErrorMessage, systemImage: "exclamationmark.triangle")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.tomato)
                    Spacer(minLength: 8)
                    Button("Retry", action: retryFailedAction)
                        .font(KitchenTableTheme.uiLabel.weight(.semibold))
                        .focused($isRetryButtonFocused)
                        .accessibilityHint("Retries only the failed shopping action.")
                }
            }
        }
    }

    private var visibleActionStatusMessage: String? {
        actionStatusMessage ?? addItemForm.actionStatusMessage
    }

    private var visibleActionErrorMessage: String? {
        effectiveShoppingMutationFeedback?.message ?? actionErrorMessage ?? addItemForm.actionErrorMessage
    }

    private var effectiveShoppingMutationFeedback: ShoppingMutationFeedback? {
        if let shoppingMutationFeedback {
            return shoppingMutationFeedback
        }
#if DEBUG
        guard ProcessInfo.processInfo.environment["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT"] == "row-error" else {
            return nil
        }
        return ShoppingMutationFeedback(
            identity: ShoppingSurfaceMutationIdentity(
                kind: .setItemChecked,
                clientMutationID: "screenshot-row-error",
                itemID: "item_lemons"
            ),
            state: .failed,
            message: "Couldn't update lemons. Try again.",
            retryIntent: .resubmitWithNewID(nil)
        )
#else
        return nil
#endif
    }

    private func focusAddItem() {
        isItemFieldFocused = true
    }

    private func addItem() {
        Task { @MainActor in
            actionStatusMessage = nil
            actionErrorMessage = nil
            var submittedForm = addItemForm
            await submittedForm.submit(
                viewModel: viewModel,
                clientMutationID: clientMutationID(prefix: "shopping-add"),
                actionDidPlan: actionDidPlan
            )
            addItemForm = submittedForm
        }
    }

    private func settingChecked(_ item: ShoppingListItem, _ checked: Bool) {
        runAction(.setItemChecked(
            itemID: item.id,
            checked: checked,
            clientMutationID: clientMutationID(prefix: checked ? "shopping-check" : "shopping-uncheck")
        ), pendingItemID: item.id)
    }

    private func deleteItem(_ item: ShoppingListItem) {
        runAction(.deleteItem(
            itemID: item.id,
            clientMutationID: clientMutationID(prefix: "shopping-delete"),
            confirmation: .required
        ), pendingItemID: item.id)
    }

    private func clearCompleted() {
        runAction(.clearCompleted(
            clientMutationID: clientMutationID(prefix: "shopping-clear-completed"),
            confirmation: .required
        ))
    }

    private func clearAll() {
        runAction(.clearAll(
            clientMutationID: clientMutationID(prefix: "shopping-clear-all"),
            confirmation: .required
        ))
    }

    private func runAction(_ action: ShoppingSurfaceAction, pendingItemID: String? = nil) {
        Task {
            await perform(action, pendingItemID: pendingItemID)
        }
    }

    @MainActor private func perform(_ action: ShoppingSurfaceAction, pendingItemID: String? = nil) async {
        if let pendingItemID {
            pendingItemIDs.insert(pendingItemID)
        }
        defer {
            if let pendingItemID {
                pendingItemIDs.remove(pendingItemID)
            }
        }
        do {
            let plan = try viewModel.plan(action)
            if let prompt = plan.confirmationPrompt {
                activeConfirmationDialog = ShoppingConfirmationDialog(
                    prompt: prompt,
                    confirmedAction: confirmedAction(for: action)
                )
                return
            }
            if let blockedReason = plan.blockedReason {
                actionErrorMessage = blockedReason
                actionStatusMessage = nil
                return
            }
            let outcome = try await actionDidPlan(plan)
            switch outcome {
            case .queuedForSync:
                actionStatusMessage = "Saved for sync"
            case .recovering:
                actionStatusMessage = "Confirming shopping change…"
            case .synced:
                actionStatusMessage = "Shopping list updated"
            }
            actionErrorMessage = nil
            lastFailedAction = nil
            addItemForm.actionStatusMessage = nil
            addItemForm.actionErrorMessage = nil
        } catch {
            actionErrorMessage = "Shopping action failed."
            actionStatusMessage = nil
            lastFailedAction = action
            isRetryButtonFocused = true
            addItemForm.actionStatusMessage = nil
            addItemForm.actionErrorMessage = nil
        }
    }

    private func retryFailedAction() {
        if let lastFailedAction {
            runAction(resubmittedAction(lastFailedAction))
            return
        }
        Task { @MainActor in
            do {
                let outcome = try await retryShoppingMutationRecovery()
                actionStatusMessage = outcome == .queuedForSync ? "Saved for sync" : "Shopping list updated"
                actionErrorMessage = nil
                isRetryButtonFocused = false
            } catch {
                actionErrorMessage = "Shopping action failed."
                isRetryButtonFocused = true
            }
        }
    }

    private func resubmittedAction(_ action: ShoppingSurfaceAction) -> ShoppingSurfaceAction {
        switch action {
        case .addItem(let name, let quantity, let unit, let categoryKey, let iconKey, _):
            .addItem(name: name, quantity: quantity, unit: unit, categoryKey: categoryKey, iconKey: iconKey, clientMutationID: clientMutationID(prefix: "shopping-add-retry"))
        case .setItemChecked(let itemID, let checked, _):
            .setItemChecked(itemID: itemID, checked: checked, clientMutationID: clientMutationID(prefix: "shopping-check-retry"))
        case .deleteItem(let itemID, _, let confirmation):
            .deleteItem(itemID: itemID, clientMutationID: clientMutationID(prefix: "shopping-delete-retry"), confirmation: confirmation)
        case .addRecipeIngredients(let recipeID, let scaleFactor, let recipeIngredients, _):
            .addRecipeIngredients(recipeID: recipeID, scaleFactor: scaleFactor, recipeIngredients: recipeIngredients, clientMutationID: clientMutationID(prefix: "shopping-recipe-retry"))
        case .clearCompleted(_, let confirmation):
            .clearCompleted(clientMutationID: clientMutationID(prefix: "shopping-clear-completed-retry"), confirmation: confirmation)
        case .clearAll(_, let confirmation):
            .clearAll(clientMutationID: clientMutationID(prefix: "shopping-clear-all-retry"), confirmation: confirmation)
        }
    }

    private func confirmedAction(for action: ShoppingSurfaceAction) -> ShoppingSurfaceAction {
        switch action {
        case .deleteItem(let itemID, let clientMutationID, _):
            .deleteItem(itemID: itemID, clientMutationID: clientMutationID, confirmation: .confirmed)
        case .clearCompleted(let clientMutationID, _):
            .clearCompleted(clientMutationID: clientMutationID, confirmation: .confirmed)
        case .clearAll(let clientMutationID, _):
            .clearAll(clientMutationID: clientMutationID, confirmation: .confirmed)
        case .addItem, .setItemChecked, .addRecipeIngredients:
            action
        }
    }

    private func clientMutationID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }
}

private struct ShoppingConfirmationDialog: Identifiable {
    let id = UUID()
    let prompt: ShoppingActionConfirmationPrompt
    let confirmedAction: ShoppingSurfaceAction
}

private struct ShoppingReceiptStateView: View {
    let state: ShoppingReceiptState
    let primaryAction: () -> Void
    let recipeActionTitle: String
    let addFromRecipeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: state.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(state.isSuccess ? KitchenTableTheme.herb : KitchenTableTheme.brass)
                .frame(width: 44, height: 44)
                .background(KitchenTableTheme.paper, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(state.title)
                    .font(KitchenTableTheme.sectionTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineLimit(2)
                Text(state.message)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Button(action: primaryAction) {
                    Label(state.actionTitle ?? "Add item", systemImage: state.actionTitle == "Clear checked" ? "checkmark.circle" : "plus.circle")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))

                Button(action: addFromRecipeAction) {
                    Label(recipeActionTitle, systemImage: recipeActionTitle == "Add from recipe" ? "book" : "square.and.pencil")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}
