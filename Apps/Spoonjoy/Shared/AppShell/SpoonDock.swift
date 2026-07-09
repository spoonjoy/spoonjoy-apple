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
        .padding(.horizontal, SpoonDockMetrics.horizontalPadding)
        .padding(.vertical, SpoonDockMetrics.verticalPadding)
        .frame(maxWidth: SpoonDockMetrics.maximumWidth)
        .background(.ultraThinMaterial, in: Capsule())
        .background(KitchenTableTheme.paper.opacity(0.82), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(KitchenTableTheme.line.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: KitchenTableTheme.charcoal.opacity(0.12), radius: 10, x: 0, y: 4)
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
        HStack(alignment: .center, spacing: SpoonDockMetrics.itemSpacing) {
            dockButton(context.leftZone, prominence: .supporting)
                .frame(width: SpoonDockMetrics.supportingWidth, alignment: .leading)
                .layoutPriority(1)

            dockButton(context.centerZone, prominence: .primary)
                .frame(minWidth: SpoonDockMetrics.primaryMinWidth, maxWidth: .infinity)
                .layoutPriority(2)

            toolRail
                .layoutPriority(1)
        }
    }

    private var compactDock: some View {
        HStack(alignment: .center, spacing: SpoonDockMetrics.itemSpacing) {
            dockButton(context.leftZone, prominence: .tool)
                .frame(width: SpoonDockMetrics.toolTargetSize, height: SpoonDockMetrics.toolTargetSize)
                .layoutPriority(1)

            dockButton(context.centerZone, prominence: .primary)
                .frame(maxWidth: .infinity, minHeight: SpoonDockMetrics.minimumTargetSize)
                .layoutPriority(2)

            toolRail
                .layoutPriority(1)
        }
    }

    private var accessibilityDock: some View {
        VStack(alignment: .leading, spacing: SpoonDockMetrics.itemSpacing) {
            HStack(spacing: SpoonDockMetrics.itemSpacing) {
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
        HStack(spacing: SpoonDockMetrics.toolSpacing) {
            ForEach(context.rightTools) { action in
                dockButton(action, prominence: .tool)
                    .frame(width: SpoonDockMetrics.toolTargetSize, height: SpoonDockMetrics.toolTargetSize)
            }
        }
    }

    @ViewBuilder
    private func dockButton(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if prominence == .primary {
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.glassProminent)
                .tint(tintColor(for: action) ?? KitchenTableTheme.action)
        } else if prominence == .supporting {
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .frame(minHeight: SpoonDockMetrics.minimumTargetSize)
                .background(.thinMaterial, in: Capsule())
                .background(KitchenTableTheme.paper.opacity(0.78), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(KitchenTableTheme.line.opacity(0.35), lineWidth: 1)
                }
        } else {
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .frame(width: SpoonDockMetrics.toolTargetSize, height: SpoonDockMetrics.toolTargetSize)
                .background(toolBackground(for: action), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(KitchenTableTheme.line.opacity(action.isEnabled ? 0.55 : 0.34), lineWidth: 1)
                }
        }
    }

    private func tintColor(for action: SpoonDockAction) -> Color? {
        action.role == .destructive ? KitchenTableTheme.tomato : nil
    }

    private func toolBackground(for action: SpoonDockAction) -> Color {
        action.isEnabled ? KitchenTableTheme.paper.opacity(0.92) : KitchenTableTheme.vellum.opacity(0.72)
    }

    @ViewBuilder
    private func dockTrigger(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if !action.isEnabled {
            dockLabel(action, prominence: prominence)
                .opacity(action.role == .status || action.role == .place ? 1 : 0.58)
                .accessibilityLabel(action.accessibilityLabel)
                .accessibilityHint(action.accessibilityHint ?? "")
        } else if let shareURL = action.shareURL {
            ShareLink(item: shareURL) {
                dockLabel(action, prominence: prominence)
            }
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityHint(action.accessibilityHint ?? "")
        } else {
            Button(action: action.action) {
                dockLabel(action, prominence: prominence)
            }
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityHint(action.accessibilityHint ?? "")
        }
    }

    @ViewBuilder
    private func dockLabel(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if prominence == .tool {
            Image(systemName: action.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(toolForeground(for: action))
                .frame(width: SpoonDockMetrics.toolGlyphFrame, height: SpoonDockMetrics.toolGlyphFrame)
        } else {
            HStack(spacing: prominence == .primary ? 7 : 6) {
                if prominence != .primary || action.role == .status {
                    Image(systemName: action.systemImage)
                        .font(.system(size: prominence == .primary ? 16 : 15, weight: .semibold))
                        .foregroundStyle(prominence == .supporting ? KitchenTableTheme.charcoal : KitchenTableTheme.paper)
                }

                VStack(alignment: prominence == .primary ? .center : .leading, spacing: 1) {
                    Text(action.title)
                        .font(prominence == .primary ? .headline.weight(.bold) : .caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(prominence == .supporting ? KitchenTableTheme.charcoal : KitchenTableTheme.paper)

                    if let subtitle = action.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(prominence == .supporting ? KitchenTableTheme.inkMuted : KitchenTableTheme.paper.opacity(0.72))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: SpoonDockMetrics.minimumTargetSize, alignment: prominence == .primary ? .center : .leading)
            .padding(.horizontal, prominence == .primary ? 8 : 0)
        }
    }

    private func toolForeground(for action: SpoonDockAction) -> Color {
        if action.role == .destructive {
            return KitchenTableTheme.tomato
        }
        return action.isEnabled ? KitchenTableTheme.charcoal : KitchenTableTheme.inkMuted
    }
}

private enum SpoonDockMetrics {
    static let maximumWidth: CGFloat = 326
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 7
    static let itemSpacing: CGFloat = 6
    static let toolSpacing: CGFloat = 5
    static let supportingWidth: CGFloat = 82
    static let primaryMinWidth: CGFloat = 118
    static let minimumTargetSize: CGFloat = 44
    static let toolTargetSize: CGFloat = 42
    static let toolGlyphFrame: CGFloat = 40
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
    static func cookMode(
        previous: @escaping () -> Void,
        markComplete: @escaping () -> Void,
        next: @escaping () -> Void,
        canGoBack: Bool,
        canAdvance: Bool,
        stepTitle: String
    ) -> Self {
        Self(
            routeIdentifier: "Cook mode",
            leftZone: .back(
                id: "cook.previous",
                title: "Previous",
                systemImage: "chevron.backward",
                isEnabled: canGoBack,
                action: previous
            ),
            centerZone: .primary(
                id: "cook.done",
                title: "Done",
                subtitle: stepTitle,
                systemImage: "checkmark.circle.fill",
                accessibilityLabel: "Mark the current step done",
                accessibilityHint: "Mark this step complete.",
                action: markComplete
            ),
            rightTools: [
                .tool(
                    id: "cook.next",
                    title: "Next",
                    systemImage: "chevron.forward",
                    isEnabled: canAdvance,
                    action: next
                )
            ]
        )
    }
}

private extension SpoonDockAction {
    static func place(id: String, title: String, systemImage: String) -> Self {
        Self(id: id, title: title, systemImage: systemImage, role: .place, isEnabled: false)
    }

    static func back(id: String, title: String, systemImage: String, isEnabled: Bool = true, action: @escaping () -> Void) -> Self {
        Self(id: id, title: title, systemImage: systemImage, role: .back, isEnabled: isEnabled, accessibilityHint: "Return to \(title).", action: action)
    }

    static func primary(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void = {}
    ) -> Self {
        Self(
            id: id,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            role: .primary,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            action: action
        )
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
