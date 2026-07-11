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
            agentImportStatus
            if let currentDraft {
                draftPreview(currentDraft)
            }
            entryPointLedger
            statusBanner
        }
        .onAppear {
            reconcile(with: inputDraft)
        }
        .onChange(of: inputDraft) { _, draft in
            reconcile(with: draft)
        }
        .task {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "capture",
                source: "CaptureDraftView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
    }

    private var header: some View {
        KitchenTableHeader(
            eyebrow: "Import queue",
            title: "Capture",
            subtitle: "Recipes sent by your Spoonjoy agent appear here for review. Shortcuts and Siri use the same local retry flow."
        )
    }

    private var entryPointLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(CaptureImportEntryPoint.allCases) { entryPoint in
                CaptureImportEntryPointRow(entryPoint: entryPoint)
                if entryPoint.id != CaptureImportEntryPoint.allCases.last?.id {
                    Divider()
                        .overlay(KitchenTableTheme.line.opacity(0.55))
                }
            }
        }
        .background(KitchenTableTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .stroke(KitchenTableTheme.line.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var agentImportStatus: some View {
        ImportStatusPanel(
            hasCurrentDraft: currentDraft != nil,
            hasPendingImport: hasPendingImport,
            hasProviderBlocker: hasProviderBlocker,
            isOffline: isOffline
        )
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
            Label("Import source", systemImage: iconName(for: draft))
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
            if isOffline {
                Label("Saved locally", systemImage: "externaldrive.badge.checkmark")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            if hasPendingImport {
                Label("Retry when online", systemImage: "arrow.clockwise")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            HStack(alignment: .center, spacing: 10) {
                Button {
                    Task { await submit(draft) }
                } label: {
                    Label(actionInFlight ? "Submitting import" : submitButtonTitle, systemImage: "tray.and.arrow.up")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
                .disabled(!draft.canCreateServerRecipe || actionInFlight || hasPendingImport)
                Button {
                    Task { await discard(draft) }
                } label: {
                    Label("Delete capture", systemImage: "trash")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .destructive))
                .disabled(actionInFlight)
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

    private var submitButtonTitle: String {
        hasPendingImport ? "Retry sync" : "Submit import"
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

private enum CaptureImportEntryPoint: String, CaseIterable, Identifiable {
    case agentMCP
    case appIntent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agentMCP:
            "Spoonjoy agent"
        case .appIntent:
            "Shortcuts & Siri"
        }
    }

    var detail: String {
        switch self {
        case .agentMCP:
            "Send an import-ready recipe capture from the Spoonjoy agent."
        case .appIntent:
            "Open, submit, and delete captures from Shortcuts and Siri."
        }
    }

    var status: String {
        switch self {
        case .agentMCP, .appIntent:
            "Ready"
        }
    }

    var symbolName: String {
        switch self {
        case .agentMCP:
            "wand.and.stars"
        case .appIntent:
            "sparkles"
        }
    }
}

private struct CaptureImportEntryPointRow: View {
    let entryPoint: CaptureImportEntryPoint

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: entryPoint.symbolName)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entryPoint.title)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                    Text(entryPoint.status)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                }
                Text(entryPoint.detail)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct ImportStatusPanel: View {
    let hasCurrentDraft: Bool
    let hasPendingImport: Bool
    let hasProviderBlocker: Bool
    let isOffline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(statusTitle, systemImage: statusSymbol)
                .font(KitchenTableTheme.sectionTitle)
                .foregroundStyle(statusForeground)
            Text(statusBody)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
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

    private var statusTitle: String {
        if hasProviderBlocker {
            return "Resolve import setup"
        }
        if hasPendingImport {
            return "Retry when online"
        }
        if hasCurrentDraft {
            return "Import ready"
        }
        if isOffline {
            return "Offline import queue"
        }
        return "Waiting for import"
    }

    private var statusBody: String {
        if hasProviderBlocker {
            return "Recipe import setup is required before Spoonjoy can finish this capture. Fix the provider setup, then retry the saved import."
        }
        if hasPendingImport {
            return "The import is saved locally. Spoonjoy will retry it when the account is back online."
        }
        if hasCurrentDraft {
            return "Review the captured source below. Submit import when it is ready."
        }
        if isOffline {
            return "New Spoonjoy agent or Shortcuts imports can be kept locally until Spoonjoy reconnects."
        }
        return "Use your Spoonjoy agent or Shortcuts to create a capture."
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
