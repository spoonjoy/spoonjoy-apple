import Foundation
import PhotosUI
import SpoonjoyCore
import SwiftUI

#if canImport(AppKit) && os(macOS)
import AppKit
#endif

#if canImport(UIKit) && !os(macOS)
import UIKit
#endif

#if canImport(Vision)
import Vision
#endif

struct CaptureDraftView: View {
    @State private var currentDraft: CaptureDraft?
    @State private var rawText: String
    @State private var recipeURLText: String = ""
    @State private var videoURLText: String = ""
    @State private var jsonLDText: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isCameraPresented = false
    @State private var statusMessage: String?
    @State private var actionErrorMessage: String?
    @State private var actionInFlight = false

    private let inputDraft: CaptureDraft?
    private let importViewModel: CaptureImportViewModel?
    private let draftDidChange: @MainActor (CaptureDraft) -> Void
    private let draftDidDiscard: @MainActor (CaptureDraft) async throws -> Void
    private let importDidSubmit: @MainActor (CaptureDraft) async throws -> CaptureImportPlan

    private var hasPendingImport: Bool {
        importViewModel?.pendingRetryMutation != nil
    }

    private var captureControlsDisabled: Bool {
        actionInFlight || hasPendingImport
    }

    init(
        viewModel: CaptureDraftViewModel?,
        importViewModel: CaptureImportViewModel?,
        draftDidChange: @escaping @MainActor (CaptureDraft) -> Void,
        draftDidDiscard: @escaping @MainActor (CaptureDraft) async throws -> Void,
        importDidSubmit: @escaping @MainActor (CaptureDraft) async throws -> CaptureImportPlan
    ) {
        let draft = viewModel?.draft
        _currentDraft = State(initialValue: draft)
        _rawText = State(initialValue: draft?.rawText ?? "")
        self.inputDraft = draft
        self.importViewModel = importViewModel
        self.draftDidChange = draftDidChange
        self.draftDidDiscard = draftDidDiscard
        self.importDidSubmit = importDidSubmit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                textCapture
                sourceCapture
                imageCapture
                if let currentDraft {
                    draftPreview(currentDraft)
                }
                statusBanner
            }
            .padding()
        }
        .background(KitchenTableTheme.bone)
        .onAppear {
            reconcile(with: inputDraft)
        }
        .onChange(of: inputDraft) { _, draft in
            reconcile(with: draft)
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { @MainActor in
                await createPhotoLibraryDraft(from: item)
            }
        }
#if canImport(UIKit) && !os(macOS)
        .sheet(isPresented: $isCameraPresented) {
            CameraCaptureView { photo in
                Task { @MainActor in
                    await createCameraDraft(from: photo)
                }
            }
        }
