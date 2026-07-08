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
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: 351)
        .background(KitchenTableTheme.bone, in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .background(KitchenTableTheme.photoCharcoal.opacity(0.92), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
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
        HStack(alignment: .center, spacing: 8) {
            dockButton(context.leftZone, prominence: .supporting)
                .frame(width: 92, alignment: .leading)
                .layoutPriority(1)

            dockButton(context.centerZone, prominence: .primary)
                .frame(minWidth: 126, maxWidth: .infinity)
                .layoutPriority(2)

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
                .tint(tintColor(for: action) ?? KitchenTableTheme.action)
        } else if prominence == .supporting {
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(.thinMaterial, in: Capsule())
                .background(KitchenTableTheme.paper.opacity(0.84), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(KitchenTableTheme.line.opacity(0.35), lineWidth: 1)
                }
        } else {
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .background(KitchenTableTheme.paper.opacity(0.10), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(KitchenTableTheme.paper.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private func tintColor(for action: SpoonDockAction) -> Color? {
        action.role == .destructive ? KitchenTableTheme.tomato : nil
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
                .foregroundStyle(action.role == .destructive ? KitchenTableTheme.tomato : KitchenTableTheme.paper)
                .frame(width: 42, height: 42)
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
            .frame(maxWidth: .infinity, minHeight: 44, alignment: prominence == .primary ? .center : .leading)
            .padding(.horizontal, prominence == .primary ? 8 : 0)
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
