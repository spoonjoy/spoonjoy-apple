import SwiftUI

struct SpoonDock: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let context: SpoonDockContext

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityDock
            } else {
                adaptiveDock
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.accessibilityLabel)
    }

    private var adaptiveDock: some View {
        ViewThatFits(in: .horizontal) {
            horizontalDock
            compactDock
        }
    }

    private var horizontalDock: some View {
        HStack(alignment: .center, spacing: 10) {
            dockButton(context.leftZone, prominence: .supporting)
                .frame(maxWidth: 112, alignment: .leading)
                .layoutPriority(1)

            Spacer(minLength: 4)

            dockButton(context.centerZone, prominence: .primary)
                .frame(maxWidth: .infinity)
                .layoutPriority(2)

            Spacer(minLength: 4)

            toolRail
                .layoutPriority(1)
        }
    }

    private var compactDock: some View {
        HStack(alignment: .center, spacing: 8) {
            dockButton(context.leftZone, prominence: .tool)
                .frame(width: 44, height: 44)
                .layoutPriority(1)

            dockButton(context.centerZone, prominence: .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .layoutPriority(2)

            toolRail
                .layoutPriority(1)
        }
    }

    private var accessibilityDock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                dockButton(context.leftZone, prominence: .supporting)
                    .frame(maxWidth: .infinity, alignment: .leading)

                dockButton(context.centerZone, prominence: .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            toolRail
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var toolRail: some View {
        HStack(spacing: 6) {
            ForEach(context.rightTools) { action in
                dockButton(action, prominence: .tool)
                    .frame(width: 44, height: 44)
            }
        }
    }

    @ViewBuilder
    private func dockButton(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if prominence == .primary {
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.glassProminent)
                .tint(tintColor(for: action))
        } else {
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.glass)
                .tint(tintColor(for: action))
        }
    }

    private func tintColor(for action: SpoonDockAction) -> Color? {
        action.role == .destructive ? KitchenTableTheme.tomato : nil
    }

    @ViewBuilder
    private func dockTrigger(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if let shareURL = action.shareURL {
            ShareLink(item: shareURL) {
                dockLabel(action, prominence: prominence)
            }
            .disabled(!action.isEnabled)
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityHint(action.accessibilityHint ?? "")
        } else {
            Button(action: action.action) {
                dockLabel(action, prominence: prominence)
            }
            .disabled(!action.isEnabled)
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityHint(action.accessibilityHint ?? "")
        }
    }

    @ViewBuilder
    private func dockLabel(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if prominence == .tool {
            Image(systemName: action.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42)
        } else {
            HStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .font(.system(size: prominence == .primary ? 18 : 15, weight: .semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(prominence == .primary ? .headline : .subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if let subtitle = action.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 2)
        }
    }
}

struct SpoonDockContext {
    let routeIdentifier: String
    let leftZone: SpoonDockAction
    let centerZone: SpoonDockAction
    let rightTools: [SpoonDockAction]

    var accessibilityLabel: String {
        "\(routeIdentifier) SpoonDock"
    }
}

struct SpoonDockAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String
    let role: SpoonDockActionRole
    let isEnabled: Bool
    let shareURL: URL?
    let accessibilityLabel: String
    let accessibilityHint: String?
    let action: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        role: SpoonDockActionRole,
        isEnabled: Bool = true,
        shareURL: URL? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.shareURL = shareURL
        self.accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
}

enum SpoonDockActionRole {
    case place
    case back
    case primary
    case status
    case tool
    case destructive
}

private enum SpoonDockActionProminence {
    case supporting
    case primary
    case tool
}

extension SpoonDockContext {
    static func kitchen(capture: @escaping () -> Void, search: @escaping () -> Void, shopping: @escaping () -> Void) -> Self {
        Self(
            routeIdentifier: "Kitchen",
            leftZone: .place(id: "kitchen.place", title: "Kitchen", systemImage: "house"),
            centerZone: .primary(id: "kitchen.capture", title: "Capture", subtitle: "new recipe", systemImage: "camera.fill", action: capture),
            rightTools: [
                .tool(id: "kitchen.search", title: "Search", systemImage: "magnifyingglass", action: search),
                .tool(id: "kitchen.shopping", title: "Shopping", systemImage: "checklist", action: shopping)
            ]
        )
    }

    static func recipes(capture: @escaping () -> Void, search: @escaping () -> Void, shopping: @escaping () -> Void) -> Self {
        Self(
            routeIdentifier: "Recipes",
            leftZone: .place(id: "recipes.place", title: "Recipes", systemImage: "book.closed"),
            centerZone: .primary(id: "recipes.capture", title: "Capture", subtitle: "save a recipe", systemImage: "camera.fill", action: capture),
            rightTools: [
                .tool(id: "recipes.search", title: "Search", systemImage: "magnifyingglass", action: search),
                .tool(id: "recipes.shopping", title: "Shopping", systemImage: "checklist", action: shopping)
            ]
        )
    }

