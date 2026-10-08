import Foundation
import PhotosUI
import SpoonjoyCore
import SwiftUI
import UniformTypeIdentifiers

struct RecipeEditorView: View {
    let viewModel: RecipeEditorViewModel
    let mutationDidPlan: @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void
    let mutationsDidQueue: @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    let conflictDidDiscardLocalChange: @MainActor @Sendable (RecipeEditorConflict) async throws -> Void
    /// Creates the recipe and uploads the chosen photo as its cover; returns the route to open next.
    let createRecipeWithPhoto: @MainActor @Sendable (RecipeEditorMutationPlan, NativeStagedMediaUpload) async throws -> AppRoute
    let close: @MainActor @Sendable (AppRoute) -> Void
    let shellOfflineIndicatorState: OfflineIndicatorState?
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var draft: RecipeEditorDraft
    @State private var blockedMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false
    @State private var conflictOverride = false
    @State private var runtimeConflict: RecipeEditorConflict?
    @State private var offlineDisplayOverride: OfflineIndicatorDisplay?
    @State private var pasteStepID: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var stagedPhoto: NativeStagedMediaUpload?
    @State private var photoMessage: String?
    @State private var isShowingCamera = false
    @State private var pendingExit: AppRoute?
    @State private var invalidQuantityRows: Set<String> = []

    init(
        viewModel: RecipeEditorViewModel,
        mutationDidPlan: @escaping @MainActor @Sendable (RecipeEditorMutationPlan) async throws -> Void,
        mutationsDidQueue: @escaping @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        conflictDidDiscardLocalChange: @escaping @MainActor @Sendable (RecipeEditorConflict) async throws -> Void,
        createRecipeWithPhoto: @escaping @MainActor @Sendable (RecipeEditorMutationPlan, NativeStagedMediaUpload) async throws -> AppRoute,
        close: @escaping @MainActor @Sendable (AppRoute) -> Void,
        shellOfflineIndicatorState: OfflineIndicatorState? = nil,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.mutationDidPlan = mutationDidPlan
        self.mutationsDidQueue = mutationsDidQueue
        self.conflictDidDiscardLocalChange = conflictDidDiscardLocalChange
        self.createRecipeWithPhoto = createRecipeWithPhoto
        self.close = close
        self.shellOfflineIndicatorState = shellOfflineIndicatorState
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _draft = State(initialValue: viewModel.draft)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let blockedMessage {
                    Label(blockedMessage, systemImage: "exclamationmark.triangle")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.tomato)
                        .accessibilityIdentifier("editor.status")
                }

                if let conflictBanner = activeViewModel.conflictBanner {
                    conflictBand(conflictBanner)
                }

                recipeCardSection
                Divider().overlay(KitchenTableTheme.line)
                methodSection
                Divider().overlay(KitchenTableTheme.line)
                footerSection
            }
            .padding(.horizontal, KitchenTableTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, KitchenTableTheme.pageSpacing)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(KitchenTableTheme.bone.ignoresSafeArea())
        .navigationTitle(draft.recipeID == nil ? "New Recipe" : "Edit Recipe")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
#endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    leave(to: exitRoute)
                }
                .disabled(isSubmitting)
                .accessibilityIdentifier("editor.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!canSave || isSubmitting)
                .accessibilityIdentifier("editor.save")
            }
        }
#if os(iOS)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCapture { data in
                isShowingCamera = false
                if let data {
                    Task { @MainActor in
                        await stageCameraImage(data)
                    }
                }
            }
            .ignoresSafeArea()
        }
