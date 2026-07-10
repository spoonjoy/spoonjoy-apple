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
            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.items, id: \.id) { item in
                        Toggle(isOn: checkedBinding(for: item)) {
                            ShoppingReceiptRow(
                                item: item,
                                sourceLine: sourceLine(for: section),
                                duplicateCountLabel: duplicateCountLabel(for: item)
                            )
                        }
                        .toggleStyle(.largeCheck)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(KitchenTableTheme.bone)
                        .accessibilityHint("Double tap to check off this item.")
#if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
#endif
                    }
                } header: {
                    Text(section.title)
                        .font(KitchenTableTheme.uiLabel)
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(KitchenTableTheme.brass)
                        .padding(.top, 8)
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

    private func sourceLine(for section: ShoppingListReceiptSection) -> String? {
        section.title == "Other" ? nil : section.title
    }

    private func duplicateCountLabel(for item: ShoppingListItem) -> String? {
        let matchCount = sections
            .flatMap(\.items)
            .filter { candidate in
                candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                    item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() &&
                    (candidate.unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                    (item.unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            .count

        return matchCount > 1 ? "\(matchCount) on receipt" : nil
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
