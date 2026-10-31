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
    @State private var checkHapticTick = 0
    @State private var remindersSender = SpoonjoyRemindersSender()
    @FocusState private var isItemFieldFocused: Bool
    @FocusState private var isRetryButtonFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.spoonjoyCompactNavigation) private var usesCompactNavigation

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
        actionDidPlan: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome,
        shoppingMutationFeedback: ShoppingMutationFeedback?,
        retryShoppingMutationRecovery: @escaping @MainActor @Sendable () async throws -> ShoppingSurfaceMutationOutcome,
        hasRecipes: Bool,
        openSearch: @escaping () -> Void,
        createRecipe: @escaping () -> Void,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void
    ) {
        let screenshotEnvironment = ProcessInfo.processInfo.environment
        let initialMode: ShoppingListViewMode
        if let rawMode = screenshotEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_MODE"],
           let configuredMode = ShoppingListViewMode(rawValue: rawMode) {
            initialMode = configuredMode
        } else {
            initialMode = .all
        }
        let initialCategory: String
        if let configuredCategory = screenshotEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_CATEGORY"] {
            initialCategory = configuredCategory
        } else {
            initialCategory = "all"
        }
        let initialPendingItemIDs: Set<String> = screenshotEnvironment["SPOONJOY_SCREENSHOT_SHOPPING_VARIANT"] == "pending" ? ["item_lemons"] : []
        self.viewModel = viewModel
        (_viewMode, _activeCategory, _pendingItemIDs) = (
            State(initialValue: initialMode),
            State(initialValue: initialCategory),
            State(initialValue: initialPendingItemIDs)
        )
        (self.actionDidPlan, self.shoppingMutationFeedback, self.retryShoppingMutationRecovery) = (
            actionDidPlan, shoppingMutationFeedback, retryShoppingMutationRecovery
        )
        (self.hasRecipes, self.openSearch, self.createRecipe) = (hasRecipes, openSearch, createRecipe)
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
    }

    var body: some View {
        KitchenTablePage(maxContentWidth: 760, topPadding: usesCompactNavigation ? 4 : 20) {
            shoppingRunHeader
            VStack(alignment: .leading, spacing: 10) {
                shoppingReceiptComposer
                activeFilterLine
                statusBanner
            }
            shoppingReceiptState
        }
        .spoonjoyRemindersSend(remindersSender)
        .onChange(of: remindersSender.statusMessage) { _, message in
            if let message {
                actionErrorMessage = nil
                actionStatusMessage = message
            }
        }
        .onChange(of: remindersSender.errorMessage) { _, message in
            if let message {
                actionStatusMessage = nil
                actionErrorMessage = message
            }
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
            if usesCompactNavigation, shoppingList != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    receiptActionsMenu
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .navigationSubtitle(usesCompactNavigation ? viewModel.shoppingRunSummary : "")
#endif
        .sensoryFeedback(.selection, trigger: checkHapticTick)
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

    /// On a phone the navigation bar carries the title, the run summary (as its subtitle) and the actions
    /// menu, so the list leads with the composer and the items. Wide layouts keep the full header.
    @ViewBuilder private var shoppingRunHeader: some View {
        if !usesCompactNavigation {
            KitchenTableHeader(
                title: "Shopping List",
                subtitle: viewModel.shoppingRunSummary,
                hidesTitleInCompactNavigation: true
            ) {
                shoppingHeaderTools
            }
        }
    }

    private var shoppingTitleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shopping")
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.ink)
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
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
#endif
        }
    }

    private var receiptActionsMenu: some View {
        Menu {
            // Need, Basket and All, and the aisle filter, live here rather than as bars over the list.
            if let presentation = shoppingPresentation {
                shoppingModeStrip(presentation)
                shoppingCategoryFilters(presentation)
                Divider()
            }
            Button {
                remindersSender.send(
                    ingredients: ReminderIncomingIngredient.fromShoppingItems(shoppingList?.items ?? []),
                    source: .shoppingList
                )
            } label: {
                Label("Send to Reminders", systemImage: "checklist")
            }
            Button {
                remindersSender.chooseList()
            } label: {
                Label(
                    remindersSender.currentListTitle.map { "Reminders list: \($0)" } ?? "Choose Reminders list",
                    systemImage: "list.bullet"
                )
            }
            Button("Clear checked") {
                clearCompleted()
            }
            Button("Clear all", role: .destructive) {
                clearAll()
            }
        } label: {
            if usesCompactNavigation {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Receipt actions")
            } else {
                Group {
                    if isAccessibilityLayout {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("Receipt actions")
                    } else {
                        Label("Receipt actions", systemImage: "ellipsis.circle")
                    }
                }
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .modifier(CompactMenuTapTarget(isCompact: usesCompactNavigation))
    }

    private var shoppingList: ShoppingListState? {
        viewModel.shoppingList
    }

    private var shoppingPresentation: ShoppingPresentationModel? {
        viewModel.presentation(mode: viewMode, activeCategory: activeCategory)
    }

    /// Need, Basket and All, as an inline picker in the ⋯ menu.
    private func shoppingModeStrip(_ presentation: ShoppingPresentationModel) -> some View {
        Picker("Show", selection: modeSelection) {
            ForEach(presentation.modeOptions, id: \.mode) { option in
                Text(option.label).tag(option.mode)
            }
        }
        .pickerStyle(.inline)
    }

    /// The aisle filter, as a submenu in the ⋯ menu; a list with one aisle has nothing to filter.
    @ViewBuilder private func shoppingCategoryFilters(_ presentation: ShoppingPresentationModel) -> some View {
        if presentation.categoryOptions.count > 1 {
            Picker(selection: $activeCategory) {
                ForEach(presentation.categoryOptions, id: \.self) { category in
                    Text(categoryLabel(category)).tag(category)
                }
            } label: {
                Label("Aisle: \(categoryLabel(presentation.activeCategory))", systemImage: "basket")
            }
            .pickerStyle(.menu)
        }
    }

    /// Changing the view resets the aisle, as the old bar did, so a filter never hides a whole view.
    private var modeSelection: Binding<ShoppingListViewMode> {
        Binding(
            get: { viewMode },
            set: { mode in
                viewMode = mode
                activeCategory = "all"
            }
        )
    }

    /// While the list is narrowed, one quiet line says how, with the way back to everything.
    @ViewBuilder private var activeFilterLine: some View {
        if let presentation = shoppingPresentation, viewMode != .all || presentation.activeCategory != "all" {
            let layout = isAccessibilityLayout
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                activeFilterLabel(presentation)
                if !isAccessibilityLayout {
                    Spacer(minLength: 8)
                }
                showAllButton
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shopping.activeFilter")
        }
    }

    private func activeFilterLabel(_ presentation: ShoppingPresentationModel) -> some View {
        let parts = [
            viewMode == .all ? nil : selectedModeLabel(in: presentation),
            presentation.activeCategory == "all" ? nil : presentation.activeCategory
        ].compactMap { $0 }
        return Label("Showing \(parts.joined(separator: " · "))", systemImage: "line.3.horizontal.decrease")
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var showAllButton: some View {
        Button("Show all") {
            viewMode = .all
            activeCategory = "all"
        }
        .font(KitchenTableTheme.uiLabel.weight(.semibold))
        .foregroundStyle(KitchenTableTheme.brass)
        .buttonStyle(.plain)
        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
        .accessibilityIdentifier("shopping.showAll")
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
                    compactRecipeActionButton
                }
            }
            if isAccessibilityLayout {
                recipeActionButton
            }
        }
    }

    private var addItemControls: some View {
        shoppingReceiptComposer
    }

    private var itemNameField: some View {
        TextField("Add an item", text: $addItemForm.itemName)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .glassEffect(.regular.interactive(), in: Capsule())
            .focused($isItemFieldFocused)
            .onSubmit(addItem)
    }

    private var quantityField: some View {
        TextField("Amount", text: $addItemForm.itemQuantity)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .glassEffect(.regular.interactive(), in: Capsule())
            .frame(maxWidth: 120)
#if os(iOS)
            .keyboardType(.decimalPad)
#endif
    }

    private var unitField: some View {
        TextField("Measure", text: $addItemForm.itemUnit)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .glassEffect(.regular.interactive(), in: Capsule())
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
                .frame(width: 48, height: 48)
                .foregroundStyle(KitchenTableTheme.onInk)
                .background(KitchenTableTheme.ink, in: Circle())
                .glassEffect(.regular.interactive(), in: Circle())
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
            Label("Add a recipe", systemImage: "plus")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
        .accessibilityIdentifier("shopping.createRecipe")
    }

    /// The phone composer keeps the recipe action beside the add button as an icon, so it costs no row.
    @ViewBuilder private var compactRecipeActionButton: some View {
        if hasRecipes {
            Button(action: openSearch) {
                Label("Add from recipe", systemImage: "book")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        } else {
            Button(action: createRecipe) {
                Label("Add a recipe", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(KitchenTableTheme.ink)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shopping.createRecipe")
        }
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
                Label("Add a recipe", systemImage: "plus")
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .accessibilityIdentifier("shopping.createRecipe")
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
        presentation.modeOptions.first { $0.mode == viewMode }!.label
    }

    private func categoryLabel(_ category: String) -> String {
        category == "all" ? "All aisles" : category
    }

    @ViewBuilder private var shoppingReceiptState: some View {
        if let presentation = shoppingPresentation, let emptyTitle = presentation.emptyTitle {
            shoppingMarketEmptyState(
                title: emptyTitle,
                message: presentation.emptyMessage!
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
                recipeActionTitle: hasRecipes ? "Add from recipe" : "Add a recipe",
                addFromRecipeAction: hasRecipes ? openSearch : createRecipe
            )
        }
    }

    private func shoppingMarketEmptyState(title: String, message: String) -> some View {
        KitchenTableEmptyTile(systemImage: "basket", title: title, message: message)
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
        checkHapticTick += 1
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

    private func runAction(
        _ action: ShoppingSurfaceAction,
        pendingItemID: String? = nil,
        clearsFailedActionOnSuccess: Bool = false
    ) {
        Task {
            await perform(
                action,
                pendingItemID: pendingItemID,
                clearsFailedActionOnSuccess: clearsFailedActionOnSuccess
            )
        }
    }

    @MainActor private func perform(
        _ action: ShoppingSurfaceAction,
        pendingItemID: String? = nil,
        clearsFailedActionOnSuccess: Bool = false
    ) async {
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
            if clearsFailedActionOnSuccess {
                lastFailedAction = nil
            }
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
            runAction(resubmittedAction(lastFailedAction), clearsFailedActionOnSuccess: true)
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

private struct CompactMenuTapTarget: ViewModifier {
    let isCompact: Bool

    func body(content: Content) -> some View {
        if isCompact {
            content.frame(minWidth: KitchenTableTheme.minimumTouchTarget, minHeight: KitchenTableTheme.minimumTouchTarget)
        } else {
            content
        }
    }
}

private struct ShoppingConfirmationDialog: Identifiable {
    let id: UUID
    let prompt: ShoppingActionConfirmationPrompt
    let confirmedAction: ShoppingSurfaceAction

    init(prompt: ShoppingActionConfirmationPrompt, confirmedAction: ShoppingSurfaceAction) {
        self.id = UUID()
        self.prompt = prompt
        self.confirmedAction = confirmedAction
    }
}

private struct ShoppingReceiptStateView: View {
    let state: ShoppingReceiptState
    let primaryAction: () -> Void
    let recipeActionTitle: String
    let addFromRecipeAction: () -> Void

    init(state: ShoppingReceiptState, primaryAction: @escaping () -> Void, recipeActionTitle: String, addFromRecipeAction: @escaping () -> Void) {
        (self.state, self.primaryAction) = (state, primaryAction)
        (self.recipeActionTitle, self.addFromRecipeAction) = (recipeActionTitle, addFromRecipeAction)
    }

    /// One way in: Clear checked when everything is in the basket, otherwise a recipe's ingredients. Typing an item
    /// is already the field above.
    var body: some View {
        KitchenTableEmptyTile(
            systemImage: state.systemImage,
            title: state.title,
            message: state.message,
            tint: state.isSuccess ? KitchenTableTheme.herb : KitchenTableTheme.brass
        ) {
            if state.actionTitle == "Clear checked" {
                Button(action: primaryAction) {
                    Label("Clear checked", systemImage: "checkmark.circle")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            } else {
                Button(action: addFromRecipeAction) {
                    Label(recipeActionTitle, systemImage: recipeActionTitle == "Add from recipe" ? "book" : "plus")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            }
        }
    }
}
