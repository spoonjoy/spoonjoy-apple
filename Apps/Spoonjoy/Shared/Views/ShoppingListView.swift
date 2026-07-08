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
    @FocusState private var isItemFieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private let viewModel: ShoppingSurfaceViewModel
    private let actionDidPlan: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    private let openSearch: () -> Void
    private let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    init(
        viewModel: ShoppingSurfaceViewModel,
        actionDidPlan: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome = { _ in .synced },
        openSearch: @escaping () -> Void = {},
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.actionDidPlan = actionDidPlan
        self.openSearch = openSearch
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            addItemControls
            statusBanner

            if let emptyState = viewModel.emptyState {
                ContentUnavailableView(
                    emptyState.title,
                    systemImage: emptyState.systemImage,
                    description: Text(emptyState.message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ReceiptListView(
                    sections: viewModel.sections,
                    setChecked: settingChecked,
                    deleteItem: deleteItem
                )
            }
        }
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
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

    private var header: some View {
        KitchenTableHeader(
            eyebrow: "Market Run",
            title: "Shopping List",
            subtitle: viewModel.activeCountLabel
        ) {
            shoppingHeaderTools
        }
        .padding(.horizontal)
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
                Menu {
                    Button("Clear Completed") {
                        clearCompleted()
                    }
                    Button("Clear All", role: .destructive) {
                        clearAll()
                    }
                } label: {
                    Label("List Actions", systemImage: "ellipsis.circle")
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

#if os(iOS)
            if currentEditMode == .active {
                Label("Editing", systemImage: "slider.horizontal.3")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
#endif
        }
    }

    private var shoppingList: ShoppingListState? {
        viewModel.shoppingList
    }

    private var addItemControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            itemNameField
            HStack(spacing: 8) {
                quantityField
                unitField
                addItemButton
            }
        }
        .padding(.horizontal)
    }

    private var itemNameField: some View {
        TextField("Item", text: $addItemForm.itemName)
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
        TextField("Qty", text: $addItemForm.itemQuantity)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
            .frame(width: 74)
#if os(iOS)
            .keyboardType(.decimalPad)
#endif
    }

    private var unitField: some View {
        TextField("Unit", text: $addItemForm.itemUnit)
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
            .frame(width: 96)
    }

    private var addItemButton: some View {
        Button(action: addItem) {
            Label("Add", systemImage: "plus.circle")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
    }

    @ViewBuilder private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.offlineIndicator.display != .synced {
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
            }
            if let queuedWorkSummary = viewModel.queuedWorkSummary {
                Label(queuedWorkSummary, systemImage: "arrow.triangle.2.circlepath")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
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
                Label(visibleActionErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
            }
        }
        .padding(.horizontal)
    }

    private var visibleActionStatusMessage: String? {
        actionStatusMessage ?? addItemForm.actionStatusMessage
    }

    private var visibleActionErrorMessage: String? {
        actionErrorMessage ?? addItemForm.actionErrorMessage
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
        ))
    }

    private func deleteItem(_ item: ShoppingListItem) {
        runAction(.deleteItem(
            itemID: item.id,
            clientMutationID: clientMutationID(prefix: "shopping-delete"),
            confirmation: .required
        ))
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

    private func runAction(_ action: ShoppingSurfaceAction) {
        Task {
            await perform(action)
        }
    }

    @MainActor private func perform(_ action: ShoppingSurfaceAction) async {
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
            actionStatusMessage = outcome == .queuedForSync ? "Saved for sync" : "Shopping list updated"
            actionErrorMessage = nil
            addItemForm.actionStatusMessage = nil
            addItemForm.actionErrorMessage = nil
        } catch {
            actionErrorMessage = "Shopping action failed."
            actionStatusMessage = nil
            addItemForm.actionStatusMessage = nil
            addItemForm.actionErrorMessage = nil
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
