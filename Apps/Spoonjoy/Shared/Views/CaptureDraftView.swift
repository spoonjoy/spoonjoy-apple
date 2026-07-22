import Foundation
import SpoonjoyCore
import SwiftUI

struct CaptureDraftView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var currentDraft: CaptureDraft?
    @State private var statusMessage: String?
    @State private var actionErrorMessage: String?
    @State private var actionInFlight = false

    private let inputDraft: CaptureDraft?
    private let importViewModel: CaptureImportViewModel?
    private let shellOfflineIndicatorState: OfflineIndicatorState?
    private let draftDidChange: @MainActor (CaptureDraft) -> Void
    private let draftDidDiscard: @MainActor (CaptureDraft) async throws -> Void
    private let importDidSubmit: @MainActor (CaptureDraft) async throws -> CaptureImportPlan
    private let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    private var hasPendingImport: Bool {
        importViewModel?.pendingRetryMutation != nil
    }

    private var hasProviderBlocker: Bool {
        if case .blocker(.providerSecret) = shellOfflineIndicatorState?.display {
            return true
        }
        return false
    }

    private var isOffline: Bool {
        importViewModel?.connectivity == .offline
    }

    init(
        viewModel: CaptureDraftViewModel?,
        importViewModel: CaptureImportViewModel?,
        shellOfflineIndicatorState: OfflineIndicatorState? = nil,
        draftDidChange: @escaping @MainActor (CaptureDraft) -> Void,
        draftDidDiscard: @escaping @MainActor (CaptureDraft) async throws -> Void,
        importDidSubmit: @escaping @MainActor (CaptureDraft) async throws -> CaptureImportPlan,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        let draft = viewModel?.draft
        _currentDraft = State(initialValue: draft)
        self.inputDraft = draft
        self.importViewModel = importViewModel
        self.shellOfflineIndicatorState = shellOfflineIndicatorState
        self.draftDidChange = draftDidChange
        self.draftDidDiscard = draftDidDiscard
        self.importDidSubmit = importDidSubmit
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
    }

    var body: some View {
        KitchenTablePage {
            header
            offlineStatus
            if shouldShowStatusPanel {
                agentImportStatus
            }
            if let currentDraft {
                draftPreview(currentDraft)
            }
            statusBanner
        }
        .onAppear {
            reconcile(with: inputDraft)
        }
        .onChange(of: inputDraft) { _, draft in
            reconcile(with: draft)
        }
        .task(id: screenshotSurfaceVariant) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "capture",
                source: "CaptureDraftView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                ),
                observedSurfaceVariant: screenshotSurfaceVariant
            )
        }
    }

    private var header: some View {
        KitchenTableHeader(
            eyebrow: "Kitchen",
            title: "Imports",
            subtitle: "Review recipes before they join your kitchen."
        )
    }

    private var shouldShowStatusPanel: Bool {
        currentDraft == nil || hasPendingImport || hasProviderBlocker || isOffline
    }

    private var agentImportStatus: some View {
        ImportStatusPanel(
            hasCurrentDraft: currentDraft != nil,
            hasPendingImport: hasPendingImport,
            hasProviderBlocker: hasProviderBlocker,
            isOffline: isOffline,
            terminalAccessibilityIdentifier: currentDraft == nil ? "capture.terminal" : nil
        )
    }

    private var screenshotSurfaceVariant: String {
        if hasProviderBlocker {
            return "provider-blocked"
        }
        if hasPendingImport {
            return "offline-retry"
        }
        if currentDraft != nil {
            return "draft"
        }
        return "empty"
    }

    @ViewBuilder private var offlineStatus: some View {
        if let display = shellOfflineIndicatorState?.display, display.isVisible {
            OfflineStatusView(display: display, onDismiss: onDismissOfflineIndicator)
        }
    }

    @ViewBuilder private var statusBanner: some View {
        if let actionErrorMessage {
            Label(actionErrorMessage, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.tomato)
        } else if let statusMessage {
            Label(statusMessage, systemImage: "info.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
        }
    }

    private func draftPreview(_ draft: CaptureDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Source", systemImage: iconName(for: draft))
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
            ForEach(draft.previewLines, id: \.self) { line in
                Text(line)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if draft.importReadiness == .needsTextRecognition {
                Label("Needs text recognition", systemImage: "text.viewfinder")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            HStack(alignment: .center, spacing: 10) {
                Button {
                    Task { await submit(draft) }
                } label: {
                    Label(actionInFlight ? "Importing" : "Import", systemImage: "tray.and.arrow.up")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
                .disabled(!draft.canCreateServerRecipe || actionInFlight || hasPendingImport || hasProviderBlocker)

                captureActionsMenu(draft)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.bone)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(KitchenTableTheme.brass.opacity(0.24))
                .frame(height: 1)
        }
    }

    private func captureActionsMenu(_ draft: CaptureDraft) -> some View {
        Menu {
            Button("Delete import", systemImage: "trash", role: .destructive) {
                Task { await discard(draft) }
            }
            .disabled(actionInFlight)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3.weight(.semibold))
                .frame(width: KitchenTableTheme.minimumTouchTarget, height: KitchenTableTheme.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("capture.terminal")
        .accessibilityLabel("Import actions")
        .help("Import actions")
    }

    private func reconcile(with draft: CaptureDraft?) {
        guard currentDraft != draft else {
            return
        }
        currentDraft = draft
        if draft == nil {
            statusMessage = nil
            actionErrorMessage = nil
        }
    }

    @MainActor private func discard(_ draft: CaptureDraft) async {
        guard !actionInFlight else { return }
        actionInFlight = true
        actionErrorMessage = nil
        defer { actionInFlight = false }

        do {
            try await draftDidDiscard(draft)
            currentDraft = nil
            statusMessage = nil
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = "Capture could not be deleted."
        }
    }

    @MainActor private func submit(_ draft: CaptureDraft) async {
        actionInFlight = true
        actionErrorMessage = nil
        defer { actionInFlight = false }

        do {
            let plan = try await importDidSubmit(draft)
            if plan.blocker != nil {
                statusMessage = nil
                actionErrorMessage = "Resolve import setup before retrying this capture."
            } else {
                statusMessage = plan.userFacingMessage
            }
            currentDraft = plan.captureDraftAfterCompletion
        } catch let error as CaptureDraftImportError where error == .needsTextRecognition {
            actionErrorMessage = "Shortcuts import needs text recognition before submission."
        } catch {
            actionErrorMessage = "Import could not be submitted."
        }
    }

    private func iconName(for draft: CaptureDraft) -> String {
        switch draft.source {
        case .text:
            "doc.text"
        case .url, .shareSheetURL:
            "link"
        case .image, .cameraImage:
            "camera"
        case .photoLibraryImage:
            "photo.on.rectangle"
        case .jsonLD:
            "curlybraces"
        case .videoURL:
            "play.rectangle"
        }
    }
}

private struct ImportStatusPanel: View {
    let hasCurrentDraft: Bool
    let hasPendingImport: Bool
    let hasProviderBlocker: Bool
    let isOffline: Bool
    let terminalAccessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(statusTitle, systemImage: statusSymbol)
                .font(KitchenTableTheme.sectionTitle)
                .foregroundStyle(statusForeground)
            statusBodyText
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusBackground)
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .stroke(statusStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    @ViewBuilder private var statusBodyText: some View {
        if let terminalAccessibilityIdentifier {
            Text(statusBody)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(terminalAccessibilityIdentifier)
        } else {
            Text(statusBody)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusTitle: String {
        if hasProviderBlocker {
            return "Import paused"
        }
        if hasPendingImport {
            return "Saved locally"
        }
        if hasCurrentDraft && isOffline {
            return "Saved locally"
        }
        if hasCurrentDraft {
            return "Ready to import"
        }
        if isOffline {
            return "Offline"
        }
        return "No imports waiting"
    }

    private var statusBody: String {
        if hasProviderBlocker {
            return "Import is unavailable right now. This recipe is still saved."
        }
        if hasPendingImport {
            return "Spoonjoy will retry this import when you're online."
        }
        if hasCurrentDraft && isOffline {
            return "Import when you're back online."
        }
        if hasCurrentDraft {
            return "Review the source below."
        }
        if isOffline {
            return "Nothing is waiting to import."
        }
        return "New recipes from your Spoonjoy agent will appear here."
    }

    private var statusSymbol: String {
        if hasProviderBlocker {
            return "lock.shield.fill"
        }
        if hasPendingImport {
            return "clock.arrow.circlepath"
        }
        if hasCurrentDraft {
            return "tray.and.arrow.up.fill"
        }
        return "tray.and.arrow.down"
    }

    private var statusForeground: Color {
        if hasProviderBlocker {
            return KitchenTableTheme.tomato
        }
        if hasPendingImport {
            return KitchenTableTheme.brass
        }
        return KitchenTableTheme.charcoal
    }

    private var statusBackground: Color {
        if hasProviderBlocker {
            return KitchenTableTheme.tomato.opacity(0.08)
        }
        if hasPendingImport {
            return KitchenTableTheme.brass.opacity(0.10)
        }
        return KitchenTableTheme.paper
    }

    private var statusStroke: Color {
        if hasProviderBlocker {
            return KitchenTableTheme.tomato.opacity(0.35)
        }
        if hasPendingImport {
            return KitchenTableTheme.brass.opacity(0.35)
        }
        return KitchenTableTheme.line.opacity(0.45)
    }
}
