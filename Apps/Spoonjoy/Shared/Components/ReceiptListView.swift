import SpoonjoyCore
import SwiftUI

struct ReceiptListView: View {
    let sections: [ShoppingPresentationSection]
    let setChecked: (ShoppingListItem, Bool) -> Void
    let deleteItem: (ShoppingListItem) -> Void

    init(
        sections: [ShoppingPresentationSection],
        setChecked: @escaping (ShoppingListItem, Bool) -> Void,
        deleteItem: @escaping (ShoppingListItem) -> Void = { _ in }
    ) {
        self.sections = sections
        self.setChecked = setChecked
        self.deleteItem = deleteItem
    }

    var body: some View {
        List {
            ForEach(sections, id: \.id) { section in
                Section {
                    ForEach(section.items) { presentationItem in
                        let item = presentationItem.item
                        Toggle(isOn: checkedBinding(for: item)) {
                            ShoppingReceiptRow(item: presentationItem)
                        }
                        .toggleStyle(.largeCheck)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(KitchenTableTheme.bone)
                        .accessibilityHint(item.checked ? "Double tap to move this item back to Need." : "Double tap to move this item to Basket.")
                        .modifier(ReceiptDeleteSwipeModifier {
                            deleteItem(item)
                        })
                        .contextMenu {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                deleteItem(item)
                            }
                        }
                    }
                } header: {
                    Text(section.title)
                        .font(KitchenTableTheme.uiLabel)
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(KitchenTableTheme.brass)
                        .padding(.top, 8)
                        .accessibilityLabel(section.title)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .frame(minHeight: receiptListHeight)
    }

    private func checkedBinding(for item: ShoppingListItem) -> Binding<Bool> {
        Binding(
            get: { item.checked },
            set: { checked in setChecked(item, checked) }
        )
    }

    private var receiptListHeight: CGFloat {
        let rowCount = sections.reduce(0) { $0 + $1.items.count }
        let sectionCount = sections.count
        let estimated = CGFloat(rowCount * 82 + sectionCount * 42 + 28)
        return min(max(estimated, 260), 680)
    }

}

private struct ShoppingReceiptRow: View {
    let item: ShoppingPresentationItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol(for: item.iconKey))
                .font(.body.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.brass)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.item.name)
                    .font(KitchenTableTheme.objectTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .strikethrough(item.item.checked, color: KitchenTableTheme.inkMuted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !item.item.displayQuantity.isEmpty {
                        Text(item.item.displayQuantity)
                    }
                    if item.item.checked {
                        Text("already in basket")
                    }
                }
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: item.item))
    }

    private func symbol(for iconKey: String) -> String {
        switch iconKey {
        case "leaf":
            "leaf"
        case "carrot":
            "carrot"
        case "citrus", "apple":
            "apple.logo"
        case "drumstick", "beef", "fish", "egg":
            "fork.knife"
        case "milk":
            "fork.knife"
        case "wheat", "sandwich":
            "takeoutbag.and.cup.and.straw"
        case "droplets":
            "drop"
        case "pot":
            "flame"
        default:
            "shippingbox"
        }
    }

    private func accessibilityText(for item: ShoppingListItem) -> String {
        let quantity = item.displayQuantity.isEmpty ? "" : ", \(item.displayQuantity)"
        let basket = item.checked ? ", already in basket" : ""
        return "\(item.name)\(quantity)\(basket)"
    }
}

private struct ReceiptDeleteSwipeModifier: ViewModifier {
    let delete: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: delete) {
                    Label("Remove", systemImage: "trash")
                }
            }
#else
        content
#endif
    }
}

struct LargeCheckToggleStyle: ToggleStyle {
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

extension ToggleStyle where Self == LargeCheckToggleStyle {
    static var largeCheck: LargeCheckToggleStyle {
        LargeCheckToggleStyle()
    }
}
