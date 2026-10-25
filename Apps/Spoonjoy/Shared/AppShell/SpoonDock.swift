import SpoonjoyCore
import SwiftUI

/// Cook mode's floating controls. Each control is its own piece of interactive Liquid Glass inside one
/// `GlassEffectContainer`, so when the set changes (step 1 has no Back) the glass merges and splits on
/// `KitchenSpring.glide`. Under Reduce Motion the control fades in and out instead.
struct SpoonDock: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    @ScaledMetric(relativeTo: .body) private var toolGlyphSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var primaryIconGlyphSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var labelGlyphSize: CGFloat = 15

    let context: SpoonDockContext

    var body: some View {
        GlassEffectContainer(spacing: SpoonDockMetrics.glassMergeSpacing) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityDock
                } else {
                    adaptiveDock
                }
            }
        }
        .padding(.horizontal, SpoonDockMetrics.horizontalPadding)
        .padding(.vertical, SpoonDockMetrics.verticalPadding)
        .frame(maxWidth: SpoonDockMetrics.maximumWidth)
        .animation(KitchenMotion.animation(.glide, reduceMotion: reduceMotion), value: showsLeftZone)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.accessibilityLabel)
    }

    /// A Back control that can't act is left out rather than shown dimmed, so the glass splits it off when it
    /// becomes useful.
    private var showsLeftZone: Bool {
        context.leftZone.role != .back || context.leftZone.isEnabled
    }

    private var adaptiveDock: some View {
        ViewThatFits(in: .horizontal) {
            cookModeIconHandrail
            horizontalDock
            compactDock
        }
    }

    @ViewBuilder
    private var leftZone: some View {
        if showsLeftZone {
            dockButton(context.leftZone, prominence: .tool)
                .frame(width: SpoonDockMetrics.toolTargetSize, height: SpoonDockMetrics.toolTargetSize)
                .kitchenTransition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    private var cookModeIconHandrail: some View {
        HStack(alignment: .center, spacing: SpoonDockMetrics.handrailSpacing) {
            leftZone

            dockButton(context.centerZone, prominence: .primaryIcon)
                .frame(width: SpoonDockMetrics.primaryIconWidth, height: SpoonDockMetrics.toolTargetSize)

            toolRail
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var horizontalDock: some View {
        HStack(alignment: .center, spacing: SpoonDockMetrics.itemSpacing) {
            if showsLeftZone {
                dockButton(context.leftZone, prominence: .supporting)
                    .frame(width: SpoonDockMetrics.supportingWidth, alignment: .leading)
                    .layoutPriority(1)
                    .kitchenTransition(.scale(scale: 0.6).combined(with: .opacity))
            }

            dockButton(context.centerZone, prominence: .primary)
                .frame(minWidth: SpoonDockMetrics.primaryMinWidth, maxWidth: .infinity)
                .layoutPriority(2)

            toolRail
                .layoutPriority(1)
        }
    }

    private var compactDock: some View {
        HStack(alignment: .center, spacing: SpoonDockMetrics.itemSpacing) {
            leftZone
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
                if showsLeftZone {
                    dockButton(context.leftZone, prominence: .supporting)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .kitchenTransition(.opacity)
                }

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
        switch prominence {
        case .primary:
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(primaryTint(for: action)).interactive(), in: Capsule())
                .dockGlassID(action.id, in: glassNamespace, morphs: !reduceMotion)
        case .primaryIcon:
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .frame(width: SpoonDockMetrics.primaryIconWidth, height: SpoonDockMetrics.toolTargetSize)
                .glassEffect(.regular.tint(primaryTint(for: action)).interactive(), in: Capsule())
                .dockGlassID(action.id, in: glassNamespace, morphs: !reduceMotion)
        case .supporting:
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .frame(minHeight: SpoonDockMetrics.minimumTargetSize)
                .glassEffect(.regular.interactive(), in: Capsule())
                .dockGlassID(action.id, in: glassNamespace, morphs: !reduceMotion)
        case .tool:
            dockTrigger(action, prominence: prominence)
                .buttonStyle(.plain)
                .frame(width: SpoonDockMetrics.toolTargetSize, height: SpoonDockMetrics.toolTargetSize)
                .glassEffect(action.isEnabled ? .regular.interactive() : .regular, in: Circle())
                .dockGlassID(action.id, in: glassNamespace, morphs: !reduceMotion)
        }
    }

    private func primaryTint(for action: SpoonDockAction) -> Color {
        action.role == .destructive ? KitchenTableTheme.tomato : KitchenTableTheme.ink
    }

    @ViewBuilder
    private func dockTrigger(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if !action.isEnabled {
            dockLabel(action, prominence: prominence)
                .opacity(action.role == .status || action.role == .place ? 1 : 0.58)
                .accessibilityLabel(action.accessibilityLabel)
                .accessibilityHint(action.accessibilityHint ?? "")
                .accessibilityIdentifier("spoonDock.\(action.id)")
        } else if let shareURL = action.shareURL {
            ShareLink(item: shareURL) {
                dockLabel(action, prominence: prominence)
            }
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityHint(action.accessibilityHint ?? "")
            .accessibilityIdentifier("spoonDock.\(action.id)")
        } else {
            Button(action: action.action) {
                dockLabel(action, prominence: prominence)
            }
            .accessibilityLabel(action.accessibilityLabel)
            .accessibilityHint(action.accessibilityHint ?? "")
            .accessibilityIdentifier("spoonDock.\(action.id)")
        }
    }

    @ViewBuilder
    private func dockLabel(_ action: SpoonDockAction, prominence: SpoonDockActionProminence) -> some View {
        if prominence == .tool || prominence == .primaryIcon {
            Image(systemName: action.systemImage)
                .font(.system(size: prominence == .primaryIcon ? primaryIconGlyphSize : toolGlyphSize, weight: .semibold))
                .foregroundStyle(prominence == .primaryIcon ? KitchenTableTheme.onInk : toolForeground(for: action))
                .frame(width: SpoonDockMetrics.toolGlyphFrame, height: SpoonDockMetrics.toolGlyphFrame)
                .contentShape(Rectangle())
        } else {
            HStack(spacing: prominence == .primary ? 7 : 6) {
                if prominence != .primary || action.role == .status {
                    Image(systemName: action.systemImage)
                        .font(.system(size: labelGlyphSize, weight: .semibold))
                        .foregroundStyle(prominence == .supporting ? KitchenTableTheme.ink : KitchenTableTheme.onInk)
                }

                VStack(alignment: prominence == .primary ? .center : .leading, spacing: 1) {
                    Text(action.title)
                        .font(prominence == .primary ? .headline.weight(.bold) : .caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(prominence == .supporting ? KitchenTableTheme.ink : KitchenTableTheme.onInk)

                    if let subtitle = action.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(prominence == .supporting ? KitchenTableTheme.ink2 : KitchenTableTheme.onInk.opacity(0.72))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: SpoonDockMetrics.minimumTargetSize, alignment: prominence == .primary ? .center : .leading)
            .padding(.horizontal, prominence == .primary ? 8 : 0)
            .contentShape(Rectangle())
        }
    }

    private func toolForeground(for action: SpoonDockAction) -> Color {
        if action.role == .destructive {
            return KitchenTableTheme.tomato
        }
        return action.isEnabled ? KitchenTableTheme.ink : KitchenTableTheme.ink2
    }
}

private extension View {
    /// Joins the dock's glass morph. Under Reduce Motion the control keeps its glass but leaves the morph, so it
    /// fades with its `kitchenTransition` instead of stretching out of its neighbour.
    @ViewBuilder
    func dockGlassID(_ id: String, in namespace: Namespace.ID, morphs: Bool) -> some View {
        if morphs {
            glassEffectID(id, in: namespace)
        } else {
            glassEffectTransition(.identity)
        }
    }
}

private enum SpoonDockMetrics {
    static let maximumWidth: CGFloat = 326
    /// Glass pieces closer than this blend while they merge or split.
    static let glassMergeSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 7
    static let itemSpacing: CGFloat = 6
    static let handrailSpacing: CGFloat = 14
    static let toolSpacing: CGFloat = 5
    static let supportingWidth: CGFloat = 82
    static let primaryMinWidth: CGFloat = 118
    static let primaryIconWidth: CGFloat = 68
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
    case primaryIcon
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
                title: "Back step",
                systemImage: "chevron.backward",
                isEnabled: canGoBack,
                accessibilityLabel: "Previous cooking step",
                accessibilityHint: "Moves to the previous cooking step.",
                action: previous
            ),
            centerZone: .primary(
                id: "cook.done",
                title: "Mark step",
                subtitle: nil,
                systemImage: "checkmark",
                accessibilityLabel: "Mark the current step done",
                accessibilityHint: "Mark this cooking step complete.",
                action: markComplete
            ),
            rightTools: [
                .tool(
                    id: "cook.next",
                    title: "Next step",
                    systemImage: "chevron.forward",
                    isEnabled: canAdvance,
                    accessibilityLabel: "Next cooking step",
                    accessibilityHint: "Moves to the next cooking step.",
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

    static func back(
        id: String,
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) -> Self {
        Self(
            id: id,
            title: title,
            systemImage: systemImage,
            role: .back,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint ?? "Return to \(title).",
            action: action
        )
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
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
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
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            action: action
        )
    }
}
