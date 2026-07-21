import PhotosUI
import SpoonjoyCore
import SwiftUI
import UniformTypeIdentifiers

private let supportedCoverPhotoContentTypes = [
    "image/jpeg": "jpg",
    "image/png": "jpg",
    "image/webp": "jpg",
    "image/heic": "jpg",
    "image/heif": "jpg"
]

#if DEBUG
private enum RecipeCoverScreenshotFixture {
    static let environmentKey = "SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE"
    static let actionStates = "action-states"

    static var isActionStatesEnabled: Bool {
        ProcessInfo.processInfo.environment[environmentKey] == actionStates
    }

    static func controlsData(recipe: Recipe) -> RecipeCoverControlsData {
        let imageURL = recipe.coverImageURL
        return RecipeCoverControlsData(
            covers: [
                RecipeCoverCandidate(
                    id: "cover_primary",
                    recipeID: recipe.id,
                    status: "ready",
                    sourceType: "chef-upload",
                    imageURL: imageURL,
                    stylizedImageURL: imageURL,
                    displayURL: imageURL,
                    activeVariant: .image,
                    provenanceLabel: nil,
                    archivedAt: nil,
                    generationStatus: "none",
                    failureReason: nil,
                    isServerBacked: true,
                    sourceImageURL: imageURL,
                    createdAt: recipe.updatedAt
                ),
                RecipeCoverCandidate(
                    id: "cover_alternate",
                    recipeID: recipe.id,
                    status: "ready",
                    sourceType: "spoon",
                    imageURL: imageURL,
                    stylizedImageURL: nil,
                    displayURL: imageURL,
                    activeVariant: nil,
                    provenanceLabel: nil,
                    archivedAt: nil,
                    generationStatus: "none",
                    failureReason: nil,
                    isServerBacked: true,
                    sourceImageURL: imageURL,
                    createdAt: recipe.updatedAt
                )
            ],
            spoonImages: []
        )
    }

    static var stagedPhoto: NativeStagedMediaUpload {
        NativeStagedMediaUpload(
            localStageID: "screenshot-cover-photo",
            fileName: "lemon-pantry-pasta.jpg",
            contentType: "image/jpeg",
            byteCount: 128_000
        )
    }
}
#endif

struct RecipeCoverControlsRouteView: View {
    let recipeID: String
    let initialRecipe: Recipe?
    let recipeRepository: any RecipeCatalogRepository
    let configuration: APIClientConfiguration
    let connectivity: RecipeCoverControlsConnectivity
    let stagedMediaUsage: RecipeCoverPhotoStagedMediaUsage
    let performCoverAction: @MainActor @Sendable (RecipeCoverControlsMutationPlan) async throws -> Void
    let close: () -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var recipe: Recipe?
    @State private var data: RecipeCoverControlsData?
    @State private var loadMessage: String?
    @State private var actionMessage: String?
    @State private var actionError: String?
    @State private var providerBlocker: RecipeCoverProviderBlockerDisplay?

    var body: some View {
        Group {
            if let recipe {
                RecipeCoverControlsView(
                    recipe: recipe,
                    data: data ?? .snapshot(recipe: recipe),
                    loadMessage: loadMessage,
                    actionMessage: actionMessage,
                    actionError: $actionError,
                    providerBlocker: providerBlocker,
                    connectivity: connectivity,
                    stagedMediaUsage: stagedMediaUsage,
                    runAction: runAction,
                    close: close,
                    onDismissOfflineIndicator: onDismissOfflineIndicator
                )
            } else if let loadMessage {
                KitchenTableRouteErrorView(message: loadMessage, systemImage: "photo.on.rectangle")
            } else {
                KitchenTableLoadingStateView(title: "Loading covers", subtitle: "Opening the recipe cover history.", systemImage: "photo.on.rectangle")
            }
        }
        .task(id: recipeID) {
            await load()
        }
    }