#endif
        .sheet(isPresented: Binding(get: { pasteStepID != nil }, set: { if !$0 { pasteStepID = nil } })) {
            if let stepID = pasteStepID, let step = draft.steps.first(where: { $0.id == stepID }) {
                IngredientPasteSheet(
                    stepNumber: step.stepNum,
                    makeLocalID: { localID("local_ingredient") },
                    onAdd: { addIngredients($0, to: stepID) },
                    onCancel: { pasteStepID = nil }
                )
            }
        }
        .confirmationDialog(activeViewModel.deleteConfirmationTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Recipe", role: .destructive) {
                Task {
                    await deleteRecipe()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Discard your changes?",
            isPresented: Binding(get: { pendingExit != nil }, set: { if !$0 { pendingExit = nil } }),
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                if let route = pendingExit {
                    pendingExit = nil
                    close(route)
                }
            }
            Button("Keep Editing", role: .cancel) {
                pendingExit = nil
            }
        }
        .safeAreaInset(edge: .bottom) {
            OfflineStatusView(display: offlineDisplayOverride ?? effectiveOfflineIndicator(activeViewModel.offlineIndicator.display), onDismiss: onDismissOfflineIndicator)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .background(KitchenTableTheme.bone.opacity(0.94))
        }
    }

    // MARK: - Recipe card

    private var recipeCardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("RECIPE CARD")
                    .font(KitchenTableTheme.runningHead)
                    .tracking(1.2)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                Text("Give the dish a home.")
                    .font(Font.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .accessibilityAddTraits(.isHeader)
                Text("Capture the name, story, serving cue, and photo someone will need when they cook this later.")
                    .font(KitchenTableTheme.instructionBody)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }

            coverControl

            EditorField("Title") {
                TextField("e.g., Chocolate Chip Cookies", text: $draft.title, axis: .vertical)
                    .lineLimit(1...3)
                    .accessibilityIdentifier("editor.title")
            }

            EditorField("Description") {
                TextField("Recipe description", text: descriptionText, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("editor.description")
            }

            EditorField("Servings") {
                TextField("e.g., 4 servings", text: servingsText)
                    .accessibilityIdentifier("editor.servings")
            }
        }
    }

    private func conflictBand(_ conflictBanner: RecipeEditorConflictBanner) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(conflictBanner.title)
                .font(.headline)
                .foregroundStyle(KitchenTableTheme.tomato)
            Text(conflictBanner.message)
                .font(KitchenTableTheme.bodyNote)
            HStack(spacing: 16) {
                Button("Review") {
                    reviewConflict()
                }
                Button(conflictBanner.discardActionTitle) {
                    Task {
                        await discardLocalChange()
                    }
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(KitchenTableTheme.tomato).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(KitchenTableTheme.tomato).frame(height: 1) }
    }

    // MARK: - Method

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("METHOD")
                    .font(KitchenTableTheme.runningHead)
                    .tracking(1.2)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                Text("Build the cooking path.")
                    .font(Font.system(.title, design: .serif).weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .accessibilityAddTraits(.isHeader)
            }

            ForEach($draft.steps) { $step in
                stepEditor($step)
                Divider().overlay(KitchenTableTheme.line)
            }

            Button {
                addStep()
            } label: {
                Label("Add Step", systemImage: "plus.circle")
                    .frame(minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .disabled(isSubmitting)
            .accessibilityIdentifier("editor.addStep")
        }
    }

    private func stepEditor(_ stepBinding: Binding<RecipeEditorStepDraft>) -> some View {
        let step = stepBinding.wrappedValue
        let number = step.stepNum
        let priorSteps = priorSteps(for: step)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Text("Step \(number)")
                    .font(KitchenTableTheme.stepNumeral)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                stepIconButton("Move Step Up", systemImage: "chevron.up", disabled: isSubmitting || number == 1) {
                    moveStep(id: step.id, by: -1)
                }
                .accessibilityIdentifier("editor.step.\(number).moveUp")
                stepIconButton("Move Step Down", systemImage: "chevron.down", disabled: isSubmitting || number == draft.steps.count) {
                    moveStep(id: step.id, by: 1)
                }
                .accessibilityIdentifier("editor.step.\(number).moveDown")
                stepIconButton("Delete Step", systemImage: "trash", disabled: isSubmitting, tint: KitchenTableTheme.tomato) {
                    removeStep(id: step.id)
                }
                .accessibilityIdentifier("editor.step.\(number).delete")
            }

            EditorField("Step title") {
                TextField("Optional, like Cook the rice", text: optionalText(stepBinding.title))
                    .accessibilityIdentifier("editor.step.\(number).title")
            }

            EditorField("Instructions") {
                TextField("Describe what to do in this step...", text: stepBinding.description, axis: .vertical)
                    .lineLimit(3...12)
                    .font(KitchenTableTheme.instructionBody)
                    .accessibilityIdentifier("editor.step.\(number).description")
            }

            Stepper(value: durationBinding(stepBinding.duration), in: 0...720, step: 1) {
                Text("Duration \(step.duration ?? 0) minutes")
                    .font(KitchenTableTheme.uiLabel)
            }
            .accessibilityIdentifier("editor.step.\(number).duration")

            // Creating a recipe cannot store which steps use another step's output (the web API
            // rejects that field on create), so output uses are offered once the recipe exists.
            if draft.recipeID != nil, !priorSteps.isEmpty {
                DisclosureGroup("Uses Output From") {
                    ForEach(priorSteps) { priorStep in
                        Toggle(
                            "Step \(priorStep.stepNum)",
                            isOn: outputUseBinding(stepBinding.outputStepNums, outputStepNum: priorStep.stepNum)
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Ingredients")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                ForEach(stepBinding.ingredients) { ingredient in
                    ingredientRow(ingredient, stepNumber: number, stepID: step.id, position: ingredientNumber(ingredient.wrappedValue.id, in: step))
                }

                // Borderless buttons each handle only their own taps, so a tap near one never runs another.
                HStack(spacing: 20) {
                    Button {
                        addIngredient(to: step.id)
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle")
                            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("editor.step.\(number).addIngredient")

                    Button {
                        pasteStepID = step.id
                    } label: {
                        Label("Paste Ingredients", systemImage: "doc.on.clipboard")
                            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("editor.step.\(number).pasteIngredients")
                }
            }
        }
    }

    private func stepIconButton(
        _ title: String,
        systemImage: String,
        disabled: Bool,
        tint: Color = KitchenTableTheme.charcoal,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: KitchenTableTheme.minimumTouchTarget, height: KitchenTableTheme.minimumTouchTarget)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(disabled ? KitchenTableTheme.inkMuted.opacity(0.5) : tint)
        .disabled(disabled)
    }

    private func ingredientRow(_ ingredient: Binding<RecipeEditorIngredientDraft>, stepNumber: Int, stepID: String, position: Int) -> some View {
        let ingredientID = "editor.step.\(stepNumber).ingredient.\(position)"
        let rowID = ingredient.wrappedValue.id
        return VStack(alignment: .leading, spacing: 8) {
            // The name wraps over as many lines as it needs, so a long ingredient is never cut off.
            TextField("Ingredient, like chicken stock", text: ingredient.name, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.done)
                .editorInputStyle()
                .accessibilityLabel("Ingredient name")
                .accessibilityIdentifier("\(ingredientID).name")
                // Typing a whole line such as "2 cups rice" and pressing return fills the quantity and unit.
                .onChange(of: ingredient.wrappedValue.name) { _, newValue in
                    guard newValue.contains("\n") else {
                        return
                    }
                    ingredient.wrappedValue.name = newValue.replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                    ingredient.wrappedValue.applyTypedLine()
                }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity")
                        .font(KitchenTableTheme.runningHead)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                    QuantityField(
                        quantity: ingredient.quantity,
                        rowID: rowID,
                        invalidRows: $invalidQuantityRows
                    )
                    .accessibilityIdentifier("\(ingredientID).quantity")
                }
                .frame(width: 104)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(KitchenTableTheme.runningHead)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                    TextField("cup", text: optionalText(ingredient.unit))
                        .textInputAutocapitalization(.never)
                        .editorInputStyle()
                        .accessibilityLabel("Unit")
                        .accessibilityIdentifier("\(ingredientID).unit")
                }
                Button(role: .destructive) {
                    removeIngredient(id: rowID, from: stepID)
                } label: {
                    Label("Delete Ingredient", systemImage: "minus.circle")
                        .labelStyle(.iconOnly)
                        .frame(width: KitchenTableTheme.minimumTouchTarget, height: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(KitchenTableTheme.tomato)
                .disabled(isSubmitting)
            }
            if invalidQuantityRows.contains(rowID) {
                Text("Use a number like 2, 1 1/2, ¾ or 0.25.")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let hint = saveHint {
                Text(hint)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .accessibilityIdentifier("editor.hint")
            }
            if draft.recipeID != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Recipe", systemImage: "trash")
                        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(KitchenTableTheme.tomato)
                .disabled(isSubmitting)
                .accessibilityIdentifier("editor.delete")
            }
        }
    }

    /// The first thing keeping Save off, so a dimmed Save always has a reason on screen.
    private var saveHint: String? {
        if !invalidQuantityRows.isEmpty {
            return "Fix the highlighted quantity to save."
        }
        return RecipeEditorValidator.validate(draft).first?.message
    }

    private var canSave: Bool {
        activeViewModel.updatingDraft(draft).canSubmit && invalidQuantityRows.isEmpty
    }

    private var hasUnsavedChanges: Bool {
        draft != viewModel.draft || stagedPhoto != nil
    }

    private var exitRoute: AppRoute {
        draft.recipeID.map { .recipeDetail(id: $0, presentation: .detail) } ?? .recipes
    }

    /// Leaves the editor, asking first when there is work that would be lost.
    private func leave(to route: AppRoute) {
        if hasUnsavedChanges {
            pendingExit = route
        } else {
            close(route)
        }
    }

    // MARK: - Cover image

    @ViewBuilder private var coverControl: some View {
        EditorField("Recipe Image", boxed: false) {
            if draft.recipeID == nil {
                photoControl
            } else if let recipeID = draft.recipeID {
                existingCoverControl(recipeID: recipeID)
            }
        }
    }

    private func existingCoverControl(recipeID: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose, take or generate a cover from the recipe's cover controls. Your edits here stay put until you save.")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
            Button {
                leave(to: .recipeCoverControls(id: recipeID))
            } label: {
                Label("Change Cover", systemImage: "photo")
                    .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            }
            .buttonStyle(.bordered)
            .disabled(isSubmitting)
            .accessibilityIdentifier("editor.cover.manage")
        }
    }

    @ViewBuilder private var photoControl: some View {
        let hasPhoto = stagedPhoto != nil
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let stagedPhoto, let thumbnail = Self.thumbnail(for: stagedPhoto.data) {
                    thumbnail
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .accessibilityLabel("Selected photo")
                        .accessibilityIdentifier("editor.photo.thumbnail")
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title)
                        Text("Add a cover photo")
                            .font(KitchenTableTheme.uiLabel)
                    }
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(KitchenTableTheme.paper)
                    .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                    .strokeBorder(KitchenTableTheme.lineStrong, style: StrokeStyle(lineWidth: 1, dash: hasPhoto ? [] : [5, 4]))
            )

            HStack(spacing: 12) {
                if journeyPhotoFixtureEnabled {
                    // Journeys cannot drive the system picker, so a journey build stages a generated picture instead.
                    Button {
                        Task { @MainActor in
                            await stageCandidate(NativeJourneyPhotoFixture.stagedUpload())
                        }
                    } label: {
                        photoPickLabel(hasPhoto: hasPhoto)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editor.photo.pick")
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(hasPhoto ? "Replace Photo" : "Choose Photo", systemImage: hasPhoto ? "photo.fill" : "photo")
                            .frame(minHeight: KitchenTableTheme.minimumTouchTarget - 12)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editor.photo.pick")
                    .onChange(of: selectedPhotoItem) { _, item in
                        Task { @MainActor in
                            await stagePhoto(item)
                        }
                    }
                }

                if !journeyPhotoFixtureEnabled,
                   RecipePhotoSource.available(cameraAvailable: Self.cameraAvailable).contains(.camera) {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .frame(minHeight: KitchenTableTheme.minimumTouchTarget - 12)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editor.photo.camera")
                }

                if hasPhoto {
                    Button {
                        selectedPhotoItem = nil
                        stagedPhoto = nil
                        photoMessage = nil
                    } label: {
                        Label("Remove Photo", systemImage: "xmark.circle")
                            .labelStyle(.iconOnly)
                            .frame(width: KitchenTableTheme.minimumTouchTarget, height: KitchenTableTheme.minimumTouchTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("editor.photo.remove")
                }
            }
            .font(KitchenTableTheme.uiLabel)
            .controlSize(.regular)

            if hasPhoto {
                Label("Photo ready", systemImage: "checkmark.circle.fill")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
                    .accessibilityIdentifier("editor.photo.ready")
            }
            Text(activeViewModel.connectivity == .offline
                ? (hasPhoto
                    ? "You're offline. The photo is kept on this device and uploads as the cover once the recipe syncs."
                    : "Optional. You're offline; a photo you add uploads once the recipe syncs.")
                : (hasPhoto
                    ? "Uploads as the cover when you save."
                    : "Optional. Without a photo, Spoonjoy makes a placeholder cover."))
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)
            if let photoMessage {
                Label(photoMessage, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.tomato)
                    .accessibilityIdentifier("editor.photo.status")
            }
        }
    }

    private func photoPickLabel(hasPhoto: Bool) -> some View {
        Label(hasPhoto ? "Replace Photo" : "Choose Photo", systemImage: hasPhoto ? "photo.fill" : "photo")
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget - 12)
    }

    private var journeyPhotoFixtureEnabled: Bool {
#if DEBUG
        NativeJourneyPhotoFixture.isRequested(environment: ProcessInfo.processInfo.environment)
#else
        false
#endif
    }

    private static func thumbnail(for data: Data) -> Image? {
#if canImport(UIKit)
        UIImage(data: data).map { Image(uiImage: $0) }
#elseif canImport(AppKit)
        NSImage(data: data).map { Image(nsImage: $0) }
#else
        nil
#endif
    }

    @MainActor private func stagePhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        guard let contentType = item.supportedContentTypes.compactMap({ $0.preferredMIMEType?.lowercased() }).first(where: { policy.fileExtension(for: $0) != nil }),
              let fileExtension = policy.fileExtension(for: contentType) else {
            selectedPhotoItem = nil
            photoMessage = "Unsupported photo format. Choose a JPEG, PNG, WebP, or HEIC image."
            return
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                selectedPhotoItem = nil
                photoMessage = "Photo could not be loaded."
                return
            }
            await stageCandidate(NativeStagedMediaUpload(
                localStageID: "recipe-create-photo-\(UUID().uuidString)",
                fileName: "cover.\(fileExtension)",
                contentType: contentType,
                data: data
            ))
        } catch {
            selectedPhotoItem = nil
            photoMessage = "Photo could not be loaded."
        }
    }

    private static var cameraAvailable: Bool {
#if os(iOS)
        UIImagePickerController.isSourceTypeAvailable(.camera)
#else
        false
#endif
    }

    @MainActor private func stageCameraImage(_ data: Data?) async {
        guard let data else {
            photoMessage = "Photo could not be loaded."
            return
        }
        await stageCandidate(RecipePhotoSource.cameraUpload(
            jpegData: data,
            stageID: "recipe-create-photo-\(UUID().uuidString)"
        ))
    }

    @MainActor private func stageCandidate(_ candidate: NativeStagedMediaUpload) async {
        let result = await RecipeCoverPhotoStagingWorker().stageSelection(
            existing: stagedPhoto,
            candidate: candidate,
            existingUsage: RecipeCoverPhotoStagedMediaUsage(byteCount: 0, fileCount: 0)
        )
        if result.rejection != nil {
            selectedPhotoItem = nil
            photoMessage = "Photo is too large or could not be read. Choose another image."
            return
        }
        stagedPhoto = result.stagedPhoto
        photoMessage = nil
    }

    private func effectiveOfflineIndicator(_ localDisplay: OfflineIndicatorDisplay) -> OfflineIndicatorDisplay {
        guard let shellOfflineIndicatorState,
              localDisplay.informationalOnly,
              !shellOfflineIndicatorState.display.informationalOnly
        else {
            return localDisplay
        }
        return shellOfflineIndicatorState.display
    }

    private var activeViewModel: RecipeEditorViewModel {
        if let runtimeConflict {
            return viewModel.replacingConflict(runtimeConflict)
        }
        if conflictOverride {
            return viewModel.replacingConflict(nil)
        }
        return viewModel
    }

    private var descriptionText: Binding<String> {
        optionalText($draft.description)
    }

    private var servingsText: Binding<String> {
        optionalText($draft.servings)
    }

    private func optionalText(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { nextValue in
                value.wrappedValue = optionalString(nextValue)
            }
        )
    }

    private func durationBinding(_ value: Binding<Int?>) -> Binding<Int> {
        Binding(
            get: { value.wrappedValue ?? 0 },
            set: { nextValue in
                value.wrappedValue = nextValue == 0 ? nil : nextValue
            }
        )
    }

    @MainActor private func save() async {
        let actions = RecipeEditorDraftChangePlanner.actions(
            original: viewModel.draft,
            draft: draft,
            clientMutationID: clientMutationID
        )
        await plan(actions)
    }

    @MainActor private func deleteRecipe() async {
        await plan([.deleteRecipe(clientMutationID: clientMutationID("recipe-delete"), confirmation: .confirmed)])
    }

    @MainActor private func plan(_ actions: [RecipeEditorAction]) async {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        defer {
            isSubmitting = false
        }

        do {
            let editor = activeViewModel.updatingDraft(draft)
            var plannedActions: [(action: RecipeEditorAction, plan: RecipeEditorMutationPlan)] = []

            for action in actions {
                let plan = try editor.plan(action)
                if let blockedReason = plan.blockedReason {
                    blockedMessage = blockedReason
                    return
                }
                plannedActions.append((action, plan))
            }

            if plannedActions.count > 1 {
                let mutations = try plannedActions.map { plannedAction in
                    guard let mutation = plannedAction.plan.queuedMutation ?? plannedAction.plan.offlineFallbackMutation else {
                        throw RecipeEditorPlanningError.missingQueuedMutation
                    }
                    return mutation
                }
                let batchResult = try await mutationsDidQueue(mutations, editor.connectivity == .online)
                if editor.connectivity == .online,
                   submittedBatchNeedsAttention(batchResult, mutations: mutations) {
                    return
                }
            } else if let plannedAction = plannedActions.first,
                      let stagedPhoto,
                      draft.recipeID == nil,
                      plannedAction.plan.remoteRequestBuilder != nil || plannedAction.plan.queuedMutation?.queueableKind == .recipeCreate {
                do {
                    let route = try await createRecipeWithPhoto(plannedAction.plan, stagedPhoto)
                    blockedMessage = nil
                    offlineDisplayOverride = nil
                    close(route)
                    return
                } catch {
                    throw RecipeEditorActionExecutionError(action: plannedAction.action, underlyingError: error)
                }
            } else if let plannedAction = plannedActions.first {
                do {
                    try await mutationDidPlan(plannedAction.plan)
                } catch {
                    throw RecipeEditorActionExecutionError(action: plannedAction.action, underlyingError: error)
                }
            }

            blockedMessage = nil
            offlineDisplayOverride = nil
            let successRoute = plannedActions.compactMap(\.plan.successRoute).last
            if let successRoute {
                close(successRoute)
            }
        } catch let error as RecipeEditorActionExecutionError {
            blockedMessage = message(for: error.underlyingError, action: error.action)
        } catch {
            blockedMessage = message(for: error, action: nil)
        }
    }

    private func moveStep(id: String, by offset: Int) {
        showMoveOutcome(draft.moveStep(id: id, by: offset))
    }

    private func showMoveOutcome(_ outcome: RecipeEditorMoveOutcome) {
        if case .blocked(let message) = outcome {
            blockedMessage = message
        } else {
            blockedMessage = nil
        }
    }

    private func addStep() {
        draft.steps.append(RecipeEditorStepDraft(
            id: localID("local_step"),
            stepNum: draft.steps.count + 1,
            title: nil,
            description: "",
            duration: nil,
            ingredients: [],
            outputStepNums: []
        ))
        renumberSteps()
    }

    private func removeStep(id: String) {
        draft.steps.removeAll { $0.id == id }
        renumberSteps()
    }

    private func priorSteps(for step: RecipeEditorStepDraft) -> [RecipeEditorStepDraft] {
        draft.steps
            .filter { $0.stepNum < step.stepNum }
            .sorted { $0.stepNum < $1.stepNum }
    }

    private func outputUseBinding(_ outputStepNums: Binding<[Int]>, outputStepNum: Int) -> Binding<Bool> {
        Binding(
            get: {
                outputStepNums.wrappedValue.contains(outputStepNum)
            },
            set: { isOn in
                var values = outputStepNums.wrappedValue.filter { $0 != outputStepNum }
                if isOn {
                    values.append(outputStepNum)
                }
                outputStepNums.wrappedValue = values.sorted()
            }
        )
    }

    private func submittedBatchNeedsAttention(
        _ result: NativeQueuedMutationBatchResult,
        mutations: [NativeQueuedMutation]
    ) -> Bool {
        if let conflict = result.submittedConflicts.first {
            let mutation = mutations.first { $0.clientMutationID == conflict.clientMutationID }
            let resourceID = mutation?.recipeID ?? draft.recipeID ?? conflict.clientMutationID
            runtimeConflict = RecipeEditorConflict(
                resourceID: resourceID,
                serverRevision: conflict.serverRevision,
                localClientMutationID: conflict.clientMutationID,
                message: conflict.message
            )
            offlineDisplayOverride = .conflict(recordID: resourceID, mutationID: conflict.clientMutationID)
            blockedMessage = conflict.message
            return true
        }

        guard !result.drainedClientMutationIDs.isEmpty,
              !result.remainingSubmittedClientMutationIDs.isEmpty else {
            return false
        }

        let remainingCount = result.remainingSubmittedClientMutationIDs.count
        blockedMessage = remainingCount == 1
            ? "One recipe edit is still queued. Review the offline status before leaving the editor."
            : "\(remainingCount) recipe edits are still queued. Review the offline status before leaving the editor."
        offlineDisplayOverride = .queuedWork(
            count: remainingCount,
            oldestClientMutationID: result.remainingSubmittedClientMutationIDs.first
        )
        return true
    }

    private func addIngredients(_ ingredients: [RecipeEditorIngredientDraft], to stepID: String) {
        pasteStepID = nil
        guard let stepIndex = draft.steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        draft.steps[stepIndex].ingredients.append(contentsOf: ingredients)
    }

    private func addIngredient(to stepID: String) {
        guard let stepIndex = draft.steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        draft.steps[stepIndex].ingredients.append(RecipeEditorIngredientDraft(
            id: localID("local_ingredient"),
            name: "",
            quantity: 1,
            unit: nil
        ))
    }

    /// The ingredient's 1-based position in its step, for accessibility identifiers.
    private func ingredientNumber(_ ingredientID: String, in step: RecipeEditorStepDraft) -> Int {
        (step.ingredients.firstIndex { $0.id == ingredientID } ?? step.ingredients.count) + 1
    }

    private func removeIngredient(id: String, from stepID: String) {
        guard let stepIndex = draft.steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        draft.steps[stepIndex].ingredients.removeAll { $0.id == id }
    }

    private func renumberSteps() {
        draft.renumberStepsPreservingOutputIdentities()
    }

    @MainActor private func reviewConflict() {
        guard let conflict = activeViewModel.conflict else {
            return
        }
        close(routeAfterConflictExit(conflict))
    }

    @MainActor private func discardLocalChange() async {
        guard let conflict = activeViewModel.conflict else {
            return
        }

        do {
            try await conflictDidDiscardLocalChange(conflict)
            conflictOverride = true
            runtimeConflict = nil
            blockedMessage = nil
            offlineDisplayOverride = nil
            close(routeAfterConflictExit(conflict))
        } catch {
            blockedMessage = message(for: error, action: nil)
            offlineDisplayOverride = .syncFailure(errorID: "recipe-editor-conflict", retryAfter: nil)
        }
    }

    private func routeAfterConflictExit(_ conflict: RecipeEditorConflict) -> AppRoute {
        let resourceID = conflict.resourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resourceID.isEmpty else {
            return .recipes
        }
        return .recipeDetail(id: resourceID, presentation: .detail)
    }

    private func clientMutationID(_ prefix: String) -> String {
        "\(prefix)-\(Date().timeIntervalSince1970.formatted(.number.precision(.fractionLength(0))))"
    }

    private func localID(_ prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString.lowercased())"
    }

    private func message(for error: Error, action: RecipeEditorAction?) -> String {
        if let transportError = error as? APITransportError {
            if transportError.statusCode == 409 {
                let mutationID = action?.clientMutationID ?? transportError.apiError?.requestID ?? "online-editor-conflict"
                runtimeConflict = RecipeEditorConflict(
                    resourceID: draft.recipeID ?? "",
                    serverRevision: conflictRevision(from: transportError),
                    localClientMutationID: mutationID,
                    message: transportError.apiError?.message ?? "This recipe changed elsewhere."
                )
                offlineDisplayOverride = .conflict(recordID: draft.recipeID ?? mutationID, mutationID: mutationID)
            } else if transportError.isOffline {
                offlineDisplayOverride = .offline
            } else {
                offlineDisplayOverride = .syncFailure(errorID: "recipe-editor", retryAfter: nil)
            }
            return transportError.apiError?.message ?? "Recipe editor action could not be saved."
        }

        offlineDisplayOverride = .syncFailure(errorID: "recipe-editor", retryAfter: nil)
        return "Recipe editor action could not be prepared."
    }

    private func conflictRevision(from error: APITransportError) -> NativeServerRevision? {
        if let etag = stringDetail("etag", in: error) ?? stringDetail("serverRevision", in: error) {
            return .etag(etag)
        }
        if let updatedAt = stringDetail("updatedAt", in: error) ?? stringDetail("serverUpdatedAt", in: error) {
            return .updatedAt(updatedAt)
        }
        return nil
    }

    private func stringDetail(_ key: String, in error: APITransportError) -> String? {
        guard case .string(let value)? = error.apiError?.details[key],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private func optionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}


