import SpoonjoyCore
import SwiftUI

struct ReceiptListView: View {
    let sections: [ShoppingListReceiptSection]
    let setChecked: (ShoppingListItem, Bool) -> Void

    var body: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.id) { item in
                        Toggle(isOn: checkedBinding(for: item)) {
                            receiptRow(item)
                        }
                        .toggleStyle(.automatic)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                setChecked(item, true)
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(KitchenTableTheme.herb)
                        }
                    }
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
    }

    private func checkedBinding(for item: ShoppingListItem) -> Binding<Bool> {
        Binding(
            get: { item.checked },
            set: { checked in setChecked(item, checked) }
        )
    }

    private func receiptRow(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 12) {
            Label(item.name, systemImage: symbol(for: item))
                .font(.body)
                .foregroundStyle(KitchenTableTheme.charcoal)

            Spacer()

            Text(item.displayQuantity)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: item))
    }

    private func symbol(for item: ShoppingListItem) -> String {
        switch item.iconKey {
        case "lemon":
            "circle.lefthalf.filled"
        case "pasta":
            "fork.knife"
        case "cheese":
            "square.stack.3d.down.forward"
        case "herb":
            "leaf"
        default:
            "cart"
        }
    }

    private func accessibilityText(for item: ShoppingListItem) -> String {
        let quantity = item.displayQuantity.isEmpty ? "" : ", \(item.displayQuantity)"
        return "\(item.name)\(quantity)"
    }
}