    @MainActor private func load() async {
        do {
            let loadedRecipe: Recipe
            if let initialRecipe {
                loadedRecipe = initialRecipe
            } else {
                let detail = try await recipeRepository.recipeDetail(id: recipeID)
                loadedRecipe = detail.recipe
            }
            recipe = loadedRecipe
#if DEBUG
            if RecipeCoverScreenshotFixture.isActionStatesEnabled {
                data = RecipeCoverScreenshotFixture.controlsData(recipe: loadedRecipe)
                loadMessage = nil
                return
            }
#endif
            do {
                data = try await RecipeCoverControlsData.live(
                    recipeID: loadedRecipe.id,
                    configuration: configuration
                )
                loadMessage = nil
            } catch {
                data = .snapshot(recipe: loadedRecipe)
                loadMessage = "Cover history did not load; showing the current cached cover."
            }
        } catch {
            loadMessage = "We couldn't load this recipe's covers."
        }
    }

    @MainActor private func runAction(_ action: RecipeCoverControlsAction) {
        guard let recipe else { return }
        let plan: RecipeCoverControlsMutationPlan
        do {
            plan = try RecipeCoverControlsMutationPlan.plan(
                action,
                recipeID: recipe.id,
                connectivity: connectivity
            )
        } catch {
            actionError = RecipeCoverControlsMutationPlan.userFacingPreparationFailureMessage(for: error)
            return
        }

        Task { @MainActor in
            do {
                try await performCoverAction(plan)
                actionError = nil
                actionMessage = action.successMessage
                providerBlocker = nil
                await load()
            } catch {
                if let blocker = RecipeCoverProviderBlockerDisplay.from(error: error) {
                    providerBlocker = blocker
                    actionError = blocker.message
                } else {
                    actionError = RecipeCoverControlsMutationPlan.userFacingExecutionFailureMessage(
                        for: action,
                        error: error
                    )
                }
            }
        }
    }
}

struct RecipeCoverControlsView: View {
    private static let photoStagingWorker = RecipeCoverPhotoStagingWorker()

    let recipe: Recipe
    let data: RecipeCoverControlsData
    let loadMessage: String?
    let actionMessage: String?
    @Binding var actionError: String?
    let providerBlocker: RecipeCoverProviderBlockerDisplay?
    let connectivity: RecipeCoverControlsConnectivity
    let stagedMediaUsage: RecipeCoverPhotoStagedMediaUsage
    let runAction: @MainActor (RecipeCoverControlsAction) -> Void
    let close: () -> Void
    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void