private struct RecipeEditorActionExecutionError: Error {
    let action: RecipeEditorAction
    let underlyingError: Error
}

/// A labelled field: the label sits above the input, as on the web editor, never as a placeholder alone.
private struct EditorField<Content: View>: View {
    let label: String
    let boxed: Bool
    let content: Content

    /// `boxed: false` is for a control that draws its own surface, such as the cover photo.
    init(_ label: String, boxed: Bool = true, @ViewBuilder content: () -> Content) {
        self.label = label
        self.boxed = boxed
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Font.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(KitchenTableTheme.charcoal)
                .accessibilityHidden(true)
            if boxed {
                content
                    .editorInputStyle()
                    .accessibilityLabel(label)
            } else {
                content
            }
        }
    }
}

private extension View {
    /// The web editor's input: paper fill, hairline border, small radius.
    func editorInputStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .topLeading)
            .background(KitchenTableTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                    .strokeBorder(KitchenTableTheme.lineStrong, lineWidth: 1)
            )
    }
}

/// A quantity field that shows "¼" and "1 ½" and reads "1/4", "1 1/2" and "0.25" back. The stored value
/// changes only when the typed text means a different number, so opening a recipe never rewrites it.
private struct QuantityField: View {
    @Binding var quantity: Double
    let rowID: String
    @Binding var invalidRows: Set<String>
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(quantity: Binding<Double>, rowID: String, invalidRows: Binding<Set<String>>) {
        _quantity = quantity
        self.rowID = rowID
        _invalidRows = invalidRows
        _text = State(initialValue: RecipeQuantity.format(quantity.wrappedValue))
    }

