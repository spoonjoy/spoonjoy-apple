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
    @State private var aiConsentRequest: ThirdPartyAIConsentRequest?

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
        .thirdPartyAIConsent($aiConsentRequest)
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
            title: "Capture",
            subtitle: "Recipes sent by your Spoonjoy agent appear here for review. Shortcuts and Siri use the same local retry flow."
        )
    }

    /// The two ways a recipe reaches the queue, as plain rows under a hairline.
    private var entryPointLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(CaptureImportEntryPoint.allCases) { entryPoint in
                Rectangle().fill(KitchenTableTheme.hairline).frame(height: 1)
                CaptureImportEntryPointRow(entryPoint: entryPoint)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var agentImportStatus: some View {
        KitchenTableSection(title: "Import queue") {
            ImportStatusPanel(
                hasCurrentDraft: currentDraft != nil,
                hasPendingImport: hasPendingImport,
                hasProviderBlocker: hasProviderBlocker,
                isOffline: isOffline
            )
            // An empty queue offers one way to fill it.
            if currentDraft == nil, !hasPendingImport, !hasProviderBlocker, let shortcutsURL = Self.shortcutsURL {
                Link(destination: shortcutsURL) {
                    Label("Open Shortcuts", systemImage: "square.2.layers.3d")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
                .frame(maxWidth: 320, alignment: .leading)
                .accessibilityIdentifier("capture.empty.openShortcuts")
            }
        }
    }

    private static let shortcutsURL = URL(string: "shortcuts://")

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
                .foregroundStyle(KitchenTableTheme.ink2)
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
                    .foregroundStyle(KitchenTableTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if draft.importReadiness == .needsTextRecognition {
                Label("Needs text recognition", systemImage: "text.viewfinder")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
            if isOffline {
                Label("Saved locally", systemImage: "externaldrive.badge.checkmark")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
            if hasPendingImport {
                Label("Retry when online", systemImage: "arrow.clockwise")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
            HStack(alignment: .center, spacing: 10) {
                Button {
                    // Imports send the captured text to an AI service, so the person consents first.
                    aiConsentRequest = ThirdPartyAIConsentGate.request(.recipeImport) {
                        Task { await submit(draft) }
                    }
                } label: {
                    Label(actionInFlight ? "Submitting import" : submitButtonTitle, systemImage: "tray.and.arrow.up")
                }
                .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
                .disabled(!draft.canCreateServerRecipe || actionInFlight || hasPendingImport)
                Button {
                    Task { await discard(draft) }
                } label: {
                    Label("Delete capture", systemImage: "trash")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.tomato)
                        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(actionInFlight)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("capture.draft")
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
                Text(entryPoint.title)
                    .font(KitchenTableTheme.objectTitle)
                    .foregroundStyle(KitchenTableTheme.ink)
                Text(entryPoint.detail)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
    }
}

private struct ImportStatusPanel: View {
    let hasCurrentDraft: Bool
    let hasPendingImport: Bool
    let hasProviderBlocker: Bool
    let isOffline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(statusTitle, systemImage: statusSymbol)
                .font(KitchenTableTheme.indexTitle)
                .foregroundStyle(statusForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text(statusBody)
                .font(KitchenTableTheme.instructionBody)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, needsAttention ? 14 : 0)
        .overlay(alignment: .leading) {
            if needsAttention {
                Rectangle().fill(statusForeground).frame(width: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var needsAttention: Bool {
        hasProviderBlocker || hasPendingImport
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
        return KitchenTableTheme.ink
    }
}