#endif
    }

    private var header: some View {
        HStack {
            Text("Capture")
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Spacer()
            if let currentDraft {
                Button {
                    Task { await discard(currentDraft) }
                } label: {
                    Label("Discard Draft", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(actionInFlight)
            }
        }
    }

    private var textCapture: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $rawText)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 170)
                .padding(8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                        .stroke(KitchenTableTheme.brass.opacity(0.22))
                }
                .accessibilityLabel("capture draft text")

            HStack {
                TextField("Recipe URL", text: $recipeURLText)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                Button {
                    createTextDraft()
                } label: {
                    Label("Save Text", systemImage: "doc.text")
                }
                .buttonStyle(.borderedProminent)
                .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || captureControlsDisabled)
            }
        }
    }

    private var sourceCapture: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Import URL", text: $recipeURLText)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                Button {
                    createURLDraft()
                } label: {
                    Label("Save URL", systemImage: "link")
                }
                .buttonStyle(.bordered)
                .disabled(recipeURL == nil || captureControlsDisabled)
            }

            HStack {
                TextField("Video URL", text: $videoURLText)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                Button {
                    createVideoDraft()
                } label: {
                    Label("Save Video", systemImage: "play.rectangle")
                }
                .buttonStyle(.bordered)
                .disabled(videoURL == nil || captureControlsDisabled)
            }

            HStack(alignment: .top) {
                TextEditor(text: $jsonLDText)
                    .font(KitchenTableTheme.bodyNote)
                    .frame(minHeight: 92)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
                    .accessibilityLabel("JSON-LD recipe")
                Button {
                    createJSONLDDraft()
                } label: {
                    Label("Save JSON-LD", systemImage: "curlybraces")
                }
                .buttonStyle(.bordered)
                .disabled(jsonLDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || captureControlsDisabled)
            }
        }
    }

    private var imageCapture: some View {
        HStack {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .disabled(captureControlsDisabled)

#if canImport(UIKit) && !os(macOS)
            Button {
                isCameraPresented = true
            } label: {
                Label("Camera", systemImage: "camera")
            }
            .buttonStyle(.bordered)
            .disabled(captureControlsDisabled || !CameraCaptureView.isAvailable)
#else
            Label("Camera unavailable on this platform", systemImage: "camera")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(.secondary)
#endif
        }
    }

    @ViewBuilder private var statusBanner: some View {
        if let actionErrorMessage {
            Label(actionErrorMessage, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(.red)
        } else if let statusMessage {
            Label(statusMessage, systemImage: "info.circle")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(.secondary)
        }
    }

    private func draftPreview(_ draft: CaptureDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Local Draft", systemImage: iconName(for: draft))
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
            ForEach(draft.previewLines, id: \.self) { line in
                Text(line)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.charcoal)
            }
            if draft.importReadiness == .needsTextRecognition {
                Label("Needs Text Recognition", systemImage: "text.viewfinder")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
            if importViewModel?.connectivity == .offline {
                Label("Saved locally", systemImage: "externaldrive.badge.checkmark")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
            if importViewModel?.pendingRetryMutation != nil {
                Label("Retry Import", systemImage: "arrow.clockwise")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button {
                    Task { await submit(draft) }
                } label: {
                    Label(actionInFlight ? "Importing" : "Submit Import", systemImage: "tray.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.canCreateServerRecipe || actionInFlight)
                Button {
                    Task { await discard(draft) }
                } label: {
                    Label("Discard Draft", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(actionInFlight)
            }
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

    private var recipeURL: URL? {
        URL(string: recipeURLText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var videoURL: URL? {
        URL(string: videoURLText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func createTextDraft() {
        do {
            let draft = try CaptureDraft.localText(
                id: newDraftID("text"),
                rawText: rawText,
                sourceURL: recipeURL,
                createdAt: timestamp()
            )
            save(draft, message: "Local draft saved.")
        } catch {
            actionErrorMessage = "Draft needs text."
        }
    }

    private func createURLDraft() {
        guard let recipeURL else { return }
        do {
            let draft = try CaptureDraft.importURL(id: newDraftID("url"), url: recipeURL, createdAt: timestamp())
            save(draft, message: "Recipe URL saved.")
        } catch {
            actionErrorMessage = "URL could not be captured."
        }
    }

    private func createVideoDraft() {
        guard let videoURL else { return }
        do {
            let draft = try CaptureDraft.videoURL(id: newDraftID("video"), url: videoURL, createdAt: timestamp())
            save(draft, message: "Video URL saved.")
        } catch {
            actionErrorMessage = "Video URL could not be captured."
        }
    }

    private func createJSONLDDraft() {
        do {
            let data = Data(jsonLDText.utf8)
            let object = try JSONSerialization.jsonObject(with: data)
            let jsonLD = try Self.jsonValue(from: object)
            let draft = try CaptureDraft.jsonLD(
                id: newDraftID("jsonld"),
                jsonLD: jsonLD,
                sourceURL: recipeURL,
                createdAt: timestamp()
            )
            save(draft, message: "JSON-LD draft saved.")
        } catch {
            actionErrorMessage = "JSON-LD could not be captured."
        }
    }

    @MainActor private func createPhotoLibraryDraft(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard !captureControlsDisabled else {
            selectedPhoto = nil
            return
        }
        actionInFlight = true
        defer {
            actionInFlight = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                actionErrorMessage = "Photo could not be loaded."
                return
            }
            await createImageDraft(
                source: .photoLibraryImage,
                assetIdentifier: item.itemIdentifier ?? "photo-\(UUID().uuidString)",
                imageData: data,
                loadedMessage: "Photo scanned"
            )
        } catch {
            actionErrorMessage = "Photo could not be captured."
        }
    }

    #if canImport(UIKit) && !os(macOS)
    @MainActor private func createCameraDraft(from photo: CameraCapturedPhoto) async {
        guard !captureControlsDisabled else { return }
        actionInFlight = true
        defer { actionInFlight = false }

        await createImageDraft(
            source: .cameraImage,
            assetIdentifier: photo.assetIdentifier,
            imageData: photo.data,
            loadedMessage: "Camera image scanned"
        )
    }
    #endif

    @MainActor private func createImageDraft(
        source: CaptureDraftSource,
        assetIdentifier: String,
        imageData: Data,
        loadedMessage: String
    ) async {
        do {
            let recognizedText = try await CaptureImageTextRecognizer.recognizedText(in: imageData)
            let draft: CaptureDraft
            switch source {
            case .cameraImage:
                draft = try CaptureDraft.cameraImage(
                    id: newDraftID("camera"),
                    assetIdentifier: assetIdentifier,
                    recognizedText: recognizedText,
                    createdAt: timestamp()
                )
            case .photoLibraryImage:
                draft = try CaptureDraft.photoLibraryImage(
                    id: newDraftID("photo"),
                    assetIdentifier: assetIdentifier,
                    recognizedText: recognizedText,
                    createdAt: timestamp()
                )
            case .text, .url, .image, .shareSheetURL, .jsonLD, .videoURL:
                return
            }
            let message = draft.canCreateServerRecipe
                ? "\(loadedMessage). Review the recognized text before import."
                : "\(loadedMessage), but no recipe text was recognized."
            save(draft, message: message)
        } catch {
            actionErrorMessage = "Text recognition could not scan this image."
        }
    }

    private func save(_ draft: CaptureDraft, message: String) {
        guard !hasPendingImport else {
            actionErrorMessage = "Resolve the pending import before replacing this draft."
            return
        }

        currentDraft = draft
        rawText = draft.rawText
        statusMessage = message
        actionErrorMessage = nil
        draftDidChange(draft)
    }

    private func reconcile(with draft: CaptureDraft?) {
        guard currentDraft != draft else {
            return
        }
        currentDraft = draft
        rawText = draft?.rawText ?? ""
        selectedPhoto = nil
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
            rawText = ""
            statusMessage = nil
            actionErrorMessage = nil
            selectedPhoto = nil
        } catch {
            actionErrorMessage = "Draft could not be discarded."
        }
    }

    @MainActor private func submit(_ draft: CaptureDraft) async {
        actionInFlight = true
        actionErrorMessage = nil
        defer { actionInFlight = false }

        do {
            let plan = try await importDidSubmit(draft)
            statusMessage = plan.userFacingMessage
            if plan.captureDraftAfterCompletion == nil {
                currentDraft = nil
                rawText = ""
            }
        } catch let error as CaptureDraftImportError where error == .needsTextRecognition {
            actionErrorMessage = "Text recognition needed before import."
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

    private func newDraftID(_ prefix: String) -> String {
        "draft-\(prefix)-\(UUID().uuidString)"
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func jsonValue(from object: Any) throws -> JSONValue {
        switch object {
        case let dictionary as [String: Any]:
            return .object(try dictionary.mapValues { try jsonValue(from: $0) })
        case let array as [Any]:
            return .array(try array.map { try jsonValue(from: $0) })
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        case _ as NSNull:
            return .null
        default:
            throw CocoaError(.coderInvalidValue)
        }
    }
}

private enum CaptureImageTextRecognitionError: Error {
    case imageDecodingFailed
}

private enum CaptureImageTextRecognizer {
    static func recognizedText(in data: Data) async throws -> String? {
#if canImport(Vision)
        guard let image = image(from: data) else {
            throw CaptureImageTextRecognitionError.imageDecodingFailed
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    let handler = VNImageRequestHandler(cgImage: image, options: [:])
                    try handler.perform([request])
                    let text = (request.results ?? [])
                        .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
                    continuation.resume(returning: text.isEmpty ? nil : text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
#else
        return nil
#endif
    }

#if canImport(Vision)
    private static func image(from data: Data) -> CGImage? {
#if canImport(UIKit) && !os(macOS)
        UIImage(data: data)?.cgImage
#elseif canImport(AppKit) && os(macOS)
        NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
#else
        nil
#endif
    }
#endif
}

#if canImport(UIKit) && !os(macOS)
private struct CameraCapturedPhoto {
    let data: Data
    let assetIdentifier: String
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    let didCapture: @MainActor (CameraCapturedPhoto) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.92) else {
                parent.dismiss()
                return
            }

            parent.didCapture(CameraCapturedPhoto(
                data: data,
                assetIdentifier: "camera-\(UUID().uuidString)"
            ))
            parent.dismiss()
        }
    }
}
#endif
