import PhotosUI
import SpoonjoyCore
import SwiftUI
import UniformTypeIdentifiers

private let supportedSpoonPhotoContentTypes = [
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp"
]

struct SpoonCookLogView: View {
    let viewModel: SpoonCookLogViewModel
    let showsHeader: Bool
    let terminalAccessibilityIdentifier: String
    let actionDidPlan: @MainActor (SpoonCookLogMutationPlan) async throws -> Void
    let draftDidChange: @MainActor (SpoonCookLogDraftState?) -> Void
    let conflictDidRequestReview: @MainActor (String) async throws -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var note: String
    @State private var nextTime: String
    @State private var useAsRecipeCover: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var stagedPhoto: SpoonCookLogPhotoAttachment?
    @State private var editingRow: SpoonCookLogRow?
    @State private var deletingRow: SpoonCookLogRow?
    @State private var actionStatusMessage: String?
    @State private var actionErrorMessage: String?
    @State private var actionInFlight = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    init(
        viewModel: SpoonCookLogViewModel,
        showsHeader: Bool = true,
        terminalAccessibilityIdentifier: String = "cook-log.terminal",
        draft: SpoonCookLogDraftState? = nil,
        actionDidPlan: @escaping @MainActor (SpoonCookLogMutationPlan) async throws -> Void,
        draftDidChange: @escaping @MainActor (SpoonCookLogDraftState?) -> Void = { _ in },
        conflictDidRequestReview: @escaping @MainActor (String) async throws -> Void = { _ in },
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.showsHeader = showsHeader
        self.terminalAccessibilityIdentifier = terminalAccessibilityIdentifier
        self.actionDidPlan = actionDidPlan
        self.draftDidChange = draftDidChange
        self.conflictDidRequestReview = conflictDidRequestReview
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _note = State(initialValue: draft?.note ?? "")
        _nextTime = State(initialValue: draft?.nextTime ?? "")
        _useAsRecipeCover = State(initialValue: draft?.useAsRecipeCover ?? false)
        _stagedPhoto = State(initialValue: draft?.stagedPhoto.map {
            SpoonCookLogPhotoAttachment(
                localStageID: $0.localStageID,
                fileName: $0.fileName,
                contentType: $0.contentType,
                data: $0.data,
                byteCount: $0.byteCount
            )
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }
            statusMessages
            createForm
            rows
        }
        .sheet(item: $editingRow) { editing in
            SpoonCookLogEditSheet(
                row: editing,
                note: editing.note ?? "",
                nextTime: editing.nextTime ?? "",
                isSaving: actionInFlight,
                save: { nextNote, nextNextTime in
                    run(.update(
                        spoonID: editing.id,
                        note: nextNote,
                        nextTime: nextNextTime,
                        cookedAt: editing.spoon.cookedAt,
                        photoURL: editing.photoURL?.absoluteString,
                        clientMutationID: clientMutationID(prefix: "spoon-update")
                    ), onSuccess: {
                        editingRow = nil
                    })
                },
                cancel: {
                    editingRow = nil
                }
            )
        }
        .task(id: viewModel.recipeID) {
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "cook-log",
                source: "SpoonCookLogView",
                runtimeContext: screenshotAccessibilityRuntimeContext
            )
        }
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Cooks")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Spacer()
            if let queuedWorkSummary = viewModel.queuedWorkSummary {
                Label(queuedWorkSummary, systemImage: "clock.arrow.circlepath")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }
        }
    }

    @ViewBuilder private var statusMessages: some View {
        if viewModel.offlineIndicator.display != .synced {
            OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
        }
        if let conflictBanner = viewModel.conflictBanner {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(conflictBanner.message, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
                Button(conflictBanner.actionTitle) {
                    runConflictAction(clientMutationID: conflictBanner.localClientMutationID)
                }
                .buttonStyle(.bordered)
                .disabled(actionInFlight)
            }
        }
        if let actionStatusMessage {
            Label(actionStatusMessage, systemImage: "checkmark.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
        }
        if let actionErrorMessage {
            Label(actionErrorMessage, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.tomato)
        }
    }

    private var createForm: some View {
        cookLogForm
    }

    private var cookLogForm: some View {
        let hasStagedPhoto = stagedPhoto != nil
        return VStack(alignment: .leading, spacing: 12) {
            TextField("What changed?", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .accessibilityIdentifier("cook-log.note")
            TextField("Next time", text: $nextTime, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .accessibilityIdentifier("cook-log.next-time")

            cookLogPhotoSlot
            cookLogActionBar

            if hasStagedPhoto {
                Toggle(isOn: $useAsRecipeCover) {
                    Label("Use photo as recipe cover", systemImage: "photo.on.rectangle")
                }
                .toggleStyle(.switch)
                .font(KitchenTableTheme.uiLabel)
                .disabled(actionInFlight)
            }
        }
        .onChange(of: note) { _, _ in
            persistDraft()
        }
        .onChange(of: nextTime) { _, _ in
            persistDraft()
        }
        .onChange(of: useAsRecipeCover) { _, _ in
            persistDraft()
        }
    }

    private var cookLogPhotoSlot: some View {
        let hasStagedPhoto = stagedPhoto != nil
        return PhotosPicker(selection: $selectedPhoto, matching: .images) {
            HStack(spacing: 12) {
                Image(systemName: hasStagedPhoto ? "photo.fill" : "photo.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasStagedPhoto ? "Photo ready" : "Add photo")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                        .lineLimit(1)
                    Text(hasStagedPhoto ? "Ready to attach to this cook." : "Optional cook photo.")
                        .font(.caption)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if hasStagedPhoto {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.herb)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(actionInFlight)
        .accessibilityIdentifier("cook-log.photo")
        .accessibilityLabel(hasStagedPhoto ? "Cook photo ready" : "Add cook photo")
        .onChange(of: selectedPhoto) { _, item in
            Task { @MainActor in
                await loadPhoto(item)
            }
        }
    }

    private var cookLogActionBar: some View {
        let hasStagedPhoto = stagedPhoto != nil
        return HStack(spacing: 10) {
            if hasStagedPhoto {
                clearPhotoButton
            }
            logCookButton
        }
    }

    private var clearPhotoButton: some View {
        Button {
            clearStagedPhoto()
        } label: {
            Label("Clear", systemImage: "xmark.circle")
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .font(KitchenTableTheme.uiLabel)
        .foregroundStyle(KitchenTableTheme.inkMuted)
        .disabled(actionInFlight)
        .accessibilityLabel("Clear cook photo")
    }

    private var logCookButton: some View {
        Button {
            run(.create(
                note: note,
                nextTime: nextTime,
                cookedAt: ISO8601DateFormatter().string(from: Date()),
                photo: stagedPhoto,
                photoURL: nil,
                useAsRecipeCover: stagedPhoto != nil && useAsRecipeCover,
                clientMutationID: clientMutationID(prefix: "spoon-create")
            ))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .accessibilityHidden(true)
                Text("Log cook")
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
        .disabled(actionInFlight)
        .accessibilityIdentifier("cook-log.submit")
        .accessibilityLabel("Log cook")
    }

    @ViewBuilder private var rows: some View {
        if let emptyState = viewModel.emptyState {
            Label(emptyState.title, systemImage: emptyState.systemImage)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint(emptyState.message)
                .accessibilityIdentifier(terminalAccessibilityIdentifier)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.rows) { row in
                    spoonRow(row)
                        .accessibilityIdentifier(
                            row.id == viewModel.rows.last?.id
                                ? terminalAccessibilityIdentifier
                                : "cook-log.row.\(row.id)"
                        )
                }
            }
        }
    }

    private func spoonRow(_ row: SpoonCookLogRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            spoonPhoto(for: row)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(row.chefLine, systemImage: "fork.knife")
                        .font(.headline)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                    Spacer()
                    Text(row.cookedAtLabel)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                }
                if let note = row.note {
                    Text(note)
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                }
                if let nextTime = row.nextTime {
                    Label(nextTime, systemImage: "arrow.clockwise")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.brass)
                }
                if row.canEdit || row.canDelete {
                    HStack {
                        if row.canEdit {
                            Button {
                                editingRow = row
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .buttonStyle(.bordered)
                            .disabled(actionInFlight)
                        }
                        if row.canDelete {
                            Button(role: .destructive) {
                                deletingRow = row
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .disabled(actionInFlight)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .confirmationDialog(
            "Delete cook log?",
            isPresented: Binding(
                get: { deletingRow?.id == row.id },
                set: { isPresented in
                    if !isPresented {
                        deletingRow = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Cook Log", role: .destructive) {
                run(.delete(spoonID: row.id, clientMutationID: clientMutationID(prefix: "spoon-delete")), onSuccess: {
                    deletingRow = nil
                })
            }
            Button("Cancel", role: .cancel) {
                deletingRow = nil
            }
        } message: {
            Text("This removes your cook note from this recipe.")
        }
    }

    @ViewBuilder private func spoonPhoto(for row: SpoonCookLogRow) -> some View {
        if let photoURL = row.photoURL {
            RecipeCoverImage(url: photoURL)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                    .fill(KitchenTableTheme.bone)
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(KitchenTableTheme.brass)
            }
            .frame(width: 76, height: 76)
        }
    }

    @MainActor private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }
        do {
            guard let (contentType, fileExtension) = item.supportedContentTypes.compactMap(Self.supportedPhotoContentType).first else {
                rejectSelectedPhoto("Unsupported photo format. Choose a JPEG, PNG, or WebP image.")
                return
            }
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                actionErrorMessage = "Photo could not be loaded."
                return
            }
            if case .rejected(let error) = viewModel.evaluateNewPhoto(byteCount: data.count, replacing: stagedPhoto) {
                rejectSelectedPhoto(Self.mediaRejectionMessage(error))
                return
            }
            stagedPhoto = SpoonCookLogPhotoAttachment(
                localStageID: "spoon-photo-\(UUID().uuidString)",
                fileName: "spoon.\(fileExtension)",
                contentType: contentType,
                data: data
            )
            actionErrorMessage = nil
            persistDraft()
        } catch {
            actionErrorMessage = "Photo could not be loaded."
        }
    }

    @MainActor private func rejectSelectedPhoto(_ message: String) {
        selectedPhoto = nil
        actionErrorMessage = message
    }

    @MainActor private func clearStagedPhoto() {
        selectedPhoto = nil
        stagedPhoto = nil
        useAsRecipeCover = false
        actionErrorMessage = nil
        persistDraft()
    }

    private static func supportedPhotoContentType(_ contentType: UTType) -> (String, String)? {
        guard let mimeType = contentType.preferredMIMEType?.lowercased(),
              let fileExtension = supportedSpoonPhotoContentTypes[mimeType] else {
            return nil
        }
        return (mimeType, fileExtension)
    }

    private static func mediaRejectionMessage(_ error: NativeMediaStagingError) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        switch error {
        case .individualFileTooLarge(let limitBytes):
            return "Photo is too large. Choose an image under \(formatter.string(fromByteCount: Int64(limitBytes)))."
        case .accountByteCapReached(let limitBytes, _):
            return "Offline photo storage is full. Sync or remove queued cook-log photos before adding more than \(formatter.string(fromByteCount: Int64(limitBytes)))."
        case .accountFileCapReached(let limitFiles, _):
            return "Offline photo storage is full. Sync or remove queued cook-log photos before adding more than \(limitFiles) files."
        case .generatedPreviewCapReached:
            return "Photo could not be staged offline."
        case .invalidPathComponent:
            return "Photo could not be staged offline."
        }
    }

    @MainActor private func persistDraft() {
        draftDidChange(SpoonCookLogDraftState(
            recipeID: viewModel.recipeID,
            note: note,
            nextTime: nextTime,
            stagedPhoto: stagedPhoto?.stagedMedia,
            useAsRecipeCover: useAsRecipeCover,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        ).persistable)
    }

    @MainActor private func run(_ action: SpoonCookLogAction, onSuccess: (@MainActor () -> Void)? = nil) {
        guard !actionInFlight else {
            return
        }
        let plan: SpoonCookLogMutationPlan
        do {
            plan = try viewModel.plan(action)
        } catch {
            actionErrorMessage = error.localizedDescription
            return
        }
        if let blockedReason = plan.blockedReason {
            actionErrorMessage = blockedReason
            return
        }

        actionInFlight = true
        Task { @MainActor in
            defer {
                actionInFlight = false
            }
            do {
                try await actionDidPlan(plan)
                actionStatusMessage = action.successMessage
                actionErrorMessage = nil
                onSuccess?()
                if case .create = action {
                    note = ""
                    nextTime = ""
                    selectedPhoto = nil
                    stagedPhoto = nil
                    useAsRecipeCover = false
                    draftDidChange(nil)
                }
            } catch {
                actionErrorMessage = "Cook log change could not be saved."
            }
        }
    }

    @MainActor private func runConflictAction(clientMutationID: String) {
        guard !actionInFlight else {
            return
        }
        actionInFlight = true
        Task { @MainActor in
            defer {
                actionInFlight = false
            }
            do {
                try await conflictDidRequestReview(clientMutationID)
                actionStatusMessage = "Cook-log conflict discarded."
                actionErrorMessage = nil
            } catch {
                actionErrorMessage = "Cook-log conflict could not be updated."
            }
        }
    }

    private func clientMutationID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }
}

private struct SpoonCookLogEditSheet: View {
    let row: SpoonCookLogRow
    @State private var note: String
    @State private var nextTime: String
    let isSaving: Bool
    let save: (String, String) -> Void
    let cancel: () -> Void

    init(row: SpoonCookLogRow, note: String, nextTime: String, isSaving: Bool, save: @escaping (String, String) -> Void, cancel: @escaping () -> Void) {
        self.row = row
        _note = State(initialValue: note)
        _nextTime = State(initialValue: nextTime)
        self.isSaving = isSaving
        self.save = save
        self.cancel = cancel
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("What changed?", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Next time", text: $nextTime, axis: .vertical)
                    .lineLimit(1...3)
            }
            .navigationTitle("Edit Cook Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(note, nextTime)
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}