    var body: some View {
        TextField("1 ½", text: $text)
            .focused($isFocused)
            .editorInputStyle()
            .overlay(
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media)
                    .strokeBorder(KitchenTableTheme.tomato, lineWidth: invalidRows.contains(rowID) ? 2 : 0)
            )
            .accessibilityLabel("Quantity")
#if os(iOS)
            .keyboardType(.numbersAndPunctuation)
#endif
            .onChange(of: text) { _, newText in
                if let value = RecipeQuantity.parse(newText), RecipeQuantity.validationMessage(for: newText) == nil {
                    invalidRows.remove(rowID)
                    if value != quantity {
                        quantity = value
                    }
                } else {
                    invalidRows.insert(rowID)
                }
            }
            // A change from outside the field (a typed "2 cups rice" line) replaces the text.
            .onChange(of: quantity) { _, newValue in
                if RecipeQuantity.parse(text) != newValue {
                    text = RecipeQuantity.format(newValue)
                    invalidRows.remove(rowID)
                }
            }
            // Leaving the field shows the fraction form of what was typed, such as "1/4" becoming "¼".
            .onChange(of: isFocused) { _, focused in
                if !focused, !invalidRows.contains(rowID) {
                    text = RecipeQuantity.format(quantity)
                }
            }
            .onDisappear {
                invalidRows.remove(rowID)
            }
    }
}

#if os(iOS)
import UIKit

/// The system camera. `onFinish` gets JPEG data for a photo taken, or nil when the chef cancels or the
/// picture cannot be encoded.
private struct CameraCapture: UIViewControllerRepresentable {
    let onFinish: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void

        init(onFinish: @escaping (Data?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onFinish(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
#endif
