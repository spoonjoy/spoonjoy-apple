import SpoonjoyCore
import SwiftUI

struct ReceiptListView: View {
    let sections: [ShoppingListReceiptSection]
    let setChecked: (ShoppingListItem, Bool) -> Void
    let deleteItem: (ShoppingListItem) -> Void

    init(
        sections: [ShoppingListReceiptSection],
        setChecked: @escaping (ShoppingListItem, Bool) -> Void,
        deleteItem: @escaping (ShoppingListItem) -> Void = { _ in }
    ) {
        self.sections = sections
        self.setChecked = setChecked
        self.deleteItem = deleteItem
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(sections, id: \.title) { section in
                    KitchenTableSection(title: section.title) {
                        ForEach(section.items, id: \.id) { item in
                            Toggle(isOn: checkedBinding(for: item)) {
                                receiptRow(item)
                            }
                            .toggleStyle(.largeCheck)
#if os(iOS)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }

                                Button {
                                    setChecked(item, true)
                                } label: {
                                    Label("Done", systemImage: "checkmark")
                                }
                                .tint(KitchenTableTheme.herb)
                            }
#endif
                        }
                    }
                }
            }
            .padding(.horizontal, KitchenTableTheme.pagePadding)
            .padding(.bottom, KitchenTableTheme.compactDockReserve)
        }
        .background(KitchenTableTheme.bone)
    }

    private func checkedBinding(for item: ShoppingListItem) -> Binding<Bool> {
        Binding(
            get: { item.checked },
            set: { checked in setChecked(item, checked) }
        )
    }

    private func receiptRow(_ item: ShoppingListItem) -> some View {
        KitchenTableReceiptRow(name: item.name, amount: item.displayQuantity) {
            Image(systemName: symbol(for: item))
                .font(.body.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.brass)
                .frame(width: 22)
        }
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

private struct LargeCheckToggleStyle: ToggleStyle {
    private static let minimumCheckTarget: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(configuration.isOn ? KitchenTableTheme.herb : KitchenTableTheme.brass)
                    .frame(width: Self.minimumCheckTarget, height: Self.minimumCheckTarget)
                    .accessibilityHidden(true)

                configuration.label
            }
            .frame(minHeight: Self.minimumCheckTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "checked" : "unchecked")
    }
}

private extension ToggleStyle where Self == LargeCheckToggleStyle {
    static var largeCheck: LargeCheckToggleStyle {
        LargeCheckToggleStyle()
    }
}
