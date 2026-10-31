import SpoonjoyCore
import SwiftUI

struct ReceiptListView: View {
    let sections: [ShoppingPresentationSection]
    let pendingItemIDs: Set<String>
    let setChecked: (ShoppingListItem, Bool) -> Void
    let deleteItem: (ShoppingListItem) -> Void

    init(
        sections: [ShoppingPresentationSection],
        pendingItemIDs: Set<String> = [],
        setChecked: @escaping (ShoppingListItem, Bool) -> Void,
        deleteItem: @escaping (ShoppingListItem) -> Void = { _ in }
    ) {
        self.sections = sections
        self.pendingItemIDs = pendingItemIDs
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
                            ShoppingReceiptRow(
                                item: presentationItem,
                                isPending: pendingItemIDs.contains(item.id)
                            )
                        }
                        .toggleStyle(.largeCheck)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(KitchenTableTheme.page)
                        .accessibilityHint(item.isEffectivelyChecked ? "Double tap to move this item back to Need." : "Double tap to move this item to Basket.")
                        .accessibilityIdentifier(pendingItemIDs.contains(item.id)
                            ? "shopping.item.\(item.id).pending"
                            : "shopping.item.\(item.id)")
                        .disabled(pendingItemIDs.contains(item.id))
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
                    // The aisle in the serif with how many are in it, in place of an all-caps kicker.
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(section.title)
                            .font(KitchenTableTheme.indexTitle)
                            .foregroundStyle(KitchenTableTheme.ink)
                        Text("\(section.items.count)")
                            .font(KitchenTableTheme.meta.monospacedDigit())
                            .foregroundStyle(KitchenTableTheme.ink2)
                    }
                    .textCase(nil)
                    .padding(.top, 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(section.title), \(section.items.count) \(section.items.count == 1 ? "item" : "items")")
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListHeaderHeight, 28)
        .contentMargins(.top, 0, for: .scrollContent)
#if os(iOS)
        .listSectionSpacing(0)
#endif
        .background(KitchenTableTheme.page)
        .frame(minHeight: receiptListHeight)
    }

    private func checkedBinding(for item: ShoppingListItem) -> Binding<Bool> {
        Binding(
            get: { item.isEffectivelyChecked },
            set: { checked in
                setChecked(item, checked)
                AccessibilityNotification.Announcement(
                    checked ? "Moved \(item.name) to Basket." : "Moved \(item.name) to Need."
                ).post()
            }
        )
    }

    private var receiptListHeight: CGFloat {
        let rowCount = sections.reduce(0) { $0 + $1.items.count }
        let sectionCount = sections.count
        let estimated = CGFloat(rowCount * 52 + sectionCount * 34 + 28)
        return min(max(estimated, 260), 680)
    }

}

private struct ShoppingReceiptRow: View {
    let item: ShoppingPresentationItem
    let isPending: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // No aisle icon per row: the aisle heading above already says where it is.
        HStack(alignment: .center, spacing: 12) {
            // One line per item, as on the web list: name leading, amount trailing. At accessibility text
            // sizes the amount drops under the name so neither is squeezed.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    nameText
                    detailLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    nameText
                    if item.item.isEffectivelyChecked {
                        Text("already in basket")
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !item.item.displayQuantity.isEmpty {
                    Text(item.item.displayQuantity)
                        .font(KitchenTableTheme.bodyNote.monospacedDigit())
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .lineLimit(1)
                }
            }

            if isPending {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Saving \(item.item.name)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: item.item))
    }

    private var nameText: some View {
        Text(item.item.name)
            .font(KitchenTableTheme.instructionBody)
            .foregroundStyle(item.item.isEffectivelyChecked ? KitchenTableTheme.ink2 : KitchenTableTheme.ink)
            .strikethrough(item.item.isEffectivelyChecked, color: KitchenTableTheme.ink2)
            // At the accessibility sizes a long name wraps in full instead of truncating.
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var detailLine: some View {
        HStack(spacing: 8) {
            if !item.item.displayQuantity.isEmpty {
                Text(item.item.displayQuantity)
            }
            if item.item.isEffectivelyChecked {
                Text("already in basket")
            }
        }
        .font(KitchenTableTheme.uiLabel)
        .foregroundStyle(KitchenTableTheme.ink2)
        .lineLimit(1)
    }

    private func accessibilityText(for item: ShoppingListItem) -> String {
        let quantity = item.displayQuantity.isEmpty ? "" : ", \(item.displayQuantity)"
        let basket = item.isEffectivelyChecked ? ", already in basket" : ""
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
    private static let minimumCheckTarget: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
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