    @State private var selectedCoverPhotoItem: PhotosPickerItem?
    @State private var stagedCoverPhoto: NativeStagedMediaUpload?
    @State private var shouldGenerateEditorialCover = true
    @State private var shouldPostUploadedPhotoAsSpoon = true
    @State private var spoonNote = ""
    @State private var spoonNextTime = ""
    @State private var spoonCookedAt = ""
    @State private var placeholderPromptAddition = ""
    @State private var regenerationPromptAdditions: [String: String] = [:]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statusMessages
                photoUploadControl
                placeholderGenerationControl
                noCoverControl
                coverList
                spoonPhotoList
            }
            .padding()
        }
        .accessibilityIdentifier("recipe-covers.scroll")
        .background(KitchenTableTheme.bone)
        .task(id: recipe.id) {
#if DEBUG
            if RecipeCoverScreenshotFixture.isActionStatesEnabled, stagedCoverPhoto == nil {
                stagedCoverPhoto = RecipeCoverScreenshotFixture.stagedPhoto
            }
#endif
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: "recipe-covers",
                source: "RecipeCoverControlsView",
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                close()
            } label: {
                Label("Recipe", systemImage: "chevron.left")
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderless)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .contentShape(Rectangle())

            Text("Photo Studio")
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(recipe.title)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
            if connectivity == .offline {
                Label("Changes will queue until Spoonjoy is online.", systemImage: "wifi.slash")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
            }
        }
    }

    @ViewBuilder private var statusMessages: some View {
        if let loadMessage {
            Label(loadMessage, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
        }
        if let actionMessage {
            Label(actionMessage, systemImage: "checkmark.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
        }
        if let actionError {
            Label(actionError, systemImage: "exclamationmark.octagon")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.tomato)
        }
        if let providerBlocker {
            providerBlockerBanner(providerBlocker)
        }
    }

    private func providerBlockerBanner(_ blocker: RecipeCoverProviderBlockerDisplay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            OfflineStatusView(display: blocker.offlineIndicatorDisplay, onDismiss: onDismissOfflineIndicator)
            Text(blocker.message)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.tomato)
            if blocker.ownerActionRequired {
                Text("Owner setup is required before editorial cover generation can run.")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var photoUploadControl: some View {
        let hasStagedPhoto = stagedCoverPhoto != nil
        return VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    stagedPhotoActions(hasStagedPhoto: hasStagedPhoto, fillsAvailableWidth: false)
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 10) {
                    stagedPhotoActions(hasStagedPhoto: hasStagedPhoto, fillsAvailableWidth: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(hasStagedPhoto ? "Photo ready for this recipe." : "JPEG, PNG, WebP, HEIC, HEIF")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)

            Text("Original photo stays on the Spoon.")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.inkMuted)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $shouldGenerateEditorialCover) {
                    Text("Editorialize cover")
                        .padding(.vertical, 8)
                }
                Toggle(isOn: $shouldPostUploadedPhotoAsSpoon) {
                    Text("Post original as a Spoon")
                        .padding(.vertical, 8)
                }
            }
            .font(KitchenTableTheme.uiLabel)

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Note", text: $spoonNote)
                        .controlSize(.extraLarge)
                        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                        .accessibilityLabel("Note")
                    TextField("Next time", text: $spoonNextTime)
                        .controlSize(.extraLarge)
                        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                        .accessibilityLabel("Next time")
                    TextField("Cooked at", text: $spoonCookedAt)
                        .controlSize(.extraLarge)
                        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                        .accessibilityLabel("Cooked at")
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 8)
            } label: {
                Text("Spoon details")
                    .foregroundStyle(KitchenTableTheme.charcoal)
            }
            .font(KitchenTableTheme.uiLabel)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .contentShape(Rectangle())
            .accessibilityIdentifier("recipe-covers.spoon-details")

            if hasStagedPhoto {
                Button { submitStagedCoverPhoto() } label: {
                    Label("Save Photo", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("recipe-covers.save-photo")
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    @ViewBuilder private func stagedPhotoActions(hasStagedPhoto: Bool, fillsAvailableWidth: Bool) -> some View {
        PhotosPicker(selection: $selectedCoverPhotoItem, matching: .images) {
            Label(hasStagedPhoto ? "Replace Photo" : "Add Photo", systemImage: hasStagedPhoto ? "photo.fill" : "photo.badge.plus")
                .font(KitchenTableTheme.uiLabel)
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
        .accessibilityIdentifier("recipe-covers.photo-picker")
        .onChange(of: selectedCoverPhotoItem) { _, item in
            Task { @MainActor in
                await stageSelectedCoverPhoto(item)
            }
        }

        if hasStagedPhoto {
            Label("Photo ready", systemImage: "checkmark.circle.fill")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
                .accessibilityIdentifier("recipe-covers.staged-photo-status")
            Button {
                clearSelectedCoverPhoto()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
                    .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
            .accessibilityIdentifier("recipe-covers.clear-photo")
        }
    }

    private var placeholderGenerationControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI placeholder")
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text("Generate a temporary cover, then regenerate with direction when it needs tuning.")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            TextField("Placeholder direction", text: $placeholderPromptAddition)
                .textFieldStyle(.roundedBorder)
                .controlSize(.extraLarge)
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .accessibilityLabel("Placeholder direction")
            Button { generatePlaceholderCover() } label: {
                Label("Generate Placeholder", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("recipe-covers.generate-placeholder")
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    private var noCoverControl: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("No cover selected")
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.charcoal)
                Text("Use an explicit empty state for this recipe.")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }
            Spacer()
            Button {
                runAction(.setNoCover(clientMutationID: clientMutationID(prefix: "cover-none")))
            } label: {
                Label("Set No Cover", systemImage: "photo.badge.minus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    @ViewBuilder private var coverList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Covers")
                .font(.title2)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .accessibilityIdentifier("recipe-covers.saved-covers")

            if data.covers.isEmpty {
                Text("No saved covers yet.")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            } else {
                ForEach(data.covers) { cover in
                    coverRow(cover)
                }
            }
        }
    }

    private func coverRow(_ cover: RecipeCoverCandidate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RecipeCoverImage(url: cover.thumbnailURL)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(cover.statusLabel)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                        if cover.isActive {
                            Text("Current")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                        }
                    }
                    Text(cover.createdAtLabel)
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                    if let provenanceLabel = cover.provenanceLabel {
                        Text(provenanceLabel)
                            .font(KitchenTableTheme.bodyNote)
                            .foregroundStyle(KitchenTableTheme.charcoal)
                    }
                    if let providerBlocker = cover.providerBlocker {
                        OfflineStatusView(display: providerBlocker.offlineIndicatorDisplay, onDismiss: onDismissOfflineIndicator)
                        Text(providerBlocker.message)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.tomato)
                    } else if let failureReason = cover.failureReason {
                        Text(failureReason)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.tomato)
                    }
                    if cover.generationStatus == "processing" {
                        HStack(spacing: 8) {
                            ProgressView()
                            Label("Editorializing cover", systemImage: "sparkles")
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.brass)
                        }
                    }
                }
                Spacer()
            }

            ForEach(cover.variants) { variant in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(variant.provenanceLabel)
                            .font(KitchenTableTheme.bodyNote)
                        Text(variant.variant.label)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                    }
                    Spacer()
                    if variant.isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.brass)
                    } else if cover.canActivate {
                        Button {
                            runAction(.activate(
                                coverID: cover.id,
                                variant: variant.variant,
                                clientMutationID: clientMutationID(prefix: "cover-use")
                            ))
                        } label: {
                            Label("Use", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.vertical, 4)
            }

            if cover.canMutate {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Regeneration direction", text: regenerationPromptBinding(for: cover.id))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.extraLarge)
                        .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                        .accessibilityLabel("Regeneration direction")

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            coverMutationActions(for: cover, fillsAvailableWidth: false)
                        }
                        .fixedSize(horizontal: true, vertical: false)

                        VStack(alignment: .leading, spacing: 10) {
                            coverMutationActions(for: cover, fillsAvailableWidth: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("recipe-covers.cover-actions.\(cover.id)")
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }

    @ViewBuilder private func coverMutationActions(for cover: RecipeCoverCandidate, fillsAvailableWidth: Bool) -> some View {
        Button {
            runAction(.regenerate(
                coverID: cover.id,
                promptAddition: trimmedOptional(regenerationPromptAdditions[cover.id] ?? ""),
                activateWhenReady: cover.isActive,
                clientMutationID: clientMutationID(prefix: "cover-regenerate")
            ))
        } label: {
            Label("Regenerate", systemImage: "wand.and.stars")
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
        .accessibilityIdentifier("recipe-covers.regenerate.\(cover.id)")

        if cover.isActive {
            let replacementOptions = replacementOptions(for: cover)
            if !replacementOptions.isEmpty {
                Menu {
                    ForEach(replacementOptions) { option in
                        Button {
                            runAction(.archive(
                                coverID: cover.id,
                                replacementCoverID: option.coverID,
                                replacementVariant: option.variant,
                                confirmNoCover: false,
                                deleteSafeObjects: false,
                                clientMutationID: clientMutationID(prefix: "cover-archive-replace")
                            ))
                        } label: {
                            Label(option.label, systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                } label: {
                    Label("Archive And Replace", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
                .accessibilityIdentifier("recipe-covers.archive-replace.\(cover.id)")
            }
        }

        Button(role: .destructive) {
            runAction(.archive(
                coverID: cover.id,
                replacementCoverID: nil,
                replacementVariant: nil,
                confirmNoCover: cover.isActive,
                deleteSafeObjects: false,
                clientMutationID: clientMutationID(prefix: "cover-archive")
            ))
        } label: {
            Label(cover.isActive ? "Archive And Clear" : "Archive", systemImage: "archivebox")
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
        .accessibilityIdentifier("recipe-covers.archive.\(cover.id)")
    }

    private func replacementOptions(for cover: RecipeCoverCandidate) -> [RecipeCoverReplacementOption] {
        data.replacementOptions(for: cover)
    }

    @ViewBuilder private var spoonPhotoList: some View {
        if !data.spoonImages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spoon Photos")
                    .font(.title2)
                    .foregroundStyle(KitchenTableTheme.charcoal)

                ForEach(data.spoonImages) { spoon in
                    HStack(spacing: 12) {
                        RecipeCoverImage(url: spoon.photoURL)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.media))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(spoon.chef.username)
                                .font(KitchenTableTheme.bodyNote)
                            Text(spoon.cookedAtLabel)
                                .font(KitchenTableTheme.uiLabel)
                                .foregroundStyle(KitchenTableTheme.inkMuted)
                        }
                        Spacer()
                        Button {
                            runAction(.createFromSpoon(
                                spoonID: spoon.id,
                                activate: false,
                                generateEditorial: true,
                                clientMutationID: clientMutationID(prefix: "cover-spoon")
                            ))
                        } label: {
                            Label("Create Cover", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
                }
            }
        }
    }

    private func clientMutationID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }

    @MainActor private func submitStagedCoverPhoto() {
        guard let stagedCoverPhoto else {
            actionError = "Choose a photo before saving."
            return
        }
        runAction(.uploadPhoto(
            photo: stagedCoverPhoto,
            activateWhenReady: true,
            generateEditorial: shouldGenerateEditorialCover,
            postAsSpoon: shouldPostUploadedPhotoAsSpoon,
            note: trimmedOptional(spoonNote),
            nextTime: trimmedOptional(spoonNextTime),
            cookedAt: trimmedOptional(spoonCookedAt),
            clientMutationID: clientMutationID(prefix: "cover-upload")
        ))
    }

    @MainActor private func generatePlaceholderCover() {
        runAction(.generatePlaceholder(
            promptAddition: trimmedOptional(placeholderPromptAddition),
            activateWhenReady: true,
            clientMutationID: clientMutationID(prefix: "cover-generate")
        ))
    }

    private func regenerationPromptBinding(for coverID: String) -> Binding<String> {
        Binding(
            get: { regenerationPromptAdditions[coverID] ?? "" },
            set: { regenerationPromptAdditions[coverID] = $0 }
        )
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor private func stageSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        guard let item else {
            let result = policy.cancel(existing: stagedCoverPhoto)
            stagedCoverPhoto = result.stagedPhoto
            return
        }

        guard let (contentType, fileExtension) = item.supportedContentTypes.compactMap(Self.supportedCoverPhotoContentType).first else {
            rejectSelectedCoverPhoto(Self.photoStagingRejectionMessage(.unsupportedContentType(item.supportedContentTypes.first?.preferredMIMEType ?? "unknown")))
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                rejectSelectedCoverPhoto(Self.photoStagingRejectionMessage(.emptyData))
                return
            }
            let candidate = NativeStagedMediaUpload(
                localStageID: "cover-photo-\(UUID().uuidString)",
                fileName: "cover.\(fileExtension)",
                contentType: contentType,
                data: data
            )
            let result = await Self.photoStagingWorker.stageSelection(
                existing: stagedCoverPhoto,
                candidate: candidate,
                existingUsage: stagedMediaUsage
            )
            if let rejection = result.rejection {
                rejectSelectedCoverPhoto(Self.photoStagingRejectionMessage(rejection))
                return
            }
            stagedCoverPhoto = result.stagedPhoto
            actionError = nil
        } catch {
            rejectSelectedCoverPhoto("Photo could not be loaded.")
        }
    }

    @MainActor private func rejectSelectedCoverPhoto(_ message: String) {
        selectedCoverPhotoItem = nil
        actionError = message
    }

    @MainActor private func clearSelectedCoverPhoto() {
        selectedCoverPhotoItem = nil
        stagedCoverPhoto = nil
        actionError = nil
    }

    private static func supportedCoverPhotoContentType(_ contentType: UTType) -> (String, String)? {
        guard let mimeType = contentType.preferredMIMEType?.lowercased(),
              let fileExtension = supportedCoverPhotoContentTypes[mimeType] else {
            return nil
        }
        return (mimeType, fileExtension)
    }

    private static func photoStagingRejectionMessage(_ rejection: RecipeCoverPhotoStagingRejection) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        switch rejection {
        case .unsupportedContentType:
            return "Unsupported photo format. Choose a JPEG, PNG, WebP, or HEIC image."
        case .emptyData:
            return "Photo could not be loaded."
        case .media(.individualFileTooLarge(let limitBytes)):
            return "Photo is too large. Choose an image under \(formatter.string(fromByteCount: Int64(limitBytes)))."
        case .media(.accountByteCapReached(let limitBytes, _)):
            return "Offline photo storage is full. Sync or remove queued cover photos before adding more than \(formatter.string(fromByteCount: Int64(limitBytes)))."
        case .media(.accountFileCapReached(let limitFiles, _)):
            return "Offline photo storage is full. Sync or remove queued cover photos before adding more than \(limitFiles) files."
        case .media(.generatedPreviewCapReached), .media(.invalidPathComponent):
            return "Photo could not be staged offline."
        }
    }
}