    static func recipeDetail(back: @escaping () -> Void, cook: @escaping () -> Void, save: @escaping () -> Void, shareURL: URL?) -> Self {
        Self(
            routeIdentifier: "Recipe detail",
            leftZone: .back(id: "recipe.back", title: "Recipes", systemImage: "chevron.backward", action: back),
            centerZone: .primary(id: "recipe.cook", title: "Cook", subtitle: "hands-free", systemImage: "fork.knife", action: cook),
            rightTools: [
                .tool(id: "recipe.save", title: "Save", systemImage: "bookmark", action: save),
                .tool(id: "recipe.share", title: "Share", systemImage: "square.and.arrow.up", isEnabled: shareURL != nil, shareURL: shareURL)
            ]
        )
    }

    static func cookMode(previous: @escaping () -> Void, next: @escaping () -> Void, stepTitle: String) -> Self {
        Self(
            routeIdentifier: "Cook mode",
            leftZone: .back(id: "cook.previous", title: "Previous", systemImage: "chevron.backward", action: previous),
            centerZone: .status(id: "cook.step", title: "Step", subtitle: stepTitle, systemImage: "flame", isEnabled: false),
            rightTools: [
                .tool(id: "cook.next", title: "Next", systemImage: "chevron.forward", action: next)
            ]
        )
    }

    static func shoppingList(add: @escaping () -> Void, search: @escaping () -> Void, clearChecked: @escaping () -> Void) -> Self {
        Self(
            routeIdentifier: "Shopping",
            leftZone: .place(id: "shopping.place", title: "List", systemImage: "checklist"),
            centerZone: .primary(id: "shopping.add", title: "Add", subtitle: "item", systemImage: "plus", action: add),
            rightTools: [
                .tool(id: "shopping.search", title: "Search", systemImage: "magnifyingglass", action: search),
                .tool(id: "shopping.clear.checked", title: "Clear checked", subtitle: "clear checked", systemImage: "checkmark.circle", role: .destructive, action: clearChecked)
            ]
        )
    }

    static func search(capture: @escaping () -> Void, scopeTitle: String, shopping: @escaping () -> Void) -> Self {
        Self(
            routeIdentifier: "Search",
            leftZone: .place(id: "search.place", title: "Search", systemImage: "magnifyingglass"),
            centerZone: .primary(id: "search.capture", title: "Capture", subtitle: "from anywhere", systemImage: "camera.fill", action: capture),
            rightTools: [
                .tool(id: "search.scope", title: scopeTitle, systemImage: "line.3.horizontal.decrease.circle"),
                .tool(id: "search.shopping", title: "Shopping", systemImage: "checklist", action: shopping)
            ]
        )
    }

    static func capture(back: @escaping () -> Void, settings: @escaping () -> Void) -> Self {
        Self(
            routeIdentifier: "Capture",
            leftZone: .back(id: "capture.back", title: "Kitchen", systemImage: "chevron.backward", action: back),
            centerZone: .primary(id: "capture.save", title: "Capture", subtitle: "import recipe", systemImage: "camera.fill"),
            rightTools: [
                .tool(id: "capture.settings", title: "Settings", systemImage: "gearshape", action: settings)
            ]
        )
    }

    static func settings(back: @escaping () -> Void, retry: @escaping () -> Void, search: @escaping () -> Void) -> Self {
        Self(
            routeIdentifier: "Settings",
            leftZone: .back(id: "settings.back", title: "Kitchen", systemImage: "chevron.backward", action: back),
            centerZone: .primary(id: "settings.retry", title: "Retry", subtitle: "sync", systemImage: "arrow.clockwise", action: retry),
            rightTools: [
                .tool(id: "settings.search", title: "Search", systemImage: "magnifyingglass", action: search)
            ]
        )
    }

    static func generic(title: String, back: @escaping () -> Void, search: @escaping () -> Void, shopping: @escaping () -> Void) -> Self {
        Self(
            routeIdentifier: title,
            leftZone: .back(id: "generic.back", title: "Kitchen", systemImage: "chevron.backward", action: back),
            centerZone: .place(id: "generic.place", title: title, systemImage: "sparkles"),
            rightTools: [
                .tool(id: "generic.search", title: "Search", systemImage: "magnifyingglass", action: search),
                .tool(id: "generic.shopping", title: "Shopping", systemImage: "checklist", action: shopping)
            ]
        )
    }
}

private extension SpoonDockAction {
    static func place(id: String, title: String, systemImage: String) -> Self {
        Self(id: id, title: title, systemImage: systemImage, role: .place, isEnabled: false)
    }

    static func back(id: String, title: String, systemImage: String, action: @escaping () -> Void) -> Self {
        Self(id: id, title: title, systemImage: systemImage, role: .back, accessibilityHint: "Return to \(title).", action: action)
    }

    static func primary(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        action: @escaping () -> Void = {}
    ) -> Self {
        Self(id: id, title: title, subtitle: subtitle, systemImage: systemImage, role: .primary, action: action)
    }

    static func status(id: String, title: String, subtitle: String?, systemImage: String, isEnabled: Bool) -> Self {
        Self(id: id, title: title, subtitle: subtitle, systemImage: systemImage, role: .status, isEnabled: isEnabled)
    }

    static func tool(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        role: SpoonDockActionRole = .tool,
        isEnabled: Bool = true,
        shareURL: URL? = nil,
        action: @escaping () -> Void = {}
    ) -> Self {
        Self(
            id: id,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            role: role,
            isEnabled: isEnabled,
            shareURL: shareURL,
            action: action
        )
    }
}
