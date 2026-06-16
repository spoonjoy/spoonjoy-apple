import Foundation
import SpoonjoyCore
import SwiftUI

struct ShoppingListView: View {
#if os(iOS)
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
#endif
    @State private var viewModel: ShoppingListViewModel
    private let viewModelDidChange: (ShoppingListViewModel, ShoppingListItem, Bool, String) -> Void

    init(
        viewModel: ShoppingListViewModel,
        viewModelDidChange: @escaping (ShoppingListViewModel, ShoppingListItem, Bool, String) -> Void = { _, _, _, _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.viewModelDidChange = viewModelDidChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ReceiptListView(sections: viewModel.sections, setChecked: setChecked)
        }
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KitchenTableTheme.bone)
#if os(iOS)
        .toolbar {
            EditButton()
        }
#endif
    }

    private var shoppingList: ShoppingListState {
        viewModel.shoppingList
    }

#if os(iOS)
    private var currentEditMode: EditMode? {
        editMode?.wrappedValue
    }
#endif

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Shopping")
                    .font(KitchenTableTheme.displayTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text("\(viewModel.checkControlItemIDs.count) active")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }

            Spacer()

#if os(iOS)
            if currentEditMode == .active {
                Label("Editing", systemImage: "slider.horizontal.3")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
#endif
        }
        .padding(.horizontal)
    }

    private func setChecked(_ item: ShoppingListItem, _ checked: Bool) {
        let nextSortIndex = (shoppingList.activeItems.map(\.sortIndex).max() ?? -1) + 1
        let changedAt = timestamp()
        guard let nextShoppingList = try? shoppingList.settingChecked(
            checked,
            itemID: item.id,
            checkedAt: checked ? changedAt : nil,
            nextSortIndex: nextSortIndex
        ) else {
            return
        }

        let nextViewModel = ShoppingListViewModel(shoppingList: nextShoppingList)
        viewModel = nextViewModel
        viewModelDidChange(nextViewModel, item, checked, changedAt)
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
