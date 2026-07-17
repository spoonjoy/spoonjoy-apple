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
        List {
            ForEach(sections, id: \.id) { section in
                Section {
                    ForEach(section.items, id: \.id) { item in
                        let isDuplicateReview = section.duplicateItemIDs.contains(item.id)
                        HStack(spacing: 8) {
                            Toggle(isOn: checkedBinding(for: item)) {
                                ShoppingReceiptRow(
                                    item: item,
                                    sourceLine: sourceLine(for: section, item: item),
                                    duplicateCountLabel: duplicateCountLabel(for: item, in: section)
                                )
                            }
                            .toggleStyle(.largeCheck)

                            if isDuplicateReview {
                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove duplicate \(item.name)")
                                .help("Remove duplicate")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(KitchenTableTheme.bone)
                        .accessibilityHint(
                            isDuplicateReview
                                ? "Review this duplicate, then remove it or check it off."
                                : "Double tap to check off this item."
                        )
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
                        .accessibilityLabel(
                            section.role == .duplicateReview ? "Duplicates to review" : section.title
                        )
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

    private func sourceLine(for section: ShoppingListReceiptSection, item: ShoppingListItem) -> String? {
        if section.role == .duplicateReview {
            return categoryLine(for: item.categoryKey)
        }

        return section.title == "Other" ? nil : section.title
    }

    private func duplicateCountLabel(for item: ShoppingListItem, in section: ShoppingListReceiptSection) -> String? {
        section.duplicateItemIDs.contains(item.id) ? "Review duplicate" : nil
    }

    private func categoryLine(for categoryKey: String?) -> String? {
        guard let categoryKey, !categoryKey.isEmpty else {
            return nil
        }

        return categoryKey
            .split(separator: "-")
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }
}

private struct ShoppingReceiptRow: View {
    let item: ShoppingListItem
    let sourceLine: String?
    let duplicateCountLabel: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol(for: item))
                .font(.body.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.brass)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(KitchenTableTheme.objectTitle)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !item.displayQuantity.isEmpty {
                        Text(item.displayQuantity)
                    }
                    if let sourceLine {
                        Text(sourceLine)
                    }
                    if let duplicateCountLabel {
                        Text(duplicateCountLabel)
                    }
                }
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        let source = sourceLine.map { ", \($0)" } ?? ""
        let duplicate = duplicateCountLabel.map { ", \($0)" } ?? ""
        return "\(item.name)\(quantity)\(source)\(duplicate)"
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
